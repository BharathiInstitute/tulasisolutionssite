/**
 * Message Queue Processor — processes pending messages across all channels via MSG91.
 * Replaces the old whatsapp-queue.ts.
 */

import { onCall, HttpsError, CallableRequest } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { DocumentReference, FieldValue } from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import {
  db,
  Collections,
  clientCol,
  getCallerClient,
  callableOptions,
  msg91AuthKey,
  msg91WhatsAppNumber,
} from "./config";
import * as msg91Whatsapp from "./msg91/msg91-whatsapp";
import { TemplateParam } from "./msg91/msg91-whatsapp";
import * as msg91Sms from "./msg91/msg91-sms";
import * as msg91Voice from "./msg91/msg91-voice";
import { normalizePhone } from "./utils";
import { getClientWhatsAppNumber } from "./msg91/msg91-client";

interface EnqueueRequest {
  contactId: string;
  clientId?: string;
  content?: string;
  channel?: string; // whatsapp | sms | voice
  mediaUrl?: string;
  mediaType?: string;
  templateName?: string;
  templateParams?: Array<{type: string; value: string}> | Record<string, string>;
  templateHeaderImageUrl?: string;
  templateButtonParams?: Record<string, string>;
  flowId?: string;
  voiceFlowId?: string;
  conversationId?: string;
  messageDocId?: string;
  campaignId?: string;
}

function formatFailureReason(unknownError: unknown): string {
  const message = unknownError instanceof Error
    ? unknownError.message
    : String(unknownError);
  const detailsMarker = " | Details:";
  const concise = message.includes(detailsMarker)
    ? message.substring(0, message.indexOf(detailsMarker))
    : message;
  return concise.replace(/^MSG91 error \[\d+\]:\s*/, "").trim();
}

const DEFAULT_DAILY_OUTREACH_LIMIT = 100;

function outreachDayKey(date = new Date()): string {
  return date.toISOString().substring(0, 10);
}

async function recordCampaignOutcome(
  campaignId: string | undefined,
  status: "sent" | "delivered" | "read" | "failed",
): Promise<void> {
  if (!campaignId) return;
  try {
    await db.collection("outreach_campaigns").doc(campaignId).update({
      [`stats.${status}`]: FieldValue.increment(1),
      updatedAt: new Date(),
    });
  } catch (error) {
    logger.warn(`Could not update campaign ${campaignId} ${status} count`, error);
  }
}

async function campaignAllowsSending(
  campaignId: string | undefined,
): Promise<boolean> {
  if (!campaignId) return true;
  const snapshot = await db.collection("outreach_campaigns").doc(campaignId).get();
  return !["paused", "cancelled"].includes(String(snapshot.data()?.status));
}

async function leadAllowsMessaging(
  clientId: string,
  queueMessageRef: DocumentReference,
): Promise<boolean> {
  const clientSnapshot = await db.collection(Collections.clients).doc(clientId).get();
  if (clientSnapshot.data()?.doNotContact !== true) return true;
  await queueMessageRef.update({
    status: "cancelled",
    error: "Lead opted out of messaging",
    cancelledAt: new Date(),
  });
  return false;
}

async function resolveEnqueueClientId(
  request: CallableRequest<EnqueueRequest>,
): Promise<{ uid: string; clientId: string }> {
  if (!request.auth?.uid) {
    throw new HttpsError("unauthenticated", "Authentication required");
  }

  const requestedClientId = request.data.clientId?.trim();
  if (!requestedClientId) {
    return getCallerClient(request.auth);
  }

  const userSnap = await db.collection("users").doc(request.auth.uid).get();
  const userData = userSnap.data();
  const panels = Array.isArray(userData?.panels) ? userData.panels : [];
  if (userData?.isAdmin === true || panels.includes("chat")) {
    return { uid: request.auth.uid, clientId: requestedClientId };
  }

  const caller = await getCallerClient(request.auth);
  if (caller.clientId !== requestedClientId) {
    throw new HttpsError("permission-denied", "Cannot send messages for this client");
  }
  return caller;
}

async function claimPendingMessage(queueMessageRef: DocumentReference): Promise<boolean> {
  return db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(queueMessageRef);
    if (!snapshot.exists || snapshot.data()?.status !== "pending") return false;
    transaction.update(queueMessageRef, {
      status: "sending",
      claimedAt: new Date(),
    });
    return true;
  });
}

/**
 * Processes pending messages in the queue.
 * Runs every 30 minutes as a recovery pass for delayed or retried messages.
 * Immediate messages are handled by onMessageQueued.
 */
export const processMessageQueue = onSchedule(
  {
    schedule: "every 30 minutes",
    region: "asia-south1",
    secrets: [msg91AuthKey, msg91WhatsAppNumber],
  },
  async () => {
    const pendingQuery = db.collectionGroup(Collections.messageQueue)
      .where("status", "==", "pending")
      .limit(100);
    const existingClients = new Map<string, boolean>();
    const clientMessageCounts = new Map<string, number>();
    let pendingSnap = await pendingQuery.get();

    while (!pendingSnap.empty) {
      for (const doc of pendingSnap.docs) {
        const ownerRef = doc.ref.parent.parent;
        if (!ownerRef || ownerRef.parent.path !== Collections.clients) continue;
        const clientId = ownerRef.id;
        const messageCount = clientMessageCounts.get(clientId) ?? 0;
        if (messageCount >= 100) continue;
        clientMessageCounts.set(clientId, messageCount + 1);
        const data = doc.data();
        const channel = data.channel ?? "whatsapp";
        const retries = data.retries ?? 0;
        const scheduledAt = data.scheduledAt?.toDate?.() as Date | undefined;

        if (scheduledAt && scheduledAt > new Date()) continue;
        if (!existingClients.has(clientId)) {
          existingClients.set(clientId, (await ownerRef.get()).exists);
        }
        if (!existingClients.get(clientId)) continue;
        if (!await campaignAllowsSending(data.campaignId)) continue;
        if (!await leadAllowsMessaging(clientId, doc.ref)) continue;

        if (retries >= 3) {
          await doc.ref.update({
            status: "failed",
            failedAt: new Date(),
            error: "Max retries exceeded",
          });
          await db.collection(Collections.clients).doc(clientId).set({
            lastSendStatus: "failed",
            lastSendError: data.lastError ?? "Maximum retries exceeded",
            lastAttemptAt: new Date(),
            lastCampaignId: data.campaignId ?? null,
          }, { merge: true });
          await recordCampaignOutcome(data.campaignId, "failed");

          // SMS fallback: if WhatsApp failed and no prior fallback attempted
          if (channel === "whatsapp" && !data.smsFallbackOf) {
            await attemptSmsFallback(clientId, data, doc.id);
          }
          continue;
        }

        if (!await claimPendingMessage(doc.ref)) continue;

        // Get contact phone
        let phone = data.phone;
        if (!phone && data.contactId) {
          const contactSnap = await db
            .doc(
              `${clientCol(clientId, Collections.contacts)}/${data.contactId}`
            )
            .get();
          phone = contactSnap.data()?.phone;
        }

        if (!phone) {
          await doc.ref.update({
            status: "failed",
            error: "No phone number found",
          });
          await db.collection(Collections.clients).doc(clientId).set({
            lastSendStatus: "failed",
            lastSendError: "No phone number found",
            lastAttemptAt: new Date(),
            lastCampaignId: data.campaignId ?? null,
          }, { merge: true });
          await recordCampaignOutcome(data.campaignId, "failed");
          continue;
        }

        const normalizedPhone = normalizePhone(phone);

        try {
          logger.info(`Sending ${channel} message to ${normalizedPhone} (raw: ${phone})`, { docId: doc.id, content: data.content?.substring(0, 50) });

          // Get this client's WhatsApp number (per-client or global fallback)
          let clientWaNumber: string | undefined;
          if (channel === "whatsapp") {
            try {
              clientWaNumber = await getClientWhatsAppNumber(clientId);
            } catch (e) {
              logger.warn(`Could not get WA number for client ${clientId}, using global`, e);
            }
          }

          let msg91RequestId: string | undefined;
          if (channel === "whatsapp") {
            // Normalize templateParams (may be Map or Array)
            let bodyParams = data.templateParams;
            if (bodyParams && !Array.isArray(bodyParams)) {
              const obj = bodyParams as Record<string, string>;
              bodyParams = Object.keys(obj)
                .sort((a, b) => parseInt(a) - parseInt(b))
                .map((k) => ({ type: "text" as const, value: obj[k] }));
            }

            // Safety net: replace empty/null param values so MSG91 never gets blanks.
            if (Array.isArray(bodyParams) && bodyParams.length > 0) {
              let contactName: string | undefined;
              if (data.contactId) {
                try {
                  const cSnap = await db
                    .doc(`${clientCol(clientId, Collections.contacts)}/${data.contactId}`)
                    .get();
                  contactName = cSnap.data()?.name;
                } catch (_) { /* ignore */ }
              }
              bodyParams = (bodyParams as TemplateParam[]).map((p, i) => {
                const v = (p?.value ?? "").toString().trim();
                if (v.length > 0 && v !== "—") return p;
                const fallback = i === 0 && contactName ? contactName : "-";
                logger.warn(`[queue] empty templateParam[${i}], filling with "${fallback}"`);
                return { type: "text" as const, value: fallback };
              });
            }

            // Look up template language (te/hi/en etc.) from Firestore
            let templateLanguage: string | undefined;
            if (data.templateName) {
              try {
                const tSnap = await db
                  .collection(clientCol(clientId, Collections.templates))
                  .where("name", "==", data.templateName).limit(1).get();
                templateLanguage = tSnap.empty ? undefined : tSnap.docs[0].data().language;
              } catch (_) { /* ignore, defaults to 'en' */ }
            }

            let result;
            if (data.templateName) {
              result = await msg91Whatsapp.sendWhatsAppMessage({
                to: normalizedPhone,
                templateName: data.templateName,
                language: templateLanguage,
                bodyParams: bodyParams as TemplateParam[],
                headerParams: data.templateHeaderImageUrl
                  ? [{ type: "image", value: data.templateHeaderImageUrl }]
                  : undefined,
                buttonParams: data.templateButtonParams,
                integratedNumber: clientWaNumber,
              });
            } else if (data.mediaUrl) {
              result = await msg91Whatsapp.sendWhatsAppMedia({
                to: normalizedPhone,
                mediaUrl: data.mediaUrl,
                caption: data.content,
                integratedNumber: clientWaNumber,
                mediaType: data.mediaType as "image" | "video" | "document" | "audio" | "sticker",
              });
            } else {
              result = await msg91Whatsapp.sendWhatsAppText({
                to: normalizedPhone,
                text: data.content,
                integratedNumber: clientWaNumber,
              });
            }
            logger.info(`MSG91 WhatsApp response for ${normalizedPhone}: ${JSON.stringify(result)}`);
            if (!result.success) {
              throw new Error(`MSG91 send failed: ${JSON.stringify(result)}`);
            }
            msg91RequestId = result.requestId;
          } else if (channel === "sms") {
            const flowId = data.flowId;
            if (!flowId) throw new Error("flowId required for SMS");
            await msg91Sms.sendSMS(flowId, [
              { mobile: normalizedPhone, VAR1: data.content },
            ]);
          } else if (channel === "voice") {
            const voiceFlowId = data.voiceFlowId;
            if (!voiceFlowId) throw new Error("voiceFlowId required for voice");
            await msg91Voice.makeVoiceCall(normalizedPhone, voiceFlowId);
          }

          const sentAt = new Date();
          await doc.ref.update({
            status: "sent",
            sentAt,
            lastError: FieldValue.delete(),
            error: FieldValue.delete(),
            ...(msg91RequestId ? { msg91RequestId } : {}),
          });
          const conversationId = data.conversationId as string | undefined;
          if (conversationId) {
            await db.doc(
              `${clientCol(clientId, Collections.conversations)}/${conversationId}`
            ).set({
              lastMessage: String(data.content ?? ""),
              lastMessageAt: sentAt,
              lastMessageDirection: "outbound",
            }, { merge: true });
          }
          const clientRef = db.collection(Collections.clients).doc(clientId);
          const clientSnapshot = await clientRef.get();
          await clientRef.set({
            lastSendStatus: "sent",
            lastSendError: null,
            lastAttemptAt: new Date(),
            lastCampaignId: data.campaignId ?? null,
            ...(clientSnapshot.data()?.stage === "reach" ? {
              stage: "click",
              stageChangedAt: new Date(),
              followUpAt: null,
              followUpNotes: null,
            } : {}),
          }, { merge: true });
          await recordCampaignOutcome(data.campaignId, "sent");
        } catch (err) {
          const failureReason = formatFailureReason(err);
          await doc.ref.update({
            status: "pending",
            retries: retries + 1,
            lastError: failureReason,
          });
          await db.collection(Collections.clients).doc(clientId).set({
            lastSendStatus: "retrying",
            lastSendError: failureReason,
            lastAttemptAt: new Date(),
            lastCampaignId: data.campaignId ?? null,
          }, { merge: true });
        }
      }
      if (pendingSnap.size < 100) break;
      pendingSnap = await pendingQuery
        .startAfter(pendingSnap.docs[pendingSnap.docs.length - 1])
        .get();
    }
  }
);

/**
 * Enqueue a single message for sending via any channel.
 */
export const enqueueMessage = onCall(
  callableOptions,
  async (request: CallableRequest<EnqueueRequest>) => {
    const { uid, clientId } = await resolveEnqueueClientId(request);
    const { contactId, content, channel, mediaUrl, mediaType, templateName, flowId, voiceFlowId } =
      request.data;

    // Normalize templateParams: accept Map<string,string> from Flutter or Array<{type,value}>
    let templateParams = request.data.templateParams;
    logger.info(`enqueueMessage: channel=${channel ?? "whatsapp"} templateName=${templateName ?? "null"} content="${(content ?? "").substring(0, 60)}" templateParams=${JSON.stringify(templateParams)}`);
    if (templateParams && !Array.isArray(templateParams)) {
      // Convert {1: "val1", 2: "val2"} to [{type:"text",value:"val1"},{type:"text",value:"val2"}]
      const obj = templateParams as Record<string, string>;
      templateParams = Object.keys(obj)
        .sort((a, b) => parseInt(a) - parseInt(b))
        .map((k) => ({ type: "text", value: obj[k] }));
      logger.info(`enqueueMessage: normalized templateParams=${JSON.stringify(templateParams)}`);
    }

    const templateButtonParams = Object.entries(request.data.templateButtonParams ?? {})
      .sort(([left], [right]) => Number(left) - Number(right))
      .map(([index, value]) => ({ index: Number(index), value: value.trim() }));

    if (templateName && !/^[a-z0-9_]+$/.test(templateName)) {
      throw new HttpsError("invalid-argument", "Invalid WhatsApp template name");
    }
    if (templateParams?.some((param) => !param.value?.trim())) {
      throw new HttpsError("invalid-argument", "WhatsApp template variables cannot be blank");
    }
    if (templateButtonParams.some((param) => !Number.isInteger(param.index) || param.index < 0 || !param.value)) {
      throw new HttpsError("invalid-argument", "WhatsApp button variables require a zero-based button index and non-blank value");
    }

    const normalizedContent = (content ?? "").trim();
    if (!normalizedContent && !mediaUrl && !templateName) {
      throw new HttpsError(
        "invalid-argument",
        "content is required for non-media messages"
      );
    }

    // Get contact phone — try contactId first, then fall back to conversation phone
    let phone: string | undefined;
    if (contactId) {
      const contactSnap = await db
        .doc(`${clientCol(clientId, Collections.contacts)}/${contactId}`)
        .get();
      phone = contactSnap.data()?.phone;
    }

    // If no phone from contact, try to get from the conversation
    if (!phone && request.data.conversationId) {
      const convSnap = await db
        .doc(`${clientCol(clientId, Collections.conversations)}/${request.data.conversationId}`)
        .get();
      phone = convSnap.data()?.contactPhone;
    }

    if (!phone) {
      throw new HttpsError("not-found", "Contact phone number not found");
    }

    const clientRef = db.collection(Collections.clients).doc(clientId);
    const clientSnapshot = await clientRef.get();
    if (clientSnapshot.data()?.doNotContact === true) {
      throw new HttpsError("failed-precondition", "This lead has opted out of messaging");
    }

    const queueRef = db.collection(
      clientCol(clientId, Collections.messageQueue)
    );

    const queueData = {
      contactId,
      phone,
      content: normalizedContent,
      channel: channel ?? "whatsapp",
      mediaUrl: mediaUrl ?? null,
      mediaType: mediaType ?? null,
      templateName: templateName ?? null,
      templateParams: templateParams ?? null,
      templateHeaderImageUrl: request.data.templateHeaderImageUrl?.trim() || null,
      templateButtonParams: templateButtonParams.length > 0 ? templateButtonParams : null,
      flowId: flowId ?? null,
      voiceFlowId: voiceFlowId ?? null,
      conversationId: request.data.conversationId ?? null,
      messageDocId: request.data.messageDocId ?? null,
      campaignId: request.data.campaignId ?? null,
      status: "pending",
      createdAt: new Date(),
      createdBy: uid,
      retries: 0,
    };

    let docRef: DocumentReference;
    if (request.data.campaignId) {
      const campaignId = request.data.campaignId;
      docRef = queueRef.doc(`${campaignId}_${contactId}`);
      const campaignRef = db.collection("outreach_campaigns").doc(campaignId);
      const usageRef = db.collection("outreach_daily_usage").doc(outreachDayKey());
      const settingsSnapshot = await db.doc("system_settings/outreach").get();
      const dailyLimit = Math.max(
        1,
        Number(settingsSnapshot.data()?.dailyLimit ?? DEFAULT_DAILY_OUTREACH_LIMIT),
      );
      let duplicate = false;

      await db.runTransaction(async (transaction) => {
        const [queueSnapshot, usageSnapshot, campaignSnapshot] = await Promise.all([
          transaction.get(docRef),
          transaction.get(usageRef),
          transaction.get(campaignRef),
        ]);
        if (queueSnapshot.exists) {
          duplicate = true;
          return;
        }
        const used = Number(usageSnapshot.data()?.count ?? 0);
        if (used >= dailyLimit) {
          throw new HttpsError(
            "resource-exhausted",
            `Daily outreach limit of ${dailyLimit} reached`,
          );
        }
        transaction.set(docRef, queueData);
        transaction.set(usageRef, {
          count: FieldValue.increment(1),
          limit: dailyLimit,
          date: outreachDayKey(),
          updatedAt: new Date(),
        }, { merge: true });
        transaction.set(campaignRef, {
          templateName: templateName ?? null,
          channel: channel ?? "whatsapp",
          createdBy: uid,
          updatedAt: new Date(),
          ...(!campaignSnapshot.exists ? {
            status: "running",
            createdAt: new Date(),
          } : {}),
          stats: {
            queued: FieldValue.increment(1),
            sent: FieldValue.increment(0),
            delivered: FieldValue.increment(0),
            read: FieldValue.increment(0),
            failed: FieldValue.increment(0),
          },
        }, { merge: true });
      });

      if (duplicate) {
        return { success: true, messageId: docRef.id, duplicate: true };
      }
    } else {
      docRef = await queueRef.add(queueData);
    }

    await db.collection(Collections.clients).doc(clientId).set({
      lastSendStatus: "pending",
      lastSendError: null,
      lastAttemptAt: new Date(),
      sendAttemptCount: FieldValue.increment(1),
      lastCampaignId: request.data.campaignId ?? null,
    }, { merge: true });

    logger.info(`enqueueMessage: queued doc ${docRef.id} for ${phone} channel=${channel ?? "whatsapp"} templateName=${templateName ?? "null"}`);
    return { success: true, messageId: docRef.id };
  }
);

export const updateOutreachCampaignStatus = onCall(
  callableOptions,
  async (request: CallableRequest<{campaignId?: string; status?: string}>) => {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "Authentication required");
    }
    const campaignId = request.data.campaignId?.trim();
    const status = request.data.status?.trim();
    if (!campaignId || !["running", "paused", "cancelled", "completed"].includes(status ?? "")) {
      throw new HttpsError("invalid-argument", "A valid campaign and status are required");
    }
    const campaignRef = db.collection("outreach_campaigns").doc(campaignId);
    const snapshot = await campaignRef.get();
    if (!snapshot.exists || snapshot.data()?.createdBy !== request.auth.uid) {
      throw new HttpsError("permission-denied", "Campaign not found");
    }
    await campaignRef.update({ status, updatedAt: new Date() });
    return { success: true };
  },
);

/**
 * Real-time trigger — sends message immediately when added to queue.
 * Fires on document creation in any client's message_queue subcollection.
 */
export const onMessageQueued = onDocumentCreated(
  {
    document: "clients/{clientId}/message_queue/{messageId}",
    region: "asia-south1",
    secrets: [msg91AuthKey, msg91WhatsAppNumber],
  },
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const data = snap.data();
    if (data.status !== "pending") return;

    const scheduledAt = data.scheduledAt?.toDate?.() as Date | undefined;
    if (scheduledAt && scheduledAt > new Date()) return;

    const clientId = event.params.clientId;
    const channel = data.channel ?? "whatsapp";
    const retries = data.retries ?? 0;

    if (!await campaignAllowsSending(data.campaignId)) return;
    if (!await leadAllowsMessaging(clientId, snap.ref)) return;

    let phone = data.phone;
    if (!phone && data.contactId) {
      const contactSnap = await db
        .doc(`${clientCol(clientId, Collections.contacts)}/${data.contactId}`)
        .get();
      phone = contactSnap.data()?.phone;
    }

    if (!phone) {
      await snap.ref.update({ status: "failed", error: "No phone number found" });
      return;
    }

    const normalizedPhone = normalizePhone(phone);

    try {
      if (!await claimPendingMessage(snap.ref)) return;
      logger.info(`[realtime] Sending ${channel} message to ${normalizedPhone} (raw: ${phone}) templateName=${data.templateName ?? "null"} templateParams=${JSON.stringify(data.templateParams)}`);

      // Get this client's WhatsApp number (per-client or global fallback)
      let clientWaNumber: string | undefined;
      if (channel === "whatsapp") {
        try {
          clientWaNumber = await getClientWhatsAppNumber(clientId);
        } catch (e) {
          logger.warn(`[realtime] Could not get WA number for client ${clientId}, using global`, e);
        }
      }

      let msg91RequestId: string | undefined;
      if (channel === "whatsapp") {
        // Normalize templateParams from Firestore doc (may be Map or Array)
        let bodyParams = data.templateParams;
        if (bodyParams && !Array.isArray(bodyParams)) {
          const obj = bodyParams as Record<string, string>;
          bodyParams = Object.keys(obj)
            .sort((a, b) => parseInt(a) - parseInt(b))
            .map((k) => ({ type: "text" as const, value: obj[k] }));
        }

        // Safety net: replace any empty/null param values so MSG91 never gets
        // blanks (which silently render as missing variables in the message).
        // Param at index 0 ({{1}}) defaults to the contact's name if known,
        // remaining params default to "-".
        if (Array.isArray(bodyParams) && bodyParams.length > 0) {
          let contactName: string | undefined;
          if (data.contactId) {
            try {
              const contactSnap = await db
                .doc(`${clientCol(clientId, Collections.contacts)}/${data.contactId}`)
                .get();
              contactName = contactSnap.data()?.name;
            } catch (_) {
              // ignore — fall back to "-"
            }
          }
          bodyParams = (bodyParams as TemplateParam[]).map((p, i) => {
            const v = (p?.value ?? "").toString().trim();
            if (v.length > 0 && v !== "—") return p;
            const fallback = i === 0 && contactName ? contactName : "-";
            logger.warn(`[realtime] empty templateParam at index ${i}, filling with "${fallback}"`);
            return { type: "text" as const, value: fallback };
          });
        }

        // Look up template language from Firestore
        let templateLanguage: string | undefined;
        if (data.templateName) {
          try {
            const tSnap = await db
              .collection(clientCol(clientId, Collections.templates))
              .where("name", "==", data.templateName).limit(1).get();
            templateLanguage = tSnap.empty ? undefined : tSnap.docs[0].data().language;
          } catch (_) { /* ignore, defaults to 'en' */ }
        }

        let result;
        if (data.templateName) {
          result = await msg91Whatsapp.sendWhatsAppMessage({
            to: normalizedPhone,
            templateName: data.templateName,
            language: templateLanguage,
            bodyParams: bodyParams as TemplateParam[],
            headerParams: data.templateHeaderImageUrl
              ? [{ type: "image", value: data.templateHeaderImageUrl }]
              : undefined,
            buttonParams: data.templateButtonParams,
            integratedNumber: clientWaNumber,
          });
        } else if (data.mediaUrl) {
          result = await msg91Whatsapp.sendWhatsAppMedia({
            to: normalizedPhone,
            mediaUrl: data.mediaUrl,
            caption: data.content,
            mediaType: data.mediaType,
            integratedNumber: clientWaNumber,
          });
        } else {
          result = await msg91Whatsapp.sendWhatsAppText({
            to: normalizedPhone,
            text: data.content,
            integratedNumber: clientWaNumber,
          });
        }
        logger.info(`[realtime] MSG91 response for ${normalizedPhone}: ${JSON.stringify(result)}`);
        if (!result.success) {
          throw new Error(`MSG91 send failed: ${JSON.stringify(result)}`);
        }
        msg91RequestId = result.requestId;
      } else if (channel === "sms") {
        if (!data.flowId) throw new Error("flowId required for SMS");
        await msg91Sms.sendSMS(data.flowId, [
          { mobile: normalizedPhone, VAR1: data.content },
        ]);
      } else if (channel === "voice") {
        if (!data.voiceFlowId) throw new Error("voiceFlowId required for voice");
        await msg91Voice.makeVoiceCall(normalizedPhone, data.voiceFlowId);
      }

      const sentAt = new Date();
      await snap.ref.update({
        status: "sent",
        sentAt,
        lastError: FieldValue.delete(),
        error: FieldValue.delete(),
        ...(msg91RequestId ? { msg91RequestId } : {}),
      });

      // Also update the actual message doc in the messages subcollection
      const conversationId = data.conversationId as string | undefined;
      const messageDocId = data.messageDocId as string | undefined;
      if (conversationId) {
        await db.doc(
          `${clientCol(clientId, Collections.conversations)}/${conversationId}`
        ).set({
          lastMessage: String(data.content ?? ""),
          lastMessageAt: sentAt,
          lastMessageDirection: "outbound",
        }, { merge: true });
      }
      if (conversationId && messageDocId) {
        try {
          await db
            .doc(
              `${clientCol(clientId, Collections.conversations)}/${conversationId}/${Collections.messages}/${messageDocId}`
            )
            .update({
              status: "sent",
              failureReason: FieldValue.delete(),
            });
          logger.info(`[realtime] Updated message doc ${messageDocId} status to sent`);
        } catch (msgErr) {
          logger.warn(`[realtime] Failed to update message doc: ${msgErr}`);
        }
      }

      const clientRef = db.collection(Collections.clients).doc(clientId);
      const clientSnapshot = await clientRef.get();
      await clientRef.set({
        lastSendStatus: "sent",
        lastSendError: null,
        lastAttemptAt: new Date(),
        lastCampaignId: data.campaignId ?? null,
      }, { merge: true });
      await recordCampaignOutcome(data.campaignId, "sent");
      if (clientSnapshot.data()?.stage === "reach") {
        await clientRef.update({
          stage: "click",
          stageChangedAt: new Date(),
          followUpAt: null,
          followUpNotes: null,
        });
      }
    } catch (err) {
      logger.error(`[realtime] Send failed for ${normalizedPhone}:`, err);
      const failureReason = formatFailureReason(err);

      // Update message doc to failed status
      const conversationId = data.conversationId as string | undefined;
      const messageDocId = data.messageDocId as string | undefined;
      if (conversationId && messageDocId) {
        try {
          await db
            .doc(
              `${clientCol(clientId, Collections.conversations)}/${conversationId}/${Collections.messages}/${messageDocId}`
            )
            .update({ status: "failed", failureReason });
        } catch (_) { /* ignore */ }
      }

      await snap.ref.update({
        status: "pending",
        retries: retries + 1,
        lastError: failureReason,
      });
      await db.collection(Collections.clients).doc(clientId).set({
        lastSendStatus: "retrying",
        lastSendError: failureReason,
        lastAttemptAt: new Date(),
        lastCampaignId: data.campaignId ?? null,
      }, { merge: true });
    }
  }
);

/**
 * Attempt SMS fallback for a failed WhatsApp message.
 * Reads the client's autoTrigger settings; if smsFallbackEnabled + smsFallbackFlowId
 * are configured, enqueues a new SMS message with the same content.
 */
async function attemptSmsFallback(
  clientId: string,
  originalData: Record<string, unknown>,
  originalDocId: string
): Promise<void> {
  try {
    // Check autoTrigger settings for SMS fallback config
    const settingsDoc = await db
      .doc(`${Collections.clients}/${clientId}/settings/autoTriggers`)
      .get();
    const settings = settingsDoc.data() ?? {};

    if (!settings.smsFallbackEnabled || !settings.smsFallbackFlowId) {
      logger.info(`[smsFallback] Not enabled for client ${clientId}`);
      return;
    }

    const queueRef = db.collection(clientCol(clientId, Collections.messageQueue));
    const content = (originalData.content as string) ?? "";

    await queueRef.add({
      contactId: originalData.contactId ?? null,
      phone: originalData.phone ?? null,
      content,
      channel: "sms",
      flowId: settings.smsFallbackFlowId,
      templateName: null,
      templateParams: null,
      mediaUrl: null,
      voiceFlowId: null,
      conversationId: originalData.conversationId ?? null,
      messageDocId: null,
      status: "pending",
      createdAt: new Date(),
      createdBy: "system:sms-fallback",
      retries: 0,
      smsFallbackOf: originalDocId,
    });

    logger.info(`[smsFallback] Enqueued SMS fallback for failed WhatsApp doc ${originalDocId}`);
  } catch (err) {
    logger.error(`[smsFallback] Failed to enqueue SMS fallback: ${err}`);
  }
}

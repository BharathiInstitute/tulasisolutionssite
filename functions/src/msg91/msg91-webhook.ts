/**
 * MSG91 Webhook Handler — receives inbound messages, delivery reports, and call status.
 * This is an HTTP function (not callable) since MSG91 POSTs directly to it.
 */

import { onRequest } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import { db, Collections, clientCol } from "../config";
import { parseWebhook } from "./msg91-whatsapp";

type TrackingInfo = {
  clickType: "reach" | "ads";
  source: string;
  campaign: string;
};

const ZW_START = "\u2063";
const ZW_END = "\u2064";
const ZW_ZERO = "\u200B";
const ZW_ONE = "\u200C";

function decodeHiddenClickRef(hidden: string): string | null {
  if (!hidden) return null;
  const bits = hidden
    .replace(new RegExp(ZW_ZERO, "g"), "0")
    .replace(new RegExp(ZW_ONE, "g"), "1");
  if (!bits || bits.length % 8 !== 0 || /[^01]/.test(bits)) return null;

  const bytes: number[] = [];
  for (let i = 0; i < bits.length; i += 8) {
    bytes.push(parseInt(bits.slice(i, i + 8), 2));
  }

  try {
    const decoded = Buffer.from(bytes).toString("utf8").trim();
    return decoded.length > 0 ? decoded : null;
  } catch {
    return null;
  }
}

function extractTrackingInfo(raw: string | undefined): { cleanText: string; tracking: TrackingInfo | null; clickRef: string | null } {
  if (!raw) return { cleanText: "", tracking: null, clickRef: null };

  const hiddenRegex = new RegExp(`${ZW_START}([${ZW_ZERO}${ZW_ONE}]+)${ZW_END}`);
  const hiddenMatch = raw.match(hiddenRegex);
  const hiddenPayload = hiddenMatch?.[1] ?? null;
  const clickRef = hiddenPayload ? decodeHiddenClickRef(hiddenPayload) : null;
  const withoutHidden = hiddenMatch ? raw.replace(hiddenMatch[0], "") : raw;

  const match = withoutHidden.match(/TCREF:(reach|ads)\|([^|\n]+)\|([^\n]+)/i);
  if (!match) return { cleanText: withoutHidden.trim(), tracking: null, clickRef };

  const clickType = match[1].toLowerCase() === "ads" ? "ads" : "reach";
  const source = match[2].trim() || "unknown_source";
  const campaign = match[3].trim() || "default_campaign";
  const cleanText = withoutHidden.replace(match[0], "").replace(/\n{3,}/g, "\n\n").trim();
  return { cleanText, tracking: { clickType, source, campaign }, clickRef };
}

async function resolveTrackingByClickRef(clientId: string, clickRef: string): Promise<TrackingInfo | null> {
  if (!clickRef) return null;

  const snap = await db
    .collection(clientCol(clientId, "linkClicks"))
    .where("clickRef", "==", clickRef)
    .limit(1)
    .get();

  if (snap.empty) return null;
  const data = snap.docs[0].data();
  const clickType = String(data.clickType ?? "reach").toLowerCase() === "ads" ? "ads" : "reach";
  const source = String(data.source ?? "unknown_source").trim() || "unknown_source";
  const campaign = String(data.campaign ?? "default_campaign").trim() || "default_campaign";

  return { clickType, source, campaign };
}

/**
 * Webhook endpoint for MSG91.
 * URL: https://<region>-<project>.cloudfunctions.net/msg91Webhook
 *
 * Handles:
 * - Inbound WhatsApp messages
 * - Inbound SMS messages
 * - Delivery status updates (sent, delivered, read, failed)
 * - Call status callbacks
 */
export const msg91Webhook = onRequest(
  { region: "asia-south1" },
  async (req, res) => {
    // Only accept POST
    if (req.method !== "POST") {
      res.status(405).json({ error: "Method not allowed" });
      return;
    }

    // Verify the request has a body
    const body = req.body;
    logger.info("msg91Webhook received:", JSON.stringify(body));

    if (!body || typeof body !== "object") {
      res.status(400).json({ error: "Missing request body" });
      return;
    }

    try {
      // Determine the type of webhook event
      const eventType = body.event ?? body.type ?? "unknown";
      const channel = body.channel ?? detectChannel(body);
      logger.info(`msg91Webhook: eventType=${eventType}, channel=${channel}`);

      if (channel === "whatsapp") {
        await handleWhatsAppWebhook(body);
      } else if (channel === "sms") {
        await handleSMSWebhook(body);
      } else if (channel === "voice") {
        await handleVoiceWebhook(body);
      } else if (eventType === "delivery" || eventType === "status") {
        await handleDeliveryReport(body);
      } else {
        // Log unknown events for debugging
        await db.collection("webhook_logs").add({
          source: "msg91",
          body,
          receivedAt: new Date(),
          processed: false,
        });
      }

      res.status(200).json({ success: true });
    } catch (err) {
      logger.error("Webhook processing error:", err);
      console.error("Webhook processing error:", err);
      // Return 200 to prevent MSG91 from retrying
      res.status(200).json({ success: false, error: "Processing error" });
    }
  }
);

function detectChannel(body: Record<string, unknown>): string {
  // MSG91 WhatsApp webhooks always include integratedNumber
  if (body.integratedNumber) return "whatsapp";
  if (body.whatsapp || body.wa || body.whatsappMessage) return "whatsapp";
  if (body.sms || body.smsMessage) return "sms";
  if (body.voice || body.call) return "voice";
  if (body.content_type === "text" || body.content_type === "template") return "whatsapp";
  if (body.contentType === "text" || body.contentType === "template") return "whatsapp";
  return "unknown";
}

/**
 * Handle inbound WhatsApp message.
 */
async function handleWhatsAppWebhook(
  body: Record<string, unknown>,
): Promise<void> {
  const parsed = parseWebhook(body);

  if (parsed.type === "status") {
    await handleDeliveryReport(body);
    return;
  }

  const phone = parsed.from;
  if (!phone) return;

  // Find the client that owns this WhatsApp number.
  // Priority 1: Match by the receiving WhatsApp number (integratedNumber in payload)
  // Priority 2: Match by sender phone in contacts (legacy fallback)
  const receivingNumber = (body.integratedNumber as string) ?? (body.integrated_number as string);
  let clientId: string | null = null;

  if (receivingNumber) {
    clientId = await findClientByWhatsAppNumber(receivingNumber);
  }
  if (!clientId) {
    clientId = await findClientByPhone(phone);
  }
  if (!clientId) return;

  // Find or create conversation
  const convRef = await findOrCreateConversation(
    clientId,
    phone,
    parsed.contactName ?? phone,
    "whatsapp"
  );

  const { cleanText, tracking: directTracking, clickRef } = extractTrackingInfo(parsed.body);
  const tracking = directTracking ?? (clickRef ? await resolveTrackingByClickRef(clientId, clickRef) : null);

  // Store inbound message
  await db
    .collection(
      `${Collections.clients}/${clientId}/${Collections.conversations}/${convRef.id}/${Collections.messages}`
    )
    .add({
      conversationId: convRef.id,
      contactId: convRef.contactId,
      direction: "inbound",
      type: (parsed.messageType ?? "text").toLowerCase(),
      content: cleanText,
      mediaUrl: parsed.mediaUrl ?? null,
      mediaType: parsed.messageType ?? null,
      status: "delivered",
      senderName: parsed.contactName ?? phone,
      createdAt: new Date(),
      channel: "whatsapp",
      whatsappMessageId: (body.uuid as string) || null,
    });

  // Update conversation's last message
  await db
    .doc(
      `${Collections.clients}/${clientId}/${Collections.conversations}/${convRef.id}`
    )
    .update({
      lastMessage: cleanText.length > 0 ? cleanText : "[Media]",
      lastMessageAt: new Date(),
      unreadCount: (convRef.unreadCount ?? 0) + 1,
    });

  if (tracking) {
    await upsertLeadFromTracking({
      clientId,
      contactId: convRef.contactId,
      contactName: parsed.contactName ?? phone,
      phone,
      tracking,
      message: cleanText,
    });
  }

  // Check auto-reply rules
  if (cleanText) {
    try {
      const { checkAutoReply } = await import("../auto-replies");
      const reply = await checkAutoReply(clientId, cleanText, "whatsapp");
      if (reply) {
        await db.collection(clientCol(clientId, Collections.messageQueue)).add({
          contactId: convRef.contactId,
          phone,
          channel: "whatsapp",
          content: reply.content,
          ...(reply.templateName ? { templateName: reply.templateName } : {}),
          ...(reply.mediaUrl ? { mediaUrl: reply.mediaUrl } : {}),
          status: "pending",
          retries: 0,
          source: "auto_reply",
          createdAt: new Date(),
        });
      }
    } catch (err) {
      logger.warn("[webhook] Auto-reply check failed:", err);
    }
  }
}

async function upsertLeadFromTracking(opts: {
  clientId: string;
  contactId: string;
  contactName: string;
  phone: string;
  tracking: TrackingInfo;
  message: string;
}): Promise<void> {
  const { clientId, contactId, contactName, phone, tracking, message } = opts;
  const status = tracking.clickType === "reach" ? "reach" : "click";
  const shortPhone = phone.replace(/\D/g, "").slice(-10);
  const leadsCol = db.collection(clientCol(clientId, Collections.leads));

  let existing = await leadsCol
    .where("contactId", "==", contactId)
    .where("status", "in", ["reach", "click", "register", "classStage", "freeTrust", "buy", "referRetain"])
    .limit(1)
    .get();

  if (existing.empty && shortPhone) {
    existing = await leadsCol
      .where("contactPhone", "==", shortPhone)
      .where("status", "in", ["reach", "click", "register", "classStage", "freeTrust", "buy", "referRetain"])
      .limit(1)
      .get();
  }

  const source = `landing_${tracking.clickType}`;
  const tag = `click-${tracking.clickType}`;

  if (!existing.empty) {
    const doc = existing.docs[0];
    const prevTags = Array.isArray(doc.data().tags) ? (doc.data().tags as string[]) : [];
    const tags = Array.from(new Set([...prevTags, "landing-click", tag]));
    await doc.ref.update({
      status,
      source,
      clickType: tracking.clickType,
      contactName,
      contactPhone: shortPhone || phone,
      tags,
      notes: message || doc.data().notes || "",
      trackingSource: tracking.source,
      trackingCampaign: tracking.campaign,
      updatedAt: new Date(),
    });
    return;
  }

  await leadsCol.add({
    title: `Lead: ${contactName}`,
    contactId,
    contactName,
    contactPhone: shortPhone || phone,
    source,
    status,
    clickType: tracking.clickType,
    score: 0,
    notes: message,
    tags: ["landing-click", tag],
    trackingSource: tracking.source,
    trackingCampaign: tracking.campaign,
    createdAt: new Date(),
    updatedAt: new Date(),
  });
}

/**
 * Handle inbound SMS.
 */
async function handleSMSWebhook(
  body: Record<string, unknown>,
): Promise<void> {
  const phone =
    (body.from as string) ??
    (body.mobile as string) ??
    (body.sender as string);
  if (!phone) return;

  const message =
    (body.message as string) ??
    (body.text as string) ??
    (body.body as string) ??
    "";

  const clientId = await findClientByPhone(phone);
  if (!clientId) return;

  const convRef = await findOrCreateConversation(
    clientId,
    phone,
    phone,
    "sms"
  );

  await db
    .collection(
      `${Collections.clients}/${clientId}/${Collections.conversations}/${convRef.id}/${Collections.messages}`
    )
    .add({
      conversationId: convRef.id,
      contactId: convRef.contactId,
      direction: "inbound",
      type: "text",
      content: message,
      status: "delivered",
      senderName: phone,
      createdAt: new Date(),
      channel: "sms",
    });

  await db
    .doc(
      `${Collections.clients}/${clientId}/${Collections.conversations}/${convRef.id}`
    )
    .update({
      lastMessage: message,
      lastMessageAt: new Date(),
      unreadCount: (convRef.unreadCount ?? 0) + 1,
    });
}

/**
 * Handle voice call status callback.
 */
async function handleVoiceWebhook(
  body: Record<string, unknown>,
): Promise<void> {
  const phone =
    (body.to as string) ??
    (body.mobile as string) ??
    (body.number as string);
  if (!phone) return;

  const clientId = await findClientByPhone(phone);
  if (!clientId) return;

  // Store call log
  await db
    .collection(`${Collections.clients}/${clientId}/call_logs`)
    .add({
      phone,
      direction: body.direction ?? "outbound",
      status: body.status ?? "unknown",
      duration: Number(body.duration ?? 0),
      recordingUrl: body.recordingUrl ?? null,
      startTime: body.startTime ?? null,
      endTime: body.endTime ?? null,
      createdAt: new Date(),
    });
}

/**
 * Handle delivery status report — update message_queue item AND the actual message doc.
 */
async function handleDeliveryReport(
  body: Record<string, unknown>,
): Promise<void> {
  const parsed = parseWebhook(body);
  const messageId =
    parsed.messageId ??
    (body.messageId as string) ??
    (body.request_id as string) ??
    (body.id as string);
  const newStatus =
    parsed.status ??
    (body.status as string) ??
    (body.event as string);

  if (!messageId || !newStatus) return;

  // Map MSG91 status to our status
  const statusMap: Record<string, string> = {
    sent: "sent",
    delivered: "delivered",
    read: "read",
    failed: "failed",
    rejected: "failed",
    expired: "failed",
  };
  const mappedStatus = statusMap[newStatus.toLowerCase()] ?? newStatus;

  logger.info(`handleDeliveryReport: msg91Id=${messageId}, status=${newStatus} → ${mappedStatus}`);

  const integratedNumber =
    (body.integratedNumber as string) ??
    (body.integrated_number as string);
  const receiptClientId = integratedNumber
    ? await findClientByWhatsAppNumber(integratedNumber)
    : null;
  let queueDoc;
  if (receiptClientId) {
    const candidates = await db
      .collection(clientCol(receiptClientId, Collections.messageQueue))
      .limit(500)
      .get();
    queueDoc = candidates.docs.find(
      (doc) => doc.data().msg91RequestId === messageId,
    );
  } else {
    const queueSnap = await db
      .collectionGroup(Collections.messageQueue)
      .where("msg91RequestId", "==", messageId)
      .limit(1)
      .get();
    queueDoc = queueSnap.docs[0];
  }

  if (!queueDoc) {
    logger.warn(`handleDeliveryReport: no queue doc found for msg91RequestId=${messageId}`);
    return;
  }

  const queueData = queueDoc.data();

  await queueDoc.ref.update({
    status: mappedStatus,
    [`${mappedStatus}At`]: new Date(),
  });

  // SMS fallback: if WhatsApp delivery permanently failed, try SMS
  const clientId = queueDoc.ref.parent.parent?.id;
  if (
    mappedStatus === "failed" &&
    queueData.channel === "whatsapp" &&
    !queueData.smsFallbackOf &&
    clientId
  ) {
    await triggerSmsFallback(clientId, queueData, queueDoc.id);
  }

  // Update the actual message in conversations/messages subcollection
  const conversationId = queueData.conversationId as string | undefined;
  const messageDocId = queueData.messageDocId as string | undefined;
  // Queue path: clients/{clientId}/message_queue/{id}

  if (!clientId || !conversationId) {
    logger.warn(`handleDeliveryReport: missing clientId=${clientId} or conversationId=${conversationId}`);
    return;
  }

  const messagesRef = db.collection(
    `${Collections.clients}/${clientId}/${Collections.conversations}/${conversationId}/${Collections.messages}`
  );

  let msgDocRef;
  if (messageDocId) {
    // Direct lookup by document ID (reliable)
    msgDocRef = messagesRef.doc(messageDocId);
  } else {
    // Fallback: match by content for older messages without messageDocId
    const content = queueData.content as string;
    const msgSnap = await messagesRef
      .where("direction", "==", "outbound")
      .where("content", "==", content)
      .orderBy("createdAt", "desc")
      .limit(1)
      .get();
    if (!msgSnap.empty) {
      msgDocRef = msgSnap.docs[0].ref;
    }
  }

  if (!msgDocRef) {
    logger.warn(`handleDeliveryReport: could not find message doc`);
    return;
  }

  const msgDoc = await msgDocRef.get();
  if (!msgDoc.exists) {
    logger.warn(`handleDeliveryReport: message doc ${msgDocRef.id} does not exist`);
    return;
  }

  const currentStatus = msgDoc.data()?.status ?? "queued";
  const statusOrder: Record<string, number> = {
    queued: 0, sent: 1, delivered: 2, read: 3, failed: -1,
  };

  if ((statusOrder[mappedStatus] ?? 0) > (statusOrder[currentStatus] ?? 0)) {
    await msgDocRef.update({
      status: mappedStatus,
      ...(mappedStatus === "read" ? { readAt: new Date() } : {}),
    });
    logger.info(`Updated message ${msgDocRef.id} status: ${currentStatus} → ${mappedStatus}`);
  }
}

/**
 * Find which client a phone number belongs to by searching contacts.
 */
async function findClientByPhone(
  phone: string,
): Promise<string | null> {
  // Normalize phone (strip + and spaces)
  const normalized = phone.replace(/[\s+\-()]/g, "");
  // Also try without country code (last 10 digits)
  const short = normalized.length > 10 ? normalized.slice(-10) : normalized;

  // Search within each client's contacts collection (avoids collectionGroup index)
  const clientsSnap = await db.collection(Collections.clients).get();
  for (const clientDoc of clientsSnap.docs) {
    const contactsRef = db.collection(
      `${Collections.clients}/${clientDoc.id}/${Collections.contacts}`
    );

    // Try full normalized number
    let snap = await contactsRef.where("phone", "==", normalized).limit(1).get();
    if (!snap.empty) return clientDoc.id;

    // Try short (10-digit) number
    if (short !== normalized) {
      snap = await contactsRef.where("phone", "==", short).limit(1).get();
      if (!snap.empty) return clientDoc.id;
    }
  }

  logger.info(`findClientByPhone: no client found for phone ${normalized}`);
  return null;
}

/**
 * Find which client is associated with a given WhatsApp integrated number.
 * Matches the `whatsappNumber` field on client documents.
 */
async function findClientByWhatsAppNumber(
  integratedNumber: string,
): Promise<string | null> {
  const normalized = integratedNumber.replace(/[\s+\-()]/g, "");
  const clientsSnap = await db
    .collection(Collections.clients)
    .where("whatsappNumber", "==", normalized)
    .limit(1)
    .get();

  if (!clientsSnap.empty) {
    return clientsSnap.docs[0].id;
  }

  // Try without country code prefix (last 10 digits)
  if (normalized.length > 10) {
    const short = normalized.slice(-10);
    const shortSnap = await db
      .collection(Collections.clients)
      .where("whatsappNumber", "==", short)
      .limit(1)
      .get();
    if (!shortSnap.empty) {
      return shortSnap.docs[0].id;
    }
  }

  logger.info(`findClientByWhatsAppNumber: no client found for number ${normalized}`);
  return null;
}

/**
 * Find or create a conversation for an inbound message.
 */
async function findOrCreateConversation(
  clientId: string,
  phone: string,
  contactName: string,
  channel: string,
): Promise<{ id: string; contactId: string; unreadCount: number }> {
  const convsCol = db.collection(
    `${Collections.clients}/${clientId}/${Collections.conversations}`
  );

  // Look for existing conversation with this phone + channel
  const short = phone.length > 10 ? phone.slice(-10) : phone;
  let existing = await convsCol
    .where("contactPhone", "==", phone)
    .where("channel", "==", channel)
    .limit(1)
    .get();
  if (existing.empty && short !== phone) {
    existing = await convsCol
      .where("contactPhone", "==", short)
      .where("channel", "==", channel)
      .limit(1)
      .get();
  }

  if (!existing.empty) {
    const doc = existing.docs[0];
    return {
      id: doc.id,
      contactId: doc.data().contactId ?? "",
      unreadCount: doc.data().unreadCount ?? 0,
    };
  }

  // Find contact ID — try full number, then short (10-digit)
  let contactSnap = await db
    .collection(`${Collections.clients}/${clientId}/${Collections.contacts}`)
    .where("phone", "==", phone)
    .limit(1)
    .get();
  if (contactSnap.empty && short !== phone) {
    contactSnap = await db
      .collection(`${Collections.clients}/${clientId}/${Collections.contacts}`)
      .where("phone", "==", short)
      .limit(1)
      .get();
  }

  let contactId: string;
  if (!contactSnap.empty) {
    contactId = contactSnap.docs[0].id;
  } else {
    // Auto-create contact for inbound caller
    const newContact = await db
      .collection(`${Collections.clients}/${clientId}/${Collections.contacts}`)
      .add({
        name: contactName,
        phone: short,
        source: "whatsapp_inbound",
        createdAt: new Date(),
      });
    contactId = newContact.id;
  }

  // Create new conversation
  const newConvRef = await convsCol.add({
    contactId,
    contactName,
    contactPhone: phone,
    channel,
    lastMessage: "",
    lastMessageAt: new Date(),
    unreadCount: 0,
    isActive: true,
    createdAt: new Date(),
  });

  return { id: newConvRef.id, contactId, unreadCount: 0 };
}

/**
 * Trigger SMS fallback for a failed WhatsApp message.
 * Reads client autoTrigger settings; if SMS fallback is configured, enqueues SMS.
 */
async function triggerSmsFallback(
  clientId: string,
  queueData: Record<string, unknown>,
  originalDocId: string
): Promise<void> {
  try {
    const settingsDoc = await db
      .doc(`${Collections.clients}/${clientId}/settings/autoTriggers`)
      .get();
    const settings = settingsDoc.data() ?? {};

    if (!settings.smsFallbackEnabled || !settings.smsFallbackFlowId) {
      return;
    }

    const queueRef = db.collection(clientCol(clientId, "message_queue"));
    const content = (queueData.content as string) ?? "";

    await queueRef.add({
      contactId: queueData.contactId ?? null,
      phone: queueData.phone ?? null,
      content,
      channel: "sms",
      flowId: settings.smsFallbackFlowId,
      templateName: null,
      templateParams: null,
      mediaUrl: null,
      voiceFlowId: null,
      conversationId: queueData.conversationId ?? null,
      messageDocId: null,
      status: "pending",
      createdAt: new Date(),
      createdBy: "system:sms-fallback",
      retries: 0,
      smsFallbackOf: originalDocId,
    });

    logger.info(`[smsFallback] Webhook triggered SMS fallback for doc ${originalDocId}`);
  } catch (err) {
    logger.error(`[smsFallback] Webhook fallback failed: ${err}`);
  }
}

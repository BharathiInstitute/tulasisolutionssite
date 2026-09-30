"use strict";
/**
 * Message Queue Processor — processes pending messages across all channels via MSG91.
 * Replaces the old whatsapp-queue.ts.
 */
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.onMessageQueued = exports.updateOutreachCampaignStatus = exports.enqueueMessage = exports.processMessageQueue = void 0;
const https_1 = require("firebase-functions/v2/https");
const scheduler_1 = require("firebase-functions/v2/scheduler");
const firestore_1 = require("firebase-functions/v2/firestore");
const firestore_2 = require("firebase-admin/firestore");
const logger = __importStar(require("firebase-functions/logger"));
const config_1 = require("./config");
const msg91Whatsapp = __importStar(require("./msg91/msg91-whatsapp"));
const msg91Sms = __importStar(require("./msg91/msg91-sms"));
const msg91Voice = __importStar(require("./msg91/msg91-voice"));
const utils_1 = require("./utils");
const msg91_client_1 = require("./msg91/msg91-client");
function formatFailureReason(unknownError) {
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
function outreachDayKey(date = new Date()) {
    return date.toISOString().substring(0, 10);
}
async function recordCampaignOutcome(campaignId, status) {
    if (!campaignId)
        return;
    try {
        await config_1.db.collection("outreach_campaigns").doc(campaignId).update({
            [`stats.${status}`]: firestore_2.FieldValue.increment(1),
            updatedAt: new Date(),
        });
    }
    catch (error) {
        logger.warn(`Could not update campaign ${campaignId} ${status} count`, error);
    }
}
async function campaignAllowsSending(campaignId) {
    if (!campaignId)
        return true;
    const snapshot = await config_1.db.collection("outreach_campaigns").doc(campaignId).get();
    return !["paused", "cancelled"].includes(String(snapshot.data()?.status));
}
async function leadAllowsMessaging(clientId, queueMessageRef) {
    const clientSnapshot = await config_1.db.collection(config_1.Collections.clients).doc(clientId).get();
    if (clientSnapshot.data()?.doNotContact !== true)
        return true;
    await queueMessageRef.update({
        status: "cancelled",
        error: "Lead opted out of messaging",
        cancelledAt: new Date(),
    });
    return false;
}
async function resolveEnqueueClientId(request) {
    if (!request.auth?.uid) {
        throw new https_1.HttpsError("unauthenticated", "Authentication required");
    }
    const requestedClientId = request.data.clientId?.trim();
    if (!requestedClientId) {
        return (0, config_1.getCallerClient)(request.auth);
    }
    const userSnap = await config_1.db.collection("users").doc(request.auth.uid).get();
    const userData = userSnap.data();
    const panels = Array.isArray(userData?.panels) ? userData.panels : [];
    if (userData?.isAdmin === true || panels.includes("chat")) {
        return { uid: request.auth.uid, clientId: requestedClientId };
    }
    const caller = await (0, config_1.getCallerClient)(request.auth);
    if (caller.clientId !== requestedClientId) {
        throw new https_1.HttpsError("permission-denied", "Cannot send messages for this client");
    }
    return caller;
}
async function claimPendingMessage(queueMessageRef) {
    return config_1.db.runTransaction(async (transaction) => {
        const snapshot = await transaction.get(queueMessageRef);
        if (!snapshot.exists || snapshot.data()?.status !== "pending")
            return false;
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
exports.processMessageQueue = (0, scheduler_1.onSchedule)({
    schedule: "every 30 minutes",
    region: "asia-south1",
    secrets: [config_1.msg91AuthKey, config_1.msg91WhatsAppNumber],
}, async () => {
    const pendingQuery = config_1.db.collectionGroup(config_1.Collections.messageQueue)
        .where("status", "==", "pending")
        .limit(100);
    const existingClients = new Map();
    const clientMessageCounts = new Map();
    let pendingSnap = await pendingQuery.get();
    while (!pendingSnap.empty) {
        for (const doc of pendingSnap.docs) {
            const ownerRef = doc.ref.parent.parent;
            if (!ownerRef || ownerRef.parent.path !== config_1.Collections.clients)
                continue;
            const clientId = ownerRef.id;
            const messageCount = clientMessageCounts.get(clientId) ?? 0;
            if (messageCount >= 100)
                continue;
            clientMessageCounts.set(clientId, messageCount + 1);
            const data = doc.data();
            const channel = data.channel ?? "whatsapp";
            const retries = data.retries ?? 0;
            const scheduledAt = data.scheduledAt?.toDate?.();
            if (scheduledAt && scheduledAt > new Date())
                continue;
            if (!existingClients.has(clientId)) {
                existingClients.set(clientId, (await ownerRef.get()).exists);
            }
            if (!existingClients.get(clientId))
                continue;
            if (!await campaignAllowsSending(data.campaignId))
                continue;
            if (!await leadAllowsMessaging(clientId, doc.ref))
                continue;
            if (retries >= 3) {
                await doc.ref.update({
                    status: "failed",
                    failedAt: new Date(),
                    error: "Max retries exceeded",
                });
                await config_1.db.collection(config_1.Collections.clients).doc(clientId).set({
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
            if (!await claimPendingMessage(doc.ref))
                continue;
            // Get contact phone
            let phone = data.phone;
            if (!phone && data.contactId) {
                const contactSnap = await config_1.db
                    .doc(`${(0, config_1.clientCol)(clientId, config_1.Collections.contacts)}/${data.contactId}`)
                    .get();
                phone = contactSnap.data()?.phone;
            }
            if (!phone) {
                await doc.ref.update({
                    status: "failed",
                    error: "No phone number found",
                });
                await config_1.db.collection(config_1.Collections.clients).doc(clientId).set({
                    lastSendStatus: "failed",
                    lastSendError: "No phone number found",
                    lastAttemptAt: new Date(),
                    lastCampaignId: data.campaignId ?? null,
                }, { merge: true });
                await recordCampaignOutcome(data.campaignId, "failed");
                continue;
            }
            const normalizedPhone = (0, utils_1.normalizePhone)(phone);
            try {
                logger.info(`Sending ${channel} message to ${normalizedPhone} (raw: ${phone})`, { docId: doc.id, content: data.content?.substring(0, 50) });
                // Get this client's WhatsApp number (per-client or global fallback)
                let clientWaNumber;
                if (channel === "whatsapp") {
                    try {
                        clientWaNumber = await (0, msg91_client_1.getClientWhatsAppNumber)(clientId);
                    }
                    catch (e) {
                        logger.warn(`Could not get WA number for client ${clientId}, using global`, e);
                    }
                }
                let msg91RequestId;
                if (channel === "whatsapp") {
                    // Normalize templateParams (may be Map or Array)
                    let bodyParams = data.templateParams;
                    if (bodyParams && !Array.isArray(bodyParams)) {
                        const obj = bodyParams;
                        bodyParams = Object.keys(obj)
                            .sort((a, b) => parseInt(a) - parseInt(b))
                            .map((k) => ({ type: "text", value: obj[k] }));
                    }
                    // Safety net: replace empty/null param values so MSG91 never gets blanks.
                    if (Array.isArray(bodyParams) && bodyParams.length > 0) {
                        let contactName;
                        if (data.contactId) {
                            try {
                                const cSnap = await config_1.db
                                    .doc(`${(0, config_1.clientCol)(clientId, config_1.Collections.contacts)}/${data.contactId}`)
                                    .get();
                                contactName = cSnap.data()?.name;
                            }
                            catch (_) { /* ignore */ }
                        }
                        bodyParams = bodyParams.map((p, i) => {
                            const v = (p?.value ?? "").toString().trim();
                            if (v.length > 0 && v !== "—")
                                return p;
                            const fallback = i === 0 && contactName ? contactName : "-";
                            logger.warn(`[queue] empty templateParam[${i}], filling with "${fallback}"`);
                            return { type: "text", value: fallback };
                        });
                    }
                    // Look up template language (te/hi/en etc.) from Firestore
                    let templateLanguage;
                    if (data.templateName) {
                        try {
                            const tSnap = await config_1.db
                                .collection((0, config_1.clientCol)(clientId, config_1.Collections.templates))
                                .where("name", "==", data.templateName).limit(1).get();
                            templateLanguage = tSnap.empty ? undefined : tSnap.docs[0].data().language;
                        }
                        catch (_) { /* ignore, defaults to 'en' */ }
                    }
                    let result;
                    if (data.templateName) {
                        result = await msg91Whatsapp.sendWhatsAppMessage({
                            to: normalizedPhone,
                            templateName: data.templateName,
                            language: templateLanguage,
                            bodyParams: bodyParams,
                            headerParams: data.templateHeaderImageUrl
                                ? [{ type: "image", value: data.templateHeaderImageUrl }]
                                : undefined,
                            buttonParams: data.templateButtonParams,
                            integratedNumber: clientWaNumber,
                        });
                    }
                    else if (data.mediaUrl) {
                        result = await msg91Whatsapp.sendWhatsAppMedia({
                            to: normalizedPhone,
                            mediaUrl: data.mediaUrl,
                            caption: data.content,
                            integratedNumber: clientWaNumber,
                            mediaType: data.mediaType,
                        });
                    }
                    else {
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
                }
                else if (channel === "sms") {
                    const flowId = data.flowId;
                    if (!flowId)
                        throw new Error("flowId required for SMS");
                    await msg91Sms.sendSMS(flowId, [
                        { mobile: normalizedPhone, VAR1: data.content },
                    ]);
                }
                else if (channel === "voice") {
                    const voiceFlowId = data.voiceFlowId;
                    if (!voiceFlowId)
                        throw new Error("voiceFlowId required for voice");
                    await msg91Voice.makeVoiceCall(normalizedPhone, voiceFlowId);
                }
                const sentAt = new Date();
                await doc.ref.update({
                    status: "sent",
                    sentAt,
                    lastError: firestore_2.FieldValue.delete(),
                    error: firestore_2.FieldValue.delete(),
                    ...(msg91RequestId ? { msg91RequestId } : {}),
                });
                const conversationId = data.conversationId;
                if (conversationId) {
                    await config_1.db.doc(`${(0, config_1.clientCol)(clientId, config_1.Collections.conversations)}/${conversationId}`).set({
                        lastMessage: String(data.content ?? ""),
                        lastMessageAt: sentAt,
                        lastMessageDirection: "outbound",
                    }, { merge: true });
                }
                const clientRef = config_1.db.collection(config_1.Collections.clients).doc(clientId);
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
            }
            catch (err) {
                const failureReason = formatFailureReason(err);
                await doc.ref.update({
                    status: "pending",
                    retries: retries + 1,
                    lastError: failureReason,
                });
                await config_1.db.collection(config_1.Collections.clients).doc(clientId).set({
                    lastSendStatus: "retrying",
                    lastSendError: failureReason,
                    lastAttemptAt: new Date(),
                    lastCampaignId: data.campaignId ?? null,
                }, { merge: true });
            }
        }
        if (pendingSnap.size < 100)
            break;
        pendingSnap = await pendingQuery
            .startAfter(pendingSnap.docs[pendingSnap.docs.length - 1])
            .get();
    }
});
/**
 * Enqueue a single message for sending via any channel.
 */
exports.enqueueMessage = (0, https_1.onCall)(config_1.callableOptions, async (request) => {
    const { uid, clientId } = await resolveEnqueueClientId(request);
    const { contactId, content, channel, mediaUrl, mediaType, templateName, flowId, voiceFlowId } = request.data;
    // Normalize templateParams: accept Map<string,string> from Flutter or Array<{type,value}>
    let templateParams = request.data.templateParams;
    logger.info(`enqueueMessage: channel=${channel ?? "whatsapp"} templateName=${templateName ?? "null"} content="${(content ?? "").substring(0, 60)}" templateParams=${JSON.stringify(templateParams)}`);
    if (templateParams && !Array.isArray(templateParams)) {
        // Convert {1: "val1", 2: "val2"} to [{type:"text",value:"val1"},{type:"text",value:"val2"}]
        const obj = templateParams;
        templateParams = Object.keys(obj)
            .sort((a, b) => parseInt(a) - parseInt(b))
            .map((k) => ({ type: "text", value: obj[k] }));
        logger.info(`enqueueMessage: normalized templateParams=${JSON.stringify(templateParams)}`);
    }
    const templateButtonParams = Object.entries(request.data.templateButtonParams ?? {})
        .sort(([left], [right]) => Number(left) - Number(right))
        .map(([index, value]) => ({ index: Number(index), value: value.trim() }));
    if (templateName && !/^[a-z0-9_]+$/.test(templateName)) {
        throw new https_1.HttpsError("invalid-argument", "Invalid WhatsApp template name");
    }
    if (templateParams?.some((param) => !param.value?.trim())) {
        throw new https_1.HttpsError("invalid-argument", "WhatsApp template variables cannot be blank");
    }
    if (templateButtonParams.some((param) => !Number.isInteger(param.index) || param.index < 0 || !param.value)) {
        throw new https_1.HttpsError("invalid-argument", "WhatsApp button variables require a zero-based button index and non-blank value");
    }
    const normalizedContent = (content ?? "").trim();
    if (!normalizedContent && !mediaUrl && !templateName) {
        throw new https_1.HttpsError("invalid-argument", "content is required for non-media messages");
    }
    // Get contact phone — try contactId first, then fall back to conversation phone
    let phone;
    if (contactId) {
        const contactSnap = await config_1.db
            .doc(`${(0, config_1.clientCol)(clientId, config_1.Collections.contacts)}/${contactId}`)
            .get();
        phone = contactSnap.data()?.phone;
    }
    // If no phone from contact, try to get from the conversation
    if (!phone && request.data.conversationId) {
        const convSnap = await config_1.db
            .doc(`${(0, config_1.clientCol)(clientId, config_1.Collections.conversations)}/${request.data.conversationId}`)
            .get();
        phone = convSnap.data()?.contactPhone;
    }
    if (!phone) {
        throw new https_1.HttpsError("not-found", "Contact phone number not found");
    }
    const clientRef = config_1.db.collection(config_1.Collections.clients).doc(clientId);
    const clientSnapshot = await clientRef.get();
    if (clientSnapshot.data()?.doNotContact === true) {
        throw new https_1.HttpsError("failed-precondition", "This lead has opted out of messaging");
    }
    const queueRef = config_1.db.collection((0, config_1.clientCol)(clientId, config_1.Collections.messageQueue));
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
    let docRef;
    if (request.data.campaignId) {
        const campaignId = request.data.campaignId;
        docRef = queueRef.doc(`${campaignId}_${contactId}`);
        const campaignRef = config_1.db.collection("outreach_campaigns").doc(campaignId);
        const usageRef = config_1.db.collection("outreach_daily_usage").doc(outreachDayKey());
        const settingsSnapshot = await config_1.db.doc("system_settings/outreach").get();
        const dailyLimit = Math.max(1, Number(settingsSnapshot.data()?.dailyLimit ?? DEFAULT_DAILY_OUTREACH_LIMIT));
        let duplicate = false;
        await config_1.db.runTransaction(async (transaction) => {
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
                throw new https_1.HttpsError("resource-exhausted", `Daily outreach limit of ${dailyLimit} reached`);
            }
            transaction.set(docRef, queueData);
            transaction.set(usageRef, {
                count: firestore_2.FieldValue.increment(1),
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
                    queued: firestore_2.FieldValue.increment(1),
                    sent: firestore_2.FieldValue.increment(0),
                    delivered: firestore_2.FieldValue.increment(0),
                    read: firestore_2.FieldValue.increment(0),
                    failed: firestore_2.FieldValue.increment(0),
                },
            }, { merge: true });
        });
        if (duplicate) {
            return { success: true, messageId: docRef.id, duplicate: true };
        }
    }
    else {
        docRef = await queueRef.add(queueData);
    }
    await config_1.db.collection(config_1.Collections.clients).doc(clientId).set({
        lastSendStatus: "pending",
        lastSendError: null,
        lastAttemptAt: new Date(),
        sendAttemptCount: firestore_2.FieldValue.increment(1),
        lastCampaignId: request.data.campaignId ?? null,
    }, { merge: true });
    logger.info(`enqueueMessage: queued doc ${docRef.id} for ${phone} channel=${channel ?? "whatsapp"} templateName=${templateName ?? "null"}`);
    return { success: true, messageId: docRef.id };
});
exports.updateOutreachCampaignStatus = (0, https_1.onCall)(config_1.callableOptions, async (request) => {
    if (!request.auth?.uid) {
        throw new https_1.HttpsError("unauthenticated", "Authentication required");
    }
    const campaignId = request.data.campaignId?.trim();
    const status = request.data.status?.trim();
    if (!campaignId || !["running", "paused", "cancelled", "completed"].includes(status ?? "")) {
        throw new https_1.HttpsError("invalid-argument", "A valid campaign and status are required");
    }
    const campaignRef = config_1.db.collection("outreach_campaigns").doc(campaignId);
    const snapshot = await campaignRef.get();
    if (!snapshot.exists || snapshot.data()?.createdBy !== request.auth.uid) {
        throw new https_1.HttpsError("permission-denied", "Campaign not found");
    }
    await campaignRef.update({ status, updatedAt: new Date() });
    return { success: true };
});
/**
 * Real-time trigger — sends message immediately when added to queue.
 * Fires on document creation in any client's message_queue subcollection.
 */
exports.onMessageQueued = (0, firestore_1.onDocumentCreated)({
    document: "clients/{clientId}/message_queue/{messageId}",
    region: "asia-south1",
    secrets: [config_1.msg91AuthKey, config_1.msg91WhatsAppNumber],
}, async (event) => {
    const snap = event.data;
    if (!snap)
        return;
    const data = snap.data();
    if (data.status !== "pending")
        return;
    const scheduledAt = data.scheduledAt?.toDate?.();
    if (scheduledAt && scheduledAt > new Date())
        return;
    const clientId = event.params.clientId;
    const channel = data.channel ?? "whatsapp";
    const retries = data.retries ?? 0;
    if (!await campaignAllowsSending(data.campaignId))
        return;
    if (!await leadAllowsMessaging(clientId, snap.ref))
        return;
    let phone = data.phone;
    if (!phone && data.contactId) {
        const contactSnap = await config_1.db
            .doc(`${(0, config_1.clientCol)(clientId, config_1.Collections.contacts)}/${data.contactId}`)
            .get();
        phone = contactSnap.data()?.phone;
    }
    if (!phone) {
        await snap.ref.update({ status: "failed", error: "No phone number found" });
        return;
    }
    const normalizedPhone = (0, utils_1.normalizePhone)(phone);
    try {
        if (!await claimPendingMessage(snap.ref))
            return;
        logger.info(`[realtime] Sending ${channel} message to ${normalizedPhone} (raw: ${phone}) templateName=${data.templateName ?? "null"} templateParams=${JSON.stringify(data.templateParams)}`);
        // Get this client's WhatsApp number (per-client or global fallback)
        let clientWaNumber;
        if (channel === "whatsapp") {
            try {
                clientWaNumber = await (0, msg91_client_1.getClientWhatsAppNumber)(clientId);
            }
            catch (e) {
                logger.warn(`[realtime] Could not get WA number for client ${clientId}, using global`, e);
            }
        }
        let msg91RequestId;
        if (channel === "whatsapp") {
            // Normalize templateParams from Firestore doc (may be Map or Array)
            let bodyParams = data.templateParams;
            if (bodyParams && !Array.isArray(bodyParams)) {
                const obj = bodyParams;
                bodyParams = Object.keys(obj)
                    .sort((a, b) => parseInt(a) - parseInt(b))
                    .map((k) => ({ type: "text", value: obj[k] }));
            }
            // Safety net: replace any empty/null param values so MSG91 never gets
            // blanks (which silently render as missing variables in the message).
            // Param at index 0 ({{1}}) defaults to the contact's name if known,
            // remaining params default to "-".
            if (Array.isArray(bodyParams) && bodyParams.length > 0) {
                let contactName;
                if (data.contactId) {
                    try {
                        const contactSnap = await config_1.db
                            .doc(`${(0, config_1.clientCol)(clientId, config_1.Collections.contacts)}/${data.contactId}`)
                            .get();
                        contactName = contactSnap.data()?.name;
                    }
                    catch (_) {
                        // ignore — fall back to "-"
                    }
                }
                bodyParams = bodyParams.map((p, i) => {
                    const v = (p?.value ?? "").toString().trim();
                    if (v.length > 0 && v !== "—")
                        return p;
                    const fallback = i === 0 && contactName ? contactName : "-";
                    logger.warn(`[realtime] empty templateParam at index ${i}, filling with "${fallback}"`);
                    return { type: "text", value: fallback };
                });
            }
            // Look up template language from Firestore
            let templateLanguage;
            if (data.templateName) {
                try {
                    const tSnap = await config_1.db
                        .collection((0, config_1.clientCol)(clientId, config_1.Collections.templates))
                        .where("name", "==", data.templateName).limit(1).get();
                    templateLanguage = tSnap.empty ? undefined : tSnap.docs[0].data().language;
                }
                catch (_) { /* ignore, defaults to 'en' */ }
            }
            let result;
            if (data.templateName) {
                result = await msg91Whatsapp.sendWhatsAppMessage({
                    to: normalizedPhone,
                    templateName: data.templateName,
                    language: templateLanguage,
                    bodyParams: bodyParams,
                    headerParams: data.templateHeaderImageUrl
                        ? [{ type: "image", value: data.templateHeaderImageUrl }]
                        : undefined,
                    buttonParams: data.templateButtonParams,
                    integratedNumber: clientWaNumber,
                });
            }
            else if (data.mediaUrl) {
                result = await msg91Whatsapp.sendWhatsAppMedia({
                    to: normalizedPhone,
                    mediaUrl: data.mediaUrl,
                    caption: data.content,
                    mediaType: data.mediaType,
                    integratedNumber: clientWaNumber,
                });
            }
            else {
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
        }
        else if (channel === "sms") {
            if (!data.flowId)
                throw new Error("flowId required for SMS");
            await msg91Sms.sendSMS(data.flowId, [
                { mobile: normalizedPhone, VAR1: data.content },
            ]);
        }
        else if (channel === "voice") {
            if (!data.voiceFlowId)
                throw new Error("voiceFlowId required for voice");
            await msg91Voice.makeVoiceCall(normalizedPhone, data.voiceFlowId);
        }
        const sentAt = new Date();
        await snap.ref.update({
            status: "sent",
            sentAt,
            lastError: firestore_2.FieldValue.delete(),
            error: firestore_2.FieldValue.delete(),
            ...(msg91RequestId ? { msg91RequestId } : {}),
        });
        // Also update the actual message doc in the messages subcollection
        const conversationId = data.conversationId;
        const messageDocId = data.messageDocId;
        if (conversationId) {
            await config_1.db.doc(`${(0, config_1.clientCol)(clientId, config_1.Collections.conversations)}/${conversationId}`).set({
                lastMessage: String(data.content ?? ""),
                lastMessageAt: sentAt,
                lastMessageDirection: "outbound",
            }, { merge: true });
        }
        if (conversationId && messageDocId) {
            try {
                await config_1.db
                    .doc(`${(0, config_1.clientCol)(clientId, config_1.Collections.conversations)}/${conversationId}/${config_1.Collections.messages}/${messageDocId}`)
                    .update({
                    status: "sent",
                    failureReason: firestore_2.FieldValue.delete(),
                });
                logger.info(`[realtime] Updated message doc ${messageDocId} status to sent`);
            }
            catch (msgErr) {
                logger.warn(`[realtime] Failed to update message doc: ${msgErr}`);
            }
        }
        const clientRef = config_1.db.collection(config_1.Collections.clients).doc(clientId);
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
    }
    catch (err) {
        logger.error(`[realtime] Send failed for ${normalizedPhone}:`, err);
        const failureReason = formatFailureReason(err);
        // Update message doc to failed status
        const conversationId = data.conversationId;
        const messageDocId = data.messageDocId;
        if (conversationId && messageDocId) {
            try {
                await config_1.db
                    .doc(`${(0, config_1.clientCol)(clientId, config_1.Collections.conversations)}/${conversationId}/${config_1.Collections.messages}/${messageDocId}`)
                    .update({ status: "failed", failureReason });
            }
            catch (_) { /* ignore */ }
        }
        await snap.ref.update({
            status: "pending",
            retries: retries + 1,
            lastError: failureReason,
        });
        await config_1.db.collection(config_1.Collections.clients).doc(clientId).set({
            lastSendStatus: "retrying",
            lastSendError: failureReason,
            lastAttemptAt: new Date(),
            lastCampaignId: data.campaignId ?? null,
        }, { merge: true });
    }
});
/**
 * Attempt SMS fallback for a failed WhatsApp message.
 * Reads the client's autoTrigger settings; if smsFallbackEnabled + smsFallbackFlowId
 * are configured, enqueues a new SMS message with the same content.
 */
async function attemptSmsFallback(clientId, originalData, originalDocId) {
    try {
        // Check autoTrigger settings for SMS fallback config
        const settingsDoc = await config_1.db
            .doc(`${config_1.Collections.clients}/${clientId}/settings/autoTriggers`)
            .get();
        const settings = settingsDoc.data() ?? {};
        if (!settings.smsFallbackEnabled || !settings.smsFallbackFlowId) {
            logger.info(`[smsFallback] Not enabled for client ${clientId}`);
            return;
        }
        const queueRef = config_1.db.collection((0, config_1.clientCol)(clientId, config_1.Collections.messageQueue));
        const content = originalData.content ?? "";
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
    }
    catch (err) {
        logger.error(`[smsFallback] Failed to enqueue SMS fallback: ${err}`);
    }
}
//# sourceMappingURL=message-queue.js.map
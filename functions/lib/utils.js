"use strict";
/**
 * Shared utilities for Cloud Functions.
 * - normalizePhone: consistent phone format (91XXXXXXXXXX) everywhere
 * - logOutboundMessage: log every outbound WhatsApp message into the contact's conversation
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
exports.normalizePhone = normalizePhone;
exports.phoneToTenDigits = phoneToTenDigits;
exports.logOutboundMessage = logOutboundMessage;
exports.findContactByPhone = findContactByPhone;
const logger = __importStar(require("firebase-functions/logger"));
const config_1 = require("./config");
// ── Phone Normalization ──────────────────────────────────────────
// Always returns 12-digit format: 91XXXXXXXXXX
// Input can be: +91 9876543210, 919876543210, 9876543210, etc.
function normalizePhone(raw) {
    const digits = String(raw).replace(/\D/g, "");
    if (digits.length === 12 && digits.startsWith("91"))
        return digits;
    if (digits.length === 10)
        return `91${digits}`;
    // If 11 digits starting with 0 (e.g. 09876543210), strip leading 0
    if (digits.length === 11 && digits.startsWith("0"))
        return `91${digits.slice(1)}`;
    return digits;
}
// Extract last 10 digits for Firestore contact lookup (contacts stored as 10-digit)
function phoneToTenDigits(raw) {
    const digits = String(raw).replace(/\D/g, "");
    return digits.slice(-10);
}
// ── Outbound Message Logging ─────────────────────────────────────
// Logs an outbound message into the contact's conversation so it shows in Chat.
async function logOutboundMessage(opts) {
    const { clientId, contactId, content, channel, templateName, classSessionId, broadcastId } = opts;
    // Find or create conversation for this contact
    const convsCol = config_1.db.collection((0, config_1.clientCol)(clientId, config_1.Collections.conversations));
    let convId;
    const existingConv = await convsCol
        .where("contactId", "==", contactId)
        .limit(1)
        .get();
    if (!existingConv.empty) {
        convId = existingConv.docs[0].id;
    }
    else {
        // Look up contact name for conversation creation
        const contactSnap = await config_1.db
            .doc(`${(0, config_1.clientCol)(clientId, config_1.Collections.contacts)}/${contactId}`)
            .get();
        const contactData = contactSnap.data();
        const convRef = await convsCol.add({
            contactId,
            contactName: contactData?.name ?? "Unknown",
            contactPhone: contactData?.phone ?? "",
            channel: channel ?? "whatsapp",
            lastMessageAt: new Date(),
            lastMessage: content.substring(0, 100),
            unreadCount: 0,
            status: "active",
            createdAt: new Date(),
        });
        convId = convRef.id;
    }
    // Add message to conversation
    const msgRef = await config_1.db
        .collection(`${(0, config_1.clientCol)(clientId, config_1.Collections.conversations)}/${convId}/messages`)
        .add({
        contactId,
        conversationId: convId,
        direction: "outbound",
        channel: channel ?? "whatsapp",
        content,
        status: "sent",
        templateName: templateName ?? null,
        classSessionId: classSessionId ?? null,
        broadcastId: broadcastId ?? null,
        sentAt: new Date(),
        createdAt: new Date(),
    });
    // Update conversation's last message
    await convsCol.doc(convId).update({
        lastMessageAt: new Date(),
        lastMessage: content.substring(0, 100),
    });
    logger.info(`[logOutboundMessage] Logged msg ${msgRef.id} in conv ${convId} for contact ${contactId}`);
    return msgRef.id;
}
// ── Find Contact by Phone ────────────────────────────────────────
// Returns contactId for a phone number, or null if not found.
async function findContactByPhone(clientId, phone) {
    const tenDigit = phoneToTenDigits(phone);
    const contactsCol = config_1.db.collection((0, config_1.clientCol)(clientId, config_1.Collections.contacts));
    // Try 10-digit first (how registerForClass stores it)
    let snap = await contactsCol.where("phone", "==", tenDigit).limit(1).get();
    if (!snap.empty)
        return snap.docs[0].id;
    // Try 12-digit (91XXXXXXXXXX)
    const twelveDigit = normalizePhone(phone);
    snap = await contactsCol.where("phone", "==", twelveDigit).limit(1).get();
    if (!snap.empty)
        return snap.docs[0].id;
    return null;
}
//# sourceMappingURL=utils.js.map
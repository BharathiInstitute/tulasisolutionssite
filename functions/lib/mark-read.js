"use strict";
/**
 * Mark Conversation Read — sends read receipts to WhatsApp for unread inbound messages.
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
exports.markConversationRead = void 0;
const https_1 = require("firebase-functions/v2/https");
const logger = __importStar(require("firebase-functions/logger"));
const config_1 = require("./config");
const msg91_whatsapp_1 = require("./msg91/msg91-whatsapp");
/**
 * Called when a user opens a conversation in the app.
 * Sends read receipts to WhatsApp for all unread inbound messages
 * and resets the conversation's unread count.
 */
exports.markConversationRead = (0, https_1.onCall)(config_1.callableOptions, async (request) => {
    const { clientId } = await (0, config_1.getCallerClient)(request.auth);
    const { conversationId } = request.data;
    if (!conversationId) {
        return { success: false, error: "conversationId is required" };
    }
    try {
        // Get conversation doc to find the customer phone number
        const convPath = `${(0, config_1.clientCol)(clientId, config_1.Collections.conversations)}/${conversationId}`;
        const convDoc = await config_1.db.doc(convPath).get();
        const convData = convDoc.data();
        const contactPhone = convData?.contactPhone;
        // Reset unread count on the conversation
        await config_1.db.doc(convPath).update({ unreadCount: 0 });
        if (!contactPhone) {
            logger.warn("markConversationRead: no contactPhone on conversation");
            return { success: true, readCount: 0 };
        }
        // Find unread inbound messages with whatsappMessageId
        const messagesRef = config_1.db.collection(`${convPath}/${config_1.Collections.messages}`);
        const unreadSnap = await messagesRef
            .where("direction", "==", "inbound")
            .where("status", "==", "delivered")
            .where("whatsappMessageId", "!=", null)
            .limit(50)
            .get();
        if (unreadSnap.empty) {
            return { success: true, readCount: 0 };
        }
        logger.info(`markConversationRead: ${unreadSnap.size} unread msgs, phone=${contactPhone}`);
        let readCount = 0;
        for (const doc of unreadSnap.docs) {
            const data = doc.data();
            const waMessageId = data.whatsappMessageId;
            let apiSuccess = false;
            if (waMessageId) {
                const result = await (0, msg91_whatsapp_1.sendReadReceipt)(waMessageId, contactPhone);
                apiSuccess = result.success;
                if (apiSuccess) {
                    readCount++;
                }
            }
            // Only mark as read in Firestore if the API call succeeded
            if (apiSuccess) {
                await doc.ref.update({
                    status: "read",
                    readAt: new Date(),
                });
            }
        }
        logger.info(`markConversationRead: sent ${readCount} read receipts`);
        return { success: true, readCount };
    }
    catch (err) {
        logger.error("markConversationRead error:", err);
        return { success: false, error: String(err) };
    }
});
//# sourceMappingURL=mark-read.js.map
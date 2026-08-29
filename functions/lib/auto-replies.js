"use strict";
/**
 * Auto-Reply Workflows
 *
 * Keyword-based automatic responses for WhatsApp/SMS inbound messages.
 *
 * Data model (Firestore):
 *   clients/{clientId}/autoReplies/{ruleId}
 *     - keywords: string[] (triggers)
 *     - matchType: "exact" | "contains" | "startsWith"
 *     - channel: "whatsapp" | "sms" | "all"
 *     - response: { content, templateName?, mediaUrl? }
 *     - enabled: boolean
 *     - priority: number (lower = higher priority)
 *
 * Called from the webhook handler when an inbound message arrives.
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
exports.getAutoReplies = exports.deleteAutoReply = exports.updateAutoReply = exports.createAutoReply = void 0;
exports.checkAutoReply = checkAutoReply;
const https_1 = require("firebase-functions/v2/https");
const logger = __importStar(require("firebase-functions/logger"));
const config_1 = require("./config");
// ── Callable: Create auto-reply rule ───────────────────────
exports.createAutoReply = (0, https_1.onCall)(config_1.callableOptions, async (request) => {
    const { clientId } = await (0, config_1.getCallerClient)(request.auth);
    const { keywords, matchType, channel, response, priority } = request.data;
    if (!keywords || keywords.length === 0 || !response?.content) {
        throw new https_1.HttpsError("invalid-argument", "keywords and response.content required");
    }
    const ref = await config_1.db.collection((0, config_1.clientCol)(clientId, config_1.Collections.autoReplies)).add({
        keywords: keywords.map((k) => k.toLowerCase().trim()),
        matchType: matchType || "contains",
        channel: channel || "all",
        response,
        enabled: true,
        priority: priority ?? 10,
        createdAt: new Date(),
        updatedAt: new Date(),
    });
    return { success: true, ruleId: ref.id };
});
// ── Callable: Update auto-reply rule ───────────────────────
exports.updateAutoReply = (0, https_1.onCall)(config_1.callableOptions, async (request) => {
    const { clientId } = await (0, config_1.getCallerClient)(request.auth);
    const { ruleId, updates } = request.data;
    if (!ruleId)
        throw new https_1.HttpsError("invalid-argument", "ruleId required");
    const ref = config_1.db.doc(`${(0, config_1.clientCol)(clientId, config_1.Collections.autoReplies)}/${ruleId}`);
    const snap = await ref.get();
    if (!snap.exists)
        throw new https_1.HttpsError("not-found", "Rule not found");
    await ref.update({ ...updates, updatedAt: new Date() });
    return { success: true };
});
// ── Callable: Delete auto-reply rule ───────────────────────
exports.deleteAutoReply = (0, https_1.onCall)(config_1.callableOptions, async (request) => {
    const { clientId } = await (0, config_1.getCallerClient)(request.auth);
    const { ruleId } = request.data;
    if (!ruleId)
        throw new https_1.HttpsError("invalid-argument", "ruleId required");
    await config_1.db.doc(`${(0, config_1.clientCol)(clientId, config_1.Collections.autoReplies)}/${ruleId}`).delete();
    return { success: true };
});
// ── Callable: List auto-reply rules ────────────────────────
exports.getAutoReplies = (0, https_1.onCall)(config_1.callableOptions, async (request) => {
    const { clientId } = await (0, config_1.getCallerClient)(request.auth);
    const snap = await config_1.db
        .collection((0, config_1.clientCol)(clientId, config_1.Collections.autoReplies))
        .orderBy("priority", "asc")
        .get();
    const rules = snap.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
    return { rules };
});
// ── Core: Check inbound message against auto-reply rules ───
/**
 * Called from msg91-webhook.ts when an inbound message arrives.
 * Returns the reply content if a rule matches, or null.
 */
async function checkAutoReply(clientId, inboundText, channel) {
    if (!inboundText || inboundText.trim().length === 0)
        return null;
    const normalizedText = inboundText.toLowerCase().trim();
    const snap = await config_1.db
        .collection((0, config_1.clientCol)(clientId, config_1.Collections.autoReplies))
        .where("enabled", "==", true)
        .orderBy("priority", "asc")
        .get();
    for (const doc of snap.docs) {
        const rule = doc.data();
        // Channel filter
        if (rule.channel !== "all" && rule.channel !== channel)
            continue;
        // Keyword matching
        const matched = rule.keywords.some((keyword) => {
            switch (rule.matchType) {
                case "exact":
                    return normalizedText === keyword;
                case "startsWith":
                    return normalizedText.startsWith(keyword);
                case "contains":
                default:
                    return normalizedText.includes(keyword);
            }
        });
        if (matched) {
            logger.info(`[autoReply] Matched rule ${doc.id} for text "${normalizedText.substring(0, 50)}"`);
            return {
                content: rule.response.content,
                templateName: rule.response.templateName,
                mediaUrl: rule.response.mediaUrl,
            };
        }
    }
    return null;
}
//# sourceMappingURL=auto-replies.js.map
"use strict";
/**
 * MSG91 WhatsApp API Wrapper
 * Handles all WhatsApp message sending via MSG91's official BSP APIs.
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
exports.sendWhatsAppMessage = sendWhatsAppMessage;
exports.sendWhatsAppText = sendWhatsAppText;
exports.sendWhatsAppMedia = sendWhatsAppMedia;
exports.listTemplates = listTemplates;
exports.submitTemplateForApproval = submitTemplateForApproval;
exports.getTemplateStatus = getTemplateStatus;
exports.sendReadReceipt = sendReadReceipt;
exports.parseWebhook = parseWebhook;
const msg91_client_1 = require("./msg91-client");
const logger = __importStar(require("firebase-functions/logger"));
function readTemplateBody(template, language) {
    const candidates = [
        language.body,
        language.content,
        language.message,
        language.template,
        template.body,
        template.content,
        template.message,
        template.template,
    ];
    for (const candidate of candidates) {
        if (typeof candidate === "string" && candidate.trim())
            return candidate.trim();
    }
    const components = language.components ?? template.components;
    if (Array.isArray(components)) {
        const body = components.find((component) => {
            const item = component;
            return String(item.type ?? "").toLowerCase() === "body";
        });
        const text = body?.text;
        if (typeof text === "string" && text.trim())
            return text.trim();
    }
    const code = language.code ?? template.code;
    if (Array.isArray(code)) {
        const body = code.find((component) => {
            const item = component;
            return String(item.type ?? "").toLowerCase() === "body";
        });
        const text = body?.text;
        if (typeof text === "string" && text.trim())
            return text.trim();
    }
    return undefined;
}
// ── Send Template Message (outbound, outside 24hr window) ────
async function sendWhatsAppMessage(msg) {
    const integratedNumber = msg.integratedNumber ?? (0, msg91_client_1.getWhatsAppIntegratedNumber)();
    const components = [];
    if (msg.bodyParams && msg.bodyParams.length > 0) {
        components.push({
            type: "body",
            parameters: msg.bodyParams.map((p) => ({
                type: p.type,
                [p.type]: p.type === "text" ? p.value : { link: p.value },
            })),
        });
    }
    if (msg.headerParams && msg.headerParams.length > 0) {
        components.push({
            type: "header",
            parameters: msg.headerParams.map((p) => ({
                type: p.type,
                [p.type]: p.type === "text" ? p.value : { link: p.value },
            })),
        });
    }
    const payload = {
        integrated_number: integratedNumber,
        content_type: "template",
        payload: {
            messaging_product: "whatsapp",
            to: msg.to,
            type: "template",
            template: {
                name: msg.templateName,
                language: { code: msg.language ?? "en" },
                components,
            },
        },
    };
    logger.info("sendWhatsAppMessage payload:", JSON.stringify(payload));
    const result = await (0, msg91_client_1.sendRequest)(`${msg91_client_1.MSG91_WA_URL}/whatsapp-outbound-message/`, payload);
    logger.info("sendWhatsAppMessage response:", JSON.stringify(result));
    return {
        success: result.status === "success" || result.hasError === false,
        requestId: result.data?.message_uuid,
    };
}
// ── Send Session Message (free-form text within 24hr window) ──
async function sendWhatsAppText(msg) {
    const integratedNumber = msg.integratedNumber ?? (0, msg91_client_1.getWhatsAppIntegratedNumber)();
    const payload = {
        integrated_number: integratedNumber,
        content_type: "text",
        recipient_number: msg.to,
        type: "text",
        text: msg.text,
    };
    logger.info("sendWhatsAppText payload:", JSON.stringify(payload));
    const result = await (0, msg91_client_1.sendRequest)(`${msg91_client_1.MSG91_WA_URL}/whatsapp-outbound-message/`, payload);
    logger.info("sendWhatsAppText response:", JSON.stringify(result));
    return {
        success: result.status === "success" || result.message === "Sent successfully",
        requestId: result.data?.message_uuid,
    };
}
// ── Send Media Message ───────────────────────────────────────
async function sendWhatsAppMedia(msg) {
    const integratedNumber = msg.integratedNumber ?? (0, msg91_client_1.getWhatsAppIntegratedNumber)();
    const mediaType = msg.mediaType ?? "image";
    const mediaPayload = mediaType === "audio" || mediaType === "sticker"
        ? { link: msg.mediaUrl }
        : { link: msg.mediaUrl, caption: msg.caption };
    const payload = {
        integrated_number: integratedNumber,
        content_type: mediaType,
        recipient_number: msg.to,
        type: mediaType,
        [mediaType]: mediaPayload,
    };
    const result = await (0, msg91_client_1.sendRequest)(`${msg91_client_1.MSG91_WA_URL}/whatsapp-outbound-message/`, payload);
    return {
        success: result.status === "success" || result.message === "Sent successfully",
        requestId: result.data?.message_uuid,
    };
}
// ── List Templates ───────────────────────────────────────────
async function listTemplates(overrideNumber) {
    const integratedNumber = overrideNumber ?? (0, msg91_client_1.getWhatsAppIntegratedNumber)();
    const result = await (0, msg91_client_1.sendRequest)(`${msg91_client_1.MSG91_BASE_URL}/whatsapp/get-template-client/${integratedNumber}`, undefined, "GET");
    logger.info("MSG91 listTemplates response:", JSON.stringify(result));
    const raw = result.templates ?? result.data;
    const templates = (Array.isArray(raw) ? raw : []);
    return templates.flatMap((template) => {
        const languages = Array.isArray(template.languages)
            ? template.languages
            : [template];
        return languages.map((language) => ({
            id: String(language.msg91_template_id ?? language.id ?? template.id ?? ""),
            name: String(template.name ?? language.name ?? ""),
            status: String(language.status ?? template.status ?? "unknown").toUpperCase(),
            enabled: Number(language.is_disabled ?? template.is_disabled ?? 0) === 0,
            category: String(template.category ?? "utility"),
            language: String(language.language ?? template.language ?? "en"),
            body: readTemplateBody(template, language),
        }));
    });
}
// ── Submit Template for Approval ─────────────────────────────
async function submitTemplateForApproval(opts) {
    const integratedNumber = opts.integratedNumber ?? (0, msg91_client_1.getWhatsAppIntegratedNumber)();
    // Extract variable count from body ({{1}}, {{2}}, etc.)
    const varMatches = opts.body.match(/\{\{(\d+)\}\}/g) ?? [];
    const varCount = new Set(varMatches.map((m) => m.replace(/\{|\}/g, ""))).size;
    // Build example values for Meta approval
    const exampleValues = Array.from({ length: varCount }, (_, i) => `Sample_${i + 1}`);
    // Build components array per MSG91 format
    const components = [
        {
            type: "BODY",
            text: opts.body,
            ...(varCount > 0
                ? { example: { body_text: [exampleValues] } }
                : {}),
        },
    ];
    if (opts.footer) {
        components.push({ type: "FOOTER", text: opts.footer });
    }
    const payload = {
        integrated_number: integratedNumber,
        template_name: opts.name,
        language: opts.language,
        category: opts.category.toUpperCase(),
        components,
    };
    logger.info("submitTemplateForApproval payload:", JSON.stringify(payload));
    const result = await (0, msg91_client_1.sendRequest)(`${msg91_client_1.MSG91_WA_URL}/client-panel-template/`, payload);
    logger.info("submitTemplateForApproval response:", JSON.stringify(result));
    const data = result.data;
    return {
        success: result.status === "success" || result.hasError === false,
        templateId: data?.template_id,
        message: data?.message,
    };
}
// ── Get Template Status ──────────────────────────────────────
async function getTemplateStatus(templateName) {
    const templates = await listTemplates();
    const tpl = templates.find((t) => t.name === templateName);
    if (!tpl) {
        return { approved: false, status: "not_found" };
    }
    return {
        approved: tpl.status === "APPROVED",
        status: tpl.status,
    };
}
// ── Send Read Receipt ────────────────────────────────────────
// NOTE: MSG91 BSP does NOT provide an API for marking messages as read.
// To send read receipts to WhatsApp (blue ticks on customer's phone),
// you need Meta's WhatsApp Cloud API credentials:
//   WHATSAPP_ACCESS_TOKEN and WHATSAPP_PHONE_NUMBER_ID
// from Meta Business Manager (business.facebook.com).
// For now, this only marks messages as read in Firestore.
async function sendReadReceipt(whatsappMessageId, _recipientNumber) {
    const accessToken = process.env.WHATSAPP_ACCESS_TOKEN;
    const phoneNumberId = process.env.WHATSAPP_PHONE_NUMBER_ID;
    // If Meta API credentials are configured, call Meta directly
    if (accessToken && phoneNumberId) {
        try {
            const axios = (await Promise.resolve().then(() => __importStar(require("axios")))).default;
            const resp = await axios.post(`https://graph.facebook.com/v21.0/${phoneNumberId}/messages`, {
                messaging_product: "whatsapp",
                status: "read",
                message_id: whatsappMessageId,
            }, {
                headers: {
                    Authorization: `Bearer ${accessToken}`,
                    "Content-Type": "application/json",
                },
                timeout: 30000,
                validateStatus: () => true,
            });
            logger.info(`sendReadReceipt Meta API [${resp.status}]: ${JSON.stringify(resp.data)}`);
            return { success: resp.status >= 200 && resp.status < 300 };
        }
        catch (err) {
            logger.warn(`sendReadReceipt Meta API error for ${whatsappMessageId}:`, err);
            return { success: false };
        }
    }
    // No Meta credentials — just mark read in Firestore (app-side blue ticks only)
    logger.info(`sendReadReceipt: no Meta API credentials, marking read in Firestore only (msgId=${whatsappMessageId})`);
    return { success: true };
}
// ── Parse Inbound Webhook ────────────────────────────────────
function asRecord(value) {
    return value && typeof value === "object" && !Array.isArray(value)
        ? value
        : undefined;
}
function firstMessage(body) {
    if (Array.isArray(body.messages)) {
        return asRecord(body.messages[0]);
    }
    if (typeof body.messages !== "string" || body.messages.trim() === "") {
        return undefined;
    }
    try {
        const messages = JSON.parse(body.messages);
        return Array.isArray(messages) ? asRecord(messages[0]) : undefined;
    }
    catch {
        return undefined;
    }
}
function firstNonEmptyString(...values) {
    for (const value of values) {
        if (typeof value === "string" && value.trim())
            return value.trim();
    }
    return undefined;
}
function parseWebhook(body) {
    // MSG91 delivery reports have eventName (sent/delivered/read/failed) and direction "1"
    const eventName = body.eventName;
    const direction = body.direction;
    if (eventName && direction === "1") {
        // Outbound delivery status report
        return {
            type: "status",
            messageId: body.requestId ?? body.uuid,
            status: eventName,
            from: body.customerNumber,
            timestamp: body.ts,
        };
    }
    // Inbound message from customer
    const message = firstMessage(body);
    const payload = asRecord(body.payload) ??
        asRecord(body.message) ??
        message;
    const messageText = asRecord(message?.text);
    const referral = asRecord(message?.referral);
    const messageTimestamp = firstNonEmptyString(message?.timestamp, body.ts);
    const mediaUrl = body.url ??
        body.mediaUrl ??
        body.media_url ??
        payload?.url ??
        payload?.mediaUrl ??
        payload?.media_url ??
        body.image?.link ??
        body.video?.link ??
        body.document?.link ??
        body.audio?.link ??
        body.sticker?.link ??
        payload?.image?.link ??
        payload?.video?.link ??
        payload?.document?.link ??
        payload?.audio?.link ??
        payload?.sticker?.link;
    const bodyText = firstNonEmptyString(body.text, body.body, payload?.text, payload?.caption, payload?.body, messageText?.body, referral?.text, referral?.headline);
    let messageType = (body.messageType ??
        body.contentType ??
        payload?.messageType ??
        payload?.contentType ??
        payload?.type ??
        "").toLowerCase().trim();
    if (!messageType) {
        if ((body.sticker || payload?.sticker)) {
            messageType = "sticker";
        }
        else if ((body.audio || payload?.audio)) {
            messageType = "audio";
        }
        else if ((body.video || payload?.video)) {
            messageType = "video";
        }
        else if ((body.document || payload?.document)) {
            messageType = "document";
        }
        else if ((body.image || payload?.image) || (mediaUrl?.includes(".gif"))) {
            messageType = "image";
        }
        else {
            messageType = "text";
        }
    }
    return {
        type: "message",
        from: body.customerNumber,
        contactName: body.customerName,
        body: bodyText,
        messageType,
        mediaUrl: mediaUrl || undefined,
        timestamp: messageTimestamp,
    };
}
//# sourceMappingURL=msg91-whatsapp.js.map
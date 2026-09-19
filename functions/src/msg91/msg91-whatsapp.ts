/**
 * MSG91 WhatsApp API Wrapper
 * Handles all WhatsApp message sending via MSG91's official BSP APIs.
 */

import { sendRequest, MSG91_WA_URL, MSG91_BASE_URL, getWhatsAppIntegratedNumber, getClientWhatsAppNumber } from "./msg91-client";
import * as logger from "firebase-functions/logger";

// ── Types ────────────────────────────────────────────────────
export interface TemplateParam {
  type: "text" | "image" | "video" | "document";
  value: string;
}

export interface WhatsAppTemplateMessage {
  to: string;
  templateName: string;
  language?: string;
  bodyParams?: TemplateParam[];
  headerParams?: TemplateParam[];
  integratedNumber?: string;
}

export interface WhatsAppSessionMessage {
  to: string;
  text: string;
  integratedNumber?: string;
}

export interface WhatsAppMediaMessage {
  to: string;
  mediaUrl: string;
  integratedNumber?: string;
  caption?: string;
  mediaType?: "image" | "video" | "document" | "audio" | "sticker";
}

export interface WhatsAppTemplate {
  id: string;
  name: string;
  status: string;
  enabled: boolean;
  category: string;
  language: string;
  body?: string;
}

function readTemplateBody(template: Record<string, unknown>, language: Record<string, unknown>): string | undefined {
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
    if (typeof candidate === "string" && candidate.trim()) return candidate.trim();
  }

  const components = language.components ?? template.components;
  if (Array.isArray(components)) {
    const body = components.find((component) => {
      const item = component as Record<string, unknown>;
      return String(item.type ?? "").toLowerCase() === "body";
    }) as Record<string, unknown> | undefined;
    const text = body?.text;
    if (typeof text === "string" && text.trim()) return text.trim();
  }

  const code = language.code ?? template.code;
  if (Array.isArray(code)) {
    const body = code.find((component) => {
      const item = component as Record<string, unknown>;
      return String(item.type ?? "").toLowerCase() === "body";
    }) as Record<string, unknown> | undefined;
    const text = body?.text;
    if (typeof text === "string" && text.trim()) return text.trim();
  }

  return undefined;
}

export interface WebhookPayload {
  type: "message" | "status";
  // Message fields
  from?: string;
  contactName?: string;
  body?: string;
  messageType?: string;
  mediaUrl?: string;
  timestamp?: string;
  // Status fields
  messageId?: string;
  status?: string; // sent, delivered, read, failed
}

// ── Send Template Message (outbound, outside 24hr window) ────
export async function sendWhatsAppMessage(
  msg: WhatsAppTemplateMessage,
): Promise<{ success: boolean; requestId?: string }> {
  const integratedNumber = msg.integratedNumber ?? getWhatsAppIntegratedNumber();

  const components: Record<string, unknown>[] = [];
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

  const result = await sendRequest<Record<string, unknown>>(
    `${MSG91_WA_URL}/whatsapp-outbound-message/`,
    payload,
  );

  logger.info("sendWhatsAppMessage response:", JSON.stringify(result));

  return {
    success: result.status === "success" || result.hasError === false,
    requestId: (result.data as Record<string, unknown>)?.message_uuid as string | undefined,
  };
}

// ── Send Session Message (free-form text within 24hr window) ──
export async function sendWhatsAppText(
  msg: WhatsAppSessionMessage,
): Promise<{ success: boolean; requestId?: string }> {
  const integratedNumber = msg.integratedNumber ?? getWhatsAppIntegratedNumber();

  const payload = {
    integrated_number: integratedNumber,
    content_type: "text",
    recipient_number: msg.to,
    type: "text",
    text: msg.text,
  };

  logger.info("sendWhatsAppText payload:", JSON.stringify(payload));

  const result = await sendRequest<Record<string, unknown>>(
    `${MSG91_WA_URL}/whatsapp-outbound-message/`,
    payload,
  );

  logger.info("sendWhatsAppText response:", JSON.stringify(result));

  return {
    success: result.status === "success" || result.message === "Sent successfully",
    requestId: (result.data as Record<string, unknown>)?.message_uuid as string | undefined,
  };
}

// ── Send Media Message ───────────────────────────────────────
export async function sendWhatsAppMedia(
  msg: WhatsAppMediaMessage,
): Promise<{ success: boolean; requestId?: string }> {
  const integratedNumber = msg.integratedNumber ?? getWhatsAppIntegratedNumber();
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

  const result = await sendRequest<Record<string, unknown>>(
    `${MSG91_WA_URL}/whatsapp-outbound-message/`,
    payload,
  );

  return {
    success: result.status === "success" || result.message === "Sent successfully",
    requestId: (result.data as Record<string, unknown>)?.message_uuid as string | undefined,
  };
}

// ── List Templates ───────────────────────────────────────────
export async function listTemplates(overrideNumber?: string): Promise<WhatsAppTemplate[]> {
  const integratedNumber = overrideNumber ?? getWhatsAppIntegratedNumber();
  const result = await sendRequest<Record<string, unknown>>(
    `${MSG91_BASE_URL}/whatsapp/get-template-client/${integratedNumber}`,
    undefined,
    "GET",
  );
  logger.info("MSG91 listTemplates response:", JSON.stringify(result));

  const raw = result.templates ?? result.data;
  const templates = (Array.isArray(raw) ? raw : []) as Record<string, unknown>[];
  return templates.flatMap((template) => {
    const languages = Array.isArray(template.languages)
      ? template.languages as Record<string, unknown>[]
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
export async function submitTemplateForApproval(opts: {
  name: string;
  body: string;
  category: string;
  language: string;
  footer?: string;
  integratedNumber?: string;
}): Promise<{ success: boolean; templateId?: string; message?: string }> {
  const integratedNumber = opts.integratedNumber ?? getWhatsAppIntegratedNumber();

  // Extract variable count from body ({{1}}, {{2}}, etc.)
  const varMatches = opts.body.match(/\{\{(\d+)\}\}/g) ?? [];
  const varCount = new Set(varMatches.map((m) => m.replace(/\{|\}/g, ""))).size;

  // Build example values for Meta approval
  const exampleValues = Array.from({ length: varCount }, (_, i) => `Sample_${i + 1}`);

  // Build components array per MSG91 format
  const components: Record<string, unknown>[] = [
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

  const result = await sendRequest<Record<string, unknown>>(
    `${MSG91_WA_URL}/client-panel-template/`,
    payload,
  );

  logger.info("submitTemplateForApproval response:", JSON.stringify(result));

  const data = result.data as Record<string, unknown> | undefined;
  return {
    success: result.status === "success" || result.hasError === false,
    templateId: data?.template_id as string | undefined,
    message: data?.message as string | undefined,
  };
}

// ── Get Template Status ──────────────────────────────────────
export async function getTemplateStatus(
  templateName: string,
): Promise<{ approved: boolean; status: string }> {
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
export async function sendReadReceipt(
  whatsappMessageId: string,
  _recipientNumber: string,
): Promise<{ success: boolean }> {
  const accessToken = process.env.WHATSAPP_ACCESS_TOKEN;
  const phoneNumberId = process.env.WHATSAPP_PHONE_NUMBER_ID;

  // If Meta API credentials are configured, call Meta directly
  if (accessToken && phoneNumberId) {
    try {
      const axios = (await import("axios")).default;
      const resp = await axios.post(
        `https://graph.facebook.com/v21.0/${phoneNumberId}/messages`,
        {
          messaging_product: "whatsapp",
          status: "read",
          message_id: whatsappMessageId,
        },
        {
          headers: {
            Authorization: `Bearer ${accessToken}`,
            "Content-Type": "application/json",
          },
          timeout: 30_000,
          validateStatus: () => true,
        },
      );
      logger.info(`sendReadReceipt Meta API [${resp.status}]: ${JSON.stringify(resp.data)}`);
      return { success: resp.status >= 200 && resp.status < 300 };
    } catch (err) {
      logger.warn(`sendReadReceipt Meta API error for ${whatsappMessageId}:`, err);
      return { success: false };
    }
  }

  // No Meta credentials — just mark read in Firestore (app-side blue ticks only)
  logger.info(`sendReadReceipt: no Meta API credentials, marking read in Firestore only (msgId=${whatsappMessageId})`);
  return { success: true };
}

// ── Parse Inbound Webhook ────────────────────────────────────
function asRecord(value: unknown): Record<string, unknown> | undefined {
  return value && typeof value === "object" && !Array.isArray(value)
    ? value as Record<string, unknown>
    : undefined;
}

function firstMessage(body: Record<string, unknown>): Record<string, unknown> | undefined {
  if (Array.isArray(body.messages)) {
    return asRecord(body.messages[0]);
  }

  if (typeof body.messages !== "string" || body.messages.trim() === "") {
    return undefined;
  }

  try {
    const messages = JSON.parse(body.messages);
    return Array.isArray(messages) ? asRecord(messages[0]) : undefined;
  } catch {
    return undefined;
  }
}

function firstNonEmptyString(...values: unknown[]): string | undefined {
  for (const value of values) {
    if (typeof value === "string" && value.trim()) return value.trim();
  }
  return undefined;
}

export function parseWebhook(body: Record<string, unknown>): WebhookPayload {
  // MSG91 delivery reports have eventName (sent/delivered/read/failed) and direction "1"
  const eventName = body.eventName as string | undefined;
  const direction = body.direction as string | undefined;

  if (eventName && direction === "1") {
    // Outbound delivery status report
    return {
      type: "status",
      messageId: body.requestId as string | undefined ?? body.uuid as string | undefined,
      status: eventName,
      from: body.customerNumber as string | undefined,
      timestamp: body.ts as string | undefined,
    };
  }

  // Inbound message from customer
  const message = firstMessage(body);
  const payload =
    asRecord(body.payload) ??
    asRecord(body.message) ??
    message;
  const messageText = asRecord(message?.text);
  const referral = asRecord(message?.referral);
  const messageTimestamp = firstNonEmptyString(message?.timestamp, body.ts);

  const mediaUrl =
    (body.url as string | undefined) ??
    (body.mediaUrl as string | undefined) ??
    (body.media_url as string | undefined) ??
    (payload?.url as string | undefined) ??
    (payload?.mediaUrl as string | undefined) ??
    (payload?.media_url as string | undefined) ??
    ((body.image as Record<string, unknown> | undefined)?.link as string | undefined) ??
    ((body.video as Record<string, unknown> | undefined)?.link as string | undefined) ??
    ((body.document as Record<string, unknown> | undefined)?.link as string | undefined) ??
    ((body.audio as Record<string, unknown> | undefined)?.link as string | undefined) ??
    ((body.sticker as Record<string, unknown> | undefined)?.link as string | undefined) ??
    ((payload?.image as Record<string, unknown> | undefined)?.link as string | undefined) ??
    ((payload?.video as Record<string, unknown> | undefined)?.link as string | undefined) ??
    ((payload?.document as Record<string, unknown> | undefined)?.link as string | undefined) ??
    ((payload?.audio as Record<string, unknown> | undefined)?.link as string | undefined) ??
    ((payload?.sticker as Record<string, unknown> | undefined)?.link as string | undefined);

  const bodyText = firstNonEmptyString(
    body.text,
    body.body,
    payload?.text,
    payload?.caption,
    payload?.body,
    messageText?.body,
    referral?.text,
    referral?.headline,
  );

  let messageType = (
    (body.messageType as string | undefined) ??
    (body.contentType as string | undefined) ??
    (payload?.messageType as string | undefined) ??
    (payload?.contentType as string | undefined) ??
    (payload?.type as string | undefined) ??
    ""
  ).toLowerCase().trim();

  if (!messageType) {
    if ((body.sticker || payload?.sticker)) {
      messageType = "sticker";
    } else if ((body.audio || payload?.audio)) {
      messageType = "audio";
    } else if ((body.video || payload?.video)) {
      messageType = "video";
    } else if ((body.document || payload?.document)) {
      messageType = "document";
    } else if ((body.image || payload?.image) || (mediaUrl?.includes(".gif"))) {
      messageType = "image";
    } else {
      messageType = "text";
    }
  }

  return {
    type: "message",
    from: body.customerNumber as string | undefined,
    contactName: body.customerName as string | undefined,
    body: bodyText,
    messageType,
    mediaUrl: mediaUrl || undefined,
    timestamp: messageTimestamp,
  };
}

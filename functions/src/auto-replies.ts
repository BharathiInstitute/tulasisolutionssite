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

import { onCall, HttpsError, CallableRequest } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import { db, Collections, clientCol, getCallerClient, callableOptions } from "./config";

// ── Types ──────────────────────────────────────────────────

interface AutoReplyRule {
  id?: string;
  keywords: string[];
  matchType: "exact" | "contains" | "startsWith";
  channel: "whatsapp" | "sms" | "all";
  response: {
    content: string;
    templateName?: string;
    templateParams?: Array<{ type: string; value: string }>;
    mediaUrl?: string;
  };
  enabled: boolean;
  priority: number;
}

interface CreateAutoReplyRequest {
  keywords: string[];
  matchType: string;
  channel: string;
  response: {
    content: string;
    templateName?: string;
    mediaUrl?: string;
  };
  priority?: number;
}

interface UpdateAutoReplyRequest {
  ruleId: string;
  updates: Partial<AutoReplyRule>;
}

// ── Callable: Create auto-reply rule ───────────────────────

export const createAutoReply = onCall(
  callableOptions,
  async (request: CallableRequest<CreateAutoReplyRequest>) => {
    const { clientId } = await getCallerClient(request.auth);
    const { keywords, matchType, channel, response, priority } = request.data;

    if (!keywords || keywords.length === 0 || !response?.content) {
      throw new HttpsError("invalid-argument", "keywords and response.content required");
    }

    const ref = await db.collection(clientCol(clientId, Collections.autoReplies)).add({
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
  }
);

// ── Callable: Update auto-reply rule ───────────────────────

export const updateAutoReply = onCall(
  callableOptions,
  async (request: CallableRequest<UpdateAutoReplyRequest>) => {
    const { clientId } = await getCallerClient(request.auth);
    const { ruleId, updates } = request.data;

    if (!ruleId) throw new HttpsError("invalid-argument", "ruleId required");

    const ref = db.doc(`${clientCol(clientId, Collections.autoReplies)}/${ruleId}`);
    const snap = await ref.get();
    if (!snap.exists) throw new HttpsError("not-found", "Rule not found");

    await ref.update({ ...updates, updatedAt: new Date() });
    return { success: true };
  }
);

// ── Callable: Delete auto-reply rule ───────────────────────

export const deleteAutoReply = onCall(
  callableOptions,
  async (request: CallableRequest<{ ruleId: string }>) => {
    const { clientId } = await getCallerClient(request.auth);
    const { ruleId } = request.data;

    if (!ruleId) throw new HttpsError("invalid-argument", "ruleId required");

    await db.doc(`${clientCol(clientId, Collections.autoReplies)}/${ruleId}`).delete();
    return { success: true };
  }
);

// ── Callable: List auto-reply rules ────────────────────────

export const getAutoReplies = onCall(
  callableOptions,
  async (request: CallableRequest<void>) => {
    const { clientId } = await getCallerClient(request.auth);

    const snap = await db
      .collection(clientCol(clientId, Collections.autoReplies))
      .orderBy("priority", "asc")
      .get();

    const rules = snap.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
    return { rules };
  }
);

// ── Core: Check inbound message against auto-reply rules ───

/**
 * Called from msg91-webhook.ts when an inbound message arrives.
 * Returns the reply content if a rule matches, or null.
 */
export async function checkAutoReply(
  clientId: string,
  inboundText: string,
  channel: string
): Promise<{ content: string; templateName?: string; mediaUrl?: string } | null> {
  if (!inboundText || inboundText.trim().length === 0) return null;

  const normalizedText = inboundText.toLowerCase().trim();

  const snap = await db
    .collection(clientCol(clientId, Collections.autoReplies))
    .where("enabled", "==", true)
    .orderBy("priority", "asc")
    .get();

  for (const doc of snap.docs) {
    const rule = doc.data() as AutoReplyRule;

    // Channel filter
    if (rule.channel !== "all" && rule.channel !== channel) continue;

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

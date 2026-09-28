/**
 * Shared utilities for Cloud Functions.
 * - normalizePhone: consistent phone format (91XXXXXXXXXX) everywhere
 * - logOutboundMessage: log every outbound WhatsApp message into the contact's conversation
 */

import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";
import { db, Collections, clientCol } from "./config";

// ── Phone Normalization ──────────────────────────────────────────
// Always returns 12-digit format: 91XXXXXXXXXX
// Input can be: +91 9876543210, 919876543210, 9876543210, etc.
export function normalizePhone(raw: string): string {
  const digits = String(raw).replace(/\D/g, "");
  if (digits.length === 12 && digits.startsWith("91")) return digits;
  if (digits.length === 10) return `91${digits}`;
  // If 11 digits starting with 0 (e.g. 09876543210), strip leading 0
  if (digits.length === 11 && digits.startsWith("0")) return `91${digits.slice(1)}`;
  return digits;
}

// Extract last 10 digits for Firestore contact lookup (contacts stored as 10-digit)
export function phoneToTenDigits(raw: string): string {
  const digits = String(raw).replace(/\D/g, "");
  return digits.slice(-10);
}

// ── Outbound Message Logging ─────────────────────────────────────
// Logs an outbound message into the contact's conversation so it shows in Chat.
export async function logOutboundMessage(opts: {
  clientId: string;
  contactId: string;
  content: string;
  channel?: string;
  templateName?: string;
  classSessionId?: string;
  broadcastId?: string;
}): Promise<string> {
  const { clientId, contactId, content, channel, templateName, classSessionId, broadcastId } = opts;

  // Find or create conversation for this contact
  const convsCol = db.collection(clientCol(clientId, Collections.conversations));
  let convId: string;

  const existingConv = await convsCol
    .where("contactId", "==", contactId)
    .limit(1)
    .get();

  if (!existingConv.empty) {
    convId = existingConv.docs[0].id;
  } else {
    // Look up contact name for conversation creation
    const contactSnap = await db
      .doc(`${clientCol(clientId, Collections.contacts)}/${contactId}`)
      .get();
    const contactData = contactSnap.data();

    const convRef = await convsCol.add({
      contactId,
      contactName: contactData?.name ?? "Unknown",
      contactPhone: contactData?.phone ?? "",
      channel: channel ?? "whatsapp",
      lastMessageAt: new Date(),
      lastMessage: content.substring(0, 100),
      lastMessageDirection: "outbound",
      unreadCount: 0,
      status: "active",
      createdAt: new Date(),
    });
    convId = convRef.id;
  }

  // Add message to conversation
  const msgRef = await db
    .collection(`${clientCol(clientId, Collections.conversations)}/${convId}/messages`)
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
    lastMessageDirection: "outbound",
  });

  logger.info(`[logOutboundMessage] Logged msg ${msgRef.id} in conv ${convId} for contact ${contactId}`);
  return msgRef.id;
}

// ── Find Contact by Phone ────────────────────────────────────────
// Returns contactId for a phone number, or null if not found.
export async function findContactByPhone(
  clientId: string,
  phone: string,
): Promise<string | null> {
  const tenDigit = phoneToTenDigits(phone);
  const contactsCol = db.collection(clientCol(clientId, Collections.contacts));

  // Try 10-digit first (how registerForClass stores it)
  let snap = await contactsCol.where("phone", "==", tenDigit).limit(1).get();
  if (!snap.empty) return snap.docs[0].id;

  // Try 12-digit (91XXXXXXXXXX)
  const twelveDigit = normalizePhone(phone);
  snap = await contactsCol.where("phone", "==", twelveDigit).limit(1).get();
  if (!snap.empty) return snap.docs[0].id;

  return null;
}

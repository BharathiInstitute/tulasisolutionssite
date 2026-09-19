/**
 * Mark Conversation Read — sends read receipts to WhatsApp for unread inbound messages.
 */

import { onCall, CallableRequest, HttpsError } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import { db, Collections, clientCol, getCallerClient, callableOptions } from "./config";
import { sendReadReceipt } from "./msg91/msg91-whatsapp";

interface MarkReadRequest {
  conversationId: string;
  clientId?: string;
}

async function resolveClientId(
  request: CallableRequest<MarkReadRequest>,
): Promise<string> {
  const requestedClientId = request.data.clientId?.trim();
  if (!requestedClientId) {
    return (await getCallerClient(request.auth)).clientId;
  }
  if (!request.auth?.uid) {
    throw new HttpsError("unauthenticated", "Authentication required");
  }

  const user = await db.collection("users").doc(request.auth.uid).get();
  const userData = user.data();
  const panels = Array.isArray(userData?.panels) ? userData.panels : [];
  if (userData?.isAdmin === true || panels.includes("chat")) {
    return requestedClientId;
  }

  const callerClientId = (await getCallerClient(request.auth)).clientId;
  if (callerClientId !== requestedClientId) {
    throw new HttpsError("permission-denied", "Cannot access this conversation");
  }
  return callerClientId;
}

/**
 * Called when a user opens a conversation in the app.
 * Sends read receipts to WhatsApp for all unread inbound messages
 * and resets the conversation's unread count.
 */
export const markConversationRead = onCall(
  callableOptions,
  async (request: CallableRequest<MarkReadRequest>) => {
    const clientId = await resolveClientId(request);
    const { conversationId } = request.data;

    if (!conversationId) {
      return { success: false, error: "conversationId is required" };
    }

    try {
      // Get conversation doc to find the customer phone number
      const convPath = `${clientCol(clientId, Collections.conversations)}/${conversationId}`;
      const convDoc = await db.doc(convPath).get();
      const convData = convDoc.data();
      const contactPhone = convData?.contactPhone as string | undefined;

      // Reset unread count on the conversation
      await db.doc(convPath).update({ unreadCount: 0 });

      if (!contactPhone) {
        logger.warn("markConversationRead: no contactPhone on conversation");
        return { success: true, readCount: 0 };
      }

      // Find unread inbound messages with whatsappMessageId
      const messagesRef = db.collection(`${convPath}/${Collections.messages}`);
      const unreadSnap = await messagesRef
        .where("status", "==", "delivered")
        .limit(50)
        .get();

      if (unreadSnap.empty) {
        return { success: true, readCount: 0 };
      }

      logger.info(`markConversationRead: ${unreadSnap.size} unread msgs, phone=${contactPhone}`);

      let readCount = 0;
      for (const doc of unreadSnap.docs) {
        const data = doc.data();
        if (data.direction !== "inbound") continue;
        const waMessageId = data.whatsappMessageId as string;

        let apiSuccess = false;
        if (waMessageId) {
          const result = await sendReadReceipt(waMessageId, contactPhone);
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
    } catch (err) {
      logger.error("markConversationRead error:", err);
      return { success: false, error: String(err) };
    }
  }
);

import { CallableRequest, HttpsError, onCall } from "firebase-functions/v2/https";
import { callableOptions, clientCol, Collections, db, getCallerClient } from "./config";
import { startQualificationTest } from "./lead-qualification";

export const startQualificationAutomation = onCall(
  callableOptions,
  async (request: CallableRequest<{ conversationId: string }>) => {
    const { clientId } = await getCallerClient(request.auth);
    const conversationId = request.data.conversationId;
    if (!conversationId) throw new HttpsError("invalid-argument", "conversationId is required");

    const conversation = await db.doc(`${clientCol(clientId, Collections.conversations)}/${conversationId}`).get();
    if (!conversation.exists) throw new HttpsError("not-found", "Conversation not found");
    const data = conversation.data()!;
    if (data.channel !== "whatsapp") throw new HttpsError("failed-precondition", "Automation is only available for WhatsApp conversations");
    if (!data.contactId || !data.contactPhone) throw new HttpsError("failed-precondition", "Conversation has no contact details");

    await startQualificationTest({
      clientId,
      contactId: data.contactId,
      conversationId,
      phone: data.contactPhone,
      contactName: data.contactName ?? "Contact",
    });
    return { success: true };
  },
);
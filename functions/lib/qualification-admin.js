"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.startQualificationAutomation = void 0;
const https_1 = require("firebase-functions/v2/https");
const config_1 = require("./config");
const lead_qualification_1 = require("./lead-qualification");
exports.startQualificationAutomation = (0, https_1.onCall)(config_1.callableOptions, async (request) => {
    const { clientId } = await (0, config_1.getCallerClient)(request.auth);
    const conversationId = request.data.conversationId;
    if (!conversationId)
        throw new https_1.HttpsError("invalid-argument", "conversationId is required");
    const conversation = await config_1.db.doc(`${(0, config_1.clientCol)(clientId, config_1.Collections.conversations)}/${conversationId}`).get();
    if (!conversation.exists)
        throw new https_1.HttpsError("not-found", "Conversation not found");
    const data = conversation.data();
    if (data.channel !== "whatsapp")
        throw new https_1.HttpsError("failed-precondition", "Automation is only available for WhatsApp conversations");
    if (!data.contactId || !data.contactPhone)
        throw new https_1.HttpsError("failed-precondition", "Conversation has no contact details");
    await (0, lead_qualification_1.startQualificationTest)({
        clientId,
        contactId: data.contactId,
        conversationId,
        phone: data.contactPhone,
        contactName: data.contactName ?? "Contact",
    });
    return { success: true };
});
//# sourceMappingURL=qualification-admin.js.map
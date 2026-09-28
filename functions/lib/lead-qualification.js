"use strict";
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
exports.processQualificationInbound = processQualificationInbound;
exports.startQualificationTest = startQualificationTest;
exports.processQualificationTimeouts = processQualificationTimeouts;
const firestore_1 = require("firebase-admin/firestore");
const logger = __importStar(require("firebase-functions/logger"));
const config_1 = require("./config");
const questions = {
    businessStatus: "*Welcome to Tulasi Solutions* 🌿\n\nThank you for reaching out. To guide you better, please choose one option:\n\n*Are you already running a business?*\n\n1️⃣  Yes, I have an existing business\n2️⃣  No, I am starting a new business\n\n_Reply with 1 or 2_",
    category: "*Great, thank you!* ✨\n\n*What type of business is it?*\n\n1️⃣  Shop / Products\n2️⃣  Restaurant / Food\n3️⃣  Service (salon, clinic, consulting)\n4️⃣  Other\n\n_Reply with 1, 2, 3, or 4_",
    categoryOther: "*No problem.* 🙂\n\nPlease tell us your business type in a few words.",
    primaryNeed: "*Almost there!* 💡\n\n*What do you need most right now?*\n\n1️⃣  Website / App\n2️⃣  Branding (logo, design)\n3️⃣  Marketing (reels, posts, ads)\n4️⃣  Growth strategy & planning\n5️⃣  Everything combined\n\n_Reply with 1 to 5_",
    urgency: "*One last question* ⏱️\n\n*When are you looking to get started?*\n\n1️⃣  Right now\n2️⃣  This week / this month\n3️⃣  Still exploring\n\n_Reply with 1, 2, or 3_",
    restart: "*We are still here to help* 👋\n\nLet's continue with a fresh start. Please choose one option:\n\n",
};
const invalidPrefix = "Please reply with the number only (for example, 1, 2, or 3).\n\n";
async function processQualificationInbound(input) {
    const content = input.content.trim();
    if (!content)
        return false;
    const enabled = await isQualificationEnabled(input.clientId);
    const sessionRef = config_1.db.doc(`${(0, config_1.clientCol)(input.clientId, "qualificationSessions")}/${input.conversationId}`);
    let reply = null;
    let leadUpdates = null;
    let handled = false;
    await config_1.db.runTransaction(async (transaction) => {
        const snapshot = await transaction.get(sessionRef);
        const now = new Date();
        if (!snapshot.exists) {
            if (!input.isNewContact || !enabled)
                return;
            handled = true;
            reply = questions.businessStatus;
            transaction.set(sessionRef, {
                contactId: input.contactId, conversationId: input.conversationId, channel: "whatsapp",
                status: "in_progress", state: "awaiting_business_status", invalidAttempts: 0,
                startedAt: now, firstMessageAt: now, firstMessageContent: content.slice(0, 500),
                lastInboundAt: now, lastQuestionAt: now,
                nextActionAt: new Date(now.getTime() + 23 * 60 * 60 * 1000),
            });
            leadUpdates = { automationStatus: "in_progress" };
            return;
        }
        const session = snapshot.data();
        handled = true;
        if (session.status !== "in_progress")
            return;
        const transition = transitionFor(session, content);
        if (transition.manualReview) {
            transaction.update(sessionRef, { status: "needs_manual_review", state: "needs_manual_review", manualReviewReason: transition.manualReview, lastInboundAt: now, updatedAt: now });
            leadUpdates = { automationStatus: "needs_manual_review", manualReviewReason: transition.manualReview };
            return;
        }
        if (transition.invalid) {
            const invalidAttempts = (session.invalidAttempts ?? 0) + 1;
            reply = invalidPrefix + questionForState(session.state);
            transaction.update(sessionRef, { invalidAttempts, lastInboundAt: now, lastQuestionAt: now, nextActionAt: new Date(now.getTime() + 23 * 60 * 60 * 1000), updatedAt: now });
            return;
        }
        reply = transition.reply ?? null;
        leadUpdates = transition.leadUpdates ?? null;
        transaction.update(sessionRef, {
            ...transition.sessionUpdates, invalidAttempts: 0, lastInboundAt: now,
            ...(reply ? { lastQuestionAt: now } : {}),
            nextActionAt: transition.complete ? null : new Date(now.getTime() + 23 * 60 * 60 * 1000),
            updatedAt: now,
        });
    });
    if (!handled)
        return false;
    if (!reply && !leadUpdates)
        return true;
    if (leadUpdates)
        await updateLead(input, leadUpdates);
    if (reply)
        await queueQualificationReply(input, reply);
    return true;
}
async function startQualificationTest(input) {
    const now = new Date();
    const sessionRef = config_1.db.doc(`${(0, config_1.clientCol)(input.clientId, "qualificationSessions")}/${input.conversationId}`);
    await sessionRef.set({
        contactId: input.contactId,
        conversationId: input.conversationId,
        channel: "whatsapp",
        status: "in_progress",
        state: "awaiting_business_status",
        invalidAttempts: 0,
        startedAt: now,
        lastQuestionAt: now,
        nextActionAt: new Date(now.getTime() + 23 * 60 * 60 * 1000),
        testMode: true,
        testStartedAt: now,
    });
    await updateLead({ ...input, content: "", isNewContact: false }, { automationStatus: "in_progress" });
    await queueQualificationReply({ ...input, content: "", isNewContact: false }, questions.businessStatus);
    logger.info(`Qualification test started for ${input.contactId}`);
}
function transitionFor(session, content) {
    if (session.state === "awaiting_category_other") {
        return { reply: questions.primaryNeed, sessionUpdates: { state: "awaiting_primary_need", categoryOther: content }, leadUpdates: { category: "other", categoryOther: content, automationStatus: "in_progress" } };
    }
    const expected = session.state === "awaiting_primary_need" ? 5 : session.state === "awaiting_urgency" ? 3 : session.state === "awaiting_category" ? 4 : 2;
    const selection = content.match(new RegExp(`^\\s*([1-${expected}])\\s*$`))?.[1];
    if (!selection)
        return { invalid: true };
    if (session.state === "awaiting_business_status") {
        const businessStatus = selection === "1" ? "existing" : "new";
        return { reply: questions.category, sessionUpdates: { state: "awaiting_category", businessStatus }, leadUpdates: { businessStatus, automationStatus: "in_progress" } };
    }
    if (session.state === "awaiting_category") {
        if (selection === "4")
            return { reply: questions.categoryOther, sessionUpdates: { state: "awaiting_category_other", category: "other" }, leadUpdates: { category: "other", automationStatus: "in_progress" } };
        const category = { "1": "shop", "2": "restaurant", "3": "service" }[selection];
        return { reply: questions.primaryNeed, sessionUpdates: { state: "awaiting_primary_need", category }, leadUpdates: { category, automationStatus: "in_progress" } };
    }
    if (session.state === "awaiting_primary_need") {
        const primaryNeed = { "1": "website_app", "2": "branding", "3": "marketing", "4": "growth_strategy", "5": "everything" }[selection];
        return { reply: questions.urgency, sessionUpdates: { state: "awaiting_urgency", primaryNeed }, leadUpdates: { primaryNeed, automationStatus: "in_progress" } };
    }
    if (session.state === "awaiting_urgency") {
        const urgency = { "1": "hot", "2": "warm", "3": "cold" }[selection];
        const existing = session.businessStatus === "existing";
        const reply = urgency === "hot" ? (existing ? "*Thank you!* 🎉\n\nOur team will reach out shortly to take this forward." : "*Thank you!* 🎉\n\nOur team will reach out shortly to help you get started.") : urgency === "warm" ? (existing ? "*Thanks for sharing!* ✨\n\nOur team will reach out soon to schedule a time that works for you." : "*Thanks for sharing!* ✨\n\nOur team will reach out soon to discuss your new business.") : (existing ? "*No problem.* 🌱\n\nTake your time. Visit us at https://tulasisolutions.com/ and message us whenever you're ready." : "*No problem.* 🌱\n\nTake your time. Visit us at https://tulasisolutions.com/ and message us whenever you're ready to begin.");
        return { reply, complete: true, sessionUpdates: { state: "complete", status: "complete", urgency, completedAt: new Date() }, leadUpdates: { urgency, automationStatus: "complete", ...(urgency === "cold" ? { nurture: true } : {}) } };
    }
    return { manualReview: "Unexpected qualification state" };
}
function questionForState(state) {
    if (state === "awaiting_business_status")
        return questions.businessStatus;
    if (state === "awaiting_category")
        return questions.category;
    if (state === "awaiting_primary_need")
        return questions.primaryNeed;
    if (state === "awaiting_urgency")
        return questions.urgency;
    return questions.categoryOther;
}
async function isQualificationEnabled(clientId) {
    const settings = await config_1.db.doc(`${(0, config_1.clientCol)(clientId, "settings")}/automation`).get();
    return settings.data()?.whatsappQualificationEnabled === true;
}
async function updateLead(input, updates) {
    const leads = await config_1.db.collection((0, config_1.clientCol)(input.clientId, config_1.Collections.leads)).where("contactId", "==", input.contactId).limit(1).get();
    const tags = [
        ...(updates.urgency ? [updates.urgency] : []),
        ...(updates.primaryNeed === "growth_strategy" ? ["growth-strategy"] : []),
        ...(updates.automationStatus === "needs_manual_review" ? ["manual-review"] : []),
        ...(updates.nurture ? ["nurture"] : []),
    ];
    if (!leads.empty) {
        await leads.docs[0].ref.update({
            ...updates,
            ...(tags.length > 0 ? { tags: firestore_1.FieldValue.arrayUnion(...tags) } : {}),
            lastReplyAt: new Date(),
            updatedAt: new Date(),
        });
        return;
    }
    await config_1.db.collection((0, config_1.clientCol)(input.clientId, config_1.Collections.leads)).add({ title: `Lead: ${input.contactName}`, contactId: input.contactId, contactName: input.contactName, contactPhone: input.phone.replace(/\D/g, "").slice(-10), source: "whatsapp", status: "new", score: 0, tags, ...updates, createdAt: new Date(), updatedAt: new Date() });
}
async function queueQualificationReply(input, content, delaySeconds = 0) {
    const now = new Date();
    const scheduledAt = delaySeconds > 0 ? new Date(now.getTime() + delaySeconds * 1000) : now;
    const messageRef = await config_1.db.collection(`${(0, config_1.clientCol)(input.clientId, config_1.Collections.conversations)}/${input.conversationId}/${config_1.Collections.messages}`).add({ conversationId: input.conversationId, contactId: input.contactId, direction: "outbound", type: "text", content, status: "queued", senderName: "Tulasi Solutions", createdAt: now, eventAt: now, channel: "whatsapp" });
    await config_1.db.doc(`${(0, config_1.clientCol)(input.clientId, config_1.Collections.conversations)}/${input.conversationId}`).update({
        lastMessage: content,
        lastMessageAt: now,
        lastMessageDirection: "outbound",
    });
    await config_1.db.collection((0, config_1.clientCol)(input.clientId, config_1.Collections.messageQueue)).add({ contactId: input.contactId, phone: input.phone, conversationId: input.conversationId, messageDocId: messageRef.id, content, channel: "whatsapp", status: "pending", retries: 0, source: "lead_qualification", scheduledAt, createdAt: now });
}
async function processQualificationTimeouts() {
    const now = new Date();
    const clients = await config_1.db.collection(config_1.Collections.clients).get();
    for (const client of clients.docs) {
        const sessions = await config_1.db.collection(`${client.ref.path}/qualificationSessions`).where("status", "==", "in_progress").get();
        for (const doc of sessions.docs) {
            const data = doc.data();
            const nextActionAt = data.nextActionAt?.toDate?.();
            if (!nextActionAt || nextActionAt > now)
                continue;
            const contactId = data.contactId;
            const contact = await config_1.db.doc(`${client.ref.path}/${config_1.Collections.contacts}/${contactId}`).get();
            const phone = contact.data()?.phone;
            if (data.restartSentAt) {
                await doc.ref.update({ status: "needs_manual_review", state: "needs_manual_review", manualReviewReason: "No response after restart", nextActionAt: null, updatedAt: now });
                await updateLead({ clientId: client.id, contactId, conversationId: data.conversationId, phone: phone ?? "", contactName: contact.data()?.name ?? "Contact", content: "", isNewContact: false }, { automationStatus: "needs_manual_review", manualReviewReason: "No response after restart" });
                continue;
            }
            if (data.conversationId && phone)
                await queueQualificationReply({ clientId: client.id, contactId, conversationId: data.conversationId, phone, contactName: contact.data()?.name ?? "Contact", content: "", isNewContact: false }, questions.restart + questions.businessStatus, 0);
            await doc.ref.update({ state: "awaiting_business_status", invalidAttempts: 0, restartSentAt: now, lastQuestionAt: now, nextActionAt: new Date(now.getTime() + 23 * 60 * 60 * 1000), updatedAt: now });
            logger.info(`Qualification session restarted: ${doc.ref.path}`);
        }
    }
}
//# sourceMappingURL=lead-qualification.js.map
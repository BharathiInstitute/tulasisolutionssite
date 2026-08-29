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
exports.Collections = exports.callableOptions = exports.msg91WhatsAppNumber = exports.msg91AuthKey = exports.messaging = exports.storage = exports.auth = exports.db = void 0;
exports.clientCol = clientCol;
exports.getCallerClient = getCallerClient;
const admin = __importStar(require("firebase-admin"));
const logger = __importStar(require("firebase-functions/logger"));
const params_1 = require("firebase-functions/params");
// Initialize Firebase Admin SDK once
admin.initializeApp();
exports.db = admin.firestore();
exports.auth = admin.auth();
exports.storage = admin.storage();
exports.messaging = admin.messaging();
exports.msg91AuthKey = (0, params_1.defineSecret)("MSG91_AUTH_KEY");
exports.msg91WhatsAppNumber = (0, params_1.defineSecret)("MSG91_WA_IBNID");
// Shared callable options — App Check enforcement disabled until reCAPTCHA key is configured
exports.callableOptions = {
    enforceAppCheck: false,
    region: "asia-south1",
};
// Canonical collection names (must match Flutter constants.dart)
exports.Collections = {
    clients: "clients",
    contacts: "contacts",
    conversations: "conversations",
    messages: "messages",
    campaigns: "campaigns",
    leads: "leads",
    deals: "deals",
    products: "products",
    quotations: "quotations",
    invoices: "invoices",
    payments: "payments",
    tasks: "tasks",
    templates: "templates",
    tickets: "tickets",
    feedback: "feedback",
    documents: "documents",
    usage: "usage",
    counters: "counters",
    socialAccounts: "socialAccounts",
    socialPosts: "socialPosts",
    workflows: "workflows",
    workflowLogs: "workflowLogs",
    autoReplies: "autoReplies",
    dripCampaigns: "dripCampaigns",
    teamMembers: "teamMembers",
    teamInvites: "teamInvites",
    activityLog: "activityLog",
    messageQueue: "message_queue",
    fcmTokens: "fcmTokens",
    notifications: "notifications",
    calendarEvents: "calendarEvents",
    dpdpRequests: "dpdpRequests",
    deletionRequests: "deletionRequests",
    consents: "consents",
    paymentOrders: "paymentOrders",
    emailLogs: "emailLogs",
    oauthStates: "oauth_states",
    connectedAccounts: "connectedAccounts",
    analytics: "analytics",
    callLogs: "call_logs",
    classSessions: "classSessions",
    classRegistrations: "classRegistrations",
    adCampaigns: "ad_campaigns",
};
// Helper: get client-scoped collection path
function clientCol(clientId, collection) {
    return `${exports.Collections.clients}/${clientId}/${collection}`;
}
// Helper: verify caller is authenticated and get their clientId
async function getCallerClient(auth) {
    if (!auth?.uid) {
        throw new Error("Authentication required");
    }
    logger.info(`getCallerClient: checking uid=${auth.uid}`);
    // Fast path: check if user IS a client (owner — uid matches clientId)
    const clientDoc = await exports.db.collection(exports.Collections.clients).doc(auth.uid).get();
    if (clientDoc.exists) {
        logger.info(`getCallerClient: fast path hit for uid=${auth.uid}`);
        return { uid: auth.uid, clientId: auth.uid };
    }
    const email = typeof auth.token?.email === "string"
        ? auth.token.email.trim().toLowerCase()
        : "";
    if (email) {
        const clientByEmail = await exports.db
            .collection(exports.Collections.clients)
            .where("contactEmail", "==", email)
            .limit(1)
            .get();
        if (!clientByEmail.empty) {
            const clientId = clientByEmail.docs[0].id;
            logger.info(`getCallerClient: email path hit for uid=${auth.uid}`);
            return { uid: auth.uid, clientId };
        }
    }
    logger.info(`getCallerClient: fast path missed, trying collectionGroup for uid=${auth.uid}`);
    // Fallback: look up which client this user belongs to via team membership
    const memberSnap = await exports.db
        .collectionGroup(exports.Collections.teamMembers)
        .where("userId", "==", auth.uid)
        .limit(1)
        .get();
    if (memberSnap.empty) {
        logger.error(`getCallerClient: no client found for uid=${auth.uid}`);
        throw new Error("User not associated with any client");
    }
    const clientId = memberSnap.docs[0].ref.parent.parent?.id;
    if (!clientId) {
        throw new Error("Could not determine client ID");
    }
    return { uid: auth.uid, clientId };
}
//# sourceMappingURL=config.js.map
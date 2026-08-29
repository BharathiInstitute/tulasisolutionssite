import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";
import { defineSecret } from "firebase-functions/params";

// Initialize Firebase Admin SDK once
admin.initializeApp();

export const db = admin.firestore();
export const auth = admin.auth();
export const storage = admin.storage();
export const messaging = admin.messaging();

export const msg91AuthKey = defineSecret("MSG91_AUTH_KEY");
export const msg91WhatsAppNumber = defineSecret("MSG91_WA_IBNID");

// Shared callable options — App Check enforcement disabled until reCAPTCHA key is configured
export const callableOptions = {
  enforceAppCheck: false,
  region: "asia-south1",
};

// Canonical collection names (must match Flutter constants.dart)
export const Collections = {
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
} as const;

// Helper: get client-scoped collection path
export function clientCol(clientId: string, collection: string): string {
  return `${Collections.clients}/${clientId}/${collection}`;
}

// Helper: verify caller is authenticated and get their clientId
export async function getCallerClient(
  auth: { uid: string; token?: { email?: unknown } } | undefined
): Promise<{ uid: string; clientId: string }> {
  if (!auth?.uid) {
    throw new Error("Authentication required");
  }

  logger.info(`getCallerClient: checking uid=${auth.uid}`);

  // Fast path: check if user IS a client (owner — uid matches clientId)
  const clientDoc = await db.collection(Collections.clients).doc(auth.uid).get();
  if (clientDoc.exists) {
    logger.info(`getCallerClient: fast path hit for uid=${auth.uid}`);
    return { uid: auth.uid, clientId: auth.uid };
  }

  const email = typeof auth.token?.email === "string"
    ? auth.token.email.trim().toLowerCase()
    : "";
  if (email) {
    const clientByEmail = await db
      .collection(Collections.clients)
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
  const memberSnap = await db
    .collectionGroup(Collections.teamMembers)
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

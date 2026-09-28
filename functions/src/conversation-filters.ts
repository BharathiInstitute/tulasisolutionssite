import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import {
  onDocumentCreated,
  onDocumentUpdated,
} from "firebase-functions/v2/firestore";
import { Collections, callableOptions, db } from "./config";

const region = "asia-south1";
const statsRef = db.doc("chat_stats/global");

function incrementFor(
  stage: string,
  isArchived: boolean,
  amount: number,
): Record<string, FirebaseFirestore.FieldValue> {
  const group = isArchived ? "archivedStages" : "activeStages";
  return {
    [`${group}.${stage}`]: admin.firestore.FieldValue.increment(amount),
    [isArchived ? "archivedTotal" : "activeTotal"]:
      admin.firestore.FieldValue.increment(amount),
  };
}

function addFilterDelta(
  deltas: Record<string, number>,
  stage: string,
  isArchived: boolean,
  amount: number,
): void {
  const group = isArchived ? "archivedStages" : "activeStages";
  const total = isArchived ? "archivedTotal" : "activeTotal";
  deltas[`${group}.${stage}`] = (deltas[`${group}.${stage}`] ?? 0) + amount;
  deltas[total] = (deltas[total] ?? 0) + amount;
}

function incrementsForDeltas(
  deltas: Record<string, number>,
): Record<string, FirebaseFirestore.FieldValue> {
  return Object.fromEntries(
    Object.entries(deltas)
      .filter(([, amount]) => amount !== 0)
      .map(([field, amount]) => [
        field,
        admin.firestore.FieldValue.increment(amount),
      ]),
  );
}

async function updateConversationFilters(
  clientId: string,
  stage: string,
  isArchived?: boolean,
): Promise<number> {
  const conversations = await db
    .collection(`${Collections.clients}/${clientId}/${Collections.conversations}`)
    .get();
  if (conversations.empty) return 0;

  let updated = 0;
  for (let offset = 0; offset < conversations.docs.length; offset += 450) {
    const batch = db.batch();
    for (const conversation of conversations.docs.slice(offset, offset + 450)) {
      batch.set(
        conversation.ref,
        isArchived == null ? { stage } : { stage, isArchived },
        { merge: true },
      );
      updated++;
    }
    await batch.commit();
  }
  return updated;
}

export const syncClientConversationFilters = onDocumentUpdated(
  { document: "clients/{clientId}", region },
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!after) return;

    const stage = String(after.stage ?? "reach");
    const isArchived = after.isArchived === true;
    const stageChanged = before?.stage !== stage;
    const archiveChanged =
      (before?.isArchived === true) !== isArchived;
    if (
      !stageChanged &&
      !archiveChanged
    ) {
      return;
    }

    await updateConversationFilters(
      event.params.clientId,
      stage,
      archiveChanged ? isArchived : undefined,
    );
  },
);

export const syncConversationFilterStats = onDocumentUpdated(
  { document: "clients/{clientId}/conversations/{conversationId}", region },
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after || after.channel !== "whatsapp") return;

    const oldStage = String(before.stage ?? "reach");
    const newStage = String(after.stage ?? "reach");
    const oldArchived = before.isArchived === true;
    const newArchived = after.isArchived === true;
    if (oldStage === newStage && oldArchived === newArchived) return;

    const deltas: Record<string, number> = {};
    addFilterDelta(deltas, oldStage, oldArchived, -1);
    addFilterDelta(deltas, newStage, newArchived, 1);
    await statsRef.set(incrementsForDeltas(deltas), { merge: true });
  },
);

export const initializeConversationFilters = onDocumentCreated(
  { document: "clients/{clientId}/conversations/{conversationId}", region },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;
    const data = snapshot.data();
    let stage = typeof data.stage === "string" ? data.stage : "reach";
    let isArchived = data.isArchived === true;
    if (typeof data.stage !== "string" || typeof data.isArchived !== "boolean") {
      const client = await db
        .collection(Collections.clients)
        .doc(event.params.clientId)
        .get();
      stage = String(client.data()?.stage ?? "reach");
      isArchived = client.data()?.isArchived === true;
      await snapshot.ref.set({ stage, isArchived }, { merge: true });
    }
    if (data.channel === "whatsapp") {
      await statsRef.set(incrementFor(stage, isArchived, 1), { merge: true });
    }
  },
);

export const backfillConversationFilters = onCall(
  { ...callableOptions, timeoutSeconds: 540, memory: "512MiB" },
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "Authentication required");
    }
    const profile = await db.collection("users").doc(request.auth.uid).get();
    if (profile.data()?.isAdmin !== true) {
      throw new HttpsError("permission-denied", "Super admin required");
    }

    const migrationRef = db.doc("system/conversationFiltersV1");
    const migration = await migrationRef.get();
    const stats = await statsRef.get();
    if (migration.data()?.completed === true && stats.exists) {
      return { skipped: true, clients: 0, conversations: 0 };
    }

    const [clients, conversations] = await Promise.all([
      db.collection(Collections.clients).get(),
      db.collectionGroup(Collections.conversations).get(),
    ]);
    const filtersByClient = new Map(
      clients.docs.map((client) => [
        client.id,
        {
          stage: String(client.data().stage ?? "reach"),
          isArchived: client.data().isArchived === true,
        },
      ]),
    );
    const writer = db.bulkWriter();
    const activeStages: Record<string, number> = {};
    const archivedStages: Record<string, number> = {};
    let activeTotal = 0;
    let archivedTotal = 0;
    for (const conversation of conversations.docs) {
      const clientId = conversation.ref.parent.parent?.id;
      const filters = clientId == null ? null : filtersByClient.get(clientId);
      const resolved = filters ?? { stage: "reach", isArchived: false };
      writer.set(
        conversation.ref,
        resolved,
        { merge: true },
      );
      if (conversation.data().channel === "whatsapp") {
        const target = resolved.isArchived ? archivedStages : activeStages;
        target[resolved.stage] = (target[resolved.stage] ?? 0) + 1;
        if (resolved.isArchived) archivedTotal++;
        else activeTotal++;
      }
    }
    await writer.close();
    const updated = conversations.size;
    await statsRef.set({
      activeTotal,
      archivedTotal,
      activeStages,
      archivedStages,
      updatedAt: new Date(),
    });
    await migrationRef.set({
      completed: true,
      completedAt: new Date(),
      clients: clients.size,
      conversations: updated,
    });
    return { clients: clients.size, conversations: updated };
  },
);

export const getConversationFilterCounts = onCall(
  callableOptions,
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "Authentication required");
    }

    const email = String(request.auth.token.email ?? "").trim().toLowerCase();
    const [uidProfile, emailProfile] = await Promise.all([
      db.collection("users").doc(request.auth.uid).get(),
      email.length > 0
        ? db.collection("users").doc(email).get()
        : Promise.resolve(null),
    ]);
    const profile = emailProfile?.exists ? emailProfile.data() : uidProfile.data();
    const panels = Array.isArray(profile?.panels) ? profile.panels : [];
    if (profile?.isAdmin !== true && !panels.includes("chat")) {
      throw new HttpsError("permission-denied", "Chat access required");
    }

    const conversationQuery = db
      .collectionGroup(Collections.conversations)
      .where("channel", "==", "whatsapp");
    const stages = [
      "reach",
      "click",
      "register",
      "consult",
      "client",
      "retain",
      "lost",
    ];
    const activeQuery = conversationQuery.where("isArchived", "==", false);
    const archivedQuery = conversationQuery.where("isArchived", "==", true);
    const [activeTotal, archivedTotal, ...stageSnapshots] = await Promise.all([
      activeQuery.count().get(),
      archivedQuery.count().get(),
      ...stages.map((stage) =>
        activeQuery.where("stage", "==", stage).count().get()),
      ...stages.map((stage) =>
        archivedQuery.where("stage", "==", stage).count().get()),
    ]);
    const activeStages = Object.fromEntries(
      stages.map((stage, index) => [stage, stageSnapshots[index].data().count]),
    );
    const archivedStages = Object.fromEntries(
      stages.map((stage, index) => [
        stage,
        stageSnapshots[index + stages.length].data().count,
      ]),
    );
    const counts = {
      activeTotal: activeTotal.data().count,
      archivedTotal: archivedTotal.data().count,
      activeStages,
      archivedStages,
    };

    await statsRef.set({
      ...counts,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return counts;
  },
);

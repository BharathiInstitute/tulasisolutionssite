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
exports.getConversationFilterCounts = exports.backfillConversationFilters = exports.initializeConversationFilters = exports.syncConversationFilterStats = exports.syncClientConversationFilters = void 0;
const https_1 = require("firebase-functions/v2/https");
const admin = __importStar(require("firebase-admin"));
const firestore_1 = require("firebase-functions/v2/firestore");
const config_1 = require("./config");
const region = "asia-south1";
const statsRef = config_1.db.doc("chat_stats/global");
function incrementFor(stage, isArchived, amount) {
    const group = isArchived ? "archivedStages" : "activeStages";
    return {
        [`${group}.${stage}`]: admin.firestore.FieldValue.increment(amount),
        [isArchived ? "archivedTotal" : "activeTotal"]: admin.firestore.FieldValue.increment(amount),
    };
}
function addFilterDelta(deltas, stage, isArchived, amount) {
    const group = isArchived ? "archivedStages" : "activeStages";
    const total = isArchived ? "archivedTotal" : "activeTotal";
    deltas[`${group}.${stage}`] = (deltas[`${group}.${stage}`] ?? 0) + amount;
    deltas[total] = (deltas[total] ?? 0) + amount;
}
function incrementsForDeltas(deltas) {
    return Object.fromEntries(Object.entries(deltas)
        .filter(([, amount]) => amount !== 0)
        .map(([field, amount]) => [
        field,
        admin.firestore.FieldValue.increment(amount),
    ]));
}
async function updateConversationFilters(clientId, stage, isArchived) {
    const conversations = await config_1.db
        .collection(`${config_1.Collections.clients}/${clientId}/${config_1.Collections.conversations}`)
        .get();
    if (conversations.empty)
        return 0;
    let updated = 0;
    for (let offset = 0; offset < conversations.docs.length; offset += 450) {
        const batch = config_1.db.batch();
        for (const conversation of conversations.docs.slice(offset, offset + 450)) {
            batch.set(conversation.ref, isArchived == null ? { stage } : { stage, isArchived }, { merge: true });
            updated++;
        }
        await batch.commit();
    }
    return updated;
}
exports.syncClientConversationFilters = (0, firestore_1.onDocumentUpdated)({ document: "clients/{clientId}", region }, async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!after)
        return;
    const stage = String(after.stage ?? "reach");
    const isArchived = after.isArchived === true;
    const stageChanged = before?.stage !== stage;
    const archiveChanged = (before?.isArchived === true) !== isArchived;
    if (!stageChanged &&
        !archiveChanged) {
        return;
    }
    await updateConversationFilters(event.params.clientId, stage, archiveChanged ? isArchived : undefined);
});
exports.syncConversationFilterStats = (0, firestore_1.onDocumentUpdated)({ document: "clients/{clientId}/conversations/{conversationId}", region }, async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after || after.channel !== "whatsapp")
        return;
    const oldStage = String(before.stage ?? "reach");
    const newStage = String(after.stage ?? "reach");
    const oldArchived = before.isArchived === true;
    const newArchived = after.isArchived === true;
    if (oldStage === newStage && oldArchived === newArchived)
        return;
    const deltas = {};
    addFilterDelta(deltas, oldStage, oldArchived, -1);
    addFilterDelta(deltas, newStage, newArchived, 1);
    await statsRef.set(incrementsForDeltas(deltas), { merge: true });
});
exports.initializeConversationFilters = (0, firestore_1.onDocumentCreated)({ document: "clients/{clientId}/conversations/{conversationId}", region }, async (event) => {
    const snapshot = event.data;
    if (!snapshot)
        return;
    const data = snapshot.data();
    let stage = typeof data.stage === "string" ? data.stage : "reach";
    let isArchived = data.isArchived === true;
    if (typeof data.stage !== "string" || typeof data.isArchived !== "boolean") {
        const client = await config_1.db
            .collection(config_1.Collections.clients)
            .doc(event.params.clientId)
            .get();
        stage = String(client.data()?.stage ?? "reach");
        isArchived = client.data()?.isArchived === true;
        await snapshot.ref.set({ stage, isArchived }, { merge: true });
    }
    if (data.channel === "whatsapp") {
        await statsRef.set(incrementFor(stage, isArchived, 1), { merge: true });
    }
});
exports.backfillConversationFilters = (0, https_1.onCall)({ ...config_1.callableOptions, timeoutSeconds: 540, memory: "512MiB" }, async (request) => {
    if (!request.auth?.uid) {
        throw new https_1.HttpsError("unauthenticated", "Authentication required");
    }
    const profile = await config_1.db.collection("users").doc(request.auth.uid).get();
    if (profile.data()?.isAdmin !== true) {
        throw new https_1.HttpsError("permission-denied", "Super admin required");
    }
    const migrationRef = config_1.db.doc("system/conversationFiltersV1");
    const migration = await migrationRef.get();
    const stats = await statsRef.get();
    if (migration.data()?.completed === true && stats.exists) {
        return { skipped: true, clients: 0, conversations: 0 };
    }
    const [clients, conversations] = await Promise.all([
        config_1.db.collection(config_1.Collections.clients).get(),
        config_1.db.collectionGroup(config_1.Collections.conversations).get(),
    ]);
    const filtersByClient = new Map(clients.docs.map((client) => [
        client.id,
        {
            stage: String(client.data().stage ?? "reach"),
            isArchived: client.data().isArchived === true,
        },
    ]));
    const writer = config_1.db.bulkWriter();
    const activeStages = {};
    const archivedStages = {};
    let activeTotal = 0;
    let archivedTotal = 0;
    for (const conversation of conversations.docs) {
        const clientId = conversation.ref.parent.parent?.id;
        const filters = clientId == null ? null : filtersByClient.get(clientId);
        const resolved = filters ?? { stage: "reach", isArchived: false };
        writer.set(conversation.ref, resolved, { merge: true });
        if (conversation.data().channel === "whatsapp") {
            const target = resolved.isArchived ? archivedStages : activeStages;
            target[resolved.stage] = (target[resolved.stage] ?? 0) + 1;
            if (resolved.isArchived)
                archivedTotal++;
            else
                activeTotal++;
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
});
exports.getConversationFilterCounts = (0, https_1.onCall)(config_1.callableOptions, async (request) => {
    if (!request.auth?.uid) {
        throw new https_1.HttpsError("unauthenticated", "Authentication required");
    }
    const email = String(request.auth.token.email ?? "").trim().toLowerCase();
    const [uidProfile, emailProfile] = await Promise.all([
        config_1.db.collection("users").doc(request.auth.uid).get(),
        email.length > 0
            ? config_1.db.collection("users").doc(email).get()
            : Promise.resolve(null),
    ]);
    const profile = emailProfile?.exists ? emailProfile.data() : uidProfile.data();
    const panels = Array.isArray(profile?.panels) ? profile.panels : [];
    if (profile?.isAdmin !== true && !panels.includes("chat")) {
        throw new https_1.HttpsError("permission-denied", "Chat access required");
    }
    const conversationQuery = config_1.db
        .collectionGroup(config_1.Collections.conversations)
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
        ...stages.map((stage) => activeQuery.where("stage", "==", stage).count().get()),
        ...stages.map((stage) => archivedQuery.where("stage", "==", stage).count().get()),
    ]);
    const activeStages = Object.fromEntries(stages.map((stage, index) => [stage, stageSnapshots[index].data().count]));
    const archivedStages = Object.fromEntries(stages.map((stage, index) => [
        stage,
        stageSnapshots[index + stages.length].data().count,
    ]));
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
});
//# sourceMappingURL=conversation-filters.js.map
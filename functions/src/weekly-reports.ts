import { onSchedule } from "firebase-functions/v2/scheduler";
import * as logger from "firebase-functions/logger";
import { db } from "./config";

type WorkGroups = {
  completedWork: string[];
  inProgressWork: string[];
  awaitingApprovalWork: string[];
};

function activeCycle(workflow: Record<string, unknown>): Record<string, unknown> {
  const cycles = Array.isArray(workflow.cycles) ? workflow.cycles : [];
  const valid = cycles.filter(
    (cycle): cycle is Record<string, unknown> =>
      typeof cycle === "object" && cycle !== null && typeof cycle.cycle === "number",
  );
  valid.sort((left, right) => Number(right.cycle) - Number(left.cycle));
  return valid[0] ?? workflow;
}

function taskLabel(feature: string): string {
  const separator = feature.indexOf(": ");
  return separator < 0 ? feature : feature.substring(separator + 2);
}

function groupWork(plans: FirebaseFirestore.QueryDocumentSnapshot[]): WorkGroups {
  const groups: WorkGroups = {
    completedWork: [],
    inProgressWork: [],
    awaitingApprovalWork: [],
  };
  for (const plan of plans) {
    const data = plan.data();
    const features = Array.isArray(data.features) ? data.features : [];
    const workflow = (data.taskWorkflow ?? {}) as Record<string, Record<string, unknown>>;
    for (const rawFeature of features) {
      if (typeof rawFeature !== "string") continue;
      const cycle = activeCycle(workflow[rawFeature] ?? {});
      const status = String(cycle.status ?? "assigned");
      const stage = String(cycle.draftStage ?? "");
      const label = taskLabel(rawFeature);
      if (status === "completed") {
        groups.completedWork.push(label);
      } else if (stage === "confirmation" || status === "awaitingConfirmation") {
        groups.awaitingApprovalWork.push(label);
      } else if (status === "started" || status === "draftCycle" || status === "inProgress") {
        groups.inProgressWork.push(label);
      }
    }
  }
  return groups;
}

export const publishWeeklyReports = onSchedule(
  { schedule: "every monday 09:00", timeZone: "Asia/Kolkata", region: "asia-south1" },
  async () => {
    const now = new Date();
    const periodEnd = new Date(now.getFullYear(), now.getMonth(), now.getDate() - 1);
    const periodStart = new Date(periodEnd);
    periodStart.setDate(periodEnd.getDate() - 6);
    const periodKey = periodEnd.toISOString().slice(0, 10);
    const [clients, plans] = await Promise.all([
      db.collection("clients").get(),
      db.collection("plans").get(),
    ]);

    for (const client of clients.docs) {
      const clientPlans = plans.docs.filter((plan) => plan.data().clientId === client.id);
      const groups = groupWork(clientPlans);
      await db.collection("weekly_reports").doc(`auto_${client.id}_${periodKey}`).set({
        clientId: client.id,
        periodStart,
        periodEnd,
        ...groups,
        summary: "Your weekly progress report is ready.",
        published: true,
        createdAt: new Date(),
        publishedAt: new Date(),
        automated: true,
      }, { merge: true });
    }
    logger.info(`Published weekly reports for ${clients.size} clients.`);
  },
);
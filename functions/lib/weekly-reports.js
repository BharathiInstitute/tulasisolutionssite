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
exports.publishWeeklyReports = void 0;
const scheduler_1 = require("firebase-functions/v2/scheduler");
const logger = __importStar(require("firebase-functions/logger"));
const config_1 = require("./config");
function activeCycle(workflow) {
    const cycles = Array.isArray(workflow.cycles) ? workflow.cycles : [];
    const valid = cycles.filter((cycle) => typeof cycle === "object" && cycle !== null && typeof cycle.cycle === "number");
    valid.sort((left, right) => Number(right.cycle) - Number(left.cycle));
    return valid[0] ?? workflow;
}
function taskLabel(feature) {
    const separator = feature.indexOf(": ");
    return separator < 0 ? feature : feature.substring(separator + 2);
}
function groupWork(plans) {
    const groups = {
        completedWork: [],
        inProgressWork: [],
        awaitingApprovalWork: [],
    };
    for (const plan of plans) {
        const data = plan.data();
        const features = Array.isArray(data.features) ? data.features : [];
        const workflow = (data.taskWorkflow ?? {});
        for (const rawFeature of features) {
            if (typeof rawFeature !== "string")
                continue;
            const cycle = activeCycle(workflow[rawFeature] ?? {});
            const status = String(cycle.status ?? "assigned");
            const stage = String(cycle.draftStage ?? "");
            const label = taskLabel(rawFeature);
            if (status === "completed") {
                groups.completedWork.push(label);
            }
            else if (stage === "confirmation" || status === "awaitingConfirmation") {
                groups.awaitingApprovalWork.push(label);
            }
            else if (status === "started" || status === "draftCycle" || status === "inProgress") {
                groups.inProgressWork.push(label);
            }
        }
    }
    return groups;
}
exports.publishWeeklyReports = (0, scheduler_1.onSchedule)({ schedule: "every monday 09:00", timeZone: "Asia/Kolkata", region: "asia-south1" }, async () => {
    const now = new Date();
    const periodEnd = new Date(now.getFullYear(), now.getMonth(), now.getDate() - 1);
    const periodStart = new Date(periodEnd);
    periodStart.setDate(periodEnd.getDate() - 6);
    const periodKey = periodEnd.toISOString().slice(0, 10);
    const [clients, plans] = await Promise.all([
        config_1.db.collection("clients").get(),
        config_1.db.collection("plans").get(),
    ]);
    for (const client of clients.docs) {
        const clientPlans = plans.docs.filter((plan) => plan.data().clientId === client.id);
        const groups = groupWork(clientPlans);
        await config_1.db.collection("weekly_reports").doc(`auto_${client.id}_${periodKey}`).set({
            clientId: client.id,
            periodStart,
            periodEnd,
            ...groups,
            summary: "Your weekly progress report is ready in your client portal.",
            published: true,
            createdAt: new Date(),
            publishedAt: new Date(),
            automated: true,
        }, { merge: true });
    }
    logger.info(`Published weekly reports for ${clients.size} clients.`);
});
//# sourceMappingURL=weekly-reports.js.map
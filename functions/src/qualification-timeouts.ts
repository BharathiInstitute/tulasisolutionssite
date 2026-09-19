import { onSchedule } from "firebase-functions/v2/scheduler";
import { processQualificationTimeouts } from "./lead-qualification";

export const qualificationTimeouts = onSchedule(
  { schedule: "every 15 minutes", region: "asia-south1" },
  processQualificationTimeouts,
);
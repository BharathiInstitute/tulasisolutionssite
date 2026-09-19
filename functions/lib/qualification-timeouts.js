"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.qualificationTimeouts = void 0;
const scheduler_1 = require("firebase-functions/v2/scheduler");
const lead_qualification_1 = require("./lead-qualification");
exports.qualificationTimeouts = (0, scheduler_1.onSchedule)({ schedule: "every 15 minutes", region: "asia-south1" }, lead_qualification_1.processQualificationTimeouts);
//# sourceMappingURL=qualification-timeouts.js.map
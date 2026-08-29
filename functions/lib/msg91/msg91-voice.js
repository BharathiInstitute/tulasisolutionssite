"use strict";
/**
 * MSG91 Voice/Call API Wrapper
 * Handles outbound voice calls, voice OTP, and broadcast via MSG91 Voice API.
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.makeVoiceCall = makeVoiceCall;
exports.sendVoiceOTP = sendVoiceOTP;
exports.sendVoiceBroadcast = sendVoiceBroadcast;
exports.getCallLogs = getCallLogs;
exports.getCallStatus = getCallStatus;
const msg91_client_1 = require("./msg91-client");
// ── Make Voice Call (IVR flow) ───────────────────────────────
async function makeVoiceCall(to, flowId, variables) {
    const recipients = [
        { mobiles: to, ...variables },
    ];
    const payload = {
        flow_id: flowId,
        recipients,
    };
    const result = await (0, msg91_client_1.sendRequest)(`${msg91_client_1.MSG91_VOICE_URL}/flow/`, payload);
    return {
        success: result.type === "success",
        requestId: result.request_id,
        message: result.message,
    };
}
// ── Send Voice OTP ───────────────────────────────────────────
async function sendVoiceOTP(mobile, templateId, otpLength = 6) {
    const payload = {
        mobile,
        template_id: templateId,
        otp_length: otpLength,
        otp_type: "voice",
    };
    const result = await (0, msg91_client_1.sendRequest)(`${msg91_client_1.MSG91_BASE_URL}/otp`, payload);
    return {
        success: result.type === "success",
        requestId: result.request_id,
        message: result.message,
    };
}
// ── Voice Broadcast ──────────────────────────────────────────
async function sendVoiceBroadcast(flowId, recipients) {
    // MSG91 Voice Flow API handles bulk natively
    const batchSize = 500;
    const batches = [];
    for (let i = 0; i < recipients.length; i += batchSize) {
        batches.push(recipients.slice(i, i + batchSize));
    }
    let totalSuccess = true;
    let lastRequestId;
    for (const batch of batches) {
        const payload = {
            flow_id: flowId,
            recipients: batch.map((r) => ({
                mobiles: r.mobile,
                ...Object.fromEntries(Object.entries(r).filter(([k]) => k !== "mobile")),
            })),
        };
        const result = await (0, msg91_client_1.sendRequest)(`${msg91_client_1.MSG91_VOICE_URL}/flow/`, payload);
        if (result.type !== "success")
            totalSuccess = false;
        lastRequestId = result.request_id ?? lastRequestId;
    }
    return {
        success: totalSuccess,
        requestId: lastRequestId,
        message: `Broadcast to ${recipients.length} recipients in ${batches.length} batch(es)`,
    };
}
// ── Get Call Logs ────────────────────────────────────────────
async function getCallLogs(requestId) {
    const params = {};
    if (requestId)
        params.request_id = requestId;
    const result = await (0, msg91_client_1.sendRequest)(`${msg91_client_1.MSG91_VOICE_URL}/logs`, params, "GET");
    const logs = (result.data ?? result.logs ?? []);
    return logs.map((l) => ({
        id: String(l.id ?? ""),
        to: String(l.to ?? l.number ?? ""),
        status: String(l.status ?? "unknown"),
        duration: Number(l.duration ?? 0),
        startTime: l.startTime,
        endTime: l.endTime,
        recordingUrl: l.recordingUrl,
    }));
}
// ── Get Call Status ──────────────────────────────────────────
async function getCallStatus(requestId) {
    const result = await (0, msg91_client_1.sendRequest)(`${msg91_client_1.MSG91_VOICE_URL}/report`, { request_id: requestId }, "GET");
    const data = (result.data ?? result);
    return {
        total: Number(data.total ?? 0),
        answered: Number(data.answered ?? 0),
        failed: Number(data.failed ?? 0),
        pending: Number(data.pending ?? 0),
    };
}
//# sourceMappingURL=msg91-voice.js.map
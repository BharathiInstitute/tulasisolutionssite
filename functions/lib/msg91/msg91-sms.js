"use strict";
/**
 * MSG91 SMS API Wrapper
 * Handles transactional SMS, OTP, and bulk SMS via MSG91 Flow API.
 * All SMS in India must use DLT-registered templates.
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.sendSMS = sendSMS;
exports.sendBulkSMS = sendBulkSMS;
exports.sendOTP = sendOTP;
exports.verifyOTP = verifyOTP;
exports.resendOTP = resendOTP;
exports.getSMSBalance = getSMSBalance;
exports.getSMSReport = getSMSReport;
const msg91_client_1 = require("./msg91-client");
// ── Send SMS via Flow API (DLT compliant) ────────────────────
async function sendSMS(flowId, recipients, senderId) {
    const payload = {
        flow_id: flowId,
        sender: senderId ?? (0, msg91_client_1.getSenderId)(),
        recipients: recipients.map((r) => ({
            mobiles: r.mobile,
            ...Object.fromEntries(Object.entries(r).filter(([k]) => k !== "mobile")),
        })),
    };
    const result = await (0, msg91_client_1.sendRequest)(`${msg91_client_1.MSG91_BASE_URL}/flow/`, payload);
    return {
        success: result.type === "success",
        requestId: result.request_id,
        message: result.message,
    };
}
// ── Send Bulk SMS (campaign) ─────────────────────────────────
async function sendBulkSMS(flowId, recipients, senderId) {
    // MSG91 Flow API handles bulk natively (up to 500 per request)
    // Split into batches if needed
    const batchSize = 500;
    const batches = [];
    for (let i = 0; i < recipients.length; i += batchSize) {
        batches.push(recipients.slice(i, i + batchSize));
    }
    let totalSuccess = true;
    let lastRequestId;
    for (const batch of batches) {
        const result = await sendSMS(flowId, batch, senderId);
        if (!result.success)
            totalSuccess = false;
        lastRequestId = result.requestId ?? lastRequestId;
    }
    return {
        success: totalSuccess,
        requestId: lastRequestId,
        message: `Sent ${recipients.length} SMS in ${batches.length} batch(es)`,
    };
}
// ── Send OTP ─────────────────────────────────────────────────
async function sendOTP(mobile, templateId, otpLength = 6) {
    const payload = {
        mobile,
        template_id: templateId,
        otp_length: otpLength,
    };
    const result = await (0, msg91_client_1.sendRequest)(`${msg91_client_1.MSG91_BASE_URL}/otp`, payload);
    return {
        success: result.type === "success",
        requestId: result.request_id,
        type: result.type,
        message: result.message,
    };
}
// ── Verify OTP ───────────────────────────────────────────────
async function verifyOTP(mobile, otp) {
    const result = await (0, msg91_client_1.sendRequest)(`${msg91_client_1.MSG91_BASE_URL}/otp/verify`, { mobile, otp });
    return {
        success: result.type === "success",
        type: result.type,
        message: result.message,
    };
}
// ── Resend OTP ───────────────────────────────────────────────
async function resendOTP(mobile, retryType = "text") {
    const result = await (0, msg91_client_1.sendRequest)(`${msg91_client_1.MSG91_BASE_URL}/otp/retry`, { mobile, retrytype: retryType });
    return {
        success: result.type === "success",
        type: result.type,
        message: result.message,
    };
}
// ── Get SMS Balance ──────────────────────────────────────────
async function getSMSBalance(route) {
    const result = await (0, msg91_client_1.sendRequest)(`${msg91_client_1.MSG91_BASE_URL}/balance.php`, { type: route ?? process.env.MSG91_ROUTE ?? "4" }, "GET");
    return {
        available: Number(result.balance ?? result.available ?? 0),
        route: String(result.route ?? route ?? "4"),
    };
}
// ── Get SMS Delivery Report ──────────────────────────────────
async function getSMSReport(requestId) {
    const result = await (0, msg91_client_1.sendRequest)(`${msg91_client_1.MSG91_BASE_URL}/report.php`, { request_id: requestId }, "GET");
    const data = result.data ?? result;
    return {
        requestId,
        total: Number(data.total ?? 0),
        delivered: Number(data.delivered ?? 0),
        failed: Number(data.failed ?? 0),
        pending: Number(data.pending ?? 0),
    };
}
//# sourceMappingURL=msg91-sms.js.map
/**
 * MSG91 SMS API Wrapper
 * Handles transactional SMS, OTP, and bulk SMS via MSG91 Flow API.
 * All SMS in India must use DLT-registered templates.
 */

import { sendRequest, MSG91_BASE_URL, getSenderId } from "./msg91-client";

// ── Types ────────────────────────────────────────────────────
export interface SMSRecipient {
  mobile: string;
  [key: string]: string; // Dynamic template variables: VAR1, VAR2, etc.
}

export interface SMSSendResult {
  success: boolean;
  requestId?: string;
  message?: string;
}

export interface OTPResult {
  success: boolean;
  requestId?: string;
  type?: string;
  message?: string;
}

export interface SMSBalance {
  available: number;
  route: string;
}

export interface SMSReport {
  requestId: string;
  total: number;
  delivered: number;
  failed: number;
  pending: number;
}

// ── Send SMS via Flow API (DLT compliant) ────────────────────
export async function sendSMS(
  flowId: string,
  recipients: SMSRecipient[],
  senderId?: string,
): Promise<SMSSendResult> {
  const payload = {
    flow_id: flowId,
    sender: senderId ?? getSenderId(),
    recipients: recipients.map((r) => ({
      mobiles: r.mobile,
      ...Object.fromEntries(
        Object.entries(r).filter(([k]) => k !== "mobile"),
      ),
    })),
  };

  const result = await sendRequest<Record<string, unknown>>(
    `${MSG91_BASE_URL}/flow/`,
    payload,
  );

  return {
    success: result.type === "success",
    requestId: result.request_id as string | undefined,
    message: result.message as string | undefined,
  };
}

// ── Send Bulk SMS (campaign) ─────────────────────────────────
export async function sendBulkSMS(
  flowId: string,
  recipients: SMSRecipient[],
  senderId?: string,
): Promise<SMSSendResult> {
  // MSG91 Flow API handles bulk natively (up to 500 per request)
  // Split into batches if needed
  const batchSize = 500;
  const batches: SMSRecipient[][] = [];

  for (let i = 0; i < recipients.length; i += batchSize) {
    batches.push(recipients.slice(i, i + batchSize));
  }

  let totalSuccess = true;
  let lastRequestId: string | undefined;

  for (const batch of batches) {
    const result = await sendSMS(flowId, batch, senderId);
    if (!result.success) totalSuccess = false;
    lastRequestId = result.requestId ?? lastRequestId;
  }

  return {
    success: totalSuccess,
    requestId: lastRequestId,
    message: `Sent ${recipients.length} SMS in ${batches.length} batch(es)`,
  };
}

// ── Send OTP ─────────────────────────────────────────────────
export async function sendOTP(
  mobile: string,
  templateId: string,
  otpLength: number = 6,
): Promise<OTPResult> {
  const payload = {
    mobile,
    template_id: templateId,
    otp_length: otpLength,
  };

  const result = await sendRequest<Record<string, unknown>>(
    `${MSG91_BASE_URL}/otp`,
    payload,
  );

  return {
    success: result.type === "success",
    requestId: result.request_id as string | undefined,
    type: result.type as string | undefined,
    message: result.message as string | undefined,
  };
}

// ── Verify OTP ───────────────────────────────────────────────
export async function verifyOTP(
  mobile: string,
  otp: string,
): Promise<OTPResult> {
  const result = await sendRequest<Record<string, unknown>>(
    `${MSG91_BASE_URL}/otp/verify`,
    { mobile, otp },
  );

  return {
    success: result.type === "success",
    type: result.type as string | undefined,
    message: result.message as string | undefined,
  };
}

// ── Resend OTP ───────────────────────────────────────────────
export async function resendOTP(
  mobile: string,
  retryType: "text" | "voice" = "text",
): Promise<OTPResult> {
  const result = await sendRequest<Record<string, unknown>>(
    `${MSG91_BASE_URL}/otp/retry`,
    { mobile, retrytype: retryType },
  );

  return {
    success: result.type === "success",
    type: result.type as string | undefined,
    message: result.message as string | undefined,
  };
}

// ── Get SMS Balance ──────────────────────────────────────────
export async function getSMSBalance(
  route?: string,
): Promise<SMSBalance> {
  const result = await sendRequest<Record<string, unknown>>(
    `${MSG91_BASE_URL}/balance.php`,
    { type: route ?? process.env.MSG91_ROUTE ?? "4" },
    "GET",
  );

  return {
    available: Number(result.balance ?? result.available ?? 0),
    route: String(result.route ?? route ?? "4"),
  };
}

// ── Get SMS Delivery Report ──────────────────────────────────
export async function getSMSReport(
  requestId: string,
): Promise<SMSReport> {
  const result = await sendRequest<Record<string, unknown>>(
    `${MSG91_BASE_URL}/report.php`,
    { request_id: requestId },
    "GET",
  );

  const data = result.data as Record<string, unknown> ?? result;
  return {
    requestId,
    total: Number(data.total ?? 0),
    delivered: Number(data.delivered ?? 0),
    failed: Number(data.failed ?? 0),
    pending: Number(data.pending ?? 0),
  };
}

/**
 * MSG91 Voice/Call API Wrapper
 * Handles outbound voice calls, voice OTP, and broadcast via MSG91 Voice API.
 */

import { sendRequest, MSG91_BASE_URL, MSG91_VOICE_URL } from "./msg91-client";

// ── Types ────────────────────────────────────────────────────
export interface VoiceCallResult {
  success: boolean;
  requestId?: string;
  message?: string;
}

export interface CallLog {
  id: string;
  to: string;
  status: string; // answered, missed, busy, failed, no-answer
  duration: number;
  startTime?: string;
  endTime?: string;
  recordingUrl?: string;
}

export interface VoiceRecipient {
  mobile: string;
  [key: string]: string;
}

// ── Make Voice Call (IVR flow) ───────────────────────────────
export async function makeVoiceCall(
  to: string,
  flowId: string,
  variables?: Record<string, string>,
): Promise<VoiceCallResult> {
  const recipients: Record<string, string>[] = [
    { mobiles: to, ...variables },
  ];

  const payload = {
    flow_id: flowId,
    recipients,
  };

  const result = await sendRequest<Record<string, unknown>>(
    `${MSG91_VOICE_URL}/flow/`,
    payload,
  );

  return {
    success: result.type === "success",
    requestId: result.request_id as string | undefined,
    message: result.message as string | undefined,
  };
}

// ── Send Voice OTP ───────────────────────────────────────────
export async function sendVoiceOTP(
  mobile: string,
  templateId: string,
  otpLength: number = 6,
): Promise<VoiceCallResult> {
  const payload = {
    mobile,
    template_id: templateId,
    otp_length: otpLength,
    otp_type: "voice",
  };

  const result = await sendRequest<Record<string, unknown>>(
    `${MSG91_BASE_URL}/otp`,
    payload,
  );

  return {
    success: result.type === "success",
    requestId: result.request_id as string | undefined,
    message: result.message as string | undefined,
  };
}

// ── Voice Broadcast ──────────────────────────────────────────
export async function sendVoiceBroadcast(
  flowId: string,
  recipients: VoiceRecipient[],
): Promise<VoiceCallResult> {
  // MSG91 Voice Flow API handles bulk natively
  const batchSize = 500;
  const batches: VoiceRecipient[][] = [];

  for (let i = 0; i < recipients.length; i += batchSize) {
    batches.push(recipients.slice(i, i + batchSize));
  }

  let totalSuccess = true;
  let lastRequestId: string | undefined;

  for (const batch of batches) {
    const payload = {
      flow_id: flowId,
      recipients: batch.map((r) => ({
        mobiles: r.mobile,
        ...Object.fromEntries(
          Object.entries(r).filter(([k]) => k !== "mobile"),
        ),
      })),
    };

    const result = await sendRequest<Record<string, unknown>>(
      `${MSG91_VOICE_URL}/flow/`,
      payload,
    );

    if (result.type !== "success") totalSuccess = false;
    lastRequestId = (result.request_id as string) ?? lastRequestId;
  }

  return {
    success: totalSuccess,
    requestId: lastRequestId,
    message: `Broadcast to ${recipients.length} recipients in ${batches.length} batch(es)`,
  };
}

// ── Get Call Logs ────────────────────────────────────────────
export async function getCallLogs(
  requestId?: string,
): Promise<CallLog[]> {
  const params: Record<string, string> = {};
  if (requestId) params.request_id = requestId;

  const result = await sendRequest<Record<string, unknown>>(
    `${MSG91_VOICE_URL}/logs`,
    params,
    "GET",
  );

  const logs = (result.data ?? result.logs ?? []) as Record<string, unknown>[];
  return logs.map((l) => ({
    id: String(l.id ?? ""),
    to: String(l.to ?? l.number ?? ""),
    status: String(l.status ?? "unknown"),
    duration: Number(l.duration ?? 0),
    startTime: l.startTime as string | undefined,
    endTime: l.endTime as string | undefined,
    recordingUrl: l.recordingUrl as string | undefined,
  }));
}

// ── Get Call Status ──────────────────────────────────────────
export async function getCallStatus(
  requestId: string,
): Promise<{ total: number; answered: number; failed: number; pending: number }> {
  const result = await sendRequest<Record<string, unknown>>(
    `${MSG91_VOICE_URL}/report`,
    { request_id: requestId },
    "GET",
  );

  const data = (result.data ?? result) as Record<string, unknown>;
  return {
    total: Number(data.total ?? 0),
    answered: Number(data.answered ?? 0),
    failed: Number(data.failed ?? 0),
    pending: Number(data.pending ?? 0),
  };
}

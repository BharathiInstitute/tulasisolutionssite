/**
 * MSG91 Shared HTTP Client
 * All MSG91 API calls go through this module for consistent auth, retry, and error handling.
 */

import axios, { AxiosError, AxiosRequestConfig } from "axios";
import * as admin from "firebase-admin";
import FormData from "form-data";

// ── Base URLs ────────────────────────────────────────────────
export const MSG91_BASE_URL = "https://control.msg91.com/api/v5";
export const MSG91_WA_URL = "https://api.msg91.com/api/v5/whatsapp";
export const MSG91_VOICE_URL = "https://api.msg91.com/api/v5/voice";

// ── Config ───────────────────────────────────────────────────
function getAuthKey(): string {
  const key = process.env.MSG91_AUTH_KEY;
  if (!key) {
    throw new Error("MSG91_AUTH_KEY environment variable is not set");
  }
  return key;
}

export function getSenderId(): string {
  return process.env.MSG91_SENDER_ID ?? "TULASI";
}

export function getWhatsAppIntegratedNumber(): string {
  const num = process.env.MSG91_WA_IBNID;
  if (!num) {
    throw new Error("MSG91_WA_IBNID environment variable is not set");
  }
  return num;
}

/**
 * Get the WhatsApp integrated number for a specific client.
 * Looks up `whatsappNumber` field on the client document in Firestore.
 * Falls back to the global MSG91_WA_IBNID env var if not set per-client.
 */
export async function getClientWhatsAppNumber(clientId: string): Promise<string> {
  const db = admin.firestore();
  const clientDoc = await db.collection("clients").doc(clientId).get();
  const data = clientDoc.data();
  if (data?.whatsappNumber) {
    return data.whatsappNumber;
  }
  // Fallback to global env var
  return getWhatsAppIntegratedNumber();
}

// ── Error mapping ────────────────────────────────────────────
interface MSG91Error {
  code: string;
  message: string;
  details?: string;
}

const ERROR_MAP: Record<string, string> = {
  "101": "Authentication failed — invalid authkey",
  "102": "Invalid sender ID",
  "103": "Invalid mobile number",
  "201": "Insufficient balance",
  "301": "Template not found or not approved",
  "401": "WhatsApp API access is unauthorized for this auth key or integrated number",
  "429": "Rate limit exceeded",
  "501": "Internal MSG91 error",
};

export function mapMSG91Error(statusCode: number, responseData: unknown): MSG91Error {
  const data = responseData as Record<string, unknown>;
  const rawCode = String(data?.code ?? data?.type ?? statusCode);
  const providerMessage = typeof data?.message === "string" && data.message.trim()
    ? data.message
    : typeof data?.errors === "string" && data.errors.trim()
      ? data.errors
      : undefined;
  return {
    code: rawCode,
    message: ERROR_MAP[rawCode] ?? providerMessage ?? "Unknown MSG91 error",
    details: JSON.stringify(data),
  };
}

// ── HTTP Client with retry ───────────────────────────────────
const MAX_RETRIES = 3;
const RETRY_DELAY_MS = 1000;
const RETRYABLE_STATUS = [429, 500, 502, 503, 504];

export async function sendRequest<T = Record<string, unknown>>(
  endpoint: string,
  payload?: Record<string, unknown>,
  method: "GET" | "POST" | "PUT" | "DELETE" = "POST",
): Promise<T> {
  const config: AxiosRequestConfig = {
    method,
    url: endpoint,
    headers: {
      authkey: getAuthKey(),
      "Content-Type": "application/json",
    },
    timeout: 30_000,
  };

  if (method === "GET") {
    config.params = payload;
  } else {
    config.data = payload;
  }

  let lastError: Error | undefined;

  for (let attempt = 0; attempt <= MAX_RETRIES; attempt++) {
    try {
      const response = await axios(config);
      return response.data as T;
    } catch (err) {
      const axiosErr = err as AxiosError;
      const status = axiosErr.response?.status ?? 0;

      if (attempt < MAX_RETRIES && RETRYABLE_STATUS.includes(status)) {
        const delay = RETRY_DELAY_MS * Math.pow(2, attempt);
        await new Promise((resolve) => setTimeout(resolve, delay));
        lastError = new Error(
          `MSG91 ${endpoint} attempt ${attempt + 1} failed (HTTP ${status})`
        );
        continue;
      }

      // Non-retryable or max retries exceeded
      const mapped = mapMSG91Error(status, axiosErr.response?.data);
      throw new Error(`MSG91 error [${mapped.code}]: ${mapped.message} | Details: ${mapped.details}`);
    }
  }

  throw lastError ?? new Error("MSG91 request failed after retries");
}

export async function uploadWhatsAppSampleMedia(
  mediaUrl: string,
  integratedNumber: string,
): Promise<string> {
  const mediaResponse = await axios.get<ArrayBuffer>(mediaUrl, {
    responseType: "arraybuffer",
    timeout: 30_000,
  });
  const contentType = String(mediaResponse.headers["content-type"] ?? "image/jpeg");
  const extension = contentType.includes("png") ? "png" : "jpg";
  const form = new FormData();
  form.append("whatsapp_number", integratedNumber);
  form.append("media", Buffer.from(mediaResponse.data), {
    filename: `template-header.${extension}`,
    contentType,
  });

  const response = await axios.post<Record<string, unknown>>(
    `${MSG91_WA_URL}/sample-media-upload/`,
    form,
    {
      headers: {
        authkey: getAuthKey(),
        ...form.getHeaders(),
      },
      timeout: 30_000,
      maxBodyLength: Infinity,
    },
  );
  const data = response.data.data as Record<string, unknown> | undefined;
  const handle = data?.url;
  if (response.data.status !== "success" || typeof handle !== "string" || !handle) {
    throw new Error(`MSG91 sample media upload failed: ${JSON.stringify(response.data)}`);
  }
  return handle;
}

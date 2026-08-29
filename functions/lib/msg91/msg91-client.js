"use strict";
/**
 * MSG91 Shared HTTP Client
 * All MSG91 API calls go through this module for consistent auth, retry, and error handling.
 */
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
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.MSG91_VOICE_URL = exports.MSG91_WA_URL = exports.MSG91_BASE_URL = void 0;
exports.getSenderId = getSenderId;
exports.getWhatsAppIntegratedNumber = getWhatsAppIntegratedNumber;
exports.getClientWhatsAppNumber = getClientWhatsAppNumber;
exports.mapMSG91Error = mapMSG91Error;
exports.sendRequest = sendRequest;
const axios_1 = __importDefault(require("axios"));
const admin = __importStar(require("firebase-admin"));
// ── Base URLs ────────────────────────────────────────────────
exports.MSG91_BASE_URL = "https://control.msg91.com/api/v5";
exports.MSG91_WA_URL = "https://api.msg91.com/api/v5/whatsapp";
exports.MSG91_VOICE_URL = "https://api.msg91.com/api/v5/voice";
// ── Config ───────────────────────────────────────────────────
function getAuthKey() {
    const key = process.env.MSG91_AUTH_KEY;
    if (!key) {
        throw new Error("MSG91_AUTH_KEY environment variable is not set");
    }
    return key;
}
function getSenderId() {
    return process.env.MSG91_SENDER_ID ?? "TULASI";
}
function getWhatsAppIntegratedNumber() {
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
async function getClientWhatsAppNumber(clientId) {
    const db = admin.firestore();
    const clientDoc = await db.collection("clients").doc(clientId).get();
    const data = clientDoc.data();
    if (data?.whatsappNumber) {
        return data.whatsappNumber;
    }
    // Fallback to global env var
    return getWhatsAppIntegratedNumber();
}
const ERROR_MAP = {
    "101": "Authentication failed — invalid authkey",
    "102": "Invalid sender ID",
    "103": "Invalid mobile number",
    "201": "Insufficient balance",
    "301": "Template not found or not approved",
    "401": "WhatsApp API access is unauthorized for this auth key or integrated number",
    "429": "Rate limit exceeded",
    "501": "Internal MSG91 error",
};
function mapMSG91Error(statusCode, responseData) {
    const data = responseData;
    const rawCode = String(data?.code ?? data?.type ?? statusCode);
    return {
        code: rawCode,
        message: ERROR_MAP[rawCode] ?? data?.message ?? "Unknown MSG91 error",
        details: JSON.stringify(data),
    };
}
// ── HTTP Client with retry ───────────────────────────────────
const MAX_RETRIES = 3;
const RETRY_DELAY_MS = 1000;
const RETRYABLE_STATUS = [429, 500, 502, 503, 504];
async function sendRequest(endpoint, payload, method = "POST") {
    const config = {
        method,
        url: endpoint,
        headers: {
            authkey: getAuthKey(),
            "Content-Type": "application/json",
        },
        timeout: 30000,
    };
    if (method === "GET") {
        config.params = payload;
    }
    else {
        config.data = payload;
    }
    let lastError;
    for (let attempt = 0; attempt <= MAX_RETRIES; attempt++) {
        try {
            const response = await (0, axios_1.default)(config);
            return response.data;
        }
        catch (err) {
            const axiosErr = err;
            const status = axiosErr.response?.status ?? 0;
            if (attempt < MAX_RETRIES && RETRYABLE_STATUS.includes(status)) {
                const delay = RETRY_DELAY_MS * Math.pow(2, attempt);
                await new Promise((resolve) => setTimeout(resolve, delay));
                lastError = new Error(`MSG91 ${endpoint} attempt ${attempt + 1} failed (HTTP ${status})`);
                continue;
            }
            // Non-retryable or max retries exceeded
            const mapped = mapMSG91Error(status, axiosErr.response?.data);
            throw new Error(`MSG91 error [${mapped.code}]: ${mapped.message} | Details: ${mapped.details}`);
        }
    }
    throw lastError ?? new Error("MSG91 request failed after retries");
}
//# sourceMappingURL=msg91-client.js.map
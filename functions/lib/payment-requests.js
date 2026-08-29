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
exports.sendPaymentRequest = void 0;
const https_1 = require("firebase-functions/v2/https");
const logger = __importStar(require("firebase-functions/logger"));
const config_1 = require("./config");
const UPI_ID = "9666464460-3@ybl";
const PAYEE_NAME = "Tulasi Solutions";
exports.sendPaymentRequest = (0, https_1.onCall)(config_1.callableOptions, async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
        throw new https_1.HttpsError("unauthenticated", "Authentication required");
    }
    const adminDoc = await config_1.db.collection(config_1.Collections.users).doc(uid).get();
    if (adminDoc.data()?.isAdmin !== true) {
        throw new https_1.HttpsError("permission-denied", "Only administrators can send payment requests");
    }
    const paymentId = String(request.data?.paymentId ?? "").trim();
    const requestId = String(request.data?.requestId ?? "").trim();
    if (!paymentId) {
        throw new https_1.HttpsError("invalid-argument", "paymentId is required");
    }
    if (!/^[a-zA-Z0-9-]{1,80}$/.test(requestId)) {
        throw new https_1.HttpsError("invalid-argument", "A valid requestId is required");
    }
    const paymentRef = config_1.db.collection(config_1.Collections.payments).doc(paymentId);
    const paymentDoc = await paymentRef.get();
    if (!paymentDoc.exists) {
        throw new https_1.HttpsError("not-found", "Payment record not found");
    }
    const payment = paymentDoc.data();
    const clientId = String(payment.clientId ?? "").trim();
    const amount = Number(payment.amount);
    if (!clientId || !Number.isFinite(amount) || amount <= 0) {
        throw new https_1.HttpsError("failed-precondition", "Payment details are invalid");
    }
    const clientDoc = await config_1.db.collection(config_1.Collections.clients).doc(clientId).get();
    if (!clientDoc.exists) {
        throw new https_1.HttpsError("not-found", "Client record not found");
    }
    const client = clientDoc.data();
    const phone = String(client.contactPhone ?? "").trim();
    if (!phone) {
        throw new https_1.HttpsError("failed-precondition", "The client does not have a phone number");
    }
    const clientName = String(client.ownerName ?? payment.clientName ?? client.name ?? "Customer").trim();
    const planName = String(payment.planName ?? "Selected plan").trim();
    const reference = String(payment.transactionId ?? paymentId).trim();
    const amountLabel = amount.toFixed(2);
    const query = new URLSearchParams({
        pa: UPI_ID,
        pn: PAYEE_NAME,
        am: amountLabel,
        cu: "INR",
        tr: reference,
        tn: `Payment for ${planName}`,
    });
    const upiLink = `upi://pay?${query.toString()}`;
    const message = [
        `Hello ${clientName},`,
        "",
        `Payment request from ${PAYEE_NAME}`,
        `Plan: ${planName}`,
        `Amount: INR ${amountLabel}`,
        `UPI ID: ${UPI_ID}`,
        `Reference: ${reference}`,
        "",
        `Pay securely using this UPI link: ${upiLink}`,
        "",
        "Please verify the payee name and amount in your UPI app before paying. After payment, please share the confirmation.",
    ].join("\n");
    const queueRef = config_1.db
        .collection((0, config_1.clientCol)(clientId, config_1.Collections.messageQueue))
        .doc(`payment-${paymentId}-${requestId}`);
    await config_1.db.runTransaction(async (transaction) => {
        const existingQueueDoc = await transaction.get(queueRef);
        if (existingQueueDoc.exists)
            return;
        transaction.set(queueRef, {
            contactId: null,
            phone,
            content: message,
            channel: "whatsapp",
            status: "pending",
            createdAt: new Date(),
            createdBy: uid,
            paymentId,
            retries: 0,
        });
    });
    await paymentRef.update({
        paymentLink: upiLink,
        requestSentDate: new Date(),
        requestSentBy: request.auth?.token.email ?? uid,
    });
    logger.info("UPI payment request queued", { paymentId, clientId, uid });
    return { success: true, upiLink, message };
});
//# sourceMappingURL=payment-requests.js.map
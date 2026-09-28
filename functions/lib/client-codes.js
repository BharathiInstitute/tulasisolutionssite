"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.assignClientCode = void 0;
const firestore_1 = require("firebase-admin/firestore");
const firestore_2 = require("firebase-functions/v2/firestore");
const config_1 = require("./config");
const counterRef = config_1.db.collection("systemCounters").doc("clientCodes");
exports.assignClientCode = (0, firestore_2.onDocumentCreated)({
    document: "clients/{clientId}",
    region: "asia-south1",
}, async (event) => {
    const client = event.data;
    if (!client)
        return;
    await config_1.db.runTransaction(async (transaction) => {
        const latestClient = await transaction.get(client.ref);
        if (!latestClient.exists)
            return;
        const counter = await transaction.get(counterRef);
        const nextValue = Number(counter.data()?.nextValue ?? 1);
        const existingCode = String(latestClient.data()?.clientCode ?? "").trim().toUpperCase();
        const suppliedNumber = /^A(\d+)$/.exec(existingCode);
        if (existingCode) {
            const followingValue = suppliedNumber
                ? Number(suppliedNumber[1]) + 1
                : nextValue;
            if (followingValue > nextValue) {
                transaction.set(counterRef, {
                    nextValue: followingValue,
                    updatedAt: firestore_1.FieldValue.serverTimestamp(),
                }, { merge: true });
            }
            return;
        }
        const clientCode = `A${String(nextValue).padStart(4, "0")}`;
        transaction.set(counterRef, { nextValue: nextValue + 1, updatedAt: firestore_1.FieldValue.serverTimestamp() }, { merge: true });
        transaction.update(client.ref, { clientCode });
    });
});
//# sourceMappingURL=client-codes.js.map
import { FieldValue } from "firebase-admin/firestore";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { db } from "./config";

const counterRef = db.collection("systemCounters").doc("clientCodes");

export const assignClientCode = onDocumentCreated(
  {
    document: "clients/{clientId}",
    region: "asia-south1",
  },
  async (event) => {
    const client = event.data;
    if (!client) return;

    await db.runTransaction(async (transaction) => {
      const latestClient = await transaction.get(client.ref);
      if (!latestClient.exists) return;

      const counter = await transaction.get(counterRef);
      const nextValue = Number(counter.data()?.nextValue ?? 1);
      const existingCode = String(
        latestClient.data()?.clientCode ?? "",
      ).trim().toUpperCase();
      const suppliedNumber = /^A(\d+)$/.exec(existingCode);
      if (existingCode) {
        const followingValue = suppliedNumber
          ? Number(suppliedNumber[1]) + 1
          : nextValue;
        if (followingValue > nextValue) {
          transaction.set(
            counterRef,
            {
              nextValue: followingValue,
              updatedAt: FieldValue.serverTimestamp(),
            },
            { merge: true },
          );
        }
        return;
      }

      const clientCode = `A${String(nextValue).padStart(4, "0")}`;

      transaction.set(
        counterRef,
        { nextValue: nextValue + 1, updatedAt: FieldValue.serverTimestamp() },
        { merge: true },
      );
      transaction.update(client.ref, { clientCode });
    });
  },
);
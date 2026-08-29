import { createHash } from "crypto";
import { FieldValue } from "firebase-admin/firestore";
import { onRequest } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import { Collections, db } from "./config";

const MAX_LENGTHS = {
  name: 100,
  business: 120,
  category: 50,
  phone: 30,
  email: 254,
  message: 2000,
};

function clean(value: unknown, maxLength: number): string {
  return typeof value === "string" ? value.trim().slice(0, maxLength) : "";
}

function isValidEmail(value: string): boolean {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value);
}

function isValidPhone(value: string): boolean {
  return value.replace(/\D/g, "").length >= 10;
}

export const submitWebsiteLead = onRequest(
  { region: "asia-south1", cors: true, maxInstances: 10 },
  async (request, response) => {
    if (request.method !== "POST") {
      response.set("Allow", "POST").status(405).json({ error: "Method not allowed" });
      return;
    }

    const body = request.body ?? {};
    if (clean(body.website, 100)) {
      response.status(200).json({ ok: true });
      return;
    }

    const lead = {
      ownerName: clean(body.name, MAX_LENGTHS.name),
      name: clean(body.business, MAX_LENGTHS.business),
      category: clean(body.category, MAX_LENGTHS.category),
      contactPhone: clean(body.phone, MAX_LENGTHS.phone),
      contactEmail: clean(body.email, MAX_LENGTHS.email).toLowerCase(),
      message: clean(body.message, MAX_LENGTHS.message),
    };

    const fieldErrors: Record<string, string> = {};
    if (!lead.ownerName) fieldErrors.name = "Please enter your name.";
    if (!lead.name) fieldErrors.business = "Please enter your business name.";
    if (!lead.category) fieldErrors.category = "Please select a business category.";
    if (!lead.contactPhone) {
      fieldErrors.phone = "Please enter your phone or WhatsApp number.";
    } else if (!isValidPhone(lead.contactPhone)) {
      fieldErrors.phone = "Please enter a phone number with at least 10 digits.";
    }
    if (!lead.contactEmail) {
      fieldErrors.email = "Please enter your email address.";
    } else if (!isValidEmail(lead.contactEmail)) {
      fieldErrors.email = "Please enter a valid email address.";
    }
    if (!lead.message) fieldErrors.message = "Please enter a message.";

    if (Object.keys(fieldErrors).length > 0) {
      response.status(400).json({
        error: "Please correct the highlighted fields.",
        fieldErrors,
      });
      return;
    }

    const day = new Date().toISOString().slice(0, 10);
    const fingerprint = createHash("sha256")
      .update(`${day}|${lead.contactEmail}|${lead.contactPhone}`)
      .digest("hex")
      .slice(0, 32);
    const document = db.collection(Collections.clients).doc(`web-${fingerprint}`);

    try {
      await document.create({
        name: lead.name,
        ownerName: lead.ownerName,
        category: lead.category,
        contactEmail: lead.contactEmail,
        contactPhone: lead.contactPhone,
        assignedManager: null,
        stage: "reach",
        createdDate: FieldValue.serverTimestamp(),
        updatedDate: null,
        notes: `Website enquiry: ${lead.message}`,
        followUpAt: null,
        followUpNotes: null,
        source: "website_contact_form",
      });

      logger.info("Website lead created", { clientId: document.id });
      response.status(201).json({ ok: true, id: document.id });
    } catch (error) {
      const code = (error as { code?: number | string }).code;
      if (code === 6 || code === "already-exists") {
        response.status(200).json({ ok: true, duplicate: true });
        return;
      }

      logger.error("Website lead submission failed", error);
      response.status(500).json({ error: "Could not submit your message. Please try again." });
    }
  }
);

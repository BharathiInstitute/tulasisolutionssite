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
exports.submitWebsiteLead = void 0;
const crypto_1 = require("crypto");
const firestore_1 = require("firebase-admin/firestore");
const https_1 = require("firebase-functions/v2/https");
const logger = __importStar(require("firebase-functions/logger"));
const config_1 = require("./config");
const MAX_LENGTHS = {
    name: 100,
    business: 120,
    category: 50,
    phone: 30,
    email: 254,
    message: 2000,
};
function clean(value, maxLength) {
    return typeof value === "string" ? value.trim().slice(0, maxLength) : "";
}
function isValidEmail(value) {
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value);
}
function isValidPhone(value) {
    return value.replace(/\D/g, "").length >= 10;
}
exports.submitWebsiteLead = (0, https_1.onRequest)({ region: "asia-south1", cors: true, maxInstances: 10 }, async (request, response) => {
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
    const fieldErrors = {};
    if (!lead.ownerName)
        fieldErrors.name = "Please enter your name.";
    if (!lead.name)
        fieldErrors.business = "Please enter your business name.";
    if (!lead.category)
        fieldErrors.category = "Please select a business category.";
    if (!lead.contactPhone) {
        fieldErrors.phone = "Please enter your phone or WhatsApp number.";
    }
    else if (!isValidPhone(lead.contactPhone)) {
        fieldErrors.phone = "Please enter a phone number with at least 10 digits.";
    }
    if (!lead.contactEmail) {
        fieldErrors.email = "Please enter your email address.";
    }
    else if (!isValidEmail(lead.contactEmail)) {
        fieldErrors.email = "Please enter a valid email address.";
    }
    if (!lead.message)
        fieldErrors.message = "Please enter a message.";
    if (Object.keys(fieldErrors).length > 0) {
        response.status(400).json({
            error: "Please correct the highlighted fields.",
            fieldErrors,
        });
        return;
    }
    const day = new Date().toISOString().slice(0, 10);
    const fingerprint = (0, crypto_1.createHash)("sha256")
        .update(`${day}|${lead.contactEmail}|${lead.contactPhone}`)
        .digest("hex")
        .slice(0, 32);
    const document = config_1.db.collection(config_1.Collections.clients).doc(`web-${fingerprint}`);
    try {
        await document.create({
            name: lead.name,
            ownerName: lead.ownerName,
            category: lead.category,
            contactEmail: lead.contactEmail,
            contactPhone: lead.contactPhone,
            assignedManager: null,
            stage: "reach",
            createdDate: firestore_1.FieldValue.serverTimestamp(),
            updatedDate: null,
            notes: `Website enquiry: ${lead.message}`,
            followUpAt: null,
            followUpNotes: null,
            source: "website_contact_form",
        });
        logger.info("Website lead created", { clientId: document.id });
        response.status(201).json({ ok: true, id: document.id });
    }
    catch (error) {
        const code = error.code;
        if (code === 6 || code === "already-exists") {
            response.status(200).json({ ok: true, duplicate: true });
            return;
        }
        logger.error("Website lead submission failed", error);
        response.status(500).json({ error: "Could not submit your message. Please try again." });
    }
});
//# sourceMappingURL=website-leads.js.map
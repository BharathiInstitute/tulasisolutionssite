"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.submitWhatsAppTemplate = exports.listTemplates = void 0;
const https_1 = require("firebase-functions/v2/https");
const config_1 = require("./config");
const msg91_client_1 = require("./msg91/msg91-client");
const msg91_whatsapp_1 = require("./msg91/msg91-whatsapp");
async function authorizeTemplateManagement(request) {
    if (!request.auth?.uid) {
        throw new https_1.HttpsError("unauthenticated", "Authentication required");
    }
    const userSnap = await config_1.db.collection("users").doc(request.auth.uid).get();
    const userData = userSnap.data();
    const panels = Array.isArray(userData?.panels) ? userData.panels : [];
    if (userData?.isAdmin === true || panels.includes("chat")) {
        return;
    }
    throw new https_1.HttpsError("permission-denied", "Cannot manage WhatsApp templates");
}
exports.listTemplates = (0, https_1.onCall)({
    ...config_1.callableOptions,
    secrets: [config_1.msg91AuthKey, config_1.msg91WhatsAppNumber],
}, async (request) => {
    await authorizeTemplateManagement(request);
    const integratedNumber = (0, msg91_client_1.getWhatsAppIntegratedNumber)();
    const templates = await (0, msg91_whatsapp_1.listTemplates)(integratedNumber);
    const savedTemplates = await config_1.db.collection("whatsapp_templates").get();
    const savedMetadata = new Map(savedTemplates.docs.map((doc) => [doc.id, doc.data()]));
    const normalizedTemplates = templates
        .map((template) => {
        const saved = savedMetadata.get(template.name);
        return {
            ...template,
            body: template.body ?? saved?.body,
            headerImageUrl: saved?.headerImageUrl ?? null,
            ctaUrl: saved?.ctaUrl ?? null,
            ctaLabel: saved?.ctaLabel ?? null,
        };
    })
        .filter((template) => template.enabled &&
        typeof template.body === "string" &&
        template.body.trim().length > 0);
    return {
        templates: normalizedTemplates.filter((template) => template.status === "APPROVED"),
        pendingTemplates: normalizedTemplates.filter((template) => template.status === "PENDING"),
    };
});
exports.submitWhatsAppTemplate = (0, https_1.onCall)({
    ...config_1.callableOptions,
    secrets: [config_1.msg91AuthKey, config_1.msg91WhatsAppNumber],
}, async (request) => {
    await authorizeTemplateManagement(request);
    const name = request.data.name?.trim();
    const body = request.data.body?.trim();
    const category = request.data.category?.trim();
    const language = request.data.language?.trim();
    const ctaUrl = request.data.ctaUrl?.trim();
    const ctaLabel = request.data.ctaLabel?.trim();
    const headerImageUrl = request.data.headerImageUrl?.trim();
    if (!name || !/^[a-z0-9_]+$/.test(name)) {
        throw new https_1.HttpsError("invalid-argument", "Template name must use lowercase letters, numbers, and underscores only");
    }
    if (!body || !category || !language) {
        throw new https_1.HttpsError("invalid-argument", "Name, body, category, and language are required");
    }
    if (ctaUrl) {
        let parsedUrl;
        try {
            parsedUrl = new URL(ctaUrl);
        }
        catch {
            throw new https_1.HttpsError("invalid-argument", "CTA URL must be a valid HTTPS URL");
        }
        if (parsedUrl.protocol !== "https:") {
            throw new https_1.HttpsError("invalid-argument", "CTA URL must use HTTPS");
        }
        if (!ctaLabel || ctaLabel.length > 25) {
            throw new https_1.HttpsError("invalid-argument", "CTA label is required and must be 25 characters or fewer");
        }
    }
    if (headerImageUrl) {
        let parsedImageUrl;
        try {
            parsedImageUrl = new URL(headerImageUrl);
        }
        catch {
            throw new https_1.HttpsError("invalid-argument", "Header image must be a valid HTTPS URL");
        }
        if (parsedImageUrl.protocol !== "https:") {
            throw new https_1.HttpsError("invalid-argument", "Header image must use HTTPS");
        }
    }
    const integratedNumber = (0, msg91_client_1.getWhatsAppIntegratedNumber)();
    let result;
    try {
        result = await (0, msg91_whatsapp_1.submitTemplateForApproval)({
            name,
            body,
            category,
            language,
            footer: request.data.footer?.trim() || undefined,
            ctaUrl: ctaUrl || undefined,
            ctaLabel: ctaLabel || undefined,
            headerImageUrl: headerImageUrl || undefined,
            integratedNumber,
        });
    }
    catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        if (!message.includes("already associated with this template")) {
            throw new https_1.HttpsError("invalid-argument", message);
        }
        result = {
            success: true,
            message: "Existing MSG91 template linked to this application",
        };
    }
    if (!result.success) {
        throw new https_1.HttpsError("invalid-argument", result.message ?? "MSG91 rejected the template submission");
    }
    await config_1.db.collection("whatsapp_templates").doc(name).set({
        name,
        body,
        category,
        language,
        footer: request.data.footer?.trim() || null,
        ctaUrl: ctaUrl || null,
        ctaLabel: ctaLabel || null,
        headerImageUrl: headerImageUrl || null,
        submittedAt: new Date(),
        msg91TemplateId: result.templateId ?? null,
    });
    return result;
});
//# sourceMappingURL=template-functions.js.map
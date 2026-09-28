import { CallableRequest, HttpsError, onCall } from "firebase-functions/v2/https";
import { callableOptions, db, msg91AuthKey, msg91WhatsAppNumber } from "./config";
import { getWhatsAppIntegratedNumber } from "./msg91/msg91-client";
import {
  listTemplates as listMsg91Templates,
  submitTemplateForApproval,
} from "./msg91/msg91-whatsapp";

interface ListTemplatesRequest {
  clientId?: string;
}

interface SubmitTemplateRequest extends ListTemplatesRequest {
  name: string;
  body: string;
  category: string;
  language: string;
  footer?: string;
  ctaUrl?: string;
  ctaLabel?: string;
  headerImageUrl?: string;
}

async function authorizeTemplateManagement(
  request: CallableRequest<ListTemplatesRequest>,
): Promise<void> {
  if (!request.auth?.uid) {
    throw new HttpsError("unauthenticated", "Authentication required");
  }

  const userSnap = await db.collection("users").doc(request.auth.uid).get();
  const userData = userSnap.data();
  const panels = Array.isArray(userData?.panels) ? userData.panels : [];
  if (userData?.isAdmin === true || panels.includes("chat")) {
    return;
  }

  throw new HttpsError("permission-denied", "Cannot manage WhatsApp templates");
}

export const listTemplates = onCall(
  {
    ...callableOptions,
    secrets: [msg91AuthKey, msg91WhatsAppNumber],
  },
  async (request: CallableRequest<ListTemplatesRequest>) => {
    await authorizeTemplateManagement(request);
    const integratedNumber = getWhatsAppIntegratedNumber();
    const templates = await listMsg91Templates(integratedNumber);
    const savedTemplates = await db.collection("whatsapp_templates").get();
    const savedMetadata = new Map(
      savedTemplates.docs.map((doc) => [doc.id, doc.data()]),
    );

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
      .filter(
        (template) =>
          template.enabled &&
          typeof template.body === "string" &&
          template.body.trim().length > 0,
      );

    return {
      templates: normalizedTemplates.filter(
        (template) =>
          template.status === "APPROVED",
      ),
      pendingTemplates: normalizedTemplates.filter(
          (template) =>
            template.status === "PENDING",
        ),
    };
  },
);

export const submitWhatsAppTemplate = onCall(
  {
    ...callableOptions,
    secrets: [msg91AuthKey, msg91WhatsAppNumber],
  },
  async (request: CallableRequest<SubmitTemplateRequest>) => {
    await authorizeTemplateManagement(request);
    const name = request.data.name?.trim();
    const body = request.data.body?.trim();
    const category = request.data.category?.trim();
    const language = request.data.language?.trim();
    const ctaUrl = request.data.ctaUrl?.trim();
    const ctaLabel = request.data.ctaLabel?.trim();
    const headerImageUrl = request.data.headerImageUrl?.trim();

    if (!name || !/^[a-z0-9_]+$/.test(name)) {
      throw new HttpsError("invalid-argument", "Template name must use lowercase letters, numbers, and underscores only");
    }
    if (!body || !category || !language) {
      throw new HttpsError("invalid-argument", "Name, body, category, and language are required");
    }
    if (ctaUrl) {
      let parsedUrl: URL;
      try {
        parsedUrl = new URL(ctaUrl);
      } catch {
        throw new HttpsError("invalid-argument", "CTA URL must be a valid HTTPS URL");
      }
      if (parsedUrl.protocol !== "https:") {
        throw new HttpsError("invalid-argument", "CTA URL must use HTTPS");
      }
      if (!ctaLabel || ctaLabel.length > 25) {
        throw new HttpsError("invalid-argument", "CTA label is required and must be 25 characters or fewer");
      }
    }
    if (headerImageUrl) {
      let parsedImageUrl: URL;
      try {
        parsedImageUrl = new URL(headerImageUrl);
      } catch {
        throw new HttpsError("invalid-argument", "Header image must be a valid HTTPS URL");
      }
      if (parsedImageUrl.protocol !== "https:") {
        throw new HttpsError("invalid-argument", "Header image must use HTTPS");
      }
    }

    const integratedNumber = getWhatsAppIntegratedNumber();
    let result;
    try {
      result = await submitTemplateForApproval({
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
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      if (!message.includes("already associated with this template")) {
        throw new HttpsError("invalid-argument", message);
      }
      result = {
        success: true,
        message: "Existing MSG91 template linked to this application",
      };
    }

    if (!result.success) {
      throw new HttpsError("invalid-argument", result.message ?? "MSG91 rejected the template submission");
    }
    await db.collection("whatsapp_templates").doc(name).set({
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
  },
);
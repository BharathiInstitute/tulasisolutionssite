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
    const savedBodies = new Map(
      savedTemplates.docs.map((doc) => [doc.id, doc.data().body as string | undefined]),
    );

    const normalizedTemplates = templates
      .map((template) => ({
        ...template,
        body: template.body ?? savedBodies.get(template.name),
      }))
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

    if (!name || !/^[a-z0-9_]+$/.test(name)) {
      throw new HttpsError("invalid-argument", "Template name must use lowercase letters, numbers, and underscores only");
    }
    if (!body || !category || !language) {
      throw new HttpsError("invalid-argument", "Name, body, category, and language are required");
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
      submittedAt: new Date(),
      msg91TemplateId: result.templateId ?? null,
    });
    return result;
  },
);
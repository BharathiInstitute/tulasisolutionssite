const assert = require("node:assert/strict");
const Module = require("node:module");
const { test } = require("node:test");

function fixture(initialDocuments, options = {}) {
  const documents = new Map(Object.entries(initialDocuments));
  const sends = [];
  const queries = [];
  const writes = [];
  let transactionTail = Promise.resolve();
  const send = async (kind, input) => {
    sends.push({ kind, ...input });
    if (options.sendError) throw new Error("Provider temporarily unavailable");
    return { success: true, requestId: "request-1" };
  };
  const reference = (path) => {
    const parts = path.split("/");
    return {
      path,
      id: parts.at(-1),
      parent: {
        path: parts.slice(0, -1).join("/"),
        parent: parts.length > 2 ? reference(parts.slice(0, -2).join("/")) : null,
      },
      get: async () => snapshot(path),
      update: async (data) => {
        writes.push({ path, data });
        documents.set(path, { ...documents.get(path), ...data });
      },
      set: async (data) => {
        writes.push({ path, data });
        documents.set(path, { ...documents.get(path), ...data });
      },
    };
  };
  const snapshot = (path) => {
    const data = { ...documents.get(path) };
    return {
      id: path.split("/").at(-1), ref: reference(path),
      exists: documents.has(path), data: () => data,
    };
  };
  const comparable = (value) => value?.toDate?.().getTime() ?? (value instanceof Date ? value.getTime() : value);
  const query = (collection, filters = [], limit = Infinity, cursor = null, orderField = null) => ({
    where: (field, operator, value) => query(collection, [...filters, [field, operator, value]], limit, cursor, orderField),
    limit: (count) => query(collection, filters, count, cursor, orderField),
    orderBy: (field) => query(collection, filters, limit, cursor, field),
    startAfter: (document) => query(collection, filters, limit, {
      path: document.ref.path, value: comparable(document.data()[orderField]),
    }, orderField),
    get: async () => {
      queries.push({ collection, filters, limit });
      const paths = [...documents.keys()].sort((left, right) =>
        (orderField ? comparable(documents.get(left)[orderField]) - comparable(documents.get(right)[orderField]) : 0) || left.localeCompare(right)
      ).filter((path) =>
        (collection.includes("/") ? path.split("/").slice(0, -1).join("/") === collection : path.split("/").at(-2) === collection) &&
        (!cursor || (orderField && comparable(documents.get(path)[orderField]) > cursor.value) ||
          ((!orderField || comparable(documents.get(path)[orderField]) === cursor.value) && path > cursor.path)) &&
        filters.every(([field, operator, value]) => {
          const actual = documents.get(path)[field];
          return operator === "==" ? actual === value : actual != null && comparable(actual) <= comparable(value);
        })
      ).slice(0, limit);
      const docs = paths.map(snapshot);
      return { docs, size: docs.length, empty: docs.length === 0 };
    },
  });
  const db = {
    collectionGroup: (name) => query(name),
    collection: (path) => ({
      doc: (id) => reference(`${path}/${id}`),
      where: (field, operator, value) => query(path).where(field, operator, value),
      add: async (data) => {
        const ref = reference(`${path}/created-${writes.length}`);
        await ref.set(data);
        return ref;
      },
      get: async () => { throw new Error(`Unexpected full collection scan: ${path}`); },
    }),
    doc: reference,
    runTransaction: (callback) => {
      const next = transactionTail.then(() => callback({
        get: (ref) => ref.get(), update: (ref, data) => ref.update(data),
      }));
      transactionTail = next.catch(() => {});
      return next;
    },
  };
  const config = {
    db, callableOptions: {}, msg91AuthKey: {}, msg91WhatsAppNumber: {},
    Collections: {
      clients: "clients", messageQueue: "message_queue", contacts: "contacts",
      conversations: "conversations", messages: "messages", templates: "templates",
      leads: "leads",
    },
    clientCol: (clientId, collection) => `clients/${clientId}/${collection}`,
  };
  const originalLoad = Module._load;
  const functionPath = require.resolve("../lib/message-queue");
  const qualificationPath = require.resolve("../lib/lead-qualification");
  delete require.cache[functionPath];
  delete require.cache[qualificationPath];
  let queue;
  let qualification;
  let immediate;
  try {
    Module._load = function(request, parent, isMain) {
      if ([functionPath, qualificationPath].includes(parent?.filename)) {
        if (request === "./config") return config;
        if (request === "./utils") return { normalizePhone: (phone) => phone };
        if (request === "./msg91/msg91-client") return { getClientWhatsAppNumber: async () => "sender" };
        if (request === "./msg91/msg91-whatsapp") return {
          sendWhatsAppText: (input) => send("text", input),
          sendWhatsAppMedia: (input) => send("media", input),
          sendWhatsAppMessage: (input) => send("template", input),
        };
        if (request === "./msg91/msg91-sms") return {
          sendSMS: (flowId, recipients) => send("sms", { flowId, recipients }),
        };
        if (request === "./msg91/msg91-voice") return {
          makeVoiceCall: (phone, flowId) => send("voice", { phone, flowId }),
        };
        if (request === "firebase-functions/v2/scheduler") return { onSchedule: (settings, handler) => ({ settings, run: handler }) };
        if (request === "firebase-functions/v2/https") return { onCall: (settings, handler) => handler };
        if (request === "firebase-functions/v2/firestore") return { onDocumentCreated: (settings, handler) => handler };
        if (request === "firebase-functions/logger") return { info() {}, warn() {}, error() {} };
      }
      return originalLoad.call(this, request, parent, isMain);
    };
    const handlers = require(functionPath);
    queue = handlers.processMessageQueue;
    immediate = handlers.onMessageQueued;
    qualification = require(qualificationPath).processQualificationTimeouts;
  } finally {
    Module._load = originalLoad;
  }
  return { queue, qualification, immediate, snapshot, documents, sends, queries, writes };
}

const pending = (extra = {}) => ({ status: "pending", phone: "919876543210", content: "Test", ...extra });
const timestamp = (date) => ({ toDate: () => date });

test("queue finds legacy and due pending messages without scanning clients", async () => {
  const state = fixture({
    "clients/first": {}, "clients/second": {},
    "clients/first/message_queue/legacy": pending(),
    "clients/second/message_queue/due": pending({ scheduledAt: timestamp(new Date(0)) }),
    "clients/first/message_queue/future": pending({ scheduledAt: timestamp(new Date(Date.now() + 3600000)) }),
    "clients/first/message_queue/sent": pending({ status: "sent" }),
    "clients/missing/message_queue/orphan": pending(),
    "other/first/message_queue/unrelated": pending(),
  });
  await state.queue.run();
  assert.equal(state.sends.length, 2);
  assert.equal(state.documents.get("clients/first/message_queue/legacy").status, "sent");
  assert.equal(state.documents.get("clients/second/message_queue/due").status, "sent");
  assert.equal(state.documents.get("clients/first/message_queue/future").status, "pending");
  assert.equal(state.documents.get("clients/missing/message_queue/orphan").status, "pending");
  assert.equal(state.queue.settings.schedule, "every 30 minutes");
  assert.ok(state.queries.every((query) => query.collection === "message_queue"));
});

test("queue pagination continues after processed messages leave the query", async () => {
  const documents = { "clients/first": {}, "clients/second": {}, "clients/third": {} };
  for (let index = 0; index < 205; index++) {
    const client = ["first", "second", "third"][index % 3];
    documents[`clients/${client}/message_queue/message-${String(index).padStart(3, "0")}`] = pending();
  }
  const state = fixture(documents);
  await state.queue.run();
  assert.equal(state.sends.length, 205);
  assert.equal(state.queries.length, 3);
});

test("queue preserves opt-outs, paused campaigns, retries, and transactional claims", async () => {
  const state = fixture({
    "clients/opted-out": { doNotContact: true }, "clients/active": {},
    "outreach_campaigns/paused": { status: "paused" },
    "clients/opted-out/message_queue/message": pending(),
    "clients/active/message_queue/paused": pending({ campaignId: "paused" }),
    "clients/active/message_queue/retry": pending({ retries: 1 }),
  }, { sendError: true });
  await state.queue.run();
  assert.equal(state.sends.length, 1);
  assert.equal(state.documents.get("clients/opted-out/message_queue/message").status, "cancelled");
  assert.equal(state.documents.get("clients/active/message_queue/paused").status, "pending");
  const retry = state.documents.get("clients/active/message_queue/retry");
  assert.equal(retry.status, "pending");
  assert.equal(retry.retries, 2);
  assert.ok(state.writes.some((write) => write.data.status === "sending"));
});

test("concurrent recovery runs do not send the same pending message twice", async () => {
  const state = fixture({
    "clients/first": {}, "clients/first/message_queue/message": pending(),
  });
  await Promise.all([state.queue.run(), state.queue.run()]);
  assert.equal(state.sends.length, 1);
});

test("immediate sending and scheduled recovery share duplicate protection", async () => {
  const path = "clients/first/message_queue/message";
  const state = fixture({ "clients/first": {}, [path]: pending() });
  await Promise.all([
    state.queue.run(),
    state.immediate({ data: state.snapshot(path), params: { clientId: "first", messageId: "message" } }),
  ]);
  assert.equal(state.sends.length, 1);
  assert.equal(state.documents.get(path).status, "sent");
});

test("recovery preserves WhatsApp template and media routing", async () => {
  const state = fixture({
    "clients/first": {},
    "clients/first/templates/template": { name: "welcome", language: "te" },
    "clients/first/message_queue/template": pending({
      templateName: "welcome", templateParams: { "1": "Name" },
    }),
    "clients/first/message_queue/media": pending({
      mediaUrl: "https://example.com/test.jpg", mediaType: "image",
    }),
  });
  await state.queue.run();
  assert.equal(state.sends.length, 2);
  const template = state.sends.find((send) => send.kind === "template");
  assert.equal(template.language, "te");
  assert.deepEqual(template.bodyParams, [{ type: "text", value: "Name" }]);
  const media = state.sends.find((send) => send.kind === "media");
  assert.equal(media.mediaType, "image");
  assert.equal(media.mediaUrl, "https://example.com/test.jpg");
});

test("empty background queries do not read any client records", async () => {
  const state = fixture({ "clients/first": {} });
  await state.queue.run();
  await state.qualification();
  assert.equal(state.sends.length, 0);
  assert.equal(state.writes.length, 0);
  assert.equal(state.queries.length, 2);
});

test("recovery preserves SMS and voice routing", async () => {
  const state = fixture({
    "clients/first": {},
    "clients/first/message_queue/sms": pending({ channel: "sms", flowId: "sms-flow" }),
    "clients/first/message_queue/voice": pending({ channel: "voice", voiceFlowId: "voice-flow" }),
  });
  await state.queue.run();
  assert.equal(state.sends.length, 2);
  assert.equal(state.sends.find((send) => send.kind === "sms").flowId, "sms-flow");
  assert.equal(state.sends.find((send) => send.kind === "voice").flowId, "voice-flow");
});

test("exhausted WhatsApp retries preserve the configured SMS fallback", async () => {
  const state = fixture({
    "clients/first": {},
    "clients/first/settings/autoTriggers": { smsFallbackEnabled: true, smsFallbackFlowId: "fallback-flow" },
    "clients/first/message_queue/exhausted": pending({ retries: 3 }),
  });
  await state.queue.run();
  assert.equal(state.documents.get("clients/first/message_queue/exhausted").status, "failed");
  const fallback = [...state.documents.entries()].find(([path, data]) =>
    path.includes("/message_queue/") && data.smsFallbackOf === "exhausted"
  );
  assert.ok(fallback);
  assert.equal(fallback[1].channel, "sms");
  assert.equal(fallback[1].flowId, "fallback-flow");
  assert.equal(fallback[1].status, "pending");
  assert.equal(state.sends.length, 0);
});

test("queue retains the original per-client limit across pages", async () => {
  const documents = { "clients/first": {} };
  for (let index = 0; index < 105; index++) {
    documents[`clients/first/message_queue/message-${String(index).padStart(3, "0")}`] = pending();
  }
  const state = fixture(documents);
  await state.queue.run();
  assert.equal(state.sends.length, 100);
  await state.queue.run();
  assert.equal(state.sends.length, 105);
});

test("qualification selects only due active sessions and keeps restart behavior", async () => {
  const state = fixture({
    "clients/first": {},
    "clients/first/contacts/contact": { phone: "919876543210", name: "Contact" },
    "clients/first/conversations/due": {},
    "clients/first/qualificationSessions/due": {
      status: "in_progress", nextActionAt: timestamp(new Date(0)), contactId: "contact", conversationId: "due",
    },
    "clients/first/qualificationSessions/future": {
      status: "in_progress", nextActionAt: timestamp(new Date(Date.now() + 3600000)),
    },
    "clients/first/qualificationSessions/complete": {
      status: "complete", nextActionAt: timestamp(new Date(0)),
    },
    "clients/first/qualificationSessions/missing-date": { status: "in_progress" },
    "clients/missing/qualificationSessions/orphan": {
      status: "in_progress", nextActionAt: timestamp(new Date(0)),
    },
  });
  await state.qualification();
  const due = state.documents.get("clients/first/qualificationSessions/due");
  assert.equal(due.state, "awaiting_business_status");
  assert.ok(due.restartSentAt instanceof Date);
  assert.ok(due.nextActionAt > new Date());
  const queued = [...state.documents.entries()].filter(([path]) => path.includes("/message_queue/"));
  assert.equal(queued.length, 1);
  assert.equal(queued[0][1].status, "pending");
  assert.equal(queued[0][1].conversationId, "due");
  assert.ok(queued[0][1].content.includes("Let's continue"));
  assert.equal(state.sends.length, 0);
  assert.equal(state.writes.some((write) => write.path.endsWith("/future")), false);
  assert.equal(state.writes.some((write) => write.path.endsWith("/complete")), false);
});

test("qualification preserves manual review and pages past updated due sessions", async () => {
  const documents = {
    "clients/first": {},
    "clients/first/contacts/contact": { phone: "919876543210", name: "Contact" },
    "clients/first/leads/lead": { contactId: "contact" },
  };
  for (let index = 0; index < 105; index++) {
    documents[`clients/first/qualificationSessions/session-${String(index).padStart(3, "0")}`] = {
      status: "in_progress", nextActionAt: timestamp(new Date(index)),
      restartSentAt: timestamp(new Date(0)), contactId: "contact", conversationId: "conversation",
    };
  }
  const state = fixture(documents);
  await state.qualification();
  const sessions = [...state.documents.entries()].filter(([path]) => path.includes("/qualificationSessions/"));
  assert.equal(sessions.length, 105);
  assert.ok(sessions.every(([, data]) => data.status === "needs_manual_review" && data.nextActionAt === null));
  assert.equal(state.queries.filter((query) => query.collection === "qualificationSessions").length, 2);
  assert.equal(state.documents.get("clients/first/leads/lead").automationStatus, "needs_manual_review");
  assert.equal(state.sends.length, 0);
});
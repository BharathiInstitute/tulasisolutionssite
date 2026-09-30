const assert = require("node:assert/strict");
const Module = require("node:module");
const { test } = require("node:test");

function fixture(options = {}) {
  const created = [];
  const deleted = [];
  const writes = [];
  const snapshot = (data, id = "staff@example.com") => ({
    id, ref: { id }, exists: data !== undefined, data: () => data,
  });
  const removedProfiles = [];
  const profiles = options.profiles ?? {
    "staff@example.com": { email: "staff@example.com", isAdmin: false },
    "staff-auth-uid": { email: "staff@example.com", isAdmin: false },
  };
  const config = {
    callableOptions: { region: "asia-south1" },
    auth: {
      createUser: async (input) => {
        created.push(input);
        if (options.authError) throw options.authError;
        return { uid: "new-staff-uid" };
      },
      deleteUser: async (uid) => { deleted.push(uid); },
      getUserByEmail: async () => {
        if (options.lookupError) throw options.lookupError;
        return { uid: "staff-auth-uid" };
      },
    },
    db: {
      collection: () => ({
        doc: (id) => ({
          id,
          get: async () => snapshot(id === "caller-uid"
            ? (options.caller ?? { isAdmin: true })
            : id === "manager@example.com" ? options.invitation : profiles[id], id),
        }),
        where: () => ({
          get: async () => ({
            docs: Object.entries(profiles).map(([id, data]) => snapshot(data, id)),
          }),
        }),
      }),
      batch: () => ({
        delete: (ref) => removedProfiles.push(ref.id),
        commit: async () => {},
      }),
      runTransaction: async (callback) => {
        if (options.profileError) throw new Error("Profile write failed");
        await callback({
          get: async () => snapshot(options.existingProfile),
          set: (ref, data, settings) => writes.push({ id: ref.id, data, settings }),
        });
      },
    },
  };
  const originalLoad = Module._load;
  const functionPath = require.resolve("../lib/staff-accounts");
  delete require.cache[functionPath];
  let callable;
  let deleteCallable;
  try {
    Module._load = function(request, parent, isMain) {
      if (request === "./config" && parent?.filename === functionPath) return config;
      return originalLoad.call(this, request, parent, isMain);
    };
    const functions = require(functionPath);
    callable = functions.createStaffAccount;
    deleteCallable = functions.deleteStaffAccount;
  } finally {
    Module._load = originalLoad;
  }
  const request = {
    auth: { uid: "caller-uid", token: { email: "manager@example.com" } },
    data: {
      name: " Staff Member ",
      email: " STAFF@Example.com ",
      password: "test-password-123",
      role: " Designer ",
      team: " Content ",
      panels: ["myTasks"],
    },
  };
  return {
    run: (input = request) => callable.run(input),
    remove: (input = { ...request, data: { uid: "staff@example.com", confirmation: "DELETE" } }) => deleteCallable.run(input),
    request, created, deleted, writes, removedProfiles,
  };
}

test("staff deletion removes the login and linked profiles but no task records", async () => {
  const state = fixture();
  assert.deepEqual(await state.remove(), { deleted: true });
  assert.deepEqual(state.deleted, ["staff-auth-uid"]);
  assert.deepEqual(state.removedProfiles.sort(), ["staff-auth-uid", "staff@example.com"]);
});

test("staff deletion requires an administrator and exact typed confirmation", async () => {
  const state = fixture({ caller: { isAdmin: false, panels: ["users"] } });
  await assert.rejects(state.remove(), { code: "permission-denied" });
  const admin = fixture();
  await assert.rejects(admin.remove({ ...admin.request, auth: undefined }), { code: "unauthenticated" });
  await assert.rejects(admin.remove({ ...admin.request, data: { uid: "staff@example.com", confirmation: "delete" } }), { code: "invalid-argument" });
  assert.equal(state.deleted.length + admin.deleted.length, 0);
});

test("staff deletion protects self and any linked administrator profile", async () => {
  const self = fixture();
  await assert.rejects(self.remove({
    ...self.request, auth: { uid: "caller-uid", token: { email: "staff@example.com" } },
    data: { uid: "staff@example.com", confirmation: "DELETE" },
  }), { code: "failed-precondition" });
  const admin = fixture({ profiles: {
    "staff@example.com": { email: "staff@example.com", isAdmin: false },
    "staff-auth-uid": { email: "staff@example.com", isAdmin: true },
  } });
  await assert.rejects(admin.remove(), { code: "failed-precondition" });
  assert.equal(self.deleted.length + admin.deleted.length, 0);
});

test("legacy staff profiles can be deleted without an Auth login", async () => {
  const state = fixture({ lookupError: { code: "auth/user-not-found" } });
  await state.remove();
  assert.equal(state.deleted.length, 0);
  assert.equal(state.removedProfiles.length, 2);
});

test("creates Auth and normalized staff profile without storing the password", async () => {
  const state = fixture();
  const result = await state.run();
  assert.deepEqual(result, { uid: "new-staff-uid", email: "staff@example.com" });
  assert.equal(state.created[0].password, state.request.data.password);
  assert.equal(state.created[0].email, "staff@example.com");
  assert.equal(state.writes[0].id, "staff@example.com");
  assert.equal(state.writes[0].data.isStaff, true);
  assert.equal(state.writes[0].data.isAdmin, false);
  assert.equal(state.writes[0].data.authUid, "new-staff-uid");
  assert.deepEqual(state.writes[0].data.panels, ["myDashboard", "myPerformance", "myTasks"]);
  assert.equal(state.writes[0].data.role, "Designer");
  assert.equal(state.writes[0].data.team, "Content");
  assert.equal(JSON.stringify(state.writes).includes(state.request.data.password), false);
});

test("rejects unauthenticated and unauthorized callers before creating Auth", async () => {
  const state = fixture({ caller: { isAdmin: false, panels: [] } });
  await assert.rejects(state.run({ ...state.request, auth: undefined }), { code: "unauthenticated" });
  await assert.rejects(state.run(), { code: "permission-denied" });
  assert.equal(state.created.length, 0);
});

test("allows staff management permission from the email invitation", async () => {
  const state = fixture({ caller: { isAdmin: false }, invitation: { panels: ["users"] } });
  await state.run();
  assert.equal(state.writes.length, 1);
});

test("validates password and panel permissions before creating Auth", async () => {
  const state = fixture();
  await assert.rejects(state.run({
    ...state.request, data: { ...state.request.data, password: "short" },
  }), { code: "invalid-argument" });
  await assert.rejects(state.run({
    ...state.request, data: { ...state.request.data, panels: ["superAdmin"] },
  }), { code: "invalid-argument" });
  assert.equal(state.created.length, 0);
});

test("existing Auth emails are rejected without modifying profiles or passwords", async () => {
  const state = fixture({ authError: { code: "auth/email-already-exists" } });
  await assert.rejects(state.run(), { code: "already-exists" });
  assert.equal(state.writes.length, 0);
  assert.equal(state.deleted.length, 0);
});

test("rolls back newly created Auth if profile saving fails", async () => {
  const state = fixture({ profileError: true });
  await assert.rejects(state.run(), { code: "internal" });
  assert.deepEqual(state.deleted, ["new-staff-uid"]);
});

test("does not downgrade an existing administrator profile", async () => {
  const state = fixture({ existingProfile: { isAdmin: true } });
  await assert.rejects(state.run(), { code: "failed-precondition" });
  assert.equal(state.writes.length, 0);
  assert.deepEqual(state.deleted, ["new-staff-uid"]);
});

test("can provision a login for a legacy staff invitation without resetting its creation date", async () => {
  const state = fixture({ existingProfile: { isAdmin: false, team: "Content" } });
  await state.run();
  assert.equal("createdAt" in state.writes[0].data, false);
  assert.deepEqual(state.writes[0].settings, { merge: true });
});
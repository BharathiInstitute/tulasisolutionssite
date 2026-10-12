const { readFileSync } = require("node:fs");
const { join } = require("node:path");
const { before, beforeEach, after, test } = require("node:test");
const { initializeTestEnvironment, assertSucceeds, assertFails } = require("@firebase/rules-unit-testing");
const { doc, getDoc, setDoc, updateDoc, deleteDoc, Timestamp } = require("firebase/firestore");

let environment;
before(async () => {
  const [host, port] = process.env.FIRESTORE_EMULATOR_HOST.split(":");
  environment = await initializeTestEnvironment({
    projectId: "demo-personal-tasks",
    firestore: { host, port: Number(port), rules: readFileSync(join(__dirname, "../../firestore.rules"), "utf8") },
  });
});
beforeEach(async () => {
  await environment.clearFirestore();
  await environment.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    const staff = { isAdmin: false, isStaff: true, panels: [] };
    await setDoc(doc(db, "users/staff-uid"), staff);
    await setDoc(doc(db, "users/staff@example.com"), staff);
    await setDoc(doc(db, "users/ordinary"), { isAdmin: false, isStaff: false, panels: [] });
    await setDoc(doc(db, "users/manager"), { isAdmin: false, isStaff: true, panels: ["tasks"] });
    await setDoc(doc(db, "users/admin"), { isAdmin: true, isStaff: false, panels: [] });
    await setDoc(doc(db, "clients/customer"), { name: "Customer" });
    await setDoc(doc(db, "plans/shared"), { ...personalPlan(), price: 500 });
  });
});
after(async () => { if (environment) await environment.cleanup(); });

function staffDb() {
  return environment.authenticatedContext("staff-uid", { email: "staff@example.com" }).firestore();
}

test("Sales activity logs preserve authorship and cannot be edited or deleted", async () => {
  const admin = environment.authenticatedContext("admin").firestore();
  const reader = environment.authenticatedContext("manager").firestore();
  const record = { id: "entry", recordedBy: "admin", recordedByName: "Admin",
    at: "2026-10-11T00:00:00.000Z", outcome: "Interested", nextReminder: null };
  await assertSucceeds(setDoc(doc(admin, "clients/customer/salesActivity/entry"), record));
  await assertSucceeds(getDoc(doc(reader, "clients/customer/salesActivity/entry")));
  await assertFails(updateDoc(doc(admin, "clients/customer/salesActivity/entry"), { outcome: "Changed" }));
  await assertFails(deleteDoc(doc(admin, "clients/customer/salesActivity/entry")));
  await assertFails(setDoc(doc(reader, "clients/customer/salesActivity/other"), { ...record, id: "other", recordedBy: "manager" }));
  await assertFails(setDoc(doc(admin, "clients/customer/salesActivity/forged"), { ...record, id: "forged", recordedBy: "someone-else" }));
});

test("removed weekly reports collection denies app access without deleting historical data", async () => {
  await environment.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), "weekly_reports/historical"), { clientId: "customer" });
  });
  for (const uid of ["staff-uid", "manager", "admin"]) {
    const db = environment.authenticatedContext(uid, { email: `${uid}@example.com` }).firestore();
    await assertFails(getDoc(doc(db, "weekly_reports/historical")));
    await assertFails(setDoc(doc(db, "weekly_reports/new"), { clientId: "customer" }));
    await assertFails(updateDoc(doc(db, "weekly_reports/historical"), { summary: "Changed" }));
    await assertFails(deleteDoc(doc(db, "weekly_reports/historical")));
  }
  await environment.withSecurityRulesDisabled(async (context) => {
    const snapshot = await getDoc(doc(context.firestore(), "weekly_reports/historical"));
    if (!snapshot.exists()) throw new Error("Historical reports must remain stored");
  });
});

test("removed consultation scheduling denies app access and preserves client records", async () => {
  await environment.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), "consultations/historical"), { clientId: "customer" });
  });
  for (const uid of ["staff-uid", "manager", "admin"]) {
    const db = environment.authenticatedContext(uid, { email: `${uid}@example.com` }).firestore();
    await assertFails(getDoc(doc(db, "consultations/historical")));
    await assertFails(setDoc(doc(db, "consultations/new"), { clientId: "customer" }));
    await assertFails(updateDoc(doc(db, "consultations/historical"), { notes: "Changed" }));
    await assertFails(deleteDoc(doc(db, "consultations/historical")));
  }
  const adminDb = environment.authenticatedContext("admin").firestore();
  await assertSucceeds(getDoc(doc(adminDb, "clients/customer")));
  await environment.withSecurityRulesDisabled(async (context) => {
    const snapshot = await getDoc(doc(context.firestore(), "consultations/historical"));
    if (!snapshot.exists()) throw new Error("Historical consultations must remain stored");
  });
});

function personalPlan(assignedTo = "staff-uid") {
  const category = "Content / Videos";
  const title = "Edit a video";
  const feature = `${category}: ${title}`;
  return {
    clientId: "customer", templateId: null, type: "setup", name: "Custom Tasks", price: 0,
    features: [feature], tasks: [{ id: "task-id", category, title, instructions: "", order: 0,
      source: "customIncluded", templateTaskId: null, addedReason: "Practice editing" }],
    completedFeatures: [], featureProgress: {},
    taskWorkflow: { [feature]: { assignedTo, assignedToName: "Staff", priority: "normal",
      updatedAt: new Date().toISOString(), dueAt: null, internalNotes: "Practice editing" } },
    startDate: Timestamp.now(), endDate: null,
  };
}

test("staff may create one self-assigned customer or internal practice task", async () => {
  const db = staffDb();
  await assertSucceeds(setDoc(doc(db, "plans/personal-uid"), personalPlan()));
  await assertSucceeds(setDoc(doc(db, "plans/personal-email"), personalPlan("staff@example.com")));
  await assertSucceeds(setDoc(doc(db, "plans/practice"), {
    ...personalPlan(), clientId: "__internal_practice__", name: "Practice (Internal)",
  }));
  const tracked = personalPlan();
  tracked.taskWorkflow[tracked.features[0]] = {
    ...tracked.taskWorkflow[tracked.features[0]],
    createdAt: new Date().toISOString(), assignedAt: new Date().toISOString(),
    createdBy: { uid: "staff-uid", name: "Staff" },
    assignedBy: { uid: "staff-uid", name: "Staff" },
    dueBy: { uid: "staff-uid", name: "Staff" },
  };
  await assertSucceeds(setDoc(doc(db, "plans/tracked"), tracked));
});

test("staff cannot assign someone else, charge money, or create completed tasks", async () => {
  const db = staffDb();
  await assertFails(setDoc(doc(db, "plans/other"), personalPlan("other-staff")));
  await assertFails(setDoc(doc(db, "plans/unassigned"), personalPlan(null)));
  await assertFails(setDoc(doc(db, "plans/paid"), { ...personalPlan(), price: 500 }));
  const completed = personalPlan();
  completed.completedFeatures = completed.features;
  await assertFails(setDoc(doc(db, "plans/completed"), completed));
  const workflowCompleted = personalPlan();
  workflowCompleted.taskWorkflow[workflowCompleted.features[0]].status = "completed";
  await assertFails(setDoc(doc(db, "plans/workflow-completed"), workflowCompleted));
});

test("staff cannot inject multiple tasks, package metadata, or Sales tasks", async () => {
  const db = staffDb();
  const multiple = personalPlan();
  multiple.tasks.push({ ...multiple.tasks[0], id: "second" });
  await assertFails(setDoc(doc(db, "plans/multiple"), multiple));
  await assertFails(setDoc(doc(db, "plans/template"), { ...personalPlan(), templateId: "paid-package" }));
  await assertFails(setDoc(doc(db, "plans/package"), { ...personalPlan(), name: "Delivery Package" }));
  const sales = personalPlan();
  sales.tasks[0].category = "Sales / Call";
  sales.features = ["Sales / Call: Edit a video"];
  sales.taskWorkflow = { [sales.features[0]]: Object.values(personalPlan().taskWorkflow)[0] };
  await assertFails(setDoc(doc(db, "plans/sales"), sales));
});

test("staff cannot append tasks to shared plans, change pricing, or delete plans", async () => {
  const db = staffDb();
  await assertFails(updateDoc(doc(db, "plans/shared"), { features: ["Content: Added task"] }));
  await assertFails(updateDoc(doc(db, "plans/shared"), { price: 0 }));
  await assertFails(deleteDoc(doc(db, "plans/shared")));
});

test("missing customers, anonymous visitors, and ordinary accounts cannot create tasks", async () => {
  await assertFails(setDoc(doc(staffDb(), "plans/missing"), { ...personalPlan(), clientId: "missing" }));
  await assertFails(setDoc(doc(environment.unauthenticatedContext().firestore(), "plans/anonymous"), personalPlan()));
  await assertFails(setDoc(doc(environment.authenticatedContext("ordinary").firestore(), "plans/ordinary"), personalPlan("ordinary")));
});

test("task managers and admins retain existing plan management permissions", async () => {
  for (const uid of ["manager", "admin"]) {
    const db = environment.authenticatedContext(uid, { email: `${uid}@example.com` }).firestore();
    await assertSucceeds(setDoc(doc(db, `plans/${uid}`), { ...personalPlan("other-staff"), price: 500 }));
    await assertSucceeds(updateDoc(doc(db, `plans/${uid}`), { price: 600 }));
    await assertSucceeds(deleteDoc(doc(db, `plans/${uid}`)));
  }
});

test("only admins can remove tasks from an existing plan", async () => {
  for (const uid of ["staff-uid", "manager", "admin"]) {
    const db = environment.authenticatedContext(uid, { email: `${uid}@example.com` }).firestore();
    const operation = updateDoc(doc(db, "plans/shared"), {
      features: [], tasks: [], completedFeatures: [], featureProgress: {}, taskWorkflow: {},
    });
    if (uid === "admin") await assertSucceeds(operation);
    else await assertFails(operation);
  }
});
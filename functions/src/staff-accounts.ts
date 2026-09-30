import { DocumentSnapshot, FieldValue } from "firebase-admin/firestore";
import { CallableRequest, HttpsError, onCall } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import { auth, callableOptions, db } from "./config";

interface CreateStaffAccountRequest {
  name: string;
  email: string;
  password: string;
  role?: string;
  team?: string;
  panels?: string[];
}

const staffPanels = new Set([
  "leads", "clients", "payments", "tasks", "myDashboard", "myTasks",
  "users", "chat", "performance", "myPerformance",
]);

export const deleteStaffAccount = onCall(
  callableOptions,
  async (request: CallableRequest<{ uid: string; confirmation: string }>) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in to delete staff.");
    }
    const users = db.collection("users");
    const caller = (await users.doc(request.auth.uid).get()).data();
    if (caller?.isAdmin !== true) {
      throw new HttpsError("permission-denied", "Only administrators can delete staff.");
    }
    const uid = typeof request.data?.uid === "string" ? request.data.uid.trim() : "";
    if (!uid || uid.includes("/") || request.data?.confirmation !== "DELETE") {
      throw new HttpsError("invalid-argument", "Type DELETE to confirm staff deletion.");
    }
    const target = await users.doc(uid).get();
    if (!target.exists) {
      throw new HttpsError("not-found", "This staff profile no longer exists.");
    }
    const email = typeof target.data()?.email === "string"
      ? target.data()!.email.trim().toLowerCase()
      : "";
    if (!email) {
      throw new HttpsError("failed-precondition", "This profile has no staff email.");
    }
    let account;
    try {
      account = await auth.getUserByEmail(email);
    } catch (error) {
      if ((error as { code?: string }).code !== "auth/user-not-found") {
        throw new HttpsError("internal", "Could not look up the staff login. Try again.");
      }
    }
    const related = await users.where("email", "==", email).get();
    const profiles = new Map<string, DocumentSnapshot>(
      related.docs.map((document) => [document.id, document]),
    );
    profiles.set(target.id, target);
    const emailProfile = await users.doc(email).get();
    if (emailProfile.exists) profiles.set(emailProfile.id, emailProfile);
    if (account) {
      const loginProfile = await users.doc(account.uid).get();
      if (loginProfile.exists) profiles.set(loginProfile.id, loginProfile);
    }
    const callerEmail = typeof request.auth.token.email === "string"
      ? request.auth.token.email.trim().toLowerCase()
      : "";
    if (email === callerEmail || account?.uid === request.auth.uid ||
        profiles.has(request.auth.uid) ||
        [...profiles.values()].some((profile) => profile.data()?.isAdmin === true)) {
      throw new HttpsError("failed-precondition", "You cannot delete yourself or an administrator.");
    }
    try {
      if (account) await auth.deleteUser(account.uid);
      const batch = db.batch();
      for (const profile of profiles.values()) batch.delete(profile.ref);
      await batch.commit();
    } catch (error) {
      logger.error("Staff deletion failed", { uid, error });
      throw new HttpsError("internal", "Could not finish deleting staff. Retry to complete removal.");
    }
    return { deleted: true };
  },
);

export const createStaffAccount = onCall(
  callableOptions,
  async (request: CallableRequest<CreateStaffAccountRequest>) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in to add staff.");
    }
    const caller = (await db.collection("users").doc(request.auth.uid).get()).data();
    const callerEmail = typeof request.auth.token.email === "string"
      ? request.auth.token.email.trim().toLowerCase()
      : "";
    const invitation = callerEmail
      ? (await db.collection("users").doc(callerEmail).get()).data()
      : undefined;
    const permissions = invitation ?? caller;
    const canManageStaff = caller?.isAdmin === true || (
      Array.isArray(permissions?.panels) && permissions.panels.includes("users")
    );
    if (!canManageStaff) {
      throw new HttpsError("permission-denied", "Staff management permission is required.");
    }

    const input = request.data;
    const name = typeof input?.name === "string" ? input.name.trim() : "";
    const email = typeof input?.email === "string" ? input.email.trim().toLowerCase() : "";
    const password = typeof input?.password === "string" ? input.password : "";
    const panels = input?.panels ?? [];
    if (!name || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || password.length < 6) {
      throw new HttpsError("invalid-argument", "Enter a name, valid email, and password of at least 6 characters.");
    }
    if (!Array.isArray(panels) || panels.some((panel) => !staffPanels.has(panel))) {
      throw new HttpsError("invalid-argument", "Invalid staff panel permissions.");
    }
    const role = typeof input.role === "string" ? input.role.trim() : "";
    const team = typeof input.team === "string" ? input.team.trim() : "";

    let account;
    try {
      account = await auth.createUser({ email, password, displayName: name });
    } catch (error) {
      const code = (error as { code?: string }).code;
      if (code === "auth/email-already-exists") {
        throw new HttpsError("already-exists", "This email already has a login. Edit its staff permissions instead; use Forgot password to reset its password.");
      }
      if (code === "auth/invalid-email" || code === "auth/invalid-password" || code === "auth/password-does-not-meet-requirements") {
        throw new HttpsError("invalid-argument", "The email or password does not meet Firebase requirements.");
      }
      throw new HttpsError("internal", "Could not create the staff login. Try again.");
    }

    try {
      const profileRef = db.collection("users").doc(email);
      await db.runTransaction(async (transaction) => {
        const existing = await transaction.get(profileRef);
        if (existing.data()?.isAdmin === true) {
          throw new HttpsError("failed-precondition", "An administrator profile already uses this email.");
        }
        transaction.set(profileRef, {
          uid: email,
          authUid: account.uid,
          email,
          name,
          isAdmin: false,
          isStaff: true,
          role,
          team,
          panels: [...new Set(["myDashboard", "myPerformance", "myTasks", ...panels])],
          ...(!existing.exists ? { createdAt: FieldValue.serverTimestamp() } : {}),
          updatedAt: FieldValue.serverTimestamp(),
        }, { merge: true });
      });
    } catch (error) {
      try {
        await auth.deleteUser(account.uid);
      } catch {
        logger.error("Failed to roll back a staff Auth account", { uid: account.uid });
      }
      if (error instanceof HttpsError) throw error;
      throw new HttpsError("internal", "Could not save the staff profile. Try again.");
    }
    return { uid: account.uid, email };
  },
);
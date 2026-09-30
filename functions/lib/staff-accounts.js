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
exports.createStaffAccount = exports.deleteStaffAccount = void 0;
const firestore_1 = require("firebase-admin/firestore");
const https_1 = require("firebase-functions/v2/https");
const logger = __importStar(require("firebase-functions/logger"));
const config_1 = require("./config");
const staffPanels = new Set([
    "leads", "clients", "payments", "tasks", "myDashboard", "myTasks",
    "users", "chat", "performance", "myPerformance",
]);
exports.deleteStaffAccount = (0, https_1.onCall)(config_1.callableOptions, async (request) => {
    if (!request.auth) {
        throw new https_1.HttpsError("unauthenticated", "Sign in to delete staff.");
    }
    const users = config_1.db.collection("users");
    const caller = (await users.doc(request.auth.uid).get()).data();
    if (caller?.isAdmin !== true) {
        throw new https_1.HttpsError("permission-denied", "Only administrators can delete staff.");
    }
    const uid = typeof request.data?.uid === "string" ? request.data.uid.trim() : "";
    if (!uid || uid.includes("/") || request.data?.confirmation !== "DELETE") {
        throw new https_1.HttpsError("invalid-argument", "Type DELETE to confirm staff deletion.");
    }
    const target = await users.doc(uid).get();
    if (!target.exists) {
        throw new https_1.HttpsError("not-found", "This staff profile no longer exists.");
    }
    const email = typeof target.data()?.email === "string"
        ? target.data().email.trim().toLowerCase()
        : "";
    if (!email) {
        throw new https_1.HttpsError("failed-precondition", "This profile has no staff email.");
    }
    let account;
    try {
        account = await config_1.auth.getUserByEmail(email);
    }
    catch (error) {
        if (error.code !== "auth/user-not-found") {
            throw new https_1.HttpsError("internal", "Could not look up the staff login. Try again.");
        }
    }
    const related = await users.where("email", "==", email).get();
    const profiles = new Map(related.docs.map((document) => [document.id, document]));
    profiles.set(target.id, target);
    const emailProfile = await users.doc(email).get();
    if (emailProfile.exists)
        profiles.set(emailProfile.id, emailProfile);
    if (account) {
        const loginProfile = await users.doc(account.uid).get();
        if (loginProfile.exists)
            profiles.set(loginProfile.id, loginProfile);
    }
    const callerEmail = typeof request.auth.token.email === "string"
        ? request.auth.token.email.trim().toLowerCase()
        : "";
    if (email === callerEmail || account?.uid === request.auth.uid ||
        profiles.has(request.auth.uid) ||
        [...profiles.values()].some((profile) => profile.data()?.isAdmin === true)) {
        throw new https_1.HttpsError("failed-precondition", "You cannot delete yourself or an administrator.");
    }
    try {
        if (account)
            await config_1.auth.deleteUser(account.uid);
        const batch = config_1.db.batch();
        for (const profile of profiles.values())
            batch.delete(profile.ref);
        await batch.commit();
    }
    catch (error) {
        logger.error("Staff deletion failed", { uid, error });
        throw new https_1.HttpsError("internal", "Could not finish deleting staff. Retry to complete removal.");
    }
    return { deleted: true };
});
exports.createStaffAccount = (0, https_1.onCall)(config_1.callableOptions, async (request) => {
    if (!request.auth) {
        throw new https_1.HttpsError("unauthenticated", "Sign in to add staff.");
    }
    const caller = (await config_1.db.collection("users").doc(request.auth.uid).get()).data();
    const callerEmail = typeof request.auth.token.email === "string"
        ? request.auth.token.email.trim().toLowerCase()
        : "";
    const invitation = callerEmail
        ? (await config_1.db.collection("users").doc(callerEmail).get()).data()
        : undefined;
    const permissions = invitation ?? caller;
    const canManageStaff = caller?.isAdmin === true || (Array.isArray(permissions?.panels) && permissions.panels.includes("users"));
    if (!canManageStaff) {
        throw new https_1.HttpsError("permission-denied", "Staff management permission is required.");
    }
    const input = request.data;
    const name = typeof input?.name === "string" ? input.name.trim() : "";
    const email = typeof input?.email === "string" ? input.email.trim().toLowerCase() : "";
    const password = typeof input?.password === "string" ? input.password : "";
    const panels = input?.panels ?? [];
    if (!name || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || password.length < 6) {
        throw new https_1.HttpsError("invalid-argument", "Enter a name, valid email, and password of at least 6 characters.");
    }
    if (!Array.isArray(panels) || panels.some((panel) => !staffPanels.has(panel))) {
        throw new https_1.HttpsError("invalid-argument", "Invalid staff panel permissions.");
    }
    const role = typeof input.role === "string" ? input.role.trim() : "";
    const team = typeof input.team === "string" ? input.team.trim() : "";
    let account;
    try {
        account = await config_1.auth.createUser({ email, password, displayName: name });
    }
    catch (error) {
        const code = error.code;
        if (code === "auth/email-already-exists") {
            throw new https_1.HttpsError("already-exists", "This email already has a login. Edit its staff permissions instead; use Forgot password to reset its password.");
        }
        if (code === "auth/invalid-email" || code === "auth/invalid-password" || code === "auth/password-does-not-meet-requirements") {
            throw new https_1.HttpsError("invalid-argument", "The email or password does not meet Firebase requirements.");
        }
        throw new https_1.HttpsError("internal", "Could not create the staff login. Try again.");
    }
    try {
        const profileRef = config_1.db.collection("users").doc(email);
        await config_1.db.runTransaction(async (transaction) => {
            const existing = await transaction.get(profileRef);
            if (existing.data()?.isAdmin === true) {
                throw new https_1.HttpsError("failed-precondition", "An administrator profile already uses this email.");
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
                ...(!existing.exists ? { createdAt: firestore_1.FieldValue.serverTimestamp() } : {}),
                updatedAt: firestore_1.FieldValue.serverTimestamp(),
            }, { merge: true });
        });
    }
    catch (error) {
        try {
            await config_1.auth.deleteUser(account.uid);
        }
        catch {
            logger.error("Failed to roll back a staff Auth account", { uid: account.uid });
        }
        if (error instanceof https_1.HttpsError)
            throw error;
        throw new https_1.HttpsError("internal", "Could not save the staff profile. Try again.");
    }
    return { uid: account.uid, email };
});
//# sourceMappingURL=staff-accounts.js.map
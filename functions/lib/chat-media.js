"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.cleanupAbandonedChatMedia = exports.processChatMedia = exports.uploadChatMedia = exports.completeChatMediaUpload = exports.prepareChatMediaUpload = void 0;
const crypto_1 = require("crypto");
const child_process_1 = require("child_process");
const promises_1 = require("fs/promises");
const os_1 = require("os");
const path_1 = require("path");
const ffmpeg_static_1 = __importDefault(require("ffmpeg-static"));
const ffprobe_static_1 = __importDefault(require("ffprobe-static"));
const https_1 = require("firebase-functions/v2/https");
const scheduler_1 = require("firebase-functions/v2/scheduler");
const config_1 = require("./config");
const CHAT_MEDIA_BUCKET = "newproject1234561-chat-media-135120528629";
const MAX_ATTACHMENT_BYTES = 20 * 1024 * 1024;
const MAX_DIRECT_UPLOAD_BYTES = 250 * 1024 * 1024;
const MAX_PROCESSED_MEDIA_BYTES = 15 * 1024 * 1024;
async function resolveClientId(request) {
    if (!request.auth?.uid) {
        throw new https_1.HttpsError("unauthenticated", "Authentication required");
    }
    const requestedClientId = request.data.clientId?.trim();
    if (!requestedClientId) {
        return (await (0, config_1.getCallerClient)(request.auth)).clientId;
    }
    const userSnapshot = await config_1.db.collection("users").doc(request.auth.uid).get();
    const userData = userSnapshot.data();
    const panels = Array.isArray(userData?.panels) ? userData.panels : [];
    if (userData?.isAdmin === true || panels.includes("chat")) {
        return requestedClientId;
    }
    const callerClientId = (await (0, config_1.getCallerClient)(request.auth)).clientId;
    if (callerClientId !== requestedClientId) {
        throw new https_1.HttpsError("permission-denied", "Cannot upload media for this client");
    }
    return callerClientId;
}
async function verifyConversation(clientId, conversationId) {
    const normalizedId = conversationId?.trim();
    if (!normalizedId) {
        throw new https_1.HttpsError("invalid-argument", "conversationId is required");
    }
    const conversationPath = `${(0, config_1.clientCol)(clientId, config_1.Collections.conversations)}/${normalizedId}`;
    if (!(await config_1.db.doc(conversationPath).get()).exists) {
        throw new https_1.HttpsError("not-found", "Conversation not found");
    }
    return normalizedId;
}
function downloadUrl(objectPath, token) {
    return `https://firebasestorage.googleapis.com/v0/b/${CHAT_MEDIA_BUCKET}/o/${encodeURIComponent(objectPath)}?alt=media&token=${token}`;
}
function runProcess(command, args) {
    return new Promise((resolve, reject) => {
        const child = (0, child_process_1.spawn)(command, args, { windowsHide: true });
        let output = "";
        child.stdout.on("data", (chunk) => {
            output += chunk.toString();
        });
        child.stderr.on("data", (chunk) => {
            output = `${output}${chunk.toString()}`.slice(-12000);
        });
        child.on("error", reject);
        child.on("close", (code) => {
            if (code === 0)
                resolve(output);
            else
                reject(new Error(`Media process exited with code ${code}: ${output}`));
        });
    });
}
async function mediaDuration(inputPath) {
    const output = await runProcess(ffprobe_static_1.default.path, [
        "-v", "error",
        "-show_entries", "format=duration",
        "-of", "default=noprint_wrappers=1:nokey=1",
        inputPath,
    ]);
    const duration = Number(output.trim().split(/\r?\n/).at(-1));
    if (!Number.isFinite(duration) || duration <= 0) {
        throw new https_1.HttpsError("invalid-argument", "The media duration could not be read");
    }
    return duration;
}
function outputObjectPath(objectPath, extension) {
    return `${objectPath.replace(/\.[^/.]+$/, "")}_processed.${extension}`;
}
exports.prepareChatMediaUpload = (0, https_1.onCall)(config_1.callableOptions, async (request) => {
    const clientId = await resolveClientId(request);
    const conversationId = await verifyConversation(clientId, request.data.conversationId);
    const contentType = request.data.contentType?.trim() || "application/octet-stream";
    const size = Number(request.data.size);
    if (!Number.isSafeInteger(size) || size <= 0 || size > MAX_DIRECT_UPLOAD_BYTES) {
        throw new https_1.HttpsError("invalid-argument", "Attachment must be between 1 byte and 250 MB");
    }
    const originalName = request.data.originalName?.trim() || "attachment";
    const fileName = (request.data.fileName?.trim() || originalName)
        .replace(/[^A-Za-z0-9._-]/g, "_")
        .substring(0, 180);
    const objectPath = `chat_media/${clientId}/${conversationId}/${Date.now()}_${(0, crypto_1.randomUUID)()}_${fileName}`;
    const [uploadUrl] = await config_1.storage.bucket(CHAT_MEDIA_BUCKET).file(objectPath).getSignedUrl({
        version: "v4",
        action: "write",
        expires: Date.now() + 15 * 60 * 1000,
        contentType,
        extensionHeaders: { "x-goog-meta-upload-state": "pending" },
    });
    return { uploadUrl, objectPath, contentType, originalName };
});
exports.completeChatMediaUpload = (0, https_1.onCall)(config_1.callableOptions, async (request) => {
    const clientId = await resolveClientId(request);
    const conversationId = await verifyConversation(clientId, request.data.conversationId);
    const objectPath = request.data.objectPath?.trim();
    const requiredPrefix = `chat_media/${clientId}/${conversationId}/`;
    if (!objectPath?.startsWith(requiredPrefix)) {
        throw new https_1.HttpsError("permission-denied", "Invalid attachment path");
    }
    const file = config_1.storage.bucket(CHAT_MEDIA_BUCKET).file(objectPath);
    const [metadata] = await file.getMetadata();
    const size = Number(metadata.size);
    if (!Number.isSafeInteger(size) || size <= 0 || size > MAX_DIRECT_UPLOAD_BYTES) {
        await file.delete({ ignoreNotFound: true });
        throw new https_1.HttpsError("invalid-argument", "Uploaded attachment has an invalid size");
    }
    const token = (0, crypto_1.randomUUID)();
    const originalName = request.data.originalName?.trim() || "attachment";
    await file.setMetadata({
        metadata: {
            ...metadata.metadata,
            firebaseStorageDownloadTokens: token,
            originalName,
            uploadState: "complete",
        },
    });
    return {
        mediaUrl: downloadUrl(objectPath, token),
        objectPath,
        contentType: metadata.contentType || "application/octet-stream",
        originalName,
        size,
    };
});
exports.uploadChatMedia = (0, https_1.onCall)({ ...config_1.callableOptions, memory: "512MiB", timeoutSeconds: 120 }, async (request) => {
    const clientId = await resolveClientId(request);
    const conversationId = request.data.conversationId?.trim();
    const base64Data = request.data.base64Data;
    const contentType = request.data.contentType?.trim() || "application/octet-stream";
    const originalName = request.data.originalName?.trim() || "attachment";
    const fileName = (request.data.fileName?.trim() || originalName)
        .replace(/[^A-Za-z0-9._-]/g, "_")
        .substring(0, 180);
    if (!conversationId || !base64Data) {
        throw new https_1.HttpsError("invalid-argument", "conversationId and file data are required");
    }
    if (base64Data.length > Math.ceil(MAX_ATTACHMENT_BYTES * 4 / 3) + 4) {
        throw new https_1.HttpsError("invalid-argument", "Attachment exceeds the 20 MB limit");
    }
    await verifyConversation(clientId, conversationId);
    const bytes = Buffer.from(base64Data, "base64");
    if (bytes.length === 0 || bytes.length > MAX_ATTACHMENT_BYTES) {
        throw new https_1.HttpsError("invalid-argument", "Attachment exceeds the 20 MB limit");
    }
    const token = (0, crypto_1.randomUUID)();
    const objectPath = `chat_media/${clientId}/${conversationId}/${Date.now()}_${fileName}`;
    await config_1.storage.bucket(CHAT_MEDIA_BUCKET).file(objectPath).save(bytes, {
        resumable: false,
        validation: "crc32c",
        metadata: {
            contentType,
            metadata: {
                firebaseStorageDownloadTokens: token,
                originalName,
            },
        },
    });
    return {
        mediaUrl: downloadUrl(objectPath, token),
        contentType,
        originalName,
    };
});
exports.processChatMedia = (0, https_1.onCall)({
    ...config_1.callableOptions,
    memory: "2GiB",
    timeoutSeconds: 540,
    maxInstances: 3,
}, async (request) => {
    const clientId = await resolveClientId(request);
    const conversationId = await verifyConversation(clientId, request.data.conversationId);
    const objectPath = request.data.objectPath?.trim();
    const requiredPrefix = `chat_media/${clientId}/${conversationId}/`;
    if (!objectPath?.startsWith(requiredPrefix)) {
        throw new https_1.HttpsError("permission-denied", "Invalid attachment path");
    }
    const mediaType = request.data.mediaType?.trim();
    if (mediaType !== "video" && mediaType !== "audio") {
        throw new https_1.HttpsError("invalid-argument", "mediaType must be video or audio");
    }
    if (!ffmpeg_static_1.default || !ffprobe_static_1.default.path) {
        throw new https_1.HttpsError("failed-precondition", "Media processor is unavailable");
    }
    const bucket = config_1.storage.bucket(CHAT_MEDIA_BUCKET);
    const sourceFile = bucket.file(objectPath);
    const [sourceMetadata] = await sourceFile.getMetadata();
    const sourceSize = Number(sourceMetadata.size);
    if (!Number.isSafeInteger(sourceSize) || sourceSize <= 0 || sourceSize > MAX_DIRECT_UPLOAD_BYTES) {
        throw new https_1.HttpsError("invalid-argument", "Uploaded media has an invalid size");
    }
    const workDir = await (0, promises_1.mkdtemp)((0, path_1.join)((0, os_1.tmpdir)(), "chat-media-"));
    const inputPath = (0, path_1.join)(workDir, "input");
    const extension = mediaType === "video" ? "mp4" : "m4a";
    const contentType = mediaType === "video" ? "video/mp4" : "audio/mp4";
    const outputPath = (0, path_1.join)(workDir, `output.${extension}`);
    const processedObjectPath = outputObjectPath(objectPath, extension);
    try {
        await sourceFile.setMetadata({
            metadata: {
                ...sourceMetadata.metadata,
                uploadState: "processing",
            },
        });
        await sourceFile.download({ destination: inputPath });
        const duration = await mediaDuration(inputPath);
        if (mediaType === "video") {
            const totalKbps = Math.floor((MAX_PROCESSED_MEDIA_BYTES * 8 * 0.9) / duration / 1000);
            let videoKbps = Math.max(100, Math.min(1800, totalKbps - 96));
            for (let attempt = 0; attempt < 3; attempt++) {
                const maxWidth = videoKbps < 250 ? 426 : videoKbps < 450 ? 640 : videoKbps < 900 ? 854 : 1280;
                await runProcess(ffmpeg_static_1.default, [
                    "-y", "-i", inputPath,
                    "-map", "0:v:0", "-map", "0:a:0?",
                    "-vf", `scale=trunc(min(iw\\,${maxWidth})/2)*2:-2`,
                    "-c:v", "libx264", "-preset", "veryfast", "-pix_fmt", "yuv420p",
                    "-b:v", `${videoKbps}k`, "-maxrate", `${videoKbps}k`,
                    "-bufsize", `${videoKbps * 2}k`,
                    "-c:a", "aac", "-b:a", "96k",
                    "-movflags", "+faststart",
                    outputPath,
                ]);
                if ((await (0, promises_1.stat)(outputPath)).size <= MAX_PROCESSED_MEDIA_BYTES)
                    break;
                videoKbps = Math.max(100, Math.floor(videoKbps * 0.72));
            }
        }
        else {
            const audioKbps = Math.max(32, Math.min(128, Math.floor((MAX_PROCESSED_MEDIA_BYTES * 8 * 0.9) / duration / 1000)));
            await runProcess(ffmpeg_static_1.default, [
                "-y", "-i", inputPath,
                "-vn", "-c:a", "aac", "-b:a", `${audioKbps}k`,
                "-movflags", "+faststart",
                outputPath,
            ]);
        }
        const processedSize = (await (0, promises_1.stat)(outputPath)).size;
        if (processedSize <= 0 || processedSize > MAX_PROCESSED_MEDIA_BYTES) {
            throw new https_1.HttpsError("resource-exhausted", "The media could not be reduced below 15 MB");
        }
        const token = (0, crypto_1.randomUUID)();
        const originalName = request.data.originalName?.trim() || "attachment";
        await bucket.upload(outputPath, {
            destination: processedObjectPath,
            resumable: false,
            validation: "crc32c",
            metadata: {
                contentType,
                metadata: {
                    firebaseStorageDownloadTokens: token,
                    originalName,
                    normalizedFrom: objectPath,
                    uploadState: "complete",
                },
            },
        });
        await sourceFile.delete({ ignoreNotFound: true });
        return {
            mediaUrl: downloadUrl(processedObjectPath, token),
            objectPath: processedObjectPath,
            contentType,
            originalName,
            size: processedSize,
        };
    }
    catch (error) {
        if (error instanceof https_1.HttpsError)
            throw error;
        console.error("Chat media processing failed", {
            mediaType,
            objectPath,
            error: error instanceof Error ? error.message : String(error),
        });
        throw new https_1.HttpsError("internal", "Media processing failed");
    }
    finally {
        await (0, promises_1.rm)(workDir, { recursive: true, force: true });
    }
});
exports.cleanupAbandonedChatMedia = (0, scheduler_1.onSchedule)({
    region: "asia-south1",
    schedule: "every 24 hours",
    timeZone: "Asia/Kolkata",
    timeoutSeconds: 540,
}, async () => {
    const cutoff = Date.now() - 24 * 60 * 60 * 1000;
    const bucket = config_1.storage.bucket(CHAT_MEDIA_BUCKET);
    const [files] = await bucket.getFiles({ prefix: "chat_media/" });
    let deleted = 0;
    for (const file of files) {
        const [metadata] = await file.getMetadata();
        const uploadState = metadata.metadata?.uploadState ??
            metadata.metadata?.["upload-state"];
        const createdAt = Date.parse(metadata.timeCreated || "");
        if ((uploadState === "pending" || uploadState === "processing") &&
            Number.isFinite(createdAt) &&
            createdAt < cutoff) {
            await file.delete({ ignoreNotFound: true });
            deleted++;
        }
    }
    console.info("Abandoned chat media cleanup complete", { deleted });
});
//# sourceMappingURL=chat-media.js.map
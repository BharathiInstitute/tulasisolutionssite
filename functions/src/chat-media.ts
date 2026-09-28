import { randomUUID } from "crypto";
import { spawn } from "child_process";
import { mkdtemp, rm, stat } from "fs/promises";
import { tmpdir } from "os";
import { join } from "path";
import ffmpegPath from "ffmpeg-static";
import ffprobeStatic from "ffprobe-static";
import { CallableRequest, HttpsError, onCall } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { Collections, callableOptions, clientCol, db, getCallerClient, storage } from "./config";

const CHAT_MEDIA_BUCKET = "newproject1234561-chat-media-135120528629";
const MAX_ATTACHMENT_BYTES = 20 * 1024 * 1024;
const MAX_DIRECT_UPLOAD_BYTES = 250 * 1024 * 1024;
const MAX_PROCESSED_MEDIA_BYTES = 15 * 1024 * 1024;

interface ChatMediaRequest {
  clientId?: string;
}

interface UploadChatMediaRequest {
  clientId?: string;
  conversationId?: string;
  fileName?: string;
  originalName?: string;
  contentType?: string;
  base64Data?: string;
}

interface PrepareChatMediaUploadRequest extends ChatMediaRequest {
  conversationId?: string;
  fileName?: string;
  originalName?: string;
  contentType?: string;
  size?: number;
}

interface CompleteChatMediaUploadRequest extends ChatMediaRequest {
  conversationId?: string;
  objectPath?: string;
  originalName?: string;
}

interface ProcessChatMediaRequest extends CompleteChatMediaUploadRequest {
  mediaType?: string;
}

async function resolveClientId<T extends ChatMediaRequest>(
  request: CallableRequest<T>,
): Promise<string> {
  if (!request.auth?.uid) {
    throw new HttpsError("unauthenticated", "Authentication required");
  }

  const requestedClientId = request.data.clientId?.trim();
  if (!requestedClientId) {
    return (await getCallerClient(request.auth)).clientId;
  }

  const userSnapshot = await db.collection("users").doc(request.auth.uid).get();
  const userData = userSnapshot.data();
  const panels = Array.isArray(userData?.panels) ? userData.panels : [];
  if (userData?.isAdmin === true || panels.includes("chat")) {
    return requestedClientId;
  }

  const callerClientId = (await getCallerClient(request.auth)).clientId;
  if (callerClientId !== requestedClientId) {
    throw new HttpsError("permission-denied", "Cannot upload media for this client");
  }
  return callerClientId;
}

async function verifyConversation(
  clientId: string,
  conversationId: string | undefined,
): Promise<string> {
  const normalizedId = conversationId?.trim();
  if (!normalizedId) {
    throw new HttpsError("invalid-argument", "conversationId is required");
  }
  const conversationPath = `${clientCol(clientId, Collections.conversations)}/${normalizedId}`;
  if (!(await db.doc(conversationPath).get()).exists) {
    throw new HttpsError("not-found", "Conversation not found");
  }
  return normalizedId;
}

function downloadUrl(objectPath: string, token: string): string {
  return `https://firebasestorage.googleapis.com/v0/b/${CHAT_MEDIA_BUCKET}/o/${encodeURIComponent(objectPath)}?alt=media&token=${token}`;
}

function runProcess(command: string, args: string[]): Promise<string> {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, { windowsHide: true });
    let output = "";
    child.stdout.on("data", (chunk: Buffer) => {
      output += chunk.toString();
    });
    child.stderr.on("data", (chunk: Buffer) => {
      output = `${output}${chunk.toString()}`.slice(-12000);
    });
    child.on("error", reject);
    child.on("close", (code) => {
      if (code === 0) resolve(output);
      else reject(new Error(`Media process exited with code ${code}: ${output}`));
    });
  });
}

async function mediaDuration(inputPath: string): Promise<number> {
  const output = await runProcess(ffprobeStatic.path, [
    "-v", "error",
    "-show_entries", "format=duration",
    "-of", "default=noprint_wrappers=1:nokey=1",
    inputPath,
  ]);
  const duration = Number(output.trim().split(/\r?\n/).at(-1));
  if (!Number.isFinite(duration) || duration <= 0) {
    throw new HttpsError("invalid-argument", "The media duration could not be read");
  }
  return duration;
}

function outputObjectPath(objectPath: string, extension: string): string {
  return `${objectPath.replace(/\.[^/.]+$/, "")}_processed.${extension}`;
}

export const prepareChatMediaUpload = onCall(
  callableOptions,
  async (request: CallableRequest<PrepareChatMediaUploadRequest>) => {
    const clientId = await resolveClientId(request);
    const conversationId = await verifyConversation(
      clientId,
      request.data.conversationId,
    );
    const contentType = request.data.contentType?.trim() || "application/octet-stream";
    const size = Number(request.data.size);
    if (!Number.isSafeInteger(size) || size <= 0 || size > MAX_DIRECT_UPLOAD_BYTES) {
      throw new HttpsError(
        "invalid-argument",
        "Attachment must be between 1 byte and 250 MB",
      );
    }

    const originalName = request.data.originalName?.trim() || "attachment";
    const fileName = (request.data.fileName?.trim() || originalName)
      .replace(/[^A-Za-z0-9._-]/g, "_")
      .substring(0, 180);
    const objectPath = `chat_media/${clientId}/${conversationId}/${Date.now()}_${randomUUID()}_${fileName}`;
    const [uploadUrl] = await storage.bucket(CHAT_MEDIA_BUCKET).file(objectPath).getSignedUrl({
      version: "v4",
      action: "write",
      expires: Date.now() + 15 * 60 * 1000,
      contentType,
      extensionHeaders: { "x-goog-meta-upload-state": "pending" },
    });

    return { uploadUrl, objectPath, contentType, originalName };
  },
);

export const completeChatMediaUpload = onCall(
  callableOptions,
  async (request: CallableRequest<CompleteChatMediaUploadRequest>) => {
    const clientId = await resolveClientId(request);
    const conversationId = await verifyConversation(
      clientId,
      request.data.conversationId,
    );
    const objectPath = request.data.objectPath?.trim();
    const requiredPrefix = `chat_media/${clientId}/${conversationId}/`;
    if (!objectPath?.startsWith(requiredPrefix)) {
      throw new HttpsError("permission-denied", "Invalid attachment path");
    }

    const file = storage.bucket(CHAT_MEDIA_BUCKET).file(objectPath);
    const [metadata] = await file.getMetadata();
    const size = Number(metadata.size);
    if (!Number.isSafeInteger(size) || size <= 0 || size > MAX_DIRECT_UPLOAD_BYTES) {
      await file.delete({ ignoreNotFound: true });
      throw new HttpsError("invalid-argument", "Uploaded attachment has an invalid size");
    }

    const token = randomUUID();
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
  },
);

export const uploadChatMedia = onCall(
  { ...callableOptions, memory: "512MiB", timeoutSeconds: 120 },
  async (request: CallableRequest<UploadChatMediaRequest>) => {
    const clientId = await resolveClientId(request);
    const conversationId = request.data.conversationId?.trim();
    const base64Data = request.data.base64Data;
    const contentType = request.data.contentType?.trim() || "application/octet-stream";
    const originalName = request.data.originalName?.trim() || "attachment";
    const fileName = (request.data.fileName?.trim() || originalName)
      .replace(/[^A-Za-z0-9._-]/g, "_")
      .substring(0, 180);

    if (!conversationId || !base64Data) {
      throw new HttpsError(
        "invalid-argument",
        "conversationId and file data are required",
      );
    }
    if (base64Data.length > Math.ceil(MAX_ATTACHMENT_BYTES * 4 / 3) + 4) {
      throw new HttpsError("invalid-argument", "Attachment exceeds the 20 MB limit");
    }

    await verifyConversation(clientId, conversationId);

    const bytes = Buffer.from(base64Data, "base64");
    if (bytes.length === 0 || bytes.length > MAX_ATTACHMENT_BYTES) {
      throw new HttpsError("invalid-argument", "Attachment exceeds the 20 MB limit");
    }

    const token = randomUUID();
    const objectPath = `chat_media/${clientId}/${conversationId}/${Date.now()}_${fileName}`;
    await storage.bucket(CHAT_MEDIA_BUCKET).file(objectPath).save(bytes, {
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
  },
);

export const processChatMedia = onCall(
  {
    ...callableOptions,
    memory: "2GiB",
    timeoutSeconds: 540,
    maxInstances: 3,
  },
  async (request: CallableRequest<ProcessChatMediaRequest>) => {
    const clientId = await resolveClientId(request);
    const conversationId = await verifyConversation(
      clientId,
      request.data.conversationId,
    );
    const objectPath = request.data.objectPath?.trim();
    const requiredPrefix = `chat_media/${clientId}/${conversationId}/`;
    if (!objectPath?.startsWith(requiredPrefix)) {
      throw new HttpsError("permission-denied", "Invalid attachment path");
    }
    const mediaType = request.data.mediaType?.trim();
    if (mediaType !== "video" && mediaType !== "audio") {
      throw new HttpsError("invalid-argument", "mediaType must be video or audio");
    }
    if (!ffmpegPath || !ffprobeStatic.path) {
      throw new HttpsError("failed-precondition", "Media processor is unavailable");
    }

    const bucket = storage.bucket(CHAT_MEDIA_BUCKET);
    const sourceFile = bucket.file(objectPath);
    const [sourceMetadata] = await sourceFile.getMetadata();
    const sourceSize = Number(sourceMetadata.size);
    if (!Number.isSafeInteger(sourceSize) || sourceSize <= 0 || sourceSize > MAX_DIRECT_UPLOAD_BYTES) {
      throw new HttpsError("invalid-argument", "Uploaded media has an invalid size");
    }

    const workDir = await mkdtemp(join(tmpdir(), "chat-media-"));
    const inputPath = join(workDir, "input");
    const extension = mediaType === "video" ? "mp4" : "m4a";
    const contentType = mediaType === "video" ? "video/mp4" : "audio/mp4";
    const outputPath = join(workDir, `output.${extension}`);
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
        const totalKbps = Math.floor(
          (MAX_PROCESSED_MEDIA_BYTES * 8 * 0.9) / duration / 1000,
        );
        let videoKbps = Math.max(100, Math.min(1800, totalKbps - 96));
        for (let attempt = 0; attempt < 3; attempt++) {
          const maxWidth = videoKbps < 250 ? 426 : videoKbps < 450 ? 640 : videoKbps < 900 ? 854 : 1280;
          await runProcess(ffmpegPath, [
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
          if ((await stat(outputPath)).size <= MAX_PROCESSED_MEDIA_BYTES) break;
          videoKbps = Math.max(100, Math.floor(videoKbps * 0.72));
        }
      } else {
        const audioKbps = Math.max(
          32,
          Math.min(
            128,
            Math.floor((MAX_PROCESSED_MEDIA_BYTES * 8 * 0.9) / duration / 1000),
          ),
        );
        await runProcess(ffmpegPath, [
          "-y", "-i", inputPath,
          "-vn", "-c:a", "aac", "-b:a", `${audioKbps}k`,
          "-movflags", "+faststart",
          outputPath,
        ]);
      }

      const processedSize = (await stat(outputPath)).size;
      if (processedSize <= 0 || processedSize > MAX_PROCESSED_MEDIA_BYTES) {
        throw new HttpsError(
          "resource-exhausted",
          "The media could not be reduced below 15 MB",
        );
      }

      const token = randomUUID();
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
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      console.error("Chat media processing failed", {
        mediaType,
        objectPath,
        error: error instanceof Error ? error.message : String(error),
      });
      throw new HttpsError("internal", "Media processing failed");
    } finally {
      await rm(workDir, { recursive: true, force: true });
    }
  },
);

export const cleanupAbandonedChatMedia = onSchedule(
  {
    region: "asia-south1",
    schedule: "every 24 hours",
    timeZone: "Asia/Kolkata",
    timeoutSeconds: 540,
  },
  async () => {
    const cutoff = Date.now() - 24 * 60 * 60 * 1000;
    const bucket = storage.bucket(CHAT_MEDIA_BUCKET);
    const [files] = await bucket.getFiles({ prefix: "chat_media/" });
    let deleted = 0;
    for (const file of files) {
      const [metadata] = await file.getMetadata();
      const uploadState = metadata.metadata?.uploadState ??
        metadata.metadata?.["upload-state"];
      const createdAt = Date.parse(metadata.timeCreated || "");
      if (
        (uploadState === "pending" || uploadState === "processing") &&
        Number.isFinite(createdAt) &&
        createdAt < cutoff
      ) {
        await file.delete({ ignoreNotFound: true });
        deleted++;
      }
    }
    console.info("Abandoned chat media cleanup complete", { deleted });
  },
);
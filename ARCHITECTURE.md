# Architecture

## Server

Python + FastAPI is the initial server target because it is practical on Linux SBCs, easy to test and provides a clear HTTP API.

Responsibilities:
- authentication and device pairing;
- upload sessions;
- resumable chunk transfer;
- file finalization;
- metadata extraction;
- indexing;
- search/filter API;
- preview generation;
- archive operations;
- audit log.

## Client

Flutter is the target GUI stack for Android and desktop. The same application should cover Android, Windows and Linux/ARM64.

Responsibilities:
- device pairing;
- browsing local files;
- selecting backup sources;
- manual transfers;
- sync policy;
- transfer queue;
- server library browsing;
- preview;
- copy/move commands.

## Storage

The server separates physical file storage, metadata index and generated previews.

Suggested layout:

/srv/phone-vault/
  storage/
    devices/
      <device-id>/
  previews/
  db/
    phone-vault.sqlite3
  logs/

## Metadata

A file record should contain:
- stable internal ID;
- device ID;
- original path;
- archive path;
- filename;
- size;
- MIME type;
- extension;
- filesystem timestamps;
- media capture timestamp when available;
- SHA-256 or equivalent content identity;
- width/height for images/video;
- duration for video;
- GPS latitude/longitude when available;
- indexing state;
- transfer state.

The model must distinguish source path, stored path and logical file identity.

## Transfer protocol

Initial API:

POST /api/v1/devices/pair
POST /api/v1/uploads
PUT /api/v1/uploads/{id}/chunks/{number}
GET /api/v1/uploads/{id}
POST /api/v1/uploads/{id}/complete
GET /api/v1/files
GET /api/v1/files/{id}
GET /api/v1/previews/{id}
POST /api/v1/archive/copy
POST /api/v1/archive/move

Upload lifecycle:

created -> uploading -> verifying -> indexed -> complete

Failure states must be recoverable without exposing incomplete files.

## Deduplication

Use a staged identity check:
1. size;
2. file metadata;
3. inexpensive fingerprint when available;
4. full cryptographic hash when required.

Equal filenames are never proof of equal content.

## Preview generation

- Images: Pillow/ImageMagick-compatible pipeline.
- Video: FFmpeg.
- PDF: PDF renderer.
- Office formats: initially convert/preview through LibreOffice or a dedicated parser.

Preview generation is asynchronous and must not block file ingestion.

## Android storage model

Use Android platform APIs:
- MediaStore for photos/videos/audio.
- Storage Access Framework for arbitrary user-selected directories/files.
- Explicit handling of modern scoped-storage restrictions.
- EXIF/GPS access only with required Android permissions.

## Security boundaries

The server must never trust client-provided destination paths, MIME types, filenames, archive paths, hashes or metadata.

All paths are canonicalized and constrained to configured roots.

Destructive actions are separate from backup ingestion.

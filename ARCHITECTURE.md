# Architecture

## Product priority

Phone Vault is first a background backup system for Android smartphones. The first useful outcome is that photos and videos are copied incrementally from one or more phones to a user-controlled server without requiring the user to open the app for every transfer. Chat exports and browser bookmarks/favorites are the next priority data classes. Advanced cataloguing, desktop workflows and AI features follow later and must not delay dependable ingestion.

## Server

Python + FastAPI is the initial server target because it is practical on Linux SBCs, easy to test and provides a clear HTTP API.

Responsibilities:
- authentication, device pairing and revocation;
- upload sessions and resumable chunk transfer;
- idempotent ingestion and integrity verification;
- file finalization and metadata extraction;
- media, chat-export and bookmark-snapshot indexing;
- source provenance and per-device/per-category backup state;
- health, audit and future read-only integration API for Ai-gateway.

The server is independent from the GUI and should run headless on PC or ARM/Linux SBC.

## Android client

Flutter is the target UI stack; Android-specific collection and background execution use native Android APIs/plugins where required.

Responsibilities:
- device pairing and scoped credentials;
- media inventory using MediaStore;
- incremental detection of new/changed photos and videos;
- durable upload queue and resumable transfer state;
- WorkManager scheduling and network/battery constraints;
- visible backup status, errors, last successful run and manual trigger;
- opt-in source adapters for chat exports and browser bookmarks;
- user-selected SAF sources where supported;
- explicit controls for categories, apps, network and charging policies.

The same Flutter codebase may later provide desktop administration, but Android backup reliability takes priority over desktop feature parity.

## Background execution model

1. A WorkManager task starts a bounded scan/sync cycle when OS constraints permit.
2. The client queries MediaStore incrementally using persisted scan state and stable media identifiers plus metadata; it reconciles changes and deletions without deleting server copies.
3. New candidates enter a durable queue. The client asks the server which content is already present and which upload sessions can resume.
4. Files are streamed in bounded chunks. Upload progress and verified chunk state are persisted.
5. Server verifies the complete content hash, atomically finalizes the object and updates its index.
6. Client records success and advances its scan cursor only when server acknowledgement is durable.
7. On process death, reboot or network loss, the next scheduled run reconciles with server state and resumes safely.

Do not rely on a permanently running Android process, exact alarms or unrestricted background services. Android Doze, battery saver, OEM task killers and network policy can delay work. The UI must distinguish pending/deferred work from failure. A foreground service is reserved for a user-visible ongoing transfer when required by platform policy.

## Data-source adapters

### Photos and videos
Use MediaStore and current Android permission model. Request only the media access needed by selected categories. Handle partial photo/video permissions on newer Android versions. Use content URIs rather than assuming filesystem paths. Record capture timestamp and available dimensions/duration/EXIF as metadata. GPS extraction and backup policy must be explicit.

### Chats and messaging data
There is no generic Android API that grants one app unrestricted access to another app's private message database. Initial support is based on user-initiated exports or documented app-supported backup/export mechanisms, imported through a controlled file/document flow. Each app adapter must document format, attachments, timestamps, edits/deletions, group metadata, encryption and completeness limitations.

Notification access may be considered only as a separate, explicitly opt-in, best-effort capture source. It is not a complete chat backup: notifications can be disabled, redacted, grouped, truncated, missed while the device is offline, or omit history and attachments. It must never be described as equivalent to a full conversation export. Do not bypass app sandboxing or encryption.

### Browser bookmarks/favorites
Treat bookmarks/favorites as a separate source from open tabs and browsing history. Prefer documented browser export/import or supported browser integration. Where no public API exists, allow the user to export or select a bookmark file through Android's document picker. Store snapshots with browser name, device, export timestamp and source metadata. Do not read another browser's private database or extract its credentials. Open-tab capture is a later, separate capability and only where a supported API/export exists.

### Other files
Downloads, Documents, audio and arbitrary SAF trees are later opt-in source adapters. They must reuse the same queue, transfer, provenance and integrity pipeline.

## Storage

Separate physical binary objects, source snapshots, metadata index, previews and database.

Suggested layout:

/srv/phone-vault/
  storage/
    devices/
      <device-id>/
    imports/
      chats/
      bookmarks/
  previews/
  db/
    phone-vault.sqlite3
  logs/

The exact layout is configurable. The server must not trust client-provided destination paths.

## Metadata and provenance

Each ingested object or snapshot should include:
- stable internal ID and content hash;
- device ID and source category;
- source application/provider and adapter version where applicable;
- original filename/path or logical source identifier;
- stored object path;
- MIME type, size and relevant media metadata;
- source creation/capture time when available;
- ingestion/backup time;
- export/snapshot time for chats and bookmarks;
- transfer and indexing state;
- integrity verification result.

Preserve raw exports as immutable source artifacts. Parsed records are derived data and must retain a link to the original export and parser version. Re-importing the same export should be idempotent.

## Transfer protocol

Initial API:
- device pairing and status;
- backup inventory/reconciliation;
- upload session creation/status;
- chunk upload and completion;
- media/object metadata and search;
- chat-export and bookmark-snapshot import;
- backup job status and audit.

Upload lifecycle:

created -> uploading -> verifying -> indexed -> complete

Failure states must be recoverable without exposing incomplete files. A client must not advance its durable cursor before server acknowledgement.

## Deduplication and conflict handling

Use content identity (cryptographic hash) for exact duplicate detection. Size, filename, timestamps and metadata are only candidate filters, never proof of equality. Keep source provenance even when identical bytes arrive from multiple devices. A changed media item is a new version/object unless a safe identity rule proves otherwise. Never infer that absence from a phone means permission to delete the server copy.

## Future Ai-gateway integration

Phone Vault exposes a narrow, authenticated, read-oriented API for authorized search and retrieval. Ai-gateway may later:
- search media/chat/bookmark metadata;
- request selected content or bounded excerpts;
- summarize or classify data under explicit user policy;
- create user-approved organization suggestions or workflows.

Ai-gateway must not be required for ingestion, must not gain blanket access by default, and must not delete or modify original backup data. Permissions should be scoped by device, category, date range and operation. Raw chat content, GPS and sensitive media require explicit grants.

## Security boundaries

- Device pairing credentials are short-lived; device identities are revocable.
- Uploads are written below configured storage roots only.
- Paths are canonicalized before filesystem access.
- Uploaded files remain temporary until verification succeeds.
- Preview/parsing runs in controlled workers with resource limits.
- Chat exports, browser data and media metadata are sensitive.
- No credential extraction from browser profiles or messaging apps.
- Archive Move/Delete is separate from backup ingestion and requires explicit authorization.
- Logs must not contain auth secrets or unnecessary message/media contents.
- TLS should be available; LAN is not treated as a security boundary.

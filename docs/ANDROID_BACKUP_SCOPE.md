# Android backup scope and delivery contract

Status: product priority and acceptance baseline. This document does not claim that background scheduling, chat adapters, browser bookmark adapters, contact sync or media browsing are implemented.

## Objective

Phone Vault's first priority is to make an Android phone quietly and reliably copy selected personal data to a server in the background. The phone remains the source of truth for originals; the server is a durable copy and later discovery/AI substrate.

The first data set is:
- photos;
- videos;
- contacts;
- chat history and attachments, using app-supported exports or explicitly supported adapters;
- browser bookmarks/favorites.

The first engineering milestone should not wait for all data sources. Deliver photos/video background backup first, then contacts, chat and bookmark import as separate source adapters over the same durable ingestion pipeline.

The Android client must also let the user browse and view backed-up photos and videos stored on the server. This is a read/retrieval path, distinct from phone-to-server backup.

## Required behavior

### Background photo/video sync
- User pairs a phone and explicitly enables Photos and/or Videos.
- Initial scan discovers the existing selected library; subsequent scans are incremental.
- New media is queued automatically and uploaded when configured constraints and Android scheduling allow.
- The client can pause, resume and run a manual sync.
- Uploads survive app process death, reboot, Wi-Fi changes, server restart and partial transfer.
- A server acknowledgement is required before the client marks an item complete or advances durable reconciliation state.
- The server verifies content and finalizes atomically.
- Source files remain untouched. A missing or deleted source item does not delete the server copy.
- UI reports last successful backup, pending count, failures, deferred-by-OS state and per-category status.

### Android scheduling reality
"Background" means OS-scheduled, persistent and opportunistic work, not a promise of an always-running daemon or immediate upload at every file creation. WorkManager is the default scheduler for deferrable periodic/one-time sync. Android may defer jobs because of Doze, battery saver, quotas, network constraints and OEM power management. The product should explain this and expose a manual trigger. Use a foreground service only for a user-visible long-running transfer when platform rules require it. Do not ask users to disable battery protections by default.

### Contact backup and restore boundary
- Request Android Contacts permissions only after the user enables contact backup.
- Read contacts through the supported Contacts Provider APIs; do not access private app databases.
- Preserve a versioned raw export/snapshot and normalized records with stable source identifiers where available, account/source metadata, names, phone numbers, email addresses, organization fields, notes and relevant structured fields supported by the provider.
- Handle multiple contact accounts, aggregated contacts, duplicate/raw contacts, deleted or merged records and partial permissions explicitly. Do not assume one visible contact maps to one underlying raw record.
- Make the default operation backup-only and non-destructive. Any restore/import into the phone must be a separate, user-initiated action with preview, duplicate/conflict handling and explicit confirmation. Never silently overwrite or delete phone contacts.
- Treat contact data as highly sensitive; keep it on the user's server and exclude it from broad AI access by default.

### Chat ingestion boundary
Android does not provide a universal permission to read other applications' private chat databases. The baseline is:
1. user exports a conversation/chat archive using the messaging app's supported feature;
2. user shares or selects the export in Phone Vault;
3. Phone Vault preserves the raw archive and attachments;
4. an app-specific parser may extract messages and metadata.

Each adapter must publish a capability matrix: text, attachments, sender/group, timestamps, edits, deletions, reactions, quoted messages, voice notes and export completeness. Unsupported fields remain absent/unknown, not guessed. Keep raw export even when parsing fails or format is unsupported.

A future notification-listener adapter is a distinct optional feature requiring a separate explicit Android grant. It can only capture notifications visible to the listener and is inherently incomplete; it is not a replacement for chat export. It may miss muted/redacted/old messages, attachments, offline activity and content not surfaced in notifications. Do not access private app data or bypass end-to-end encryption.

### Bookmark/favorites ingestion boundary
First support user-selected browser bookmark exports or files through Android's document picker/share flow. Normalize URL, title, folder hierarchy, order and timestamps when present, but preserve the original export as an immutable snapshot. Browser support is adapter-specific; do not assume a common Android bookmark API.

Bookmarks/favorites are not the same as:
- open tabs (a point-in-time set of currently open pages);
- browsing history;
- cookies, passwords or authentication state.

Open tabs may be considered later only through a documented browser capability or explicit user export. No private browser database scraping or credential collection.

### In-app server media library
- The client can request a paginated media catalog from the server and browse backed-up photos/videos without first downloading the full library.
- The server provides bounded thumbnails/previews and metadata; original files are retrieved or streamed only when opened or played.
- Support image viewing and video playback using platform-native capabilities where practical; cache previews and recently accessed media with explicit storage limits and cache eviction.
- Distinguish remote-only, cached, downloading, available and unavailable items. Handle server offline/network loss without corrupting the catalog.
- Access is authenticated and scoped to the paired user's library. No public media URLs or unauthenticated file access.
- Browsing and viewing must not modify or delete backup originals. Destructive archive management is a separate explicit workflow.

## Shared ingestion model

Every source adapter produces a bounded, versioned manifest and references content through the same upload/import manager. Common fields:
- device ID;
- source category and source application;
- source item stable ID when available;
- source timestamps and observation time;
- size and MIME type where applicable;
- content hash;
- adapter/parser version;
- import/transfer session ID;
- consent/configuration scope.

Binary artifacts are stored immutably. Parsed metadata is derived and linked to the raw artifact. Re-import must be idempotent. Deduplication must not erase provenance from multiple devices or source apps.

## Cross-platform and architecture expansion

The initial delivery target remains Android client plus a server that runs on the current supported Linux/PC baseline. After the Android backup, contacts and remote media-library workflows are stable, expand deliberately:
1. server packaging/support for additional operating systems and CPU architectures;
2. client support for additional mobile and desktop operating systems;
3. architecture-specific builds and installation/update paths, including x86_64 and ARM64 first, with other targets selected by demand and testability.

Keep protocol, storage model and API independent of UI framework and CPU architecture. Use capability negotiation rather than assuming every client/OS supports every source or feature. Maintain a compatibility matrix and automated tests per supported OS/architecture. Do not claim universal portability until each target has packaging, installation, upgrade, backup/restore and integration-test coverage.

## Ai-gateway relationship

Phone Vault owns acquisition, durable storage, source provenance, indexing and user access controls. Ai-gateway is a later consumer, not a dependency of the backup pipeline.

Initial integration should be read-only and scoped:
- query permitted metadata;
- retrieve selected objects or bounded excerpts;
- request summaries/classification only after explicit authorization;
- return provenance with every result.

No default bulk access to all photos, contacts, chats, GPS or browser data. No AI-initiated deletion or mutation of originals. Phone Vault must continue backing up when Ai-gateway is unavailable.

## Definition of first release

A paired Android phone can automatically and incrementally back up photos/videos to the server under user-selected constraints; the system recovers safely from process/device/network/server interruptions; integrity is verified; no source data is deleted; the user can see what is backed up and what remains pending.

Contacts backup is a separately gated source milestone. The client can then browse and view backed-up photos/videos from the server. Chat export and bookmark snapshot ingestion follow through the same source/transfer foundations.
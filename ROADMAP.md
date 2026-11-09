# Roadmap

## Priority principle

The first product outcome is reliable background backup from Android smartphones to a self-hosted server, followed by access to the backed-up library from the phone itself. Prioritize data collection, durability, resumability, integrity and safe retrieval over desktop polish, advanced indexing or AI features.

Priority order:
1. Photos and videos copied automatically in the background.
2. Contact backup with explicit permissions and safe snapshot/reconciliation.
3. Browse and view server-stored photos/videos in the Android client.
4. Chat history imported through supported exports and explicitly supported app-specific mechanisms.
5. Browser bookmarks/favorites imported from supported browsers or user-selected exports.
6. Reliability, multi-device operation, storage/index health and basic browsing/search.
7. Expand server and client support to additional operating systems and CPU architectures.
8. Ai-gateway integration and AI-assisted analysis/organization as that project matures.

## Phase 0 — Foundation and safe transfer pipeline
- [x] Create repository and define local-first architecture.
- [x] Define Android + Flutter client direction.
- [x] Define server/client separation.
- [x] Initial requirements and security model.
- [x] Initial FastAPI server bootstrap and safe Flutter transfer client (see implementation commits).
- [x] Resumable upload and integrity-check foundation.
- [ ] Freeze protocol v0.1 around device inventory, upload reconciliation and backup source metadata.
- [ ] Add CI skeleton and repeatable server/client integration tests.

## Phase 1 — Automatic photo/video backup (highest priority)
Definition of Done: a paired Android phone backs up new photos and videos to the server without requiring the app to remain open, subject to Android scheduling and user-configured constraints.

- [ ] MediaStore scanner with stable incremental scan state.
- [ ] Explicit photo/video permissions, including partial access behavior on current Android.
- [ ] Durable local backup inventory and queue.
- [ ] WorkManager periodic and constrained one-time jobs.
- [ ] Configurable Wi-Fi-only / unmetered / charging preferences.
- [ ] Resumable chunk uploads using existing transfer pipeline.
- [ ] Server/client reconciliation after app restart, reboot and network loss.
- [ ] Content hash verification and idempotent deduplication.
- [ ] Per-device backup status, last successful sync, pending/error counts.
- [ ] Manual "Back up now" and safe pause/resume.
- [ ] Never delete or alter phone originals.
- [ ] Test with screen off, Doze, battery saver, OEM background restrictions, large files and interrupted transfers.

## Phase 2 — Contact backup
Definition of Done: user can explicitly enable contact backup, review what source/accounts and fields are collected, and preserve recoverable versioned snapshots on the server without modifying the phone address book.

- [ ] Contacts Provider integration and permission lifecycle.
- [ ] Model aggregated and raw contacts, accounts and source provenance.
- [ ] Versioned export/snapshot and incremental change detection where reliable.
- [ ] Handle duplicates, merges, deletions and account changes without destructive assumptions.
- [ ] Contact count/status and last successful backup in client UI.
- [ ] Tests for multiple accounts, duplicate contacts, permission revocation and provider changes.
- [ ] Any future restore/import must have preview, explicit confirmation and conflict handling.

## Phase 3 — Server media library in Android client
Definition of Done: user can browse backed-up photos/videos from the server in the Android app and open images or play videos without downloading the entire library first.

- [ ] Authenticated paginated catalog and filters.
- [ ] Bounded thumbnail/preview generation and retrieval.
- [ ] Image viewer and video playback/streaming or resumable on-demand download.
- [ ] HTTP range support for video where practical.
- [ ] Bounded cache with user-visible storage use and safe eviction.
- [ ] Remote-only/cached/loading/offline/unavailable states.
- [ ] Large-library pagination, network interruption and access-control tests.
- [ ] Viewer cannot alter or delete backup originals.

## Phase 4 — Chat backup ingestion
Definition of Done: user can enable a documented source for a supported messaging app, export or select its backup, and preserve the raw export plus parsed metadata/content where legally and technically supported.

- [ ] Generic chat-export import pipeline (document picker/share target).
- [ ] Immutable raw export storage, hash and provenance.
- [ ] Idempotent re-import and duplicate detection.
- [ ] App-specific adapters for formats the project explicitly supports.
- [ ] Preserve attachments and associate them with messages where export format permits.
- [ ] Preserve sender/group/time/edit/delete metadata where available.
- [ ] Document completeness gaps and unsupported formats per app.
- [ ] Optional notification capture evaluated separately; never present it as complete chat backup.
- [ ] Explicit opt-in and local-only handling for sensitive message content.

## Phase 5 — Browser bookmarks/favorites
Definition of Done: user can export or select a supported browser bookmark collection and have it backed up as a versioned snapshot on the server.

- [ ] Define browser source adapter interface.
- [ ] Support user-selected HTML/JSON export formats where available.
- [ ] Add browser-specific documented integration only where supported.
- [ ] Preserve URL, title, folder/hierarchy, order and timestamps when present.
- [ ] Version snapshots and make re-import idempotent.
- [ ] Keep bookmarks distinct from open tabs and browsing history.
- [ ] Do not read browser private databases or extract credentials.
- [ ] Evaluate open-tab capture as a separate later capability.

## Phase 6 — Basic library, index and reliability
- [ ] SQLite schema for media, contacts, chat exports, bookmark snapshots and provenance.
- [ ] Basic media metadata and EXIF extraction with explicit GPS policy.
- [ ] Search/filter by device, source, date, type and size.
- [ ] Basic server-side browsing and backup health.
- [ ] Storage usage, capacity warnings and database backup/restore.
- [ ] Transfer and import audit history.
- [ ] Large-library and restart/power-loss tests.

## Phase 7 — Additional sources and richer management
- [ ] Downloads, Documents, audio and arbitrary user-selected SAF trees.
- [ ] Desktop UI improvements and multi-device management.
- [ ] Archive folders, copy/move workflows, conflict policies and dry-run.
- [ ] More parsers and duplicate-group views.
- [ ] Optional rule-based organization.

## Phase 8 — Cross-platform expansion
- [ ] Separate protocol/API compatibility from client and server packaging.
- [ ] Server packaging for Linux x86_64 and ARM64, then selected Windows/macOS or other OS targets based on demand.
- [ ] Client builds for selected Android, Windows, Linux, macOS and other mobile platforms where APIs permit.
- [ ] Capability negotiation for platform-specific source collection and media playback.
- [ ] Installation, upgrade, service management, backup/restore and integration tests per target.
- [ ] Publish a tested OS/architecture compatibility matrix; do not mark untested targets supported.

## Phase 9 — Ai-gateway integration (as Ai-gateway develops)
- [ ] Define authenticated read-only integration contract.
- [ ] Search Phone Vault metadata from Ai-gateway.
- [ ] Retrieve user-selected media, contact fields, chat excerpts and bookmark records with bounded responses.
- [ ] Per-device/per-category grants and audit.
- [ ] AI summaries, classification and organization suggestions only after explicit user enablement.
- [ ] Keep Phone Vault fully functional if Ai-gateway is offline or absent.
- [ ] Never allow AI to delete source backups or silently alter originals.

## Non-goals for the initial backup release

- Cloud synchronization or mandatory external accounts.
- Public Internet exposure by default.
- Social sharing.
- AI photo classification or autonomous organization.
- Automatic deletion from phones or server-side destructive sync.
- Universal extraction of private chats from every messaging app.
- Universal access to private browser databases, cookies, passwords or browsing profiles.
- Full office-suite editing.

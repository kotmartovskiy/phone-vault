# Roadmap

## Priority principle

The first product outcome is reliable background backup from Android smartphones to a self-hosted server. Prioritize data collection, durability, resumability and integrity over desktop polish, advanced indexing or AI features.

Priority order:
1. Photos and videos copied automatically in the background.
2. Chat history imported through supported exports and explicitly supported app-specific mechanisms.
3. Browser bookmarks/favorites imported from supported browsers or user-selected exports.
4. Reliability, multi-device operation, storage/index health and basic browsing/search.
5. Broader file sources, richer indexing/preview and archive management.
6. Ai-gateway integration and AI-assisted analysis/organization as that project matures.

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

## Phase 2 — Chat backup ingestion
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

## Phase 3 — Browser bookmarks/favorites
Definition of Done: user can export or select a supported browser bookmark collection and have it backed up as a versioned snapshot on the server.

- [ ] Define browser source adapter interface.
- [ ] Support user-selected HTML/JSON export formats where available.
- [ ] Add browser-specific documented integration only where supported.
- [ ] Preserve URL, title, folder/hierarchy, order and timestamps when present.
- [ ] Version snapshots and make re-import idempotent.
- [ ] Keep bookmarks distinct from open tabs and browsing history.
- [ ] Do not read browser private databases or extract credentials.
- [ ] Evaluate open-tab capture as a separate later capability.

## Phase 4 — Basic library, index and reliability
- [ ] SQLite schema for media, chat exports, bookmark snapshots and provenance.
- [ ] Basic media metadata and EXIF extraction with explicit GPS policy.
- [ ] Search/filter by device, source, date, type and size.
- [ ] Basic server-side browsing and backup health.
- [ ] Storage usage, capacity warnings and database backup/restore.
- [ ] Transfer and import audit history.
- [ ] Large-library and restart/power-loss tests.

## Phase 5 — Additional sources and richer management
- [ ] Downloads, Documents, audio and arbitrary user-selected SAF trees.
- [ ] Desktop UI improvements and multi-device management.
- [ ] Photo/video previews, thumbnails and playback.
- [ ] Archive folders, copy/move workflows, conflict policies and dry-run.
- [ ] More parsers and duplicate-group views.
- [ ] Optional rule-based organization.

## Phase 6 — Ai-gateway integration (as Ai-gateway develops)
- [ ] Define authenticated read-only integration contract.
- [ ] Search Phone Vault metadata from Ai-gateway.
- [ ] Retrieve user-selected media, chat excerpts and bookmark records with bounded responses.
- [ ] Per-device/per-category grants and audit.
- [ ] AI summaries, classification and organization suggestions only after explicit user enablement.
- [ ] Keep Phone Vault fully functional if Ai-gateway is offline or absent.
- [ ] Never allow AI to delete source backups or silently alter originals.

## Phase 7 — SBC / appliance and hardening
- [ ] Debian/Ubuntu ARM64 packaging and systemd service.
- [ ] Resource limits and headless operation.
- [ ] Health endpoint and storage monitoring.
- [ ] TLS option, token rotation and device revocation.
- [ ] Path traversal, malformed import, parser sandbox and upload tests.
- [ ] Power-loss recovery and large-library performance tests.

## Non-goals for the initial backup release

- Cloud synchronization or mandatory external accounts.
- Public Internet exposure by default.
- Social sharing.
- AI photo classification or autonomous organization.
- Automatic deletion from phones or server-side destructive sync.
- Universal extraction of private chats from every messaging app.
- Universal access to private browser databases, cookies, passwords or browsing profiles.
- Full office-suite editing.

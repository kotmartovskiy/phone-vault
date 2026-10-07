# Roadmap

## Phase 0 — Foundation
- [x] Create repository.
- [x] Define local-first architecture.
- [x] Define Android + Flutter client direction.
- [x] Define server/client separation.
- [x] Initial requirements and security model.
- [ ] Freeze protocol v0.1.
- [ ] Add CI skeleton.

## Phase 1 — Transfer MVP
Definition of Done: one Android device can reliably send a selected file to the server.

- [ ] FastAPI server bootstrap.
- [ ] Device registration.
- [ ] Pairing/authentication.
- [ ] File metadata endpoint.
- [ ] Chunked upload.
- [ ] Resume interrupted upload.
- [ ] SHA-256 verification.
- [ ] Atomic finalization.
- [ ] Transfer queue.
- [ ] Basic Android file picker.
- [ ] Basic desktop connection screen.
- [ ] Integration tests.

## Phase 2 — Automatic backup
- [ ] MediaStore scanner.
- [ ] Downloads/SAF integration.
- [ ] Incremental scan.
- [ ] File fingerprinting.
- [ ] Deduplication.
- [ ] Background sync.
- [ ] Wi-Fi/charging policies.
- [ ] Retry/backoff.
- [ ] Transfer history.
- [ ] Multiple Android devices.

## Phase 3 — Metadata index
- [ ] SQLite schema.
- [ ] EXIF extraction.
- [ ] GPS metadata.
- [ ] Video metadata.
- [ ] Document metadata.
- [ ] Search indexes.
- [ ] Date/size/type/device/GPS filters.
- [ ] Duplicate groups.

## Phase 4 — Preview and desktop UI
- [ ] Photo thumbnails.
- [ ] Photo viewer.
- [ ] Video thumbnails.
- [ ] Video playback.
- [ ] PDF preview.
- [ ] Office document preview strategy.
- [ ] Grid/list views.
- [ ] Selection and batch actions.
- [ ] Copy/Move to archive folders.
- [ ] Safe delete workflow.
- [ ] Transfer progress UI.

## Phase 5 — Archive automation
- [ ] Rule-based destination folders.
- [ ] Templates such as Photos/YYYY/MM.
- [ ] Import profiles.
- [ ] Conflict policies.
- [ ] Duplicate handling policies.
- [ ] Dry-run mode.
- [ ] Audit log.

## Phase 6 — SBC / appliance
- [ ] Debian/Ubuntu ARM64 packaging.
- [ ] systemd service.
- [ ] Resource limits.
- [ ] Headless operation.
- [ ] Health endpoint.
- [ ] Database backup/restore.
- [ ] Storage monitoring.
- [ ] Optional LAN Discovery integration.

## Phase 7 — Hardening
- [ ] TLS option.
- [ ] Device revocation.
- [ ] Token rotation.
- [ ] Rate limits.
- [ ] Path traversal tests.
- [ ] Malformed upload tests.
- [ ] Power-loss recovery tests.
- [ ] Large-library performance tests.
- [ ] Security review.

## Non-goals for the first release

- Cloud synchronization.
- Public Internet exposure.
- Social sharing.
- AI photo classification.
- Automatic deletion from phones.
- Full office-suite editing.


## Current implementation status — 2026-10-07

The repository is ahead of the original checkbox roadmap in several areas.

### Verified complete
- Server pairing and bearer-token authentication.
- Device-scoped API access.
- Resumable chunk uploads with offset reconciliation.
- SHA-256 verification and atomic finalization.
- Safe filename handling and upload isolation.
- Custom Flutter file explorer with multi-select, filtering, search and image preview.
- Android Keystore protection for the pairing token.
- Content-hash deduplication: a file already stored for the same device, size and SHA-256 is skipped before upload.
- Server startup migrated to FastAPI lifespan.
- Automated server API suite: 12 tests passing.
- Local development branch and local bare Git mirror created.

### Intentionally not enabled yet
- Automatic background backup.
- Trusted-server discovery/automatic connection.
- MediaStore/SAF incremental background scanner.
- Persistent transfer queue/history.
- Wi-Fi/charging policies and retry scheduling.
- Real-phone validation of resume/deduplication. The phone is not touched during the current development phase.

### Next engineering step
Build the persistent transfer queue and sync-policy layer as a platform-neutral core first. Android background execution will then become an adapter around that core rather than containing transfer logic itself.

- Persistent queue metadata storage using SharedPreferences, with interrupted `running` tasks recovered as `queued`.
- Platform-neutral `SyncPolicy` enforcing trusted-server, network, battery and charging conditions before automatic transfer.
- Platform-neutral `TransferManager` coordinating queue, persistence, policy, deduplication and resumable upload without enabling background execution yet.
- Flutter client suite: 16 tests passing; debug APK rebuilt successfully after queue/policy/manager changes.

### Intentionally not enabled yet
- Automatic background backup.
- Trusted-server discovery/automatic connection.
- MediaStore/SAF incremental background scanner.
- Android WorkManager/foreground transfer adapter.
- Real-phone validation of resume/deduplication. The phone is not touched during the current development phase.

### Next engineering step
Add a platform adapter boundary for network/server discovery and Android background execution. Keep the queue, policy and transfer manager platform-neutral; only then connect automatic sync to a trusted paired server. Real-phone testing remains deferred.

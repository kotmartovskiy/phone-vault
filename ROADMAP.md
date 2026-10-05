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

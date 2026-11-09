# Functional Requirements

## Core background backup

FR-001 Device pairing: a new Android device can pair with a server using a short-lived pairing flow.

FR-002 Background media backup: the Android client automatically copies newly discovered photos and videos to the paired server when Android scheduling and configured constraints permit.

FR-003 Incremental scan: media inventory resumes from durable scan state and reconciles additions/changes without requiring a full scan every run.

FR-004 Durable queue: pending uploads and retry state survive process death, reboot and network interruption.

FR-005 Resume: interrupted transfers resume without retransmitting already verified chunks.

FR-006 Integrity: the server verifies completed objects before exposing them as complete.

FR-007 Idempotency: repeated sync and retry do not create duplicate stored objects; identical content from different devices retains separate source provenance.

FR-008 Non-destructive backup: automatic backup never deletes or modifies originals on the phone and absence from the source never triggers server deletion.

FR-009 Background policy: user can configure Wi-Fi/unmetered network and charging constraints; the UI explains OS-deferred work and last successful sync.

FR-010 Multi-device: multiple phones share one server while preserving independent device identity, status and revocation.

## Contact backup

FR-011 Contact permission and collection: user explicitly enables contact backup; Android client reads through Contacts Provider and does not access private app databases.

FR-012 Contact preservation: preserve a versioned source snapshot plus normalized contact records, source/account identifiers and supported structured fields.

FR-013 Contact reconciliation: handle aggregated/raw contacts, multiple accounts, duplicates, merges and deletions without assuming a one-to-one mapping between visible and raw records.

FR-014 Safe restore: any future restore/import to the phone is user-initiated, previewed and explicitly confirmed; duplicate/conflict handling is visible; no silent overwrite or deletion.

## Chat backup

FR-015 Chat export import: user can import a messaging-app export through Android share/document picker or another documented supported mechanism.

FR-016 Raw preservation: original chat export and attachments are preserved immutably with content hash, source app, device and import timestamp.

FR-017 Parsing: supported app-specific adapters extract message records and metadata where format permits; parser version and source-export link are retained.

FR-018 Honest completeness: each adapter documents which messages, attachments, edits, deletions, reactions, group metadata and timestamps are or are not available. No universal access to other apps' private databases is assumed.

FR-019 Optional notification capture, if implemented, is a separately consented best-effort source and is never represented as complete chat history.

## Browser bookmarks/favorites

FR-020 Bookmark import: user can export or select a supported browser bookmark collection for backup.

FR-021 Bookmark fidelity: preserve URL, title, folder hierarchy/order and timestamps where available.

FR-022 Versioning: each import creates or updates a deduplicated snapshot without silently overwriting prior history.

FR-023 Source boundaries: bookmarks/favorites are distinct from open tabs, history, cookies and credentials. Open-tab backup is a separate future requirement.

## Server media library and client viewer

FR-024 Remote catalog: authenticated client can browse a paginated catalog of backed-up photos/videos without downloading all originals.

FR-025 Preview and playback: server supplies bounded thumbnails/previews; client can open images and stream or download videos on demand.

FR-026 Cache management: client caches previews and optionally recent media within configurable storage limits, distinguishes cached from remote-only items and evicts cache without affecting server originals.

FR-027 Resilience and access: browsing handles offline server/network interruption and all media retrieval remains authenticated and scoped.

## Library and future integration

FR-028 Index: each accepted file/export/snapshot receives an index record and provenance.

FR-029 Search: basic filtering by device, source category, date, size and type.

FR-030 Ai-gateway integration: later authenticated, read-only access to explicitly authorized metadata and selected content.

FR-031 Offline operation: server remains usable without Internet access and backup works over the configured LAN.

FR-032 Audit: device pairing, transfers, imports, parsing and destructive archive operations are logged without exposing secrets.

## Cross-platform expansion

FR-033 Portable protocol: API, transfer protocol and storage model are independent of client UI framework and CPU architecture, with explicit versioning and capability negotiation.

FR-034 Additional server targets: after the initial supported Linux/PC deployment is stable, add documented server builds for selected operating systems and CPU architectures.

FR-035 Additional clients: add clients for selected mobile/desktop operating systems and architectures with a published support matrix and target-specific tests.

## Non-functional requirements

- Local-first; no mandatory cloud dependency.
- Android background behavior must comply with WorkManager, Doze and current foreground-service restrictions. No guarantee of instant/uninterrupted sync when Android defers background work.
- Works on modest ARM Linux hardware in the initial server target.
- Recoverable after process restart, device reboot, server restart and power interruption.
- Large files are streamed/chunked rather than loaded into memory.
- API versioning and idempotent request semantics from the first public protocol.
- Chat, contacts and browser data are treated as sensitive and require explicit source/category consent.
- Phone Vault remains functional without Ai-gateway.
- Cross-platform support is claimed only for targets with installation, upgrade, recovery and integration-test coverage.

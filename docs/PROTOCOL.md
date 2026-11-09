# Protocol

## Principles

- REST/HTTPS control plane under `/api/v1/`.
- Resumable chunked object transfer.
- Explicit upload and import session states.
- Idempotent operations and stable request IDs.
- Server is authoritative for stored-object and verified-chunk state.
- Client advances durable source cursors only after durable server acknowledgement.
- Device identity and source provenance accompany every backup item.
- Raw contact snapshots, chat exports and bookmark snapshots are immutable source artifacts; parsed/indexed records are derived.
- No source-side deletion is part of backup protocol.
- API schemas and storage identifiers are independent of client UI framework and CPU architecture.

## Core resources

- `devices`: paired device identity, status, revocation and capabilities.
- `backup-sources`: enabled source category, adapter and source-specific cursor/version.
- `backup-jobs`: scheduled/manual run, constraints, progress and terminal state.
- `inventory`: client-discovered candidates and server reconciliation.
- `uploads`: media/object upload sessions, chunks, hash and verification.
- `imports`: contact snapshots, chat exports and bookmark-snapshot ingestion sessions.
- `objects`: immutable stored binary objects with source provenance.
- `records`: parsed media/contact/message/bookmark metadata linked to source objects.
- `media-catalog`: authenticated, paginated server-side media browsing.
- `previews`: bounded thumbnail/preview retrieval; originals are fetched or streamed on demand.
- `audit`: pairing, authorization, transfer, import and administrative events.

## Initial ingestion flows

### Media backup
1. Client scans MediaStore incrementally and sends a bounded inventory batch.
2. Server returns already-known content and resumable upload sessions.
3. Client streams missing content in chunks.
4. Server verifies size/hash and atomically finalizes the object.
5. Client receives durable acknowledgement and persists the new scan cursor/state.

### Contact snapshot
1. User explicitly enables contact backup and grants Contacts Provider permission.
2. Client reads supported contact/account data and creates a versioned snapshot with source provenance.
3. Snapshot and normalized records are transferred through an idempotent import session.
4. Server preserves raw snapshot and indexes supported fields; re-import does not silently overwrite prior versions.
5. Restore/import back to a phone is a separate user-confirmed operation, not part of backup.

### Chat export
1. User explicitly selects/shares an export from a supported messaging app.
2. Client identifies source app and format, computes hash and creates an import session.
3. Raw export and attachments are transferred and preserved.
4. A versioned parser may create derived records; parser failure does not discard raw source.
5. Re-import is idempotent and retains import provenance.

### Bookmark snapshot
1. User exports or selects a supported bookmark file, or invokes a documented browser adapter.
2. Client identifies browser/source version and snapshot timestamp.
3. Raw snapshot is preserved; parser creates normalized bookmark records.
4. A later snapshot does not silently destroy earlier versions.

### Remote media browsing
1. Client requests a filtered, paginated catalog using authenticated device/user scope.
2. Server returns bounded metadata and thumbnail references, not full-resolution media payloads.
3. Client requests thumbnails and opens selected originals on demand.
4. Video playback may use authenticated HTTP range requests; otherwise use resumable download.
5. Cache eviction is client-local and never deletes server objects.

## Lifecycle and reliability

Upload lifecycle:

`created -> uploading -> verifying -> indexed -> complete`

Import lifecycle:

`created -> receiving -> preserved -> parsing -> indexed`

Terminal states include `failed`, `cancelled`, `waiting_for_user` and `needs_reconciliation`. A timeout after sending data but before acknowledgement must be reconciled by request/session ID; do not create a duplicate blindly.

## Data limits and security

- All batches, chunks, metadata fields and responses are bounded.
- Server ignores client-supplied storage paths and computes/validates content hashes.
- File names, contact fields and parsed content are untrusted input.
- Import parsers run with time, memory and file-size limits.
- Media catalog and object/preview retrieval require authentication and authorization; no public URLs by default.
- Secrets never appear in protocol payload logs.
- Detailed endpoint schemas and compatibility/version negotiation must be frozen before protocol v0.1.
- Feature availability is advertised through capability negotiation; clients must not assume all platforms support every source or codec.

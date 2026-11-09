# Protocol

## Principles

- REST/HTTPS control plane under `/api/v1/`.
- Resumable chunked object transfer.
- Explicit upload and import session states.
- Idempotent operations and stable request IDs.
- Server is authoritative for stored-object and verified-chunk state.
- Client advances durable source cursors only after durable server acknowledgement.
- Device identity and source provenance accompany every backup item.
- Raw chat exports and bookmark snapshots are immutable source artifacts; parsed/indexed records are derived.
- No source-side deletion is part of backup protocol.

## Core resources

- `devices`: paired device identity, status, revocation and capabilities.
- `backup-sources`: enabled source category, adapter and source-specific cursor/version.
- `backup-jobs`: scheduled/manual run, constraints, progress and terminal state.
- `inventory`: client-discovered candidates and server reconciliation.
- `uploads`: media/object upload sessions, chunks, hash and verification.
- `imports`: chat-export and bookmark-snapshot ingestion sessions.
- `objects`: immutable stored binary objects with source provenance.
- `records`: parsed metadata/messages/bookmarks linked to source objects.
- `audit`: pairing, authorization, transfer, import and administrative events.

## Initial ingestion flows

### Media backup
1. Client scans MediaStore incrementally and sends a bounded inventory batch.
2. Server returns already-known content and resumable upload sessions.
3. Client streams missing content in chunks.
4. Server verifies size/hash and atomically finalizes the object.
5. Client receives durable acknowledgement and persists the new scan cursor/state.

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

## Lifecycle and reliability

Upload lifecycle:

`created -> uploading -> verifying -> indexed -> complete`

Import lifecycle:

`created -> receiving -> preserved -> parsing -> indexed`

Terminal states include `failed`, `cancelled`, `waiting_for_user` and `needs_reconciliation`. A timeout after sending data but before acknowledgement must be reconciled by request/session ID; do not create a duplicate blindly.

## Data limits and security

- All batches, chunks, metadata fields and responses are bounded.
- Server ignores client-supplied storage paths and computes/validates content hashes.
- File names and parsed content are untrusted input.
- Import parsers run with time, memory and file-size limits.
- Secrets never appear in protocol payload logs.
- Detailed endpoint schemas and compatibility/version negotiation must be frozen before protocol v0.1.

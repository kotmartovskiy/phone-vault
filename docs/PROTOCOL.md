# Protocol

Initial principles:
- REST/HTTPS control plane.
- Resumable chunked file transfer.
- Explicit upload session state.
- Idempotent operations where practical.
- API versioning under /api/v1/.
- Server is authoritative for stored-file state.

This document will become the canonical protocol contract before Phase 1 implementation is frozen.

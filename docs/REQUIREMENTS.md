# Functional Requirements

FR-001 Device pairing: a new Android device can pair with a server using a short-lived pairing flow.

FR-002 Manual transfer: the user can select one or more files and transfer them to the server.

FR-003 Automatic transfer: the user can configure Camera, Pictures, Movies, Downloads and Documents for automatic backup.

FR-004 Resume: interrupted transfers resume without restarting already verified chunks.

FR-005 Integrity: the server verifies completed files before exposing them as complete.

FR-006 Deduplication: repeated synchronization does not create unnecessary duplicate files.

FR-007 Index: every accepted file receives an index record.

FR-008 Search: the desktop UI can filter by date, size, extension/MIME, device and GPS.

FR-009 Preview: image, video and supported document previews are available.

FR-010 Archive operations: the user can Copy or Move selected files to configured computer folders.

FR-011 Safety: automatic backup never deletes the source file on the phone.

FR-012 Multi-device: multiple phones can share one server while preserving device identity.

FR-013 Offline operation: the server remains usable without Internet access.

FR-014 Audit: transfer and destructive archive operations are logged.

Non-functional requirements:
- Local-first.
- No mandatory cloud dependency.
- Works on modest ARM Linux hardware.
- Recoverable after process restart and power interruption.
- Large files are streamed/chunked rather than loaded into memory.
- API versioning from the first public protocol.

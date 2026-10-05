# Phone Vault

Local-first, self-hosted system for transferring, indexing, previewing and organizing files from Android phones to a computer or ARM/Linux single-board computer.

## Goals

- Android client for photos, videos, Downloads and documents.
- Cross-platform Flutter client for Windows, Linux/ARM64 and Android.
- Self-hosted server for PC/SBC.
- Automatic and manual transfer modes.
- Resumable, chunked uploads.
- File integrity verification and deduplication.
- Local metadata index with fast filtering.
- Photo/video/document previews.
- Search by date, size, format, device and GPS metadata.
- Manual Copy/Move operations to archive folders.
- Multiple phones connected to one server.
- No mandatory cloud account or external service.
- Safe-by-default behavior.

## Initial architecture

Android / Desktop Flutter client
            |
        HTTPS / LAN
            |
     FastAPI server
            |
   SQLite metadata index
            |
     Local file storage

The server is independent from the GUI so it can run headless on an SBC.

## Repository layout

- server/ — Python/FastAPI server and indexing engine.
- client/ — Flutter Android/desktop client.
- docs/ — requirements, architecture and protocol documentation.
- roadmap/ — staged development plan.
- tests/ — planned integration and protocol tests.

## Important design constraints

Modern Android uses scoped storage. Media should be accessed through MediaStore, while arbitrary files such as other applications' Downloads may require the Storage Access Framework. GPS/EXIF access has explicit permission requirements.

Transfers must support chunks, resume after disconnect, checksums, temporary files, atomic finalization and bounded retry/backoff.

The binary file and its index record are separate. The index stores path, size, timestamps, media type, dimensions, duration, GPS and content hash.

LAN-only does not mean trusted. The server will use authentication, scoped device identities and optional TLS. Destructive operations require explicit user intent.

## Status

Phase 0 — architecture and repository bootstrap.

First implementation milestone:

Android -> LAN -> server -> indexed file

## License

License has not been selected yet.

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

## Cross-platform and multi-transport architecture

The transfer core must not assume Android or Wi-Fi. Physical transport and transfer protocol are separate layers above a common Transfer Manager.

### Device identity

- `device_id` is a stable internal identity independent of the display name, manufacturer, model or platform.
- Device metadata may include platform, OS version, manufacturer, model and available capabilities/transports.
- The server uses the device display name as the default storage folder name, while allowing the user to change that destination independently.

### Supported and planned platforms

The architecture is intended to accommodate Android, iOS/iPhone, BlackBerry, Java ME, Symbian/Nokia, Windows Mobile and Windows CE where the platform capabilities permit it. Legacy platforms may use a native client, a compatible protocol, removable media or a desktop gateway rather than the modern Flutter client.

### Transport layer

Planned transports include:

- Wi-Fi/LAN and Wi-Fi hotspot.
- Bluetooth Classic (BR/EDR) and BLE, with version/mode capability discovery.
- USB/cable: MTP, PTP, Mass Storage, ADB, serial and vendor-specific protocols where available.
- IrDA for legacy devices.
- WAP/legacy mobile HTTP where applicable.
- Memory cards, card readers and other removable-media adapters.

For old phones that cannot run the modern client, the Lenovo/desktop side may act as a Communication Gateway. The Transfer Manager above the transport layer remains independent of the physical connection.

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

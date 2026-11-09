# Phone Vault

Local-first, self-hosted personal data backup and library system. Its first priority is reliable **background copying from Android smartphones to a user-controlled server**, followed by useful access to the stored library from the phone. Initial data sources are photos, videos and contacts, then chat data that can be exported or accessed through explicitly supported mechanisms, and browser bookmarks/favorites.

## Primary goal

A phone should back up new and changed user-selected data to the server with minimal manual interaction. Backup is additive and non-destructive: it must never delete or modify the phone's originals. The Android app should also allow the user to browse and view photos/videos already stored on the server.

### Priority data classes and capabilities
1. **Photos and videos** — scan Android MediaStore, detect new/changed media and transfer incrementally in the background.
2. **Contacts** — back up user-authorized contacts through Android Contacts Provider, preserving snapshots and source/account provenance. Restore/import, if added, is a separate confirmed workflow.
3. **Server media library** — browse paginated server catalog, view images and play/stream videos on demand, with bounded local caching.
4. **Chats and messaging history** — ingest exports and other explicitly supported app-provided backup formats. Each messaging app needs a separately documented adapter and compatibility limits; there is no assumption that Android permits universal access to another app's private chat database.
5. **Browser bookmarks/favorites** — import supported browser exports or use documented browser capabilities where available. Browser-specific support must be explicit. Bookmarks are distinct from currently open tabs and browser history.

Other file categories (Downloads, Documents, arbitrary SAF folders, audio, app data), advanced indexing, archive rules and AI workflows follow after the core backup and library access paths are reliable.

## Initial architecture

Android backup and library client
            |
        HTTPS / LAN
            |
     FastAPI server
            |
   SQLite metadata index
            |
   Local file + export storage
            |
   Future: Ai-gateway integration

The server is independent from the GUI and can run headless on a PC or ARM/Linux SBC in the initial target. No mandatory cloud account or external service is required.

## Android background behavior

- Use Android-supported background scheduling (WorkManager) for deferred, retryable synchronization.
- Respect Doze, battery saver, metered networks, charging/Wi-Fi preferences and OEM background restrictions.
- Provide a visible status and explain when the OS has deferred work or requires the user to exempt the app from battery optimization.
- Use a foreground service only for user-visible long-running transfers where current Android rules require it; do not promise uninterrupted always-on execution.
- Persist scan cursors, upload sessions and verified chunk state so work resumes after process death, reboot or network loss.
- Keep manual "Back up now" available.

## Server media access

The Android client should browse a paginated authenticated media catalog and load thumbnails/previews without downloading the entire archive. Full images and videos are retrieved only when selected; video range streaming is preferred where practical. Local cache is bounded and disposable. Offline and remote-only states are visible. Viewing never changes the server originals.

## Server and integrity

- Multiple paired devices with independent identities and revocation.
- Resumable, chunked uploads; checksums; temporary staging; verification; atomic finalization.
- Idempotent ingestion and deduplication without relying on filenames.
- Separate original binary data, metadata, contact snapshots, chat exports and bookmark snapshots.
- Server-side indexing must preserve source device, source application/account, export time and original timestamps when available.

## Privacy and safety

- Local-first; no mandatory third-party processing.
- Explicit per-device and per-data-class backup selection.
- Contacts, chat and browser data are sensitive. Collect only with explicit user consent and show exactly which source is enabled.
- No silent access to other apps' private storage, no bypass of encryption or Android permission boundaries.
- Automatic backup never deletes source data on the phone.
- GPS/EXIF and personal records remain on the user's server unless the user separately authorizes later processing.
- LAN-only does not mean trusted: authentication, scoped device identities, path validation and optional TLS are required.

## Cross-platform direction

Android client and the current Linux/PC server baseline come first. Once backup, contact snapshots and server media viewing are stable, expand server and client support to additional operating systems and CPU architectures. Keep protocol and storage independent of UI and hardware; use capability negotiation and publish a tested compatibility matrix. A target is supported only after build, install, upgrade, recovery and integration tests.

## Relationship with Ai-gateway

Phone Vault's immediate job is dependable collection, preservation and user access. Ai-gateway integration is a later layer: it may query the Phone Vault index, search permitted content, summarize or classify selected data, and coordinate user-approved workflows. Phone Vault must remain useful without Ai-gateway, and Ai-gateway must not become a prerequisite for backup.

## Repository layout

- server/ — Python/FastAPI API, ingestion and indexing.
- client/ — Flutter Android/desktop client.
- docs/ — requirements, architecture, protocol, security and [Android backup scope](docs/ANDROID_BACKUP_SCOPE.md).
- roadmap/ — staged development plan.
- tests/ — protocol, transfer and integration tests.

## Current implementation baseline

The repository contains an initial FastAPI server, Flutter client and resumable transfer pipeline. The documented next priority is to turn the existing safe transfer foundation into reliable scheduled Android media backup, then add contact backup and in-app server media browsing, followed by chat-export and browser-bookmark ingestion. Cross-platform expansion follows after these core workflows stabilize. Documentation does not imply these capabilities are already implemented.

## License

License has not been selected yet.

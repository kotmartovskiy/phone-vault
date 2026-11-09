# Security Model

Phone Vault is intended for a trusted home LAN, but the LAN itself is not treated as a security boundary. The server may contain private photos, videos, message history, attachments, bookmarks and location metadata.

## Threats

- unauthorized LAN client or stolen pairing token;
- malicious filename/path or forged metadata;
- corrupted or replayed upload;
- malicious chat export, archive or media parser payload;
- unauthorized access to another device's backup;
- accidental destructive archive operation;
- leakage of chat content, GPS, browser data or credentials;
- server exposed beyond the LAN;
- compromised Android client or server account.

## Rules

1. Pairing credentials are short-lived; each device receives a scoped, revocable identity.
2. Device identity and per-source permissions are checked on every operation.
3. Uploads are written below configured storage roots only; paths are canonicalized.
4. Uploaded files remain temporary until integrity verification succeeds.
5. Preview and import parsing runs in controlled workers with CPU, memory, time and file-size limits.
6. Chat and browser sources require explicit user opt-in, with clear per-app/category status.
7. No generic access to other apps' private storage; do not bypass app sandboxing, encryption, browser profile protection, MFA or Android permission boundaries.
8. Notification capture, if ever added, requires a separate explicit notification-listener grant and clear disclosure. It is best-effort and not a complete chat backup.
9. Browser integration must not collect cookies, passwords, auth tokens or browsing profile secrets. Bookmark export only.
10. Automatic backup is additive. It never deletes or modifies phone originals and never infers server deletion from source absence.
11. Archive Move/Delete operations are separate from backup ingestion and require explicit authorization; destructive operations can be disabled globally.
12. GPS/EXIF and message contents remain on the user's server by default and are never sent to third-party services automatically.
13. Logs must not contain authentication secrets or unnecessary message/media contents.
14. TLS should be available; LAN is not treated as a security boundary.
15. Ai-gateway integration, when implemented, is authenticated and read-only by default, with grants scoped by device, data category and operation.

# Security Model

Phone Vault is intended for a trusted home LAN, but the LAN itself is not treated as a security boundary.

Threats:
- unauthorized LAN client;
- stolen pairing token;
- malicious filename/path;
- forged MIME type;
- corrupted upload;
- malicious preview payload;
- accidental destructive archive operation;
- server exposed beyond the LAN.

Rules:
1. Pairing credentials are short-lived.
2. Devices receive revocable identities.
3. Uploads are written below configured storage roots only.
4. Paths are canonicalized before filesystem access.
5. Uploaded files remain temporary until verification succeeds.
6. Preview generation runs in a controlled worker.
7. Archive Move/Delete operations require explicit authorization.
8. Destructive operations can be disabled globally.
9. TLS should be available.
10. Logs must not contain authentication secrets.

GPS and other sensitive metadata remain local by default and are never sent to third-party services.

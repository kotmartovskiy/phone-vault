# Phone Vault Flutter Client

The Flutter client provides the first safe end-to-end transfer workflow.

## Current MVP

- Connect to a Phone Vault server over the local network.
- Pair a device with an Android Keystore-protected token.
- Browse a custom indexed view of supported shared-storage folders.
- Filter by type, age and filename; multi-select files; preview images.
- Upload files in resumable chunks with SHA-256 verification.
- Detect files already stored for the same device by size + SHA-256 and skip them.
- Show upload progress and allow a safe interruption without modifying the source file.
- Complete the upload through the server API.

## Safety contract

The MVP only reads the selected source file.

It does not:
- delete files on the phone;
- move files on the phone;
- overwrite source files;
- run automatic backup;
- modify the phone library.

## Development

The Android debug APK is built from this directory.

The transport layer is in lib/phone_vault_client.dart. Android MediaStore/SAF background scanning and automatic backup are intentionally deferred to the next phase.

The first real-device test should use a small file, verify size and SHA-256 on the server, and then test interrupted/resumed upload before larger transfers.

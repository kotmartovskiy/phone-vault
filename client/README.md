# Phone Vault Flutter Client

The Flutter client provides the first safe end-to-end transfer workflow.

## Current MVP

- Connect to a Phone Vault server over the local network.
- Pair a device.
- Pick a single file using the native file picker.
- Upload the file in resumable chunks.
- Show upload progress.
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

# Server

Initial target: Python 3.11+ and FastAPI.

## Run

The server is platform-neutral and uses `pathlib`; it does not depend on Windows-specific paths. By default, runtime data is stored in `runtime/` next to the server project. Override it with `PHONE_VAULT_ROOT`.

Example:

```text
PHONE_VAULT_ROOT=/path/to/phone-vault-runtime uvicorn app.main:app --host 0.0.0.0 --port 8766
```

On Windows PowerShell:

```text
$env:PHONE_VAULT_ROOT='D:\\phone-vault-runtime'
python -m uvicorn app.main:app --host 0.0.0.0 --port 8766
```

The application itself only relies on the configured runtime root. The HTTP host and port are deployment settings supplied to Uvicorn.

Planned modules:
- API and authentication
- upload/session manager
- storage manager
- metadata extractor
- index/database
- preview worker
- search/filter service
- archive operations

First executable milestone: one-file upload with verification and indexing.

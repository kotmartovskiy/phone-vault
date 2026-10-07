import hashlib
from fastapi.testclient import TestClient
from app.main import app

client=TestClient(app)

def test_health():
    r=client.get("/api/v1/health")
    assert r.status_code==200
    assert r.json()["status"]=="ok"

def test_authenticated_api_rejects_missing_and_wrong_credentials(tmp_path, monkeypatch):
    import app.main as m
    monkeypatch.setattr(m, "ROOT", tmp_path)
    monkeypatch.setattr(m, "STORAGE", tmp_path / "storage")
    monkeypatch.setattr(m, "DB_PATH", tmp_path / "db.sqlite3")
    m.init_db()
    device = client.post("/api/v1/devices/pair", json={"name": "auth-test"}).json()
    missing = client.get("/api/v1/files")
    assert missing.status_code == 401
    wrong = client.get("/api/v1/files", headers={"authorization": "Bearer invalid", "X-Device-ID": device["device_id"]})
    assert wrong.status_code == 401
    mismatch = client.get("/api/v1/files", headers={"authorization": f"Bearer {device['token']}", "X-Device-ID": "other-device"})
    assert mismatch.status_code == 403


def test_upload_and_resume(tmp_path,monkeypatch):
    import app.main as m
    monkeypatch.setattr(m,"ROOT",tmp_path)
    monkeypatch.setattr(m,"STORAGE",tmp_path/"storage")
    monkeypatch.setattr(m,"DB_PATH",tmp_path/"db.sqlite3")
    m.init_db()
    device=client.post("/api/v1/devices/pair",json={"name":"test-phone"}).json()
    auth={"authorization": f"Bearer {device['token']}", "X-Device-ID": device["device_id"]}
    payload=b"Phone Vault integration test payload\n"*100
    digest=hashlib.sha256(payload).hexdigest()
    u=client.post("/api/v1/uploads",json={"device_id":device["device_id"],"filename":"hello.txt","source_path":"Downloads/hello.txt","size":len(payload),"sha256":digest,"mime_type":"text/plain"},headers=auth).json()
    mid=len(payload)//2
    assert client.put(f"/api/v1/uploads/{u['upload_id']}/chunks/0",content=payload[:mid],headers={**auth,"X-Upload-Offset":"0"}).status_code==200
    assert client.get(f"/api/v1/uploads/{u['upload_id']}",headers=auth).json()["received_bytes"]==mid
    assert client.put(f"/api/v1/uploads/{u['upload_id']}/chunks/1",content=payload[mid:],headers={**auth,"X-Upload-Offset":str(mid)}).status_code==200
    done=client.post(f"/api/v1/uploads/{u['upload_id']}/complete",headers=auth)
    assert done.status_code==200
    assert done.json()["sha256"]==digest
    files=client.get("/api/v1/files",headers=auth).json()["items"]
    assert len(files)==1 and files[0]["filename"]=="hello.txt"
    check = client.get(f"/api/v1/files/check?sha256={digest}&size={len(payload)}", headers=auth)
    assert check.status_code == 200
    assert check.json()["exists"] is True

def test_wrong_resume_offset_does_not_corrupt_upload(tmp_path, monkeypatch):
    import app.main as m
    monkeypatch.setattr(m, "ROOT", tmp_path)
    monkeypatch.setattr(m, "STORAGE", tmp_path / "storage")
    monkeypatch.setattr(m, "DB_PATH", tmp_path / "db.sqlite3")
    m.init_db()
    device = client.post("/api/v1/devices/pair", json={"name": "offset-test"}).json()
    auth = {"authorization": f"Bearer {device['token']}", "X-Device-ID": device["device_id"]}
    upload = client.post("/api/v1/uploads", json={"device_id": device["device_id"], "filename": "offset.bin", "size": 6}, headers=auth).json()
    upload_id = upload["upload_id"]
    first = client.put(f"/api/v1/uploads/{upload_id}/chunks/0", headers={**auth, "X-Upload-Offset": "0"}, content=b"abc")
    assert first.status_code == 200
    assert first.json()["received_bytes"] == 3
    wrong = client.put(f"/api/v1/uploads/{upload_id}/chunks/1", headers={**auth, "X-Upload-Offset": "1"}, content=b"def")
    assert wrong.status_code == 409
    assert wrong.json()["received_bytes"] == 3
    correct = client.put(f"/api/v1/uploads/{upload_id}/chunks/1", headers={**auth, "X-Upload-Offset": "3"}, content=b"def")
    assert correct.status_code == 200
    assert correct.json()["received_bytes"] == 6


def test_sha256_mismatch_fails_without_creating_file(tmp_path, monkeypatch):
    import app.main as m
    monkeypatch.setattr(m, "ROOT", tmp_path)
    monkeypatch.setattr(m, "STORAGE", tmp_path / "storage")
    monkeypatch.setattr(m, "DB_PATH", tmp_path / "db.sqlite3")
    m.init_db()
    device = client.post("/api/v1/devices/pair", json={"name": "hash-test"}).json()
    auth = {"authorization": f"Bearer {device['token']}", "X-Device-ID": device["device_id"]}
    upload = client.post("/api/v1/uploads", json={"device_id": device["device_id"], "filename": "bad-hash.bin", "size": 3, "sha256": "0" * 64}, headers=auth).json()
    upload_id = upload["upload_id"]
    uploaded = client.put(f"/api/v1/uploads/{upload_id}/chunks/0", headers={**auth, "X-Upload-Offset": "0"}, content=b"abc")
    assert uploaded.status_code == 200
    completed = client.post(f"/api/v1/uploads/{upload_id}/complete", headers=auth)
    assert completed.status_code == 422
    status = client.get(f"/api/v1/uploads/{upload_id}", headers=auth)
    assert status.status_code == 200
    assert status.json()["status"] == "failed"
    files = client.get("/api/v1/files", headers=auth).json()["items"]
    assert all(item["filename"] != "bad-hash.bin" for item in files)


def test_invalid_offset_is_rejected(tmp_path, monkeypatch):
    import app.main as m
    monkeypatch.setattr(m, "ROOT", tmp_path)
    monkeypatch.setattr(m, "STORAGE", tmp_path / "storage")
    monkeypatch.setattr(m, "DB_PATH", tmp_path / "db.sqlite3")
    m.init_db()
    device = client.post("/api/v1/devices/pair", json={"name": "offset-format"}).json()
    auth = {"authorization": f"Bearer {device['token']}", "X-Device-ID": device["device_id"]}
    upload = client.post("/api/v1/uploads", json={"device_id": device["device_id"], "filename": "offset.bin", "size": 3}, headers=auth).json()
    bad = client.put(f"/api/v1/uploads/{upload['upload_id']}/chunks/0", headers={**auth, "X-Upload-Offset": "abc"}, content=b"abc")
    assert bad.status_code == 400
    negative = client.put(f"/api/v1/uploads/{upload['upload_id']}/chunks/0", headers={**auth, "X-Upload-Offset": "-1"}, content=b"abc")
    assert negative.status_code == 409


def test_device_isolation(tmp_path, monkeypatch):
    import app.main as m
    monkeypatch.setattr(m, "ROOT", tmp_path)
    monkeypatch.setattr(m, "STORAGE", tmp_path / "storage")
    monkeypatch.setattr(m, "DB_PATH", tmp_path / "db.sqlite3")
    m.init_db()
    first = client.post("/api/v1/devices/pair", json={"name": "first"}).json()
    second = client.post("/api/v1/devices/pair", json={"name": "second"}).json()
    auth1 = {"authorization": f"Bearer {first['token']}", "X-Device-ID": first["device_id"]}
    auth2 = {"authorization": f"Bearer {second['token']}", "X-Device-ID": second["device_id"]}
    upload = client.post("/api/v1/uploads", json={"device_id": first["device_id"], "filename": "secret.bin", "size": 3}, headers=auth1).json()
    forbidden = client.get(f"/api/v1/uploads/{upload['upload_id']}", headers=auth2)
    assert forbidden.status_code == 404
    mismatch = client.put(f"/api/v1/uploads/{upload['upload_id']}/chunks/0", headers={**auth2, "X-Upload-Offset": "0"}, content=b"abc")
    assert mismatch.status_code == 404


def test_resume_reconciles_actual_partial_size(tmp_path, monkeypatch):
    import app.main as m
    monkeypatch.setattr(m, "ROOT", tmp_path)
    monkeypatch.setattr(m, "STORAGE", tmp_path / "storage")
    monkeypatch.setattr(m, "DB_PATH", tmp_path / "db.sqlite3")
    m.init_db()
    device = client.post("/api/v1/devices/pair", json={"name": "reconcile-test"}).json()
    auth = {"authorization": f"Bearer {device['token']}", "X-Device-ID": device["device_id"]}
    payload = b"abcdef"
    digest = hashlib.sha256(payload).hexdigest()
    upload = client.post("/api/v1/uploads", json={"device_id": device["device_id"], "filename": "reconcile.bin", "size": 6, "sha256": digest}, headers=auth).json()
    upload_id = upload["upload_id"]
    assert client.put(f"/api/v1/uploads/{upload_id}/chunks/0", headers={**auth, "X-Upload-Offset": "0"}, content=b"abc").status_code == 200
    with m.db() as c:
        temp_path = c.execute("SELECT temp_path FROM uploads WHERE id=?", (upload_id,)).fetchone()["temp_path"]
        c.execute("UPDATE uploads SET received_bytes=1 WHERE id=?", (upload_id,))
    resumed = client.post("/api/v1/uploads/resume", json={"device_id": device["device_id"], "filename": "reconcile.bin", "size": 6, "sha256": digest}, headers=auth)
    assert resumed.status_code == 200
    assert resumed.json()["upload_id"] == upload_id
    assert resumed.json()["received_bytes"] == 3
    assert temp_path.endswith(".part")


def test_path_traversal_is_reduced_to_filename(tmp_path, monkeypatch):
    import app.main as m
    monkeypatch.setattr(m, "ROOT", tmp_path)
    monkeypatch.setattr(m, "STORAGE", tmp_path / "storage")
    monkeypatch.setattr(m, "DB_PATH", tmp_path / "db.sqlite3")
    m.init_db()
    device = client.post("/api/v1/devices/pair", json={"name": "path-test"}).json()
    auth = {"authorization": f"Bearer {device['token']}", "X-Device-ID": device["device_id"]}
    upload = client.post("/api/v1/uploads", json={"device_id": device["device_id"], "filename": "../../safe.txt", "size": 4}, headers=auth)
    assert upload.status_code == 200
    upload_id = upload.json()["upload_id"]
    assert client.put(f"/api/v1/uploads/{upload_id}/chunks/0", headers={**auth, "X-Upload-Offset": "0"}, content=b"safe").status_code == 200
    done = client.post(f"/api/v1/uploads/{upload_id}/complete", headers=auth)
    assert done.status_code == 200
    stored = tmp_path / "storage" / "devices" / device["device_id"] / "safe.txt"
    assert stored.read_bytes() == b"safe"


def test_zero_byte_upload_completes(tmp_path, monkeypatch):
    import app.main as m
    monkeypatch.setattr(m, "ROOT", tmp_path)
    monkeypatch.setattr(m, "STORAGE", tmp_path / "storage")
    monkeypatch.setattr(m, "DB_PATH", tmp_path / "db.sqlite3")
    m.init_db()
    device = client.post("/api/v1/devices/pair", json={"name": "empty-test"}).json()
    auth = {"authorization": f"Bearer {device['token']}", "X-Device-ID": device["device_id"]}
    digest = hashlib.sha256(b"").hexdigest()
    upload = client.post("/api/v1/uploads", json={"device_id": device["device_id"], "filename": "empty.bin", "size": 0, "sha256": digest}, headers=auth).json()
    done = client.post(f"/api/v1/uploads/{upload['upload_id']}/complete", headers=auth)
    assert done.status_code == 200
    assert done.json()["sha256"] == digest


def test_incomplete_upload_cannot_be_completed(tmp_path, monkeypatch):
    import app.main as m
    monkeypatch.setattr(m, "ROOT", tmp_path)
    monkeypatch.setattr(m, "STORAGE", tmp_path / "storage")
    monkeypatch.setattr(m, "DB_PATH", tmp_path / "db.sqlite3")
    m.init_db()
    device = client.post("/api/v1/devices/pair", json={"name": "incomplete-test"}).json()
    auth = {"authorization": f"Bearer {device['token']}", "X-Device-ID": device["device_id"]}
    upload = client.post("/api/v1/uploads", json={"device_id": device["device_id"], "filename": "incomplete.bin", "size": 4}, headers=auth).json()
    completed = client.post(f"/api/v1/uploads/{upload['upload_id']}/complete", headers=auth)
    assert completed.status_code == 409


import hashlib
from fastapi.testclient import TestClient
from app.main import app

client=TestClient(app)

def test_health():
    r=client.get("/api/v1/health")
    assert r.status_code==200
    assert r.json()["status"]=="ok"

def test_upload_and_resume(tmp_path,monkeypatch):
    import app.main as m
    monkeypatch.setattr(m,"ROOT",tmp_path)
    monkeypatch.setattr(m,"STORAGE",tmp_path/"storage")
    monkeypatch.setattr(m,"DB_PATH",tmp_path/"db.sqlite3")
    m.init_db()
    device=client.post("/api/v1/devices/pair",json={"name":"test-phone"}).json()
    payload=b"Phone Vault integration test payload\n"*100
    digest=hashlib.sha256(payload).hexdigest()
    u=client.post("/api/v1/uploads",json={"device_id":device["device_id"],"filename":"hello.txt","source_path":"Downloads/hello.txt","size":len(payload),"sha256":digest,"mime_type":"text/plain"}).json()
    mid=len(payload)//2
    assert client.put(f"/api/v1/uploads/{u['upload_id']}/chunks/0",content=payload[:mid],headers={"X-Upload-Offset":"0"}).status_code==200
    assert client.get(f"/api/v1/uploads/{u['upload_id']}").json()["received_bytes"]==mid
    assert client.put(f"/api/v1/uploads/{u['upload_id']}/chunks/1",content=payload[mid:],headers={"X-Upload-Offset":str(mid)}).status_code==200
    done=client.post(f"/api/v1/uploads/{u['upload_id']}/complete")
    assert done.status_code==200
    assert done.json()["sha256"]==digest
    files=client.get("/api/v1/files").json()["items"]
    assert len(files)==1 and files[0]["filename"]=="hello.txt"

def test_wrong_resume_offset_does_not_corrupt_upload(tmp_path, monkeypatch):
    import app.main as m
    monkeypatch.setattr(m, "ROOT", tmp_path)
    monkeypatch.setattr(m, "STORAGE", tmp_path / "storage")
    monkeypatch.setattr(m, "DB_PATH", tmp_path / "db.sqlite3")
    m.init_db()
    device = client.post("/api/v1/devices/pair", json={"name": "offset-test"}).json()
    upload = client.post("/api/v1/uploads", json={"device_id": device["device_id"], "filename": "offset.bin", "size": 6}).json()
    upload_id = upload["upload_id"]
    first = client.put(f"/api/v1/uploads/{upload_id}/chunks/0", headers={"X-Upload-Offset": "0"}, content=b"abc")
    assert first.status_code == 200
    assert first.json()["received_bytes"] == 3
    wrong = client.put(f"/api/v1/uploads/{upload_id}/chunks/1", headers={"X-Upload-Offset": "1"}, content=b"def")
    assert wrong.status_code == 409
    assert wrong.json()["received_bytes"] == 3
    correct = client.put(f"/api/v1/uploads/{upload_id}/chunks/1", headers={"X-Upload-Offset": "3"}, content=b"def")
    assert correct.status_code == 200
    assert correct.json()["received_bytes"] == 6


def test_sha256_mismatch_fails_without_creating_file(tmp_path, monkeypatch):
    import app.main as m
    monkeypatch.setattr(m, "ROOT", tmp_path)
    monkeypatch.setattr(m, "STORAGE", tmp_path / "storage")
    monkeypatch.setattr(m, "DB_PATH", tmp_path / "db.sqlite3")
    m.init_db()
    device = client.post("/api/v1/devices/pair", json={"name": "hash-test"}).json()
    upload = client.post("/api/v1/uploads", json={"device_id": device["device_id"], "filename": "bad-hash.bin", "size": 3, "sha256": "0" * 64}).json()
    upload_id = upload["upload_id"]
    uploaded = client.put(f"/api/v1/uploads/{upload_id}/chunks/0", headers={"X-Upload-Offset": "0"}, content=b"abc")
    assert uploaded.status_code == 200
    completed = client.post(f"/api/v1/uploads/{upload_id}/complete")
    assert completed.status_code == 422
    status = client.get(f"/api/v1/uploads/{upload_id}")
    assert status.status_code == 200
    assert status.json()["status"] == "failed"
    files = client.get("/api/v1/files").json()["items"]
    assert all(item["filename"] != "bad-hash.bin" for item in files)


def test_incomplete_upload_cannot_be_completed(tmp_path, monkeypatch):
    import app.main as m
    monkeypatch.setattr(m, "ROOT", tmp_path)
    monkeypatch.setattr(m, "STORAGE", tmp_path / "storage")
    monkeypatch.setattr(m, "DB_PATH", tmp_path / "db.sqlite3")
    m.init_db()
    device = client.post("/api/v1/devices/pair", json={"name": "incomplete-test"}).json()
    upload = client.post("/api/v1/uploads", json={"device_id": device["device_id"], "filename": "incomplete.bin", "size": 4}).json()
    completed = client.post(f"/api/v1/uploads/{upload['upload_id']}/complete")
    assert completed.status_code == 409


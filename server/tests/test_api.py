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

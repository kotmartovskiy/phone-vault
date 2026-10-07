from fastapi.testclient import TestClient
from app.main import app

def test_server_identity_is_stable_and_pairing_exposes_it(tmp_path, monkeypatch):
    import app.main as m
    monkeypatch.setattr(m, "ROOT", tmp_path)
    monkeypatch.setattr(m, "STORAGE", tmp_path / "storage")
    monkeypatch.setattr(m, "DB_PATH", tmp_path / "db.sqlite3")
    with TestClient(app) as scoped:
        first = scoped.get("/api/v1/identity")
        second = scoped.get("/api/v1/identity")
        assert first.status_code == 200
        assert second.status_code == 200
        assert first.json()["server_id"] == second.json()["server_id"]
        assert first.json()["version"] == m.APP_VERSION
        pair = scoped.post("/api/v1/devices/pair", json={"name": "identity-test"})
        assert pair.status_code == 200
        assert pair.json()["server_id"] == first.json()["server_id"]

def test_identity_does_not_require_auth(tmp_path, monkeypatch):
    import app.main as m
    monkeypatch.setattr(m, "ROOT", tmp_path)
    monkeypatch.setattr(m, "STORAGE", tmp_path / "storage")
    monkeypatch.setattr(m, "DB_PATH", tmp_path / "db.sqlite3")
    with TestClient(app) as scoped:
        response = scoped.get("/api/v1/identity")
        assert response.status_code == 200
        assert response.json()["server_id"]

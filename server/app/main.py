from __future__ import annotations
import hashlib, os, secrets, sqlite3, uuid
from contextlib import asynccontextmanager
from pathlib import Path
from fastapi import FastAPI, HTTPException, Query, Request, Header
from fastapi.responses import FileResponse, JSONResponse
from pydantic import BaseModel, Field

APP_VERSION="0.2.0"
ROOT=Path(os.environ.get("PHONE_VAULT_ROOT", Path(__file__).resolve().parents[2]/"runtime")).resolve()
STORAGE=ROOT/"storage"
DB_PATH=ROOT/"db"/"phone-vault.sqlite3"
CHUNK_SIZE=4*1024*1024

@asynccontextmanager
async def lifespan(_app:FastAPI):
    init_db()
    STORAGE.mkdir(parents=True,exist_ok=True)
    yield

app=FastAPI(title="Phone Vault",version=APP_VERSION,lifespan=lifespan)

@app.middleware("http")
async def auth_middleware(request:Request,call_next):
    if request.url.path in {"/api/v1/health","/api/v1/devices/pair"}:
        return await call_next(request)
    authorization=request.headers.get("authorization","")
    if not authorization.startswith("Bearer "):
        return JSONResponse(status_code=401,content={"error":"authentication_required"})
    token=authorization[7:].strip()
    with db() as c:
        row=c.execute("SELECT id FROM devices WHERE token_hash=?",(_token_hash(token),)).fetchone()
    if row is None:
        return JSONResponse(status_code=401,content={"error":"invalid_token"})
    device_id=request.headers.get("X-Device-ID")
    if device_id != row["id"]:
        return JSONResponse(status_code=403,content={"error":"device_mismatch"})
    request.state.device_id=row["id"]
    return await call_next(request)

def db():
    ROOT.joinpath("db").mkdir(parents=True,exist_ok=True)
    c=sqlite3.connect(DB_PATH)
    c.row_factory=sqlite3.Row
    return c

def init_db():
    with db() as c:
        c.executescript("""
        CREATE TABLE IF NOT EXISTS devices(id TEXT PRIMARY KEY,name TEXT NOT NULL,token_hash TEXT,created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,last_seen TEXT);
        """)
        cols={r[1] for r in c.execute("PRAGMA table_info(devices)").fetchall()}
        if "token_hash" not in cols:
            c.execute("ALTER TABLE devices ADD COLUMN token_hash TEXT")
        c.executescript("""
        CREATE TABLE IF NOT EXISTS files(id TEXT PRIMARY KEY,device_id TEXT NOT NULL,original_path TEXT NOT NULL,stored_path TEXT NOT NULL,filename TEXT NOT NULL,size INTEGER NOT NULL,sha256 TEXT NOT NULL,mime_type TEXT,created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP);
        CREATE INDEX IF NOT EXISTS idx_files_device ON files(device_id);
        CREATE INDEX IF NOT EXISTS idx_files_sha256 ON files(sha256);
        CREATE TABLE IF NOT EXISTS uploads(id TEXT PRIMARY KEY,device_id TEXT NOT NULL,filename TEXT NOT NULL,source_path TEXT NOT NULL,size INTEGER NOT NULL,expected_sha256 TEXT,mime_type TEXT,received_bytes INTEGER NOT NULL DEFAULT 0,status TEXT NOT NULL,temp_path TEXT NOT NULL,created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP);
        CREATE INDEX IF NOT EXISTS idx_upload_resume ON uploads(device_id,filename,size,status);
        """)

@app.get("/api/v1/health")
def health():
    return {"status":"ok","version":APP_VERSION}

class PairRequest(BaseModel):
    name:str=Field(min_length=1,max_length=100)

def _token_hash(token:str)->str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()

def require_auth(authorization:str|None=Header(default=None)):
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(401,"authentication required")
    token=authorization[7:].strip()
    if not token:
        raise HTTPException(401,"authentication required")
    with db() as c:
        row=c.execute("SELECT id FROM devices WHERE token_hash=?",(_token_hash(token),)).fetchone()
    if row is None:
        raise HTTPException(401,"invalid token")
    return row["id"]

@app.post("/api/v1/devices/pair")
def pair(req:PairRequest):
    device_id=uuid.uuid4().hex
    token=secrets.token_urlsafe(32)
    with db() as c:
        c.execute("INSERT INTO devices(id,name,token_hash) VALUES(?,?,?)",(device_id,req.name,_token_hash(token)))
    return {"device_id":device_id,"token":token,"name":req.name}


class UploadRequest(BaseModel):
    device_id:str
    filename:str=Field(min_length=1,max_length=255)
    source_path:str=""
    size:int=Field(ge=0)
    sha256:str|None=Field(default=None,min_length=64,max_length=64)
    mime_type:str|None=None

def safe_name(name:str)->str:
    n=Path(name.replace("\\","/")).name
    if not n or n in {".",".."}:
        raise HTTPException(400,"invalid filename")
    return n

def upload_json(row):
    return {"upload_id":row["id"],"chunk_size":CHUNK_SIZE,"received_bytes":row["received_bytes"],"size":row["size"],"status":row["status"]}

@app.post("/api/v1/uploads")
def create_upload(req:UploadRequest,request:Request):
    if req.device_id != request.state.device_id:
        raise HTTPException(403,"device mismatch")
    with db() as c:
        if c.execute("SELECT 1 FROM devices WHERE id=?",(req.device_id,)).fetchone() is None:
            raise HTTPException(404,"unknown device")
    filename=safe_name(req.filename)
    upload_id=uuid.uuid4().hex
    temp_dir=ROOT/"incoming"
    temp_dir.mkdir(parents=True,exist_ok=True)
    temp=temp_dir/f"{upload_id}.part"
    with db() as c:
        c.execute("INSERT INTO uploads(id,device_id,filename,source_path,size,expected_sha256,mime_type,status,temp_path) VALUES(?,?,?,?,?,?,?,?,?)",
                  (upload_id,req.device_id,filename,req.source_path,req.size,req.sha256,req.mime_type,"uploading",str(temp)))
    temp.touch()
    return {"upload_id":upload_id,"chunk_size":CHUNK_SIZE,"received_bytes":0,"size":req.size,"status":"uploading"}

@app.post("/api/v1/uploads/resume")
def resume_upload(req:UploadRequest,request:Request):
    if req.device_id != request.state.device_id:
        raise HTTPException(403,"device mismatch")
    filename=safe_name(req.filename)
    with db() as c:
        row=c.execute(
            "SELECT * FROM uploads WHERE device_id=? AND filename=? AND size=? AND status='uploading' AND ((expected_sha256 IS NULL AND ? IS NULL) OR expected_sha256=?) ORDER BY created_at DESC LIMIT 1",
            (request.state.device_id,filename,req.size,req.sha256,req.sha256)
        ).fetchone()
    if row is not None:
        temp=Path(row["temp_path"])
        actual=temp.stat().st_size if temp.exists() else 0
        if actual!=row["received_bytes"]:
            with db() as c:
                c.execute("UPDATE uploads SET received_bytes=? WHERE id=?",(actual,row["id"]))
            row=dict(row)
            row["received_bytes"]=actual
        return upload_json(row)
    return create_upload(req)

@app.get("/api/v1/uploads/{upload_id}")
def upload_status(upload_id:str,request:Request):
    with db() as c:
        row=c.execute("SELECT * FROM uploads WHERE id=?",(upload_id,)).fetchone()
    if row is None:
        raise HTTPException(404,"upload not found")
    if row["device_id"] != request.state.device_id:
        raise HTTPException(404,"upload not found")
    temp=Path(row["temp_path"])
    actual=temp.stat().st_size if temp.exists() else 0
    if actual!=row["received_bytes"] and row["status"]=="uploading":
        with db() as c:
            c.execute("UPDATE uploads SET received_bytes=? WHERE id=?",(actual,upload_id))
        row=dict(row)
        row["received_bytes"]=actual
    return upload_json(row)

@app.put("/api/v1/uploads/{upload_id}/chunks/{chunk_number}")
async def upload_chunk(upload_id:str,chunk_number:int,request:Request):
    if chunk_number<0:
        raise HTTPException(400,"invalid chunk number")
    with db() as c:
        row=c.execute("SELECT * FROM uploads WHERE id=?",(upload_id,)).fetchone()
    if row is None:
        raise HTTPException(404,"upload not found")
    if row["device_id"] != request.state.device_id:
        raise HTTPException(404,"upload not found")
    if row["status"]!="uploading":
        raise HTTPException(409,f"upload is {row['status']}")
    expected=row["received_bytes"]
    hdr=request.headers.get("X-Upload-Offset")
    if hdr is not None:
        try:
            offset=int(hdr)
        except ValueError:
            raise HTTPException(400,"invalid upload offset")
        if offset<0 or offset!=expected:
            return JSONResponse(status_code=409,content={"error":"offset_mismatch","received_bytes":expected})
    data=await request.body()
    if not data:
        raise HTTPException(400,"empty chunk")
    if expected+len(data)>row["size"]:
        raise HTTPException(413,"chunk exceeds declared size")
    with open(row["temp_path"],"ab") as f:
        f.write(data)
        f.flush()
        os.fsync(f.fileno())
    received=expected+len(data)
    with db() as c:
        c.execute("UPDATE uploads SET received_bytes=? WHERE id=?",(received,upload_id))
    return {"upload_id":upload_id,"chunk_number":chunk_number,"received_bytes":received,"status":"uploading"}

@app.post("/api/v1/uploads/{upload_id}/complete")
def complete_upload(upload_id:str,request:Request):
    with db() as c:
        row=c.execute("SELECT * FROM uploads WHERE id=?",(upload_id,)).fetchone()
    if row is None:
        raise HTTPException(404,"upload not found")
    if row["device_id"] != request.state.device_id:
        raise HTTPException(404,"upload not found")
    if row["received_bytes"]!=row["size"]:
        raise HTTPException(409,detail={"error":"incomplete","received_bytes":row["received_bytes"],"size":row["size"]})
    with db() as c:
        c.execute("UPDATE uploads SET status='verifying' WHERE id=?",(upload_id,))
    h=hashlib.sha256()
    with open(row["temp_path"],"rb") as f:
        for block in iter(lambda:f.read(1024*1024),b""):
            h.update(block)
    digest=h.hexdigest()
    if row["expected_sha256"] and digest.lower()!=row["expected_sha256"].lower():
        with db() as c:
            c.execute("UPDATE uploads SET status='failed' WHERE id=?",(upload_id,))
        raise HTTPException(422,detail={"error":"sha256_mismatch","actual":digest})
    destination=STORAGE/"devices"/row["device_id"]/row["filename"]
    destination.parent.mkdir(parents=True,exist_ok=True)
    if destination.exists():
        destination=destination.with_name(f"{destination.stem}-{upload_id[:8]}{destination.suffix}")
    os.replace(row["temp_path"],destination)
    file_id=uuid.uuid4().hex
    with db() as c:
        c.execute("INSERT INTO files(id,device_id,original_path,stored_path,filename,size,sha256,mime_type) VALUES(?,?,?,?,?,?,?,?)",
                  (file_id,row["device_id"],row["source_path"],str(destination),row["filename"],row["size"],digest,row["mime_type"]))
        c.execute("UPDATE uploads SET status='complete' WHERE id=?",(upload_id,))
    return {"upload_id":upload_id,"file_id":file_id,"sha256":digest,"status":"complete"}

@app.get("/api/v1/files/check")
def check_file(request:Request,sha256:str, size:int=Query(...,ge=0)):
    with db() as c:
        row=c.execute("SELECT id,filename,size,sha256 FROM files WHERE device_id=? AND size=? AND lower(sha256)=lower(?) LIMIT 1",(request.state.device_id,size,sha256)).fetchone()
    return {"exists": row is not None, "file": dict(row) if row is not None else None}

@app.get("/api/v1/files")
def list_files(request:Request,limit:int=Query(100,ge=1,le=1000),offset:int=Query(0,ge=0)):
    with db() as c:
        rows=c.execute("SELECT id,device_id,original_path,filename,size,sha256,mime_type,created_at FROM files WHERE device_id=? ORDER BY created_at DESC LIMIT ? OFFSET ?",(request.state.device_id,limit,offset)).fetchall()
    return {"items":[dict(r) for r in rows],"limit":limit,"offset":offset}

@app.get("/api/v1/files/{file_id}/content")
def file_content(file_id:str,request:Request):
    with db() as c:
        row=c.execute("SELECT filename,stored_path,device_id FROM files WHERE id=? AND device_id=?",(file_id,request.state.device_id)).fetchone()
    if row is None: raise HTTPException(404,"file not found")
    path=Path(row["stored_path"]).resolve()
    if not path.is_relative_to(STORAGE): raise HTTPException(500,"invalid storage path")
    if not path.is_file(): raise HTTPException(404,"stored file missing")
    return FileResponse(path,filename=row["filename"])

@app.get("/api/v1/files/{file_id}")
def file_info(file_id:str,request:Request):
    with db() as c:
        row=c.execute("SELECT * FROM files WHERE id=? AND device_id=?",(file_id,request.state.device_id)).fetchone()
    if row is None: raise HTTPException(404,"file not found")
    return dict(row)

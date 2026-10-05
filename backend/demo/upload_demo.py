#!/usr/bin/env python3
"""Sube las fotos de demo de backend/demo/photos/<handle>/ y las asigna a los perfiles de
prueba: foto principal (portrait), galería en orden (photo2…photo5) y Momentos recientes
(moment1, moment2). La misma persona conserva las mismas fotos en Discover, perfil,
mensajes y Momentos.

Requisitos (ya configurados en este Mac):
  · ~/.supabase/access-token-balicircle   → token de la Management API (para la base de datos)
  · ~/.supabase/balicircle-viewer-password → contraseña de la cuenta test.viewer (para subir a Storage)
Uso:  python3 backend/demo/upload_demo.py [handle …]   (sin argumentos: todos los que tengan fotos)
"""
import json, os, subprocess, sys, tempfile, urllib.request, uuid

REF = "tmwgcvnibyvxedpqjqkr"
BASE = f"https://{REF}.supabase.co"
ANON = "sb_publishable_K0-23t6p3put3a28oJIH6A_SCv16EhP"
VIEWER_ID = "5eed0000-0000-4000-8000-0000000000aa"
HERE = os.path.dirname(os.path.abspath(__file__))
TOKEN = open(os.path.expanduser("~/.supabase/access-token-balicircle")).read().strip()

def http(method, url, body=None, headers=None):
    req = urllib.request.Request(url, data=body, method=method, headers=headers or {})
    with urllib.request.urlopen(req) as r:
        return json.loads(r.read() or b"null")

def sql(q):
    return http("POST", f"https://api.supabase.com/v1/projects/{REF}/database/query",
                json.dumps({"query": q}).encode(), {"Authorization": f"Bearer {TOKEN}", "Content-Type": "application/json"})

def viewer_token():
    pw = open(os.path.expanduser("~/.supabase/balicircle-viewer-password")).read().strip()
    r = http("POST", f"{BASE}/auth/v1/token?grant_type=password",
             json.dumps({"email": "viewer@balicircle.test", "password": pw}).encode(),
             {"apikey": ANON, "Content-Type": "application/json"})
    return r["access_token"]

def prepare(path):
    """Reduce a 1600 px de lado mayor, JPEG; devuelve (bytes, ancho, alto)."""
    out = os.path.join(tempfile.mkdtemp(), "x.jpg")
    subprocess.run(["sips", "-Z", "1600", "-s", "format", "jpeg", "-s", "formatOptions", "82", path, "--out", out],
                   check=True, capture_output=True)
    info = subprocess.run(["sips", "-g", "pixelWidth", "-g", "pixelHeight", out], capture_output=True, text=True).stdout
    w = int(info.split("pixelWidth:")[1].split()[0]); h = int(info.split("pixelHeight:")[1].split()[0])
    return open(out, "rb").read(), w, h

def upload(tok, handle, name, data):
    path = f"{VIEWER_ID}/demo/{handle}/{name}-{uuid.uuid4().hex[:6]}.jpg"
    http("POST", f"{BASE}/storage/v1/object/media/{path}", data,
         {"Authorization": f"Bearer {tok}", "apikey": ANON, "Content-Type": "image/jpeg", "x-upsert": "true"})
    return f"{BASE}/storage/v1/object/public/media/{path}"

def q(s): return "'" + s.replace("'", "''") + "'"

def main():
    catalog = json.load(open(os.path.join(HERE, "catalog.json")))
    only = set(sys.argv[1:])
    tok = viewer_token()
    done = 0
    for p in catalog:
        h = p["handle"]
        folder = os.path.join(HERE, "photos", h)
        if (only and h not in only) or not os.path.exists(os.path.join(folder, "portrait.jpg")):
            continue
        media = []
        for ph in p["photos"]:
            f = os.path.join(folder, ph["file"])
            if os.path.exists(f):
                data, w, hh = prepare(f)
                media.append({"kind": "photo", "url": upload(tok, h, ph["file"][:-4], data), "w": w, "h": hh})
        moments = []
        for i, m in enumerate(p["moments"]):
            f = os.path.join(folder, m["file"])
            if os.path.exists(f):
                data, w, hh = prepare(f)
                moments.append((m["activity"], {"kind": "photo", "url": upload(tok, h, m["file"][:-4], data), "w": w, "h": hh}, 2 + i * 4))
        area = p["area"].lower().replace(" ", "")
        stmts = [f"update public.profiles set media = {q(json.dumps(media))}::jsonb, avatar_url = {q(media[0]['url'])} "
                 f"where handle = {q(h)} and is_seed;"]
        if moments:
            stmts.append(f"delete from public.moments where user_id = (select id from public.profiles where handle = {q(h)});")
            for act, item, hours in moments:
                stmts.append("insert into public.moments (user_id, media, activity, area, happened_at, created_at, pinned) "
                             f"select id, {q(json.dumps(item))}::jsonb, {q(act)}, {q(area)}, now() - interval '{hours} hours', "
                             f"now() - interval '{hours} hours', false from public.profiles where handle = {q(h)};")
        sql("\n".join(stmts))
        done += 1
        print(f"✓ {p['name']:<10} {len(media)} fotos · {len(moments)} momentos")
    print(f"--- {done} perfiles actualizados" if done else "No hay fotos en backend/demo/photos/<handle>/portrait.jpg")

if __name__ == "__main__":
    main()

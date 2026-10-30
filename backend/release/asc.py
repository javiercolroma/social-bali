"""Cliente mínimo de la App Store Connect API (JWT ES256 firmado con openssl; sin dependencias).
Las claves viven en ~/.appstoreconnect/private_keys/. BA5Q98NXS8 = Admin; 869JC2XBQL = solo subidas.
Uso: from asc import call; call("GET", "/v1/apps")"""
import json,time,base64,subprocess,urllib.request,os
KID=os.environ.get("KID","BA5Q98NXS8"); ISS="71bda987-43c6-4c5f-b068-f969b6eaf269"
KEY=os.path.expanduser(f"~/.appstoreconnect/private_keys/AuthKey_{KID}.p8")
b64=lambda b: base64.urlsafe_b64encode(b).rstrip(b"=").decode()
def jwt():
    h=b64(json.dumps({"alg":"ES256","kid":KID,"typ":"JWT"}).encode())
    now=int(time.time()); p=b64(json.dumps({"iss":ISS,"iat":now,"exp":now+900,"aud":"appstoreconnect-v1"}).encode())
    msg=f"{h}.{p}".encode()
    der=subprocess.run(["openssl","dgst","-sha256","-sign",KEY],input=msg,capture_output=True,check=True).stdout
    i=2 if der[1]<0x80 else 3
    def rd(i):
        assert der[i]==2; l=der[i+1]; v=der[i+2:i+2+l]; return v.lstrip(b"\0").rjust(32,b"\0"), i+2+l
    r,i=rd(i); s,_=rd(i)
    return f"{h}.{p}.{b64(r+s)}"
def call(method,path,body=None,raw=None,ctype="application/json"):
    url=path if path.startswith("http") else "https://api.appstoreconnect.apple.com"+path
    data=raw if raw is not None else (json.dumps(body).encode() if body else None)
    req=urllib.request.Request(url,method=method,data=data,headers={"Authorization":"Bearer "+jwt(),"Content-Type":ctype})
    try:
        with urllib.request.urlopen(req) as r: return r.status, json.loads(r.read() or b"{}")
    except urllib.error.HTTPError as e: return e.code, json.loads(e.read() or b"{}")

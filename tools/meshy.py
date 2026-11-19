"""Cliente mínimo de la API REST de Meshy (https://docs.meshy.ai).

La clave NO está en el repositorio: es un "network secret" del entorno para api.meshy.ai y el
proxy de salida la agrega a cada solicitud. Por eso aquí no hay cabecera Authorization.

Uso:
  python3 tools/meshy.py saldo
  python3 tools/meshy.py imagen <imagen.png> [--polys 30000] [--textura 2k] [--modelo meshy-t2.5]  -> crea la tarea, imprime el id
  python3 tools/meshy.py estado <id>
  python3 tools/meshy.py esperar <id> <carpeta>          -> espera, descarga GLB, texturas y miniatura
"""
import base64
import io
import json
import os
import sys
import time
import urllib.parse
import urllib.request

API = os.environ.get("MESHY_API_HOST", "https://api.meshy.ai")


def _pedir(metodo, ruta, cuerpo=None):
    datos = json.dumps(cuerpo).encode() if cuerpo is not None else None
    req = urllib.request.Request(API + ruta, data=datos, method=metodo, headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=120) as r:
        return json.loads(r.read().decode())


def saldo():
    return _pedir("GET", "/openapi/v1/balance")


def data_uri(ruta):
    """Imagen como data URI JPEG (más liviana que el PNG original)."""
    from PIL import Image
    im = Image.open(ruta).convert("RGB")
    b = io.BytesIO()
    im.save(b, "JPEG", quality=93)
    return "data:image/jpeg;base64," + base64.b64encode(b.getvalue()).decode()


def imagen_a_3d(ruta, polys=30000, textura="2k", modelo="meshy-t2.5"):
    """Image to 3D con Smart Topology (triángulos, polys ≤ 30000 en meshy-t2.5). Costo: 15 créditos con textura 2K."""
    cuerpo = {
        "image_url": data_uri(ruta),
        "model_type": "smart-topology",
        "ai_model": modelo,
        "target_polycount": int(polys),
        "should_texture": True,
        "texture_resolution": textura,
        "topology": "triangle",
    }
    return _pedir("POST", "/openapi/v1/image-to-3d", cuerpo)["result"]


def texto_a_3d_vista(prompt, polys=8000, modelo="meshy-t2.5"):
    """Text to 3D, fase 1 (malla sin textura) con Smart Topology. Costo: 5 créditos."""
    cuerpo = {"mode": "preview", "prompt": prompt[:800], "model_type": "smart-topology", "ai_model": modelo,
              "target_polycount": int(polys), "topology": "triangle", "should_remesh": True}
    return _pedir("POST", "/openapi/v2/text-to-3d", cuerpo)["result"]


def texto_a_3d_textura(vista, texto_textura):
    """Text to 3D, fase 2 (textura sobre la malla de la fase 1). Costo: 10 créditos."""
    cuerpo = {"mode": "refine", "preview_task_id": vista, "texture_prompt": texto_textura[:600], "enable_pbr": False}
    return _pedir("POST", "/openapi/v2/text-to-3d", cuerpo)["result"]


def estado(tarea, tipo="image-to-3d"):
    if tipo == "text-to-3d":
        return _pedir("GET", "/openapi/v2/text-to-3d/" + tarea)
    return _pedir("GET", "/openapi/v1/image-to-3d/" + tarea)


def descargar(url, destino):
    req = urllib.request.Request(url)
    with urllib.request.urlopen(req, timeout=300) as r, open(destino, "wb") as f:
        f.write(r.read())
    return os.path.getsize(destino)


def esperar(tarea, carpeta, cada=10, limite=1800, tipo="image-to-3d"):
    t0 = time.time()
    while True:
        e = estado(tarea, tipo)
        print("estado %s · progreso %s %%" % (e.get("status"), e.get("progress")), flush=True)
        if e.get("status") in ("SUCCEEDED", "FAILED", "CANCELED", "EXPIRED"):
            break
        if time.time() - t0 > limite:
            raise SystemExit("tiempo agotado")
        time.sleep(cada)
    if e.get("status") != "SUCCEEDED":
        raise SystemExit("la tarea terminó en %s: %s" % (e.get("status"), e.get("task_error")))
    return bajar(e, carpeta)


def bajar(e, carpeta):
    """Descarga GLB, texturas y miniatura de una tarea terminada (sin guardar las URL firmadas)."""
    os.makedirs(carpeta, exist_ok=True)
    archivos = {}
    for clave, url in (e.get("model_urls") or {}).items():
        if url and clave in ("glb",):
            archivos["modelo." + clave] = url
    for i, tex in enumerate(e.get("texture_urls") or []):
        for clave, url in tex.items():
            if url:
                archivos["textura_%d_%s.png" % (i, clave)] = url
    if e.get("thumbnail_url"):
        archivos["miniatura.png"] = e["thumbnail_url"]
    descargar_archivos(e, carpeta, archivos)
    return e


def descargar_archivos(e, carpeta, archivos):
    for nombre, url in archivos.items():
        tam = descargar(url, os.path.join(carpeta, nombre))
        print("descargado %-28s %8d bytes  (%s)" % (nombre, tam, urllib.parse.urlparse(url).netloc), flush=True)
    json.dump({k: v for k, v in e.items() if "url" not in k},
              open(os.path.join(carpeta, "tarea.json"), "w"), indent=1)


if __name__ == "__main__":
    import urllib.parse  # noqa: F401  (para netloc)
    a = sys.argv[1:]
    if not a or a[0] == "saldo":
        print(json.dumps(saldo()))
    elif a[0] == "imagen":
        opc = {"polys": 30000, "textura": "2k", "modelo": "meshy-t2.5"}
        for i in range(2, len(a), 2):
            opc[a[i].lstrip("-")] = a[i + 1]
        print(imagen_a_3d(a[1], int(opc["polys"]), opc["textura"], opc["modelo"]))
    elif a[0] == "estado":
        e = estado(a[1])
        print(json.dumps({k: e.get(k) for k in ("id", "status", "progress", "task_error")}))
    elif a[0] == "esperar":
        esperar(a[1], a[2])

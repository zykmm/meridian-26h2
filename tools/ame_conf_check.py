"""Comprueba un playbook.conf con las reglas de validación de AME Wizard.

Las reglas salen de los mensajes de error que lleva dentro "AME Beta.exe"
(los textos UTF-16 entre "Playbook Name cannot contain..." y
"FeaturePage cannot be used directly..."). Solo cubre lo que esos mensajes
dicen; no sustituye a cargar el .apbx en AME.

Uso:  python ame_conf_check.py <playbook.conf | archivo.apbx>
      (con .apbx extrae playbook.conf con 7z y la contraseña 'malte')
Sale con código 1 si hay algún error.
"""
import os
import re
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET

INVALID_NAME_CHARS = set('\\/:*?<>|')
HEX_COLOR = re.compile(r"^#[0-9A-Fa-f]{6}$")
VERSION = re.compile(r"^\d+(\.\d+){0,3}$")
VERSION_RANGE = re.compile(r"^\d+(\.\d+){0,3}(-\d+(\.\d+){0,3})?$")


def load(path):
    if path.lower().endswith(".apbx"):
        out = tempfile.mkdtemp(prefix="apbx-conf-")
        subprocess.run(["7z", "e", "-y", "-pmalte", f"-o{out}", path, "playbook.conf"],
                       check=True, stdout=subprocess.DEVNULL)
        path = os.path.join(out, "playbook.conf")
    with open(path, encoding="utf-8-sig") as f:
        return path, f.read()


def check(text):
    errors, notes = [], []
    root = ET.fromstring(text)

    name = (root.findtext("Name") or "").strip()
    if not name:
        errors.append("Name vacío")
    elif INVALID_NAME_CHARS & set(name):
        errors.append(f"Name con caracteres no válidos: {name!r}")

    version = (root.findtext("Version") or "").strip()
    if not VERSION.match(version):
        errors.append(f"Version con formato no válido: {version!r}")

    upg = (root.findtext("UpgradableFrom") or "").strip()
    if upg and not VERSION_RANGE.match(upg):
        errors.append(f"UpgradableFrom con formato no válido: {upg!r}")

    if (root.findtext("SupportsISO") or "").strip().lower() == "true":
        bps = root.findall("./OOBE/BulletPoints/BulletPoint")
        if len(bps) != 3:
            errors.append(f"OOBE: hacen falta exactamente 3 BulletPoint (hay {len(bps)})")
        icons = [bp.get("Icon") for bp in bps]
        if len(set(icons)) != len(icons):
            errors.append(f"OOBE: iconos repetidos {icons}")
        for bp in bps:
            if not (bp.get("Title") or "").strip() or not (bp.get("Description") or "").strip():
                errors.append("OOBE: BulletPoint con Title o Description vacío")

    pages = root.find("FeaturePages")
    for i, page in enumerate(list(pages) if pages is not None else [], 1):
        tag = page.tag
        label = f"página {i} ({tag}, {page.get('Description', '')[:40]!r})"
        if tag == "FeaturePage":
            errors.append(f"{label}: FeaturePage no se puede usar directamente")
            continue
        if tag not in ("CheckboxPage", "RadioPage", "RadioImagePage"):
            notes.append(f"{label}: etiqueta desconocida, no comprobada")
            continue
        opts = page.findall("./Options/*")
        names = [(o.findtext("Name") or "").strip() for o in opts]
        top = page.find("TopLine") is not None
        bottom = page.find("BottomLine") is not None
        n = len(opts)
        if tag in ("CheckboxPage", "RadioPage"):
            if top and bottom and n > 2:
                errors.append(f"{label}: TopLine y BottomLine con {n} opciones (máximo 2)")
            elif (top or bottom) and n > 3:
                errors.append(f"{label}: TopLine o BottomLine con {n} opciones (máximo 3)")
            elif n > 4:
                errors.append(f"{label}: {n} opciones (máximo 4)")
        elif n > 4:
            errors.append(f"{label}: {n} opciones (máximo 4)")
        if len(set(names)) != len(names):
            errors.append(f"{label}: opciones repetidas {names}")
        default = page.get("DefaultOption")
        if tag in ("RadioPage", "RadioImagePage") and default and default not in names:
            errors.append(f"{label}: DefaultOption {default!r} no coincide con ninguna opción")
        if tag == "RadioImagePage":
            for o in opts:
                top_c = (o.findtext("GradientTopColor") or "").strip()
                bot_c = (o.findtext("GradientBottomColor") or "").strip()
                oname = o.findtext("Name")
                for c in (top_c, bot_c):
                    if not HEX_COLOR.match(c):
                        errors.append(f"{label}: {oname}: color {c!r} no es #RRGGBB")
                    elif c.upper() in ("#000000", "#FFFFFF"):
                        errors.append(f"{label}: {oname}: color {c} negro o blanco")
                if top_c and top_c.upper() == bot_c.upper():
                    errors.append(f"{label}: {oname}: los dos colores son iguales")
        notes.append(f"{label}: {n} opciones, TopLine={top}, BottomLine={bottom}")
    return errors, notes


def main():
    if len(sys.argv) != 2:
        print(__doc__)
        return 2
    path, text = load(sys.argv[1])
    errors, notes = check(text)
    print(f"Archivo: {path}")
    for n in notes:
        print("  ·", n)
    for e in errors:
        print("  ERROR:", e)
    print("Resultado:", "OK" if not errors else f"{len(errors)} error(es)")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())

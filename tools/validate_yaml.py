"""Carga todos los YAML del playbook con PyYAML (acepta las etiquetas !accion de AME)
y comprueba que cada !task apunta a un archivo que existe. Sale con 1 si hay errores.

Uso: python tools/validate_yaml.py src/playbook/Configuration
"""
import os
import sys

import yaml


class Loader(yaml.SafeLoader):
    pass


def _any_tag(loader, suffix, node):
    if isinstance(node, yaml.MappingNode):
        return {"__tag__": suffix, **loader.construct_mapping(node, deep=True)}
    if isinstance(node, yaml.SequenceNode):
        return loader.construct_sequence(node, deep=True)
    return loader.construct_scalar(node)


Loader.add_multi_constructor("!", _any_tag)


def walk(obj):
    if isinstance(obj, dict):
        yield obj
        for v in obj.values():
            yield from walk(v)
    elif isinstance(obj, list):
        for v in obj:
            yield from walk(v)


def main(root):
    errors, count, tasks = [], 0, 0
    for dirpath, _, files in os.walk(root):
        for name in files:
            if not name.lower().endswith((".yml", ".yaml")):
                continue
            path = os.path.join(dirpath, name)
            count += 1
            try:
                with open(path, encoding="utf-8-sig") as fh:
                    data = yaml.load(fh, Loader=Loader)
            except yaml.YAMLError as exc:
                errors.append(f"{path}: {exc}")
                continue
            for node in walk(data):
                if str(node.get("__tag__", "")).rstrip(":") == "task" and "path" in node:
                    tasks += 1
                    target = os.path.join(root, str(node["path"]).replace("\\", os.sep))
                    if not os.path.isfile(target):
                        errors.append(f"{path}: !task apunta a un archivo que no existe: {node['path']}")
    print(f"YAML cargados: {count}; !task comprobadas: {tasks}")
    for e in errors:
        print("ERROR", e)
    print("Resultado:", "OK" if not errors else f"{len(errors)} errores")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "src/playbook/Configuration"))

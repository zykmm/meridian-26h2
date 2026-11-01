"""Extrae todas las acciones de AME Wizard de los YAML del playbook a TSV.

Uso: python ame_yaml_extract.py <dir Configuration> <salida.tsv> [tags separados por coma]
Sin PyYAML: parser mínimo para el estilo usado en Atlas (flow mappings de una línea
y block mappings con claves 'k: v' indentadas bajo '- !tag:').
"""
import os
import re
import sys

ACTION_RE = re.compile(r'^(\s*)-\s*!(\w+):\s*(.*)$')
KEY_RE = re.compile(r'^(\s*)([A-Za-z][\w]*):\s*(.*)$')
HEADER_KEYS = ('builds', 'option', 'privilege', 'onUpgrade', 'cpuArch', 'oobe')


def unquote(v):
    v = v.strip()
    if len(v) >= 2 and v[0] == "'" and v[-1] == "'":
        return v[1:-1].replace("''", "'")
    if len(v) >= 2 and v[0] == '"' and v[-1] == '"':
        return bytes(v[1:-1], 'utf-8').decode('unicode_escape')
    return v


def strip_comment(v):
    # quita comentario '#' fuera de comillas
    q = None
    for i, c in enumerate(v):
        if q:
            if c == q:
                q = None
        elif c in "'\"":
            q = c
        elif c == '#' and (i == 0 or v[i - 1] in ' \t'):
            return v[:i].rstrip()
    return v


def parse_flow(s):
    """Parsea '{k: v, k2: 'v, x', k3: {a: b}}' -> dict (valores crudos des-entrecomillados)."""
    s = s.strip()
    assert s[0] == '{'
    out, i, n = {}, 1, len(s)
    while i < n:
        while i < n and s[i] in ' ,\t':
            i += 1
        if i >= n or s[i] == '}':
            break
        j = s.index(':', i)
        key = s[i:j].strip().strip('"\'')
        i = j + 1
        while i < n and s[i] == ' ':
            i += 1
        start, depth, q = i, 0, None
        while i < n:
            c = s[i]
            if q:
                if c == q:
                    if q == "'" and i + 1 < n and s[i + 1] == "'":
                        i += 1
                    else:
                        q = None
            elif c in "'\"":
                q = c
            elif c in '{[':
                depth += 1
            elif c in '}]':
                if depth == 0:
                    break
                depth -= 1
            elif c == ',' and depth == 0:
                break
            i += 1
        out[key] = unquote(s[start:i])
    return out


def balanced_end(lines, idx, text):
    """Concatena líneas hasta cerrar la llave del flow mapping."""
    buf, k = text, idx
    while buf.count('{') > buf.count('}') and k + 1 < len(lines):
        k += 1
        buf += ' ' + lines[k].strip()
    return buf, k


def parse_file(path):
    with open(path, encoding='utf-8-sig') as f:
        lines = f.read().splitlines()
    header = {}
    for ln in lines:
        if ln.startswith('actions:'):
            break
        m = KEY_RE.match(ln)
        if m and m.group(1) == '' and m.group(2) in HEADER_KEYS:
            header[m.group(2)] = unquote(strip_comment(m.group(3)))
    actions, i = [], 0
    while i < len(lines):
        ln = lines[i]
        if ln.lstrip().startswith('#'):
            i += 1
            continue
        m = ACTION_RE.match(ln)
        if not m:
            i += 1
            continue
        indent, tag, rest = len(m.group(1)), m.group(2), strip_comment(m.group(3))
        lineno = i + 1
        if rest.startswith('{'):
            buf, i = balanced_end(lines, i, rest)
            fields = parse_flow(buf)
            i += 1
        else:
            fields, i = {}, i + 1
            while i < len(lines):
                l2 = lines[i]
                if not l2.strip() or l2.lstrip().startswith('#'):
                    i += 1
                    continue
                cur = len(l2) - len(l2.lstrip())
                if cur <= indent and l2.lstrip().startswith('-'):
                    break
                if cur < indent:
                    break
                km = KEY_RE.match(l2)
                if not km:
                    i += 1
                    continue
                key, val = km.group(2), strip_comment(km.group(3))
                kind = len(km.group(1))
                i += 1
                if val in ('|', '>-', '>', '|-'):
                    block = []
                    while i < len(lines) and (not lines[i].strip() or len(lines[i]) - len(lines[i].lstrip()) > kind):
                        block.append(lines[i].strip())
                        i += 1
                    fields[key] = ' '.join(b for b in block if b)
                elif val.startswith('{'):
                    fields[key] = val
                else:
                    fields[key] = unquote(val)
        actions.append((lineno, tag, fields))
    return header, actions


def main():
    root, out = sys.argv[1], sys.argv[2]
    tags = set(sys.argv[3].split(',')) if len(sys.argv) > 3 else None
    cols = ['file', 'line', 'tag', 'operation', 'path', 'value', 'type', 'data',
            'option', 'builds', 'cpuArch', 'iso', 'oobe', 'onUpgrade', 'file_option', 'file_builds',
            'file_onUpgrade', 'file_privilege', 'other']
    rows = []
    parsed = {}
    for dp, _, fns in os.walk(root):
        for fn in sorted(fns):
            if fn.endswith('.yml'):
                p = os.path.join(dp, fn)
                parsed[os.path.relpath(p, root).replace('\\', '/')] = parse_file(p)
    # Condiciones puestas en la !task que incluye cada archivo (p. ej. tweaks.yml:167 option: remove-snipping-tool).
    # Se combinan con las de la cabecera del archivo (corrección Fase 3).
    task_cond = {}
    for rel, (_, actions) in parsed.items():
        for _, tag, fl in actions:
            if tag == 'task' and fl.get('path'):
                target = fl['path'].replace('\\', '/').lstrip('./')
                for k in ('option', 'builds', 'onUpgrade'):
                    if fl.get(k):
                        task_cond.setdefault(target, {})[k] = fl[k]
    for rel in sorted(parsed):
        header, actions = parsed[rel]
        header = dict(header)
        for k, v in task_cond.get(rel, {}).items():
            header[k] = (header[k] + ' AND ' + v) if header.get(k) and header[k] != v else v
        if True:
            for lineno, tag, fl in actions:
                if tags and tag not in tags:
                    continue
                known = {'operation', 'path', 'value', 'type', 'data', 'option', 'builds', 'cpuArch',
                         'iso', 'oobe', 'onUpgrade'}
                other = '; '.join(f'{k}={v}' for k, v in fl.items() if k not in known)
                op = fl.get('operation') or {'registryKey': 'delete (default)', 'registryValue': 'add (default)'}.get(tag, '')
                rows.append([rel, str(lineno), tag, op, fl.get('path', ''),
                             fl.get('value', ''), fl.get('type', ''), fl.get('data', ''),
                             fl.get('option', ''), fl.get('builds', ''), fl.get('cpuArch', ''),
                             fl.get('iso', ''), fl.get('oobe', ''), fl.get('onUpgrade', ''),
                             header.get('option', ''), header.get('builds', ''),
                             header.get('onUpgrade', ''), header.get('privilege', ''), other])
    rows.sort(key=lambda r: (r[0], int(r[1])))
    with open(out, 'w', encoding='utf-8', newline='') as f:
        f.write('\t'.join(cols) + '\n')
        for r in rows:
            f.write('\t'.join(c.replace('\t', ' ').replace('\n', ' ') for c in r) + '\n')
    print(f'{len(rows)} acciones escritas en {out}')


if __name__ == '__main__':
    main()

#!/usr/bin/env python3
"""Package each plugin under plugins/ into an installable .rbz in dist/.

    python3 tools/package.py            # package everything
    python3 tools/package.py field_designer bsf_suite   # just these

A .rbz is a plain zip of a plugin folder's contents: the registrar .rb at
the archive root plus its support folder. Install via SketchUp's
Extension Manager > Install Extension.
"""

import os
import sys
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PLUGINS = os.path.join(ROOT, "plugins")
DIST = os.path.join(ROOT, "dist")


def package(name):
    src = os.path.join(PLUGINS, name)
    if not os.path.isdir(src):
        sys.exit(f"no such plugin: {name}")
    out = os.path.join(DIST, f"{name}.rbz")
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        for base, _dirs, files in os.walk(src):
            for f in sorted(files):
                full = os.path.join(base, f)
                z.write(full, os.path.relpath(full, src))
    print(f"wrote {os.path.relpath(out, ROOT)}")


def main():
    os.makedirs(DIST, exist_ok=True)
    names = sys.argv[1:] or sorted(os.listdir(PLUGINS))
    for name in names:
        package(name)


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""
Build & minify Tinymetrix Monkey C barrel.

Merges all .mc files into one, removes comments/whitespace,
renames private identifiers, and optionally builds the .barrel.

Usage:
    python3 minify.py <directory>                     # merge + minify
    python3 minify.py <directory> --build              # merge + minify + build barrel
    python3 minify.py <directory> --build --sdk <path> # specify SDK path
    python3 minify.py <file.mc> -o <output.mc>         # single file mode
"""

import sys
import argparse
import os
import re
import glob
import shutil
import subprocess
import tempfile
import xml.etree.ElementTree as ET

SHORT_CHARS = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'


# ── Tokenizer helpers ───────────────────────────────────────────

def _skip_string(source, i, quote):
    n = len(source)
    j = i + 1
    while j < n:
        if source[j] == '\\':
            j += 2
        elif source[j] == quote:
            return j + 1
        else:
            j += 1
    return j


# ── Merge ────────────────────────────────────────────────────────


def remove_dead_blocks(source):
    i = 0
    while True:
        import re
        match = re.search(r'if\s*\(\s*false\s*\)\s*\{', source[i:])
        if not match:
            break

        idx = i + match.start()
        brace_start = i + match.end() - 1

        depth = 1
        j = brace_start + 1
        while j < len(source) and depth > 0:
            if source[j] == '"':
                j = _skip_string(source, j, '"')
                continue
            elif source[j] == "'":
                j = _skip_string(source, j, "'")
                continue
            elif source[j] == '{':
                depth += 1
            elif source[j] == '}':
                depth -= 1
            j += 1

        if depth == 0:
            source = source[:idx] + source[j:]
            i = idx
        else:
            i = idx + 1

    return source

def remove_empty_blocks(source):
    """Remove empty if/else blocks left after dead code removal."""
    # Remove  else { }  and  else { \n }
    source = re.sub(r'\s*else\s*\{\s*\}', '', source)
    # Remove  if (...) { }  (any condition, empty body)
    changed = True
    while changed:
        new = re.sub(r'if\s*\([^)]*\)\s*\{\s*\}', '', source)
        changed = new != source
        source = new
    return source


def process_debug(source, is_release=True):
    import re
    replacement = "false" if is_release else "true"

    # Strip function declarations first before we replace their names
    source = re.sub(r'(?:\(:inline\)\s*)?(?:protected\s+|private\s+|public\s+)?(?:static\s+)?function\s+_isDebug\s*\(\)\s*(?:as\s+Lang\.Boolean)?\s*\{[^}]*\}', '', source)

    source = re.sub(r'TinymetrixConfig\.isDebug\(\)', replacement, source)
    source = re.sub(r'\b_isDebug\(\)', replacement, source)
    # Catch isDebug() used without prefix (e.g. inside TinymetrixConfig itself)
    source = re.sub(r'(?<!function )(?<!\.)\bisDebug\(\)', replacement, source)

    if is_release:
        source = remove_dead_blocks(source)
        source = remove_empty_blocks(source)

    return source


def parse_mc_file(filepath):
    with open(filepath, 'r') as f:
        source = f.read()

    imports = []
    has_barrel = False

    for line in source.split('\n'):
        stripped = line.strip()
        if stripped.startswith('import ') or stripped.startswith('using '):
            imports.append(stripped)
        elif stripped == '(:barrel)':
            has_barrel = True

    module_body = ''
    m = re.search(r'\bmodule\s+Tinymetrix\s*\{', source)
    if m:
        brace_start = m.end() - 1
        depth = 1
        j = brace_start + 1
        while j < len(source) and depth > 0:
            if source[j] == '"':
                j = _skip_string(source, j, '"')
                continue
            if source[j] == '{':
                depth += 1
            elif source[j] == '}':
                depth -= 1
            j += 1
        module_body = source[brace_start + 1 : j - 1]

    return imports, has_barrel, module_body


def merge_files(directory):
    mc_files = sorted(glob.glob(os.path.join(directory, '*.mc')))
    if not mc_files:
        print(f"No .mc files found in {directory}", file=sys.stderr)
        sys.exit(1)

    all_imports = []
    seen_imports = set()
    all_bodies = []
    has_barrel = False

    for filepath in mc_files:
        imports, barrel, body = parse_mc_file(filepath)
        has_barrel = has_barrel or barrel
        for imp in imports:
            # Normalize whitespace for deduplication
            normalized = re.sub(r'\s+', ' ', imp)
            if normalized not in seen_imports:
                seen_imports.add(normalized)
                all_imports.append(normalized)
        if body.strip():
            all_bodies.append(body)

    parts = []
    for imp in all_imports:
        parts.append(imp)
    parts.append('')
    if has_barrel:
        parts.append('(:barrel)')
    parts.append('module Tinymetrix {')
    for body in all_bodies:
        parts.append(body)
    parts.append('}')

    return '\n'.join(parts) + '\n'


# ── Strip comments & whitespace ──────────────────────────────────

def strip_comments_and_whitespace(source):
    result = []
    i = 0
    n = len(source)

    while i < n:
        if source[i] == '"':
            j = _skip_string(source, i, '"')
            result.append(source[i:j])
            i = j
        elif source[i] == "'":
            j = _skip_string(source, i, "'")
            result.append(source[i:j])
            i = j
        elif source[i:i+2] == '/*':
            j = source.find('*/', i + 2)
            i = n if j == -1 else j + 2
        elif source[i:i+2] == '//':
            j = source.find('\n', i)
            i = n if j == -1 else j
        else:
            result.append(source[i])
            i += 1

    code = ''.join(result)
    lines = []
    for line in code.split('\n'):
        stripped = line.strip()
        if stripped:
            stripped = re.sub(r'  +', ' ', stripped)
            lines.append(stripped)

    return '\n'.join(lines) + '\n'


# ── Rename private identifiers ───────────────────────────────────

def find_class_blocks(code):
    results = []
    for match in re.finditer(r'\bclass\s+(\w+)', code):
        class_name = match.group(1)
        brace_pos = code.find('{', match.end())
        if brace_pos == -1:
            continue
        depth = 1
        j = brace_pos + 1
        while j < len(code) and depth > 0:
            if code[j] == '"':
                j = _skip_string(code, j, '"')
                continue
            if code[j] == '{':
                depth += 1
            elif code[j] == '}':
                depth -= 1
            j += 1
        results.append({
            'name': class_name,
            'body_start': brace_pos + 1,
            'body_end': j - 1,
        })
    return results


def find_private_names(class_body):
    names = set()
    for m in re.finditer(
        r'\bprivate\s+(?:static\s+)?(?:function|var|const)\s+(\w+)', class_body
    ):
        names.add(m.group(1))
    return sorted(names, key=lambda x: (-len(x), x))


def generate_short_name(index):
    if index < len(SHORT_CHARS):
        return '_' + SHORT_CHARS[index]
    i = index - len(SHORT_CHARS)
    return '_' + SHORT_CHARS[i // len(SHORT_CHARS)] + SHORT_CHARS[i % len(SHORT_CHARS)]


def replace_in_code(code, name_map):
    if not name_map:
        return code
    result = []
    i = 0
    n = len(code)
    while i < n:
        if code[i] == '"':
            j = _skip_string(code, i, '"')
            result.append(code[i:j])
            i = j
        else:
            j = code.find('"', i)
            if j == -1:
                j = n
            chunk = code[i:j]
            for old, new in name_map:
                chunk = re.sub(r'(?<![\.:])' + r'\b' + re.escape(old) + r'\b', new, chunk)
            result.append(chunk)
            i = j
    return ''.join(result)


def rename_private_identifiers(code):
    classes = find_class_blocks(code)
    renames_log = []
    for cls in reversed(classes):
        body = code[cls['body_start']:cls['body_end']]
        private_names = find_private_names(body)
        if not private_names:
            continue
        name_map = []
        for i, name in enumerate(private_names):
            short = generate_short_name(i)
            name_map.append((name, short))
            renames_log.append((cls['name'], name, short))
        new_body = replace_in_code(body, name_map)
        code = code[:cls['body_start']] + new_body + code[cls['body_end']:]
    return code, renames_log


# ── Barrel builder ───────────────────────────────────────────────

def find_sdk():
    # CI (and any contributor who prefers it) can just export CIQ_HOME.
    env_sdk = os.environ.get('CIQ_HOME')
    if env_sdk and os.path.isdir(env_sdk):
        return env_sdk

    candidates = [
        # macOS SDK Manager install location
        '~/Library/Application Support/Garmin/ConnectIQ/Sdks/',
        # Linux SDK Manager install location
        '~/.Garmin/ConnectIQ/Sdks/',
    ]
    for base in candidates:
        sdk_base = os.path.expanduser(base)
        if not os.path.isdir(sdk_base):
            continue
        sdks = sorted([
            d for d in os.listdir(sdk_base)
            if os.path.isdir(os.path.join(sdk_base, d)) and d.startswith('connectiq-sdk')
        ])
        if sdks:
            return os.path.join(sdk_base, sdks[-1])
    return None


def get_barrel_version(project_dir):
    manifest = os.path.join(project_dir, 'manifest.xml')
    if not os.path.isfile(manifest):
        return '0.0.0'
    try:
        tree = ET.parse(manifest)
        root = tree.getroot()
        ns = {'iq': 'http://www.garmin.com/xml/connectiq'}
        barrel = root.find('.//iq:barrel', ns)
        if barrel is not None:
            return barrel.get('version', '0.0.0')
    except Exception:
        pass
    return '0.0.0'


def build_barrel(project_dir, sdk_path, minified_file, barrel_output=None):
    jar = os.path.join(sdk_path, 'bin', 'monkeybrains.jar')
    if not os.path.isfile(jar):
        print(f"Error: monkeybrains.jar not found at {jar}", file=sys.stderr)
        sys.exit(1)

    # Create a temporary project with only the minified source
    tmp_dir = tempfile.mkdtemp(prefix='tinymetrix_build_')
    try:
        # Copy manifest.xml
        shutil.copy2(os.path.join(project_dir, 'manifest.xml'), tmp_dir)

        # Copy the minified .mc file
        shutil.copy2(minified_file, tmp_dir)

        # Create monkey.jungle
        jungle = os.path.join(tmp_dir, 'monkey.jungle')
        with open(jungle, 'w') as f:
            f.write('project.manifest = manifest.xml\n')

        # Determine output path
        if not barrel_output:
            version = get_barrel_version(project_dir)
            output_dir = os.path.join(project_dir, 'output')
            os.makedirs(output_dir, exist_ok=True)
            barrel_output = os.path.join(output_dir, f'tinymetrix-{version}.barrel')

        barrel_output = os.path.abspath(barrel_output)
        os.makedirs(os.path.dirname(barrel_output) or '.', exist_ok=True)

        cmd = [
            'java',
            '-Dfile.encoding=UTF-8',
            '-Dapple.awt.UIElement=true',
            '-cp', jar,
            'com.garmin.monkeybrains.MonkeyBarrelEntry',
            '-o', barrel_output,
            '-f', jungle,
            '-w',
            '-O', '3',
        ]

        print(f"Building barrel in temp project: {tmp_dir}")
        result = subprocess.run(cmd, capture_output=True, text=True)

        if result.returncode != 0:
            print(f"Barrel build failed (exit {result.returncode}):", file=sys.stderr)
            if result.stderr:
                print(result.stderr, file=sys.stderr)
            sys.exit(1)

        if result.stderr:
            for line in result.stderr.strip().split('\n'):
                if line.strip():
                    print(f"  {line}")

        barrel_size = os.path.getsize(barrel_output)
        print(f"Barrel: {barrel_output} ({barrel_size:,} bytes)")
    finally:
        # Always clean up the temp project
        shutil.rmtree(tmp_dir)


# ── Main pipeline ────────────────────────────────────────────────

def minify(source, do_rename=True):
    code = strip_comments_and_whitespace(source)
    renames = []
    if do_rename:
        code, renames = rename_private_identifiers(code)
    return code, renames


def main():
    parser = argparse.ArgumentParser(description='Build & minify Tinymetrix barrel')
    parser.add_argument('input', help='Input .mc file or directory with .mc files')
    parser.add_argument('-o', '--output', help='Output .mc file path')
    parser.add_argument('--no-rename', action='store_true', help='Skip identifier renaming')
    parser.add_argument('--build', action='store_true', help='Build .barrel after minifying')
    parser.add_argument('--release', action='store_true', help='Compile in release mode (strip debug logging)')
    parser.add_argument('--debug', action='store_true', help='Compile in debug mode (force debug logging)')
    parser.add_argument('--sdk', help='Path to Connect IQ SDK (auto-detected if omitted)')
    parser.add_argument('--barrel-output', help='Custom .barrel output path')
    parser.add_argument('-v', '--verbose', action='store_true', help='Show rename mappings')
    args = parser.parse_args()

    input_path = args.input

    # Merge or read single file
    if os.path.isdir(input_path):
        source = merge_files(input_path)
        default_output = os.path.join(input_path, 'bin', 'tinymetrix.min.mc')
    else:
        with open(input_path, 'r') as f:
            source = f.read()
        base, ext = os.path.splitext(input_path)
        default_output = base + '.min' + ext

    original_size = len(source.encode('utf-8'))

    is_release = True
    if args.debug:
        is_release = False
    elif not args.release:
        # Default to release unless specified? The old behavior was config based.
        # But if we inline it, we should probably make --release the default for build, or explicit
        pass

    # Process debug blocks before minification
    source = process_debug(source, is_release=not args.debug)
    minified, renames = minify(source, do_rename=not args.no_rename)

    minified_size = len(minified.encode('utf-8'))
    reduction = ((original_size - minified_size) / original_size) * 100

    output_path = args.output or default_output
    os.makedirs(os.path.dirname(output_path) or '.', exist_ok=True)
    with open(output_path, 'w') as f:
        f.write(minified)

    print(f"Minified: {original_size} -> {minified_size} bytes ({reduction:.1f}% smaller)")
    if renames:
        print(f"Renamed {len(renames)} private identifiers")
    if args.verbose and renames:
        for cls, old, new in renames:
            print(f"  {cls}: {old} -> {new}")

    # Build barrel
    if args.build:
        sdk_path = args.sdk or find_sdk()
        if not sdk_path:
            print("Error: SDK not found. Use --sdk <path>", file=sys.stderr)
            sys.exit(1)
        print(f"SDK: {os.path.basename(sdk_path)}")

        project_dir = input_path if os.path.isdir(input_path) else os.path.dirname(input_path)

        build_barrel(project_dir, sdk_path, output_path, args.barrel_output)


if __name__ == '__main__':
    main()

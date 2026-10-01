#!/usr/bin/env python3
"""Validate and package existing pet artwork; this script never generates or redraws a pet."""
import argparse
import hashlib
import io
import json
import re
import uuid
import zipfile
from pathlib import Path
from PIL import Image


def package(atlas_path, name, description, output, pet_id=None):
    atlas_path, output = Path(atlas_path), Path(output)
    if output.exists():
        raise ValueError('Output already exists; choose a new filename.')
    if not name.strip() or len(name) > 60 or any(ord(c) < 32 or ord(c) == 127 for c in name):
        raise ValueError('Name must be 1–60 characters without control characters.')
    if len(description) > 600:
        raise ValueError('Description exceeds 600 characters.')
    pet_id = pet_id or str(uuid.uuid4())
    if not re.fullmatch(r'[A-Za-z0-9_-]{1,64}', pet_id):
        raise ValueError('Invalid pet ID.')
    data = atlas_path.read_bytes()
    if not 0 < len(data) <= 20 * 1024 * 1024:
        raise ValueError('Atlas must be between 1 byte and 20 MiB.')
    with Image.open(io.BytesIO(data)) as source:
        if source.format != 'PNG' or source.size not in [(1536, 2288), (1536, 1872)]:
            raise ValueError('Use a PNG atlas sized 1536×2288 (v2) or 1536×1872 (v1).')
        if 'A' not in source.getbands() and 'transparency' not in source.info:
            raise ValueError('The PNG must have transparency.')
        image = source.convert('RGBA')
    version = 2 if image.height == 2288 else 1
    counts = [6, 8, 8, 4, 5, 8, 6, 6, 6] + ([8, 8] if version == 2 else [])
    for row, count in enumerate(counts):
        for column in range(8):
            alpha = image.crop((column * 192, row * 208, (column + 1) * 192, (row + 1) * 208)).getchannel('A')
            visible = alpha.getbbox() is not None
            if column < count and (not visible or alpha.getextrema()[0] > 0):
                raise ValueError(f'Row {row}, frame {column} is empty or has an opaque background.')
            if column >= count and visible:
                raise ValueError(f'Unused cell {row},{column} is not transparent.')
    digest = hashlib.sha256(data).hexdigest()
    manifest = {'schemaVersion': 1, 'id': pet_id, 'name': name.strip(), 'description': description,
                'spriteVersion': version, 'atlas': 'spritesheet.png', 'artworkSHA256': digest}
    preview = io.BytesIO()
    image.crop((0, 0, 192, 208)).save(preview, format='PNG')
    output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(output, 'x', zipfile.ZIP_DEFLATED) as archive:
        archive.writestr('manifest.json', json.dumps(manifest, indent=2) + '\n')
        archive.writestr('spritesheet.png', data)
        archive.writestr('preview.png', preview.getvalue())
    with zipfile.ZipFile(output) as archive:
        if archive.testzip() is not None or archive.read('spritesheet.png') != data:
            raise ValueError('Archive verification failed.')
    report = {'ok': True, 'pet_id': pet_id, 'sprite_version': version, 'occupied_cells': sum(counts),
              'atlas_sha256': digest, 'atlas_bytes_preserved': True, 'output': str(output.resolve())}
    output.with_suffix('.validation.json').write_text(json.dumps(report, indent=2) + '\n')
    return report


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--atlas', required=True)
    parser.add_argument('--name', required=True)
    parser.add_argument('--description', default='')
    parser.add_argument('--id')
    parser.add_argument('--output', required=True)
    args = parser.parse_args()
    print(json.dumps(package(args.atlas, args.name, args.description, args.output, args.id), indent=2))

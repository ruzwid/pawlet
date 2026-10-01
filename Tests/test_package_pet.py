import importlib.util
import json
import tempfile
import unittest
import zipfile
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
HELPER = ROOT / '.agents/skills/create-desktop-pet/scripts/package_pet.py'
spec = importlib.util.spec_from_file_location('package_pet', HELPER)
packager = importlib.util.module_from_spec(spec)
spec.loader.exec_module(packager)
SAMPLE = ROOT / 'Resources/Pets/Mochi/spritesheet.png'


class PackagingTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.folder = Path(self.temp.name)

    def tearDown(self):
        self.temp.cleanup()

    def test_roundtrip_preserves_bytes_and_stable_id(self):
        output = self.folder / 'new.petpack'
        report = packager.package(SAMPLE, 'A new pet', 'Any character', output, 'custom-42')
        with zipfile.ZipFile(output) as archive:
            self.assertIsNone(archive.testzip())
            self.assertEqual(archive.read('spritesheet.png'), SAMPLE.read_bytes())
            manifest = json.loads(archive.read('manifest.json'))
            self.assertEqual(manifest['id'], 'custom-42')
            self.assertEqual(set(archive.namelist()), {'manifest.json', 'spritesheet.png', 'preview.png'})
        self.assertEqual(report['occupied_cells'], 73)
        self.assertEqual(report['sprite_version'], 2)

    def test_v1_without_gaze(self):
        atlas = self.folder / 'v1.png'
        with Image.open(SAMPLE) as source:
            source.crop((0, 0, 1536, 1872)).save(atlas)
        report = packager.package(atlas, 'Classic pet', '', self.folder / 'v1.petpack')
        self.assertEqual(report['sprite_version'], 1)
        self.assertEqual(report['occupied_cells'], 57)

    def test_unused_cell_must_be_empty(self):
        atlas = self.folder / 'invalid.png'
        with Image.open(SAMPLE) as source:
            invalid = source.convert('RGBA')
            invalid.putpixel((7 * 192 + 20, 20), (0, 0, 0, 255))
            invalid.save(atlas)
        with self.assertRaisesRegex(ValueError, 'Unused cell'):
            packager.package(atlas, 'Invalid', '', self.folder / 'invalid.petpack')

    def test_ordinary_photo_is_not_atlas(self):
        photo = self.folder / 'photo.png'
        Image.new('RGBA', (192, 208)).save(photo)
        with self.assertRaisesRegex(ValueError, 'atlas sized'):
            packager.package(photo, 'Photo', '', self.folder / 'photo.petpack')

    def test_invalid_id_is_rejected(self):
        with self.assertRaisesRegex(ValueError, 'Invalid pet ID'):
            packager.package(SAMPLE, 'Pet', '', self.folder / 'bad.petpack', '../outside')

    def test_existing_pack_is_never_overwritten(self):
        output = self.folder / 'preserved.petpack'
        output.write_bytes(b'keep this')
        with self.assertRaisesRegex(ValueError, 'already exists'):
            packager.package(SAMPLE, 'Pet', '', output)
        self.assertEqual(output.read_bytes(), b'keep this')


if __name__ == '__main__':
    unittest.main()

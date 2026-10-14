from pathlib import Path
import re
import unittest
import xml.etree.ElementTree as ET


ROOT = Path(__file__).resolve().parents[1]


class ProjectStructureTests(unittest.TestCase):
    def test_main_scene_exists(self):
        project = (ROOT / "project.godot").read_text(encoding="utf-8")
        match = re.search(r'run/main_scene="res://([^"]+)"', project)
        self.assertIsNotNone(match)
        self.assertTrue((ROOT / match.group(1)).is_file())

    def test_scene_and_script_resource_paths_resolve(self):
        source_files = list((ROOT / "scenes").glob("*.tscn")) + list((ROOT / "scripts").glob("*.gd"))
        self.assertGreaterEqual(len(source_files), 5)
        for source in source_files:
            text = source.read_text(encoding="utf-8")
            # Only validate literal resources; dynamic paths such as explorer_%d.svg
            # are assembled at runtime and cannot be resolved from the format string.
            resources = re.findall(r'res://([A-Za-z0-9_./-]+\.(?:gd|tscn|svg))', text)
            for resource in resources:
                self.assertTrue((ROOT / resource).is_file(), f"{source.relative_to(ROOT)} references missing {resource}")

    def test_original_svg_assets_are_well_formed(self):
        assets = sorted((ROOT / "assets").glob("*.svg"))
        self.assertGreaterEqual(len(assets), 4)
        for asset in assets:
            root = ET.parse(asset).getroot()
            self.assertTrue(root.tag.endswith("svg"), asset.name)
            self.assertIn("viewBox", root.attrib, asset.name)

    def test_first_level_has_collect_restore_and_exit_flow(self):
        game = (ROOT / "scripts" / "hope_forest.gd").read_text(encoding="utf-8")
        self.assertIn("add_pickup(Vector2(505, 470), 0)", game)
        self.assertIn("add_pickup(Vector2(928, 414), 1)", game)
        self.assertIn("add_pickup(Vector2(1652, 438), 2)", game)
        self.assertIn("func _restore_grove()", game)
        self.assertIn("create_terrain(2320, 2684, 620, true)", game)
        self.assertIn('progress.save("user://athar_save.cfg")', game)
        self.assertIn('GameSession.change_scene("res://scenes/level_complete.tscn")', game)

    def test_fall_keeps_seed_progress_and_interaction_reaches_gate(self):
        game = (ROOT / "scripts" / "hope_forest.gd").read_text(encoding="utf-8")
        self.assertIn("func _respawn_player(player: CharacterBody2D)", game)
        self.assertIn("player.global_position = _checkpoint", game)
        self.assertIn("_collected_seed_ids.size()", game)
        self.assertIn("[KEY_E, KEY_F, KEY_ENTER, KEY_KP_ENTER]", game)
        self.assertIn("player.global_position.distance_to(GATE_POINT) < 210.0", game)

    def test_browser_preview_uses_local_game_assets(self):
        game = (ROOT / "web-preview" / "game.js").read_text(encoding="utf-8")
        self.assertIn('../assets/hope_forest.svg', game)
        self.assertIn('../assets/explorer.svg', game)
        self.assertIn('../assets/companion.svg', game)
        css = (ROOT / "web-preview" / "style.css").read_text(encoding="utf-8")
        self.assertNotIn("@import url(", css)

    def test_godot_text_catalog_has_both_languages(self):
        catalog = (ROOT / "scripts" / "localization.gd").read_text(encoding="utf-8")
        self.assertGreaterEqual(catalog.count('"ar":'), 20)
        self.assertEqual(catalog.count('"ar":'), catalog.count('"en":'))

    def test_requested_screens_exist(self):
        for scene in ["mode_select", "character_select", "settings", "lobby", "level_complete"]:
            self.assertTrue((ROOT / "scenes" / f"{scene}.tscn").is_file(), scene)


if __name__ == "__main__":
    unittest.main()

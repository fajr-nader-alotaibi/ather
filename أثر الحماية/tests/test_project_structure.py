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
            resources = re.findall(r'res://([A-Za-z0-9_./-]+\.(?:gdshader|gd|tscn|svg|png))', text)
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
        self.assertIn('player.call("reset_to_spawn", _checkpoint)', game)
        self.assertIn("_collected_seed_ids.size()", game)
        self.assertIn("[KEY_E, KEY_F, KEY_ENTER, KEY_KP_ENTER]", game)
        self.assertIn("player.global_position.distance_to(GATE_POINT) < 210.0", game)

    def test_player_uses_two_character_animation_sets_and_palette(self):
        library = (ROOT / "scripts" / "character_library.gd").read_text(encoding="utf-8")
        player_scene = (ROOT / "scenes" / "player.tscn").read_text(encoding="utf-8")
        selector = (ROOT / "scripts" / "character_select.gd").read_text(encoding="utf-8")
        frame_counts = {
            "idle": 1, "walk": 2, "run": 2, "jump": 1, "fall": 1,
            "land": 1, "interact": 1, "double_jump": 2, "air_spin": 3,
        }
        for state in [*frame_counts, "celebrate"]:
            self.assertIn(f'"{state}"', library)
        self.assertIn('type="AnimatedSprite2D"', player_scene)
        self.assertIn("palette_color(index)", selector)
        self.assertIn("GameSession.character_index = _character_index", selector)
        for character in ["lina", "rayan"]:
            folder = ROOT / "assets" / "characters" / character
            for state, expected_count in frame_counts.items():
                frames = sorted(folder.glob(f"{state}_*.png"))
                self.assertEqual(len(frames), expected_count, f"{character}/{state}")
                for frame in frames:
                    self.assertEqual(frame.read_bytes()[:8], b"\x89PNG\r\n\x1a\n")
                if expected_count > 1:
                    self.assertEqual(len({frame.read_bytes() for frame in frames}), expected_count, f"duplicate {character}/{state} frames")
            self.assertTrue((folder / "portrait.png").is_file(), f"{character}/portrait.png")

    def test_interaction_parse_error_is_typed(self):
        game = (ROOT / "scripts" / "hope_forest.gd").read_text(encoding="utf-8")
        self.assertIn("var key: int = int(", game)

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

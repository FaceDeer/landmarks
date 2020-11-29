This mod provides a player-facing interface for the ``named_waypoints`` mod, allowing players to construct "landmark" nodes that they can place in world and use to create their own named waypoints for navigational purposes.

When used in conjunction with the ``default`` mod two types of landmarks will be registered for player use; stone landmarks and gold landmarks. Gold landmarks are visible at five times the range of stone landmarks, and have similarly expanded exclusion zones.

The following settings are available:

``landmarks_proximity_exclusion_radius`` -- No landmark of the same type can be within this many meters of another. Defaults to 100m for stone landmarks, five times that for gold landmarks
``landmarks_uniqueness_exclusion_radius`` -- No landmark within this many meters can have the same (or similar) name. Defaults to 500m for stone landmarks, five times that for gold landmarks
``landmarks_hud_requires_item`` -- If enabled, viewing a waypoint in the hud requires an item in the player inventory
``landmarks_hud_item_required`` -- If an item is required, this is the item that is required. Defaults to ``map:mapping_kit``
``landmarks_hud_visibility_range`` -- Range at which landmark waypoints are visible in a player's HUD. Defaults to 200m for stone landmarks, five times that for gold landmarks

## API

An example of API usage:

	landmarks.register_landmark_type("landmarks:stone_landmark", {
		visibility_radius = base_visibility_radius,
		discovery_radius = 10,
		proximity_radius = base_proximity_radius,
		uniqueness_radius = base_uniqueness_radius,
		requires_item = minetest.settings:get_bool("landmarks_hud_requires_item", true),
		item_required = minetest.settings:get("landmarks_hud_item_required"),
		recipe = {
			{'default:stone_block', 'default:stone_block', 'default:stone_block'},
			{'default:stone_block', 'default:sign_wall_steel', 'default:stone_block'},
			{'default:stone_block', 'default:stone_block', 'default:stone_block'},
		},
		description = S("Stone Landmark"),
		hud_color = 0xDDDDDD,
		blank_tiles = {stone_texture, stone_texture, stone_texture .. "^(landmarks_blank.png^[colorize:#DDDDDD:128^[multiply:#9E9E9E)"},
		tiles = {stone_texture, stone_texture, stone_texture .. "^(landmarks_landmark.png^[colorize:#DDDDDD:128^[multiply:#9E9E9E)"},
		vertical_displacement = 2,
		node_blank_def_override = {},
		node_def_override = {},
	})
	
## License

All code is released under the MIT license.

Textures are under CC0.
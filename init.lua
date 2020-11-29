landmarks = {}

local modpath = minetest.get_modpath(minetest.get_current_modname())
dofile(modpath.."/api.lua")

local S = minetest.get_translator(minetest.get_current_modname())

--------------------------------------------------------------------------------------------------------
-- Default implementations

local base_proximity_radius = tonumber(minetest.settings:get("landmarks_proximity_exclusion_radius")) or 100
local base_uniqueness_radius = tonumber(minetest.settings:get("landmarks_uniqueness_exclusion_radius")) or 500
local base_visibility_radius = tonumber(minetest.settings:get("landmarks_hud_visibility_range")) or 200
local gold_landmark_multiplier = tonumber(minetest.settings:get("landmarks_gold_landmark_multiplier")) or 5

local require_privilege = nil
if minetest.settings:get_bool("landmarks_require_privilege", false) then
	require_privilege = "landmarks"
	minetest.register_privilege("landmarks", S("Grants the ability to name player-placed landmarks."))
end

local requires_item = minetest.settings:get_bool("landmarks_hud_requires_item", true)

local implementation = function(stone_texture, stone_item, gold_texture, gold_item, sign_item, item_required)

	landmarks.register_landmark_type("landmarks:stone_landmark", {
		visibility_radius = base_visibility_radius,
		discovery_radius = 10,
		proximity_radius = base_proximity_radius,
		uniqueness_radius = base_uniqueness_radius,
		requires_item = requires_item,
		item_required = item_required,
		recipe = {
			{stone_item, stone_item, stone_item},
			{stone_item, sign_item, stone_item},
			{stone_item, stone_item, stone_item},
		},
		description = S("Stone Landmark"),
		hud_color = 0xDDDDDD,
		blank_tiles = {stone_texture, stone_texture, stone_texture .. "^(landmarks_blank.png^[colorize:#DDDDDD:128^[multiply:#9E9E9E)"},
		tiles = {stone_texture, stone_texture, stone_texture .. "^(landmarks_landmark.png^[colorize:#DDDDDD:128^[multiply:#9E9E9E)"},
		vertical_displacement = 2,
		node_blank_def_override = {},
		node_def_override = {},
		require_privilege = require_privilege,
	})
	
	landmarks.register_landmark_type("landmarks:gold_landmark", {
		visibility_radius = base_visibility_radius * gold_landmark_multiplier,
		discovery_radius = 20,
		proximity_radius = base_proximity_radius * gold_landmark_multiplier,
		uniqueness_radius = base_uniqueness_radius * gold_landmark_multiplier,
		requires_item = requires_item,
		item_required = item_required,
		recipe = {
			{gold_item, gold_item, gold_item},
			{gold_item, sign_item, gold_item},
			{gold_item, gold_item, gold_item},
		},
		description = S("Gold Landmark"),
		hud_color = 0xFFD700,
		blank_tiles = {gold_texture, gold_texture, gold_texture .. "^(landmarks_blank.png^[colorize:#DDDDDD:128^[multiply:#F5D729)"},
		tiles = {gold_texture, gold_texture, gold_texture .. "^(landmarks_landmark.png^[colorize:#DDDDDD:128^[multiply:#F5D729)"},
		vertical_displacement = 2,
		node_blank_def_override = {},
		node_def_override = {},
		require_privilege = require_privilege,
	})
end

if minetest.get_modpath("default") then
	implementation("default_stone_block.png", "default:stone_block", "default_gold_block.png", "default:goldblock", "default:sign_wall_steel", minetest.settings:get("landmarks_hud_item_required"))
end

if minetest.get_modpath("mcl_signs") and minetest.get_modpath("mcl_core") then
	local item_required = minetest.settings:get("landmarks_hud_item_required")
	if item_required == nil or item_required == "map:mapping_kit" then
		item_required = "mcl_maps:filled_map"
	end
	implementation("mcl_core_stonebrick_carved.png", "mcl_core:stonebrickcarved", "default_gold_block.png", "mcl_core:goldblock", "mcl_signs:wall_sign", item_required)
end

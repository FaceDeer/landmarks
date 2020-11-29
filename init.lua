local modpath = minetest.get_modpath(minetest.get_current_modname())
local default_modpath = minetest.get_modpath("default")
local S = minetest.get_translator(minetest.get_current_modname())

local exclusion_radius = tonumber(minetest.settings:get("landmarks_proximity_exclusion_radius")) or 100
local uniqueness_radius = tonumber(minetest.settings:get("landmarks_uniqueness_exclusion_radius")) or 5000

local base_texture = "default_cobble.png"

local item_required = nil
if minetest.settings:get_bool("landmarks_hud_requires_item", true) then
	item_required = minetest.settings:get("landmarks_hud_item_required")
	if item_required == nil or item_required == "" then
		item_required = "map:mapping_kit"
	end
end

local landmarks_waypoint_def = {
	default_name = S("A Landmark"),
	default_color = 0xFFFFFF,
	discovery_volume_radius = 10,
--	visibility_requires_item = item_required,
}
if minetest.settings:get_bool("landmarks_show_in_hud", true) then
	landmarks_waypoint_def.visibility_volume_radius = tonumber(minetest.settings:get("landmarks_hud_visibility_range")) or 250
	landmarks_waypoint_def.on_discovery = named_waypoints.default_discovery_popup
end
	
named_waypoints.register_named_waypoints("landmarks", landmarks_waypoint_def)


local player_setting_landmark = {}
local set_landmark = function(pos, player)
	local player_name = player:get_player_name()
	local formspec = "formspec_version[2]" ..
		"size[10,2]" ..
		"field[1,0.5;8,0.5;landmark_name;".. S("Landmark Name:") .. ";]" ..
		"button_exit[3.0,1.25;3,0.5;btn_set;".. S("Set") .."]"

	minetest.show_formspec(player_name, "landmarks:set_landmark", formspec)
	player_setting_landmark[player_name] = pos
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= "landmarks:set_landmark" then
		return
	end
	local player_name = player:get_player_name()
	local landmark_pos = player_setting_landmark[player_name]
	if not landmark_pos then
		return
	end
	
	if fields.btn_set or (fields.key_enter and fields.key_enter_field == "landmark_name") then
		local target_node = minetest.get_node(landmark_pos)
		local waypoint_pos = {x=landmark_pos.x, y=landmark_pos.y+2, z=landmark_pos.z}
		if target_node.name ~= "landmarks:landmark_blank" then
			-- some kind of error happened, bail
			player_setting_landmark[player_name] = nil		
			return
		end

		local overlapping_waypoints = named_waypoints.get_waypoints_in_area("landmarks", vector.subtract(waypoint_pos, exclusion_radius), vector.add(waypoint_pos, exclusion_radius))
		if #overlapping_waypoints > 0 then
			minetest.chat_send_player(player_name, S("You're too close to the following existing landmarks:"))
			for _, landmark in pairs(overlapping_waypoints) do
				minetest.chat_send_player(player_name, S("@1 owned by @2", landmark.data.name, landmark.data.owner))
			end
			player_setting_landmark[player_name] = nil		
			return
		end

		if not fields.landmark_name or fields.landmark_name == "" then
			minetest.chat_send_player(player_name, S("Please specify a landmark name."))
			player_setting_landmark[player_name] = nil
			return
		end
		
		local lowercase_landmark_name = string.lower(fields.landmark_name)
		overlapping_waypoints = named_waypoints.get_waypoints_in_area("landmarks", vector.subtract(waypoint_pos, uniqueness_radius), vector.add(waypoint_pos, uniqueness_radius))
		for _, landmark in pairs(overlapping_waypoints) do
			if  string.lower(landmark.data.name) == lowercase_landmark_name then
				minetest.chat_send_player(player_name, S("There's another landmark within @1m of here already named @2.", uniqueness_radius, fields.landmark_name))
				player_setting_landmark[player_name] = nil
				return
			end
		end

		minetest.set_node(landmark_pos, {name="landmarks:landmark", param2=target_node.param2})
		local meta = minetest.get_meta(landmark_pos)
		meta:set_string("owner", player_name)
		meta:set_string("waypoint_pos", minetest.pos_to_string(waypoint_pos))
		meta:set_string("infotext", S('Landmark "@1"\nOwned by@2', fields.landmark_name, player_name))
		
		named_waypoints.add_waypoint("landmarks", waypoint_pos, {name=fields.landmark_name, owner = player_name})
	
		minetest.chat_send_player(player_name, S("Landmark set"))
	end
	
	player_setting_landmark[player_name] = nil		
end)

minetest.register_node("landmarks:landmark_blank", {
    description = S("Blank Landmark"),
    groups = {oddly_breakable_by_hand = 1},
    drawtype = "normal",  -- See "Node drawtypes"
    tiles = {base_texture, base_texture, base_texture .. "^landmarks_blank.png"},
    -- Textures of node; +Y, -Y, +X, -X, +Z, -Z
    paramtype = "light", 
    paramtype2 = "facedir",  -- See "Nodes"
    is_ground_content = false,
    -- If false, the cave generator and dungeon generator will not carve
    -- through this node.
    sounds = {},
    on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
		set_landmark(pos, clicker)
	end,
})

minetest.register_node("landmarks:landmark", {
    description = S("Landmark"),
    groups = {oddly_breakable_by_hand = 1},
    drawtype = "normal",  -- See "Node drawtypes"
    tiles = {base_texture, base_texture, base_texture .. "^landmarks_landmark.png"},
    -- Textures of node; +Y, -Y, +X, -X, +Z, -Z
    paramtype = "light", 
    paramtype2 = "facedir",  -- See "Nodes"
    is_ground_content = false,
    -- If false, the cave generator and dungeon generator will not carve
    -- through this node.
    sounds = {},
    drop = "landmarks:landmark_blank",

    on_destruct = function(pos)
    -- Node destructor; called before removing node.
    -- Not called for bulk node placement.
    -- default: nil
		local meta = minetest.get_meta(pos)
		local waypoint_pos = minetest.string_to_pos(meta:get_string("waypoint_pos"))
		if not waypoint_pos then
			waypoint_pos = pos -- Hail Hydra. Er, I mean, hail Mary
		end
		named_waypoints.remove_waypoint("landmarks", waypoint_pos)
	end,

    can_dig = function(pos, player)
    -- Returns true if node can be dug, or false if not.
    -- default: nil
		local player_name = player:get_player_name()
		local meta = minetest.get_meta(pos)
		if meta:get_string("owner") == player_name or minetest.check_player_privs(player, "server")then
			return true
		end
		return false
	end,

--    on_blast = function(pos, intensity)
    -- intensity: 1.0 = mid range of regular TNT.
    -- If defined, called when an explosion touches the node, instead of
    -- removing the node.
--	end,
})

if default_modpath then
	minetest.register_craft({
		output = 'landmarks:test_node',
		recipe = {
			{'', 'default:cobble', ''},
			{'', 'default:cobble', ''},
			{'default:cobble', 'default:cobble', 'default:cobble'},  -- Also groups; e.g. 'group:crumbly'
		},
	})
end
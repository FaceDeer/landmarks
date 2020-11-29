local S = minetest.get_translator(minetest.get_current_modname())

local player_setting_landmark = {}

landmarks.register_landmark_type = function(base_name, landmark_def)

local proximity_radius = landmark_def.proximity_radius
local uniqueness_radius = landmark_def.uniqueness_radius
local discovery_radius = landmark_def.discovery_radius
local visibility_radius = landmark_def.visibility_radius

local description = landmark_def.description
local vertical_displacement = landmark_def.vertical_displacement or 2
local require_privilege = landmark_def.require_privilege

local item_required = nil
if landmark_def.requires_item then
	item_required = landmark_def.item_required
	if item_required == nil or item_required == "" then
		item_required = "map:mapping_kit"
	end
end

local landmarks_waypoint_def = {
	default_name = S("A Landmark"),
	default_color = landmark_def.hud_color,
	discovery_volume_radius = discovery_radius,
	visibility_requires_item = item_required,
	visibility_volume_radius = visibility_radius,
	on_discovery = named_waypoints.default_discovery_popup,
}
	
named_waypoints.register_named_waypoints(base_name, landmarks_waypoint_def)

local formspec = "formspec_version[2]" ..
	"size[10,2]" ..
	"field[1,0.5;8,0.5;landmark_name;".. S("@1 Name:", description) .. ";]" ..
	"button_exit[3.0,1.25;3,0.5;btn_set;".. S("Set") .."]"

local set_landmark = function(pos, player)
	local player_name = player:get_player_name()
	minetest.show_formspec(player_name, "landmarks:set_landmark"..base_name, formspec)
	player_setting_landmark[player_name] = pos
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= "landmarks:set_landmark"..base_name then
		return
	end
	local player_name = player:get_player_name()
	local landmark_pos = player_setting_landmark[player_name]
	if not landmark_pos then
		return
	end
	
	if fields.btn_set or (fields.key_enter and fields.key_enter_field == "landmark_name") then
		local target_node = minetest.get_node(landmark_pos)
		local waypoint_pos = {x=landmark_pos.x, y=landmark_pos.y+vertical_displacement, z=landmark_pos.z}
		if target_node.name ~= base_name.."_blank" then
			-- some kind of error happened, bail out
			player_setting_landmark[player_name] = nil
			return
		end

		local overlapping_waypoints = named_waypoints.get_waypoints_in_area(base_name, vector.subtract(waypoint_pos, proximity_radius), vector.add(waypoint_pos, proximity_radius))
		if #overlapping_waypoints > 0 then
			minetest.chat_send_player(player_name, S("You're too close to the following existing landmarks of this type:"))
			for _, landmark in pairs(overlapping_waypoints) do
				minetest.chat_send_player(player_name, S("@1 owned by @2", landmark.data.name, landmark.data.owner))
			end
			minetest.chat_send_player(player_name, S("Landmarks of this type must be at least @1m apart.", proximity_radius))
			player_setting_landmark[player_name] = nil		
			return
		end

		local landmark_name = string.gsub(fields.landmark_name or "", "^%s*(.-)%s*$", "%1") -- strip leading and trailing whitespace 
		if landmark_name == "" then
			minetest.chat_send_player(player_name, S("Please specify a landmark name."))
			player_setting_landmark[player_name] = nil
			return
		end

		local remove_characters = "[%s!.?,;:_]+" -- remove whitespace and punctuation to eliminate simple attempts at spoofing
		local simplified_landmark_name =  string.gsub(string.lower(landmark_name), remove_characters, "")
		overlapping_waypoints = named_waypoints.get_waypoints_in_area(base_name, vector.subtract(waypoint_pos, uniqueness_radius), vector.add(waypoint_pos, uniqueness_radius))
		for _, landmark in pairs(overlapping_waypoints) do
			if  string.gsub(string.lower(landmark.data.name), remove_characters, "") == simplified_landmark_name then
				minetest.chat_send_player(player_name, S("There's another landmark of this type within @1m of here with a name similar to @2.", uniqueness_radius, landmark_name))
				player_setting_landmark[player_name] = nil
				return
			end
		end

		minetest.set_node(landmark_pos, {name=base_name, param2=target_node.param2})
		local meta = minetest.get_meta(landmark_pos)
		meta:set_string("owner", player_name)
		meta:set_string("waypoint_pos", minetest.pos_to_string(waypoint_pos))
		meta:set_string("infotext", S('@1 "@2"\nOwned by @3', description, landmark_name, player_name))
		
		named_waypoints.add_waypoint(base_name, waypoint_pos, {name=landmark_name, owner=player_name})
	
		minetest.chat_send_player(player_name, S("Landmark set"))
	end
	
	player_setting_landmark[player_name] = nil		
end)

-- TODO dependency problem; if the mod that provides the item required isn't loaded yet this will fail.
-- Oh well, for the time being I'm not too fussed. nobody reads documentation anyway.
local usage_help_addendum = ""
if item_required and minetest.registered_items[item_required] then
	usage_help_addendum = S(" Players will need to have a @1 in their inventory to see the names of these location markers in their HUDs.", minetest.registered_items[item_required].description)
end

local blank_def = {
    description = S("Blank @1", description),
	_doc_items_longdesc = S("This is a blank @1 ready to be placed and chiseled with a location's name for all to see.", description),
    _doc_items_usagehelp = S("Place the @1 on the ground and right-click it to carve a location name into it. When a player comes within @2m they will 'discover' it, and will then be able to see the location's name from a distance of up to @3m away.", description, discovery_radius, visibility_radius) .. usage_help_addendum,
    groups = {cracky = 1},
    drawtype = "normal",  -- See "Node drawtypes"
    tiles = landmark_def.blank_tiles,
    paramtype = "light", 
    paramtype2 = "facedir",  -- See "Nodes"
    is_ground_content = false,
    -- If false, the cave generator and dungeon generator will not carve
    -- through this node.
    sounds = {},
    on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
		if clicker and minetest.is_protected(pos, clicker:get_player_name()) and not minetest.check_player_privs(clicker, "protection_bypass") then
			minetest.chat_send_player(clicker:get_player_name(), S("This area is protected, you can't name landmarks here."))		
			return
		end
		if require_privilege and not minetest.check_player_privs(clicker, require_privilege) then
			minetest.chat_send_player(clicker:get_player_name(), S("You need the @1 privilege to name landmarks of this type.", require_privilege))
			return
		end
		set_landmark(pos, clicker)
	end,
}
for k,v in pairs(landmark_def.node_blank_def_override or {}) do
	blank_def[k] = v
end
minetest.register_node(base_name.."_blank", blank_def)

local node_def = {
    description = description,
	_doc_items_longdesc = S("This @1 has had the name of this location chiseled into it for all to see.", description),
    _doc_items_usagehelp = S("When a player comes within @1m they will 'discover' this location and will then be able to see the location's name from a distance of up to @2m away. Only the player who named this location can remove this marker and the corresponding name.", discovery_radius, visibility_radius) .. usage_help_addendum,
	groups = {cracky = 1, level = 3, not_in_creative_inventory = 1},
    drawtype = "normal",  -- See "Node drawtypes"
    tiles = landmark_def.tiles,
    -- Textures of node; +Y, -Y, +X, -X, +Z, -Z
    paramtype = "light", 
    paramtype2 = "facedir",  -- See "Nodes"
    is_ground_content = false,
    -- If false, the cave generator and dungeon generator will not carve through this node.
    sounds = {},
    drop = base_name.."_blank",

    on_destruct = function(pos)
		local meta = minetest.get_meta(pos)
		local waypoint_pos = minetest.string_to_pos(meta:get_string("waypoint_pos"))
		if not waypoint_pos then
			waypoint_pos = {x=pos.x, y=pos.y+vertical_displacement, z=pos.z} -- hail Mary
		end
		named_waypoints.remove_waypoint(base_name, waypoint_pos)
	end,

    can_dig = function(pos, player)
		local player_name = player:get_player_name()
		local meta = minetest.get_meta(pos)
		if meta:get_string("owner") == player_name or minetest.check_player_privs(player, "server")then
			return true
		end
		return false
	end,
}
for k,v in pairs(landmark_def.node_def_override or {}) do
	node_def[k] = v
end
minetest.register_node(base_name, node_def)

if landmark_def.recipe then
	minetest.register_craft({
		output = base_name..'_blank',
		recipe = landmark_def.recipe,
	})
end

end

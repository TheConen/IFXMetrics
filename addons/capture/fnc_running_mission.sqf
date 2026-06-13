#include "script_component.hpp"

[
	["bucket", "mission_data"],
	["measurement", "loaded_info"],
	["tags", GVARMAIN(standardTags)],
	["fields", [
		["briefing_name", briefingName],
        ["mission_name", missionName],
        ["mission_name_source", missionNameSource],
        [
            "on_load_name", 
            getMissionConfigValue ["onLoadName", "Unknown"]
        ],
        ["author", getMissionConfigValue ["author", "Unknown"]],
        ["server_name", serverName],
        ["playable_slots_west", playableSlotsNumber west],
        ["playable_slots_east", playableSlotsNumber east],
        ["playable_slots_guer", playableSlotsNumber independent],
        ["playable_slots_civ", playableSlotsNumber civilian],
        ["playable_slots_logic", playableSlotsNumber sideLogic]
	]]
];

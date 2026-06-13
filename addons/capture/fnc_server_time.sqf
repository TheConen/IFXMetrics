#include "script_component.hpp"

[
	["bucket", "mission_data"],
	["measurement", "server_time"],
	["tags", GVARMAIN(standardTags)],
	["fields", [
		["diag_tickTime", diag_tickTime],
		["serverTime", time],
		["timeMultiplier", timeMultiplier],
		["accTime", accTime]
	]]
];

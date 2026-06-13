#include "script_component.hpp"

[
	["bucket", "server_performance"],
	["measurement", "fps"],
	["tags", GVARMAIN(standardTags)],
	["fields", [
		["fps_avg", diag_fps],
		["fps_min", diag_fpsMin]
	]]
];

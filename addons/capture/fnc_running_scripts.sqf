#include "script_component.hpp"

[
	["bucket", "server_performance"],
	["measurement", "running_scripts"],
	["tags", GVARMAIN(standardTags)],
	["fields", [
		["spawn", diag_activeScripts select 0],
		["execVM", diag_activeScripts select 1],
		["exec", diag_activeScripts select 2],
		["execFSM", diag_activeScripts select 3],
		["pfh",
			if (GVARMAIN(cbaLoaded)) then {
				count CBA_common_perFrameHandlerArray
			} else {0}
		]
	]]
];

#include "script_component.hpp"

params ["_name", "_function", "_data"];
if !(_name == GVARMAIN(extensionName)) exitWith {};

// Validate data param
if (isNil "_data") then {_data = ""};

if (_data isEqualTo "") exitWith {
	[
		"WARN",
		format ["Callback empty data: %1", _function]
	] call FUNC(log);
	false;
};

private _dataArr = parseSimpleArray _data;
if (
	(count _dataArr isEqualTo 0) &&
	(_function isNotEqualTo ":LOG:")
) exitWith {
	[
		"WARN",
		format ["Callback invalid data for function %1: %2", _function, _data]
	] call FUNC(log);
	false;
};


switch (_function) do {
	case ":LOG:": {
		diag_log formatText ["[%1] %2", GVARMAIN(logPrefix), _dataArr#0];
	};
	default {
		["INFO", _data] call FUNC(log);
	};
};

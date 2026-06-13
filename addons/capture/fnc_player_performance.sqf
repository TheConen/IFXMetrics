#include "script_component.hpp"

params [
	["_allUserInfos", [], [[]]]
];

private _hashesOut = [];
{
	_x params ["_playerID", "_ownerId", "_playerUID", "_profileName", "_displayName", "_steamName", "_clientState", "_isHC", "_adminState", "_networkInfo", "_unit"];
	_networkInfo params ["_avgPing", "_avgBandwidth", "_desync"];

	if (_unit == objNull || _isHC) then {
		continue;
	};

	_tags = +GVARMAIN(standardTags);
	_tags pushBack ["playerUID", _playerUID];
	_tags pushBack ["playerName", _profileName];

	_hashesOut pushBack ([
		["bucket", "player_performance"],
		["measurement", "network"],
		["tags", _tags],
		["fields", [
			["avgPing", _avgPing],
			["avgBandwidth", _avgBandwidth],
			["desync", _desync]
		]]
	]);
} forEach _allUserInfos;

_hashesOut;

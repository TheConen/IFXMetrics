#include "script_component.hpp"

// wait until READY
waitUntil {
	sleep 2;
    (GVARMAIN(extensionName) callExtension ":READY:") isEqualTo "true";
};

// load settings from extension
private _settings = GVARMAIN(extensionName) callExtension ":SETTINGS:";
if (isNil "_settings") exitWith {
    diag_log formatText[
        "[%1] (ERROR): IFXMetrics extension settings not loaded. IFXMetrics will not be available.",
        GVARMAIN(logPrefix)
    ];
};

_settingsArr = parseSimpleArray _settings;
GVARMAIN(enabled) = _settingsArr select 0;
GVARMAIN(debug) = _settingsArr select 1;
GVARMAIN(refreshRateMs) = _settingsArr select 2;

if (!GVARMAIN(enabled)) exitWith {
    diag_log formatText[
        "[%1] (WARN): IFXMetrics config entry influxdb.enabled is false. IFXMetrics will not be available.",
        GVARMAIN(logPrefix)
    ];
};

// get custom CBA handlers
private _handlersFromExtension = GVARMAIN(extensionName) callExtension ":CUSTOM:CBA:EVENTS:";

_handlersFromExtension = parseSimpleArray _handlersFromExtension;
if (count _handlersFromExtension isEqualTo 0) then {
    diag_log formatText[
        "[%1] (WARN): IFXMetrics custom CBA handlers failed to parse. Custom events will not be logged.",
        GVARMAIN(logPrefix)
    ];
} else {
    diag_log formatText[
        "[%1] (INFO): IFXMetrics custom CBA handlers loaded: %2",
        GVARMAIN(logPrefix),
        _handlersFromExtension
    ];

    // data is a keyed HashMap
    GVARMAIN(cbaHandlers) = createHashMapFromArray _handlersFromExtension;
};


GVARMAIN(standardTags) = [
    ["profile", profileName],
    ["world", worldName],
    ["server", serverName]
];



// Connect to InfluxDB
GVARMAIN(extensionName) callExtension ":INFLUX:CONNECT:";
waitUntil {
	sleep 2;
    (GVARMAIN(extensionName) callExtension ":INFLUX:CONNECTED:") isEqualTo "true";
};


// Send initial mission info
GVARMAIN(extensionName) callExtension [
    ":INFLUX:WRITE:",
    [(call EFUNC(capture,running_mission))]
];


// Set up CBA event listeners
/* example usage:
["milsimServerEfficiency", [
    ["tags", [ // tags must be string values!
        ["missionPhase", "init"]
    ]],
    ["fields", [ // fields can be any type
        ["value", 0.5]
        ["numberOfShinyObjects", 3]
    ]]
]] call CBA_fnc_serverEvent;
*/
{
    _key = _x;
    _hash = _y;
    [
        _hash get "eventName", // event name
        { // function
            _thisArgs params [
                "_enabled",
                "_bucket",
                "_measurement",
                "_description"
            ];
            private _data = [
                ["bucket", _bucket],
                ["measurement", _measurement],
                ["tags", GVARMAIN(standardTags)],
                ["fields", _this]
            ];

            GVARMAIN(extensionName) callExtension [
                ":INFLUX:WRITE:",
                [_data]
            ];
        },
        [ // args
            _hash get "enabled",
            _hash get "bucket", 
            _hash get "measurement",
            _hash get "description"
        ]
    ] call CBA_fnc_addEventHandlerArgs;
} forEach GVARMAIN(cbaHandlers);


// wait five seconds, then start the loop
[{call FUNC(captureLoop);}, 5] call CBA_fnc_waitAndExecute;

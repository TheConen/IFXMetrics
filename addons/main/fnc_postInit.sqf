#include "script_component.hpp"
// if (!isServer) exitWith {};

if (is3DEN || !isMultiplayer) exitWith {};
if (!isServer && hasInterface) exitWith {};


GVARMAIN(cbaLoaded) = isClass(configFile >> "CfgPatches" >> "cba_main");
GVARMAIN(logPrefix) = QUOTE(PREFIX_BEAUTIFIED);
GVARMAIN(extensionName) = QUOTE(PREFIX);


// Create listener for async callbacks
addMissionEventHandler [
    "ExtensionCallback",
    FUNC(callbackHandler)
];

// start loading the extension
[(parseSimpleArray (GVARMAIN(extensionName) callExtension ":START:")) select 0] remoteExec ["systemChat", 0];

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
GVARMAIN(cbaHandlers) = createHashMap;
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
private _connectResult = parseSimpleArray (GVARMAIN(extensionName) callExtension ":INFLUX:CONNECT:");
if (count _connectResult isEqualTo 0) exitWith {
    diag_log formatText[
        "[%1] (ERROR): IFXMetrics failed to connect to InfluxDB. IFXMetrics will not be available.",
        GVARMAIN(logPrefix)
    ];
};
if (_connectResult select 0 isNotEqualTo "OK") exitWith {
    diag_log formatText[
        "[%1] (ERROR): IFXMetrics failed to connect to InfluxDB. IFXMetrics will not be available.",
        GVARMAIN(logPrefix)
    ];
};
[format ["%1", (_connectResult select 1)]] remoteExec ["systemChat", 0];


// Send initial mission info
[
    "DEBUG",
    str (call EFUNC(capture,running_mission))
] call FUNC(log);

GVARMAIN(extensionName) callExtension [
    ":INFLUX:WRITE:",
    [(call EFUNC(capture,running_mission))]
];


// Set up CBA event listeners
/* example usage:
["milsimServerEfficiency", [
    [ // tags in hash format. must be string values!
        ["missionPhase", "init"]
    ],
    [ // fields in hash format. can be any type
        ["value", 0.5]
        ["numberOfShinyObjects", 3]
    ]
]] call CBA_fnc_serverEvent;
*/
{
    _key = _x;
    _hash = createHashMapFromArray _y;
    [
        _hash get "eventName", // event name
        { // function

            if (count _this isNotEqualTo 2) exitWith {
                diag_log formatText[
                    "[%1] (ERROR): IFXMetrics CBA handler %2 received invalid number of arguments. Expected 2, got %3.",
                    GVARMAIN(logPrefix),
                    _thisType,
                    count _this
                ];
            };

            _thisArgs params [
                "_enabled",
                "_bucket",
                "_measurement",
                "_description"
            ];
            private _data = [
                ["bucket", _bucket],
                ["measurement", _measurement],
                ["tags", _this#0],
                ["fields", _this#1]
            ];

            GVARMAIN(extensionName) callExtension [
                ":INFLUX:WRITE:",
                [_data]
            ];
        },
        [ // args
            _key,
            _hash get "enabled",
            _hash get "bucket", 
            _hash get "measurement",
            _hash get "description"
        ]
    ] call CBA_fnc_addEventHandlerArgs;
} forEach GVARMAIN(cbaHandlers);


// wait five seconds, then start the loop
call FUNC(captureLoop);

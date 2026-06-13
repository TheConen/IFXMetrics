#include "script_component.hpp"
/* 
Parameters
_function	The function you wish to execute.  <CODE>
_delay	The amount of time in seconds between executions, 0 for every frame.  (optional, default: 0) <NUMBER>
_args	Parameters passed to the function executing.  (optional) <ANY>
_start	Function that is executed when the PFH is added.  (optional) <CODE>
_end	Function that is executed when the PFH is removed.  (optional) <CODE>
_runCondition	Condition that has to return true for the PFH to be executed.  (optional, default {true}) <CODE>
_exitCondition	Condition that has to return true to delete the PFH object.  (optional, default {false}) <CODE>
_private	List of local variables that are serialized between executions.  (optional) <CODE>
 */
GVARMAIN(captureLoop) = [
    {
        private _startTime = diag_tickTime;

        GVARMAIN(extensionName) callExtension [
            ":INFLUX:WRITE:",
            [
                call EFUNC(capture,server_performance),
                call EFUNC(capture,running_scripts),
                call EFUNC(capture,server_time),
                call EFUNC(capture,weather)
            ]
        ];
    

        // getUserInfo for all users
        private _allUserInfos = allUsers apply {getUserInfo _x} select {count _x > 0};
        // entity_count returns an array of hashMap
        {
            GVARMAIN(extensionName) callExtension [
                ":INFLUX:WRITE:",
                [_x]
            ];
        } forEach ([_allUserInfos] call EFUNC(capture,entity_count));
        {
            GVARMAIN(extensionName) callExtension [
                ":INFLUX:WRITE:",
                [_x]
            ];
        } forEach ([_allUserInfos] call EFUNC(capture,player_performance));

        ["DEBUG", format[
            "Processed primary data loop in %1 ms",
            (diag_tickTime - _startTime) * 1000
        ]] call FUNC(log);
    },
    (GVARMAIN(refreshRateMs) / 1000), // delay in seconds,
    [], // args
    {
        // start
        ["DEBUG", "Starting server performance capture"] call FUNC(log);
    },
    {
        // end
        ["DEBUG", "Stopping server performance capture"] call FUNC(log);
    },
    {
        // runCondition
        true
    },
    {
        // exitCondition
        false
    },
    [] // private
] call CBA_fnc_createPerFrameHandlerObject;

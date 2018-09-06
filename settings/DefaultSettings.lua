---@type RebornUI
local _, RebornUI = ...;

---@class ProfileSettings
local P = {
    printSuccess = "Profile defaults registered successfully.",
    testNumber = 9,

    MeterWindows = {
        enableSkada = true,
        enableRecount = true,
        enableDetails = true,
        visibleBars = 7,
        positions = {

        },
    },
}

RebornUI.defaults = {};
RebornUI.defaults.profile = P;




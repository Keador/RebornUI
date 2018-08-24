---@type RebornUI
local _, RebornUI = ...;

---@class RebornUIEvents
local EVENTS = {
    ---@field Initialize event fires after RebornUI initializes
    Initialize = "Initialize",
    ---@field PostInitialization event fires after event Initialize
    PostInitialization = "PostInitialization",
    ---@field Enable event fires when RebornUI OnEnable fires or when a module is enabled through the option menu
    Enable = "Enable",
    ---@field Disable event fires when RebornUI OnDisable fires or when a module is disabled through the option menu
    Disable = "Disable",
    ---@field ElvUIInitialized event fires when ElvUI has loaded its chat panels
    ElvUIInitialized = "ElvUIInitialized",
    ---@field ElvUINotFound event fires if ElvUI is not present
    ElvUINotFound = "ElvUINotFound",
    ---@field FontsChanged event fires when any font or font color is changed
    FontsChanged = "FontsChanged",
    ---@field TabsSorted event fires when tab positions changed
    TabsSorted = "TabsSorted",
}

---GetEventSystem
---@return EventSystem
function RebornUI:GetEventSystem()
    return self.EventSystem;
end

---GetEvents
---@return RebornUIEvents
function RebornUI:GetEvents()
    return EVENTS;
end

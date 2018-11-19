-- ---@type RebornUI
-- local R = RebornUI;
-- local L, CONSTANTS, profile, global, char = R:GetData();

local ADDON_NAME, ADDON = ...;
---@class RebornUI :AceAddon
local R = LibStub('AceAddon-3.0'):NewAddon(ADDON, ADDON_NAME, 'AceConsole-3.0', 'AceHook-3.0', 'AceEvent-3.0');

R.ADDON_NAME = ADDON_NAME;

local DEFAULTS = { profile = {}, global = {}, char = {} };
R.CONSTANTS = {};

local _G = _G;
local IsAddOnLoaded = IsAddOnLoaded;
local tinsert = table.insert;

local fontChangeRegistry = {};
local colorChangeRegistry = {};

local initializeCallbacks = {};
local elvuiCallbacks = {};

local Locale = LibStub("AceLocale-3.0"):GetLocale(ADDON_NAME);

_G["RebornUI"] = R;

local function FireCallbacks(callbacks, ...)
    for _, callback in pairs(callbacks) do
        callback(...);
    end
end

function R:OnInitialize()
    local savedVars = LibStub("AceDB-3.0"):New(ADDON_NAME .. "_DB", DEFAULTS, true);
    self.profile = savedVars.profile;
    self.global = savedVars.global;
    self.char = savedVars.char;

    self.ElvUI = unpack(_G["ElvUI"]);

    self.ElvUI['valueColorUpdateFuncs'][function() FireCallbacks(colorChangeRegistry) end] = true;
    self:SecureHook(self.ElvUI:GetModule("Chat"), "SetupChat", function() FireCallbacks(fontChangeRegistry) end)
    self:SecureHook(self.ElvUI, "Initialize", function() FireCallbacks(elvuiCallbacks) end)

    FireCallbacks(initializeCallbacks);
end

function R:OnEnable()

end

function R:RegisterModule(module, initCallback, elvuiCallback)
    LibStub("AceAddon-3.0"):EmbedLibraries(module, "AceEvent-3.0", "AceHook-3.0");

    local name = module:GetName();
    initializeCallbacks[name] = initCallback;
    if elvuiCallback then elvuiCallbacks[name] = elvuiCallback end
end

function R:RegisterForFontChange(func)
    tinsert(fontChangeRegistry, func);
end

function R:RegisterForColorChange(func)
    tinsert(colorChangeRegistry, func);
end

function R:RegisterForFontAndColorChange(func)
    tinsert(fontChangeRegistry, func);
    tinsert(colorChangeRegistry, func);
end

local loadedAddons = {};
function R:CheckDependency(dep)
    loadedAddons[dep] = loadedAddons[dep] or IsAddOnLoaded(dep);
    return loadedAddons[dep];
end

function R:GetData()
    return Locale, self.CONSTANTS, DEFAULTS.profile, DEFAULTS.global, DEFAULTS.char;
end



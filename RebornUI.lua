local ADDON_NAME, ADDON = ...;
LibStub("AceAddon-3.0"):NewAddon(ADDON, ADDON_NAME, "AceConsole-3.0", "AceHook-3.0");

---@class RebornUI :AceAddon
local rui = ADDON;
rui.LSM = LibStub("LibSharedMedia-3.0");
rui.L = LibStub("AceLocale-3.0"):GetLocale(ADDON_NAME);
rui.ADDON_NAME = ADDON_NAME;

local defaults = { profile = {}, global = {}, char = {}, };
---@class SavedVariables
local savedVars;

local _G = _G;
_G["RebornUI"] = ADDON;

local IsAddOnLoaded = IsAddOnLoaded;

local tinsert = table.insert;

local fontChangeRegistry = {};
local colorChangeRegistry = {};
local registeredModules = {};
local registeredElvUIModules = {};


local optionalDeps = {
    "Skada",
    "Recount",
    "Details",
}

local function FireCallbacks(funcSet, ...)
    for _, func in pairs(funcSet) do
        func(...);
    end
end

local function SetupForElvui()
    rui.ElvUI = unpack(_G["ElvUI"]);

    rui.ElvUI['valueColorUpdateFuncs'][function() FireCallbacks(colorChangeRegistry)  end] = true;
    rui:SecureHook(rui.ElvUI:GetModule("Chat"), "SetupChat", function() FireCallbacks(fontChangeRegistry) end)
    rui:SecureHook(rui.ElvUI, "Initialize", function() FireCallbacks(registeredElvUIModules) end)
end

function rui:OnInitialize()
    if IsAddOnLoaded("ElvUI") then SetupForElvui() end

    for _, name in ipairs(optionalDeps) do
        self[name .. "Loaded"] = IsAddOnLoaded(name)
    end

    ---@type SavedVariableDB
    savedVars = LibStub("AceDB-3.0"):New(ADDON_NAME .. "_DB", defaults, true);

    for name, func in pairs(registeredModules) do
        func(savedVars.profile[name], savedVars.global[name], savedVars.char[name])
    end
end

function rui:OnEnable()

end

function rui:RegisterModule(module, modDefaults, initFunc, elvuiInitFunc)
    local name = module:GetName();
    registeredModules[name] = initFunc;
    registeredElvUIModules[name] = elvuiInitFunc;

    for key, settings in pairs(modDefaults) do
        defaults[key][name] = settings
    end

    LibStub("AceAddon-3.0"):EmbedLibraries(module, "AceEvent-3.0", "AceHook-3.0");
end

function rui:RegisterForFontChange(func)
    tinsert(fontChangeRegistry, func);
end

function rui:RegisterForColorChange(func)
    tinsert(colorChangeRegistry, func);
end

function rui:RegisterForFontAndColorChange(func)
    tinsert(fontChangeRegistry, func);
    tinsert(colorChangeRegistry, func);
end
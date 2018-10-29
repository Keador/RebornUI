local ADDON_NAME, ADDON = ...;
LibStub("AceAddon-3.0"):NewAddon(ADDON, ADDON_NAME, "AceConsole-3.0", "AceHook-3.0");

---@class RebornUI :AceAddon
local rui = ADDON;
rui.LSM = LibStub("LibSharedMedia-3.0");
rui.L = LibStub("AceLocale-3.0"):GetLocale(ADDON_NAME);
rui.ADDON_NAME = ADDON_NAME;

local _G = _G;
_G["RebornUI"] = ADDON;
local IsAddOnLoaded = IsAddOnLoaded;
local tinsert = table.insert;

local fontChangeRegistry = {};
local colorChangeRegistry = {};
local optionalDeps = {
    "Skada",
    "Recount",
    "Details",
}
function rui:OnInitialize()
    local events = self:GetEvents();

    if IsAddOnLoaded("ElvUI") then
        self.ElvUI = unpack(_G["ElvUI"]);

        self:SecureHook(self.ElvUI, "Initialize", "ElvUIInitialized");
    end

    for _, name in ipairs(optionalDeps) do
        self[name .."Loaded"] = IsAddOnLoaded(name)
    end

    self.db = LibStub("AceDB-3.0"):New(ADDON_NAME .. "_DB", self.defaults, true);

    self.EventHandler:FireEvent(events.Initialize, self.ElvUI);
    self.EventHandler:FireEvent(events.PostInitialization);
end

function rui:OnEnable()
    for _, module in self:IterateModules() do
       -- module:Enable();
    end
end

function rui:ElvUIInitialized()

    -- Hook into ElvUI's value color update system
    local function UpdateColor()
        for i = 1, #colorChangeRegistry do
            colorChangeRegistry[i]();
        end
    end
    self.ElvUI['valueColorUpdateFuncs'][UpdateColor] = true;

    -- Hook SetupChat() so we know when chat fonts are changed
    local function UpdateFont()
        for i = 1, #fontChangeRegistry do
            fontChangeRegistry[i]();
        end
    end
    self:SecureHook(self.ElvUI:GetModule("Chat"), "SetupChat", UpdateFont);

    self.EventHandler:FireEvent(self:GetEvents().ElvUIInitialized)
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
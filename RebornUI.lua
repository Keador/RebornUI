local ADDON_NAME, ADDON = ...;
LibStub("AceAddon-3.0"):NewAddon(ADDON, ADDON_NAME, "AceConsole-3.0", "AceHook-3.0");

---@class RebornUI :AceAddon
local rui = ADDON;
rui.LSM = LibStub("LibSharedMedia-3.0");
rui.L = LibStub("AceLocale-3.0"):GetLocale(ADDON_NAME);
rui.ADDON_NAME = ADDON_NAME;
rui.defaults = { profile = {}, global = {}, char = {}, };

local _G = _G;
_G["RebornUI"] = ADDON;

local IsAddOnLoaded = IsAddOnLoaded;

local optionalDeps = {
    "Skada",
    "Recount",
    "Details",
}

function rui:OnInitialize()
    if IsAddOnLoaded("ElvUI") then
        self.ElvUI = unpack(_G["ElvUI"]);

        self.ElvUI['valueColorUpdateFuncs'][self.OnValueColorChange] = true;
        self:SecureHook(self.ElvUI:GetModule("Chat"), "SetupChat", self.OnFontChange);
        self:SecureHook(self.ElvUI, "Initialize", self.OnElvUIInitialized);
    end

    for _, name in ipairs(optionalDeps) do
        self[name .. "Loaded"] = IsAddOnLoaded(name)
    end

    ---@type SavedVariableDB
    self.db = LibStub("AceDB-3.0"):New(ADDON_NAME .. "_DB", self.defaults, true);

    for name, func in self:IterateRegisteredModules() do
        func(self.db.profile[name], self.db.global[name], self.db.char[name])
    end
end

function rui:OnEnable()

end
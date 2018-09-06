local ADDON_NAME, ADDON = ...;
LibStub("AceAddon-3.0"):NewAddon(ADDON, ADDON_NAME, "AceConsole-3.0", "AceHook-3.0");

---@type RebornUI
local RebornUI = ADDON;
RebornUI.LSM = LibStub("LibSharedMedia-3.0");
RebornUI.L = LibStub("AceLocale-3.0"):GetLocale(ADDON_NAME);

RebornUI.ADDON_NAME = ADDON_NAME;

function RebornUI:OnInitialize()
    local events = self:GetEvents();

    if IsAddOnLoaded("ElvUI") then
        self.ElvUI = unpack(_G["ElvUI"]);
        self:SecureHook(self.ElvUI, "Initialize", "ElvUIInitialized");
    end

    self.db = LibStub("AceDB-3.0"):New(ADDON_NAME.."_DB", self.defaults, true);

    self.EventSystem:FireEvent(events.Initialize, self.ElvUI);
    self.RightChatDock = self:CreateDock("RebornUI_RightChatDock");

    self.EventSystem:FireEvent(events.PostInitialization);
end

function RebornUI:OnEnable()
    self.EventSystem:FireEvent(self:GetEvents().Enable);
end

function RebornUI:ElvUIInitialized()
    self.RightChatDock:SetPosition(RightChatPanel);
    self.RightChatDock:Size(RightChatTab:GetSize());

    self.EventSystem:FireEvent(self:GetEvents().ElvUIInitialized)
end
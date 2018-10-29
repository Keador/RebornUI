---@type RebornUI
local _, RebornUI = ...;
local EventHandler = RebornUI:GetEventHandler();
local events = RebornUI:GetEvents();

---@type RebornUIModule
local prototype = {};

---@private
function prototype:Initialize(ElvUI)
    EventHandler:RemoveEvent(self, events.Initialize);

    self.ElvUI = ElvUI;
    self.SV = RebornUI.db.profile[self:GetName()];

    EventHandler:AddEvent(self, events.PostInitialization);
end

---@private
function prototype:PostInitialization()
    EventHandler:RemoveEvent(self, events.PostInitialization);

    EventHandler:AddEvent(self, events.Enable);
end

function prototype:Enable()
    EventHandler:AddEvent(self, events.Disable);
end

function prototype:Disable()
    EventHandler:AddEvent(self, events.Enable);
end

function prototype:OnEvent(event, ...)
    self[event](self, ...);
end

---@return Module
function RebornUI:CreateModule(name, ...)
    ---@class  Module : AceAddonModule
    local module = self:NewModule(name, prototype, "AceEvent-3.0", "AceHook-3.0", ...);

    EventHandler:AddEvent(module, events.Initialize);
    return module;
end

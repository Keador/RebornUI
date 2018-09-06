---@type RebornUI
local _, RebornUI = ...;
local EventSystem = RebornUI:GetEventSystem();
local events = RebornUI:GetEvents();

---@type RebornUIModule
local prototype = {};

---@private
function prototype:Initialize(ElvUI)
    EventSystem:RemoveEvent(self, events.Initialize);

    self.ElvUI = ElvUI;
    self.SV = RebornUI.db.profile[self:GetName()];

    EventSystem:AddEvent(self, events.PostInitialization);
end

---@private
function prototype:PostInitialization()
    EventSystem:RemoveEvent(self, events.PostInitialization);

    EventSystem:AddEvent(self, events.Enable);
end

function prototype:Enable()
    EventSystem:AddEvent(self, events.Disable);
end

function prototype:Disable()
    EventSystem:AddEvent(self, events.Enable);
end

function prototype:OnEvent(event, ...)
    self[event](self, ...);
end

---LoadModule
---@param name string name of the module
---@return RebornUIModule
function RebornUI:LoadModule(name, ...)
    ---@type RebornUIModule
    local module = self:NewModule(name, prototype, "AceEvent-3.0", "AceHook-3.0", ...);

    EventSystem:AddEvent(module, events.Initialize);
    return module;
end

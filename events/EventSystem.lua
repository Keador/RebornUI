---@type RebornUI
local _, RebornUI = ...;

---@type EventSystem
local EventSystem = {};
LibStub("AceEvent-3.0"):Embed(EventSystem);

function EventSystem:GetName() return "EventSystem" end

local function SetOnEventScript(object)
    object.OnEvent = function(obj, event, ...)
        obj[event](obj, ...);
    end
end

---AddEvent
---@param obj table
---@param event string
---@param func fun(obj:table) | string
function EventSystem:AddEvent(obj, event, func)
    if not obj.OnEvent then SetOnEventScript(obj) end
    if event == nil then return end
    obj:RegisterMessage(event, func or obj.OnEvent, obj);
end

---AddGameEvent
---@param obj table
---@param event string
---@param func fun(obj:table)
function EventSystem:AddGameEvent(obj, event, func)
    if not obj.OnEvent then SetOnEventScript(obj) end
    obj:RegisterEvent(event, func or obj.OnEvent, obj);
end

---RemoveEvent
---@param obj table
---@param event string
function EventSystem:RemoveEvent(obj, event)
    obj:UnregisterMessage(event);
end

---RemoveGameEvent
---@param obj table
---@param event string
function EventSystem:RemoveGameEvent(obj, event)
    obj:UnregisterEvent(event);
end

---FireEvent
---@param event event
function EventSystem:FireEvent(event, ...)
    --RebornUI:Print(event);
    self:SendMessage(event, ...);
end
RebornUI.EventSystem = EventSystem;

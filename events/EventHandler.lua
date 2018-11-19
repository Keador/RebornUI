---@type RebornUI
local R = RebornUI;

---@class EventHandler
local EventHandler = {};
LibStub("AceEvent-3.0"):Embed(EventHandler);

local function SetOnEventScript(object)
    object.OnEvent = function(obj, event, ...)
        obj[event](obj, ...);
    end
end

---@param obj table
---@param event string
---@param func fun(obj:table) | string
function EventHandler:AddEvent(obj, event, func)
    if not obj.OnEvent then SetOnEventScript(obj) end
    if event == nil then return end
    obj:RegisterMessage(event, func or obj.OnEvent, obj);
end

---@param obj table
---@param event string
---@param func fun(obj:table)
function EventHandler:AddGameEvent(obj, event, func)
    if not obj.OnEvent then SetOnEventScript(obj) end
    obj:RegisterEvent(event, func or obj.OnEvent, obj);
end

---@param obj table
---@param event string
function EventHandler:RemoveEvent(obj, event)
    obj:UnregisterMessage(event);
end

---@param obj table
---@param event string
function EventHandler:RemoveGameEvent(obj, event)
    obj:UnregisterEvent(event);
end

---@param event event
function EventHandler:FireEvent(event, ...)
    --RebornUI:Print(event);
    self:SendMessage(event, ...);
end

R.EventHandler = EventHandler;

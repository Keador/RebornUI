---@type RebornUI
local rui = RebornUI;

local fontChangeRegistry = {};
local colorChangeRegistry = {};
local registeredModules = {};
local registeredElvUIModules = {};

local tinsert = table.insert;

function rui:RegisterModule(name, initFunc, elvuiInitFunc, profile, global, char)
    registeredModules[name] = initFunc;
    registeredElvUIModules[name] = elvuiInitFunc;
    self.defaults.profile[name] = profile;
    self.defaults.global[name] = global;
    self.defaults.char[name] = char;

    local module = self:GetModule(name);
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

function rui:IterateRegisteredModules()
    return pairs(registeredModules);
end

function rui:IterateElvUIModules()
    return pairs(registeredElvUIModules);
end

function rui.OnElvUIInitialized()
    for _, func in pairs(registeredElvUIModules) do
        func();
    end
end
function rui.OnValueColorChange()
    for _, func in ipairs(colorChangeRegistry) do
        func();
    end
end

function rui.OnFontChange()
    for _, func in ipairs(fontChangeRegistry) do
        func();
    end
end
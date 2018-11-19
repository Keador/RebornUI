---@type RebornUI
local R = RebornUI;
local L, CONSTANTS, profile, global, char = R:GetData();
local LSM = LibStub('LibSharedMedia-3.0');

function R:GetTabFontColor()
    return unpack(self.ElvUI["media"].rgbvaluecolor);
end

function R:GetTabFont(sizeOff)
    local db = self.ElvUI.db.chat
    sizeOff = sizeOff or 0;
    return LSM:Fetch("font", db.tabFont), db.tabFontSize + sizeOff, db.tabFontOutline;
end

function R:GetChatFont(sizeOff)
    local db = self.ElvUI.db.chat
    sizeOff = sizeOff or 0;
    return LSM:Fetch("font", db.font), db.fontSize + sizeOff, db.fontOutline;
end

function R:GetSpacing()
    if self.ElvUI then
        return self.ElvUI.Border * 3 - self.ElvUI.Spacing;
    else
        return 1;
    end
end

do
    ---Right now this adds functions to call for ElvUI API if ElvUI is loaded.
    ---Eventually our own API will be set here if ElvUI is not loaded.
    local function SetAPI(obj)
        local mt = getmetatable(obj).__index;
        mt.FontTemplate = mt.FontTemplate or mt.SetFont;
        mt.Point = mt.Point or mt.SetPoint;
        mt.Width = mt.Width or mt.SetWidth;
        mt.Height = mt.Height or mt.SetHeight;
        mt.Size = mt.Size or mt.SetSize;
        mt.AddBackdrop = mt.CreateBackdrop or function() end;
        mt.SetInside = mt.SetInside or function() end;
    end

    local obj = CreateFrame("Frame");
    SetAPI(obj);
    SetAPI(obj:CreateTexture());
    SetAPI(obj:CreateFontString());
    local apiSet = { Frame = true };

    obj = EnumerateFrames();
    while obj do
        if not obj:IsForbidden() and not apiSet[obj:GetObjectType()] then
            SetAPI(obj);
            apiSet[obj:GetObjectType()] = true;
        end

        obj = EnumerateFrames(obj);
    end
end
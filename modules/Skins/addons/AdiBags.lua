---@type RebornUI
local R = RebornUI;
local L, CONSTANTS, profile, global, char = R:GetData();
---@type Skins
local Skins = R:GetModule('Skins');

local function LoadSkin()
    if not R:CheckDependency('AdiBags') or not R.profile.skins.enableAdiBags then return end
    local adibags = LibStub("AceAddon-3.0"):GetAddon("AdiBags");

    local bagFont = adibags.db.profile.bagFont;
    bagFont.r, bagFont.g, bagFont.b = R:GetTabFontColor();

    local function LayoutBags()
        for index, bag in adibags:IterateBags() do
            if not bag.isSkinned and bag:HasFrame() then

                local frame = bag:GetFrame();
                Skins:HandleFrame(frame, 'Transparent');
                Skins:HandleFrame(_G[frame:GetName() .. "Bags"], 'Transparent');

                for i, widget in ipairs(frame.HeaderRightRegion.widgets) do
                    local w = widget.widget;
                    if w:IsObjectType("Button") then
                        Skins:HandleButton(w, 'ButtonText');
                    elseif w:IsObjectType("EditBox") then
                        Skins:HandleEditBox(w);
                    end
                end

                Skins:HandleButton(frame.CloseButton, 'Close');
                Skins:HandleTexture(frame.BagSlotButton:GetNormalTexture());

                bag.isSkinned = true;
            end
        end
    end

    Skins:SecureHook(adibags, "LayoutBags", LayoutBags);
end
Skins:RegisterCallbackToSkin(LoadSkin);

profile.skins.enableAdiBags = true;
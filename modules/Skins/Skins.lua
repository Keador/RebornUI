---@type RebornUI
local R = RebornUI;
local L, CONSTANTS, profile, global, char = R:GetData();

---@class Skins : Module
local Skins = R:NewModule("Skins");

local eSkins;
local callbacks = {};

function Skins:Initialize(...)
    eSkins = R.ElvUI:GetModule("Skins");
end

function Skins:OnEnable()
    for callback in pairs(callbacks) do callback() end
end

function Skins:HandleCloseButton(closeButton)
    eSkins:HandleCloseButton(closeButton);
end

function Skins:HandleFrame(frame, template)
    frame:CreateBackdrop(template);
end

function Skins:HandleButton(button, template)
    if template == 'ButtonText' then

        eSkins:HandleButton(button, true);

        local letter = button:GetText();
        ---@type FontString
        local fs = button:CreateFontString(nil, 'OVERLAY');
        fs:SetFont([[Interface\AddOns\ElvUI\media\fonts\PT_Sans_Narrow.ttf]], 16, 'OUTLINE');
        fs:SetText(letter);
        fs:SetJustifyH('CENTER');
        fs:Point('CENTER', button, 'CENTER');

    elseif template == 'Close' then
        eSkins:HandleCloseButton(button, nil, 'X');
        button.backdrop:Point('TOPLEFT', 5, -7);
        button.backdrop:Point('BOTTOMRIGHT', -7, 6);

    elseif template == "Icon" then
        local tex = button:GetNormalTexture():GetTexture();
        eSkins:HandleButton(button, true);
        button:SetNormalTexture(tex);

    end
end

function Skins:HandleEditBox(editBox)
    eSkins:HandleEditBox(editBox);
end

function Skins:HandleTexture(tex)
    tex:SetTexCoord(unpack(R.ElvUI.TexCoords))
end

function Skins:RegisterCallbackToSkin(callback)
    callbacks[callback] = true;
end

profile['skins'] = {}

R:RegisterModule(Skins, function() Skins:Initialize() end);
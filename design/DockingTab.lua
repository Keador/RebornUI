---@type RebornUI
local _, RebornUI = ...;
---@type Design
local design = RebornUI:GetModule("Design");

local insert, remove = tinsert, tremove;

---@type DockingTab
local mixin = {};

local AVAILABLE_TABS = {};
local SPACING;

local DropDown_OnInitialize;

---NewDockingFrame
---@param dockManager DockManager dock manager that this tab will dock to
---@param title string title to be displayed on the tab
---@param type string type of docking tab NYI
---@return DockingTab
function design:NewDockingTab(dockManager, title, type)
    ---@type DockingTab
    local tab;
    for i = 1, #AVAILABLE_TABS do
        tab = remove(AVAILABLE_TABS, i);
    end

    if not tab then
        tab = CreateFrame("Button", nil, dockManager, "RebornUI_DockingTabTemplate");
        Mixin(tab, mixin);
    end
    tab:SetTitle(title);
    tab:SetScript("OnClick", function(t, mb) t:OnClick(mb, dockManager) end);

    tab.frame:CreateBackdrop("Transparent")
    tab.frame.backdrop:SetBackdropColor(0, 0, 0, 0);

    tab.dropDown:SetScript("OnShow", function(dropDown) UIDropDownMenu_Initialize(dropDown, DropDown_OnInitialize, "MENU") end)

    SPACING = SPACING or design:GetSpacing();
    return tab;
end

function DropDown_OnInitialize(dropDown)
    --@debug@
    RebornUI:Print("DropDownOnInitialize()");
    --@end-debug@
    if not dropDown.backdrop then
        dropDown:CreateBackdrop();
    end
    dropDown:Show();
end

function mixin:OnClick(button, dockManager)
    PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON);
    if button == "LeftButton" then
        if self.dockID == dockManager.selectedTab then return end
        dockManager:SelectTab(self.dockID);
    elseif button == "RightButton" then
        if self.dropDown:IsShown() then
            self.dropDown:Hide();
        else
            self.dropDown:Show();
        end
    end
end

function mixin:SetTitle(title)
    self.title = title;
    self.text:SetText(title);
end

function mixin:Resize(padding, absoluteSize, minWidth, maxWidth, absoluteTextSize)
    local width, tabWidth, textWidth;
    local sideWidth = 6;

    if absoluteTextSize then
        textWidth = absoluteTextSize;
    else
        self.text:Width(0);
        textWidth = self.text:GetWidth();
    end

    if absoluteSize then
        width = absoluteSize - sideWidth;
        tabWidth = absoluteSize;

        self.text:Width(width);
    else
        -- todo add other functionality?
    end

    self:Width(tabWidth);
end

function mixin:SetFrameSize(a1, a2)
    self.frame:ClearAllPoints();
    self.frame:SetPoint("TOPLEFT", a1, "BOTTOMLEFT", SPACING / 3, -SPACING);

    if design.ElvUI.db.datatexts.rightChatPanel then
        self.frame:SetPoint("BOTTOMRIGHT", a2, "BOTTOMRIGHT", -SPACING * 1.5, RightChatDataPanel:GetHeight() + (SPACING * 2));
    else
        self.frame:SetPoint("BOTTOMRIGHT", a2, "BOTTOMRIGHT", -SPACING * 1.5, SPACING * 1.5);
    end
    self.width = self.frame:GetWidth();
    self.height = self.frame:GetHeight();
end

function mixin:Store()
    insert(AVAILABLE_TABS, self);
    self:Hide();
end

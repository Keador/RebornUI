---@type RebornUI
local _, RebornUI = ...;

---@type Dock
local DockMixin = {};
DockMixin.DOCKED_TABS = {};
DockMixin.STORED_TABS = {};
DockMixin.HIDDEN_TABS = {};
---@type DockingTab
local DockTabMixin = {};

local OverflowButton_UpdateList, TabDropDown_OnInitialize, GetNextTabID;

---@type RebornUILocalization
local L = RebornUI.L;
---@type Design
local Design = RebornUI:GetModule("Design");

---@type EventSystem
local EventSystem = RebornUI:GetEventSystem();
---@type RebornUIEvents
local events = RebornUI:GetEvents();

local insert, remove, delete, indexOf = tinsert, tremove, tDeleteItem, tIndexOf;
local min, max, abs, floor = min, max, abs, floor;
local format = format;

local SPACING;
function RebornUI:CreateDock(name)
    SPACING = Design:GetSpacing();

    ---@type Dock
    local dock = CreateFrame("ScrollFrame", name, UIParent);
    Mixin(dock, DockMixin);

    dock:SetFrameStrata("LOW")
    dock.overflowButton = dock:CreateOverflowButton();

    local scrollChild = CreateFrame("Frame", name .. "ScrollChild", dock);
    scrollChild:SetWidth(1);
    scrollChild:SetHeight(22);
    scrollChild:Point("TOPLEFT");
    dock:SetScrollChild(scrollChild);

    dock.frameAnchor = CreateFrame("Frame", nil, dock);

    return dock;
end

---@return OverflowButton
function DockMixin:CreateOverflowButton()
    ---@type OverflowButton
    local newOFB = CreateFrame("Button", self:GetName() .. "OverflowButton", self);

    newOFB:Size(16, 16);
    newOFB:Point("RIGHT");
    newOFB:SetAlpha(0.7);

    local list = CreateFrame("Frame", newOFB:GetName() .. "List", newOFB, "UIDropDownMenuTemplate");
    list:SetScript("OnShow", function(l) UIDropDownMenu_Initialize(l, OverflowButton_UpdateList, "Menu") end);

    UIDropDownMenu_Initialize(list, OverflowButton_UpdateList, "Menu");
    UIDropDownMenu_SetAnchor(list, 0, 0, "TOPRIGHT", newOFB, "BOTTOMRIGHT");
    newOFB.list = list;

    newOFB:SetNormalTexture("Interface/ChatFrame/chat-tab-arrow");
    newOFB:SetHighlightTexture("Interface/ChatFrame/chat-tab-arrow-on", "ADD");

    newOFB.width = newOFB:GetWidth();

    newOFB:SetScript("OnClick", function(b)
        PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON);
        ToggleDropDownMenu(1, nil, b.list);
    end);

    return newOFB;
end

---@return DockingTab
function DockMixin:NewTab(text, position)
    local handlers = { "OnClick" };
    ---@type DockingTab
    local tab;
    for i = 1, #self.STORED_TABS do
        tab = remove(self.STORED_TABS, i);
        break ;
    end

    if not tab then
        local id = GetNextTabID();
        local tabName = "RebornUI_MeterTab" .. id;
        tab = CreateFrame("Button", tabName, self, nil, id);
        Mixin(tab, DockTabMixin);

        tab:Size(50, 22);
        tab:RegisterForClicks("LeftButtonDown", "RightButtonDown");
        tab:SetButtonText(text);

        for _, script in ipairs(handlers) do
            tab:SetScript(script, tab[script]);
        end

        tab.frame = CreateFrame("Frame", tabName .. "Frame", tab, nil, id);

        local dropDown = CreateFrame("Frame", tab:GetName() .. "DropDown", tab, "UIDropDownMenuTemplate");
        UIDropDownMenu_Initialize(dropDown, TabDropDown_OnInitialize, "MENU");
        UIDropDownMenu_SetAnchor(dropDown, 0, 0, "TOP", tab, "TOP");
        tab.dropDown = dropDown;
    end

    tab.position = position;
    tab:SetButtonText(text);
    self:DockTab(tab);

    return tab;
end

---@param tab DockingTab
function DockMixin:DockTab(tab)
    if tab.position then
        insert(self.DOCKED_TABS, tab.position, tab);
    else
        insert(self.DOCKED_TABS, tab);
    end
    tab.frame:SetAllPoints(self.frameAnchor);
    self:UpdateTabs();
end

function DockMixin:UndockTab(tab, permanent)
    delete(self.DOCKED_TABS, tab);

    EventSystem:FireEvent(events.TabsSorted);
    self:UpdateTabs();

    if permanent then
        tab.position = nil;
        tab:Store();
    end
end

function DockMixin:HideTab(tab)
    tab.isHidden = true;
    self:UndockTab(tab);
    tab:Hide();
    insert(self.HIDDEN_TABS, tab);
    tab.hiddenID = #self.HIDDEN_TABS;
end

function DockMixin:ShowTab(tab)
    delete(self.HIDDEN_TABS, tab);
    tab.isHidden = false;
    tab.hiddenID = nil;
    self:DockTab(tab);
end

function DockMixin:SelectTab(tab)
    if type(tab) == "number" then tab = self.DOCKED_TABS[tab] end
    self:SetSelectedTab(tab);
    self:UpdateTabs();
end

function DockMixin:SetSelectedTab(tab)
    self.selected = tab;
end

function DockMixin:GetSelectedTab()
    return self.selected or self.DOCKED_TABS[1];
end

---@param tab DockingTab
function DockMixin:MoveTab(tab, direction)
    PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON);
    self:UndockTab(tab);

    tab.position = tab.position + ((direction == "left" and -1) or (direction == "right" and 1) or 0);
    self:DockTab(tab);
    EventSystem:FireEvent(events.TabsSorted);
    self:SelectTab(tab);
end

local TAB_HEIGHT = 22;
function DockMixin:SetPosition(anchor, forceUpdate)
    self.anchor = self.anchor or anchor;

    self:ClearAllPoints();
    self:Point("TOPLEFT", self.anchor, "TOPLEFT", SPACING, -SPACING);
    self:Point("TOPRIGHT", self.anchor, "TOPRIGHT", -SPACING, -SPACING);

    self.frameAnchor:Point("TOPLEFT", self, "BOTTOMLEFT", SPACING / 3, -SPACING);
    if Design.ElvUI.db.datatexts.rightChatPanel then
        self.frameAnchor:Point("BOTTOMRIGHT", self.anchor, "BOTTOMRIGHT", -SPACING * 1.5, RightChatDataPanel:GetHeight() + (SPACING * 2));
    else
        self.frameAnchor:Point("BOTTOMRIGHT", self.anchor, "BOTTOMRIGHT", -SPACING * 1.5, SPACING * 1.5);
    end
end

function DockMixin:ShowOverflowButton()
    local x = self.overflowButton:GetWidth() + 2;

    self.overflowButton:Point("TOPRIGHT", self.anchor, "TOPRIGHT", -4, -7);
    self:Point("TOPRIGHT", self.anchor, "TOPRIGHT", -x, -2);

    self.overflowButton:Show();
end

function DockMixin:HideOverflowButton()
    self:SetPosition();
    self.overflowButton:Hide();
end

function DockMixin:UpdateTabs()
    local lastDockedTab, selectedTabIndex;
    local scrollChild = self:GetScrollChild();

    local numFrames = 0;
    for i, tab in ipairs(self.DOCKED_TABS) do
        local frame = tab.frame;
        tab.position = indexOf(self.DOCKED_TABS, tab);
        numFrames = numFrames + 1;
        if self:GetSelectedTab() == tab then
            selectedTabIndex = numFrames;
            frame:Show();
            tab:SetAlpha(1.0);
        else
            frame:Hide();
            tab:SetAlpha(0.6);
        end

        tab:ClearAllPoints();
        tab:Show();

        if lastDockedTab then
            tab:Point("LEFT", lastDockedTab, "RIGHT");
        else
            tab:Point("LEFT", scrollChild, "LEFT");
        end
        lastDockedTab = tab;
    end

    self:UpdateTabFonts();

    local tabSize = self:CalculateTabSize(numFrames);

    for i = 1, #self.DOCKED_TABS do
        self.DOCKED_TABS[i]:Resize(0, tabSize);
    end

    if self.hasOverflow or #self.HIDDEN_TABS > 0 then
        self:ShowOverflowButton();
    else
        self.overflowButton:Hide();
    end

    self.tabSize = tabSize;
    self.numFrames = numFrames;
    self.selectedTabIndex = selectedTabIndex;

    self.isDirty = false;
    self:JumpToTab();
end

function DockMixin:CalculateTabSize(numFrames)
    local MIN_SIZE, MAX_SIZE = 94, 104;
    local scrollSize = self:GetWidth() + (self.overflowButton:IsShown() and -self.overflowButton.width or 0);

    if numFrames * MAX_SIZE < scrollSize then
        self.hasOverflow = false;
        return MAX_SIZE;
    end

    if scrollSize / MIN_SIZE < numFrames then
        scrollSize = scrollSize - self.overflowButton.width;
    end

    local numWholeTabs = min(floor(scrollSize / MIN_SIZE), numFrames);
    if scrollSize == 0 then
        self.hasOverflow = numFrames > 0;
        return 1;
    end
    if numWholeTabs == 0 then
        return scrollSize, true;
    end

    local tabSize = scrollSize / numWholeTabs;
    self.hasOverflow = numFrames > numWholeTabs;

    return tabSize;
end

function DockMixin:JumpToTab(lt)
    -- Setting leftTab here may cause a problem in the future
    local leftTab = self:GetLeftMostTab();
    local numDisplayedTabs = floor(self:GetWidth() / self.tabSize);

    if self.selectedTabIndex then
        if self.selectedTabIndex >= leftTab + numDisplayedTabs then
            leftTab = self.selectedTabIndex - numDisplayedTabs + 1;
        elseif self.selectedTabIndex < leftTab then
            leftTab = self.selectedTabIndex;
        end
    end

    leftTab = min(leftTab, self.numFrames - numDisplayedTabs + 1);

    leftTab = max(leftTab, 1);

    self:SetHorizontalScroll(self.tabSize * (leftTab - 1));
    self:SetVisibleTabs(leftTab, self:GetRightMostTab(leftTab, numDisplayedTabs));

    -- TODO 7/30/2018: Overflow button pulse?
end

function DockMixin:GetLeftMostTab()
    -- This needs to be a separate function if we want to add dragging tabs to different positions
    return floor((self:GetHorizontalScroll() / self.tabSize) + 0.5) + 1;
end

function DockMixin:GetRightMostTab(leftTab, numDisplayedTabs)
    return floor(leftTab + numDisplayedTabs) - 1;
end

function DockMixin:SetVisibleTabs(leftTab, rightTab)
    for i, tab in ipairs(self.DOCKED_TABS) do
        if tab.position < leftTab or tab.position > rightTab then
            tab:Hide();
        else
            tab:Show();
        end
    end
end

function DockMixin:UpdateTabFonts()
    local r, g, b = Design:GetTabFontColor();
    local f, s, o = Design:GetTabFont();

    for i = 1, #self.DOCKED_TABS do
        local fs = self.DOCKED_TABS[i]:GetFontString();
        fs:FontTemplate(f, s, o);
        fs:SetTextColor(r, g, b);
    end
end

function DockTabMixin:OnClick(button)
    PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON);
    if button == "LeftButton" then
        local dock = self:GetParent();
        if self == dock:GetSelectedTab() then return end
        dock:SelectTab(self);
        return ;
    end
    if button == "RightButton" then
        ToggleDropDownMenu(1, nil, self.dropDown);
    end
end

function DockTabMixin:SetButtonText(text)
    self.title = text;
    self:SetText(text);
end

function DockTabMixin:Resize(padding, absoluteSize, minWidth, maxWidth, absoluteTextSize)
    local width, tabWidth, textWidth;
    local sideWidth = 6;

    local fs = self:GetFontString();
    if absoluteTextSize then
        textWidth = absoluteTextSize;
    else
        fs:Width(0);
        textWidth = fs:GetWidth();
    end

    if absoluteSize then
        width = absoluteSize - sideWidth;
        tabWidth = absoluteSize;

        fs:Width(width);
    else
        -- todo add other functionality?
    end

    self:Width(tabWidth);
end

function DockTabMixin:Store()
    insert(self:GetParent().STORED_TABS, self);
    self:Hide();
end

function TabDropDown_OnInitialize(dropDown)
    local tab = dropDown:GetParent();
    local dock = tab:GetParent();

    local info = UIDropDownMenu_CreateInfo();
    info.text = tab.title;
    info.isTitle = true;
    info.notCheckable = true;
    info.justifyH = "CENTER";
    UIDropDownMenu_AddButton(info);

    info = UIDropDownMenu_CreateInfo();
    info.text = L.MOVE_TAB_LEFT;
    info.tooltipTitle = L.MOVE_TAB_LEFT
    info.tooltipText = L.TAB_LEFT_TOOLTIP;
    info.disabled = tab.position == 1;
    info.notCheckable = true;
    info.func = function() dock:MoveTab(tab, "left") end;
    UIDropDownMenu_AddButton(info);

    info = UIDropDownMenu_CreateInfo();
    info.text = L.MOVE_TAB_RIGHT;
    info.tooltipTitle = L.MOVE_TAB_RIGHT;
    info.tooltipText = L.TAB_RIGHT_TOOLTIP;
    info.disabled = tab.position == #dock.DOCKED_TABS;
    info.notCheckable = true;
    info.func = function() dock:MoveTab(tab, "right") end;
    UIDropDownMenu_AddButton(info);

    info = UIDropDownMenu_CreateInfo();
    info.text = "Hide Window";
    info.tooltipTitle = L.HIDE_BUTTON_TOOLTIP_TITLE;
    info.tooltipText = format(L.HIDE_BUTTON_TOOLTIP, tab.title);
    info.tooltipOnButton = true;
    info.disabled = #dock.DOCKED_TABS == 1;
    info.func = function()
        dock:HideTab(tab);
        dock:UpdateTabs();
    end
    info.notCheckable = true;
    UIDropDownMenu_AddButton(info);
end

function OverflowButton_UpdateList(list)
    ---@type Dock
    local dock = list:GetParent():GetParent();
    local info = UIDropDownMenu_CreateInfo();

    if #dock.HIDDEN_TABS > 0 then
        info.text = format(L.HIDDEN_WINDOW_COUNT, #dock.HIDDEN_TABS);
        info.isTitle = true
        info.notCheckable = true;
        UIDropDownMenu_AddButton(info);

        for i, tab in ipairs(dock.HIDDEN_TABS) do
            info = UIDropDownMenu_CreateInfo();
            info.text = tab.title;
            info.func = function() dock:ShowTab(tab) end;
            info.notCheckable = true;
            UIDropDownMenu_AddButton(info);
        end
    end

    if dock.hasOverflow then
        info.text = format(L.METER_WINDOW_COUNT, #dock.DOCKED_TABS);
        info.isTitle = true;
        info.notCheckable = true;
        UIDropDownMenu_AddButton(info);

        for i, tab in ipairs(dock.DOCKED_TABS) do
            info = UIDropDownMenu_CreateInfo();
            info.text = tab.title;
            info.func = function() dock:SelectTab(tab) end;
            info.notCheckable = true;
            UIDropDownMenu_AddButton(info);
        end
    end
end

local currentID = 0;
function GetNextTabID()
    currentID = currentID + 1;
    return currentID
end
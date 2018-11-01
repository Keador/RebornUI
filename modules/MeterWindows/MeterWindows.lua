---@type RebornUI
local rui = RebornUI;

---@class MeterWindows : Module
local MW = rui:NewModule("MeterWindows");

---@class MeterDock : ScrollFrame
---@field overflowButton OverflowButton
local DockMixin = {};

---@class DockingTab
local DockTabMixin = {};

---@type MeterWindowsProfileSettings
local PROFILE;
---@type MeterWindowsGlobalSettings
local GLOBAL;
---@type MeterWindowCharacterSettings
local CHAR;

---@type RebornUILocalization
local L = RebornUI.L;

local _G = _G;
local tinsert, tremove, tdelete, tindexof = tinsert, tremove, tDeleteItem, tIndexOf;
local min, max, abs, floor = min, max, abs, floor;
local format = format;

local EventHandler = rui:GetEventHandler();
local events = rui:GetEvents();

---@type MeterDock
local dock;
local SPACING;
local OverflowButton_UpdateList, TabDropDown_OnInitialize, GetNextTabID;
local newSkadaWindowFound;

local DOCKED_TABS = {};
local STORED_TABS = {};
local HIDDEN_TABS = {};
local embeds = {
    "Recount",
    "Skada",
    --"Details",
}

function MW:Initialize(...)
    SPACING = SPACING or rui:GetSpacing();
    PROFILE, GLOBAL, CHAR = ...;


    dock = CreateFrame("ScrollFrame", name, UIParent, "RebornUI_MeterDockTemplate");
    Mixin(dock, DockMixin);

    local oB = dock.overflowButton;
    oB.list:SetScript("OnShow", function(l) UIDropDownMenu_Initialize(l, OverflowButton_UpdateList, "Menu") end);

    UIDropDownMenu_Initialize(oB.list, OverflowButton_UpdateList, "Menu");
    UIDropDownMenu_SetAnchor(oB.list, 0, 0, "TOPRIGHT", oB, "TOPRIGHT");
end

function MW:ElvUIInitialized()
    local RightChatPanel = RightChatPanel;

    self:SetDockPosition(RightChatPanel);
    dock:Size(RightChatTab:GetSize());

    local function UpdateTabFont()
        MW:UpdateTabFonts();
    end
    rui:RegisterForFontAndColorChange(UpdateTabFont)
    dock:Show();

    self:SecureHookScript(RightChatPanel, "OnHide", function() dock:Hide() end);
    self:SecureHookScript(RightChatPanel, "OnShow", function() dock:Show() end);

    EventHandler:AddEvent(self, events.TabsSorted)

    for i = 1, #embeds do
        self[embeds[i].."_Load"](self);
        self[embeds[i].."Embedded"] = true;
    end
end

function MW:TabsSorted()
    if self.SkadaLoaded then
        local skadaWindows = _G.Skada:GetWindows();
        for i, win in ipairs(skadaWindows) do
            if not win.tab.isHidden then
                win.embedID = win.tab.position;
                PROFILE.positions[win.db.name] = win.tab.position;
            end
        end
    end
    if self.RecountLoaded then
        local win = Recount.MainWindow;
        win.embedID = win.tab.position;
    end
end

function MW:Skada_Load()
    if not rui.SkadaLoaded then return end

    local Skada = _G["Skada"];

    -- We hook into Skada:ApplySettings() to redesign the Skada windows.
    local function ApplySettings()
        for _, win in ipairs(Skada:GetWindows()) do
            MW:Skada_UpdateWindowSettings(win);
        end
    end
    self:SecureHook(Skada, "ApplySettings", ApplySettings);
    rui:RegisterForFontChange(ApplySettings);

    -- We hook into Skada:CreateWindow() so we know if a window is new.
    local function CreateWindow(sk, name, db)
        newSkadaWindowFound = not db and name or nil;
    end
    self:Hook(Skada, "CreateWindow", CreateWindow);

    -- We hook into Skada:DeleteWindow() so we know when a window is deleted
    local function DeleteWindow(sk, name)
        for _, win in ipairs(sk:GetWindows()) do
            if win.db.name == name then
                MW:UndockTab(win.tab, true);
                MW:SelectTab(1);
            end
        end
    end
    self:Hook(Skada, "DeleteWindow", DeleteWindow);
end

function MW:Skada_UpdateWindowSettings(win)
    local isNew = win.db.name == newSkadaWindowFound;

    if not win.tab or isNew then
        local tab = self:NewDockTab(win.db.name, PROFILE.positions[win.db.name]);
        win.embedID = tab.position;

        -- Locks the BarGroup from being resized.
        win.db.barslocked = true;
        win.bargroup:Lock();

        -- TODO 8/13/2018: Need to turn this back on when MeterWindows is disabled.
        -- Hides the title bar.
        win.db.enabletitle = false;
        win.bargroup:HideAnchor();

        win.bargroup:SetParent(tab.frame);
        win.frameLevel = tab.frame:GetFrameLevel() + 1;

        win.tab = tab;
    end

    win.bargroup:SetBackdrop(nil);
    win.bargroup.borderFrame:SetBackdrop(nil);
    win.bargroup:SetFrameLevel(win.frameLevel);

    win.bargroup:SetInside(win.tab.frame);
    win.bargroup:SetBarHeight((win.bargroup:GetHeight()) / PROFILE.visibleBars);
    win.bargroup:SetLength(win.bargroup:GetWidth());

    win.bargroup:SetFont(rui:GetChatFont(2));

    if isNew then
        self:SelectTab(win.tab);
        newSkadaWindowFound = nil;
    end
end

function MW:Recount_Load()
    if not rui.RecountLoaded then return end

    local Recount = _G.Recount;
    local mainWindow = Recount.MainWindow;

    local function AdjustPosition()
        mainWindow:SetInside(mainWindow.tab.frame);

        for i = 0, #mainWindow.Rows do
            local row = mainWindow.Rows[i];
            if row then
                if mainWindow.Rows[i - 1] then
                    row:Point("TOPLEFT", mainWindow.Rows[i - 1], "BOTTOMLEFT", 0, -Recount.db.profile.MainWindow.RowSpacing);
                else
                    row:Point("TOPLEFT", mainWindow.Title, "BOTTOMLEFT", 0, -Recount.db.profile.MainWindow.RowSpacing);
                end
            end
        end
        mainWindow:Show();
    end
    self:SecureHook(Recount, "ShowConfig", AdjustPosition);
    self:Hook(Recount, "ResizeMainWindow", AdjustPosition);

    if not mainWindow.tab then
        local tab = self:NewDockTab("Recount", PROFILE.positions["Recount"]);
        mainWindow.embedID = tab.position;
        mainWindow.tab = tab;
        mainWindow:SetParent(tab.frame);
        mainWindow.Title:SetPoint("TOPLEFT", tab.frame, "TOPLEFT", SPACING, -SPACING)
        mainWindow.CloseButton:SetPoint("TOPRIGHT", tab.frame, "TOPRIGHT", 0, 0)

        local frameStrata = mainWindow.tab.frame:GetFrameStrata();
        local frameLevel = mainWindow.tab.frame:GetFrameLevel() + 1;
        mainWindow.SetFrameLevel = nil;
        mainWindow.SetFrameLevel = function(f)
            if frameStrata ~= f:GetFrameStrata() then
                f:SetFrameStrata(frameStrata)
                f:SetFrameLevel(frameLevel);
            end
        end;

        Recount:LockWindows(true);
    end

    Recount.db.profile.MainWindow.RowHeight = (mainWindow.tab.frame:GetHeight() - 15) / PROFILE.visibleBars;
    --Recount.db.profile.MainWindowVis = true;

    Recount.Colors:SetColor("Window", "Title", { r = 0, g = 0, b = 0, a = 0 });
    Recount.Colors:SetColor("Window", "Background", { r = 0, g = 0, b = 0, a = 0 });

    Recount:ResizeMainWindow();
end

---@return DockingTab
function MW:NewDockTab(text, position)
    local handlers = { "OnClick" };
    ---@type DockingTab
    local tab;
    for i = 1, #STORED_TABS do
        tab = tremove(STORED_TABS, i);
        break ;
    end

    if not tab then
        local id = GetNextTabID();
        local tabName = "RebornUI_MeterTab" .. id;
        tab = CreateFrame("Button", tabName, dock, nil, id);
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
    MW:DockTab(tab);

    return tab;
end

---@param tab DockingTab
function MW:DockTab(tab)
    if tab.position then
        tinsert(DOCKED_TABS, tab.position, tab);
    else
        tinsert(DOCKED_TABS, tab);
    end
    tab.frame:SetAllPoints(dock.meterAnchor);
    self:UpdateTabs();
end

function MW:UndockTab(tab, permanent)
    tdelete(DOCKED_TABS, tab);

    EventHandler:FireEvent(events.TabsSorted);
    self:UpdateTabs();

    if permanent then
        tab.position = nil;
        tab:Store();
    end
end

function MW:HideTab(tab)
    tab.isHidden = true;
    self:UndockTab(tab);
    tab:Hide();
    tinsert(HIDDEN_TABS, tab);
    tab.hiddenID = #HIDDEN_TABS;
end

function MW:ShowTab(tab)
    tdelete(HIDDEN_TABS, tab);
    tab.isHidden = false;
    tab.hiddenID = nil;
    self:DockTab(tab);
end

function MW:SelectTab(tab)
    if type(tab) == "number" then tab = DOCKED_TABS[tab] end
    self:SetSelectedTab(tab);
    self:UpdateTabs();
end

function MW:SetSelectedTab(tab)
    dock.selected = tab;
end

function MW:GetSelectedTab()
    return dock.selected or DOCKED_TABS[1];
end

---@param tab DockingTab
function MW:MoveTab(tab, direction)
    PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON);
    self:UndockTab(tab);

    tab.position = tab.position + ((direction == "left" and -1) or (direction == "right" and 1) or 0);
    self:DockTab(tab);
    EventHandler:FireEvent(events.TabsSorted);
    self:SelectTab(tab);
end

function MW:SetDockPosition(anchor, forceUpdate)
    dock.anchor = dock.anchor or anchor;

    dock:ClearAllPoints();
    dock:Point("TOPLEFT", dock.anchor, "TOPLEFT", SPACING, -SPACING);
    dock:Point("TOPRIGHT", dock.anchor, "TOPRIGHT", -SPACING, -SPACING);

    dock.meterAnchor:Point("TOPLEFT", dock, "BOTTOMLEFT", SPACING / 3, -SPACING);
    if rui.ElvUI.db.datatexts.rightChatPanel then
        dock.meterAnchor:Point("BOTTOMRIGHT", dock.anchor, "BOTTOMRIGHT", -SPACING * 1.5, RightChatDataPanel:GetHeight() + (SPACING * 2));
    else
        dock.meterAnchor:Point("BOTTOMRIGHT", dock.anchor, "BOTTOMRIGHT", -SPACING * 1.5, SPACING * 1.5);
    end
end

function MW:ShowOverflowButton()
    local x = dock.overflowButton:GetWidth() + 2;

    dock.overflowButton:Point("TOPRIGHT", dock.anchor, "TOPRIGHT", -4, -7);
    dock:Point("TOPRIGHT", dock.anchor, "TOPRIGHT", -x, -2);

    dock.overflowButton:Show();
end

function MW:HideOverflowButton()
    self:SetDockPosition();
    dock.overflowButton:Hide();
end

function MW:UpdateTabs()
    local lastDockedTab, selectedTabIndex;
    local scrollChild = dock:GetScrollChild();

    local numFrames = 0;
    for i, tab in ipairs(DOCKED_TABS) do
        local frame = tab.frame;
        tab.position = tindexof(DOCKED_TABS, tab);
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

    for i = 1, #DOCKED_TABS do
        DOCKED_TABS[i]:Resize(0, tabSize);
    end

    if dock.hasOverflow or #HIDDEN_TABS > 0 then
        self:ShowOverflowButton();
    else
        self:HideOverflowButton();
    end

    dock.tabSize = tabSize;
    dock.numFrames = numFrames;
    dock.selectedTabIndex = selectedTabIndex;

    dock.isDirty = false;
    self:JumpToTab();
end

function MW:CalculateTabSize(numFrames)
    local MIN_SIZE, MAX_SIZE = 94, 104;
    local scrollSize = dock:GetWidth() + (dock.overflowButton:IsShown() and -dock.overflowButton.width or 0);

    if numFrames * MAX_SIZE < scrollSize then
        dock.hasOverflow = false;
        return MAX_SIZE;
    end

    if scrollSize / MIN_SIZE < numFrames then
        scrollSize = scrollSize - dock.overflowButton.width;
    end

    local numWholeTabs = min(floor(scrollSize / MIN_SIZE), numFrames);
    if scrollSize == 0 then
        dock.hasOverflow = numFrames > 0;
        return 1;
    end
    if numWholeTabs == 0 then
        return scrollSize, true;
    end

    local tabSize = scrollSize / numWholeTabs;
    dock.hasOverflow = numFrames > numWholeTabs;

    return tabSize;
end

function MW:JumpToTab(lt)
    -- Setting leftTab here may cause a problem in the future
    local leftTab = self:GetLeftMostTab();
    local numDisplayedTabs = floor(dock:GetWidth() / dock.tabSize);

    if dock.selectedTabIndex then
        if dock.selectedTabIndex >= leftTab + numDisplayedTabs then
            leftTab = dock.selectedTabIndex - numDisplayedTabs + 1;
        elseif dock.selectedTabIndex < leftTab then
            leftTab = dock.selectedTabIndex;
        end
    end

    leftTab = min(leftTab, dock.numFrames - numDisplayedTabs + 1);

    leftTab = max(leftTab, 1);

    dock:SetHorizontalScroll(dock.tabSize * (leftTab - 1));
    self:SetVisibleTabs(leftTab, self:GetRightMostTab(leftTab, numDisplayedTabs));

    -- TODO 7/30/2018: Overflow button pulse?
end

function MW:GetLeftMostTab()
    -- This needs to be a separate function if we want to add dragging tabs to different positions
    return floor((dock:GetHorizontalScroll() / dock.tabSize) + 0.5) + 1;
end

function MW:GetRightMostTab(leftTab, numDisplayedTabs)
    return floor(leftTab + numDisplayedTabs) - 1;
end

function MW:SetVisibleTabs(leftTab, rightTab)
    for i, tab in ipairs(DOCKED_TABS) do
        if tab.position < leftTab or tab.position > rightTab then
            tab:Hide();
        else
            tab:Show();
        end
    end
end

function MW:UpdateTabFonts()
    local r, g, b = rui:GetTabFontColor();
    local f, s, o = rui:GetTabFont();

    for i = 1, #DOCKED_TABS do
        local fs = DOCKED_TABS[i]:GetFontString();
        fs:FontTemplate(f, s, o);
        fs:SetTextColor(r, g, b);
    end
end

function DockTabMixin:OnClick(button)
    PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON);
    if button == "LeftButton" then
        if self == MW:GetSelectedTab() then return end
        MW:SelectTab(self);
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
    tinsert(STORED_TABS, self);
    self:Hide();
end

function TabDropDown_OnInitialize(dropDown)
    local tab = dropDown:GetParent();

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
    info.func = function() MW:MoveTab(tab, "left") end;
    UIDropDownMenu_AddButton(info);

    info = UIDropDownMenu_CreateInfo();
    info.text = L.MOVE_TAB_RIGHT;
    info.tooltipTitle = L.MOVE_TAB_RIGHT;
    info.tooltipText = L.TAB_RIGHT_TOOLTIP;
    info.disabled = tab.position == #DOCKED_TABS;
    info.notCheckable = true;
    info.func = function() MW:MoveTab(tab, "right") end;
    UIDropDownMenu_AddButton(info);

    info = UIDropDownMenu_CreateInfo();
    info.text = "Hide Window";
    info.tooltipTitle = L.HIDE_BUTTON_TOOLTIP_TITLE;
    info.tooltipText = format(L.HIDE_BUTTON_TOOLTIP, tab.title);
    info.tooltipOnButton = true;
    info.disabled = #DOCKED_TABS == 1;
    info.func = function()
        MW:HideTab(tab);
        MW:UpdateTabs();
    end
    info.notCheckable = true;
    UIDropDownMenu_AddButton(info);
end

function OverflowButton_UpdateList(list)
    local info = UIDropDownMenu_CreateInfo();

    if #HIDDEN_TABS > 0 then
        info.text = format(L.HIDDEN_WINDOW_COUNT, #HIDDEN_TABS);
        info.isTitle = true
        info.notCheckable = true;
        UIDropDownMenu_AddButton(info);

        for i, tab in ipairs(HIDDEN_TABS) do
            info = UIDropDownMenu_CreateInfo();
            info.text = tab.title;
            info.func = function() MW:ShowTab(tab) end;
            info.notCheckable = true;
            UIDropDownMenu_AddButton(info);
        end
    end

    if dock.hasOverflow then
        info.text = format(L.METER_WINDOW_COUNT, #DOCKED_TABS);
        info.isTitle = true;
        info.notCheckable = true;
        UIDropDownMenu_AddButton(info);

        for i, tab in ipairs(DOCKED_TABS) do
            info = UIDropDownMenu_CreateInfo();
            info.text = tab.title;
            info.func = function() MW:SelectTab(tab) end;
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

---@class MeterWindowsProfileSettings
local p = {
    enableSkada = true,
    enableRecount = true,
    enableDetails = true,
    visibleBars = 7,
    positions = {

    },
}

---@class MeterWindowsGlobalSettings
local g = {

}

---@class MeterWindowsCharacterSettings
local c = {

}

local function init(...) MW:Initialize(...) end
local function elvuiInit() MW:ElvUIInitialized() end
rui:RegisterModule(MW:GetName(), init, elvuiInit, p, g, c);
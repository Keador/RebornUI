---@type RebornUI
local R = RebornUI;
local L, CONSTANTS, profile, global, char = R:GetData();

---@class MeterWindows : Module
local MW = R:NewModule("MeterWindows");

local NewDockTab, UpdateTabs, UpdateTabFonts, DockTab, UndockTab, HideTab, ShowTab, SelectTab, SetSelectedTab, GetSelectedTab, MoveTab, ResizeTabs;
local SetDockPosition, ShowOverflowButton, HideOverflowButton;
local OverflowButton_UpdateList, TabDropDown_OnInitialize;
local CalculateTabSize, SetVisibleTabs, IterateDockedTabs, JumpToTab;

local _G = _G;
local tinsert, tremove, tdelete, tindexof = tinsert, tremove, tDeleteItem, tIndexOf;
local min, max, abs, floor = min, max, abs, floor;
local format = format;

---@type MeterDock
local dock;
local SPACING;
local newSkadaWindowFound;

local DOCKED_TABS = {};
local STORED_TABS = {};
local HIDDEN_TABS = {};
local embeds = {
    "Recount",
    "Skada",
    --"Details",
}
local loaded = {};

function MW:Initialize()
    SPACING = SPACING or R:GetSpacing();

    dock = CreateFrame("ScrollFrame", name, UIParent, "RebornUI_MeterDockTemplate");

    local oB = dock.overflowButton;
    oB.list:SetScript("OnShow", function(l) UIDropDownMenu_Initialize(l, OverflowButton_UpdateList, "Menu") end);

    UIDropDownMenu_Initialize(oB.list, OverflowButton_UpdateList, "Menu");
    UIDropDownMenu_SetAnchor(oB.list, 0, 0, "TOPRIGHT", oB, "TOPRIGHT");
end

function MW:ElvUIInitialized()
    local RightChatPanel = RightChatPanel;

    SetDockPosition(RightChatPanel);
    dock:Size(RightChatTab:GetSize());

    R:RegisterForFontAndColorChange(UpdateTabFonts)
    dock:Show();

    self:SecureHookScript(RightChatPanel, "OnHide", function() dock:Hide() end);
    self:SecureHookScript(RightChatPanel, "OnShow", function() dock:Show() end);

    for _, addon in ipairs(embeds) do
        if R:CheckDependency(addon) then
            self[addon .. "_Load"](self);
            self[addon .. "Embedded"] = true;
            loaded[addon] = true;
        end
    end
    UpdateTabs();
end

function MW:TabsSorted()
    if loaded['Skada'] then
        local skadaWindows = _G.Skada:GetWindows();
        for i, win in ipairs(skadaWindows) do
            if not win.tab.isHidden then
                win.embedID = win.tab.position;
                R.profile.meters.positions[win.db.name] = win.tab.position;
            end
        end
    end
    if loaded['Recount'] then
        local win = Recount.MainWindow;
        win.embedID = win.tab.position;
    end
end

function MW:Skada_Load()
    local Skada = _G["Skada"];

    -- We hook into Skada:ApplySettings() to redesign the Skada windows.
    local function ApplySettings()
        for _, win in ipairs(Skada:GetWindows()) do
            MW:Skada_UpdateWindowSettings(win);
        end
    end
    self:SecureHook(Skada, "ApplySettings", ApplySettings);
    R:RegisterForFontChange(ApplySettings);

    -- We hook into Skada:CreateWindow() so we know if a window is new.
    local function CreateWindow(sk, name, db)
        newSkadaWindowFound = not db and name or nil;
    end
    self:Hook(Skada, "CreateWindow", CreateWindow);

    -- We hook into Skada:DeleteWindow() so we know when a window is deleted
    local function DeleteWindow(sk, name)
        for _, win in ipairs(sk:GetWindows()) do
            if win.db.name == name then
                UndockTab(win.tab, true);
                SelectTab(1);
            end
        end
    end
    self:Hook(Skada, "DeleteWindow", DeleteWindow);
end

function MW:Skada_UpdateWindowSettings(win)
    local isNew = win.db.name == newSkadaWindowFound;

    if not win.tab or isNew then
        local tab = NewDockTab(win.db.name, R.profile.meters.positions[win.db.name]);
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
    win.bargroup:SetBarHeight((win.bargroup:GetHeight()) / R.profile.meters.visibleBars);
    win.bargroup:SetLength(win.bargroup:GetWidth());

    win.bargroup:SetFont(R:GetChatFont(2));

    if isNew then
        SelectTab(win.tab);
        newSkadaWindowFound = nil;
    end
end

function MW:Recount_Load()
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
        local tab = NewDockTab("Recount", R.profile.meters.positions["Recount"]);
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

    Recount.db.profile.MainWindow.RowHeight = (mainWindow.tab.frame:GetHeight() - 15) / R.profile.meters.visibleBars;

    Recount.Colors:SetColor("Window", "Title", { r = 0, g = 0, b = 0, a = 0 });
    Recount.Colors:SetColor("Window", "Background", { r = 0, g = 0, b = 0, a = 0 });

    Recount:ResizeMainWindow();
end

function NewDockTab(text, position)
    local tab;
    for i = 1, #STORED_TABS do
        tab = tremove(STORED_TABS, i);
        break ;
    end
    tab = tab or CreateFrame("Button", nil, dock, "RebornUI_MeterDockTabTemplate");

    tab.position = position;
    tab.title = text;
    tab:SetText(text);
    UIDropDownMenu_Initialize(tab.dropDown, TabDropDown_OnInitialize, "MENU");

    DockTab(tab);

    return tab;
end

---@param tab DockingTab
function DockTab(tab)
    if tab.position then
        tinsert(DOCKED_TABS, tab.position, tab);
    else
        tinsert(DOCKED_TABS, tab);
    end
    tab.frame:SetAllPoints(dock.meterAnchor);
    UpdateTabs();
end

function UndockTab(tab, permanent)
    tdelete(DOCKED_TABS, tab);

    MW:TabsSorted();
    UpdateTabs();

    if permanent then
        tab.position = nil;
        tinsert(STORED_TABS, tab);
        tab:Hide();
    end
end

function HideTab(tab)
    tab.isHidden = true;
    tab:Hide();
    UndockTab(tab);
    tinsert(HIDDEN_TABS, tab);
    tab.hiddenID = #HIDDEN_TABS;
end

function ShowTab(tab)
    tdelete(HIDDEN_TABS, tab);
    tab.isHidden = false;
    tab.hiddenID = nil;
    DockTab(tab);
end

function SelectTab(tab)
    if type(tab) == "number" then tab = DOCKED_TABS[tab] end
    SetSelectedTab(tab);
    UpdateTabs();
end

function SetSelectedTab(tab)
    dock.selected = tab;
end

function GetSelectedTab()
    return dock.selected or DOCKED_TABS[1];
end

---@param tab DockingTab
function MoveTab(tab, direction)
    PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON);
    UndockTab(tab);

    tab.position = tab.position + ((direction == "left" and -1) or (direction == "right" and 1) or 0);
    DockTab(tab);
    MW:TabsSorted();
    SelectTab(tab);
end

function SetDockPosition(anchor, forceUpdate)
    dock.anchor = dock.anchor or anchor;

    dock:ClearAllPoints();
    dock:Point("TOPLEFT", dock.anchor, "TOPLEFT", SPACING, -SPACING);
    dock:Point("TOPRIGHT", dock.anchor, "TOPRIGHT", -SPACING, -SPACING);

    dock.meterAnchor:Point("TOPLEFT", dock, "BOTTOMLEFT", SPACING / 3, -SPACING);
    if R.ElvUI.db.datatexts.rightChatPanel then
        dock.meterAnchor:Point("BOTTOMRIGHT", dock.anchor, "BOTTOMRIGHT", -SPACING * 1.5, RightChatDataPanel:GetHeight() + (SPACING * 2));
    else
        dock.meterAnchor:Point("BOTTOMRIGHT", dock.anchor, "BOTTOMRIGHT", -SPACING * 1.5, SPACING * 1.5);
    end
end

function ShowOverflowButton()
    local x = dock.overflowButton:GetWidth() + 2;

    dock.overflowButton:Point("TOPRIGHT", dock.anchor, "TOPRIGHT", -4, -7);
    dock:Point("TOPRIGHT", dock.anchor, "TOPRIGHT", -x, -2);

    dock.overflowButton:Show();
end

function HideOverflowButton()
    SetDockPosition();
    dock.overflowButton:Hide();
end

function IterateDockedTabs()
    return ipairs(DOCKED_TABS)
end

function CalculateTabSize(numFrames)
    local MIN_SIZE, MAX_SIZE = 80, 110;
    local scrollSize = dock:GetWidth() + (dock.overflowButton:IsShown() and dock.overflowButton.width or 0);

    if numFrames * MAX_SIZE < scrollSize then
        return false, scrollSize / numFrames;
    end

    if scrollSize / MIN_SIZE < numFrames then
        scrollSize = scrollSize - dock.overflowButton.width;
    end

    local numWholeTabs = min(floor(scrollSize / MIN_SIZE), numFrames);
    if scrollSize == 0 then
        return numFrames > 0, 1;
    end
    if numWholeTabs == 0 then
        return true, scrollSize;
    end

    return numFrames > numWholeTabs, scrollSize / numWholeTabs;
end

function SetVisibleTabs(leftTab, rightTab)
    for i, tab in IterateDockedTabs() do
        if tab.position < leftTab or tab.position > rightTab then
            tab:Hide();
        else
            tab:Show();
        end
    end
end

function JumpToTab()
    local numDisplayedTabs = floor(dock:GetWidth() / dock.tabSize);
    -- Setting leftTab here may cause a problem in the future
    local leftTab = floor((dock:GetHorizontalScroll() / dock.tabSize) + 0.5) + 1;

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

    local rightTab = floor(leftTab + numDisplayedTabs + 0.5) - 1;
    SetVisibleTabs(leftTab, rightTab);
end

function ResizeTabs(padding, tabSize)
    for i, tab in IterateDockedTabs() do
        local fs = tab:GetFontString();
        fs:Width(tabSize - padding);
        tab:Width(tabSize);
    end
end

function UpdateTabs()
    local lastDockedTab, selectedTabIndex;

    local numFrames = 0;
    for i, tab in IterateDockedTabs() do
        local frame = tab.frame;
        tab.position = tindexof(DOCKED_TABS, tab);
        numFrames = numFrames + 1;
        if GetSelectedTab() == tab then
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
            tab:Point("LEFT", dock.scrollChild, "LEFT");
        end
        lastDockedTab = tab;
    end

    UpdateTabFonts();

    local hasOverflow, tabSize = CalculateTabSize(numFrames);

    ResizeTabs(10, tabSize);

    if hasOverflow or #HIDDEN_TABS > 0 then
        ShowOverflowButton();
    else
        HideOverflowButton();
    end

    dock.tabSize = tabSize;
    dock.numFrames = numFrames;
    dock.selectedTabIndex = selectedTabIndex;
    dock.hasOverflow = hasOverflow;

    dock.isDirty = false;
    JumpToTab();
end

function UpdateTabFonts()
    local r, g, b = R:GetTabFontColor();
    local f, s, o = R:GetTabFont();

    for _, tab in IterateDockedTabs() do
        local fs = tab:GetFontString();
        fs:FontTemplate(f, s, o);
        fs:SetTextColor(r, g, b);
    end
end

function RebornUI_MeterDockTabOnClick(tab, button)
    PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON);
    if button == "LeftButton" then
        if tab == GetSelectedTab() then return end
        SelectTab(tab);
        return ;
    end
    if button == "RightButton" then
        ToggleDropDownMenu(1, nil, tab.dropDown);
    end
end

function TabDropDown_OnInitialize(dropDown)
    local tab = dropDown:GetParent();

    local info = UIDropDownMenu_CreateInfo();
    info.text = tab.title;
    info.isTitle = true;
    info.notCheckable = true;
    info.justifyH = "CENTER";
    UIDropDownMenu_AddButton(info);

    -- TODO 11/5/2018: Disabled moving tabs until we can figure out how to do it effectively.
    info = UIDropDownMenu_CreateInfo();
    info.text = L.MOVE_TAB_LEFT;
    info.tooltipTitle = L.MOVE_TAB_LEFT
    info.tooltipText = L.TAB_LEFT_TOOLTIP;
    info.disabled = true;-- tab.position == 1;
    info.notCheckable = true;
    info.func = function() MoveTab(tab, "left") end;
    UIDropDownMenu_AddButton(info);

    info = UIDropDownMenu_CreateInfo();
    info.text = L.MOVE_TAB_RIGHT;
    info.tooltipTitle = L.MOVE_TAB_RIGHT;
    info.tooltipText = L.TAB_RIGHT_TOOLTIP;
    info.disabled = true;-- tab.position == #DOCKED_TABS;
    info.notCheckable = true;
    info.func = function() MoveTab(tab, "right") end;
    UIDropDownMenu_AddButton(info);

    info = UIDropDownMenu_CreateInfo();
    info.text = "Hide Window";
    info.tooltipTitle = L.HIDE_BUTTON_TOOLTIP_TITLE;
    info.tooltipText = format(L.HIDE_BUTTON_TOOLTIP, tab.title);
    info.tooltipOnButton = true;
    info.disabled = #DOCKED_TABS == 1;
    info.func = function()
        HideTab(tab);
        UpdateTabs();
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
            info.func = function() ShowTab(tab) end;
            info.notCheckable = true;
            UIDropDownMenu_AddButton(info);
        end
    end

    if dock.hasOverflow then
        info = UIDropDownMenu_CreateInfo();
        info.text = format(L.METER_WINDOW_COUNT, #DOCKED_TABS);
        info.isTitle = true;
        info.notCheckable = true;
        UIDropDownMenu_AddButton(info);

        for i, tab in ipairs(DOCKED_TABS) do
            info = UIDropDownMenu_CreateInfo();
            info.text = tab.title;
            info.func = function() SelectTab(tab) end;
            info.notCheckable = true;
            UIDropDownMenu_AddButton(info);
        end
    end
end

profile.meters = {
    enableSkada = true,
    enableRecount = true,
    enableDetails = true,
    visibleBars = 7,
    positions = {

    },
}

R:RegisterModule(MW, function() MW:Initialize() end, function() MW:ElvUIInitialized() end);
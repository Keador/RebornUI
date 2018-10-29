---@type RebornUI
local rui = RebornUI;

---@class MeterWindows : Module
local MeterWindows = rui:CreateModule("MeterWindows");

---@class MeterDock : ScrollFrame
---@field overflowButton OverflowButton
local DockMixin = {};
DockMixin.DOCKED_TABS = {};
DockMixin.STORED_TABS = {};
DockMixin.HIDDEN_TABS = {};

---@class DockingTab
local DockTabMixin = {};

---@type Design
local design = rui:GetModule("Design");
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
local embeds = {
    "Recount",
    "Skada",
    --"Details",
}

function MeterWindows:PostInitialization()
    EventHandler:RemoveEvent(self, events.PostInitialization);

    EventHandler:AddEvent(self, events.Enable);
    EventHandler:AddEvent(self, events.ElvUIInitialized);
    EventHandler:AddEvent(self, events.ElvUINotFound);
end

function MeterWindows:OnInitialize()
    SPACING = SPACING or design:GetSpacing();

    dock = CreateFrame("ScrollFrame", name, UIParent, "RebornUI_MeterDockTemplate");
    Mixin(dock, DockMixin);

    dock:SetupOverflowDropDownMenu();
end

function MeterWindows:ElvUINotFound()

end

function MeterWindows:ElvUIInitialized()
    local RightChatPanel = RightChatPanel;

    dock:SetPosition(RightChatPanel);
    dock:Size(RightChatTab:GetSize());

    local function UpdateTabFont()
        dock:UpdateTabFonts();
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

function MeterWindows:TabsSorted()
    if self.SkadaLoaded then
        local skadaWindows = _G.Skada:GetWindows();
        for i, win in ipairs(skadaWindows) do
            if not win.tab.isHidden then
                win.embedID = win.tab.position;
                self.SV.positions[win.db.name] = win.tab.position;
            end
        end
    end
    if self.RecountLoaded then
        local win = Recount.MainWindow;
        win.embedID = win.tab.position;
    end
end

function MeterWindows:Skada_Load()
    if not rui.SkadaLoaded then return end

    local Skada = _G["Skada"];

    -- We hook into Skada:ApplySettings() to redesign the Skada windows.
    local function ApplySettings()
        for _, win in ipairs(Skada:GetWindows()) do
            MeterWindows:Skada_UpdateWindowSettings(win);
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
        for _, win in pairs(sk:GetWindows()) do
            if win.db.name == name then
                dock:UndockTab(win.tab, true);
                dock:SelectTab(1);
            end
        end
    end
    self:Hook(Skada, "DeleteWindow", DeleteWindow);
end

function MeterWindows:Skada_UpdateWindowSettings(win)
    local isNew = win.db.name == newSkadaWindowFound;

    if not win.tab or isNew then
        local tab = dock:NewTab(win.db.name, MeterWindows.SV.positions[win.db.name]);
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
    win.bargroup:SetBarHeight((win.bargroup:GetHeight()) / MeterWindows.SV.visibleBars);
    win.bargroup:SetLength(win.bargroup:GetWidth());

    win.bargroup:SetFont(design:GetChatFont(2));

    if isNew then
        dock:SelectTab(win.tab);
        newSkadaWindowFound = nil;
    end
end

function MeterWindows:Recount_Load()
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
        local tab = dock:NewTab("Recount", self.SV.positions["Recount"]);
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

    Recount.db.profile.MainWindow.RowHeight = (mainWindow.tab.frame:GetHeight() - 15) / self.SV.visibleBars;
    --Recount.db.profile.MainWindowVis = true;

    Recount.Colors:SetColor("Window", "Title", { r = 0, g = 0, b = 0, a = 0 });
    Recount.Colors:SetColor("Window", "Background", { r = 0, g = 0, b = 0, a = 0 });

    Recount:ResizeMainWindow();
end

function DockMixin:SetupOverflowDropDownMenu()
    ---@class OverflowButton : Button
    ---@field list Frame
    ---@field width number
    local oB = self.overflowButton;
    oB.list:SetScript("OnShow", function(l) UIDropDownMenu_Initialize(l, OverflowButton_UpdateList, "Menu") end);

    UIDropDownMenu_Initialize(oB.list, OverflowButton_UpdateList, "Menu");
    UIDropDownMenu_SetAnchor(oB.list, 0, 0, "TOPRIGHT", oB, "BOTTOMRIGHT");
end

---@return DockingTab
function DockMixin:NewTab(text, position)
    local handlers = { "OnClick" };
    ---@type DockingTab
    local tab;
    for i = 1, #self.STORED_TABS do
        tab = tremove(self.STORED_TABS, i);
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
        tinsert(self.DOCKED_TABS, tab.position, tab);
    else
        tinsert(self.DOCKED_TABS, tab);
    end
    tab.frame:SetAllPoints(self.meterAnchor);
    self:UpdateTabs();
end

function DockMixin:UndockTab(tab, permanent)
    tdelete(self.DOCKED_TABS, tab);

    EventHandler:FireEvent(events.TabsSorted);
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
    tinsert(self.HIDDEN_TABS, tab);
    tab.hiddenID = #self.HIDDEN_TABS;
end

function DockMixin:ShowTab(tab)
    tdelete(self.HIDDEN_TABS, tab);
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
    EventHandler:FireEvent(events.TabsSorted);
    self:SelectTab(tab);
end

function DockMixin:SetPosition(anchor, forceUpdate)
    self.anchor = self.anchor or anchor;

    self:ClearAllPoints();
    self:Point("TOPLEFT", self.anchor, "TOPLEFT", SPACING, -SPACING);
    self:Point("TOPRIGHT", self.anchor, "TOPRIGHT", -SPACING, -SPACING);

    self.meterAnchor:Point("TOPLEFT", self, "BOTTOMLEFT", SPACING / 3, -SPACING);
    if design.ElvUI.db.datatexts.rightChatPanel then
        self.meterAnchor:Point("BOTTOMRIGHT", self.anchor, "BOTTOMRIGHT", -SPACING * 1.5, RightChatDataPanel:GetHeight() + (SPACING * 2));
    else
        self.meterAnchor:Point("BOTTOMRIGHT", self.anchor, "BOTTOMRIGHT", -SPACING * 1.5, SPACING * 1.5);
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
        tab.position = tindexof(self.DOCKED_TABS, tab);
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
    local r, g, b = design:GetTabFontColor();
    local f, s, o = design:GetTabFont();

    for i = 1, #self.DOCKED_TABS do
        local fs = self.DOCKED_TABS[i]:GetFontString();
        fs:FontTemplate(f, s, o);
        fs:SetTextColor(r, g, b);
    end
end

function DockTabMixin:OnClick(button)
    PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON);
    if button == "LeftButton" then
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
    tinsert(self:GetParent().STORED_TABS, self);
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


---@type RebornUI
local _, RebornUI = ...;
---@type Design
local design = RebornUI:GetModule("Design");

---@type EventSystem
local EventSystem = RebornUI:GetEventSystem();
---@type RebornUIEvents
local events = RebornUI:GetEvents();

local insert, remove = tinsert, tremove;
local min, max, abs, floor = min, max, abs, floor;

---@type DockManager
local mixin = {};

local TAB_HEIGHT = 22;
local SPACING;

---NewDockManager
---@param name string global name for the dock manager
---@param type string type of dock manager NYI
---@param parent Frame
---@return DockManager
function design:NewDockManager(name, listHeaderFormat, type, parent)
    ---@type DockManager
    local rtn = CreateFrame("ScrollFrame", name, parent or UIParent, "RebornUI_DockManagerTemplate");
    Mixin(rtn, mixin);

    insert(self.DOCK_MANAGERS, rtn);
    rtn.dockedTabs = {};

    rtn.overflowButton:SetScript("OnClick",
            function(button)
                PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON);
                if button.list:IsShown() then
                    button.list:Hide();
                else
                    rtn:UpdateOverflowList(button.list);
                    button.list:Show();
                end
            end
    );
    if self.ElvUI then
        rtn.overflowButton.list:AddBackdrop();
    end

    SPACING = SPACING or self:GetSpacing();
    rtn.listHeaderFormat = listHeaderFormat;
    return rtn;
end

---UpdateOverflowList
---@param list OverflowList
function mixin:UpdateOverflowList(list)
    local totalHeight = 25;

    list.numTabs:SetFormattedText(self.listHeaderFormat, #self.dockedTabs);

    for i, tab in ipairs(self.dockedTabs) do

        local button = list.buttons[i];
        if not button then
            list.buttons[i] = CreateFrame("Button", nil, list, "RebornUI_OverflowListButtonTemplate");
            button = list.buttons[i];
            button:SetScript("OnClick", function() self:SelectTab(tab.dockID) end);
            button.text:FontTemplate(design:GetChatFont());

            if not list.buttons[i - 1] then
                button:Point("TOPLEFT", list, "TOPLEFT", 5, -19);
            else
                button:Point("TOPLEFT", list.buttons[i - 1], "BOTTOMLEFT", 0, -3);
            end

            button:Width(list:GetWidth() - 10);
        end

        button.text:SetText(tab.title);
        button:Height(button:GetTextHeight());

        totalHeight = totalHeight + button:GetHeight() + 3;
    end
    list:Height(totalHeight);

    for i = #self.dockedTabs + 1, #list.buttons do
        list.buttons[i]:Hide();
    end
end
---DockTab
---@param tab DockingTab
function mixin:DockTab(tab)
    if tab.dockID then return end

    insert(self.dockedTabs, tab);
    tab.dockID = #self.dockedTabs;
    tab:SetFrameSize(self, self.anchor);

    self.isDirty = true;
    self:UpdateTabs();
end

function mixin:UndockTab(id)
    ---@type DockingTab
    local removedTab = remove(self.dockedTabs, id);
    removedTab.dockID = nil;
    removedTab:Store();

    for i, tab in ipairs(self.dockedTabs) do
        tab.dockID = i;
    end
    EventSystem:FireEvent(events.TabsSorted);

    self.isDirty = true;
    self:UpdateTabs();
end

function mixin:SelectTab(id)
    self.selectedTab = id;
    self.isDirty = true;

    self.overflowButton.list:Hide();
    self:UpdateTabs();
end

function mixin:SetPosition(anchor, forceUpdate)
    self.anchor = self.anchor or anchor;

    self:ClearAllPoints();

    self:Point("BOTTOMLEFT", self.anchor, "TOPLEFT", SPACING, -(SPACING + TAB_HEIGHT));
    self:Point("TOPRIGHT", self.anchor, "TOPRIGHT", -SPACING, -SPACING);
end

function mixin:ShowOverflowButton()
    local x = self.overflowButton:GetWidth() + 2;

    self.overflowButton:Point("TOPRIGHT", self.anchor, "TOPRIGHT", -4, -7);
    self:Point("TOPRIGHT", self.anchor, "TOPRIGHT", -x, -2);

    self.overflowButton:Show();
end

function mixin:HideOverflowButton()
    self:SetPosition();
    self.overflowButton:Hide();
end

---@private
function mixin:UpdateTabs(forceUpdate)
    if not self.isDirty and not forceUpdate then return end

    local lastDockedTab, selectedTabIndex;
    local scrollChild = self:GetScrollChild();

    local numFrames = 0;
    for i, tab in ipairs(self.dockedTabs) do
        local frame = tab.frame;
        selectedTabIndex = self.selectedTab and self.selectedTab or 1;

        --RebornUI:Print("SelectedTab -", self.selectedTab);
        if selectedTabIndex == tab.dockID then
            frame:Show();
            tab:SetAlpha(1.0);
        else
            frame:Hide();
            tab:SetAlpha(0.6);
        end
        self:UpdateTabFont();

        tab:ClearAllPoints();
        tab:Show();

        -- tab:SetParent(scrollChild);
        numFrames = numFrames + 1;

        if lastDockedTab then
            tab:Point("LEFT", lastDockedTab, "RIGHT");
        else
            tab:Point("LEFT", scrollChild, "LEFT");
        end
        lastDockedTab = tab;
    end

    local tabSize, overflow = self:CalculateTabSize(numFrames);

    for i = 1, #self.dockedTabs do
        self.dockedTabs[i]:Resize(0, tabSize);
    end

    if overflow then
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

function mixin:CalculateTabSize(numFrames)
    local MIN_SIZE, MAX_SIZE = 94, 104;
    local oButtonSize = self.overflowButton:IsShown() and -self.overflowButton.width  or 0;
    local scrollSize = self:GetWidth() + oButtonSize;

    if numFrames * MAX_SIZE < scrollSize then
        return MAX_SIZE, false;
    end

    if scrollSize / MIN_SIZE < numFrames then
        scrollSize = scrollSize - self.overflowButton.width;
    end

    local numWholeTabs = min(floor(scrollSize / MIN_SIZE), numFrames);
    if scrollSize == 0 then
        return 1, numFrames > 0;
    end
    if numWholeTabs == 0 then
        return scrollSize, true;
    end

    local tabSize = scrollSize / numWholeTabs;
    return tabSize, numFrames > numWholeTabs;
end

---JumpToTab
---@param lt number this is here as a place holder for leftTab
function mixin:JumpToTab(lt)
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

function mixin:GetLeftMostTab()
    -- This needs to be a separate function if we want to add dragging tabs to different positions
    return floor((self:GetHorizontalScroll() / self.tabSize) + 0.5) + 1;
end

function mixin:GetRightMostTab(leftTab, numDisplayedTabs)
    return floor(leftTab + numDisplayedTabs) - 1;
end

function mixin:SetVisibleTabs(leftTab, rightTab)
    for i, tab in ipairs(self.dockedTabs) do
        if tab.dockID < leftTab or tab.dockID > rightTab then
            tab:Hide();
        else
            tab:Show();
        end
    end
end

---UpdateTabFont
---@param tab DockingTab
function mixin:UpdateTabFont(tab)
    if tab then
        tab.text:SetTextColor(design:GetTabFontColor());
        tab.text:FontTemplate(design:GetTabFont());
        tab.text.isSkinned = true;
    else
        for i, frame in ipairs(self.dockedTabs) do
            self:UpdateTabFont(frame);
        end
    end
end

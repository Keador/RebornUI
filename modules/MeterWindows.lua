---@type RebornUI
local _, RebornUI = ...;

---@type MeterWindows
local MeterWindows = RebornUI:LoadModule("MeterWindows");
local EventSystem = RebornUI:GetEventSystem();
local events = RebornUI:GetEvents();
---@type Design
local design = RebornUI:GetModule("Design");
---@type RebornUILocalization
local L = RebornUI.L;

---@type DockManager
local dockManager;

local SPACING;

function MeterWindows:PostInitialization()
    EventSystem:RemoveEvent(self, events.PostInitialization);

    EventSystem:AddEvent(self, events.Enable);
    EventSystem:AddEvent(self, events.ElvUIInitialized);
    EventSystem:AddEvent(self, events.ElvUINotFound);
end

function MeterWindows:Enable()
    dockManager = design:NewDockManager("RebornUI_Dock", L.METER_WINDOW_COUNT);

    if self.ElvUI then
        -- Hook into ElvUI's value color update system
        local function UpdateFonts(_, r, g, b)
            EventSystem:FireEvent(events.FontsChanged);
        end
        self.ElvUI['valueColorUpdateFuncs'][UpdateFonts] = true;

        -- Hook SetupChat() so we know when chat fonts are changed
        self:SecureHook(self.ElvUI:GetModule("Chat"), "SetupChat", UpdateFonts);
    end

    SPACING = SPACING or design:GetSpacing();
end

---CreateWindow
---@param name string
---@param showFunc fun() callback when window is shown
---@param hideFunc fun() callback when window is hidden
---@return DockingTab
function MeterWindows:CreateWindow(name)
    local tab = design:NewDockingTab(dockManager, name);
    dockManager:DockTab(tab);

    return tab;
end

function MeterWindows:ElvUINotFound()

end

local function CreateWindow(skada, name, db)
    if not db then
        MeterWindows.hasNewWindow = name;
    end
end

function MeterWindows:ElvUIInitialized()
    local RightChatPanel = RightChatPanel;
    dockManager:Size(RightChatTab:GetSize());
    dockManager:SetPosition(RightChatPanel);
    dockManager:Show();

    EventSystem:AddEvent(self, events.FontsChanged);
    -- TODO 8/13/2018: Add hook for size change?

    self:SecureHookScript(RightChatPanel, "OnHide", function() dockManager:Hide() end);
    self:SecureHookScript(RightChatPanel, "OnShow", function() dockManager:Show() end);

    EventSystem:AddEvent(self, events.TabsSorted)
    if IsAddOnLoaded("Skada") then
        self:LoadSkada();
        self.skadaLoaded = true;
    end

    if IsAddOnLoaded("Recount") then
        self:LoadRecount();
    end
end

function MeterWindows:TabsSorted()
    if self.skadaLoaded then
        local skadaWindows = _G.Skada:GetWindows();
        for i, win in ipairs(skadaWindows) do
            win.embedID = win.tab.dockID;
        end
    end
end

function MeterWindows:LoadSkada()
    --[===[@debug@
    RebornUI:Print("LoadSkada");
    --@end-debug@]===]
    local Skada = _G.Skada;
    self:SecureHook(Skada, "ApplySettings", "Skada_ApplySettings");
    self:Hook(Skada, "CreateWindow", CreateWindow);
    self:Hook(Skada, "DeleteWindow", "DeleteWindow_Skada");
end

function MeterWindows:Skada_ApplySettings(Skada)

    for _, win in ipairs(Skada:GetWindows()) do
        local isNew = win.db.name == self.hasNewWindow;
        --[===[@debug@
        RebornUI:Print(isNew);
        --@end-debug@]===]
        if not win.tab or isNew then
            local tab = self:CreateWindow(win.db.name);
            win.embedID = tab.dockID;

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
        win.bargroup:SetBarHeight((win.bargroup:GetHeight()) / self.SV.visibleBars);
        win.bargroup:SetLength(win.bargroup:GetWidth());

        win.bargroup:SetFont(design:GetChatFont(2));

        if isNew then
            dockManager:SelectTab(win.tab.dockID);
            self.hasNewWindow = nil;
        end
    end
end

function MeterWindows:DeleteWindow_Skada(Skada, name)
    for _, win in pairs(Skada:GetWindows()) do
        if win.db.name == name then
            dockManager:UndockTab(win.tab.dockID);
        end
    end
end

function MeterWindows:LoadRecount()
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
        local tab = self:CreateWindow("Recount");
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

    Recount.db.profile.MainWindow.RowHeight = (mainWindow.tab.height - 15) / self.SV.visibleBars;
    --Recount.db.profile.MainWindowVis = true;

    Recount.Colors:SetColor("Window", "Title", { r = 0, g = 0, b = 0, a = 0 });
    Recount.Colors:SetColor("Window", "Background", { r = 0, g = 0, b = 0, a = 0 });

    Recount:ResizeMainWindow();
end

function MeterWindows:FontsChanged()
    dockManager:UpdateTabFont();
    self:Skada_ApplySettings(_G.Skada);
end

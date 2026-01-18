if select(2,UnitClass("player")) ~= "SHAMAN" then return end

local L = LibStub("AceLocale-3.0"):GetLocale("TotemTimers", true)

local buttonlocations = {
	{"BOTTOM", "TOP"},
	{"BOTTOMLEFT", "TOPRIGHT"},
	{"LEFT", "RIGHT"},
	{"TOPLEFT", "BOTTOMRIGHT"},
	{"TOP", "BOTTOM"},
	{"TOPRIGHT", "BOTTOMLEFT"},
	{"RIGHT", "LEFT"},
	{"BOTTOMRIGHT", "TOPLEFT"},
}

function TotemTimers.InitSetButtons()
    local ankh = TotemTimers.AnkhTracker.button
    ankh:SetScript("OnClick", TotemTimers.SetAnchor_OnClick)
    TotemTimers.ProgramSetButtons()
    ankh:WrapScript(XiTimers.timers[5].button, "OnClick",
                                                            [[ if button == "LeftButton" then
                                                                control:ChildUpdate("toggle")
                                                            end ]])

    ankh.tooltip = TotemTimers.Tooltips.SetAnchor:new(ankh)
    ankh:SetAttribute("_onattributechanged", [[ if name=="hide" then
                                                    control:ChildUpdate("show", false)
                                                    self:SetAttribute("open", false)
                                                elseif name=="state-invehicle" then
                                                    if value == "show" and self:GetAttribute("active") then
                                                        self:Show()
                                                    else
                                                        self:Hide()
                                                    end
                                                end]])
end


local NameToSpellID = TotemTimers.NameToSpellID

-- Helper function to normalize spell values (handles string-encoded numbers from saved data)
local function NormalizeSpellValue(value)
    if value == nil then return nil end
    if type(value) == "string" then
        local num = tonumber(value)
        if num then return num end
    end
    return value
end

-- Helper function to check if a spell value is valid (number > 0 or non-empty string)
local function IsValidSpellValue(value)
    if value == nil then return false end
    local normalized = NormalizeSpellValue(value)
    if type(normalized) == "number" then
        return normalized > 0
    elseif type(normalized) == "string" then
        return normalized ~= ""
    end
    return false
end

function TotemTimers.ProgramSetButtons()
    -- Ensure TotemSets exists and is a table
    if not TotemTimers.ActiveProfile.TotemSets or type(TotemTimers.ActiveProfile.TotemSets) ~= "table" then
        TotemTimers.ActiveProfile.TotemSets = {}
    end
    local Sets = TotemTimers.ActiveProfile.TotemSets
	local nr = 0
	for i=1,8 do
        local b = _G["TotemTimers_SetButton"..i]
        if not b then
            b = CreateFrame("Button", "TotemTimers_SetButton"..i, XiTimers.timers[5].button, "TotemTimers_SetButtonTemplate")
            b:SetAttribute("_childupdate-show", [[ if message and not self:GetAttribute("inactive") then self:Show() else self:Hide() end ]])
            b:SetAttribute("_childupdate-toggle", [[ if not self:GetAttribute("inactive") then if self:IsVisible() then self:Hide() else self:Show() end end ]])
            b.nr = i

            b.tooltip = TotemTimers.Tooltips.SetButton:new(b)
            XiTimers.HookTooltips(b)
            b:SetAttribute("tooltip", true)

            b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            b:SetParent(XiTimers.timers[5].button)
        end
        b:ClearAllPoints()
        b:SetPoint(buttonlocations[i][1], XiTimers.timers[5].button, buttonlocations[i][2])

        if Sets[i] then
            for k = 1,4 do
                if Sets[i][k] then
                    local _, _, texture = GetSpellInfo(Sets[i][k])
                    if texture then
                        _G[b:GetName().."Icon"..k]:SetTexture(texture)
                    end
                end
            end
            b:SetAttribute("inactive", false)            
        else
            b:SetAttribute("inactive", true)
            b:Hide()
        end
	end
end

function TotemTimers.SetAnchor_OnClick(self, button)
    if InCombatLockdown() then return end
	if button == "RightButton" then
        -- Ensure TotemSets exists and is a table
        if not TotemTimers.ActiveProfile.TotemSets or type(TotemTimers.ActiveProfile.TotemSets) ~= "table" then
            TotemTimers.ActiveProfile.TotemSets = {}
        end
		if #TotemTimers.ActiveProfile.TotemSets >= 8 then return end
        local set = {}
		for i=1,4 do
            local nr = XiTimers.timers[i].nr
            local spell = XiTimers.timers[i].button:GetAttribute("*spell1")
            spell = TotemTimers.GetBaseSpellID(spell)
            if not spell then spell = 0 end
			set[nr] = spell
		end
        table.insert(TotemTimers.ActiveProfile.TotemSets, set)
		TotemTimers.ProgramSetButtons()
    end
end

function TotemTimers.SetButton_OnClick(self, button)
    if InCombatLockdown() then return end
    --XiTimers.timers[5].button:SetAttribute("hide", true)
    self:GetParent():Execute([[ owner:ChildUpdate("show", false) ]])

    local set = TotemTimers.ActiveProfile.TotemSets[self.nr]
    if not set then return end

	if button == "RightButton" then
		local popup = StaticPopup_Show("TOTEMTIMERS_DELETESET", not set.name and self.nr or set.name)
		popup.data = self.nr
    elseif button == "LeftButton" then
        for i=1,4 do
            local spell = TotemTimers.UpdateSpellRank(set[XiTimers.timers[i].nr])
            XiTimers.timers[i].button:SetAttribute("*spell1", spell)

            if LE_EXPANSION_LEVEL_CURRENT > LE_EXPANSION_BURNING_CRUSADE and LE_EXPANSION_LEVEL_CURRENT < LE_EXPANSION_MISTS_OF_PANDARIA then
                if TotemTimers_MultiSpell.active then
                    local mspell = XiTimers.timers[i].button:GetAttribute("mspell")
                    local disabled = XiTimers.timers[i].button:GetAttribute("mspelldisabled"..mspell)
                    if not disabled then
                        SetMultiCastSpell(XiTimers.timers[i].button:GetAttribute("action"..mspell), spell)
                    end
                end
            end
        end
	end
end

local function TotemTimers_DeleteSet(self, nr)
	if not InCombatLockdown() then
		table.remove(TotemTimers.ActiveProfile.TotemSets,nr)
		TotemTimers.ProgramSetButtons()
	end
end

StaticPopupDialogs["TOTEMTIMERS_DELETESET"] = {
  text = L["Delete Set"],
  button1 = OKAY,
  button2 = CANCEL,
  whileDead = 1,
  hideOnEscape = 1,
  timeout = 0,
  OnAccept = TotemTimers_DeleteSet,
}


-- ============================================================================
-- LOADOUT BAR - Visual loadout switcher (works like totem menus)
-- ============================================================================

local LoadoutBar = {}
TotemTimers.LoadoutBar = LoadoutBar
LoadoutBar.buttons = {}
LoadoutBar.menuOpen = false

-- Default icon for loadouts (Shaman class icon)
local DEFAULT_LOADOUT_ICON = "Interface\\Icons\\Spell_Nature_Lightning"

-- Opacity for non-active loadouts in the menu
local INACTIVE_ALPHA = 0.5

-- Spacing between menu buttons (0 to prevent gaps that would close menu)
local MENU_SPACING = 0

-- Get the icon for a loadout
function TotemTimers.GetLoadoutIcon(setIndex)
    local set = TotemTimers.ActiveProfile.TotemSets[setIndex]
    if set and set.icon then
        return set.icon
    end
    -- Default: use the first totem's icon or a default
    local spellValue = NormalizeSpellValue(set and set[1])
    if IsValidSpellValue(spellValue) then
        local _, _, texture = GetSpellInfo(spellValue)
        if texture then return texture end
    end
    return DEFAULT_LOADOUT_ICON
end

-- Initialize the loadout bar
function TotemTimers.InitLoadoutBar()
    local anchor = TotemTimers_LoadoutBarAnchor
    if not anchor then return end

    anchor:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    -- Set initial position
    TotemTimers.RestoreLoadoutBarPosition()

    -- Update the anchor icon
    TotemTimers.UpdateLoadoutBarIcon()

    -- Create menu buttons
    TotemTimers.CreateLoadoutMenuButtons()

    -- Show/hide based on settings
    TotemTimers.ProcessSetting("LoadoutBar")
end

-- Create/update menu buttons for each loadout (arranged vertically like totem menus)
function TotemTimers.CreateLoadoutMenuButtons()
    local anchor = TotemTimers_LoadoutBarAnchor
    if not anchor then return end

    local Sets = TotemTimers.ActiveProfile.TotemSets
    local numSets = #Sets
    local buttonSize = anchor:GetWidth() or 36

    -- Hide all existing buttons first
    for i, btn in ipairs(LoadoutBar.buttons) do
        btn:Hide()
    end

    if numSets == 0 then return end

    -- Create/update buttons for each loadout
    for i = 1, numSets do
        local btn = LoadoutBar.buttons[i]
        if not btn then
            btn = CreateFrame("Button", "TotemTimers_LoadoutMenuButton"..i, anchor, "TotemTimers_LoadoutMenuButtonTemplate")
            btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            LoadoutBar.buttons[i] = btn
        end

        btn.loadoutIndex = i
        btn:SetSize(buttonSize, buttonSize)
        btn:ClearAllPoints()

        -- Arrange vertically above the anchor (like totem menus)
        if i == 1 then
            btn:SetPoint("BOTTOM", anchor, "TOP", 0, MENU_SPACING)
        else
            btn:SetPoint("BOTTOM", LoadoutBar.buttons[i-1], "TOP", 0, MENU_SPACING)
        end

        -- Set main icon (background)
        local set = Sets[i]
        local icon = _G[btn:GetName().."Icon"]
        if icon then
            icon:SetTexture(TotemTimers.GetLoadoutIcon(i))
            icon:SetAlpha(0.3) -- Dim the background icon so totem icons stand out
        end

        -- Set mini totem icons in corners
        for element = 1, 4 do
            local totemIcon = _G[btn:GetName().."Totem"..element]
            if totemIcon then
                local spellValue = NormalizeSpellValue(set[element])
                if IsValidSpellValue(spellValue) then
                    local _, _, texture = GetSpellInfo(spellValue)
                    if texture then
                        totemIcon:SetTexture(texture)
                        totemIcon:Show()
                    else
                        totemIcon:Hide()
                    end
                else
                    totemIcon:Hide()
                end
            end
        end

        -- Set opacity based on active state (non-active = dimmed)
        local isActive = (TotemTimers.ActiveProfile.ActiveLoadout == i)
        btn:SetAlpha(isActive and 1.0 or INACTIVE_ALPHA)

        btn:SetParent(anchor)
        -- Don't show yet - wait for hover
    end
end

-- Show the loadout menu
function TotemTimers.ShowLoadoutMenu()
    if LoadoutBar.menuOpen then return end
    LoadoutBar.menuOpen = true

    TotemTimers.CreateLoadoutMenuButtons()

    local Sets = TotemTimers.ActiveProfile.TotemSets
    for i = 1, #Sets do
        local btn = LoadoutBar.buttons[i]
        if btn then
            btn:Show()
        end
    end
end

-- Hide the loadout menu
function TotemTimers.HideLoadoutMenu()
    LoadoutBar.menuOpen = false

    for i, btn in ipairs(LoadoutBar.buttons) do
        btn:Hide()
    end
end

-- Check if mouse is over anchor or any menu button
function TotemTimers.IsMouseOverLoadoutBar()
    local anchor = TotemTimers_LoadoutBarAnchor
    if anchor and anchor:IsMouseOver() then
        return true
    end

    for i, btn in ipairs(LoadoutBar.buttons) do
        if btn:IsVisible() and btn:IsMouseOver() then
            return true
        end
    end

    return false
end

-- Update the main anchor button icon
function TotemTimers.UpdateLoadoutBarIcon()
    local anchor = TotemTimers_LoadoutBarAnchor
    if not anchor then return end

    local icon = TotemTimers_LoadoutBarAnchorIcon
    if not icon then return end

    local activeIndex = TotemTimers.ActiveProfile.ActiveLoadout
    if activeIndex and TotemTimers.ActiveProfile.TotemSets[activeIndex] then
        icon:SetTexture(TotemTimers.GetLoadoutIcon(activeIndex))
    else
        icon:SetTexture(DEFAULT_LOADOUT_ICON)
    end
end

-- Save loadout bar position
function TotemTimers.SaveLoadoutBarPosition()
    local anchor = TotemTimers_LoadoutBarAnchor
    if not anchor then return end

    local point, _, relativePoint, x, y = anchor:GetPoint()
    TotemTimers.ActiveProfile.LoadoutBarPosition = {
        point = point,
        relativePoint = relativePoint,
        x = x,
        y = y
    }
end

-- Restore loadout bar position
function TotemTimers.RestoreLoadoutBarPosition()
    local anchor = TotemTimers_LoadoutBarAnchor
    if not anchor then return end

    local pos = TotemTimers.ActiveProfile.LoadoutBarPosition
    if pos then
        anchor:ClearAllPoints()
        anchor:SetPoint(pos.point or "CENTER", UIParent, pos.relativePoint or "CENTER", pos.x or 0, pos.y or 0)
    else
        anchor:ClearAllPoints()
        anchor:SetPoint("CENTER", UIParent, "CENTER", 0, -200)
    end
end

-- Mouse enter on main anchor - show menu
function TotemTimers.LoadoutBar_OnEnter(self)
    TotemTimers.ShowLoadoutMenu()

    -- Show tooltip
    if TotemTimers.ActiveProfile.Tooltips then
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Totem Loadouts", 1, 1, 1)
        local activeIndex = TotemTimers.ActiveProfile.ActiveLoadout
        if activeIndex then
            local set = TotemTimers.ActiveProfile.TotemSets[activeIndex]
            if set then
                GameTooltip:AddLine("Active: " .. (set.name or ("Loadout "..activeIndex)), 0, 1, 0)
            end
        end
        GameTooltip:AddLine(" ", 1, 1, 1)
        GameTooltip:AddLine("Right-click: Options", 0.7, 0.7, 0.7)
        if not TotemTimers.ActiveProfile.Lock then
            GameTooltip:AddLine("Shift+Drag: Move", 0.7, 0.7, 0.7)
        end
        GameTooltip:Show()
    end
end

-- Mouse leave on main anchor - check if should hide menu
function TotemTimers.LoadoutBar_OnLeave(self)
    GameTooltip:Hide()

    -- Use a short delay to check if mouse moved to a menu button
    C_Timer.After(0.05, function()
        if not TotemTimers.IsMouseOverLoadoutBar() then
            TotemTimers.HideLoadoutMenu()
        end
    end)
end

-- Click on main anchor
function TotemTimers.LoadoutBar_OnClick(self, button)
    if button == "RightButton" then
        -- Open loadouts options
        TotemTimers.HideLoadoutMenu()
        if Settings then
            Settings.OpenToCategory("TotemTimers")
        else
            InterfaceOptionsFrame_OpenToCategory("TotemTimers")
        end
    end
end

-- Mouse enter on menu button
function TotemTimers.LoadoutMenuButton_OnEnter(self)
    -- Keep menu open
    local set = TotemTimers.ActiveProfile.TotemSets[self.loadoutIndex]
    if not set then return end

    -- Show tooltip with loadout details
    if TotemTimers.ActiveProfile.Tooltips then
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(set.name or ("Loadout "..self.loadoutIndex), 1, 1, 1)

        -- Show totems in tooltip
        local SpellNames = TotemTimers.SpellNames
        local elementNames = {"Earth", "Fire", "Water", "Air"}
        for element = 1, 4 do
            local spellValue = NormalizeSpellValue(set[element])
            if IsValidSpellValue(spellValue) then
                -- Handle both spell ID (number) and spell name (string) formats
                local spellName = type(spellValue) == "string" and spellValue or (SpellNames[spellValue] or GetSpellInfo(spellValue) or "Unknown")
                local color = TotemTimers.ElementColors[element]
                GameTooltip:AddLine(elementNames[element] .. ": " .. spellName, color.r, color.g, color.b)
            end
        end

        if TotemTimers.ActiveProfile.ActiveLoadout == self.loadoutIndex then
            GameTooltip:AddLine(" ", 1, 1, 1)
            GameTooltip:AddLine("(Active)", 0, 1, 0)
        end

        GameTooltip:Show()
    end
end

-- Mouse leave on menu button - check if should hide menu
function TotemTimers.LoadoutMenuButton_OnLeave(self)
    GameTooltip:Hide()

    -- Use a short delay to check if mouse moved to another button
    C_Timer.After(0.05, function()
        if not TotemTimers.IsMouseOverLoadoutBar() then
            TotemTimers.HideLoadoutMenu()
        end
    end)
end

-- Click on menu button - activate loadout
function TotemTimers.LoadoutMenuButton_OnClick(self, button)
    local setIndex = self.loadoutIndex
    local set = TotemTimers.ActiveProfile.TotemSets[setIndex]
    if not set then return end

    if button == "LeftButton" then
        if InCombatLockdown() then
            print("|cffff0000TotemTimers:|r Cannot change loadout during combat")
            return
        end

        -- Apply loadout
        for i = 1, 4 do
            local spell = TotemTimers.UpdateSpellRank(set[XiTimers.timers[i].nr])
            XiTimers.timers[i].button:SetAttribute("*spell1", spell)
        end
        TotemTimers.ActiveProfile.ActiveLoadout = setIndex

        -- Update visuals
        TotemTimers.UpdateLoadoutBarIcon()
        TotemTimers.CreateLoadoutMenuButtons()

        local name = set.name or ("Loadout " .. setIndex)
        print("|cff00ff00TotemTimers:|r Activated loadout '" .. name .. "'")

        -- Hide menu
        TotemTimers.HideLoadoutMenu()
    end
end

-- Hook into the delete confirmation to update loadout bar
local origDeleteOnAccept = StaticPopupDialogs["TOTEMTIMERS_DELETESET"].OnAccept
StaticPopupDialogs["TOTEMTIMERS_DELETESET"].OnAccept = function(self, nr)
    origDeleteOnAccept(self, nr)
    -- Update loadout bar after deletion
    if TotemTimers_LoadoutBarAnchor and TotemTimers_LoadoutBarAnchor:IsVisible() then
        TotemTimers.UpdateLoadoutBarIcon()
        TotemTimers.CreateLoadoutMenuButtons()
    end
end
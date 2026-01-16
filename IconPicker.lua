if select(2, UnitClass("player")) ~= "SHAMAN" then return end

-- Icon Picker Frame for TotemTimers Loadouts
-- Creates a grid-based icon selector like the macro UI
-- Uses virtual scrolling to handle thousands of icons efficiently

local IconPicker = {}
TotemTimers.IconPicker = IconPicker

local ICONS_PER_ROW = 10
local ICON_SIZE = 36
local ICON_SPACING = 4
local VISIBLE_ROWS = 8
local ROW_HEIGHT = ICON_SIZE + ICON_SPACING

local allIcons = {}
local filteredIcons = {}
local currentCallback = nil
local currentLoadoutIndex = nil
local selectedIconIndex = nil

-- Build the list of all available icons
local function BuildIconList()
    if #allIcons > 0 then return end -- Already built

    -- Get macro icons (spells, items, etc.)
    local macroIcons = GetMacroIcons()
    if macroIcons then
        for i = 1, #macroIcons do
            table.insert(allIcons, macroIcons[i])
        end
    end

    -- Get macro item icons
    local itemIcons = GetMacroItemIcons()
    if itemIcons then
        for i = 1, #itemIcons do
            table.insert(allIcons, itemIcons[i])
        end
    end

    -- If those functions didn't work (TBC might not have them), add some common icons manually
    if #allIcons == 0 then
        -- Shaman-related icons
        local commonIcons = {
            "Interface\\Icons\\Spell_Nature_Lightning",
            "Interface\\Icons\\Spell_Nature_ChainLightning",
            "Interface\\Icons\\Spell_Fire_FlameShock",
            "Interface\\Icons\\Spell_Nature_EarthShock",
            "Interface\\Icons\\Spell_Frost_FrostShock2",
            "Interface\\Icons\\Spell_Nature_MagicImmunity",
            "Interface\\Icons\\Ability_Shaman_Stormstrike",
            "Interface\\Icons\\Spell_Nature_LightningShield",
            "Interface\\Icons\\Spell_Fire_Volcano",
            "Interface\\Icons\\Spell_Nature_HealingWaveGreater",
            "Interface\\Icons\\Spell_Nature_StoneSkinTotem",
            "Interface\\Icons\\Spell_Fire_SearingTotem",
            "Interface\\Icons\\Spell_Nature_ManaRegenTotem",
            "Interface\\Icons\\Spell_Nature_InvisibilityTotem",
            "Interface\\Icons\\Spell_Nature_Cyclone",
            "Interface\\Icons\\Spell_Nature_EarthBindTotem",
            "Interface\\Icons\\Spell_Nature_TremorTotem",
            "Interface\\Icons\\Spell_Fire_SelfDestruct",
            "Interface\\Icons\\Spell_Nature_GroundingTotem",
            "Interface\\Icons\\Spell_Nature_Purge",
            "Interface\\Icons\\Spell_Nature_SkinofEarth",
            "Interface\\Icons\\Spell_Nature_Bloodlust",
            "Interface\\Icons\\Spell_Nature_UnyeildingStamina",
            "Interface\\Icons\\Spell_FireResistanceTotem_01",
            "Interface\\Icons\\Spell_FrostResistanceTotem_01",
            "Interface\\Icons\\Spell_Nature_NatureResistanceTotem",
            "Interface\\Icons\\Spell_Nature_WispSplode",
            "Interface\\Icons\\Spell_Fire_TotemOfWrath",
            "Interface\\Icons\\Spell_Nature_ManaTide",
            "Interface\\Icons\\Spell_Shaman_TotemRecall",
            -- Class icons
            "Interface\\Icons\\ClassIcon_Shaman",
            "Interface\\Icons\\ClassIcon_Warrior",
            "Interface\\Icons\\ClassIcon_Paladin",
            "Interface\\Icons\\ClassIcon_Hunter",
            "Interface\\Icons\\ClassIcon_Rogue",
            "Interface\\Icons\\ClassIcon_Priest",
            "Interface\\Icons\\ClassIcon_Mage",
            "Interface\\Icons\\ClassIcon_Warlock",
            "Interface\\Icons\\ClassIcon_Druid",
            -- Spec/role icons
            "Interface\\Icons\\Ability_ThunderBolt",
            "Interface\\Icons\\Ability_DualWield",
            "Interface\\Icons\\Ability_Rogue_Ambush",
            "Interface\\Icons\\Ability_Warrior_BattleShout",
            "Interface\\Icons\\Ability_Warrior_DefensiveStance",
            "Interface\\Icons\\Ability_Warrior_OffensiveStance",
            -- PvP icons
            "Interface\\Icons\\Achievement_PVP_A_A",
            "Interface\\Icons\\Achievement_PVP_H_H",
            "Interface\\Icons\\INV_BannerPVP_01",
            "Interface\\Icons\\INV_BannerPVP_02",
            -- Raid/dungeon icons
            "Interface\\Icons\\Spell_Holy_PrayerOfHealing",
            "Interface\\Icons\\INV_Misc_Head_Dragon_01",
            "Interface\\Icons\\Achievement_Dungeon_ClassicDungeonMaster",
            -- Misc useful icons
            "Interface\\Icons\\INV_Misc_QuestionMark",
            "Interface\\Icons\\Ability_Creature_Cursed_02",
            "Interface\\Icons\\Spell_Shadow_SacrificialShield",
            "Interface\\Icons\\Ability_Creature_Disease_03",
        }
        for _, icon in ipairs(commonIcons) do
            table.insert(allIcons, icon)
        end
    end

    filteredIcons = allIcons
end

-- Update visible buttons based on scroll position (virtual scrolling)
local function UpdateVisibleButtons()
    local frame = IconPicker.frame
    if not frame then return end

    local scrollFrame = frame.scrollFrame
    local offset = scrollFrame:GetVerticalScroll()
    local firstVisibleRow = math.floor(offset / ROW_HEIGHT)
    local firstIconIndex = firstVisibleRow * ICONS_PER_ROW + 1

    -- Update each button with the correct icon
    for i, btn in ipairs(frame.iconButtons) do
        local iconIndex = firstIconIndex + i - 1
        if iconIndex <= #filteredIcons then
            local iconPath = filteredIcons[iconIndex]
            btn.iconIndex = iconIndex
            btn.iconPath = iconPath
            btn.icon:SetTexture(iconPath)

            -- Show selection border if this is the selected icon
            if iconIndex == selectedIconIndex then
                btn.border:Show()
            else
                btn.border:Hide()
            end

            btn:Show()
        else
            btn:Hide()
        end
    end
end

-- Create the icon picker frame
local function CreateIconPickerFrame()
    if IconPicker.frame then return end

    local frameWidth = ICONS_PER_ROW * (ICON_SIZE + ICON_SPACING) + 50
    local frameHeight = VISIBLE_ROWS * ROW_HEIGHT + 110

    local frame = CreateFrame("Frame", "TotemTimers_IconPicker", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(frameWidth, frameHeight)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()

    frame.TitleText:SetText("Choose an Icon")

    -- Currently selected icon display
    local selectedBG = frame:CreateTexture(nil, "BACKGROUND")
    selectedBG:SetSize(ICON_SIZE + 8, ICON_SIZE + 8)
    selectedBG:SetPoint("TOPLEFT", frame, "TOPLEFT", 15, -35)
    selectedBG:SetColorTexture(0.2, 0.2, 0.2, 1)

    local selectedIcon = frame:CreateTexture(nil, "ARTWORK")
    selectedIcon:SetSize(ICON_SIZE, ICON_SIZE)
    selectedIcon:SetPoint("CENTER", selectedBG, "CENTER")
    frame.selectedIcon = selectedIcon

    local selectedLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    selectedLabel:SetPoint("LEFT", selectedBG, "RIGHT", 10, 0)
    selectedLabel:SetText("Selected")

    -- Container for icons (clips content)
    local iconContainer = CreateFrame("Frame", nil, frame)
    iconContainer:SetPoint("TOPLEFT", frame, "TOPLEFT", 15, -80)
    iconContainer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -35, 45)
    iconContainer:SetClipsChildren(true)
    frame.iconContainer = iconContainer

    -- Scroll frame (for scroll bar only, not for content)
    local scrollFrame = CreateFrame("ScrollFrame", "TotemTimers_IconPickerScroll", frame, "FauxScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", iconContainer, "TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", iconContainer, "BOTTOMRIGHT", -18, 0)
    frame.scrollFrame = scrollFrame

    -- Create only enough buttons for visible area (+ 1 row buffer)
    local numVisibleButtons = ICONS_PER_ROW * (VISIBLE_ROWS + 1)
    frame.iconButtons = {}

    for i = 1, numVisibleButtons do
        local btn = CreateFrame("Button", nil, iconContainer)
        btn:SetSize(ICON_SIZE, ICON_SIZE)

        local row = math.floor((i - 1) / ICONS_PER_ROW)
        local col = (i - 1) % ICONS_PER_ROW
        btn:SetPoint("TOPLEFT", iconContainer, "TOPLEFT", col * (ICON_SIZE + ICON_SPACING), -row * ROW_HEIGHT)

        local icon = btn:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints()
        btn.icon = icon

        local highlight = btn:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetAllPoints()
        highlight:SetColorTexture(1, 1, 1, 0.3)

        local border = btn:CreateTexture(nil, "OVERLAY")
        border:SetSize(ICON_SIZE * 1.8, ICON_SIZE * 1.8)
        border:SetPoint("CENTER")
        border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
        border:SetBlendMode("ADD")
        border:Hide()
        btn.border = border

        btn:SetScript("OnClick", function(self)
            -- Update selection
            selectedIconIndex = self.iconIndex
            frame.selectedIconPath = self.iconPath
            frame.selectedIcon:SetTexture(self.iconPath)

            -- Update all visible buttons to show/hide selection border
            for _, b in ipairs(frame.iconButtons) do
                if b.iconIndex == selectedIconIndex then
                    b.border:Show()
                else
                    b.border:Hide()
                end
            end
        end)

        btn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            local path = self.iconPath
            local name
            if type(path) == "number" then
                name = tostring(path)
            elseif type(path) == "string" then
                name = path:match("Interface\\Icons\\(.+)") or path
            else
                name = "Unknown"
            end
            GameTooltip:SetText(name)
            GameTooltip:Show()
        end)

        btn:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        frame.iconButtons[i] = btn
    end

    -- Scroll handler
    scrollFrame:SetScript("OnVerticalScroll", function(self, offset)
        local numRows = math.ceil(#filteredIcons / ICONS_PER_ROW)
        FauxScrollFrame_OnVerticalScroll(self, offset, ROW_HEIGHT, function()
            UpdateVisibleButtons()
        end)
    end)

    -- Okay button
    local okayButton = CreateFrame("Button", nil, frame, "GameMenuButtonTemplate")
    okayButton:SetSize(80, 22)
    okayButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOM", -5, 12)
    okayButton:SetText("Okay")
    okayButton:SetScript("OnClick", function()
        if currentCallback and frame.selectedIconPath then
            currentCallback(frame.selectedIconPath)
        end
        frame:Hide()
    end)

    -- Cancel button
    local cancelButton = CreateFrame("Button", nil, frame, "GameMenuButtonTemplate")
    cancelButton:SetSize(80, 22)
    cancelButton:SetPoint("BOTTOMLEFT", frame, "BOTTOM", 5, 12)
    cancelButton:SetText("Cancel")
    cancelButton:SetScript("OnClick", function()
        frame:Hide()
    end)

    IconPicker.frame = frame
end

-- Initialize/update the scroll frame
local function InitializeScrollFrame()
    local frame = IconPicker.frame
    local scrollFrame = frame.scrollFrame

    local numRows = math.ceil(#filteredIcons / ICONS_PER_ROW)
    local totalHeight = numRows * ROW_HEIGHT

    FauxScrollFrame_Update(scrollFrame, numRows, VISIBLE_ROWS, ROW_HEIGHT)
    UpdateVisibleButtons()
end

-- Open the icon picker
function TotemTimers.OpenIconPicker(loadoutIndex, callback)
    BuildIconList()
    CreateIconPickerFrame()

    currentCallback = callback
    currentLoadoutIndex = loadoutIndex
    selectedIconIndex = nil

    -- Set current icon if loadout has one
    local set = TotemTimers.ActiveProfile.TotemSets[loadoutIndex]
    if set and set.icon then
        IconPicker.frame.selectedIconPath = set.icon
        IconPicker.frame.selectedIcon:SetTexture(set.icon)
        -- Find the index of the current icon
        for i, icon in ipairs(filteredIcons) do
            if icon == set.icon then
                selectedIconIndex = i
                break
            end
        end
    else
        IconPicker.frame.selectedIconPath = nil
        IconPicker.frame.selectedIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    end

    InitializeScrollFrame()
    IconPicker.frame:Show()
end

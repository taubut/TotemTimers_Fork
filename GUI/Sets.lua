if select(2,UnitClass("player")) ~= "SHAMAN" then return end

local L = LibStub("AceLocale-3.0"):GetLocale("TotemTimers_GUI", true)

-- Track currently selected loadout in the UI
local selectedLoadout = 1

TotemTimers.options.args.sets = {
    type = "group",
    name = "Loadouts",
    args = {},
}

local SpellNames = TotemTimers.SpellNames

local ACD = LibStub("AceConfigDialog-3.0")
local ACR =	LibStub("AceConfigRegistry-3.0")

-- Helper function to get current totems from the timer buttons
local function GetCurrentTotems()
    local set = {}
    for i = 1, 4 do
        local nr = XiTimers.timers[i].nr
        local spell = XiTimers.timers[i].button:GetAttribute("*spell1")
        spell = TotemTimers.GetBaseSpellID(spell)
        if not spell then spell = 0 end
        set[nr] = spell
    end
    return set
end

-- Helper function to apply a loadout to the totem buttons
local function ApplyLoadout(setIndex)
    if InCombatLockdown() then
        print("|cffff0000TotemTimers:|r Cannot change loadout during combat")
        return false
    end

    local set = TotemTimers.ActiveProfile.TotemSets[setIndex]
    if not set then return false end

    for i = 1, 4 do
        local spell = TotemTimers.UpdateSpellRank(set[XiTimers.timers[i].nr])
        XiTimers.timers[i].button:SetAttribute("*spell1", spell)
    end

    TotemTimers.ActiveProfile.ActiveLoadout = setIndex

    -- Update loadout bar visuals
    if TotemTimers.UpdateLoadoutBarIcon then
        TotemTimers.UpdateLoadoutBarIcon()
    end
    if TotemTimers.CreateLoadoutMenuButtons then
        TotemTimers.CreateLoadoutMenuButtons()
    end

    return true
end

-- Helper function to get loadout dropdown values
local function GetLoadoutValues()
    local values = {}
    local Sets = TotemTimers.ActiveProfile.TotemSets
    for i = 1, #Sets do
        local set = Sets[i]
        values[i] = set.name or ("Loadout " .. i)
    end
    return values
end

-- Helper function to get totem description for a set
local function GetTotemDescription(set)
    local totems = {}
    for element = 1, 4 do
        if set[element] and set[element] > 0 then
            totems[element] = TotemTimers.ElementColors[element]:WrapTextInColorCode(SpellNames[set[element]])
        else
            totems[element] = TotemTimers.ElementColors[element]:WrapTextInColorCode("(none)")
        end
    end
    return table.concat(totems, ", ")
end

local frame, categoryID = ACD:AddToBlizOptions("TotemTimers", "Loadouts", "TotemTimers", "sets")
TotemTimers.HookGUIFrame(frame, categoryID)

frame:HookScript("OnShow", function(self)
    TotemTimers.options.args.sets.args = {}
    local args = TotemTimers.options.args.sets.args
    local Sets = TotemTimers.ActiveProfile.TotemSets

    -- Description header
    args.desc = {
        type = "description",
        order = 1,
        name = "Save and switch between different totem configurations. Create loadouts for different specs or situations (Enhance, Elemental, Resto, PvP, etc.)\n",
    }

    -- Loadout Bar toggle
    args.showLoadoutBar = {
        type = "toggle",
        order = 2,
        name = "Show Loadout Bar",
        desc = "Display a visual loadout switcher button on screen. Hover over it to see and switch between your saved loadouts.",
        width = "full",
        set = function(info, val)
            TotemTimers.ActiveProfile.LoadoutBar = val
            TotemTimers.ProcessSetting("LoadoutBar")
        end,
        get = function()
            return TotemTimers.ActiveProfile.LoadoutBar
        end,
    }

    -- Quick Actions section
    args.quickHeader = {
        type = "header",
        order = 5,
        name = "Quick Actions",
    }

    -- Save current totems as new loadout
    args.newLoadoutName = {
        type = "input",
        order = 10,
        name = "New Loadout Name",
        desc = "Enter a name for your new loadout, then click 'Save Current Totems'",
        set = function(info, val)
            TotemTimers.NewLoadoutName = val
        end,
        get = function()
            return TotemTimers.NewLoadoutName or ""
        end,
    }

    args.saveNew = {
        type = "execute",
        order = 11,
        name = "Save Current Totems",
        desc = "Save your current totem configuration as a new loadout",
        func = function()
            if #Sets >= 8 then
                print("|cffff0000TotemTimers:|r Maximum of 8 loadouts reached. Delete one first.")
                return
            end

            local newSet = GetCurrentTotems()
            newSet.name = TotemTimers.NewLoadoutName or nil
            table.insert(Sets, newSet)
            TotemTimers.NewLoadoutName = nil
            TotemTimers.ProgramSetButtons()

            -- Update loadout bar
            if TotemTimers.CreateLoadoutMenuButtons then
                TotemTimers.CreateLoadoutMenuButtons()
            end

            local name = newSet.name or ("Loadout " .. #Sets)
            print("|cff00ff00TotemTimers:|r Saved loadout '" .. name .. "'")

            -- Hide and show to trigger OnShow which rebuilds the args
            frame:Hide()
            frame:Show()
        end,
    }

    -- Switch loadout dropdown (only show if there are sets)
    if #Sets > 0 then
        args.switchHeader = {
            type = "header",
            order = 20,
            name = "Switch Loadout",
        }

        args.loadoutSelect = {
            type = "select",
            order = 21,
            name = "Select Loadout",
            desc = "Choose a loadout to activate",
            values = GetLoadoutValues,
            set = function(info, val)
                selectedLoadout = val
                if ApplyLoadout(val) then
                    local set = Sets[val]
                    local name = set.name or ("Loadout " .. val)
                    print("|cff00ff00TotemTimers:|r Activated loadout '" .. name .. "'")
                end
                ACR:NotifyChange("TotemTimers")
            end,
            get = function()
                -- Default to active loadout if set
                if TotemTimers.ActiveProfile.ActiveLoadout and Sets[TotemTimers.ActiveProfile.ActiveLoadout] then
                    selectedLoadout = TotemTimers.ActiveProfile.ActiveLoadout
                end
                return selectedLoadout
            end,
        }

        -- Show current loadout's totems
        args.currentTotems = {
            type = "description",
            order = 22,
            name = function()
                local set = Sets[selectedLoadout]
                if set then
                    return "Totems: " .. GetTotemDescription(set)
                end
                return ""
            end,
        }

        args.overwrite = {
            type = "execute",
            order = 23,
            name = "Overwrite Selected",
            desc = "Replace the selected loadout with your current totems",
            func = function()
                local set = Sets[selectedLoadout]
                if not set then return end

                local newTotems = GetCurrentTotems()
                for k, v in pairs(newTotems) do
                    set[k] = v
                end

                TotemTimers.ProgramSetButtons()

                local name = set.name or ("Loadout " .. selectedLoadout)
                print("|cff00ff00TotemTimers:|r Updated loadout '" .. name .. "'")

                ACR:NotifyChange("TotemTimers")
            end,
        }
    end

    -- Existing loadouts management section
    args.manageHeader = {
        type = "header",
        order = 100,
        name = "Manage Loadouts",
    }

    if #Sets == 0 then
        args.noSets = {
            type = "description",
            order = 101,
            name = "No loadouts saved yet. Enter a name above and click 'Save Current Totems' to create your first loadout.",
        }
    else
        for i = 1, #Sets do
            local set = Sets[i]
            local setName = set.name or ("Loadout " .. i)
            local baseOrder = 100 + (i * 10)

            args["setHeader" .. i] = {
                type = "header",
                order = baseOrder,
                name = function()
                    local currentSet = Sets[i]
                    if not currentSet then return "" end
                    local prefix = ""
                    if TotemTimers.ActiveProfile.ActiveLoadout == i then
                        prefix = "|cff00ff00[Active]|r "
                    end
                    return prefix .. (currentSet.name or ("Loadout " .. i))
                end,
            }

            args["setDesc" .. i] = {
                type = "description",
                order = baseOrder + 1,
                name = function()
                    local currentSet = Sets[i]
                    if not currentSet then return "" end
                    return GetTotemDescription(currentSet)
                end,
            }

            args["setRename" .. i] = {
                type = "input",
                name = L["Rename"],
                order = baseOrder + 2,
                arg = i,
                set = function(info, value)
                    if not Sets[info.arg] then return end
                    Sets[info.arg].name = value
                    ACR:NotifyChange("TotemTimers")
                end,
                get = function(info)
                    if not Sets[info.arg] then return "" end
                    return Sets[info.arg].name or ""
                end,
            }

            args["setIcon" .. i] = {
                type = "execute",
                name = function()
                    local currentSet = Sets[i]
                    if not currentSet then return "Choose Icon" end
                    local icon = currentSet.icon or TotemTimers.GetLoadoutIcon(i)
                    return "|T" .. icon .. ":20|t Choose Icon"
                end,
                desc = "Click to choose an icon for this loadout",
                order = baseOrder + 2.5,
                arg = i,
                func = function(info)
                    if not Sets[info.arg] then return end
                    local loadoutIndex = info.arg  -- Capture value for callback
                    TotemTimers.OpenIconPicker(loadoutIndex, function(selectedIcon)
                        if not Sets[loadoutIndex] then return end
                        Sets[loadoutIndex].icon = selectedIcon
                        -- Update loadout bar
                        if TotemTimers.UpdateLoadoutBarIcon then
                            TotemTimers.UpdateLoadoutBarIcon()
                        end
                        if TotemTimers.CreateLoadoutMenuButtons then
                            TotemTimers.CreateLoadoutMenuButtons()
                        end
                        ACR:NotifyChange("TotemTimers")
                    end)
                end,
            }

            args["setDelete" .. i] = {
                type = "execute",
                name = L["Delete"],
                order = baseOrder + 3,
                arg = i,
                func = function(info)
                    if not Sets[info.arg] then return end
                    local popup = StaticPopup_Show("TOTEMTIMERS_DELETESET", Sets[info.arg].name or info.arg)
                    popup.data = info.arg
                end,
            }
        end
    end

    ACR:NotifyChange("TotemTimers")

end)

local deleteOnAccept = StaticPopupDialogs["TOTEMTIMERS_DELETESET"].OnAccept
StaticPopupDialogs["TOTEMTIMERS_DELETESET"].OnAccept = function(self, nr)
    deleteOnAccept(self, nr)
    if frame:IsVisible() then
        -- Hide and show to trigger OnShow which rebuilds the args
        frame:Hide()
        frame:Show()
    end
end

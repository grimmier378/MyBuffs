--[[
    Title: MyBuffs
    Author: Grimmier
    Description: stupidly simple buff window.
    Right Click to Inspect
    Left Click and Drag to remove a buff.
]]
---@type Mq
local mq = require('mq')
---@type ImGui
local ImGui = require('ImGui')
local Icons = require('mq.ICONS')

-- set variables
local animSpell = mq.FindTextureAnimation('A_SpellIcons')
local TLO = mq.TLO
local ME = TLO.Me
local BUFF = mq.TLO.Me.Buff
local SONG = mq.TLO.Me.Song
local winFlag = bit32.bor(ImGuiWindowFlags.NoScrollbar, ImGuiWindowFlags.MenuBar, ImGuiWindowFlags.NoScrollWithMouse)
local firstTime = true
local iconSize = 24
local flashAlpha, flashAlphaT = 1, 255
local rise, riseT = true, true
local ShowGUI, openGUI, SplitWin, openConfigGUI = true, true, false, false
local debuffed, stateChanged = false, false
local locked, ShowIcons, ShowTimer, ShowText, ShowScroll = false, true, true, true, true
local songTimer, buffTime = 20, 5 -- timers for how many Minutes left before we show the timer.
local check = os.time()
local MaxBuffs = ME.MaxBuffSlots() or 0 --Max Buff Slots
local ColorCount, ColorCountSongs, ColorCountConf, StyleCount, StyleCountSongs, StyleCountConf = 0, 0, 0, 0, 0, 0
local themeFile = mq.configDir .. '/MyThemeZ.lua'
local configFile = mq.configDir .. '/MyUI_Configs.lua'
local Scale = 1.0
local gIcon = Icons.MD_SETTINGS
local themeName = 'Default'
local script = 'MyBuffs'
local lastBuffCount = -1
local defaults, settings, timerColor, theme = {}, {}, {}, {}
defaults = {
    Scale = 1.0,
    LoadTheme = 'Default',
    locked = false,
    IconSize = 24,
    ShowIcons = true,
    ShowTimer = true,
    ShowText = true,
    ShowScroll = true,
    SplitWin = false,
    SongTimer = 20, -- number of seconds remaining to trigger showing timer
    BuffTimer = 5,  -- number of minutes remaining to trigger showing timer
    TimerColor = {0,0,0,1}
}


---comment Check to see if the file we want to work on exists.
---@param fileName string -- Full Path to file
---@return boolean -- returns true if the file exists and false otherwise
local function File_Exists(fileName)
    local f=io.open(fileName,"r")
    if f~=nil then io.close(f) return true else return false end
end

---comment Writes settings from the settings table passed to the setting file (full path required)
-- Uses mq.pickle to serialize the table and write to file
---@param fileName string -- File Name and path
---@param table table -- Table of settings to write
local function writeSettings(fileName, table)
    mq.pickle(fileName, table)
end

local function loadTheme()
    if File_Exists(themeFile) then
        theme = dofile(themeFile)
        else
        theme = require('themes')
    end
    themeName = theme.LoadTheme or 'notheme'
end

local function loadSettings()
    if not File_Exists(configFile) then
        mq.pickle(configFile, defaults)
        loadSettings()
        else
        
        -- Load settings from the Lua config file
        timerColor = {}
        settings = dofile(configFile)
        if not settings[script] then
            settings[script] = {}
        settings[script] = defaults end
        timerColor = settings[script]
    end
    
    loadTheme()
    local newSetting = false
    if settings[script].locked == nil then
        settings[script].locked = false
        newSetting = true
    end
    
    if settings[script].Scale == nil then
        settings[script].Scale = 1
        newSetting = true
    end
    
    if not settings[script].LoadTheme then
        settings[script].LoadTheme = theme.LoadTheme
        newSetting = true
    end
    
    if settings[script].IconSize == nil then
        settings[script].IconSize = iconSize
        newSetting = true
    end
    
    if settings[script].ShowIcons == nil then
        settings[script].ShowIcons = ShowIcons
        newSetting = true
    end
    
    if settings[script].ShowText == nil then
        settings[script].ShowText = ShowText
        newSetting = true
    end
    
    if settings[script].ShowTimer == nil then
        settings[script].ShowTimer = ShowTimer
        newSetting = true
    end

    if settings[script].SplitWin == nil then
        settings[script].SplitWin = SplitWin
        newSetting = true
    end

    if settings[script].BuffTimer == nil then
        settings[script].BuffTimer = buffTime
        newSetting = true
    end

    if not settings[script].TimerColor then
        settings[script].TimerColor = {}
        settings[script].TimerColor = {1,1,1,1}
        newSetting = true
    end

    if settings[script].SongTimer == nil then
        settings[script].SongTimer = songTimer
        newSetting = true
    end

    if settings[script].ShowScroll == nil then
        settings[script].ShowScroll = ShowScroll
        newSetting = true
    end
    
    timerColor = settings[script].TimerColor
    ShowScroll = settings[script].ShowScroll
    songTimer = settings[script].SongTimer
    buffTime = settings[script].BuffTimer
    SplitWin = settings[script].SplitWin
    ShowTimer = settings[script].ShowTimer
    ShowText = settings[script].ShowText
    ShowIcons = settings[script].ShowIcons
    iconSize = settings[script].IconSize
    locked = settings[script].locked
    Scale = settings[script].Scale
    themeName = settings[script].LoadTheme
    
    if newSetting then writeSettings(configFile, settings) end
end

--- comments Gets the duration of a spell or song and returns the duration in HH:MM:SS format
---@param i integer -- Spell Slot Number
---@param type string -- 'song' or 'spell'
---@param tooltip boolean -- is this for a tooltip if so we will display hours as well otherwise we chop it down to minutes and seconds
---@return string -- time formated
local function getDuration(i, type, tooltip)
    local remaining = 0
    if type == 'song' then
        remaining = SONG(i).Duration() or 0
        elseif type == 'spell' then
        remaining = BUFF(i).Duration() or 0
    end
    remaining = remaining / 1000 -- convert to seconds
    -- Calculate hours, minutes, and seconds
    local h = math.floor(remaining / 3600) or 0
    remaining = remaining % 3600 -- remaining seconds after removing hours
    local m = math.floor(remaining / 60) or 0
    local s = remaining % 60     -- remaining seconds after removing minutes
    -- Format the time string as H : M : S
    local sRemaining = string.format("%02d:%02d:%02d", h, m, s)
    if not tooltip then
        sRemaining = string.format("%02d:%02d", m, s)
    end
    return sRemaining
end

--- comments
---@param iconID integer
---@param spell MQSpell
---@param i integer
local function DrawInspectableSpellIcon(iconID, spell, i)
    local cursor_x, cursor_y = ImGui.GetCursorPos()
    local beniColor = IM_COL32(0,20,180,190) -- blue benificial default color
    animSpell:SetTextureCell(iconID or 0)
    if not spell.Beneficial() then
        beniColor = IM_COL32(255,0,0,190) --red detrimental
    end
    ImGui.GetWindowDrawList():AddRectFilled(ImGui.GetCursorScreenPosVec() + 1,
    ImGui.GetCursorScreenPosVec() + iconSize, beniColor)
    ImGui.SetCursorPos(cursor_x+3, cursor_y+3)
    ImGui.DrawTextureAnimation(animSpell, iconSize - 5, iconSize - 5)
    ImGui.SetCursorPos(cursor_x+2, cursor_y+2)
    local sName = spell.Name() or '??'
    local sDur = spell.Duration.TotalSeconds() or 0
    ImGui.PushID(tostring(iconID) .. sName .. "_invis_btn")
    if sDur < 18 and sDur > 0 then
        local flashColor = IM_COL32(0, 0, 0, flashAlpha)
        ImGui.GetWindowDrawList():AddRectFilled(ImGui.GetCursorScreenPosVec() +1,
        ImGui.GetCursorScreenPosVec() + iconSize -4, flashColor)
    end
    ImGui.SetCursorPos(cursor_x, cursor_y)
    ImGui.InvisibleButton(sName, ImVec2(iconSize, iconSize), bit32.bor(ImGuiButtonFlags.MouseButtonRight))
    ImGui.PopID()
end

---comment
---@param tName string -- name of the theme to load form table
---@return integer, integer -- returns the new counter values 
local function DrawTheme(tName)
    local StyleCounter = 0
    local ColorCounter = 0
    for tID, tData in pairs(theme.Theme) do
        if tData.Name == tName then
            for pID, cData in pairs(theme.Theme[tID].Color) do
                ImGui.PushStyleColor(pID, ImVec4(cData.Color[1], cData.Color[2], cData.Color[3], cData.Color[4]))
                ColorCounter = ColorCounter + 1
            end
            if tData['Style'] ~= nil then
                if next(tData['Style']) ~= nil then
                    for sID, sData in pairs (theme.Theme[tID].Style) do
                        if sData.Size ~= nil then
                            ImGui.PushStyleVar(sID, sData.Size)
                            StyleCounter = StyleCounter + 1
                            elseif sData.X ~= nil then
                            ImGui.PushStyleVar(sID, sData.X, sData.Y)
                            StyleCounter = StyleCounter + 1
                        end
                    end
                end
            end
        end
    end
    return ColorCounter, StyleCounter
end

local counter = 0
local function MyBuffs(count)
    -- Width and height of each texture
    local windowWidth = ImGui.GetWindowContentRegionWidth()
    if riseT == true then
        flashAlphaT = flashAlphaT - 5
        elseif riseT == false then
        flashAlphaT = flashAlphaT + 5
    end
    if flashAlphaT == 128 then riseT = false end
    if flashAlphaT == 25 then riseT = true end
    if rise == true then
        flashAlpha = flashAlpha + 5
        elseif rise == false then
        flashAlpha = flashAlpha - 5
    end
    if flashAlpha == 128 then rise = false end
    if flashAlpha == 25 then rise = true end
    ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 0, 0)
    local sizeX , sizeY = ImGui.GetContentRegionAvail()
    
    -------------------------------------------- Buffs Section ---------------------------------
    ImGui.SeparatorText('Buffs')
    if not SplitWin then sizeY = sizeY *0.7 else sizeY = sizeY * 0.9 end
    if not ShowScroll then
        ImGui.BeginChild("MyBuffs", sizeX, sizeY, ImGuiChildFlags.Border, ImGuiWindowFlags.NoScrollbar)
        else
        ImGui.BeginChild("MyBuffs", sizeX, sizeY, ImGuiChildFlags.Border)
    end

    local numBuffs = ME.BuffCount() or 0
    counter = 0
    if ME.BuffCount() > 0 then
        local sName = ' '
        for i = 1, count do
            if counter == numBuffs then break end
            local sIcon = BUFF(i).SpellIcon() or 0
            if BUFF(i) ~= nil and BUFF(i).Name() ~= nil then
                ImGui.BeginGroup()
                sName = BUFF(i).Name()
                ----- Show Icons ----
                if ShowIcons then
                    DrawInspectableSpellIcon(sIcon, BUFF(i), i)
                    ImGui.SameLine()
                end
                local sDur = BUFF(i).Duration.TotalMinutes() or 0
                local sDurS = BUFF(i).Duration.TotalSeconds() or 0
                
                ---- Show Timer ----
                ImGui.PushStyleColor(ImGuiCol.Text,timerColor[1], timerColor[2], timerColor[3],timerColor[4])

                if sDur < buffTime then
                    if ShowTimer then ImGui.Text(' '..(getDuration(i, 'spell', false) or ' ')) end
                    else
                    ImGui.Text(' ')
                end
                ImGui.PopStyleColor()

                ---- Show Text ----
                ImGui.SameLine()
                if ShowText then ImGui.Text(' '..(BUFF(i).Name() or '')) end
                counter = counter + 1
                ImGui.EndGroup()

                if ImGui.IsItemHovered() then
                    if (ImGui.IsMouseReleased(1)) then
                        BUFF(i).Inspect()
                        if TLO.MacroQuest.BuildName()=='Emu' then
                            mq.cmdf("/nomodkey /altkey /notify BuffWindow Buff%s leftmouseup", i-1)
                        end
                    end
                    if ImGui.IsMouseDoubleClicked(0) then
                        BUFF(i).Remove()
                        if TLO.MacroQuest.BuildName()=='Emu' then
                            mq.cmdf("/nomodkey /notify BuffWindow Buff%s leftmouseup", i-1)
                        end
                    end
                    ImGui.BeginTooltip()
                    if sName ~= '' then
                        ImGui.Text(sName .. '\n' .. getDuration(i, 'spell', true))
                        else
                        ImGui.Text('none')
                    end
                    ImGui.EndTooltip()
                end

                else
                sName = ''
                ImGui.Dummy(iconSize,iconSize)
            end
        end
    end
    ImGui.EndChild()
    ImGui.PopStyleVar()
end

local function MySongs()
    -- Width and height of each texture
    local windowWidth = ImGui.GetWindowContentRegionWidth()

    ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 0, 0)
    local sizeX , sizeY = ImGui.GetContentRegionAvail()
    ImGui.SeparatorText('Songs')
    sizeX, sizeY = ImGui.GetContentRegionAvail()
    --------- Songs Section -----------------------
    if ShowScroll then
        ImGui.BeginChild("Songs", ImVec2(sizeX, sizeY - 2), ImGuiChildFlags.Border)
        else
        ImGui.BeginChild("Songs", ImVec2(sizeX, sizeY - 2), ImGuiChildFlags.Border, ImGuiWindowFlags.NoScrollbar)
    end
    if ME.CountSongs() > 0 then
        local sName = '?'
        for i = 1, ME.CountSongs() do
            ImGui.BeginGroup()
            local sIcon = SONG(i).SpellIcon() or 0
            if SONG(i) ~= nil and SONG(i).Name() ~= nil then
                sName = SONG(i).Name() or ''
                ----------- Show Icons ----------------
                if ShowIcons then
                    DrawInspectableSpellIcon(sIcon, SONG(i), i)
                    ImGui.SameLine()
                end

                ----------- Show Timers -------------------
                local sngDurS = SONG(i).Duration.TotalSeconds() or 0
                ImGui.PushStyleColor(ImGuiCol.Text,timerColor[1], timerColor[2], timerColor[3],timerColor[4])

                if sngDurS < songTimer then
                    if ShowTimer then ImGui.Text(' '..(getDuration(i, 'song', false) or ' ')) end
                    else
                    ImGui.Text(' ')
                end
                ImGui.PopStyleColor()
                ImGui.SameLine()
                
                ------------ Show Text -------------------
                if ShowText then ImGui.Text(' '..(SONG(i).Name() or '')) end
                else
                ImGui.Dummy(iconSize,iconSize)
            end
            ImGui.EndGroup()
            if ImGui.IsItemHovered() then
                if (ImGui.IsMouseReleased(1)) then
                    BUFF(i).Inspect()
                    if TLO.MacroQuest.BuildName()=='Emu' then
                        mq.cmdf("/nomodkey /altkey /notify ShortDurationBuffWindow Buff%s leftmouseup", i-1)
                    end
                end
                if ImGui.IsMouseDragging(0, 15) then
                    BUFF(i).Remove()
                    if TLO.MacroQuest.BuildName()=='Emu' then
                        mq.cmdf("/nomodkey /notify ShortDurationBuffWindow Buff%s leftmouseup", i-1)
                    end
                end
                ImGui.BeginTooltip()
                ImGui.Text(sName .. '\n' .. getDuration(i, 'song', true))
                ImGui.EndTooltip()
            end
        end
    end
    
    ImGui.EndChild()
    ImGui.PopStyleVar()
end

local function GUI_Buffs(open)
    if not ShowGUI then return end
    if TLO.Me.Zoning() then return end
    ColorCount = 0
    StyleCount = 0
    -- Default window size
    ImGui.SetNextWindowSize(216, 239, ImGuiCond.FirstUseEver)
    local show = false
    local flags = winFlag
    if locked then
        flags = bit32.bor(ImGuiWindowFlags.NoMove, flags)
    end
    ColorCount, StyleCount = DrawTheme(themeName)
    open, show = ImGui.Begin("MyBuffs##"..ME.DisplayName(), open, flags)
    
    if not show then
        if StyleCount > 0 then ImGui.PopStyleVar(StyleCount) end
        if ColorCount > 0 then ImGui.PopStyleColor(ColorCount) end
        ImGui.SetWindowFontScale(1)
        ImGui.End()
        return open
    end

    if ImGui.BeginMenuBar() then
        if Scale > 1.25 then ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, 4,7) end
        local lockedIcon = locked and Icons.FA_LOCK .. '##lockTabButton_MyBuffs' or
        Icons.FA_UNLOCK .. '##lockTablButton_MyBuffs'
        if ImGui.Button(lockedIcon) then

            locked = not locked
            settings = dofile(configFile)
            settings[script].locked = locked
            writeSettings(configFile, settings)
        end
        if ImGui.IsItemHovered() then
            ImGui.BeginTooltip()
            ImGui.Text("Lock Window")
            ImGui.EndTooltip()
        end
        if ImGui.Button(gIcon..'##MyBuffsg') then
            openConfigGUI = not openConfigGUI
        end
        local splitIcon = SplitWin and Icons.FA_TOGGLE_ON ..'##MyBuffsSplit' or Icons.FA_TOGGLE_OFF ..'##MyBuffsSplit'
        if ImGui.Button(splitIcon) then
            SplitWin = not SplitWin
            settings = dofile(configFile)
            settings[script].SplitWin = SplitWin
            writeSettings(configFile, settings)
        end
        if ImGui.IsItemHovered() then
            ImGui.BeginTooltip()
            ImGui.Text("Split Songs into Separate Window")
            ImGui.EndTooltip()
        end
        ImGui.EndMenuBar()
    end
    ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, 4,3)
    ImGui.SetWindowFontScale(Scale)
    MyBuffs(MaxBuffs)
    if not SplitWin then MySongs() end

    if StyleCount > 0 then ImGui.PopStyleVar(StyleCount) else ImGui.PopStyleVar(1) end
    if ColorCount > 0 then ImGui.PopStyleColor(ColorCount) end

    ImGui.Spacing()
    ImGui.SetWindowFontScale(1)

    ImGui.End()
    return open
end

local function GUI_Songs(open)
    if not SplitWin then return end
    if TLO.Me.Zoning() then return end
    ColorCountSongs = 0
    StyleCountSongs = 0
    local flags = winFlag
    if locked then
        flags = bit32.bor(ImGuiWindowFlags.NoMove, flags)
    end
    if not ShowScroll then
        flags = bit32.bor(flags, ImGuiWindowFlags.NoScrollbar)
    end
    -- Default window size
    ImGui.SetNextWindowSize(216, 239, ImGuiCond.FirstUseEver)
    local show = false
    ColorCountSongs, StyleCountSongs = DrawTheme(themeName)
    open, show = ImGui.Begin("MyBuffs_Songs##Songs"..ME.DisplayName(), open, flags)
    ImGui.SetWindowFontScale(Scale)
    if not show then
        if StyleCountSongs > 0 then ImGui.PopStyleVar(StyleCountSongs) end
        if ColorCountSongs > 0 then ImGui.PopStyleColor(ColorCountSongs) end
        ImGui.SetWindowFontScale(1)
        ImGui.End()
        return open
    end
    
    MySongs()
    
    if StyleCountSongs > 0 then ImGui.PopStyleVar(StyleCountSongs) end
    if ColorCountSongs > 0 then ImGui.PopStyleColor(ColorCountSongs) end
    ImGui.Spacing()
    ImGui.SetWindowFontScale(1)
    ImGui.End()
    return open
end

local function MyBuffConf_GUI(open)
    if not openConfigGUI then return end
    ColorCountConf = 0
    StyleCountConf = 0
    ColorCountConf, StyleCountConf = DrawTheme(themeName)
    open, openConfigGUI = ImGui.Begin("MyBuffs Conf", open, bit32.bor(ImGuiWindowFlags.None, ImGuiWindowFlags.AlwaysAutoResize, ImGuiWindowFlags.NoCollapse))
    ImGui.SetWindowFontScale(Scale)
    if not openConfigGUI then
        openConfigGUI = false
        open = false
        if StyleCountConf > 0 then ImGui.PopStyleVar(StyleCountConf) end
        if ColorCountConf > 0 then ImGui.PopStyleColor(ColorCountConf) end
        ImGui.SetWindowFontScale(1)
        ImGui.End()
        return open
    end
    ImGui.SameLine()
    ImGui.SeparatorText('Theme')
    local vis = ImGui.CollapsingHeader('Theme##Coll'..script)
    if vis then
    ImGui.Text("Cur Theme: %s", themeName)
    -- Combo Box Load Theme
    
    if ImGui.BeginCombo("Load Theme##MyBuffs", themeName) then
        ImGui.SetWindowFontScale(Scale)
        for k, data in pairs(theme.Theme) do
            local isSelected = data.Name == themeName
            if ImGui.Selectable(data.Name, isSelected) then
                theme.LoadTheme = data.Name
                themeName = theme.LoadTheme
                settings[script].LoadTheme = themeName
            end
        end
        ImGui.EndCombo()
    end

    if ImGui.Button('Reload Theme File') then
        loadTheme()
    end
    end
    --------------------- Sliders ----------------------
    ImGui.SeparatorText('Scaling')
    local vis = ImGui.CollapsingHeader('Scaling##Coll'..script)
    if vis then
    -- Slider for adjusting zoom level
    local tmpZoom = Scale
    if Scale then
        tmpZoom = ImGui.SliderFloat("Text Scale##MyBuffs", tmpZoom, 0.5, 2.0)
    end
    if Scale ~= tmpZoom then
        Scale = tmpZoom
    end
    
    -- Slider for adjusting IconSize
    local tmpSize = iconSize
    if iconSize then
        tmpSize = ImGui.SliderInt("Icon Size##MyBuffs", tmpSize, 15, 50)
    end
    if iconSize ~= tmpSize then
        iconSize = tmpSize
    end
    end
    ImGui.SeparatorText('Timers')
    local vis = ImGui.CollapsingHeader('Timers##Coll'..script)
    if vis then
    ---- timer threshold adjustment sliders
    local tmpBuffTimer = buffTime
    if buffTime then
        tmpBuffTimer = ImGui.SliderInt("Buff Timer (Minutes)##MyBuffs", tmpBuffTimer, 1, 240)
    end
    
    if buffTime ~= tmpBuffTimer then
        buffTime = tmpBuffTimer
    end
    
    local tmpSongTimer = songTimer
    if songTimer then
        tmpSongTimer = ImGui.SliderInt("Song Timer (Seconds)##MyBuffs", tmpSongTimer, 1, 240)
    end
    
    if songTimer ~= tmpSongTimer then
        songTimer = tmpSongTimer
    end

    timerColor = ImGui.ColorPicker4('Timer Color', timerColor)
    end
    --------------------- input boxes --------------------
    
    ---------- Checkboxes ---------------------
    ImGui.SeparatorText('Toggles')
    local vis = ImGui.CollapsingHeader('Toggles##Coll'..script)
    if vis then
    local tmpShowText = ShowText
    tmpShowText = ImGui.Checkbox('Show Text', tmpShowText)
    if tmpShowText ~= ShowText then
        ShowText = tmpShowText
    end
    
    ImGui.SameLine()
    local tmpShowIcons = ShowIcons
    tmpShowIcons = ImGui.Checkbox('Show Icons', tmpShowIcons)
    if tmpShowIcons ~= ShowIcons then
        ShowIcons = tmpShowIcons
    end
    
    ImGui.SameLine()
    
    local tmpShowTimer = ShowTimer
    tmpShowTimer = ImGui.Checkbox('Show Timer', tmpShowTimer)
    if tmpShowTimer ~= ShowTimer then
        ShowTimer = tmpShowTimer
    end
    
    local tmpScroll = ShowScroll
    tmpScroll = ImGui.Checkbox('Show Scrollbar', tmpScroll)
    if tmpScroll ~= ShowScroll then
        ShowScroll = tmpScroll
    end
    ImGui.SameLine()
    
    local tmpSplit = SplitWin
    tmpSplit = ImGui.Checkbox('Split Win', tmpSplit)
    if tmpSplit ~= SplitWin then
        SplitWin = tmpSplit
    end
    end
    ImGui.SeparatorText('Save and Close')

    if ImGui.Button('Save and Close') then
        openConfigGUI = false
        settings = dofile(configFile)
        settings[script].TimerColor = timerColor
        settings[script].ShowScroll = ShowScroll
        settings[script].SongTimer = songTimer
        settings[script].BuffTimer = buffTime
        settings[script].IconSize = iconSize
        settings[script].Scale = Scale
        settings[script].LoadTheme = themeName
        settings[script].ShowIcons = ShowIcons
        settings[script].ShowText = ShowText
        settings[script].ShowTimer = ShowTimer
        writeSettings(configFile,settings)
    end
    if StyleCountConf > 0 then ImGui.PopStyleVar(StyleCountConf) end
    if ColorCountConf > 0 then ImGui.PopStyleColor(ColorCountConf) end
    ImGui.SetWindowFontScale(1)
    ImGui.End()
end

local function checkDebuff()
    local tmpDebuffed = debuffed
    if ME.Poisoned() or ME.Diseased() or ME.Dotted() or ME.Cursed() or ME.Corrupted() then
        tmpDebuffed = true
    end
    if tmpDebuffed ~= debuffed then
        debuffed = tmpDebuffed
        stateChanged = true
    else
        stateChanged = false
    end
    return stateChanged
end

local function recheckBuffs()
    local nTime = os.time()
    local bCount = ME.BuffCount() or 0
    -- if bCount > 0 or sCount > 0 then
        if (nTime - check > 120 or firstTime) or (bCount ~= lastBuffCount) or checkDebuff() then
            local lTarg = TLO.Target.ID() or -1
            mq.cmdf('/target id %s', ME.ID())
            mq.delay(1)
            if lTarg ~= -1 and lTarg ~= ME.ID() then
                mq.cmdf('/target id %s', lTarg)
            else
                mq.cmdf('/target clear')
            end
            check = os.time()
            if firstTime then firstTime = false end
            lastBuffCount = bCount
        end
    -- end

end

local function init()
    -- check for theme file or load defaults from our themes.lua
    loadSettings()
    mq.imgui.init('GUI_Buffs', GUI_Buffs)
    mq.imgui.init('GUI_Songs', GUI_Songs)
    mq.imgui.init('MyBuffConf_GUI', MyBuffConf_GUI)
end

local function MainLoop()
    while true do
        if TLO.Window('CharacterListWnd').Open() then return false end
        mq.delay(1)
        if ME.Zoning() then
            ShowGUI = false
            local flag = not ME.Zoning()
            mq.delay(9000, function() return not ME.Zoning() end)
            firstTime = true
            lastBuffCount = -1
            else
            ShowGUI = true
        end
        if not openGUI then
            return false
        end
        recheckBuffs()
    end
end

init()
printf("\ag %s \aw[\ayMyBuffs\aw] ::\a-t Loaded",TLO.Time())
printf("\ag %s \aw[\ayMyBuffs\aw] ::\a-t Right Click will inspect Buff",TLO.Time())
printf("\ag %s \aw[\ayMyBuffs\aw] ::\a-t Double Left Click will Remove the Buff",TLO.Time())
recheckBuffs()
MainLoop()

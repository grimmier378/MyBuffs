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
--local COLOR = require('colors.colors')
-- set variables
local animSpell = mq.FindTextureAnimation('A_SpellIcons')
local animItem = mq.FindTextureAnimation('A_DragItem')
local TLO = mq.TLO
local ME = TLO.Me
local BUFF = mq.TLO.Me.Buff
local SONG = mq.TLO.Me.Song
local winFlag = bit32.bor(ImGuiWindowFlags.NoScrollbar, ImGuiWindowFlags.MenuBar, ImGuiWindowFlags.NoScrollWithMouse)
local pulse = true
local iconSize = 24
local flashAlpha = 1
local flashAlphaT = 255
local flashAlphaS = 255
local rise, riseS, riseT, riseTs = true, true, true, true
local ShowGUI = true
local SplitWin = false
local openGUI = true
local songTimer, buffTime = 20, 5 -- timers for how many Minutes left before we show the timer. 
local ver = "v0.12"
local check = os.time()
local firstTime = true
local MaxBuffs = ME.MaxBuffSlots() or 0 --Max Buff Slots
local theme = {}
local ColorCount, ColorCountSongs, ColorCountConf = 0, 0, 0
local openConfigGUI = false
local themeFile = mq.configDir .. '/MyThemeZ.lua'
local configFile = mq.configDir .. '/MyUI_Configs.lua'
local ZoomLvl = 1.0
local gIcon = Icons.MD_SETTINGS
local locked, ShowIcons, ShowTimer, ShowText = false, true, true, true
local themeName = 'Default'
local script = 'MyBuffs'
local defaults, settings, temp = {}, {}, {}
defaults = {
        Scale = 1.0,
        LoadTheme = 'Default',
        locked = false,
        IconSize = 24,
        ShowIcons = true,
        ShowTimer = true,
        ShowText = true,
        SplitWin = false,
        SongTimer = 20, -- number of seconds remaining to trigger showing timer
        BuffTimer = 5,  -- number of minutes remaining to trigger showing timer
}


---comment Check to see if the file we want to work on exists.
---@param name string -- Full Path to file
---@return boolean -- returns true if the file exists and false otherwise
local function File_Exists(name)
    local f=io.open(name,"r")
    if f~=nil then io.close(f) return true else return false end
end


---comment Writes settings from the settings table passed to the setting file (full path required)
-- Uses mq.pickle to serialize the table and write to file
---@param file string -- File Name and path
---@param settings table -- Table of settings to write
local function writeSettings(file, settings)
    mq.pickle(file, settings)
end

local function loadTheme()
    if File_Exists(themeFile) then
        theme = dofile(themeFile)
    else
        theme = require('themes.lua')
    end
    themeName = theme.LoadTheme or 'notheme'
end

local function loadSettings()
    if not File_Exists(configFile) then
        mq.pickle(configFile, defaults)
        loadSettings()
    else

    -- Load settings from the Lua config file
    temp = {}
    settings = dofile(configFile)
    if not settings[script] then
        settings[script] = {}
        settings[script] = defaults end
        temp = settings[script]
    end

    loadTheme()

    if settings[script].locked == nil then
        settings[script].locked = false
    end

    if settings[script].Scale == nil then
        settings[script].Scale = 1
    end

    if not settings[script].LoadTheme then
        settings[script].LoadTheme = theme.LoadTheme
    end

    if settings[script].IconSize == nil then
        settings[script].IconSize = iconSize
    end

    if settings[script].ShowIcons == nil then
        settings[script].ShowIcons = ShowIcons
    end

    if settings[script].ShowText == nil then
        settings[script].ShowText = ShowText
    end

    if settings[script].ShowTimer == nil then
        settings[script].ShowTimer = ShowTimer
    end
    if settings[script].SplitWin == nil then
        settings[script].SplitWin = SplitWin
    end
    if settings[script].BuffTimer == nil then
        settings[script].BuffTimer = buffTime
    end
    if settings[script].SongTimer == nil then
        settings[script].SongTimer = songTimer
    end

    songTimer = settings[script].SongTimer
    buffTime = settings[script].BuffTimer
    SplitWin = settings[script].SplitWin
    ShowTimer = settings[script].ShowTimer
    ShowText = settings[script].ShowText
    ShowIcons = settings[script].ShowIcons
    iconSize = settings[script].IconSize
    locked = settings[script].locked
    ZoomLvl = settings[script].Scale
    themeName = settings[script].LoadTheme

    writeSettings(configFile, settings)

    temp = settings[script]
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
    -- local caster = BUFF(i).Caster() or '?' -- the caster of the Spell
    if not spell.Beneficial() then
        beniColor = IM_COL32(255,0,0,190) --red detrimental
    end
    -- if caster == mq.TLO.Me.DisplayName() then
    --     beniColor = IM_COL32(190,190,20,255) -- detrimental cast by me (yellow)
    -- end
    ImGui.GetWindowDrawList():AddRectFilled(ImGui.GetCursorScreenPosVec() + 1,
    ImGui.GetCursorScreenPosVec() + iconSize, beniColor)
    ImGui.SetCursorPos(cursor_x+3, cursor_y+3)
    -- if caster == ME.DisplayName() and spell.Beneficial() then
    --     ImGui.DrawTextureAnimation(animSpell, textureWidth - 6, textureHeight -6, true)
    --     else
        ImGui.DrawTextureAnimation(animSpell, iconSize - 5, iconSize - 5)
    -- end
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
---@param counter integer -- the counter used for this window to keep track of color changes
---@param themeName string -- name of the theme to load form table
---@return integer -- returns the new counter value 
local function DrawTheme(counter, themeName)
    -- Push Theme Colors
    for tID, tData in pairs(theme.Theme) do
        if tData.Name == themeName then
            for pID, cData in pairs(theme.Theme[tID].Color) do
                ImGui.PushStyleColor(pID, ImVec4(cData.Color[1], cData.Color[2], cData.Color[3], cData.Color[4]))
                counter = counter +1
            end
        end
    end
    return counter
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
    if not SplitWin then sizeY = sizeY *0.7 else sizeY = sizeY - 2 end
    ImGui.BeginChild("MyBuffs", ImVec2(sizeX, sizeY), ImGuiChildFlags.Border)
    ImGui.BeginTable('##MyBuffs'..ME.DisplayName(), 1, bit32.bor(ImGuiTableFlags.NoBordersInBody))
    ImGui.TableSetupColumn("##txt"..ME.DisplayName(), ImGuiTableColumnFlags.NoHeaderLabel)
    ImGui.TableNextRow()
    ImGui.TableSetColumnIndex(0)
    local numBuffs = ME.BuffCount() or 0
    counter = 0
    if ME.BuffCount() > 0 then
        local sName = ' '
        for i = 1, count do
            if counter == numBuffs then break end
            
            ImGui.BeginGroup()
            local sIcon = BUFF(i).SpellIcon() or 0
            if BUFF(i) ~= nil and BUFF(i).Name() ~= nil then
                sName = BUFF(i).Name()
                ----- Show Icons ----
                if ShowIcons then
                    DrawInspectableSpellIcon(sIcon, BUFF(i), i)
                    --ImGui.Dummy(textureHeight,textureWidth)
                    ImGui.SameLine()
                end
                local sDur = BUFF(i).Duration.TotalMinutes() or 0
                local sDurS = BUFF(i).Duration.TotalSeconds() or 0
    
                ---- Show Timer ----

                if sDurS < 18 and sDurS > 0 then
                    local flashColor = IM_COL32(255, 255, 255, flashAlphaT)
                    ImGui.PushStyleColor(ImGuiCol.Text,flashColor)
                end
                if sDur < buffTime then
                    if ShowTimer then ImGui.Text(' '..(getDuration(i, 'spell', false) or ' ')) end
                    else
                    ImGui.Text(' ')
                end
                ImGui.SameLine()
            
                if sDurS < 18 and sDurS > 0 then
                    local flashColor = IM_COL32(255, 255, 255, flashAlphaT)
                    ImGui.PushStyleColor(ImGuiCol.Text,flashColor)
                end

                if ShowText then ImGui.Text(' '..(BUFF(i).Name() or '')) end
                counter = counter + 1
                if sDurS < 18 and sDurS > 0 then
                    ImGui.PopStyleColor()
                end
            else
                sName = ''
                ImGui.Dummy(iconSize,iconSize)
            end

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
                    ImGui.Dummy(iconSize,iconSize)
                end
                ImGui.EndTooltip()
            end
            ImGui.TableNextRow()
            ImGui.TableSetColumnIndex(0)
        end
    end
    ImGui.EndTable()
    ImGui.EndChild()
    ImGui.PopStyleVar()
end

local function MySongs()
    -- Width and height of each texture
    local windowWidth = ImGui.GetWindowContentRegionWidth()
    if riseS == true then
        flashAlphaS = flashAlphaS - 5
        elseif riseS == false then
        flashAlphaS = flashAlphaS + 5
    end
    if flashAlphaS == 128 then riseS = false end
    if flashAlphaS == 25 then riseS = true end
    ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 0, 0)
    local sizeX , sizeY = ImGui.GetContentRegionAvail()
    ImGui.SeparatorText('Songs')
    sizeX, sizeY = ImGui.GetContentRegionAvail()
    --------- Songs Section -----------------------
    ImGui.BeginChild("Songs", ImVec2(sizeX, sizeY - 2), ImGuiChildFlags.Border)
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

                ------------ Show Text -------------------

                local sngDur = SONG(i).Duration.TotalMinutes() or 0
                local sngDurS = SONG(i).Duration.TotalSeconds() or 0
                if sngDurS < 18 and sngDurS > 0 then
                    local flashColorS = IM_COL32(255, 255, 255, flashAlphaS)
                    ImGui.PushStyleColor(ImGuiCol.Text,flashColorS)
                end
                ----------- Show Timers -------------------

                if sngDurS < songTimer then
                    if ShowTimer then ImGui.Text(' '..(getDuration(i, 'song', false) or ' ')) end
                    else
                    ImGui.Text(' ')
                end
                ImGui.SameLine()

                if ShowText then ImGui.Text(' '..(SONG(i).Name() or '')) end
                if sngDurS < 18 and sngDurS > 0 then
                    ImGui.PopStyleColor()
                end
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
end

local function GUI_Buffs(open)
    if not ShowGUI then return end
    if TLO.Me.Zoning() then return end
    ColorCount = 0
    --Rounded corners
    ImGui.PushStyleVar(ImGuiStyleVar.FrameRounding, 10)
    -- Default window size
    ImGui.SetNextWindowSize(216, 239, ImGuiCond.FirstUseEver)
    local show = false
    local flags = winFlag
    if locked then
        flags = bit32.bor(ImGuiWindowFlags.NoScrollbar, ImGuiWindowFlags.NoMove, ImGuiWindowFlags.MenuBar, ImGuiWindowFlags.NoScrollWithMouse)
    end
    ColorCount = DrawTheme(ColorCount, themeName)
    open, show = ImGui.Begin("MyBuffs##"..ME.DisplayName(), open, flags)
    ImGui.BeginGroup()
    if not show then
        ImGui.PopStyleVar()
        if ColorCount > 0 then ImGui.PopStyleColor(ColorCount) end
        ImGui.SetWindowFontScale(1)
        ImGui.End()
        return open
    end
    if ImGui.BeginMenuBar() then
        local lockedIcon = locked and Icons.FA_LOCK .. '##lockTabButton_MyBuffs' or
        Icons.FA_UNLOCK .. '##lockTablButton_MyBuffs'
        if ImGui.Button(lockedIcon) then
            --ImGuiWindowFlags.NoMove
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
    ImGui.SetWindowFontScale(ZoomLvl)
    MyBuffs(MaxBuffs)
    if not SplitWin then MySongs() end

    if ColorCount > 0 then ImGui.PopStyleColor(ColorCount) end
    ImGui.PopStyleVar()
    ImGui.Spacing()
    ImGui.SetWindowFontScale(1)
    ImGui.EndGroup()
    if ImGui.IsWindowHovered() then
        ImGui.SetWindowFocus("MyBuffs##"..ME.DisplayName())
    end
    ImGui.SetWindowFontScale(1)
    ImGui.End()
    return open
end

local function GUI_Songs(open)
    if not SplitWin then return end
    if TLO.Me.Zoning() then return end
    ColorCountSongs = 0
    --Rounded corners
    ImGui.PushStyleVar(ImGuiStyleVar.FrameRounding, 10)
    -- Default window size
    ImGui.SetNextWindowSize(216, 239, ImGuiCond.FirstUseEver)
    local show = false
    ColorCountSongs = DrawTheme(ColorCountSongs, themeName)
    open, show = ImGui.Begin("MyBuffs_Songs##Songs"..ME.DisplayName(), open, winFlag)
    ImGui.SetWindowFontScale(ZoomLvl)
    if not show then
        ImGui.PopStyleVar()
        if ColorCountSongs > 0 then ImGui.PopStyleColor(ColorCountSongs) end
        ImGui.SetWindowFontScale(1)
        ImGui.End()
        return open
    end

    MySongs()
    if ColorCountSongs > 0 then ImGui.PopStyleColor(ColorCountSongs) end
    ImGui.PopStyleVar()
    ImGui.Spacing()
    ImGui.SetWindowFontScale(1)
    ImGui.End()
    return open
end

local function MyBuffConf_GUI(open)
    if not openConfigGUI then return end
    ColorCountConf = 0
    ColorCountConf = DrawTheme(ColorCountConf, themeName)
    open, openConfigGUI = ImGui.Begin("MyBuffs Conf", open, bit32.bor(ImGuiWindowFlags.None, ImGuiWindowFlags.AlwaysAutoResize, ImGuiWindowFlags.NoCollapse))
    ImGui.SetWindowFontScale(ZoomLvl)
    if not openConfigGUI then
        openConfigGUI = false
        open = false
        if ColorCountConf > 0 then ImGui.PopStyleColor(ColorCountConf) end
        ImGui.SetWindowFontScale(1)
        ImGui.End()
        return open
    end
    ImGui.SameLine()

    ImGui.Text("Cur Theme: %s", themeName)
    -- Combo Box Load Theme
    if ImGui.BeginCombo("Load Theme##MyBuffs", themeName) then
        ImGui.SetWindowFontScale(ZoomLvl)
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

    --------------------- Sliders ----------------------

    -- Slider for adjusting zoom level
    local tmpZoom = ZoomLvl
    if ZoomLvl then
        tmpZoom = ImGui.SliderFloat("Zoom Level##MyBuffs", tmpZoom, 0.5, 2.0)
    end
    if ZoomLvl ~= tmpZoom then
        ZoomLvl = tmpZoom
    end
    
    -- Slider for adjusting IconSize
    local tmpSize = iconSize
    if iconSize then
        tmpSize = ImGui.SliderInt("Icon Size##MyBuffs", tmpSize, 15, 50)
    end
    if iconSize ~= tmpSize then
        iconSize = tmpSize
    end
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

    --------------------- input boxes --------------------

    ---------- Checkboxes ---------------------

    local tmpSplit = SplitWin
    tmpSplit = ImGui.Checkbox('Split Win', tmpSplit)
    if tmpSplit ~= SplitWin then
        SplitWin = tmpSplit
    end

    ImGui.SameLine()

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


    ImGui.SameLine()

    if ImGui.Button('close') then
        openConfigGUI = false
        settings = dofile(configFile)
        settings[script].SongTimer = songTimer
        settings[script].BuffTimer = buffTime
        settings[script].IconSize = iconSize
        settings[script].Scale = ZoomLvl
        settings[script].LoadTheme = themeName
        settings[script].ShowIcons = ShowIcons
        settings[script].ShowText = ShowText
        settings[script].ShowTimer = ShowTimer
        writeSettings(configFile,settings)
    end

    if ColorCountConf > 0 then ImGui.PopStyleColor(ColorCountConf) end
    ImGui.SetWindowFontScale(1)
    ImGui.End()

end

local function recheckBuffs()
    local nTime = os.time()
    if nTime - check > 6 or firstTime then
        local lTarg = mq.TLO.Target.ID() or -1
        mq.cmdf('/target id %s', mq.TLO.Me.ID())
        -- mq.delay(1)
        if lTarg ~= -1  then mq.cmdf('/target id %s', lTarg) end
        check = os.time()
        if firstTime then firstTime = false end
    end
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
            else
            ShowGUI = true
        end
        if not openGUI then
            -- openGUI = ShowGUI
            -- GUI_Buffs(openGUI)
            return false
        end
        recheckBuffs()
    end
end

init()
printf("\ag %s \aw[\ayMyBuffs\aw] ::\a-t Version \aw::\ay %s \at Loaded",TLO.Time(), ver)
printf("\ag %s \aw[\ayMyBuffs\aw] ::\a-t Right Click will inspect Buff",TLO.Time())
printf("\ag %s \aw[\ayMyBuffs\aw] ::\a-t Left Click and Drag will Remove the Buff",TLO.Time())
recheckBuffs()
MainLoop()

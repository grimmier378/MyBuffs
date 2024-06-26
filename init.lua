--[[
    Title: MyBuffs
    Author: Grimmier
    Description: stupidly simple buff window.
    Right Click to Inspect
    Left Click and Drag to remove a buff.
]]

-- Imports
local mq = require('mq')
local actors = require('actors')
local ImGui = require('ImGui')
local Icons = require('mq.ICONS')

-- TLO shortcuts
local TLO = mq.TLO
local ME = TLO.Me
local BUFF = mq.TLO.Me.Buff
local SONG = mq.TLO.Me.Song

-- Config Paths
local themeFileOld = mq.configDir .. '/MyThemeZ.lua'
local themeFile = mq.configDir .. '/MyUI/MyThemeZ.lua'
local configFileOld = mq.configDir .. '/MyUI_Configs.lua'
local configFile = mq.configDir .. '/MyUI/MyBuffs/'..ME.Name()..'_Config.lua'
-- Tables
local boxes = {}
local defaults, settings, timerColor, theme, buffs, songs = {}, {}, {}, {}, {}, {}

-- local Variables
local winFlag = bit32.bor(ImGuiWindowFlags.NoScrollbar, ImGuiWindowFlags.MenuBar, ImGuiWindowFlags.NoScrollWithMouse)
local iconSize = 24
local flashAlpha, flashAlphaT = 1, 255
local rise, riseT = true, true
local ShowGUI,  SplitWin, ShowConfig, MailBoxShow, ShowDebuffs = true,  false, false, false, false
local locked, ShowIcons, ShowTimer, ShowText, ShowScroll, DoPulse = false, true, true, true, true, true
local RUNNING, firstRun, changed, solo = true, true, false, true
local songTimer, buffTime = 20, 5 -- timers for how many Minutes left before we show the timer.
local numSlots = ME.MaxBuffSlots() or 0 --Max Buff Slots
local ColorCount, ColorCountSongs, ColorCountConf, StyleCount, StyleCountSongs, StyleCountConf = 0, 0, 0, 0, 0, 0
local Scale = 1.0
local build = mq.TLO.MacroQuest.BuildName()
local animSpell = mq.FindTextureAnimation('A_SpellIcons')
local gIcon = Icons.MD_SETTINGS
local activeButton = mq.TLO.Me.Name()  -- Initialize the active button with the first box's name
local PulseSpeed = 5
local Actor
local script = 'MyBuffs'
local themeName = 'Default'
local mailBox = {}
-- Timing Variables
local lastTime = os.clock()
local checkIn = os.time()
local frameTime = 1 / 60
local debuffOnMe = {}

-- default config settings
defaults = {
    Scale = 1.0,
    LoadTheme = 'Default',
    locked = false,
    IconSize = 24,
    ShowIcons = true,
    ShowTimer = true,
    ShowText = true,
    DoPulse = true,
    PulseSpeed = 5,
    ShowScroll = true,
    SplitWin = false,
    SongTimer = 20,
    ShowDebuffs = false,
    BuffTimer = 5,
    TimerColor = {0,0,0,1},
}

-- Functions

---comment
---@param songsTable table
---@param buffsTable table
---@return table
local function GenerateContent(subject,songsTable, buffsTable, doWho, doWhat)
    local dWho = doWho or nil
    local dWhat = doWhat or nil
    
    if subject == nil then subject = 'Update' end
    if #boxes == 0 or firstRun then
        subject = 'Hello'
        firstRun = false
    end

    local content = {
        Who = ME.DisplayName(),
        Buffs = buffsTable,
        Songs = songsTable,
        DoWho = dWho,
        Debuffs = debuffOnMe or nil,
        DoWhat = dWhat,
        BuffSlots = numSlots,
        BuffCount = ME.BuffCount(),
        Check = os.time(),
        Subject = subject
    }
    checkIn = os.time()
    return content
end

local function GetBuff(slot)
    local buffTooltip , buffName , buffDuration ,buffIcon, buffID, buffBeneficial,buffHr ,buffMin,buffSec, totalMin,totalSec, buffDurHMS
    if mq.TLO.MacroQuest.BuildName() == 'Emu' then
        buffTooltip = mq.TLO.Window('BuffWindow').Child('BW_Buff'..slot..'_Button').Tooltip() or ''
        buffName = buffTooltip ~= '' and buffTooltip:sub(1, buffTooltip:find('%(') - 2) or ''
        buffDuration = buffTooltip ~= '' and buffTooltip:sub(buffTooltip:find('%(') + 1, buffTooltip:find('%)') - 1) or ''
        buffIcon = mq.TLO.Me.Buff(slot+1).SpellIcon() or 0
        buffID = buffName ~= '' and  (mq.TLO.Me.Buff(slot+1).ID() or 0) or 0
        buffBeneficial = mq.TLO.Me.Buff(slot+1).Beneficial() or false

        -- Extract hours, minutes, and seconds from buffDuration
        buffHr, buffMin, buffSec = buffDuration:match("(%d+)h"), buffDuration:match("(%d+)m"), buffDuration:match("(%d+)s")
        buffHr = buffHr and string.format("%02d", tonumber(buffHr)) or "00"
        buffMin = buffMin and string.format("%02d", tonumber(buffMin)) or "00"
        buffSec = buffSec and string.format("%02d", tonumber(buffSec)) or "00"

        -- Calculate total minutes and total seconds
        totalMin = tonumber(buffHr) * 60 + tonumber(buffMin)
        totalSec = tonumber(totalMin) * 60 + tonumber(buffSec)
        -- print(totalSec)
        buffDurHMS = ''
        if buffHr  ~= "00" then
            buffDurHMS = buffHr .. ":".. buffMin .. ":" .. buffSec
        else
            buffDurHMS = buffMin .. ":" .. buffSec
        end
    else
        buffName = mq.TLO.Me.Buff(slot+1).Name() or ''
        buffDuration = mq.TLO.Me.Buff(slot+1).Duration.TimeHMS() or ''
        buffIcon = mq.TLO.Me.Buff(slot+1).SpellIcon() or 0
        buffID = mq.TLO.Me.Buff(slot+1).ID() or 0
        buffBeneficial = mq.TLO.Me.Buff(slot+1).Beneficial() or false
    
        -- Extract hours, minutes, and seconds from buffDuration
        buffHr = mq.TLO.Me.Buff(slot+1).Duration.Hours() or 0
        buffMin = mq.TLO.Me.Buff(slot+1).Duration.Minutes() or 0
        buffSec = mq.TLO.Me.Buff(slot+1).Duration.Seconds() or 0
    
        -- Calculate total minutes and total seconds
        totalMin = mq.TLO.Me.Buff(slot+1).Duration.TotalMinutes() or 0
        totalSec = mq.TLO.Me.Buff(slot+1).Duration.TotalSeconds() or 0
        -- print(totalSec)
        buffDurHMS = mq.TLO.Me.Buff(slot+1).Duration.TimeHMS() or ''
        buffTooltip = string.format("%s) %s (%s)",slot+1, buffName, buffDurHMS)

    end

    if buffs[slot] ~= nil then
        if buffs[slot].ID ~= buffID  or (buffID > 0 and totalSec < 20) then changed = true end
    end
    if not buffBeneficial then
        if #debuffOnMe > 0 then
            local found = false
            for i = 1, #debuffOnMe do
                if debuffOnMe[i].ID == buffID then
                    found = true
                    break
                end
            end
            if not found then
                table.insert(debuffOnMe, {Name = buffName, Duration = buffDurHMS, Icon = buffIcon, ID = buffID, Hours = buffHr, Minutes = buffMin, Seconds = buffSec, TotalMinutes = totalMin, TotalSeconds = totalSec, Tooltip = buffTooltip})
            end
        else
            table.insert(debuffOnMe, {Name = buffName, Duration = buffDurHMS, Icon = buffIcon, ID = buffID, Hours = buffHr, Minutes = buffMin, Seconds = buffSec, TotalMinutes = totalMin, TotalSeconds = totalSec, Tooltip = buffTooltip})
        end
    end
    -- Duration = mq.TLO.Me.Buff(slot+1).Duration.TimeHMS()
    buffs[slot] = {Name = buffName, Beneficial = buffBeneficial, Duration = buffDurHMS, Icon = buffIcon, ID = buffID, Hours = buffHr, Minutes = buffMin, Seconds = buffSec, TotalMinutes = totalMin, TotalSeconds = totalSec, Tooltip = buffTooltip}
    -- printf('Slot: %d, Name: %s, Duration: %s, Icon: %d, ID: %d, Hours: %d, Minutes: %d, Seconds: %d, TotalMinutes: %d, TotalSeconds: %d', slot, buffName, buffDuration, buffIcon, buffID, buffHr, buffMin, buffSec, totalMin, totalSec)
end

local function GetSong(slot)
    local songTooltip, songName, songDuration, songIcon, songID, songBeneficial, songHr, songMin, songSec, totalMin, totalSec, songDurHMS
    songName = mq.TLO.Me.Song(slot+1).Name() or ''
    songIcon = mq.TLO.Me.Song(slot+1).SpellIcon() or 0
    songID = songName ~= '' and  (mq.TLO.Me.Song(slot+1).ID() or 0) or 0
    songBeneficial = mq.TLO.Me.Song(slot+1).Beneficial() or false
    totalMin = mq.TLO.Me.Song(slot+1).Duration.TotalMinutes() or 0
    totalSec = mq.TLO.Me.Song(slot+1).Duration.TotalSeconds() or 0

    if mq.TLO.MacroQuest.BuildName() == "Emu" then
        songTooltip = mq.TLO.Window('ShortDurationBuffWindow').Child('SDBW_Buff'..slot..'_Button').Tooltip() or ''
        if songTooltip:find('%(') then
            -- songName = mq.TLO.Me.Song(slot+1).Name() or '' --songTooltip ~= '' and songTooltip:sub(1, songTooltip:find('%(') - 2) or ''
            songDuration = songTooltip ~= '' and songTooltip:sub(songTooltip:find('%(') + 1, songTooltip:find('%)') - 1) or ''
        else
            -- songName = mq.TLO.Me.Song(slot+1).Name() or '' --songTooltip ~= '' and songTooltip:sub(1, songTooltip:find(':Permanent') - 1) or ''
            songDuration = '99h 99m 99s'
        end
        songHr, songMin, songSec = songDuration:match("(%d+)h"), songDuration:match("(%d+)m"), songDuration:match("(%d+)s")

        -- Extract hours, minutes, and seconds from songDuration

        songHr = songHr and string.format("%02d", tonumber(songHr)) or "00"
        songMin = songMin and string.format("%02d", tonumber(songMin)) or "00"
        songSec = songSec and string.format("%02d", tonumber(songSec)) or "99"

        -- Calculate total minutes and total seconds

        songDurHMS = ""
        if songHr  == "99" then
            songDurHMS = "Permanent"
            totalSec = 99999
        elseif songHr  ~= "00" then
            songDurHMS = songHr .. ":".. songMin .. ":" .. songSec
        else
            songDurHMS = songMin .. ":" .. songSec
        end
    else
        songDurHMS = mq.TLO.Me.Song(slot+1).Duration.TimeHMS() or ''
        songHr = mq.TLO.Me.Song(slot+1).Duration.Hours() or 0
        songMin = mq.TLO.Me.Song(slot+1).Duration.Minutes() or 0
        songSec = mq.TLO.Me.Song(slot+1).Duration.Seconds() or 0
        songTooltip = string.format("%s) %s (%s)",slot+1, songName, songDurHMS)
    end

    if songs[slot] ~= nil then
        if songs[slot].ID ~= songID and os.time() - checkIn >= 6 then changed = true end
    end
    -- Duration = mq.TLO.Me.Song(slot+1).Duration.TimeHMS()
    songs[slot] = {Name = songName, Beneficial = songBeneficial, Duration = songDurHMS, Icon = songIcon, ID = songID, Hours = songHr, Minutes = songMin, Seconds = songSec, TotalMinutes = totalMin, TotalSeconds = totalSec, Tooltip = songTooltip}
    -- printf('Slot: %d, Name: %s, Duration: %s, Icon: %d, ID: %d, Hours: %d, Minutes: %d, Seconds: %d, TotalMinutes: %d, TotalSeconds: %d', slot, songName, songDuration, songIcon, songID, songHr, songMin, songSec, totalMin, totalSec)
end

local function pulseIcon(speed)
    local currentTime = os.clock()
    if currentTime - lastTime < frameTime then
        return -- exit if not enough time has passed
    end

    lastTime = currentTime -- update the last time
    if riseT == true then
        flashAlphaT = flashAlphaT - speed
        elseif riseT == false then
        flashAlphaT = flashAlphaT + speed
    end
    if flashAlphaT == 200 then riseT = false end
    if flashAlphaT == 10 then riseT = true end
    if rise == true then
        flashAlpha = flashAlpha + speed
        elseif rise == false then
        flashAlpha = flashAlpha - speed
    end
    if flashAlpha == 200 then rise = false end
    if flashAlpha == 10 then rise = true end
end

local function CheckIn()
    local now = os.time()
    if now - checkIn >= 120 or firstRun then
        checkIn = now
        return true
    end
    return false
end

local function CheckStale()
    local now = os.time()
    local found = false
    for i = 1, #boxes do
        if boxes[1].Check == nil then
            table.remove(boxes, i)
            found = true
            break
        else
            if now - boxes[i].Check > 180 then
                table.remove(boxes, i)
                found = true
                break
            end
        end
    end
    if found then CheckStale() end
end

local function GetBuffs()
    changed = false
    local subject = 'Update'
    debuffOnMe = {}
    numSlots = ME.MaxBuffSlots() or 0
    for i = 0, numSlots -1 do
        GetBuff(i)
    end
    if mq.TLO.Me.CountSongs() > 0 then
        for i = 0, 19 do
            GetSong(i)
        end
    end
    if CheckIn() then changed = true subject = 'CheckIn' end
    if firstRun then subject = 'Hello' end
    if not solo then
        if changed or firstRun then
            Actor:send({mailbox='my_buffs'}, GenerateContent(subject,songs, buffs))
            changed = false
        else
            for i = 1, #boxes do
                if boxes[i].Who == ME.DisplayName() then
                    boxes[i].Buffs = buffs
                    boxes[i].Songs = songs
                    boxes[1].BuffSlots = numSlots
                    boxes[1].BuffCount = ME.BuffCount() or 0
                    boxes[1].Hello = false
                    boxes[i].Debuffs = debuffOnMe
                    break
                end
            end
        end
    else
        if boxes[1] == nil then
            table.insert(boxes, {
                Who = ME.DisplayName(),
                Buffs = buffs,
                Songs = songs,
                Check = os.time(),
                BuffSlots = numSlots,
                BuffCount = ME.BuffCount(),
                Debuffs = debuffOnMe,
            })
        else
            boxes[1].Buffs = buffs
            boxes[1].Songs = songs
            boxes[1].Who = ME.DisplayName()
            boxes[1].BuffCount = ME.BuffCount() or 0
            boxes[1].BuffSlots = numSlots
            boxes[1].Check = os.time()
            boxes[1].Debuffs = debuffOnMe
        end
    end
end

local function RegisterActor()
    Actor = actors.register('my_buffs', function(message)
        local MemberEntry = message()
        -- print('Received Message: ', MemberEntry.Who)
        local who = MemberEntry.Who or 'Unknown'
        local charBuffs = MemberEntry.Buffs or {}
        local charSongs = MemberEntry.Songs or {}
        local charSlots = MemberEntry.BuffSlots or 0
        local charCount = MemberEntry.BuffCount or 0
        local check = MemberEntry.Check or os.time()
        local doWho = MemberEntry.DoWho or 'N/A'
        local dowhat = MemberEntry.DoWhat or 'N/A'
        local found = false
        local debuffActor = MemberEntry.Debuffs or {}
        local subject = MemberEntry.Subject or 'Update'
        table.insert(mailBox, {Name = who, Subject = subject, Check = check, DoWho = doWho, DoWhat = dowhat, When = os.date("%H:%M:%S")})
        if #debuffActor == 0 then
            debuffActor = {}
        end
        if MemberEntry.Subject == 'Action' then
            if MemberEntry.DoWho ~= nil and MemberEntry.DoWhat ~= nil then
                if MemberEntry.DoWho == mq.TLO.Me.DisplayName() then 
                    local bID = MemberEntry.DoWhat:sub(5) or 0
                    if MemberEntry.DoWhat:find("^buff") then
                        mq.TLO.Me.Buff(bID).Remove()
                        GetBuffs()
                        elseif MemberEntry.DoWhat:find("^song") then
                        mq.TLO.Me.Song(bID).Remove()
                        GetBuffs()
                        elseif MemberEntry.DoWhat:find("blockbuff") then
                            bID = MemberEntry.DoWhat:sub(10) or 0
                            bID = mq.TLO.Spell(bID).ID()
                        mq.cmdf("/blockspell add me '%s'",bID)
                        GetBuffs()
                        elseif MemberEntry.DoWhat:find("blocksong") then
                            local bID = MemberEntry.DoWhat:sub(10) or 0
                            bID = mq.TLO.Spell(bID).ID()
                        mq.cmdf("/blockspell add me '%s'",bID)
                        GetBuffs()
                    end
                end
                return
            end
        end
        --New member connected if Hello is true. Lets send them our data so they have it.
        if MemberEntry.Subject == 'Hello' then
            check = os.time()
            if who ~= ME.DisplayName() then
                Actor:send({mailbox='my_buffs'}, GenerateContent('Welcome',songs, buffs))
            end
        end

        if MemberEntry.Subject == 'Goodbye' then
            check = 0
        end
        -- Process the rest of the message into the groupData table.
        if MemberEntry.Subject ~= 'Action' then
            for i = 1, #boxes do
                if boxes[i].Who == who then
                    boxes[i].Buffs = charBuffs
                    boxes[i].Songs = charSongs
                    boxes[i].Check = check
                    boxes[i].BuffSlots = charSlots
                    boxes[i].BuffCount = charCount
                    boxes[i].Debuffs = debuffActor
                    found = true
                    break
                end
            end
            if not found then
                table.insert(boxes, {
                    Who = who,
                    Buffs = charBuffs,
                    Songs = charSongs,
                    Check = check,
                    BuffSlots = charSlots,
                    BuffCount = charCount,
                    Debuffs = debuffActor,
                })
            end
        end
        if check == 0 then CheckStale() end
    end)
end

local function SayGoodBye()
    Actor:send({mailbox='my_buffs'}, {
    Subject = 'Goodbye',
    Who = ME.DisplayName(),
    Check = 0})
end

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
        if File_Exists(themeFileOld) then
            theme = dofile(themeFileOld)
            mq.pickle(themeFile, theme)
        else
            theme = require('themes')
            mq.pickle(themeFile, theme)
        end
    end
    themeName = theme.LoadTheme or 'notheme'
end

local function loadSettings()
    local newSetting = false
    if not File_Exists(configFile) then
        if File_Exists(configFileOld) then
            local tmp = dofile(configFileOld)
            settings[script] = tmp[script]
        else
            settings[script] = defaults
        end
        mq.pickle(configFile, settings)
        loadSettings()
        else
        
        -- Load settings from the Lua config file
        timerColor = {}
        settings = dofile(configFile)
        if settings[script] == nil then
            settings[script] = {}
        settings[script] = defaults 
        newSetting = true
        end
        timerColor = settings[script]
    end
    
    loadTheme()
    
    if settings[script].locked == nil then
        settings[script].locked = false
        newSetting = true
    end
    
    if settings[script].Scale == nil then
        settings[script].Scale = 1
        newSetting = true
    end

    if settings[script].DoPulse == nil then
        settings[script].DoPulse = true
        newSetting = true
    end
    
    if settings[script].PulseSpeed == nil then
        settings[script].PulseSpeed = 5
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

    if settings[script].ShowDebuffs == nil then
        settings[script].ShowDebuffs = ShowDebuffs
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

    PulseSpeed = settings[script].PulseSpeed
    DoPulse = settings[script].DoPulse
    timerColor = settings[script].TimerColor
    ShowScroll = settings[script].ShowScroll
    songTimer = settings[script].SongTimer
    buffTime = settings[script].BuffTimer
    SplitWin = settings[script].SplitWin
    ShowTimer = settings[script].ShowTimer
    ShowText = settings[script].ShowText
    ShowIcons = settings[script].ShowIcons
    ShowDebuffs = settings[script].ShowDebuffs
    iconSize = settings[script].IconSize
    locked = settings[script].locked
    Scale = settings[script].Scale
    themeName = settings[script].LoadTheme
    
    if newSetting then writeSettings(configFile, settings) end
end

--- comments
---@param iconID integer
---@param spell table
---@param i integer
local function DrawInspectableSpellIcon(iconID, spell, i)
    local cursor_x, cursor_y = ImGui.GetCursorPos()
    local beniColor = IM_COL32(0,20,180,190) -- blue benificial default color
    if iconID == 0 then
        ImGui.SetWindowFontScale(Scale)
        ImGui.TextDisabled("")
        ImGui.SetWindowFontScale(1)
        return
    end
    animSpell:SetTextureCell(iconID or 0)
    if not spell.Beneficial then
        beniColor = IM_COL32(255,0,0,190) --red detrimental

    end
    ImGui.GetWindowDrawList():AddRectFilled(ImGui.GetCursorScreenPosVec() + 1,
    ImGui.GetCursorScreenPosVec() + iconSize, beniColor)
    ImGui.SetCursorPos(cursor_x+3, cursor_y+3)
    ImGui.DrawTextureAnimation(animSpell, iconSize - 5, iconSize - 5)
    ImGui.SetCursorPos(cursor_x+2, cursor_y+2)
    local sName = spell.Name or '??'
    local sDur = spell.TotalSeconds or 0
    ImGui.PushID(tostring(iconID) .. sName .. "_invis_btn")
    if sDur < 18 and sDur > 0 and DoPulse then
        pulseIcon(PulseSpeed)
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

local function BoxBuffs(id)
    -- Width and height of each texture
    -- local windowWidth = ImGui.GetWindowContentRegionWidth()

    local boxChar = boxes[id].Who or '?'
    local boxBuffs = boxes[id].Buffs or {}
    local buffCount = boxes[id].BuffCount or 0
    local buffSlots = boxes[id].BuffSlots or 0

    local sizeX , sizeY = ImGui.GetContentRegionAvail()
    
    -------------------------------------------- Buffs Section ---------------------------------
    ImGui.SeparatorText(boxChar..' Buffs')
    if not SplitWin then sizeY = math.floor(sizeY *0.7) else sizeY = math.floor(sizeY * 0.9) end
    if not ShowScroll then
        ImGui.BeginChild("Buffs##"..boxChar, sizeX, sizeY, ImGuiChildFlags.Border, ImGuiWindowFlags.NoScrollbar)
        else
        ImGui.BeginChild("Buffs##"..boxChar, sizeX, sizeY, ImGuiChildFlags.Border)
    end
    for i = 0, buffSlots -1 do
        
        local bID
        local sDurT = ''
        ImGui.BeginGroup()
        if boxBuffs[i] == nil or boxBuffs[i].ID == 0 then
            ImGui.SetWindowFontScale(Scale)
            ImGui.TextDisabled(tostring(i+1))
            ImGui.SetWindowFontScale(1)
        else
            bID = boxBuffs[i].Name:sub(1,-1)
            sDurT = boxBuffs[i].Duration or ' '

            if ShowIcons then
                DrawInspectableSpellIcon(boxBuffs[i].Icon, boxBuffs[i], i+1)
                ImGui.SameLine()
            end
            if boxChar == mq.TLO.Me.DisplayName() then
                if ShowTimer then
                    local sDur = boxBuffs[i].TotalMinutes or 0
                    if sDur < buffTime then
                        ImGui.PushStyleColor(ImGuiCol.Text,timerColor[1], timerColor[2], timerColor[3],timerColor[4])
                        ImGui.Text(" %s ",sDurT)
                        ImGui.PopStyleColor()
                    else
                        ImGui.Text(' ')
                    end
                    ImGui.SameLine()
                end
            else
                if ShowTimer then
                    local sDur = boxBuffs[i].TotalSeconds or 0
                    if sDur < 20 then
                        ImGui.PushStyleColor(ImGuiCol.Text,timerColor[1], timerColor[2], timerColor[3],timerColor[4])
                        ImGui.Text(" %s ",sDurT)
                        ImGui.PopStyleColor()
                    else
                        ImGui.Text(' ')
                    end
                    ImGui.SameLine()
                end
            end

            if ShowText and boxBuffs[i].Name ~= ''  then
                ImGui.Text(boxBuffs[i].Name)
            end
        end
        ImGui.EndGroup()
        if ImGui.BeginPopupContextItem("##Buff"..tostring(i)) then
            if boxChar == mq.TLO.Me.DisplayName() then 
                if ImGui.MenuItem("Inspect##"..i) then
                    BUFF(i+1).Inspect()
                    if build =='Emu' then
                        mq.cmdf("/nomodkey /altkey /notify BuffWindow Buff%s leftmouseup", i)
                    end
                end
            end
            if ImGui.MenuItem("Block##"..i) then
                local what = string.format('blockbuff%s',bID)
                if not solo then
                    Actor:send({mailbox = 'my_buffs'}, GenerateContent('Action',songs, buffs, boxChar, what))
                else
                    bID = mq.TLO.Spell(bID).ID()
                    mq.cmdf("/blockspell add me '%s'",bID)
                end
            end
            if ImGui.MenuItem("Remove##"..i) then
                local what = string.format('buff%s',i+1)
                if not solo then
                    Actor:send({mailbox = 'my_buffs'}, GenerateContent('Action',songs, buffs, boxChar, what))
                else
                    mq.TLO.Me.Buff(i+1).Remove()
                end
            end
            ImGui.EndPopup()
        end
        if ImGui.IsItemHovered() then
            -- if (ImGui.IsMouseReleased(1)) then
            --     -- print(boxChar)
            --     if boxChar == mq.TLO.Me.DisplayName() then
            --     BUFF(i+1).Inspect()
            --     if build =='Emu' then
            --         mq.cmdf("/nomodkey /altkey /notify BuffWindow Buff%s leftmouseup", i)
            --     end
            -- end
            -- end
            if ImGui.IsMouseDoubleClicked(0) then
                local what = string.format('buff%s',i+1)
                
                -- print(what)
                if not solo then
                    Actor:send({mailbox = 'my_buffs'}, GenerateContent('Action',songs, buffs, boxChar, what))
                else
                    mq.TLO.Me.Buff(i+1).Remove()
                end
            end
            ImGui.BeginTooltip()
            if boxBuffs[i] ~= nil then
                if boxBuffs[i].Icon > 0 then
                    if boxChar == mq.TLO.Me.DisplayName() then
                        ImGui.Text(boxBuffs[i].Tooltip)
                    else
                        ImGui.Text(boxBuffs[i].Name)
                    end
                else
                    ImGui.SetWindowFontScale(Scale)
                    ImGui.Text('none')
                    ImGui.SetWindowFontScale(1)
                end
            else
                ImGui.SetWindowFontScale(Scale)
                ImGui.Text('none')
                ImGui.SetWindowFontScale(1)
            end
            ImGui.EndTooltip()
        end
    end
    ImGui.EndChild()
end

local function BoxSongs(id)
    -- Width and height of each texture
    if #boxes == 0 then return end
    -- if sCount <= 0 then return end
    -- local windowWidth = ImGui.GetWindowContentRegionWidth()
    local boxChar = boxes[id].Who or '?'
    local boxSongs = boxes[id].Songs or {}
    local sCount = #boxes[id].Songs or 0
    local sizeX , sizeY = ImGui.GetContentRegionAvail()
    ImGui.SeparatorText(boxChar..' Songs##'..boxChar)
    sizeX, sizeY = ImGui.GetContentRegionAvail()
    sizeX, sizeY = math.floor(sizeX), math.floor(sizeY)

    --------- Songs Section -----------------------
    if ShowScroll then
        ImGui.BeginChild("Songs##"..boxChar, ImVec2(sizeX, sizeY - 2), ImGuiChildFlags.Border)
        else
        ImGui.BeginChild("Songs##"..boxChar, ImVec2(sizeX, sizeY - 2), ImGuiChildFlags.Border, ImGuiWindowFlags.NoScrollbar)
    end
    local counterSongs = 1
    for i = 0, 19 do
        if counterSongs > sCount then break end
        -- local songs[i] = songs[i] or nil
        local sID
        local sDurT = ''
        ImGui.BeginGroup()
        if boxSongs[i] == nil or boxSongs[i].ID == 0 then
            ImGui.SetWindowFontScale(Scale)
            ImGui.TextDisabled("")
            ImGui.SetWindowFontScale(1)
        else
            sID = boxSongs[i].Name:sub(1,-1)
            sID = tostring(mq.TLO.Spell('"'..sID..'"').ID())
            sDurT = boxSongs[i].Duration or ""
            if ShowIcons then
                DrawInspectableSpellIcon(boxSongs[i].Icon, boxSongs[i], i)
                ImGui.SameLine()
            end
            if boxChar == mq.TLO.Me.DisplayName() then
                if ShowTimer then
                    local sngDurS = boxSongs[i].TotalSeconds or 0
                    if sngDurS < songTimer then 
                        ImGui.PushStyleColor(ImGuiCol.Text,timerColor[1], timerColor[2], timerColor[3],timerColor[4])
                        ImGui.Text(" %ss ",sngDurS)
                        ImGui.PopStyleColor()
                    else
                        ImGui.Text(' ')
                    end
                    ImGui.SameLine()    
                end
            end
            if ShowText then
                ImGui.Text(boxSongs[i].Name)
            end
            counterSongs = counterSongs + 1  
        end
        ImGui.EndGroup()
        if ImGui.BeginPopupContextItem("##Song"..tostring(i)) then
            if ImGui.MenuItem("Inspect##"..i) then
                SONG(i+1).Inspect()
                if build =='Emu' then
                    mq.cmdf("/nomodkey /altkey /notify ShortDurationBuffWindow Buff%s leftmouseup", i)
                end
            end
            if ImGui.MenuItem("Block##"..i) then
                local what = string.format('blocksong%s',sID)
                if not solo then
                    Actor:send({mailbox = 'my_buffs'}, GenerateContent('Action',songs, buffs, boxChar, what))
                else
                    sID = mq.TLO.Spell(sID).ID()
                    mq.cmdf("/blockspell add me '%s'",sID)
                end
            end
            if ImGui.MenuItem("Remove##"..i) then
                local what = string.format('song%s',i+1)
                if not solo then
                    Actor:send({mailbox = 'my_buffs'}, GenerateContent('Action',songs, buffs, boxChar, what))
                else
                    mq.TLO.Me.Song(i+1).Remove()
                end
            end
            ImGui.EndPopup()
        end
        if ImGui.IsItemHovered() then
            -- if (ImGui.IsMouseReleased(1)) and boxes[id].Who == ME.DisplayName() then


            -- end
            if ImGui.IsMouseDoubleClicked(0) then

                if not solo then
                    Actor:send({mailbox = 'my_buffs'}, GenerateContent('Action',songs, buffs, boxChar, 'song'..i+1))
                else
                    mq.TLO.Me.Song(i+1).Remove()
                end
            end
            ImGui.BeginTooltip()
            if boxSongs[i] ~= nil then
                if boxSongs[i].Icon > 0 then
                    if boxChar == mq.TLO.Me.DisplayName() then
                        ImGui.Text(boxSongs[i].Tooltip)
                    else
                        ImGui.Text(boxSongs[i].Name)
                    end
                else
                    ImGui.SetWindowFontScale(Scale)
                    ImGui.Text('none')
                    ImGui.SetWindowFontScale(1)
                end
            else
                ImGui.SetWindowFontScale(Scale)
                ImGui.Text('none')
                ImGui.SetWindowFontScale(1)
            end
            ImGui.EndTooltip()
        end

    end
    ImGui.EndChild()

end

local function sortedBoxes(boxes)
    table.sort(boxes, function(a, b)
        return a.Who < b.Who
    end)
    return boxes
end

local function MyBuffsGUI_Buffs()
    if TLO.Me.Zoning() then return end
    -- Default window size

    if ShowGUI then
        ImGui.SetNextWindowSize(216, 239, ImGuiCond.FirstUseEver)
        local flags = winFlag
        if locked then
            flags = bit32.bor(ImGuiWindowFlags.NoMove, flags)
        end
        ColorCount, StyleCount = DrawTheme(themeName)
        local openGUI, showMain = ImGui.Begin("MyBuffs##"..ME.DisplayName(), true, flags)
        if not openGUI then
            ShowGUI = false
        end
        if showMain then
            if ImGui.BeginMenuBar() then
                -- if Scale > 1.25 then ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, 4,7) end
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
                    ShowConfig = not ShowConfig
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

            ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, 4, 3)
            ImGui.SetWindowFontScale(Scale)
            if not solo then
                if #boxes > 0 then
                    -- Sort boxes by the 'Who' attribute
                    local sorted_boxes = sortedBoxes(boxes)

                    local activeIndex = 0
                    for i = 1, #sorted_boxes do
                        if sorted_boxes[i].Who == activeButton then
                            activeIndex = i
                            break
                        end
                    end
                    ImGui.SetNextItemWidth(ImGui.GetWindowWidth()-15)
                    if ImGui.BeginCombo("##CharacterCombo", activeButton) then
                        for i = 1, #sorted_boxes do
                            local box = sorted_boxes[i]
                            if ImGui.Selectable(box.Who, activeButton == box.Who) then
                                activeButton = box.Who
                            end
                        end
                        ImGui.EndCombo()
                    end
                
                    -- Draw the content of the active button
                    for i = 1, #sorted_boxes do
                        if sorted_boxes[i].Who == activeButton then
                            ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 0, 0)
                            BoxBuffs(i)
                            if not SplitWin then BoxSongs(i) end
                            ImGui.PopStyleVar()
                            break
                        end
                    end
                end
            else
                ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 0, 0)
                BoxBuffs(1)
                if not SplitWin then BoxSongs(1) end
                ImGui.PopStyleVar()
            end
            ImGui.PopStyleVar()

        end

        if StyleCount > 0 then ImGui.PopStyleVar(StyleCount) end
        if ColorCount > 0 then ImGui.PopStyleColor(ColorCount) end
        ImGui.SetWindowFontScale(1)
        
        ImGui.End()
    end

    if SplitWin then
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
        ColorCountSongs, StyleCountSongs = DrawTheme(themeName)
        local songWin, show = ImGui.Begin("MyBuffs Songs##Songs"..ME.DisplayName(), true, flags)
        ImGui.SetWindowFontScale(Scale)
        if not songWin then
            SplitWin = false
        end
        if show then
            if #boxes > 0 then
                for i =1, #boxes do
                    local selected = ImGuiTabItemFlags.None
                    if boxes[i].Who == activeButton then 
                        BoxSongs(i)
                    end
                end
            end

            ImGui.SetWindowFontScale(1)
            ImGui.Spacing()
        end
        if StyleCountSongs > 0 then ImGui.PopStyleVar(StyleCountSongs) end
        if ColorCountSongs > 0 then ImGui.PopStyleColor(ColorCountSongs) end
        ImGui.SetWindowFontScale(1)
        ImGui.End()
    end

    if ShowConfig then
        ColorCountConf = 0
        StyleCountConf = 0
        ColorCountConf, StyleCountConf = DrawTheme(themeName)
        local openConfig, showConfigGui = ImGui.Begin("MyBuffs Conf", true, bit32.bor(ImGuiWindowFlags.None, ImGuiWindowFlags.AlwaysAutoResize, ImGuiWindowFlags.NoCollapse))
        ImGui.SetWindowFontScale(Scale)
        if not openConfig then
            ShowConfig  = false
        end
        if showConfigGui then
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
                timerColor = ImGui.ColorEdit4('Timer Color', timerColor, bit32.bor(ImGuiColorEditFlags.NoInputs))

            ---- timer threshold adjustment sliders
                local tmpBuffTimer = buffTime
                if buffTime then
                    ImGui.SetNextItemWidth(100)
                    tmpBuffTimer = ImGui.InputInt("Buff Timer (Minutes)##MyBuffs", tmpBuffTimer, 1, 600)
                end
                if tmpBuffTimer < 0 then tmpBuffTimer = 0 end
                if buffTime ~= tmpBuffTimer then
                    buffTime = tmpBuffTimer
                end
                
                local tmpSongTimer = songTimer
                if songTimer then
                    ImGui.SetNextItemWidth(100)
                    tmpSongTimer = ImGui.InputInt("Song Timer (Seconds)##MyBuffs", tmpSongTimer, 1, 600)
                end
                if tmpSongTimer < 0 then tmpSongTimer = 0 end
                if songTimer ~= tmpSongTimer then
                    songTimer = tmpSongTimer
                end
            end
            --------------------- input boxes --------------------
            
            ---------- Checkboxes ---------------------
            ImGui.SeparatorText('Toggles')
            local vis = ImGui.CollapsingHeader('Toggles##Coll'..script)
            if vis then
                local tmpShowIcons = ShowIcons
                tmpShowIcons = ImGui.Checkbox('Show Icons', tmpShowIcons)
                if tmpShowIcons ~= ShowIcons then
                    ShowIcons = tmpShowIcons
                end
                ImGui.SameLine()
                local tmpPulseIcons = DoPulse
                tmpPulseIcons = ImGui.Checkbox('Pulse Icons', tmpPulseIcons)
                if tmpPulseIcons ~= DoPulse then
                    DoPulse = tmpPulseIcons
                end
                local tmpPulseSpeed = PulseSpeed
                if DoPulse then
                    ImGui.SetNextItemWidth(100)
                    tmpPulseSpeed = ImGui.InputInt("Pulse Speed##MyBuffs", tmpPulseSpeed, 1, 10)
                end
                if PulseSpeed < 0 then PulseSpeed = 0 end
                if PulseSpeed ~= tmpPulseSpeed then
                    PulseSpeed = tmpPulseSpeed
                end

                ImGui.Separator()
                local tmpShowText = ShowText
                tmpShowText = ImGui.Checkbox('Show Text', tmpShowText)
                if tmpShowText ~= ShowText then
                    ShowText = tmpShowText
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
                MailBoxShow = ImGui.Checkbox('Show MailBox', MailBoxShow)
                ImGui.SameLine()
                ShowDebuffs = ImGui.Checkbox('Show Debuffs', ShowDebuffs)
            end

            ImGui.SeparatorText('Save and Close')

            if ImGui.Button('Save and Close') then
                settings = dofile(configFile)
                settings[script].DoPulse = DoPulse
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
                settings[script].ShowDebuffs = ShowDebuffs
                writeSettings(configFile,settings)

                ShowConfig = false
            end
        end
        if StyleCountConf > 0 then ImGui.PopStyleVar(StyleCountConf) end
        if ColorCountConf > 0 then ImGui.PopStyleColor(ColorCountConf) end
        ImGui.SetWindowFontScale(1)
        ImGui.End()
    end

    if ShowDebuffs then        
        local found = false
        ImGui.SetNextWindowSize(80, 239, ImGuiCond.Appearing)
        for i = 1 , #boxes do
            if #boxes[i].Debuffs > 1 then
                found = true
                break
            end
        end
        if found then
            ColorCountDebuffs, StyleCountDebuffs = DrawTheme(themeName)
            local openDebuffs, showDebuffs = ImGui.Begin("MyBuffs Debuffs##"..ME.DisplayName(), true, bit32.bor(ImGuiWindowFlags.AlwaysAutoResize))
            ImGui.SetWindowFontScale(Scale)

            if not openDebuffs then
                ShowDebuffs = false
            end
            if showDebuffs then
                for i = 1 , #boxes do
                    if #boxes[i].Debuffs > 1 then
                        if ImGui.BeginChild(boxes[i].Who.."##Debuffs_"..boxes[i].Who, 100, 60, bit32.bor(ImGuiChildFlags.Border, ImGuiChildFlags.AutoResizeX)) then
                            ImGui.Text(boxes[i].Who)
                            for k, v in pairs (boxes[i].Debuffs) do
                                if v.ID > 0 then
                                    DrawInspectableSpellIcon(v.Icon, v, k)
                                    ImGui.SetItemTooltip(v.Tooltip)
                                    ImGui.SameLine(0,0)
                                end
                            end
                        end
                        ImGui.EndChild()
                    end
                end
            end
            if StyleCountDebuffs > 0 then ImGui.PopStyleVar(StyleCountDebuffs) end
            if ColorCountDebuffs > 0 then ImGui.PopStyleColor(ColorCountDebuffs) end
            ImGui.SetWindowFontScale(1)
            ImGui.End()
        end
    end

    if MailBoxShow then
        local ColorCountMail, StyleCountMail = DrawTheme(themeName)
        local openMail, showMail = ImGui.Begin("MyBuffs MailBox##MailBox_MyBuffs_"..ME.Name(), true, ImGuiWindowFlags.None)
        if not openMail then
            MailBoxShow = false
            mailBox = {}
        end
        if showMail then
            ImGui.Text('Clear')
            if ImGui.IsItemHovered() and ImGui.IsMouseReleased(0) then
                ImGui.BeginTooltip()
                ImGui.Text("Clear Mail Box")
                ImGui.EndTooltip()
                mailBox = {}
            end
            ImGui.BeginTable("Mail Box##MyBuffs", 6, bit32.bor(ImGuiTableFlags.Borders,ImGuiTableFlags.Resizable,ImGuiTableFlags.ScrollY), ImVec2(0.0, 0.0))
            ImGui.TableSetupScrollFreeze(0, 1)
            ImGui.TableSetupColumn("Sender", ImGuiTableColumnFlags.WidthFixed, 100)
            ImGui.TableSetupColumn("Subject", ImGuiTableColumnFlags.WidthFixed, 100)
            ImGui.TableSetupColumn("TimeStamp", ImGuiTableColumnFlags.WidthFixed, 100)
            ImGui.TableSetupColumn("DoWho", ImGuiTableColumnFlags.WidthFixed, 100)
            ImGui.TableSetupColumn("DoWhat", ImGuiTableColumnFlags.WidthFixed, 100)
            ImGui.TableSetupColumn("CheckIn", ImGuiTableColumnFlags.WidthFixed, 100)
            ImGui.TableHeadersRow()
            for i = 1, #mailBox do
                ImGui.TableNextRow()
                ImGui.TableNextColumn()
                ImGui.Text(mailBox[i].Name)
                ImGui.TableNextColumn()
                ImGui.Text(mailBox[i].Subject)
                ImGui.TableNextColumn()
                ImGui.Text(mailBox[i].When)
                ImGui.TableNextColumn()
                ImGui.Text(mailBox[i].DoWho)
                ImGui.TableNextColumn()
                ImGui.Text(mailBox[i].DoWhat)
                ImGui.TableNextColumn()
                ImGui.Text(tostring(mailBox[i].Check))
            end
            ImGui.EndTable()
        end
        if StyleCountMail > 0 then ImGui.PopStyleVar(StyleCountMail) end
        if ColorCountMail > 0 then ImGui.PopStyleColor(ColorCountMail) end
        ImGui.End()
    else
        mailBox = {}
    end
end

local args = {...}
local function checkArgs(args)
    if #args > 0 then
        if args[1] == 'driver' then
            ShowGUI = true
            solo = false
            if args[2] ~= nil and args[2] == 'mailbox' then
                MailBoxShow = true
            end
            print('\ayMyBuffs:\ao Setting \atDriver\ax Mode. Actors [\agEnabled\ax] UI [\agOn\ax].')
            print('\ayMyBuffs:\ao Type \at/mybuffs show\ax. to Toggle the UI')
        elseif args[1] == 'client' then
            openGUI = false
            ShowGUI = false
            solo = false
            print('\ayMyBuffs:\ao Setting \atClient\ax Mode.Actors [\agEnabled\ax] UI [\arOff\ax].')
            print('\ayMyBuffs:\ao Type \at/mybuffs show\ax. to Toggle the UI')
        elseif args[1] == 'solo' then
            ShowGUI = true
            solo = true
            print('\ayMyBuffs:\ao Setting \atSolo\ax Mode. Actors [\arDisabled\ax] UI [\agOn\ax].')
            print('\ayMyBuffs:\ao Type \at/mybuffs show\ax. to Toggle the UI')
        end
    else
        ShowGUI = true
        solo = true
        print('\ayMyBuffs: \aoUse \at/lua run mybuffs client\ax To start with Actors [\agEnabled\ax] UI [\arOff\ax].')
        print('\ayMyBuffs: \aoUse \at/lua run mybuffs driver\ax To start with the Actors [\agEnabled\ax] UI [\agOn\ax].')
        print('\ayMyBuffs: \aoType \at/mybuffs show\ax. to Toggle the UI')
        print('\ayMyBuffs: \aoNo arguments passed, defaulting to \agSolo\ax Mode. Actors [\arDisabled\ax] UI [\agOn\ax].')
    end
end

local function processCommand(...)
    local args = {...}
    if #args > 0 then
        if args[1] == 'gui' or args[1] == 'show' or args[1] == 'open' then
            ShowGUI = not ShowGUI
            if ShowGUI then
                openGUI = true
                print('\ayMyBuffs:\ao Toggling GUI \atOpen\ax.')
            else
                print('\ayMyBuffs:\ao Toggling GUI \atClosed\ax.')
            end

        elseif args[1] == 'exit' or args[1] == 'quit'  then
            print('\ayMyBuffs:\ao Exiting.')
            if not solo then SayGoodBye() end
            RUNNING = false
        elseif args[1] == 'mailbox' then
            MailBoxShow = not MailBoxShow
        end
    else
        print('\ayMyBuffs:\ao No command given.')
        print('\ayMyBuffs:\ag /mybuffs gui \ao- Toggles the GUI on and off.')
        print('\ayMyBuffs:\ag /mybuffs exit \ao- Exits the plugin.')
    end
end

local function init()
    checkArgs(args)
    -- check for theme file or load defaults from our themes.lua
    loadSettings()
    if not solo then
        RegisterActor()
    end

    GetBuffs()
    firstRun = false

    mq.bind('/mybuffs', processCommand)
    mq.imgui.init('MyBuffsGUI_Buffs', MyBuffsGUI_Buffs)
end

local function MainLoop()
    while RUNNING do
        if mq.TLO.EverQuest.GameState() ~= "INGAME" then mq.exit() end
        if not solo then mq.delay(500) else mq.delay(33) end -- refresh faster if solo, otherwise every 1 second to report is reasonable
        while ME.Zoning() do
            mq.delay(9000, function() return not ME.Zoning() end)
        end

        if not RUNNING then
            return false
        end
        if not solo then CheckStale() end
        GetBuffs()
    end
end

if mq.TLO.EverQuest.GameState() ~= "INGAME" then mq.exit() end
init()
MainLoop()
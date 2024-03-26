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
local winFlag = bit32.bor(ImGuiWindowFlags.NoCollapse, ImGuiWindowFlags.NoScrollbar, ImGuiWindowFlags.NoScrollWithMouse)
local pulse = true
local textureWidth = 24
local textureHeight = 24
local flashAlpha = 1
local rise = true
local ShowGUI = true
local songTimer, buffTime = 0.75, 5 -- timers for how many Minutes left before we show the timer. 
local ver = "v0.5.Beta"
local check = os.time()
local firstTime = true
local MaxBuffs = ME.MaxBuffSlots() or 0 --Max Buff Slots


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


--[[
    Borrowed from rgmercs
    ~Thanks Derple
]]
---@param iconID integer
---@param spell MQSpell
---@param i integer
function DrawInspectableSpellIcon(iconID, spell, i)
    local cursor_x, cursor_y = ImGui.GetCursorPos()
    local beniColor = IM_COL32(0,20,180,190) -- blue benificial default color
    animSpell:SetTextureCell(iconID or 0)
    local caster = spell.Caster() or '?' -- the caster of the Spell
    if not spell.Beneficial() then
        beniColor = IM_COL32(255,0,0,190) --red detrimental
    end
    if caster == ME.DisplayName() and not spell.Beneficial() then
        beniColor = IM_COL32(190,190,20,255) -- detrimental cast by me (yellow)
    end
    ImGui.GetWindowDrawList():AddRectFilled(ImGui.GetCursorScreenPosVec() + 1,
    ImGui.GetCursorScreenPosVec() + textureHeight, beniColor)
    ImGui.SetCursorPos(cursor_x+3, cursor_y+3)
    if caster == ME.DisplayName() and spell.Beneficial() then
        ImGui.DrawTextureAnimation(animSpell, textureWidth - 6, textureHeight -6, true)
        else
        ImGui.DrawTextureAnimation(animSpell, textureWidth - 5, textureHeight - 5)
    end
    ImGui.SetCursorPos(cursor_x+2, cursor_y+2)
    local sName = spell.Name() or '??'
    local sDur = spell.Duration.TotalSeconds() or 0
    ImGui.PushID(tostring(iconID) .. sName .. "_invis_btn")
    if sDur < 18 and sDur > 0 then
        local flashColor = IM_COL32(0, 0, 0, flashAlpha)
        ImGui.GetWindowDrawList():AddRectFilled(ImGui.GetCursorScreenPosVec() +1,
        ImGui.GetCursorScreenPosVec() + textureHeight -4, flashColor)
    end
    ImGui.SetCursorPos(cursor_x, cursor_y)
    ImGui.InvisibleButton(sName, ImVec2(textureWidth, textureHeight), bit32.bor(ImGuiButtonFlags.MouseButtonRight))
    ImGui.PopID()
end

---@param type string
---@param txt string
function DrawStatusIcon(iconID, type, txt)
    animSpell:SetTextureCell(iconID or 0)
    animItem:SetTextureCell(iconID or 3996)
    if type == 'item' then
        ImGui.DrawTextureAnimation(animItem, textureWidth - 11, textureHeight - 11)
        elseif type == 'pwcs' then
        local animPWCS = mq.FindTextureAnimation(iconID)
        animPWCS:SetTextureCell(iconID)
        ImGui.DrawTextureAnimation(animPWCS, textureWidth - 11, textureHeight - 11)
        else
        ImGui.DrawTextureAnimation(animSpell, textureWidth - 11, textureHeight - 11)
    end
end

local counter = 0
local function MyBuffs(count)
    -- Width and height of each texture
    local windowWidth = ImGui.GetWindowContentRegionWidth()
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
    ImGui.BeginChild("MyBuffs", ImVec2(sizeX, sizeY *.7), ImGuiChildFlags.Border)
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
                DrawInspectableSpellIcon(sIcon, BUFF(i), i)
                ImGui.SameLine()
                local sDur = BUFF(i).Duration.TotalMinutes() or 0
                if sDur < buffTime then
                    ImGui.Text(' '..(getDuration(i, 'spell', false) or ' '))
                    else
                    ImGui.Text(' ')
                end
                ImGui.SameLine()
                ImGui.Text(' '..(BUFF(i).Name() or ''))
                counter = counter + 1
                else
                sName = ''
                ImGui.Dummy(textureWidth,textureHeight)
            end
            ImGui.EndGroup()
            if ImGui.IsItemHovered() then
                if (ImGui.IsMouseReleased(1)) then
                    BUFF(i).Inspect()
                    if TLO.MacroQuest.BuildName()=='Emu' then
                        mq.cmdf("/nomodkey /altkey /notify BuffWindow Buff%s leftmouseup", i-1)
                    end
                end
                if ImGui.IsMouseDragging(0, 15) then
                    BUFF(i).Remove()
                    if TLO.MacroQuest.BuildName()=='Emu' then
                        mq.cmdf("/nomodkey /notify BuffWindow Buff%s leftmouseup", i-1)
                    end
                end
                ImGui.BeginTooltip()
                if sName ~= '' then
                    ImGui.Text(sName .. '\n' .. getDuration(i, 'spell', true))
                    else
                    ImGui.Dummy(textureHeight,textureHeight)
                end
                ImGui.EndTooltip()
            end
        end
    end
    ImGui.EndChild()

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
                DrawInspectableSpellIcon(sIcon, SONG(i), i)
                ImGui.SameLine()
                local sngDur = SONG(i).Duration.TotalMinutes() or 0
                if sngDur < songTimer then
                    ImGui.Text(' '..(getDuration(i, 'song', false) or ' '))
                    else
                    ImGui.Text(' ')
                end
                ImGui.SameLine()
                ImGui.Text(' '..(SONG(i).Name() or ''))
                else
                ImGui.Dummy(textureWidth,textureHeight)
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

function GUI_Buffs(open)
    if not ShowGUI then return end
    if TLO.Me.Zoning() then return end
    --Rounded corners
    ImGui.PushStyleVar(ImGuiStyleVar.FrameRounding, 10)
    -- Default window size
    ImGui.SetNextWindowSize(216, 239, ImGuiCond.FirstUseEver)
    local show = false
    open, show = ImGui.Begin("MyBuffs##"..ME.DisplayName(), open, winFlag)
    if not show then
        ImGui.PopStyleVar()
        ImGui.End()
        return open
    end
    MyBuffs(MaxBuffs)
    ImGui.PopStyleVar()
    ImGui.Spacing()
    ImGui.End()
    return open
end

local function recheckBuffs()
    local nTime = os.time()
    if nTime - check > 5 or firstTime then
        local lTarg = mq.TLO.Target.ID() or -1
        mq.cmdf('/target id %s', mq.TLO.Me.ID())
        -- mq.delay(1)
        if lTarg ~= -1  then mq.cmdf('/target id %s', lTarg) end
        check = os.time()
        if firstTime then firstTime = false end
    end
end

local openGUI = true
ImGui.Register('GUI_Buffs', function()
    openGUI = GUI_Buffs(openGUI)
end)

local function MainLoop()
    while true do
        if TLO.Window('CharacterListWnd').Open() then return false end
        mq.delay(1)
        if ME.Zoning() then
            ShowGUI = false
            mq.delay(3000)
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

printf("\ag %s \aw[\ayMyBuffs\aw] ::\a-t Version \aw::\ay %s \at Loaded",TLO.Time(), ver)
printf("\ag %s \aw[\ayMyBuffs\aw] ::\a-t Right Click will inspect Buff",TLO.Time())
printf("\ag %s \aw[\ayMyBuffs\aw] ::\a-t Left Click and Drag will Remove the Buff",TLO.Time())
MainLoop()

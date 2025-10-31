-- Fix BigDebuffs for WOW Ascension modified by Hannahmckay

local InArena = InArena or function() return (select(2, IsInInstance()) == "arena") end

BigDebuffs.SpellsByName = {}

function BigDebuffs:BuildSpellNameTable()
    for spellId, spellData in pairs(self.Spells) do
        if type(spellId) == "number" then
            local spellName = GetSpellInfo(spellId)
            if spellName then
                if not self.SpellsByName[spellName] then
                    self.SpellsByName[spellName] = {}
                end
                
                for k, v in pairs(spellData) do
                    self.SpellsByName[spellName][k] = v
                end
                
                self.SpellsByName[spellName].originalId = spellId
            end
        end
    end
end


local TestDebuffs = {}

function BigDebuffs:InsertTestDebuff(spellID)
    local texture = select(3, GetSpellInfo(spellID))
    table.insert(TestDebuffs, {spellID, texture})
end


function UnitDebuffTest(unit, index)
    local debuff = TestDebuffs[index]
    if not debuff then return end
    return GetSpellInfo(debuff[1]), nil, debuff[2], 0, "Magic", 30, GetTime() + 30, nil, nil, nil, debuff[1]
end


local original_OnEnable = BigDebuffs.OnEnable
function BigDebuffs:OnEnable()
    self:BuildSpellNameTable()
    
    self:InsertTestDebuff(10890) -- Psychic Scream test
    
    if original_OnEnable then
        original_OnEnable(self)
    end
    
    BigDebuffs.TestDebuffs = TestDebuffs
end

function BigDebuffs:GetAuraPriority(name, id, unit)
    local spellData = self.Spells[id]
    
    if not spellData and name then
        spellData = self.SpellsByName[name]
        if spellData and spellData.originalId then
            id = spellData.originalId
        end
    end
    
    if not spellData then return end

    if spellData.parent then
        local parentData = self.Spells[spellData.parent]
        if parentData then
            id = spellData.parent
            spellData = parentData
        else
            local parentName = GetSpellInfo(spellData.parent)
            if parentName then
                parentData = self.SpellsByName[parentName]
                if parentData and parentData.originalId then
                    id = parentData.originalId
                    spellData = parentData
                end
            end
        end
    end

    if not self.db.profile.unitFrames[unit:gsub("%d", "")][spellData.type] then 
        return 
    end

    if self.db.profile.spells[id] then
        if self.db.profile.spells[id].unitFrames and self.db.profile.spells[id].unitFrames == 0 then 
            return 
        end
        if self.db.profile.spells[id].priority then 
            return self.db.profile.spells[id].priority 
        end
    end

    if spellData.nounitFrames and (not self.db.profile.spells[id] or not self.db.profile.spells[id].unitFrames) then
        return
    end

    return self.db.profile.priority[spellData.type] or 0
end

function BigDebuffs:UNIT_AURA(event, unit)
    if not self.db.profile.unitFrames.enabled
    or not unit
    or not self.db.profile.unitFrames[unit:gsub("%d", "")]
    or not self.db.profile.unitFrames[unit:gsub("%d", "")].enabled
    or not self.test and self.db.profile.unitFrames[unit:gsub("%d", "")].inArena and not InArena()
    then return end

    if unit == "player" then
        self:UNIT_AURA(nil, "playerFAKE")
    end

    self:AttachUnitFrame(unit)

    local frame = self.UnitFrames[unit]
    if not frame then return end

    if unit == "playerFAKE" then
        unit = string.gsub(unit, "%u", "")
    end

    local UnitDebuff = self.test and UnitDebuffTest or _G.UnitDebuff

    local now = GetTime()
    local left, priority, duration, expires, icon, isAura, interrupt, auraType, spellId = 0, 0

    for i = 1, 40 do
        local n, _, ico, _, _, d, e, caster, _, _, id = UnitDebuff(unit, i)
        if not n then break end
        
        if id and (self.Spells[id] or self.SpellsByName[n]) then
            local p = self:GetAuraPriority(n, id, unit)

            if p and p > priority or p == priority and e - now > left then
                left = e - now
                duration = d
                isAura = true
                priority = p
                expires = e
                icon = ico
                
                local spellData = self.Spells[id] or self.SpellsByName[n]
                if spellData then
                    if spellData.parent then
                        local parentData = self.Spells[spellData.parent]
                        if not parentData then
                            local parentName = GetSpellInfo(spellData.parent)
                            if parentName then
                                parentData = self.SpellsByName[parentName]
                            end
                        end
                        if parentData then
                            spellData = parentData
                        end
                    end
                    auraType = spellData.type
                end
                
                spellId = id
            end
        end
    end

    for i = 1, 40 do
        local n, _, ico, _, _, d, e, _, _, _, id = UnitBuff(unit, i)
        if not n then break end
        
        if id == 605 then break end
        
        if id and (self.Spells[id] or self.SpellsByName[n]) then
            local p = self:GetAuraPriority(n, id, unit)
            if p and p >= priority then
                if p and p > priority or p == priority and e - now > left then
                    left = e - now
                    duration = d
                    isAura = true
                    priority = p
                    expires = e
                    icon = ico
                    
                    local spellData = self.Spells[id] or self.SpellsByName[n]
                    if spellData then
                        if spellData.parent then
                            local parentData = self.Spells[spellData.parent]
                            if not parentData then
                                local parentName = GetSpellInfo(spellData.parent)
                                if parentName then
                                    parentData = self.SpellsByName[parentName]
                                end
                            end
                            if parentData then
                                spellData = parentData
                            end
                        end
                        auraType = spellData.type
                    end
                    
                    spellId = id
                end
            end
        end
    end

    local n, id, ico, d, e = self:GetInterruptFor(unit)
    if n then
        local p = self:GetAuraPriority(n, id, unit)
        if p and p > priority or p == priority and e - now > left then
            left = e - now
            duration = d
            isAura = true
            priority = p
            expires = e
            icon = ico
            auraType = "interrupts"
            spellId = id
        end
    end

    local guid = UnitGUID(unit)
    if self.stances and self.stances[guid] then
        local stanceId = self.stances[guid].stance
        if stanceId then
            local stanceName = GetSpellInfo(stanceId)
            if stanceName and (self.Spells[stanceId] or self.SpellsByName[stanceName]) then
                n, _, ico = GetSpellInfo(stanceId)
                local p = self:GetAuraPriority(n, stanceId, unit)
                if p and p >= priority then
                    left = 0
                    duration = 0
                    isAura = true
                    priority = p
                    expires = 0
                    icon = ico
                    
                    local spellData = self.Spells[stanceId] or self.SpellsByName[stanceName]
                    if spellData then
                        auraType = spellData.type
                    end
                    
                    spellId = stanceId
                end
            end
        end
    end

    if isAura then
        if frame.blizzard then
            SetPortraitToTexture(frame.icon, icon)
            
            local frameName = frame:GetName()
            if frameName then
                local fixes = {
                    BigDebuffsplayerUnitFrame = {PlayerPortrait, 0.5, -0.7},
                    BigDebuffsplayerFAKEUnitFrame = {PlayerPortrait, 0.5, -0.7},
                    BigDebuffspetUnitFrame = {PetPortrait, -1.4, -0.5, 1.5},
                    BigDebuffstargetUnitFrame = {TargetFramePortrait, -0.4, -0.7},
                    BigDebuffstargettargetUnitFrame = {TargetFrameToTPortrait, -0.1, -0.5, 4.2},
                    BigDebuffsfocusUnitFrame = {FocusFramePortrait, -0.4, -0.7},
                    BigDebuffsfocustargetUnitFrame = {FocusFrameToTPortrait, -0.1, -0.5, 4.2},
                }
                
                local fix = fixes[frameName]
                if fix then
                    local portrait, x, y, sizeAdd = fix[1], fix[2], fix[3], fix[4] or 0
                    if portrait then
                        frame:ClearAllPoints()
                        frame:SetPoint("CENTER", portrait, "CENTER", x, y)
                        frame:SetSize(portrait:GetHeight() + sizeAdd, portrait:GetWidth() + sizeAdd)
                    end
                end
            end
        else
            frame.icon:SetTexture(icon)
        end

        if auraType == "interrupts" then
            if frame.interruptBorder then
                local color = self.db.profile.unitFrames.interruptBorderColor or {1, 0, 0, 1}
                if color[4] > 0 then
                    frame.interruptBorder:SetVertexColor(color[1], color[2], color[3], color[4])
                    frame.interruptBorder:ClearAllPoints()
                    
                    local isGladiusFrame = frame:GetName() and (frame:GetName():match("arena%d") ~= nil) and unit:match("arena%d") ~= nil
                    
                    if isGladiusFrame then
                        frame.interruptBorder:SetWidth(frame:GetWidth() * 1.5)
                        frame.interruptBorder:SetHeight(frame:GetHeight() * 1.5)
                    else
                        frame.interruptBorder:SetWidth(frame:GetWidth() * 1.1)
                        frame.interruptBorder:SetHeight(frame:GetHeight() * 1.1)
                    end
                    frame.interruptBorder:SetPoint("CENTER", frame, "CENTER", 0, 0)
                    frame.interruptBorder:Show()
                else
                    frame.interruptBorder:Hide()
                end
            end
        else
            if frame.interruptBorder then
                frame.interruptBorder:Hide()
            end
        end

        -- Cooldown
        if duration > 0.2 then
            if self.db.profile.unitFrames.circleCooldown and frame.blizzard then
                frame.CircleCooldown:SetCooldown(expires - duration, duration)
                frame.cooldown:Hide()
            else
                frame.cooldown:SetCooldown(expires - duration, duration)
                frame.CircleCooldown:Hide()
            end

            if self.db.profile.unitFrames.hideCDanimation then
                frame.cooldown:SetAlpha(0)
                frame.CircleCooldown:SetAlpha(0)
            else
                frame.cooldown:SetAlpha(0.85)
                frame.CircleCooldown:SetAlpha(1)
            end

            if self.db.profile.unitFrames.customTimer then
                frame.timeEnd = (expires - duration) + duration
            else
                frame.timeEnd = GetTime()
            end

            frame.cooldownContainer:Show()
        else
            frame.timeEnd = GetTime()
            frame.cooldownContainer:Hide()
        end

        frame:Show()
        frame.current = icon
        frame.currentAuraType = auraType
        frame.currentSpellId = spellId
    else
        if frame.anchor and frame.blizzard and Adapt and Adapt.portraits[frame.anchor] then
            Adapt.portraits[frame.anchor].modelLayer:SetFrameStrata("LOW")
        else
            frame:Hide()
            frame.current = nil
            frame.currentAuraType = nil
            frame.currentSpellId = nil
            if frame.interruptBorder then
                frame.interruptBorder:Hide()
            end
        end
    end
end

local original_Test = BigDebuffs.Test
function BigDebuffs:Test()
    if original_Test then
        original_Test(self)
    end
    
    if self.test then
        print("|cff00ff00BigDebuffs Test Mode:|r ENABLED")
    else
        print("|cffff0000BigDebuffs Test Mode:|r DISABLED")
    end
end
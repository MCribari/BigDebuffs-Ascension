-- BigDebuffs Ascension Fix - Adaptation for Ascension/Bronzebeard server by Hannahmckay

local addonName, addon = ...

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("RAID_ROSTER_UPDATE")

-- OnUpdate loop 
local updateFrame = CreateFrame("Frame")
local pendingAttach = false

updateFrame:SetScript("OnUpdate", function(self, elapsed)
    if not pendingAttach or not _G.BigDebuffsInstance then return end
    
    local attached = 0
    for i = 1, 40 do
        local compactFrame = _G["CompactRaidFrame" .. i]
        if compactFrame and compactFrame.displayedUnit then
            local unit = compactFrame.displayedUnit
            if UnitExists(unit) and not compactFrame.BigDebuffs then
                pcall(function()
                    _G.BigDebuffsInstance:AddBigDebuffs(compactFrame)
                    attached = attached + 1
                end)
            end
        end
    end
    
    if attached > 0 then
        pendingAttach = false
    end
end)

local function EnableAttachLoop()
    pendingAttach = true
end

frame:SetScript("OnEvent", function(self, event, loadedAddon)
    if event == "ADDON_LOADED" then
        if loadedAddon ~= "BigDebuffs" then return end
        
        local BigDebuffs = LibStub("AceAddon-3.0"):GetAddon("BigDebuffs")
        if not BigDebuffs then return end
        
        BigDebuffs.SpellsByName = {}
        
        -- Build spell name table
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
        
        
        local original_OnEnable = BigDebuffs.OnEnable
        function BigDebuffs:OnEnable()
            self:BuildSpellNameTable()
            
            
            if original_OnEnable then
                original_OnEnable(self)
            end
            
            --loop raidframes
            EnableAttachLoop()
        end
        
        
        local function FixCooldownFrames()
            local cooldownMT = getmetatable(CreateFrame("Cooldown"))
            if cooldownMT and cooldownMT.__index then
                if not cooldownMT.__index.SetHideCountdownNumbers then
                    cooldownMT.__index.SetHideCountdownNumbers = function(self, hide)
                        self.noCooldownCount = hide
                    end
                end
            end
            
            if not _G.CompactUnitFrame_HideAllDebuffs then
                _G.CompactUnitFrame_HideAllDebuffs = function(compactFrame)
                    if compactFrame and compactFrame.debuffFrames then
                        for i = 1, #compactFrame.debuffFrames do
                            compactFrame.debuffFrames[i]:Hide()
                        end
                    end
                end
            end
            
            if not _G.CompactUnitFrame_UpdateAuras then
                _G.CompactUnitFrame_UpdateAuras = function(compactFrame)
                    if compactFrame then
                        if CompactUnitFrame_UpdateDebuffs then
                            CompactUnitFrame_UpdateDebuffs(compactFrame)
                        end
                        if CompactUnitFrame_UpdateBuffs then
                            CompactUnitFrame_UpdateBuffs(compactFrame)
                        end
                        if BigDebuffs and BigDebuffs.ShowBigDebuffs and compactFrame.BigDebuffs then
                            BigDebuffs:ShowBigDebuffs(compactFrame)
                        end
                    end
                end
            end
        end
        FixCooldownFrames()
        
        
        if CompactUnitFrame_SetUnit then
            hooksecurefunc("CompactUnitFrame_SetUnit", function(compactFrame, unit)
                if not compactFrame or not unit then return end
                if not UnitExists(unit) then return end
                if compactFrame.BigDebuffs then return end
                if not BigDebuffs then return end
                
                pcall(function()
                    BigDebuffs:AddBigDebuffs(compactFrame)
                end)
            end)
        end
        
        
        if CompactRaidFrameContainer_ApplyToFrames then
            hooksecurefunc("CompactRaidFrameContainer_ApplyToFrames", function()
                EnableAttachLoop()
            end)
        end
        
        
        if CompactUnitFrame_UpdateAll then
            hooksecurefunc("CompactUnitFrame_UpdateAll", function(compactFrame)
                if compactFrame and compactFrame.displayedUnit and not compactFrame.BigDebuffs and BigDebuffs then
                    pcall(function()
                        BigDebuffs:AddBigDebuffs(compactFrame)
                    end)
                end
            end)
        end
        
        
        local original_GetAuraPriority = BigDebuffs.GetAuraPriority
        function BigDebuffs:GetAuraPriority(id)
            local priority = original_GetAuraPriority(self, id)
            if priority then return priority end
            
            
            if not self.test and type(id) == "number" then
                local spellName = GetSpellInfo(id)
                if spellName and self.SpellsByName[spellName] then
                    local newId = self.SpellsByName[spellName].originalId
                    if newId and newId ~= id then
                        return original_GetAuraPriority(self, newId)
                    end
                end
            end
            
            return priority
        end
        
        
        local original_GetNameplatesPriority = BigDebuffs.GetNameplatesPriority
        function BigDebuffs:GetNameplatesPriority(id)
            local priority = original_GetNameplatesPriority(self, id)
            if priority then return priority end
            
            
            if not self.test and type(id) == "number" then
                local spellName = GetSpellInfo(id)
                if spellName and self.SpellsByName[spellName] then
                    local newId = self.SpellsByName[spellName].originalId
                    if newId and newId ~= id then
                        return original_GetNameplatesPriority(self, newId)
                    end
                end
            end
            
            return priority
        end
        
        
        local original_GetDebuffSize = BigDebuffs.GetDebuffSize
        function BigDebuffs:GetDebuffSize(id, dispellable)
            local size = original_GetDebuffSize(self, id, dispellable)
            if size then return size end
            
            if not self.test and type(id) == "number" then
                local spellName = GetSpellInfo(id)
                if spellName and self.SpellsByName[spellName] then
                    local newId = self.SpellsByName[spellName].originalId
                    if newId and newId ~= id then
                        return original_GetDebuffSize(self, newId, dispellable)
                    end
                end
            end
            
            return size
        end
        
        
        local original_GetDebuffPriority = BigDebuffs.GetDebuffPriority
        function BigDebuffs:GetDebuffPriority(id)
            local priority = original_GetDebuffPriority(self, id)
            if priority then return priority end
            
            if not self.test and type(id) == "number" then
                local spellName = GetSpellInfo(id)
                if spellName and self.SpellsByName[spellName] then
                    local newId = self.SpellsByName[spellName].originalId
                    if newId and newId ~= id then
                        return original_GetDebuffPriority(self, newId)
                    end
                end
            end
            
            return priority
        end
        
        
        local original_IsPriorityBigDebuff = BigDebuffs.IsPriorityBigDebuff
        function BigDebuffs:IsPriorityBigDebuff(id)
            local isPriority = original_IsPriorityBigDebuff(self, id)
            if isPriority then return isPriority end
            
            if not self.test and type(id) == "number" then
                local spellName = GetSpellInfo(id)
                if spellName and self.SpellsByName[spellName] then
                    local newId = self.SpellsByName[spellName].originalId
                    if newId and newId ~= id then
                        return original_IsPriorityBigDebuff(self, newId)
                    end
                end
            end
            
            return isPriority
        end
        
       
        local original_ShowBigDebuffs = BigDebuffs.ShowBigDebuffs
        function BigDebuffs:ShowBigDebuffs(frame)
            if not frame then return end
            
            
            if self.test then
                return original_ShowBigDebuffs(self, frame)
            end
            
            local unit = frame.displayedUnit or frame.unit
            if not unit then return end
            
            
            local foundAuras = {}
            
            
            for i = 1, 40 do
                local name, icon, count, debuffType, duration, expirationTime, caster, _, _, spellId = UnitDebuff(unit, i)
                if not name then break end
                
                local mappedId = spellId
                if spellId and not self.Spells[spellId] and self.SpellsByName[name] then
                    mappedId = self.SpellsByName[name].originalId
                end
                
                if mappedId then
                    local size = self:GetDebuffSize(mappedId, debuffType ~= "")
                    if size then
                        table.insert(foundAuras, {
                            name = name,
                            icon = icon,
                            count = count,
                            debuffType = debuffType,
                            duration = duration,
                            expirationTime = expirationTime,
                            caster = caster,
                            spellId = mappedId,
                            index = i,
                            isBuff = false,
                            size = size
                        })
                    end
                end
            end
            
            
            for i = 1, 40 do
                local name, icon, count, debuffType, duration, expirationTime, caster, _, _, spellId = UnitBuff(unit, i)
                if not name then break end
                
                local mappedId = spellId
                if spellId and not self.Spells[spellId] and self.SpellsByName[name] then
                    mappedId = self.SpellsByName[name].originalId
                end
                
                if mappedId then
                    local size = self:GetDebuffSize(mappedId, false)
                    if size then
                        table.insert(foundAuras, {
                            name = name,
                            icon = icon,
                            count = count,
                            debuffType = debuffType,
                            duration = duration,
                            expirationTime = expirationTime,
                            caster = caster,
                            spellId = mappedId,
                            index = i,
                            isBuff = true,
                            size = size
                        })
                    end
                end
            end
            
            
            if #foundAuras > 0 then
                original_ShowBigDebuffs(self, frame)
            else
                if frame.BigDebuffs then
                    for i = 1, #frame.BigDebuffs do
                        frame.BigDebuffs[i]:Hide()
                    end
                end
            end
        end
        
        
        if CompactUnitFrame_UpdateDebuffs then
            hooksecurefunc("CompactUnitFrame_UpdateDebuffs", function(frame)
                if frame and frame.BigDebuffs and BigDebuffs and not BigDebuffs.test then
                    BigDebuffs:ShowBigDebuffs(frame)
                end
            end)
        end
        
        hooksecurefunc(BigDebuffs, "UNIT_AURA", function(self, unit)
        
            if self.test then return end
            
            local frame = self.UnitFrames[unit]
            if not frame then return end
            
         
            if frame.current then return end
            
            
            local now = GetTime()
            local left, priority, duration, expires, icon, debuff, buff = 0, 0
            
            for i = 1, 40 do
                local name, _, ico, _, _, d, e, caster, _, _, id = UnitDebuff(unit, i)
                if not name then break end
                
                
                if id and not self.Spells[id] and self.SpellsByName[name] then
                    local mappedId = self.SpellsByName[name].originalId
                    if mappedId then
                        local p = self:GetAuraPriority(mappedId)
                        if p and p >= priority then
                            if p > priority or e == 0 or e - now > left then
                                left = e - now
                                duration = d
                                debuff = i
                                priority = p
                                expires = e
                                icon = ico
                            end
                        end
                    end
                end
            end
            
            for i = 1, 40 do
                local name, _, ico, _, _, d, e, caster, _, _, id = UnitBuff(unit, i)
                if not name then break end
                
                
                if id and not self.Spells[id] and self.SpellsByName[name] then
                    local mappedId = self.SpellsByName[name].originalId
                    if mappedId then
                        local p = self:GetAuraPriority(mappedId)
                        if p and p >= priority then
                            if p > priority or e == 0 or e - now > left then
                                left = e - now
                                duration = d
                                debuff = i
                                priority = p
                                expires = e
                                icon = ico
                                buff = true
                            end
                        end
                    end
                end
            end
            
            
            if debuff and not frame.current then
                if frame.blizzard then
                    frame.icon:SetTexture(icon)
                    frame.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                    frame.icon:Show()
                    frame.icon:SetAlpha(1)
                    SetPortraitToTexture(frame.icon, icon)
                else
                    frame.icon:SetTexture(icon)
                    frame.icon:SetTexCoord(0, 1, 0, 1)
                end
                
                CooldownFrame_Set(frame.cooldown, expires - duration, duration, true)
                frame:Show()
                frame:SetID(debuff)
                frame.buff = buff
                frame.current = icon
            end
        end)
        
        -- Hook to modify aura detection in UNIT_AURA_NAMEPLATE
        hooksecurefunc(BigDebuffs, "UNIT_AURA_NAMEPLATE", function(self, unit)
            if self.test then return end
            
            local frame = self.Nameplates[unit]
            if not frame then return end
            
            if frame.current then return end
            
            local now = GetTime()
            local left, priority, duration, expires, icon, debuff, buff, interrupt = 0, 0
            
            for i = 1, 40 do
                local name, _, ico, _, _, d, e, caster, _, _, id = UnitDebuff(unit, i)
                if not name then break end
                
                
                if id and not self.Spells[id] and self.SpellsByName[name] then
                    local mappedId = self.SpellsByName[name].originalId
                    if mappedId then
                        local reaction = caster and UnitReaction("player", caster) or 0
                        local friendlySmokeBomb = mappedId == 212183 and reaction > 4
                        local p = self:GetNameplatesPriority(mappedId)
                        if p and p >= priority and not friendlySmokeBomb then
                            if p > priority or self:IsPriorityBigDebuff(mappedId) or e == 0 or e - now > left then
                                left = e - now
                                duration = d
                                debuff = i
                                priority = p
                                expires = e
                                icon = ico
                            end
                        end
                    end
                end
            end
            
            for i = 1, 40 do
                local name, _, ico, _, _, d, e, caster, _, _, id = UnitBuff(unit, i)
                if not name then break end
                
                
                if id and not self.Spells[id] and self.SpellsByName[name] then
                    local mappedId = self.SpellsByName[name].originalId
                    if mappedId then
                        local p = self:GetNameplatesPriority(mappedId)
                        if p and p >= priority then
                            if p > priority or self:IsPriorityBigDebuff(mappedId) or e == 0 or e - now > left then
                                left = e - now
                                duration = d
                                debuff = i
                                priority = p
                                expires = e
                                icon = ico
                                buff = true
                            end
                        end
                    end
                end
            end
            
            
            if debuff and not frame.current then
                if duration < 1 then duration = 1 end
                
                frame.icon:SetTexture(icon)
                frame.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                frame.icon:Show()
                frame.icon:SetAlpha(1)
                
                frame.cooldown:SetCooldown(expires - duration, duration)
                frame:Show()
                
                frame:SetID(debuff)
                frame.buff = buff
                frame.interrupt = interrupt
                frame.current = icon
            end
        end)
        
        -- Hook Refresh position raid frames
        local original_Refresh = BigDebuffs.Refresh
        if original_Refresh then
            function BigDebuffs:Refresh()
                original_Refresh(self)
                
                for unit, attachedFrame in pairs(self.AttachedFrames) do
                    if attachedFrame and attachedFrame.BigDebuffs then
                        local max = self.db.profile.raidFrames.maxDebuffs + 1
                        
                        for i = 1, max do
                            local big = attachedFrame.BigDebuffs[i]
                            if big then
                                big:ClearAllPoints()
                                
                                if i > 1 then
                                    if self.db.profile.raidFrames.anchor == "INNER" or 
                                       self.db.profile.raidFrames.anchor == "RIGHT" or
                                       self.db.profile.raidFrames.anchor == "TOP" then
                                        big:SetPoint("BOTTOMLEFT", attachedFrame.BigDebuffs[i - 1], "BOTTOMRIGHT", 0, 0)
                                    elseif self.db.profile.raidFrames.anchor == "LEFT" then
                                        big:SetPoint("BOTTOMRIGHT", attachedFrame.BigDebuffs[i - 1], "BOTTOMLEFT", 0, 0)
                                    elseif self.db.profile.raidFrames.anchor == "BOTTOM" then
                                        big:SetPoint("TOPLEFT", attachedFrame.BigDebuffs[i - 1], "TOPRIGHT", 0, 0)
                                    end
                                else
                                    if self.db.profile.raidFrames.anchor == "INNER" then
                                        big:SetPoint("BOTTOMLEFT", attachedFrame.debuffFrames[1], "BOTTOMLEFT", 0, 0)
                                    elseif self.db.profile.raidFrames.anchor == "LEFT" then
                                        big:SetPoint("BOTTOMRIGHT", attachedFrame, "BOTTOMLEFT", 0, 1)
                                    elseif self.db.profile.raidFrames.anchor == "RIGHT" then
                                        big:SetPoint("BOTTOMLEFT", attachedFrame, "BOTTOMRIGHT", 0, 1)
                                    elseif self.db.profile.raidFrames.anchor == "TOP" then
                                        big:SetPoint("BOTTOMLEFT", attachedFrame, "TOPLEFT", 0, 1)
                                    elseif self.db.profile.raidFrames.anchor == "BOTTOM" then
                                        big:SetPoint("TOPLEFT", attachedFrame, "BOTTOMLEFT", 0, 1)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        
        -- Save
        _G.BigDebuffsInstance = BigDebuffs
        
        -- attach loop
        EnableAttachLoop()
        
        
        self:UnregisterEvent("ADDON_LOADED")
        
    elseif event == "GROUP_ROSTER_UPDATE" or event == "RAID_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
        
        EnableAttachLoop()
    end
end)
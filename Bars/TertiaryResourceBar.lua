local _, addonTable = ...

local LEM = addonTable.LEM or LibStub("LibEQOLEditMode-1.0")
local L = addonTable.L

local TertiaryResourceBarMixin = Mixin({}, addonTable.PowerBarMixin)

local CELESTIAL_SHIELD_SPELL_IDS = {
    322507, -- Celestial Brew
    1241059, -- Celestial Infusion
}

local function GetAuraAmountFromUnitAuras(spellId)
    if not UnitAura then
        return nil
    end

    for i = 1, 60 do
        local name, _, _, _, _, _, _, _, _, auraSpellId, _, _, _, _, _, _, value1, value2, value3 = UnitAura("player", i, "HELPFUL")
        if not name then break end
        if auraSpellId == spellId then
            local amount = value1
            if value2 and (not amount or value2 > amount) then
                amount = value2
            end
            if value3 and (not amount or value3 > amount) then
                amount = value3
            end
            return amount
        end
    end

    return nil
end

local function GetAuraAmountFromData(auraData)
    if not auraData then return nil end

    local points = auraData.points
    local amount = points and points[1]
    if amount and amount > 0 then
        return amount
    end

    amount = auraData.value
    if amount and amount > 0 then
        return amount
    end

    amount = auraData.amount
    if amount and amount > 0 then
        return amount
    end

    amount = auraData.absorb
    if amount and amount > 0 then
        return amount
    end

    return nil
end

local function GetCelestialShieldAmount()
    local auraFound = false

    for _, spellId in ipairs(CELESTIAL_SHIELD_SPELL_IDS) do
        local auraData = C_UnitAuras.GetPlayerAuraBySpellID(spellId)
        if auraData then
            auraFound = true
            local amount = GetAuraAmountFromData(auraData)
            if not amount or amount <= 0 then
                amount = GetAuraAmountFromUnitAuras(spellId)
            end
            if amount and amount > 0 then
                return amount
            end
        end
    end

    if not auraFound then
        return 0
    end

    -- Fallback: if the aura doesn't expose points, use total absorbs.
    return UnitGetTotalAbsorbs("player") or 0
end

function TertiaryResourceBarMixin:GetResource()
    local playerClass = select(2, UnitClass("player"))
    local tertiaryResources = {
        ["DEATHKNIGHT"] = nil,
        ["DEMONHUNTER"] = nil,
        ["DRUID"]       = nil,
        ["EVOKER"]      = {
            [1473] = "EBON_MIGHT", -- Augmentation
        },
        ["HUNTER"]      = nil,
        ["MAGE"]        = nil,
        ["MONK"]        = {
            [268] = "CELESTIAL_SHIELD", -- Brewmaster (Celestial Brew/Infusion shield)
        },
        ["PALADIN"]     = nil,
        ["PRIEST"]      = nil,
        ["ROGUE"]       = nil,
        ["SHAMAN"]      = nil,
        ["WARLOCK"]     = nil,
        ["WARRIOR"]     = nil,
    }

    local spec = C_SpecializationInfo.GetSpecialization()
    local specID = C_SpecializationInfo.GetSpecializationInfo(spec)

    local resource = tertiaryResources[playerClass]

    -- Druid: form-based
    if playerClass == "DRUID" then
        local formID = GetShapeshiftFormID()
        resource = resource and resource[formID or 0]
    end

    if type(resource) == "table" then
        resource = resource[specID]
    end

    -- VITALITY: hidden until Blizzard exposes the vitality amount via the API (aura 450521 points[1] stays 0)
    if resource == "VITALITY" then
        return nil
    end

    return resource
end

function TertiaryResourceBarMixin:GetResourceValue(resource)
    if not resource then return nil, nil end
    local data = self:GetData()
    if not data then return nil, nil end

    if resource == "EBON_MIGHT" then
        local auraData = C_UnitAuras.GetPlayerAuraBySpellID(395296) -- Ebon Might
        local current = auraData and (auraData.expirationTime - GetTime()) or 0
        local max = 20

        return max, current
    end

    if resource == "CELESTIAL_SHIELD" then
        local max = UnitHealthMax("player") or 1
        local current = GetCelestialShieldAmount()

        return max, current
    end

    if resource == "VITALITY" then
        -- Aspect of Harmony (450521): vitality amount is not exposed by the API (points[1] stays 0).
        -- Bar shows 0% until/if Blizzard exposes it; structure is ready (max = UnitHealthMax, current = points[1]).
        local auraData = C_UnitAuras.GetPlayerAuraBySpellID(450521)
        local current = (auraData and auraData.points and auraData.points[1]) or 0
        local max = UnitHealthMax("player") or 1

        return max, current
    end

    local current = UnitPower("player", resource)
    local max = UnitPowerMax("player", resource)
    if max <= 0 then return nil, nil, nil, nil end

    return max, current
end

function TertiaryResourceBarMixin:GetTagValues(resource, max, current, precision)
    local tagValues = addonTable.PowerBarMixin.GetTagValues(self, resource, max, current, precision)

    if resource == "EBON_MIGHT" then
        tagValues["[current]"] = function() return string.format("%.1f", AbbreviateNumbers(current)) end
    end

    if resource == "VITALITY" then
        local pFormat = "%." .. (precision or 0) .. "f"
        local percentStr = (max and max > 0) and string.format(pFormat, (current / max) * 100) or "0"
        tagValues["[percent]"] = function() return percentStr end
    end

    return tagValues
end

addonTable.TertiaryResourceBarMixin = TertiaryResourceBarMixin

addonTable.RegisteredBar = addonTable.RegisteredBar or {}
addonTable.RegisteredBar.TertiaryResourceBar = {
    mixin = addonTable.TertiaryResourceBarMixin,
    dbName = "tertiaryResourceBarDB",
    editModeName = L["TERNARY_POWER_BAR_EDIT_MODE_NAME"],
    frameName = "TertiaryResourceBar",
    frameLevel = 1,
    defaultValues = {
        point = "CENTER",
        x = 0,
        y = -80,
        useResourceAtlas = false,
    },
    allowEditPredicate = function()
        local playerClass = select(2, UnitClass("player"))
        local spec = C_SpecializationInfo.GetSpecialization()
        local specID = C_SpecializationInfo.GetSpecializationInfo(spec)
        return specID == 1473 -- Augmentation
            or (playerClass == "MONK" and specID == 268) -- Brewmaster (Celestial Shield)
    end,
    -- No loadPredicate: bar is created for all classes; visibility is by GetResource() (nil = hide).
    -- Evoker Augmentation shows EBON_MIGHT, Monk Brewmaster shows CELESTIAL_SHIELD; others see bar hidden.
    loadPredicate = nil,
    lemSettings = function(bar, defaults)
        local dbName = bar:GetConfig().dbName

        return {
            {
                parentId = L["CATEGORY_BAR_STYLE"],
                order = 401,
                name = L["USE_RESOURCE_TEXTURE_AND_COLOR"],
                kind = LEM.SettingType.Checkbox,
                default = defaults.useResourceAtlas,
                get = function(layoutName)
                    local data = SenseiClassResourceBarDB[dbName][layoutName]
                    if data and data.useResourceAtlas ~= nil then
                        return data.useResourceAtlas
                    else
                        return defaults.useResourceAtlas
                    end
                end,
                set = function(layoutName, value)
                    SenseiClassResourceBarDB[dbName][layoutName] = SenseiClassResourceBarDB[dbName][layoutName] or CopyTable(defaults)
                    SenseiClassResourceBarDB[dbName][layoutName].useResourceAtlas = value
                    bar:ApplyLayout(layoutName)
                end,
            },
        }
    end
}
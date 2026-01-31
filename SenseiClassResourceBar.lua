local addonName, addonTable = ...

------------------------------------------------------------
-- BAR FACTORY
------------------------------------------------------------
local function CreateBarInstance(config, parent, frameLevel)
    -- Initialize database
    if not SenseiClassResourceBarDB[config.dbName] then
        SenseiClassResourceBarDB[config.dbName] = {}
    end

    -- Create frame
    local bar = CreateFromMixins(config.mixin or addonTable.BarMixin)
    bar:Init(config, parent, frameLevel)

    -- Copy defaults if needed
    local curLayout = addonTable.LEM.GetActiveLayoutName() or "Default"
    if not SenseiClassResourceBarDB[config.dbName][curLayout] then
        SenseiClassResourceBarDB[config.dbName][curLayout] = CopyTable(bar.defaults)
    end

    bar:OnLoad()
    bar:GetFrame():SetScript("OnEvent", function(_, ...)
        bar:OnEvent(...)
    end)

    bar:ApplyVisibilitySettings()
    bar:ApplyLayout(true)
    bar:UpdateDisplay(true)

    return bar
end

------------------------------------------------------------
-- INITIALIZE BARS
------------------------------------------------------------
local function InitializeBar(config, frameLevel)
    local bar = CreateBarInstance(config, UIParent, math.max(0, frameLevel or 0))

    local defaults = CopyTable(addonTable.commonDefaults)
    for k, v in pairs(config.defaultValues or {}) do
        defaults[k] = v
    end

    local LEMSettingsLoader = CreateFromMixins(addonTable.LEMSettingsLoaderMixin)
    LEMSettingsLoader:Init(bar, defaults)
    LEMSettingsLoader:LoadSettings()

    return bar
end

local SCRB = CreateFrame("Frame")
SCRB:RegisterEvent("ADDON_LOADED")
SCRB:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        if not SenseiClassResourceBarDB then
            SenseiClassResourceBarDB = {}
        end

        addonTable.barInstances = addonTable.barInstances or {}

        for _, config in pairs(addonTable.RegisteredBar or {}) do
            if config.loadPredicate == nil or (type(config.loadPredicate) == "function" and config.loadPredicate(config) == true) then
                local frame = InitializeBar(config, config.frameLevel or 1)
                addonTable.barInstances[config.frameName] = frame
            end
        end

        addonTable.SettingsRegistrar()

        -- Debug: /scrb vitality or /scrb celestial — dump aura details to chat
        SLASH_SCRB1 = "/scrb"
        SlashCmdList["SCRB"] = function(msg)
            msg = msg and strlower(strtrim(msg)) or ""
            local p = addonTable.prettyPrint or print
            local function DumpAuraBySpellId(spellId, label)
                local found = false
                for i = 1, 60 do
                    local name, _, _, _, _, _, _, _, _, auraSpellId, _, _, _, _, _, _, value1, value2, value3 = UnitAura("player", i, "HELPFUL")
                    if not name then break end
                    if auraSpellId == spellId then
                        found = true
                        p(label .. " at buff index " .. i .. " | value1=" .. tostring(value1) .. " value2=" .. tostring(value2) .. " value3=" .. tostring(value3))
                        for vi = 16, 24 do
                            local v = select(vi, UnitAura("player", i, "HELPFUL"))
                            if v ~= nil then p("  return[" .. vi .. "]=" .. tostring(v)) end
                        end
                    end
                end
                if not found then
                    p(label .. " not found in UnitAura.")
                end

                local aura = C_UnitAuras.GetPlayerAuraBySpellID(spellId)
                if aura then
                    p("C_UnitAuras: " .. label .. " found. points[1]=" .. tostring(aura.points and aura.points[1]))
                    for k, v in pairs(aura) do
                        if type(v) == "table" then
                            p("  " .. tostring(k) .. "=table")
                            for ki, vi in pairs(v) do p("    [" .. tostring(ki) .. "]=" .. tostring(vi)) end
                        else
                            p("  " .. tostring(k) .. "=" .. tostring(v))
                        end
                    end
                else
                    p("C_UnitAuras: " .. label .. " not found.")
                end
            end

            if msg == "" or msg == "help" then
                print("|cffb5a707SenseiClassResourceBar:|r /scrb vitality or /scrb celestial - dump aura details")
                return
            end
            if msg == "vitality" or msg == "debug" then
                print("|cffb5a707SenseiClassResourceBar:|r vitality debug started.")
                DumpAuraBySpellId(450521, "Spell 450521")
                p("SCRB vitality debug done.")
            elseif msg == "celestial" or msg == "brew" or msg == "shield" then
                print("|cffb5a707SenseiClassResourceBar:|r celestial debug started.")
                DumpAuraBySpellId(322507, "Spell 322507")
                DumpAuraBySpellId(1241059, "Spell 1241059")
                p("UnitGetTotalAbsorbs: " .. tostring(UnitGetTotalAbsorbs("player")))
                p("SCRB celestial debug done.")
            end
        end
    end
end)

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
            local function DebugPrint(text)
                if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
                    DEFAULT_CHAT_FRAME:AddMessage("|cffb5a707SenseiClassResourceBar:|r " .. tostring(text))
                else
                    print("|cffb5a707SenseiClassResourceBar:|r " .. tostring(text))
                end
            end

            local function SafeCall(label, fn)
                if type(pcall) ~= "function" then
                    DebugPrint(label .. " error: pcall not available.")
                    return fn()
                end
                local ok, err = pcall(fn)
                if not ok then
                    DebugPrint(label .. " error: " .. tostring(err))
                end
                return ok, err
            end

            local function DumpAuraBySpellId(spellId, label)
                DebugPrint(label .. " scan started.")

                if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
                    local aura = C_UnitAuras.GetPlayerAuraBySpellID(spellId)
                    if aura then
                        DebugPrint("C_UnitAuras: found.")
                        DebugPrint("  points[1]=" .. tostring(aura.points and aura.points[1])
                            .. " value=" .. tostring(aura.value)
                            .. " amount=" .. tostring(aura.amount)
                            .. " absorb=" .. tostring(aura.absorb)
                            .. " applications=" .. tostring(aura.applications)
                            .. " expiration=" .. tostring(aura.expirationTime))
                    else
                        DebugPrint("C_UnitAuras: not found.")
                    end
                else
                    DebugPrint("C_UnitAuras API not available.")
                end

                local unitAuraFound = false
                if UnitAura then
                    for i = 1, 60 do
                        local auraOrName, _, _, _, _, _, _, _, _, auraSpellId, _, _, _, _, _, _, value1, value2, value3 = UnitAura("player", i, "HELPFUL")
                        if not auraOrName then break end
                        if type(auraOrName) == "table" then
                            local aura = auraOrName
                            local auraId = aura.spellId or aura.spellID
                            if auraId == spellId then
                                unitAuraFound = true
                                DebugPrint("UnitAura: found table at index " .. i
                                    .. " points[1]=" .. tostring(aura.points and aura.points[1])
                                    .. " value=" .. tostring(aura.value)
                                    .. " amount=" .. tostring(aura.amount)
                                    .. " absorb=" .. tostring(aura.absorb)
                                    .. " applications=" .. tostring(aura.applications)
                                    .. " expiration=" .. tostring(aura.expirationTime))
                                break
                            end
                        elseif auraSpellId == spellId then
                            unitAuraFound = true
                            DebugPrint("UnitAura: found at index " .. i
                                .. " value1=" .. tostring(value1)
                                .. " value2=" .. tostring(value2)
                                .. " value3=" .. tostring(value3))
                            break
                        end
                    end
                    if not unitAuraFound then
                        DebugPrint("UnitAura: not found.")
                    end
                else
                    DebugPrint("UnitAura API not available.")
                end
            end

            if msg == "" or msg == "help" then
                DebugPrint("/scrb vitality or /scrb celestial - dump aura details")
                return
            end
            if msg == "vitality" or msg == "debug" then
                DebugPrint("vitality debug started.")
                SafeCall("vitality", function()
                    DumpAuraBySpellId(450521, "Spell 450521")
                end)
                DebugPrint("vitality debug done.")
            elseif msg == "celestial" or msg == "brew" or msg == "shield" then
                DebugPrint("celestial debug started.")
                SafeCall("celestial", function()
                    DumpAuraBySpellId(322507, "Spell 322507")
                    DumpAuraBySpellId(1241059, "Spell 1241059")
                    if UnitGetTotalAbsorbs then
                        DebugPrint("UnitGetTotalAbsorbs: " .. tostring(UnitGetTotalAbsorbs("player")))
                    else
                        DebugPrint("UnitGetTotalAbsorbs API not available.")
                    end
                end)
                DebugPrint("celestial debug done.")
            end
        end
    end
end)

local file = assert(io.open("RollCurtain/RollCurtain.toc", "r"))
local toc = file:read("*a")
file:close()

local function position(name)
    local index = toc:find("\n" .. name .. "\n", 1, true)
    assert(index, name .. " is missing from RollCurtain.toc")
    return index
end

local settingsLayout = position("SettingsLayout.lua")
local uxSettings = position("UXSettings.lua")
local uxPolish = position("UXPolish.lua")
local lairSupport = position("LairSupport.lua")
local firstRun = position("FirstRun.lua")

-- LairSupport wraps the final Settings registration/refresh methods. It must
-- load after every module that reflows the main settings page, otherwise those
-- later modules can move Raid/Scenario controls back over the Lair controls on
-- the first render. It still loads before FirstRun so Lair defaults exist when
-- first-run presets are evaluated.
assert(lairSupport > settingsLayout, "LairSupport must load after SettingsLayout")
assert(lairSupport > uxSettings, "LairSupport must load after UXSettings")
assert(lairSupport > uxPolish, "LairSupport must load after UXPolish")
assert(lairSupport < firstRun, "LairSupport must load before FirstRun")

print("Roll Curtain Lair layout order test passed")

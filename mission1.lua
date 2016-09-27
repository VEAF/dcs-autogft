-- Mission initialization
if (initialized == nil or initialized == false) then
  lastCreatedUnitId = 0
  lastCreatedGroupId = 0

  upTime = 0
  prevReinforcementTime = 0
  minReinforcementTime = 1200

  -- Some type names:
  -- BRDM-2
  -- BMP-3
  -- T-55
  -- T-72B
  -- T-90

  -- M-1 Abrams
  -- Leopard-2
  reinforcementSetups = {
    -- Blue reinforcements
    bsputil.ReinforcementSetup.new("BMP-3", 3, country.id.USA, "spawnB1", "defenceB1"),
    bsputil.ReinforcementSetup.new("BRDM-2", 2, country.id.USA, "spawnB1", "defenceB1"),
    bsputil.ReinforcementSetup.new("LAV-25", 4, country.id.USA, "spawnB1", "defenceB1"),

    bsputil.ReinforcementSetup.new("BMP-3", 3, country.id.USA, "spawnB2", "defenceB2"),
    bsputil.ReinforcementSetup.new("BRDM-2", 2, country.id.USA, "spawnB2", "defenceB2"),
    bsputil.ReinforcementSetup.new("LAV-25", 4, country.id.USA, "spawnB2", "defenceB2"),
    bsputil.ReinforcementSetup.new("M-1 Abrams", 3, country.id.USA, "spawnB2", "defenceB2"),

    -- Red reinforcements
    bsputil.ReinforcementSetup.new("BMP-3", 3, country.id.RUSSIA, "spawnR1", "defenceR1"),
    bsputil.ReinforcementSetup.new("BRDM-2", 2, country.id.RUSSIA, "spawnR1", "defenceR1"),
    bsputil.ReinforcementSetup.new("BTR-80", 4, country.id.RUSSIA, "spawnR1", "defenceR1"),

    bsputil.ReinforcementSetup.new("BMP-3", 3, country.id.RUSSIA, "spawnR2", "defenceR2"),
    bsputil.ReinforcementSetup.new("BRDM-2", 2, country.id.RUSSIA, "spawnR2", "defenceR2"),
    bsputil.ReinforcementSetup.new("BTR-80", 4, country.id.RUSSIA, "spawnR2", "defenceR2"),
    bsputil.ReinforcementSetup.new("T-72B", 3, country.id.RUSSIA, "spawnR2", "defenceR2")
  }

  local function checkEm()
    bsputil.checkAndReinforce(reinforcementSetups)
  end
  
  mist.scheduleFunction(checkEm, nil, timer.getTime()+1, minReinforcementTime)
  initialized = true
end














































































































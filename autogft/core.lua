-- Namespace declaration

autogft = {}

-- Constants

autogft.CARDINAL_DIRECTIONS = {"N", "N/NE", "NE", "NE/E", "E", "E/SE", "SE", "SE/S", "S", "S/SW", "SW", "SW/W", "W", "W/NW", "NW", "NW/N"}
autogft.MAX_CLUSTER_DISTANCE = 1000
autogft.IOCEV_COMMAND_TEXT = "Request location of enemy vehicles"
autogft.DEFAULT_AUTO_ISSUE_DELAY = 600
autogft.DEFAULT_AUTO_REINFORCE_DELAY = 1800

-- Counters

autogft.lastCreatedUnitId = 0
autogft.lastCreatedGroupId = 0

-- Misc

autogft.debugMode = false

-- Type definitions

---
-- @type autogft.UnitCluster
-- @field #list<#string> unitNames
-- @field DCSTypes#Vec2 midPoint
autogft.UnitCluster = {}
autogft.UnitCluster.__index = autogft.UnitCluster

---
-- @param #autogft.UnitCluster self
-- @return #autogft.UnitCluster
function autogft.UnitCluster:new()
  local self = setmetatable({}, autogft.UnitCluster)
  self.unitNames = {}
  self.midPoint = {}
  return self
end

---
-- @type autogft.UnitSpec
-- @field #number count
-- @field #string type
autogft.UnitSpec = {}
autogft.UnitSpec.__index = autogft.UnitSpec

---
-- @param #autogft.UnitSpec self
-- @param #number count
-- @param #string type
-- @return #autogft.UnitSpec
function autogft.UnitSpec:new(count, type)
  self = setmetatable({}, autogft.UnitSpec)
  self.count = count
  self.type = type
  return self
end

---
-- @type autogft.ControlZone
-- @field #string name
-- @field #number status
autogft.ControlZone = {}
autogft.ControlZone.__index = autogft.ControlZone

---
-- @param #autogft.ControlZone self
-- @param #string name
-- @return #autogft.ControlZone
function autogft.ControlZone:new(name)
  self = setmetatable({}, autogft.ControlZone)
  self.name = name
  self.status = coalition.side.NEUTRAL
  return self
end

---
-- @type autogft.TaskForce
-- @field #number country
-- @field #list<#string> stagingZones
-- @field #list<#autogft.ControlZone> controlZones
-- @field #number speed
-- @field #string formation
-- @field #list<#autogft.UnitSpec> unitSpecs
-- @field #list<DCSGroup#Group> groups
-- @field #string target
autogft.TaskForce = {}
autogft.TaskForce.__index = autogft.TaskForce

---
-- @param #autogft.TaskForce self
-- @param #number country
-- @param #list<#string> stagingZones
-- @param #list<#string> controlZones
-- @return #autogft.TaskForce
function autogft.TaskForce:new(country, stagingZones, controlZones)

  local function verifyZoneExists(name)
    assert(trigger.misc.getZone(name) ~= nil, "Zone \""..name.."\" does not exist in this mission.")
  end

  self = setmetatable({}, autogft.TaskForce)
  self.country = country
  for k,v in pairs(stagingZones) do verifyZoneExists(v) end
  self.stagingZones = stagingZones
  self.unitSpecs = {}
  self.controlZones = {}
  self.speed = 100
  self.formation = "cone"
  for i = 1, #controlZones do
    local controlZone = controlZones[i]
    verifyZoneExists(controlZone)
    self.controlZones[#self.controlZones + 1] = autogft.ControlZone:new(controlZone)
  end
  self.groups = {}
  self.target = controlZones[1]
  return self
end

---
-- @param #autogft.TaskForce self
-- @param #number count
-- @param #string type
-- @return #autogft.TaskForce
function autogft.TaskForce:addUnitSpec(count, type)
  self.unitSpecs[#self.unitSpecs + 1] = autogft.UnitSpec:new(count, type)
  return self
end

---
-- @param #autogft.TaskForce self
-- @return #autogft.TaskForce
function autogft.TaskForce:cleanGroups()
  local newGroups = {}
  for i = 1, #self.groups do
    local group = self.groups[i]
    if #group:getUnits() > 0 then newGroups[#newGroups + 1] = group end
  end
  self.groups = newGroups
  return self
end

---
-- @param #autogft.TaskForce self
-- @param #boolean spawn
-- @return #autogft.TaskForce
function autogft.TaskForce:reinforce(spawn)
  local spawnedUnitCount = 0
  self:cleanGroups()
  local desiredUnits = {}
  for unitSpecIndex = 1, #self.unitSpecs do
    -- Determine desired replacement units of this spec
    local unitSpec = self.unitSpecs[unitSpecIndex]
    if desiredUnits[unitSpec.type] == nil then
      desiredUnits[unitSpec.type] = 0
    end

    desiredUnits[unitSpec.type] = desiredUnits[unitSpec.type] + unitSpec.count
    local replacements = desiredUnits[unitSpec.type]
    for groupIndex = 1, #self.groups do
      replacements = replacements - autogft.countUnitsOfType(self.groups[groupIndex]:getUnits(), unitSpec.type)
    end

    -- Get replacements
    if replacements > 0 then

      local groupName
      local units = {}

      function addUnit(type, name, id, x, y, skill)
        units[#units + 1] = {
          ["type"] = type,
          ["transportable"] =
          {
            ["randomTransportable"] = false,
          },
          ["x"] = x,
          ["y"] = y,
          ["name"] = name,
          ["unitId"] = id,
          ["skill"] = skill,
          ["playerCanDrive"] = true
        }
      end

      -- Assign units to group
      if spawn then
        local spawnZoneIndex = math.random(#self.stagingZones)
        local spawnZone = trigger.misc.getZone(self.stagingZones[spawnZoneIndex])

        local replacedUnits = 0
        while replacedUnits < replacements do

          local id = autogft.lastCreatedUnitId
          local name = "Unit no " .. autogft.lastCreatedUnitId
          local x = spawnZone.point.x + 15 * spawnedUnitCount
          local y = spawnZone.point.z - 15 * spawnedUnitCount
          local skill = "High"
          autogft.lastCreatedUnitId = autogft.lastCreatedUnitId + 1
          addUnit(unitSpec.type, name, id, x, y, skill)

          spawnedUnitCount = spawnedUnitCount + 1
          replacedUnits = replacedUnits + 1
        end
      else
      -- TODO: Select units from staging zones
      end

      if #units > 0 then
        -- Create a group
        groupName = "Group #00" .. autogft.lastCreatedGroupId
        local groupData = {
          ["route"] = {},
          ["groupId"] = autogft.lastCreatedGroupId,
          ["units"] = units,
          ["name"] = groupName
        }
        coalition.addGroup(self.country, Group.Category.GROUND, groupData)
        autogft.lastCreatedGroupId = autogft.lastCreatedGroupId + 1

        -- Issue group to control zone
        self.groups[#self.groups + 1] = Group.getByName(groupName)
        if self.target ~= nil then
          autogft.issueGroupTo(groupName, self.target)
        end
      end
    end
  end
  return self
end

---
-- @param #autogft.TaskForce self
-- @return #autogft.TaskForce
function autogft.TaskForce:updateTarget()
  local redVehicles = mist.makeUnitTable({'[red][vehicle]'})
  local blueVehicles = mist.makeUnitTable({'[blue][vehicle]'})

  local done = false
  local zoneIndex = 1
  while done == false and zoneIndex <= #self.controlZones do
    local zone = self.controlZones[zoneIndex]
    local newStatus = nil
    if #mist.getUnitsInZones(redVehicles, {zone.name}) > 0 then
      newStatus = coalition.side.RED
    end

    if #mist.getUnitsInZones(blueVehicles, {zone.name}) > 0 then
      if newStatus == coalition.side.RED then
        newStatus = coalition.side.NEUTRAL
      else
        newStatus = coalition.side.BLUE
      end
    end

    if newStatus ~= nil then
      zone.status = newStatus
    end

    if zone.status ~= coalition.getCountryCoalition(self.country) then
      self.target = zone.name
      done = true
    end
    zoneIndex = zoneIndex + 1
  end

  if self.target == nil then
    self.target = self.controlZones[#self.controlZones].name
  end
  return self
end

---
-- @param #autogft.TaskForce self
-- @param #string zone
-- @return #autogft.TaskForce
function autogft.TaskForce:issueTo(zone)
  self:cleanGroups()
  for i = 1, #self.groups do
    autogft.issueGroupTo(self.groups[i]:getName(), self.target, self.speed, self.formation)
  end
  return self
end

---
-- @param #autogft.TaskForce self
-- @return #autogft.TaskForce
function autogft.TaskForce:moveToTarget()
  self:issueTo(self.target)
  return self
end

---
-- @param #autogft.TaskForce self
-- @param #number timeIntervalSec
-- @return #autogft.TaskForce
function autogft.TaskForce:enableObjectiveUpdateTimer(timeIntervalSec)
  local function autoIssue()
    self:updateTarget()
    self:moveToTarget()
    autogft.scheduleFunction(autoIssue, timeIntervalSec)
  end
  autogft.scheduleFunction(autoIssue, timeIntervalSec)
  return self
end

---
-- @param #autogft.TaskForce self
-- @param #number timeIntervalSec
-- @param #number maxReinforcementTime (optional)
-- @return #autogft.TaskForce
function autogft.TaskForce:enableRespawnTimer(timeIntervalSec, maxReinforcementTime)
  local keepRespawning = true
  local function respawn()
    if keepRespawning then
      self:reinforce(true)
      autogft.scheduleFunction(respawn, timeIntervalSec)
    end
  end

  autogft.scheduleFunction(respawn, timeIntervalSec)

  if maxReinforcementTime ~= nil and maxReinforcementTime > 0 then
    local function killTimer()
      keepRespawning = false
    end
    autogft.scheduleFunction(killTimer, maxReinforcementTime)
  end
  return self
end

---
-- @param #autogft.TaskForce self
-- @return #autogft.TaskForce
function autogft.TaskForce:enableDefaultTimers()
  self:enableObjectiveUpdateTimer(autogft.DEFAULT_AUTO_ISSUE_DELAY)
  self:enableRespawnTimer(autogft.DEFAULT_AUTO_REINFORCE_DELAY)
  return self
end

---
-- @param #autogft.TaskForce self
-- @param #string name
-- @return #boolean
function autogft.TaskForce:containsUnit(name)
  for groupIndex = 1, #self.groups do
    local units = self.groups[groupIndex]:getUnits()
    for unitIndex = 1, #units do
      if units[unitIndex]:getName() == name then return true end
    end
  end
  return false
end

---
-- @type autogft.GroupCommand
-- @field #string commandName
-- @field #string groupName
-- @field #number groupId
-- @field #function func
-- @field #number timerId
-- @field #boolean enabled
autogft.GroupCommand = {}
autogft.GroupCommand.__index = autogft.GroupCommand

---
-- @param #autogft.GroupCommand self
-- @param #string commandName
-- @param #string groupName
-- @param #function func
-- @return #autogft.GroupCommand
function autogft.GroupCommand:new(commandName, groupName, func)
  self = setmetatable({}, autogft.GroupCommand)
  self.commandName = commandName
  self.groupName = groupName
  self.groupId = Group.getByName(groupName):getID()
  self.func = func
  return self
end

---
-- @param #autogft.GroupCommand self
function autogft.GroupCommand:enable()
  self.enabled = true

  local flagName = "groupCommandFlag"..self.groupId
  trigger.action.setUserFlag(flagName, 0)
  trigger.action.addOtherCommandForGroup(self.groupId, self.commandName, flagName, 1)

  local function checkTrigger()
    if self.enabled == true then
      if (trigger.misc.getUserFlag(flagName) == 1) then
        trigger.action.setUserFlag(flagName, 0)
        self.func()
      end
      autogft.scheduleFunction(checkTrigger, 1)
    else
    end
  end
  checkTrigger()
end

---
-- @param #autogft.GroupCommand self
function autogft.GroupCommand:disable()
  -- Remove group command from mission
  trigger.action.removeOtherCommandForGroup(self.groupId, self.commandName)
  self.enabled = false
end

-- Utility function definitions

---
-- @param #string groupName
-- @param #string zoneName
function autogft.issueGroupTo(groupName, zoneName, speed, formation)
  local destinationZone = trigger.misc.getZone(zoneName)
  local destinationZonePos2 = {
    x = destinationZone.point.x,
    y = destinationZone.point.z
  }
  local randomPointVars = {
    group = Group.getByName(groupName),
    point = destinationZonePos2,
    radius = destinationZone.radius,
    speed = speed,
    formation = formation,
    disableRoads = true
  }
  mist.groupToRandomPoint(randomPointVars)
end

---
-- @param #list<DCSUnit#Unit> units
-- @param #string type
-- @return #number
function autogft.countUnitsOfType(units, type)
  local count = 0
  local unit
  for i = 1, #units do
    if units[i]:getTypeName() == type then
      count = count + 1
    end
  end
  return count
end

---
-- @param #vec3
-- @param #vec3
-- @return #number
function autogft.getDistanceBetween(a, b)
  local dx = a.x - b.x
  local dy = a.y - b.y
  local dz = a.z - b.z
  return math.sqrt(dx * dx + dy * dy + dz * dz)
end

---
-- @param #string unitName
-- @return DCSUnit#Unit
function autogft.getClosestEnemyVehicle(unitName)

  local unit = Unit.getByName(unitName)
  local unitPosition = unit:getPosition().p
  local enemyCoalitionString = "[red]"
  if unit:getCoalition() == 1 then
    enemyCoalitionString = "[blue]"
  end
  local unitTableStr = enemyCoalitionString .. '[vehicle]'
  local enemyVehicles = mist.makeUnitTable({ unitTableStr })
  if #enemyVehicles > 0 then
    local closestEnemy
    local closestEnemyDistance
    local newClosestEnemy = {}
    local newClosestEnemyDistance = 0
    for i = 1, #enemyVehicles do
      newClosestEnemy = Unit.getByName(enemyVehicles[i])
      if newClosestEnemy ~= nil then
        if closestEnemy == nil then
          closestEnemy = newClosestEnemy
          closestEnemyDistance = autogft.getDistanceBetween(unitPosition, closestEnemy:getPosition().p)
        else
          newClosestEnemyDistance = autogft.getDistanceBetween(unitPosition, newClosestEnemy:getPosition().p)
          if (newClosestEnemyDistance < closestEnemyDistance) then
            closestEnemy = newClosestEnemy
          end
        end
      end
    end
    return closestEnemy
  end
end

---
-- @param #number rad Direction in radians
-- @return #string A string representing a cardinal direction
function autogft.radToCardinalDir(rad)

  local dirNormalized = rad / math.pi / 2
  local i = 1
  if dirNormalized < (#autogft.CARDINAL_DIRECTIONS-1) / #autogft.CARDINAL_DIRECTIONS then
    while dirNormalized > i/#autogft.CARDINAL_DIRECTIONS/2 do
      i = i + 2
    end
  end
  local index = math.floor(i/2) + 1
  return autogft.CARDINAL_DIRECTIONS[index]
end

---
-- This function might be computationally expensive
-- @param DCSUnit#Unit unit
-- @param #number radius
-- @return #autogft.UnitCluster
function autogft.getFriendlyVehiclesWithin(unit, radius)
  local coalitionString
  if unit:getCoalition() == coalition.side.BLUE then
    coalitionString = "[blue]"
  else
    coalitionString  = "[red]"
  end
  local unitTableStr = coalitionString .. '[vehicle]'
  local units = mist.makeUnitTable({ unitTableStr })

  local addedVehiclesNames = {unit:getName()}
  local minPos = unit:getPosition().p
  local maxPos = unit:getPosition().p

  ---
  -- @param #list list
  -- @param value
  local function contains(list, value)
    for i = 1, #list do
      if list[i] == value then
        return true
      end
    end
    return false
  end

  ---
  -- @param DCSUnit#Unit unit
  local function addUnit(unit)
    local pos = unit:getPosition().p
    if pos.x < minPos.x then minPos.x = pos.x end
    if pos.z < minPos.z then minPos.z = pos.z end
    if pos.x > maxPos.x then maxPos.x = pos.x end
    if pos.z > maxPos.z then maxPos.z = pos.z end
    addedVehiclesNames[#addedVehiclesNames + 1] = unit:getName()
  end

  ---
  -- @param DCSUnit#Unit unit
  local function vehiclesWithinRecurse(targetUnit)
    for i = 1, #units do
      local nextUnit = Unit.getByName(units[i])
      if nextUnit then
        if nextUnit:getID() == targetUnit:getID() == false then
          if autogft.getDistanceBetween(targetUnit:getPosition().p, nextUnit:getPosition().p) <= radius then
            if contains(addedVehiclesNames, nextUnit:getName()) == false then
              addUnit(nextUnit)
              vehiclesWithinRecurse(nextUnit)
            end
          end
        end
      end
    end
  end

  vehiclesWithinRecurse(unit)

  local dx = maxPos.x - minPos.x
  local dz = maxPos.z - minPos.z

  local midPoint = { -- 3D to 2D conversion implemented
    x = minPos.x + dx / 2,
    y = minPos.z + dz / 2
  }

  local result = autogft.UnitCluster:new()
  result.unitNames = addedVehiclesNames
  result.midPoint = midPoint
  return result

end

---
--Prints out a message to a group, describing nearest enemy vehicles
-- @param DCSGroup#Group group
function autogft.informOfClosestEnemyVehicles(group)

  local firstGroupUnit = group:getUnit(1)
  local closestEnemy = autogft.getClosestEnemyVehicle(firstGroupUnit:getName())
  if closestEnemy == nil then
    trigger.action.outTextForGroup(group:getID(), "No enemy vehicles", 30)
  else
    local groupUnitPos = {
      x = firstGroupUnit:getPosition().p.x,
      y = 0,
      z = firstGroupUnit:getPosition().p.z
    }

    local enemyCluster = autogft.getFriendlyVehiclesWithin(closestEnemy, autogft.MAX_CLUSTER_DISTANCE)
    local midPoint = mist.utils.makeVec3(enemyCluster.midPoint)

    local dirRad = mist.utils.getDir(mist.vec.sub(midPoint, groupUnitPos))
    local dirDegree = math.floor(dirRad / math.pi * 18 + 0.5) * 10 -- Rounded to nearest 10
    --  local cardinalDir = autogft.radToCardinalDir(dirRad)
    local distanceM = autogft.getDistanceBetween(midPoint, groupUnitPos)
    local distanceKM = distanceM / 1000
    local distanceNM = distanceKM / 1.852

    local vehicleTypes = {}
    for i = 1, #enemyCluster.unitNames do
      local type = Unit.getByName(enemyCluster.unitNames[i]):getTypeName()
      if vehicleTypes[type] == nil then
        vehicleTypes[type] = 0
      end

      vehicleTypes[type] = vehicleTypes[type] + 1
    end

    local text = ""
    for key, val in pairs(vehicleTypes) do
      if (text ~= "") then
        text = text..", "
      end
      text = text..val.." "..key
    end

    local distanceNMRounded = math.floor(distanceNM + 0.5)
    text = text .. " located " .. distanceNMRounded .. "nm at ~" .. dirDegree .. " from group lead"
    trigger.action.outTextForGroup(group:getID(), text, 30)
  end

end

function autogft.enableIOCEV()

  local enabledGroupCommands = {}

  local function cleanEnabledGroupCommands()
    local newEnabledGroupCommands = {}
    for i = 1, #enabledGroupCommands do
      if not Group.getByName(enabledGroupCommands[i].groupName) then
        enabledGroupCommands[i]:disable()
      else
        newEnabledGroupCommands[#newEnabledGroupCommands + 1] = enabledGroupCommands[i]
      end
    end
    enabledGroupCommands = newEnabledGroupCommands
  end

  ---
  -- @param #number groupId
  local function groupHasCommandEnabled(groupId)
    for i = 1, #enabledGroupCommands do
      if enabledGroupCommands[i].groupId == groupId then
        return true
      end
    end
    return false
  end

  ---
  -- @param DCSGroup#Group group
  local function groupHasPlayer(group)
    local units = group:getUnits()
    for i = 1, #units do
      if units[i]:getPlayerName() ~= nil then return true end
    end
    return false
  end

  ---
  -- @param #list<DCSGroup#Group> groups
  local function enableForGroups(groups)
    for i = 1, #groups do
      local group = groups[i]
      if groupHasPlayer(group) then
        if not groupHasCommandEnabled(group:getID()) then
          local function triggerCommand()
            autogft.informOfClosestEnemyVehicles(group)
          end
          local groupCommand = autogft.GroupCommand:new(autogft.IOCEV_COMMAND_TEXT, group:getName(), triggerCommand)
          groupCommand:enable()
          enabledGroupCommands[#enabledGroupCommands + 1] = groupCommand
        end
      end
    end
  end

  local function reEnablingLoop()
    cleanEnabledGroupCommands()
    enableForGroups(coalition.getGroups(coalition.side.RED))
    enableForGroups(coalition.getGroups(coalition.side.BLUE))
    autogft.scheduleFunction(reEnablingLoop, 30)
  end

  reEnablingLoop()

end

---
-- @param #string str
-- @param #number time
function autogft.printIngame(str, time)
  if (time == nil) then
    time = 1
  end
  trigger.action.outText(str, time)
end

---
--
function autogft.spawnUnits()
end

function autogft.log(variable)
  if autogft.debugMode then
    autogft.printIngame(autogft.toString(variable))
  end
end

---
-- Deep copy a table
--Code from https://gist.github.com/MihailJP/3931841
function autogft.deepCopy(t)
  if type(t) ~= "table" then return t end
  local meta = getmetatable(t)
  local target = {}
  for k, v in pairs(t) do
    if type(v) == "table" then
      target[k] = autogft.deepCopy(v)
    else
      target[k] = v
    end
  end
  setmetatable(target, meta)
  return target
end

---
-- Returns a string representation of an object
function autogft.toString(obj)

  local indent = "    "
  local function toStringRecursively(obj, level)

    if (obj == nil) then
      return "(nil)"
    end

    local str = ""
    if (type(obj) == "table") then
      if (level ~= 0) then
        str = str .. "{"
      end
      local isFirst = true
      for key, value in pairs(obj) do
        if (isFirst == false) then
          str = str .. ","
        end
        str = str .. "\n"
        for i = 1, level do
          str = str .. indent
        end

        if (type(key) == "number") then
          str = str .. "[\"" .. key .. "\"]"
        else
          str = str .. key
        end
        str = str .. " = "

        if (type(value) == "function") then
          str = str .. "(function)"
        else
          str = str .. toStringRecursively(value, level + 1)
        end
        isFirst = false
      end

      if (level ~= 0) then
        str = str .. "\n"
        for i = 1, level - 1 do
          str = str .. indent
        end
        str = str .. "}"
      end
    else
      str = obj
      if (type(obj) == "string") then
        str = "\"" .. str .. "\""
      elseif type(obj) == "boolean" then
        if obj == true then
          str = "true"
        else
          str = "false"
        end
      end
    end

    return str
  end

  return toStringRecursively(obj, 1)
end

function autogft.scheduleFunction(func, time)
  local function triggerFunction()
    local success, message = pcall(func)
    if not success then
      env.error("Error in scheduled function: "..message, true)
    end
  end
  timer.scheduleFunction(triggerFunction, {}, timer.getTime() + time)
end

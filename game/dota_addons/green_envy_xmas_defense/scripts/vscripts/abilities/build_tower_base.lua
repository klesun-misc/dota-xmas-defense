
local types = require('types')

-- this module provides code needed by all
-- towers - use it to avoid copy-pasting

local lastCursorPosition = Vector(0,0,0);
local defaultTowerRadius = 64

local HasPathFromSpawnPoint = function(point)
    if Entities and Entities.FindByName and GridNav then
        local spawnEnt = Entities:FindByName(nil, 'creep_spawn_mark')
        if spawnEnt and not GridNav:CanFindPath(point, spawnEnt:GetAbsOrigin()) then
            return false
        end
    end
    return true
end

local NormalizeTowerPoint = function(castPoint, hullRadius)
    hullRadius = hullRadius or defaultTowerRadius
    local xRest = castPoint.x % (hullRadius * 2)
    local yRest = castPoint.y % (hullRadius * 2)

    return Vector(
        castPoint.x - xRest + (xRest > hullRadius and hullRadius * 2 or 0),
        castPoint.y - yRest + (yRest > hullRadius and hullRadius * 2 or 0),
        castPoint.z
    )
end

--- check whether it is possible to build tower on that point
local CanBuildThere = function(point, towerRadius)
    towerRadius = towerRadius or defaultTowerRadius
    point = NormalizeTowerPoint(point, towerRadius)

    local floatError = point.z % 128
    if floatError > 0.01 and 128 - floatError > 0.01 then
        -- when trying to build on a wall
        return false
    end

    -- I had problems with other Entities: functions, it
    -- looked like they are not available in this context
    local ent = Entities:First()
    while ent ~= nil do
        local entRad = ent.GetHullRadius and ent:GetHullRadius() or 0
        if entRad > 0 then
            local dv = point - ent:GetAbsOrigin()
            if (math.abs(dv.x) - entRad < towerRadius) and (math.abs(dv.y) - entRad < towerRadius) then
                return false
            end
        end
        ent = Entities:Next(ent)
    end
    return true
end

local MakeAbility = function(params)
    local datadrivenName = params.datadrivenName
    local towerRadius = params.towerRadius or defaultTowerRadius
    local OnCreated = params.OnCreated or function(tower) end
    local CustomPointCheck = params.CustomPointCheck
        or function(point, abil) return nil end

    local build_tower_base = {}

    ---@param point Vector | t_vec
    function build_tower_base:CastFilterResultLocation(point)
        lastCursorPosition = point + Vector(0,0,0)
        if not CanBuildThere(point, towerRadius) then
            return UF_FAIL_CUSTOM
        elseif not HasPathFromSpawnPoint(point) then
            return UF_FAIL_CUSTOM
        else
            local error = CustomPointCheck(point, self)
            if error then
                return UF_FAIL_CUSTOM
            else
                return UF_SUCCESS
            end
        end
    end

    function build_tower_base:GetCustomCastErrorLocation(point)
        local customError = CustomPointCheck(point, self)
        if customError then
            return customError
        elseif not CanBuildThere(point, towerRadius) then
            return 'I can\'t build there'
        elseif not HasPathFromSpawnPoint(point) then
            return 'There is no path to this point'
        else
            return nil
        end
    end

    ---@param event t_ability_event
    function build_tower_base:OnSpellStart(event)
        local caster = types:t_npc(self:GetCaster())
        local spellPoint = NormalizeTowerPoint(self:GetCursorPosition(), towerRadius)

        local tower = CreateUnitByName(
            datadrivenName, spellPoint,
            false, caster, caster, caster:GetTeam()
        )
        tower.envyNs = tower.envyNs or {}
        tower.envyNs.builder = caster
        tower.envyNs.goldCost = self:GetGoldCost(self:GetLevel())
        if tower.SetInvulnCount ~= nil then
            tower:SetInvulnCount(0)
        end

        --tower:SetIdleAcquire(true) -- auto-attack ON
        --tower:SetControllableByPlayer(caster:GetMainControllingPlayer(), false)
        tower:SetHullRadius(towerRadius)

        OnCreated(tower, self)
    end

    function build_tower_base:GetAOERadius(event)
        local point = lastCursorPosition
        local towerPoint = NormalizeTowerPoint(point, towerRadius)
        local maxDistance = math.sqrt(towerRadius ^ 2 + towerRadius ^ 2)
        local distance = (point - towerPoint):Length()
        return math.max(1, (maxDistance - distance) * 1.5)
    end

    return build_tower_base
end

return {
    MakeAbility = MakeAbility,
    CanBuildThere = CanBuildThere,
    NormalizeTowerPoint = NormalizeTowerPoint,
}
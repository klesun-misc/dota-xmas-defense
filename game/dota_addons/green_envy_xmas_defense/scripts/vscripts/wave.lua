
local lang = require('reloaded.lang')

-- this module encapsulates logic related to waves: who/how often/what modifiers/special events/etc...

local GetClosestEnemy = function(attacker)
    local distance = 400
    local ent = Entities:FindInSphere(nil, attacker:GetAbsOrigin(), distance)
    while ent do
        if not ent:IsAlive()
        or type(ent.IsHero) ~= 'function'
        or not ent:IsOpposingTeam(attacker:GetTeamNumber())
        or ent:GetHealth() < 1
        then --[[skip]] else
            return ent
        end
        ent = Entities:FindInSphere(ent, attacker:GetAbsOrigin(), distance)
    end
    return nil
end

local Spawn = function()
    local waveInterval = 6.0 -- seconds

    local linearMult = 0.85
    local expSpeed = 0.012
    local exp = 3.6
    local postExpMult = 0.10
    local spawnMark = Entities:FindByName(nil, 'creep_spawn_mark')
    local goalMark = Entities:FindByName(nil, 'creep_goal_mark')
    local point = spawnMark:GetAbsOrigin()
    local goal = goalMark:GetAbsOrigin()

    local GetTimeFactor = function()
        local seconds = GameRules:GetGameTime()
        return seconds * linearMult + math.pow(expSpeed * seconds, exp) * postExpMult
    end

    local SpawnUnit = function(dataDrivenName)
        local unit = CreateUnitByName(
            dataDrivenName,
            point + RandomVector(RandomInt(100, 600)),
            true, nill, nill, DOTA_TEAM_BADGUYS
        )
        -- need to apply any modifier to update npc gui hp numbers
        unit:AddNewModifier(nil, nil, 'modifier_stunned', {duration = 0.05})

        local goToGoalOrder = {
            UnitIndex = unit:GetEntityIndex(),
            OrderType = DOTA_UNIT_ORDER_ATTACK_MOVE,
            Position = goal, Queue = true
        }
        ExecuteOrderFromTable(goToGoalOrder)

        local lastLocation = nil
        unit:SetThink(function()
            local currentLocation = unit:GetAbsOrigin()
            if not lastLocation
            or lastLocation:__sub(currentLocation):Length() > 0.0001
            or unit:IsAttacking()
            or not unit:IsAlive()
            then --[[skip]] else
                unit:AddNewModifier(nil, nil, 'modifier_phased', {duration = 5.00})
                -- creep is either stuck or done moving to the ancient
                -- if the former - attack nearest tower, if the latter, re-execute order to go to ancient
                local enemy = GetClosestEnemy(unit)
                if enemy then
                    ExecuteOrderFromTable({
                        UnitIndex = unit:entindex(),
                        OrderType = DOTA_UNIT_ORDER_ATTACK_TARGET,
                        TargetIndex = enemy:entindex(),
                    })
                else
                    ExecuteOrderFromTable(goToGoalOrder)
                end
            end
            lastLocation = currentLocation
            return 1
        end)

        return unit
    end

    local SpawnCreep = function(wave)
        local timeFactor = GetTimeFactor()
        local golem = SpawnUnit('npc_dota_creature_gnoll_assassin')
        local hp = 60 + timeFactor
        local dmg = 17 + timeFactor / 15
        golem:SetBaseAttackTime(1)
        golem:SetBaseDamageMin(dmg)
        golem:SetBaseDamageMax(dmg)
        golem:SetBaseMaxHealth(hp)
        golem:SetBaseHealthRegen(5)
		
		-- so they skipped Vika's maze fast
        golem:SetBaseMoveSpeed(3000)
		lang.Timeout(25).callback = function()
			golem:SetBaseMoveSpeed(350)
		end

		golem:AddNewModifier(nil, nil, 'modifier_phased', {duration = 20.00})
        golem:AddNewModifier(golem, nil, 'modifier_kill', {duration = 90})

        if wave % 5 == 0 then
            GameRules:SendCustomMessage('Creep spawned with hp: ' .. math.floor(hp) ..' dmg: ' .. math.floor(dmg), DOTA_TEAM_FIRST, 0)
        end
    end

    local SpawnBoss = function()
        local timeFactor = GetTimeFactor()
        local golem = SpawnUnit('npc_dota_creature_gnoll_boss')
        local hp = 1000 + timeFactor * 6
        local dmg = 30 + timeFactor / 6
        golem:SetBaseAttackTime(2)
        golem:SetBaseDamageMin(dmg)
        golem:SetBaseDamageMax(dmg)
        golem:SetBaseMaxHealth(hp)
        golem:SetBaseHealthRegen(10)
        golem:SetBaseMoveSpeed(200)
        golem:SetMana(200)

        GameRules:SendCustomMessage('Boss spawned with hp: ' .. math.floor(hp) ..' dmg: ' .. math.floor(dmg), DOTA_TEAM_FIRST, 0)
    end

    local SpawnDragon = function()
        local timeFactor = GetTimeFactor()
        local unit = SpawnUnit('npc_dota_creature_gnoll_dragon')
		unit:AddNewModifier(nil, nil, 'modifier_phased', {duration = -1})
        unit:AddNewModifier(unit, nil, 'MODIFIER_STATE_FLYING ', {duration = -1})
        unit:AddNewModifier(unit, nil, 'MODIFIER_STATE_NO_UNIT_COLLISION ', {duration = -1})
        unit:AddNewModifier(unit, nil, 'MODIFIER_STATE_FLYING_FOR_PATHING_PURPOSES_ONLY ', {duration = -1})
        local hp = 300 + timeFactor * 2
        local dmg = 20 + timeFactor / 9
        unit:SetBaseAttackTime(2)
        unit:SetBaseDamageMin(dmg)
        unit:SetBaseDamageMax(dmg)
        unit:SetBaseMaxHealth(hp)
        unit:SetBaseHealthRegen(5)
        unit:SetBaseMoveSpeed(350)
        unit:SetMana(200)

        GameRules:SendCustomMessage('Dragon spawned with hp: ' .. math.floor(hp) ..' dmg: ' .. math.floor(dmg), DOTA_TEAM_FIRST, 0)
    end

    local seconds = GameRules:GetGameTime()

    cnt = 2
    if seconds > 60 then cnt = cnt + 1 end
    if seconds > 180 then cnt = cnt + 1 end
    if seconds > 540 then cnt = cnt + 1 end
    if seconds > 1620 then cnt = cnt + 1 end

    local wave = math.floor(GameRules:GetGameTime() / waveInterval)
    if wave > 25 and wave % 25 == 0 then
        SpawnBoss()
    end
    if wave > 16 and wave % 16 == 0 then
        SpawnDragon()
    end
    for i = 1,cnt,1 do
        SpawnCreep(wave)
    end

    return waveInterval
end

return {
    Spawn = function()
        ---@debug
        --return 100
        return Spawn()
    end
}
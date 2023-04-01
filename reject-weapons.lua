local infernoInstalled = mods and mods.inferno
local vertexInstalled = mods and mods.vertexutil

-------------
-- UTILITY --
-------------
local vter = nil
if infernoInstalled then
    vter = mods.inferno.vter
elseif vertexInstalled then
    vter = mods.vertexutil.vter
else
    vter = function(cvec)
        local i = -1
        local n = cvec:size()
        return function()
            i = i + 1
            if i < n then return cvec[i] end
        end
    end
end

local INT_MAX = 2147483647

-----------
-- LOGIC --
-----------
-- Make scatter bomb fire a burst of bombs
local shotgunBombs = {}
shotgunBombs["BOMB_SHOTGUN_SHRAPNEL"] = {
    blueprint = Hyperspace.Global.GetInstance():GetBlueprints():GetWeaponBlueprint("BOMB_SHOTGUN_SHRAPNEL_PROJ"),
    count = 4
}
local function handle_shotgun_bomb(weapon, projectile)
    local shotgunBomb = shotgunBombs[weapon.blueprint.name]
    if shotgunBomb then
        local targetCenter = nil
        if pcall(function() targetCenter = weapon.lastTargets[0] end) and targetCenter then
        
            -- Find all room tiles within the weapon's radius
            local targetShipGraph = Hyperspace.ShipGraph.GetShipInfo(projectile.destinationSpace)
            local validTargets = {}
            local horzMult = 1
            local vertMult = 1
            local checkRadius = weapon.radius
            if targetCenter.x%35 > 0 then horzMult = 0 end
            if targetCenter.y%35 > 0 then vertMult = 0 end
            if checkRadius%35 > 0 then checkRadius = checkRadius - checkRadius%35 + 35 end
            for targetY = targetCenter.y - checkRadius + vertMult*17, targetCenter.y + checkRadius - vertMult*18, 35 do
                for targetX = targetCenter.x - checkRadius + horzMult*17, targetCenter.x + checkRadius - horzMult*18, 35 do
                    if (targetX - targetCenter.x)^2 + (targetY - targetCenter.y)^2 <= weapon.radius^2 and targetShipGraph:GetSelectedRoom(targetX, targetY, false) > -1 then
                        table.insert(validTargets, Hyperspace.Pointf(targetX, targetY))
                    end
                end
            end
            
            -- Fire 4 bombs randomly at found tiles
            local spaceManager = Hyperspace.Global.GetInstance():GetCApp().world.space
            local bombsCreated = 0
            while #validTargets > 0 and bombsCreated < shotgunBomb.count do
                local targetIndex = Hyperspace.random32()%#validTargets + 1
                target = validTargets[targetIndex]
                table.remove(validTargets, targetIndex)
                spaceManager:CreateBomb(shotgunBomb.blueprint, projectile.ownerId, target, projectile.destinationSpace)
                bombsCreated = bombsCreated + 1
            end
            
            projectile:Kill()
            return true
        end
    end
end
if infernoInstalled then
    script.on_fire_event(Defines.FireEvents.WEAPON_FIRE, function(ship, weapon, projectile) handle_shotgun_bomb(weapon, projectile) end, INT_MAX)
else
    local function handle_shotgun_bomb_wrapper(weapons)
        for weapon in vter(weapons) do
            if shotgunBombs[weapon.blueprint.name] then
                local projectile = weapon:GetProjectile()
                while projectile do
                    handle_shotgun_bomb(weapon, projectile)
                    projectile = weapon:GetProjectile()
                end
            end
        end
    end
    script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
        local weaponsPlayer = nil
        if pcall(function() weaponsPlayer = Hyperspace.ships.player.weaponSystem.weapons end) and weaponsPlayer then
            handle_shotgun_bomb_wrapper(weaponsPlayer)
        end
        local weaponsEnemy = nil
        if pcall(function() weaponsEnemy = Hyperspace.ships.enemy.weaponSystem.weapons end) and weaponsEnemy then
            handle_shotgun_bomb_wrapper(weaponsEnemy)
        end
    end)
end

-- Delete flintlock projectile 15% of the time
local function handle_flintlock(weapon, projectile)
    if weapon.blueprint.name == "AC_FLINTLOCK" and Hyperspace.random32()%100 < 15 then
        Hyperspace.Global.GetInstance():GetSoundControl():PlaySoundMix("flintlockMisfire", 1, false)
        projectile:Kill()
        return true
    end
end
if infernoInstalled then
    script.on_fire_event(Defines.FireEvents.WEAPON_FIRE, function(ship, weapon, projectile) handle_flintlock(weapon, projectile) end, INT_MAX)
else
    local function handle_flintlock_wrapper(weapons)
        for weapon in vter(weapons) do
            if weapon.blueprint.name == "AC_FLINTLOCK" then
                local projectile = weapon:GetProjectile()
                while projectile do
                    Hyperspace.Global.GetInstance():GetCApp().world.space.projectiles:push_back(projectile)
                    handle_flintlock(weapon, projectile)
                    projectile = weapon:GetProjectile()
                end
            end
        end
    end
    script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
        local weaponsPlayer = nil
        if pcall(function() weaponsPlayer = Hyperspace.ships.player.weaponSystem.weapons end) and weaponsPlayer then
            handle_flintlock_wrapper(weaponsPlayer)
        end
        local weaponsEnemy = nil
        if pcall(function() weaponsEnemy = Hyperspace.ships.enemy.weaponSystem.weapons end) and weaponsEnemy then
            handle_flintlock_wrapper(weaponsEnemy)
        end
    end)
end

-------------------------------------------
-- SWARM CONTROL BY MOUSE / LOOK DIRECTION
-------------------------------------------

local TICK_INTERVAL = 1
local RAY_DISTANCE = 100

script.on_init(function()
    storage.swarm_follow_mouse = false
    storage.active_group = nil
end)

remote.add_interface("ai_core", {
    follow_mouse = function()
        storage.swarm_follow_mouse = true
        game.print("AI Swarm: Слідування за курсором Увімкнено.")
    end,
    
    stop_follow_mouse = function()
        storage.swarm_follow_mouse = false
        if storage.active_group and storage.active_group.valid then
            storage.active_group.destroy()
            storage.active_group = nil
        end
        game.print("AI Swarm: Слідування за курсором Вимкнено.")
    end
})

script.on_nth_tick(1, function()
    if not storage.swarm_follow_mouse then return end
    
    local player = game.get_player(1)
    if not (player and player.valid and player.connected) then return end
    
    local surface = player.surface
    local character = player.character
    if not (character and character.valid) then return end

    local units = surface.find_entities_filtered{type = "unit", force = "enemy"}
    if #units < 3 then 
        if storage.active_group and storage.active_group.valid then
            storage.active_group.destroy()
            storage.active_group = nil
        end
        return 
    end

    local target = player.selected
    local dest

    -- Перевіряємо, чи можна атакувати ціль
    local can_attack_target = false
    if target and target.valid then
        if target.health and target.health > 0 and target.force.name ~= "player" then
            can_attack_target = true
            dest = target.position
        end
    end

    if not can_attack_target then
        -- Біжимо вперед по напрямку гравця
        local p = character.position
        local r = character.orientation * 2 * math.pi
        dest = {
            x = p.x + math.cos(r) * RAY_DISTANCE,
            y = p.y + math.sin(r) * RAY_DISTANCE
        }
    end

    -- Створюємо нову групу або оновлюємо існуючу
    if storage.active_group and storage.active_group.valid then
        -- Оновлюємо команду для існуючої групи
        if can_attack_target then
            storage.active_group.set_command{
                type = defines.command.attack,
                target = target,
                distraction = defines.distraction.none
            }
        else
            storage.active_group.set_command{
                type = defines.command.go_to_location,
                destination = dest,
                distraction = defines.distraction.none,
                pathfind_flags = {
                    allow_destroy_friendly_entities = false
                }
            }
        end
    else
        -- Створюємо нову групу
        local cx, cy = 0, 0
        for _, u in pairs(units) do
            cx = cx + u.position.x
            cy = cy + u.position.y
        end
        cx, cy = cx / #units, cy / #units

        storage.active_group = surface.create_unit_group{position = {cx, cy}}
        for _, u in pairs(units) do
            storage.active_group.add_member(u)
        end

        if can_attack_target then
            storage.active_group.set_command{
                type = defines.command.attack,
                target = target,
                distraction = defines.distraction.none
            }
        else
            storage.active_group.set_command{
                type = defines.command.go_to_location,
                destination = dest,
                distraction = defines.distraction.none,
                pathfind_flags = {
                    allow_destroy_friendly_entities = false
                }
            }
        end
    end
end)
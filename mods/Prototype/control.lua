-------------------------------------------
-- SWARM CONTROL BY MOUSE TARGETING
-- API: ai_core.follow_mouse(), ai_core.stop_follow_mouse()
-------------------------------------------
script.on_init(function()
    storage.swarm_follow_mouse = false
end)

-------------------------------------------
-- PUBLIC API
-------------------------------------------
remote.add_interface("ai_core", {
    follow_mouse = function()
        storage.swarm_follow_mouse = true
        game.print("AI Swarm: Слідування за курсором Увімкнено.")
    end,

    stop_follow_mouse = function()
        storage.swarm_follow_mouse = false
        game.print("AI Swarm: Слідування за курсором Вимкнено.")
    end
})

-------------------------------------------
-- MAIN FOLLOW-MOUSE LOOP
-------------------------------------------
script.on_nth_tick(10, function()

    -- 1) Перевірки
    if not storage.swarm_follow_mouse then return end

    local player = game.player
    if not (player and player.valid) then return end

    local surface = player.surface
    if not surface then return end

    -- 2) Зібрати всіх біттерів
    local units = surface.find_entities_filtered{type="unit", force="enemy"}
    if #units < 3 then return end

    -- 3) Визначити точку, куди біжити
    local target = player.selected
    local dest

    if target and target.valid then
        dest = target.position
    else
        local p = player.position
        local r = player.look_direction

        dest = {
            x = p.x + math.cos(r) * 100,
            y = p.y + math.sin(r) * 100
        }
    end

    -- 4) Центр рою
    local cx, cy = 0, 0
    for _, u in pairs(units) do
        cx = cx + u.position.x
        cy = cy + u.position.y
    end
    cx, cy = cx / #units, cy / #units

    -- 5) Група
    local group = surface.create_unit_group{position={cx, cy}}
    for _, u in pairs(units) do group.add_member(u) end

    -- 6) Команда
    if target and target.valid then
        group.set_command{
            type = defines.command.attack,
            target = target,
            distraction = defines.distraction.by_enemy
        }
    else
        group.set_command{
            type = defines.command.go_to_location,
            destination = dest,
            distraction = defines.distraction.by_enemy
        }
    end

end)

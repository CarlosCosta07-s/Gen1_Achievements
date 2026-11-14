#!/usr/bin/env luajit
-- Execute the real mod against a controlled Portable Mod API 3 test double.
-- No ROM, game save, extracted asset or emulator runtime is required.

local function fail(message)
    io.stderr:write("Runtime harness failed: " .. message .. "\n")
    os.exit(1)
end

local function check(condition, message)
    if not condition then fail(message) end
end

local function split_tabs(line)
    local fields = {}
    local start_at = 1
    for index = 1, #line do
        if line:sub(index, index) == "\t" then
            fields[#fields + 1] = line:sub(start_at, index - 1)
            start_at = index + 1
        end
    end
    fields[#fields + 1] = line:sub(start_at)
    return fields
end

local function parse_scalar(value)
    if value == "true" then return true end
    if value == "false" then return false end
    local number = tonumber(value)
    if number ~= nil then return number end
    return value
end

local function read_file(path)
    local file, err = io.open(path, "rb")
    check(file ~= nil, "cannot read " .. path .. ": " .. tostring(err))
    local contents = file:read("*a")
    file:close()
    return contents
end

local function load_rows()
    local rows = {}
    local contents = read_file("data/achievements.tsv")
    for line in (contents .. "\n"):gmatch("(.-)\n") do
        line = line:gsub("\r$", "")
        if line ~= "" and line:sub(1, 1) ~= "#" then
            local fields = split_tabs(line)
            check(#fields == 15, "catalog row must contain 15 fields")
            rows[#rows + 1] = fields
        end
    end
    return rows
end

local function make_environment(game_id, initial_cache, language)
    local listeners = {}
    local emitted = {}
    local cache = initial_cache or {}
    local screens = {}
    local hook_wrappers = {}
    local option_definitions = {}
    local pressed = {}
    local touch_down = {}
    local drawn = {}
    local pushes = {}
    local write_count = 0
    local fail_writes = false
    local pop_count = 0
    local selected_language = language or "pt-BR"
    local battle_snapshot = nil
    local submitted_intents = {}
    local game = {
        save = { version = game_id },
        input = {
            keyBindings = {
                up = "up", down = "down", left = "left", right = "right",
                z = "a", ["return"] = "a", space = "a",
                x = "b", backspace = "b",
            },
            padAction = function(_, button)
                local map = {
                    dpup = "up", dpdown = "down", dpleft = "left", dpright = "right",
                    a = "a", b = "b", x = "b",
                }
                return map[button]
            end,
            wasPressed = function(_, button)
                local value = pressed[button] == true
                pressed[button] = nil
                return value
            end,
            isDown = function(_, button)
                return pressed[button] == true
            end,
            isTouchDown = function(_, button)
                return touch_down[button] == true
            end,
            overlayPressed = function(_, button)
                touch_down[button] = true
                pressed[button] = true
            end,
            overlayReleased = function(_, button)
                touch_down[button] = false
            end,
        },
        stack = {
            pop = function()
                pop_count = pop_count + 1
            end,
        },
    }

    local mod = {}
    mod.options = {
        define = function(_, rows)
            option_definitions = rows
        end,
        get = function() return selected_language end,
    }
    mod.cache = {
        read = function(_, path)
            local value = cache[path]
            if value == nil then return nil, "not found" end
            return value
        end,
        write = function(_, path, value)
            if fail_writes then return false, "synthetic write failure" end
            cache[path] = value
            write_count = write_count + 1
            return true
        end,
    }
    mod.battle = {
        snapshot = function() return battle_snapshot end,
        submit = function(_, intent)
            submitted_intents[#submitted_intents + 1] = intent
            return true
        end,
    }
    mod.events = {
        on = function(_, name, callback)
            listeners[name] = listeners[name] or {}
            listeners[name][#listeners[name] + 1] = callback
        end,
        emit = function(_, name, payload)
            emitted[#emitted + 1] = { name = name, payload = payload }
        end,
    }
    mod.content = {
        screens = {
            register = function(_, screen_id, definition)
                screens[screen_id] = definition
            end,
        },
    }
    mod.ui = {
        Font = {
            draw = function(value, x, y)
                drawn[#drawn + 1] = {
                    text = tostring(value),
                    x = x,
                    y = y,
                }
            end,
            drawBox = function() end,
        },
        insertAfter = function(items, anchor, new_item)
            local output = {}
            local inserted = false
            for _, item in ipairs(items) do
                output[#output + 1] = item
                local label = type(item) == "table" and item.label or item
                if label == anchor then
                    output[#output + 1] = new_item
                    inserted = true
                end
            end
            if not inserted then output[#output + 1] = new_item end
            return output
        end,
        push = function(target_game, screen_id)
            pushes[#pushes + 1] = { game = target_game, id = screen_id }
        end,
    }
    mod.hooks = {
        wrap = function(_, name, callback)
            hook_wrappers[name] = callback
        end,
    }
    mod.log = {}
    for _, level in ipairs({ "info", "warn", "error" }) do
        mod.log[level] = function() end
    end
    function mod:supports(surface, name)
        if surface == "events" then return true end
        if surface == "hooks" then
            return name == "ui.start_menu.items"
                or name == "ui.options.rows"
                or name == "ui.party.submenu"
                or name == "battle.bottom_ui_visible"
                or name == "input.step"
                or name == "input.key"
                or name == "input.gamepad"
                or name == "input.pointer"
                or name == "render.hud"
                or name == "core.update"
        end
        return false
    end
    function mod:read(path)
        return read_file(path)
    end

    local initialize = dofile("main.lua")
    initialize(mod)

    local env = {
        game = game,
        cache = cache,
        emitted = emitted,
        listeners = listeners,
        screens = screens,
        hook_wrappers = hook_wrappers,
        options = option_definitions,
        drawn = drawn,
        submitted_intents = submitted_intents,
        pushes = pushes,
    }
    function env:dispatch(name, payload)
        payload = payload or {}
        for _, callback in ipairs(listeners[name] or {}) do
            callback(payload)
        end
    end
    function env:set_write_failure(value)
        fail_writes = value
    end
    function env:set_language(value)
        selected_language = value
    end
    function env:set_battle_snapshot(value)
        battle_snapshot = value
    end
    function env:set_touch_down(button, value)
        touch_down[button] = value == true
    end
    function env:submitted()
        return submitted_intents
    end
    function env:write_count()
        return write_count
    end
    function env:press(button)
        pressed[button] = true
    end
    function env:clear_drawn()
        for index = #drawn, 1, -1 do drawn[index] = nil end
    end
    function env:draw_screen(screen)
        screen:draw()
    end
    function env:run_hook(name, next_result, ...)
        local callback = hook_wrappers[name]
        check(type(callback) == "function", "missing hook wrapper " .. name)
        return callback(function() return next_result end, ...)
    end
    function env:pop_count()
        return pop_count
    end
    return env
end

local function set_path(root, path, value)
    local segments = {}
    for segment in path:gmatch("[^%.]+") do
        segments[#segments + 1] = segment
    end
    local current = root
    for index = 1, #segments - 1 do
        local key = segments[index]
        if type(current[key]) ~= "table" then current[key] = {} end
        current = current[key]
    end
    if #segments > 0 then current[segments[#segments]] = value end
end

local function value_for(row, iteration)
    local operator = row[5]
    local encoded = row[6]
    if operator == "equals" or operator == "at_least" then
        return parse_scalar(encoded)
    elseif operator == "truthy" then
        return true
    elseif operator == "one_of" or operator == "one_of_true" then
        local options = {}
        for candidate in encoded:gmatch("[^|]+") do
            options[#options + 1] = parse_scalar(candidate)
        end
        return options[((iteration - 1) % #options) + 1]
    elseif operator == "ends_with" then
        return "SYNTHETIC_MAP_PREFIX_" .. encoded
    end
    return nil
end

local function make_event(row, env, iteration, valid)
    local event = { game = env.game }
    local operator = row[5]
    local field = row[4]

    if not valid then
        if operator == "equals" then
            set_path(event, field, "__not_the_expected_value__")
        elseif operator == "at_least" then
            set_path(event, field, math.max(0, (tonumber(row[6]) or 1) - 1))
        elseif operator == "truthy" then
            set_path(event, field, false)
        elseif operator == "one_of" then
            set_path(event, field, "__not_in_the_allowed_set__")
        elseif operator == "one_of_true" then
            set_path(event, field, value_for(row, 1))
            event.value = false
        elseif operator == "ends_with" then
            set_path(event, field, "NOT_THE_REQUESTED_MAP")
        else
            return nil
        end
        return event
    end

    if operator == "one_of_true" then event.value = true end
    if field ~= "*" then
        set_path(event, field, value_for(row, iteration))
    end
    return event
end

local function count_unlocks(env, achievement_id)
    local count = 0
    for _, item in ipairs(env.emitted) do
        if item.name == "mod.gen1_achievements.unlocked"
            and item.payload.achievement == achievement_id then
            count = count + 1
        end
    end
    return count
end

local rows = load_rows()
check(#rows > 0, "the achievement catalog is empty")

-- Each real catalog row is executed through main.lua in isolation. The
-- pre-load event must be ignored; after save.loaded, the declared condition
-- must unlock exactly once and survive serialization.
for _, row in ipairs(rows) do
    local game_id, achievement_id = row[1], row[2]
    local env = make_environment(game_id)
    env:dispatch("game.ready", { game = env.game })

    env:dispatch(row[3], make_event(row, env, 1, true))
    check(count_unlocks(env, achievement_id) == 0,
        achievement_id .. ": event during startup unlocked too early")
    check(env:write_count() == 0,
        achievement_id .. ": event during startup wrote the profile")

    env:dispatch("save.loaded", {})
    local negative = make_event(row, env, 1, false)
    if negative then
        env:dispatch(row[3], negative)
        check(count_unlocks(env, achievement_id) == 0,
            achievement_id .. ": non-matching event unlocked the achievement")
    end

    local target = row[7] == "counter" and tonumber(row[8]) or 1
    check(target ~= nil and target >= 1, achievement_id .. ": invalid test target")
    for iteration = 1, target do
        env:dispatch(row[3], make_event(row, env, iteration, true))
    end

    check(count_unlocks(env, achievement_id) == 1,
        achievement_id .. ": matching event sequence did not unlock exactly once")
    local profile = env.cache["profiles/" .. game_id .. ".dat"]
    check(type(profile) == "string"
        and profile:find("U|" .. achievement_id, 1, true) ~= nil,
        achievement_id .. ": unlock was not persisted")
    env:dispatch(row[3], make_event(row, env, 1, true))
    check(count_unlocks(env, achievement_id) == 1,
        achievement_id .. ": duplicate event emitted a second unlock")
end

-- Switching active titles must reject stale events from the previous game and
-- keep each title's progress in its own cache file.
local function find_row(game_id, achievement_id)
    for _, row in ipairs(rows) do
        if row[1] == game_id and row[2] == achievement_id then return row end
    end
    fail("missing fixture " .. achievement_id)
end

local red_row = find_row("red", "red_evolve_5")
local blue_row = find_row("blue", "blue_evolve_5")
local env = make_environment("red")
env:dispatch("game.ready", { game = env.game })
env:dispatch("save.loaded", {})
env:dispatch(red_row[3], make_event(red_row, env, 1, true))

local old_red_game = env.game
local blue_game = {
    save = { version = "blue" },
    input = { wasPressed = function() return false end },
    stack = { pop = function() end },
}
env.game = blue_game
env:dispatch("game.ready", { game = blue_game })
env:dispatch(red_row[3], {
    game = old_red_game,
})
local red_progress = env.cache["profiles/red.dat"] or ""
check(red_progress:find("P|red_evolve_5|1", 1, true) ~= nil,
    "stale event from Red changed its stored progress")
env:dispatch("save.loaded", {})
for iteration = 1, 5 do
    env:dispatch(blue_row[3], make_event(blue_row, env, iteration, true))
end
check(count_unlocks(env, "blue_evolve_5") == 1,
    "Blue did not unlock independently")
check((env.cache["profiles/blue.dat"] or ""):find("U|blue_evolve_5", 1, true) ~= nil,
    "Blue unlock was not written to the Blue profile")
check((env.cache["profiles/blue.dat"] or ""):find("red_evolve_5", 1, true) == nil,
    "Red achievement leaked into the Blue profile")

env.game = old_red_game
env:dispatch("game.ready", { game = old_red_game })
for iteration = 2, 5 do
    env:dispatch(red_row[3], make_event(red_row, env, iteration, true))
end
check(count_unlocks(env, "red_evolve_5") == 1,
    "Red progress did not resume from its own profile")
check((env.cache["profiles/red.dat"] or ""):find("U|red_evolve_5", 1, true) ~= nil,
    "Red unlock was not written to the Red profile")

-- Legacy format is accepted and upgraded on the next successful write.
local legacy_cache = {
    ["profiles/red.dat"] = "GEN1ACHIEVEMENTS1\nU|red_dex_10\n",
}
local legacy_env = make_environment("red", legacy_cache)
legacy_env:dispatch("game.ready", { game = legacy_env.game })
legacy_env:dispatch("save.loaded", {})
local articuno = find_row("red", "red_articuno_captured")
legacy_env:dispatch(articuno[3], make_event(articuno, legacy_env, 1, true))
local migrated = legacy_env.cache["profiles/red.dat"] or ""
check(migrated:sub(1, #"GEN1ACHIEVEMENTS2") == "GEN1ACHIEVEMENTS2",
    "legacy profile was not migrated to format 2")
check(migrated:find("U|red_dex_10", 1, true) ~= nil,
    "legacy unlock was lost during migration")

-- A profile containing another game's achievement ID is rejected rather
-- than importing progress across titles.
local corrupt_cache = {
    ["profiles/red.dat"] = "GEN1ACHIEVEMENTS2\nU|blue_dex_10\n",
}
local corrupt_env = make_environment("red", corrupt_cache)
corrupt_env:dispatch("game.ready", { game = corrupt_env.game })
corrupt_env:dispatch("save.loaded", {})
corrupt_env:dispatch(articuno[3], make_event(articuno, corrupt_env, 1, true))
local recovered = corrupt_env.cache["profiles/red.dat"] or ""
check(recovered:find("blue_dex_10", 1, true) == nil,
    "foreign-game ID survived profile validation")
check(recovered:find("U|red_articuno_captured", 1, true) ~= nil,
    "profile did not recover after rejecting foreign-game data")

-- A failed disk write must roll back the in-memory unlock and allow a retry.
local write_env = make_environment("red")
write_env:dispatch("game.ready", { game = write_env.game })
write_env:dispatch("save.loaded", {})
write_env:set_write_failure(true)
write_env:dispatch(articuno[3], make_event(articuno, write_env, 1, true))
check(count_unlocks(write_env, "red_articuno_captured") == 0,
    "failed cache write still emitted an unlock")
write_env:set_write_failure(false)
write_env:dispatch(articuno[3], make_event(articuno, write_env, 1, true))
check(count_unlocks(write_env, "red_articuno_captured") == 1,
    "achievement could not be retried after a failed cache write")

-- save.loading closes the gate again; no progress is counted until save.loaded.
local gate_env = make_environment("red")
gate_env:dispatch("game.ready", { game = gate_env.game })
gate_env:dispatch("save.loaded", {})
gate_env:dispatch(red_row[3], make_event(red_row, gate_env, 1, true))
gate_env:dispatch("save.loading", {})
for iteration = 2, 5 do
    gate_env:dispatch(red_row[3], make_event(red_row, gate_env, iteration, true))
end
check(count_unlocks(gate_env, "red_evolve_5") == 0,
    "save.loading did not close the event gate")
gate_env:dispatch("save.loaded", {})
for iteration = 2, 5 do
    gate_env:dispatch(red_row[3], make_event(red_row, gate_env, iteration, true))
end
check(count_unlocks(gate_env, "red_evolve_5") == 1,
    "save.loaded did not reopen the event gate")


-- Malformed profiles must be rejected as a whole, never partially trusted.
-- Each case starts with one valid unlock so the assertion proves that the
-- parser discarded the complete invalid profile before persisting new data.
local malformed_profiles = {
    {
        name = "duplicate unlock",
        bytes = "GEN1ACHIEVEMENTS2\nU|red_dex_10\nU|red_dex_10\n",
    },
    {
        name = "progress on an instant achievement",
        bytes = "GEN1ACHIEVEMENTS2\nU|red_dex_10\nP|red_articuno_captured|1\n",
    },
    {
        name = "counter already at its unlock threshold",
        bytes = "GEN1ACHIEVEMENTS2\nU|red_dex_10\nP|red_evolve_5|5\n",
    },
    {
        name = "counter above its unlock threshold",
        bytes = "GEN1ACHIEVEMENTS2\nU|red_dex_10\nP|red_evolve_5|6\n",
    },
    {
        name = "duplicate counter row",
        bytes = "GEN1ACHIEVEMENTS2\nU|red_dex_10\nP|red_evolve_5|1\nP|red_evolve_5|2\n",
    },
    {
        name = "unlock and progress collision",
        bytes = "GEN1ACHIEVEMENTS2\nU|red_dex_10\nU|red_evolve_5\nP|red_evolve_5|1\n",
    },
    {
        name = "unknown achievement ID",
        bytes = "GEN1ACHIEVEMENTS2\nU|red_dex_10\nU|red_not_in_catalog\n",
    },
    {
        name = "malformed record",
        bytes = "GEN1ACHIEVEMENTS2\nU|red_dex_10\nX|unexpected\n",
    },
    {
        name = "unsupported profile version",
        bytes = "GEN1ACHIEVEMENTS99\nU|red_dex_10\n",
    },
    {
        name = "negative counter",
        bytes = "GEN1ACHIEVEMENTS2\nU|red_dex_10\nP|red_evolve_5|-1\n",
    },
    {
        name = "fractional counter",
        bytes = "GEN1ACHIEVEMENTS2\nU|red_dex_10\nP|red_evolve_5|1.5\n",
    },
}
for _, case in ipairs(malformed_profiles) do
    local cache = { ["profiles/red.dat"] = case.bytes }
    local env = make_environment("red", cache)
    env:dispatch("game.ready", { game = env.game })
    env:dispatch("save.loaded", {})
    env:dispatch(articuno[3], make_event(articuno, env, 1, true))
    local recovered_profile = env.cache["profiles/red.dat"] or ""
    check(recovered_profile:find("U|red_articuno_captured", 1, true) ~= nil,
        case.name .. ": a fresh valid unlock was not persisted after recovery")
    check(recovered_profile:find("U|red_dex_10", 1, true) == nil,
        case.name .. ": the valid-looking prefix of a malformed profile was trusted")
    check(recovered_profile:find("red_not_in_catalog", 1, true) == nil,
        case.name .. ": foreign data survived the profile reset")
end

-- A valid partial profile must retain both completed achievements and counters
-- when a different achievement is unlocked and the profile is rewritten.
local valid_partial_cache = {
    ["profiles/red.dat"] =
        "GEN1ACHIEVEMENTS2\nU|red_dex_10\nP|red_evolve_5|2\n",
}
local valid_partial_env = make_environment("red", valid_partial_cache)
valid_partial_env:dispatch("game.ready", { game = valid_partial_env.game })
valid_partial_env:dispatch("save.loaded", {})
valid_partial_env:dispatch(articuno[3], make_event(articuno, valid_partial_env, 1, true))
local preserved = valid_partial_env.cache["profiles/red.dat"] or ""
check(preserved:find("U|red_dex_10", 1, true) ~= nil,
    "valid profile rewrite lost an existing unlock")
check(preserved:find("P|red_evolve_5|2", 1, true) ~= nil,
    "valid profile rewrite lost partial counter progress")

-- save.created is the legitimate start of a fresh gameplay session too.
local created_env = make_environment("red")
created_env:dispatch("game.ready", { game = created_env.game })
created_env:dispatch(red_row[3], make_event(red_row, created_env, 1, true))
check(count_unlocks(created_env, "red_evolve_5") == 0,
    "game.ready alone opened a new-game session")
created_env:dispatch("save.created", {})
for iteration = 1, 5 do
    created_env:dispatch(red_row[3], make_event(red_row, created_env, iteration, true))
end
check(count_unlocks(created_env, "red_evolve_5") == 1,
    "save.created did not open the new-game session")

-- Exercise the actual mod-owned menu hook and screen implementation.
-- This covers the UI surface that the previous event-only harness did not run.
local ui_env = make_environment("red")
local screen_id = "Gen1AchievementConsole"
check(ui_env.screens[screen_id] ~= nil,
    "the mod did not register its achievement screen")

local base_menu = {
    { label = "POKEDEX" },
    { label = "SAVE" },
    { label = "OTHER MOD ENTRY" },
    { label = "OPTION" },
    { label = "QUIT" },
}
local menu = ui_env:run_hook(
    "ui.start_menu.items", base_menu, ui_env.game, base_menu
)
check(type(menu) == "table" and #menu == #base_menu + 1,
    "START menu hook did not preserve the vanilla rows and add one row")
check(menu[1].label == "POKEDEX" and menu[2].label == "SAVE",
    "START menu hook changed the rows before SAVE")
check(menu[3].label == "CONQUISTAS" and type(menu[3].onSelect) == "function",
    "achievement entry was not inserted immediately after SAVE")
check(menu[4].label == "OTHER MOD ENTRY"
    and menu[5].label == "OPTION" and menu[6].label == "QUIT",
    "achievement hook did not preserve another mod's menu entry")
menu[3].onSelect()
check(#ui_env.pushes == 1 and ui_env.pushes[1].game == ui_env.game
    and ui_env.pushes[1].id == screen_id,
    "START menu selection did not push the mod-owned achievement screen")

local screen = ui_env.screens[screen_id].new(ui_env.game)
local function draw_contains(fragment)
    ui_env:clear_drawn()
    ui_env:draw_screen(screen)
    for _, item in ipairs(ui_env.drawn) do
        if item.text:find(fragment, 1, true) then return true end
    end
    return false
end

check(draw_contains("CONQUISTAS") and draw_contains("PROGRESSO")
    and draw_contains("< TODAS >"),
    "achievement screen did not draw its title, progress and default filter")

ui_env:press("right")
screen:update(0)
check(draw_contains("< DESBLOQUEADAS >")
    and draw_contains("AINDA SEM CONQUISTAS")
    and draw_contains("ESQ/DIR: FILTRO"),
    "Unlocked filter did not show its empty state for a fresh profile")

ui_env:press("right")
screen:update(0)
check(draw_contains("< BLOQUEADAS >")
    and not draw_contains("AINDA SEM CONQUISTAS"),
    "Locked filter did not show the locked catalog")

ui_env:press("left")
screen:update(0)
check(draw_contains("< DESBLOQUEADAS >")
    and draw_contains("AINDA SEM CONQUISTAS"),
    "left navigation did not return from Locked to Unlocked")
ui_env:press("left")
screen:update(0)
check(draw_contains("< TODAS >"),
    "left navigation did not return from Unlocked to All")

-- Move beyond the first five rows and verify that the viewport still renders
-- exactly five list entries instead of clipping the cursor off-screen.
for _ = 1, 6 do
    ui_env:press("down")
    screen:update(0)
end
ui_env:clear_drawn()
ui_env:draw_screen(screen)
local visible_rows = 0
for _, item in ipairs(ui_env.drawn) do
    if item.x == 16 and item.y >= 58 and item.y <= 106 then
        visible_rows = visible_rows + 1
    end
end
check(visible_rows == 5,
    "D-pad scrolling did not keep exactly five achievement rows visible")

ui_env:press("a")
screen:update(0)
check(draw_contains("BLOQUEADA") and draw_contains("B: VOLTAR"),
    "A did not open the selected achievement details")
ui_env:press("b")
screen:update(0)
check(draw_contains("< TODAS >") and draw_contains("A: DETALHES")
    and draw_contains("ESQ/DIR: FILTRO"),
    "B did not return from details to the achievement list")
ui_env:press("start")
screen:update(0)
check(ui_env:pop_count() == 1,
    "START did not close the achievement screen")

local second_screen = ui_env.screens[screen_id].new(ui_env.game)
ui_env:press("b")
second_screen:update(0)
check(ui_env:pop_count() == 2,
    "B did not close the achievement screen from its main list")

-- Render the screen for every supported title and locale. The displayed
-- title, total count and menu strings must follow the active game/language.
local game_titles = {
    red = "POKEMON RED",
    blue = "POKEMON BLUE",
    yellow = "POKEMON YELLOW",
    gold = "POKEMON GOLD",
    silver = "POKEMON SILVER",
    crystal = "POKEMON CRYSTAL",
    firered = "POKEMON FIRERED",
    leafgreen = "POKEMON LEAFGREEN",
    ruby = "POKEMON RUBY",
    sapphire = "POKEMON SAPPHIRE",
    emerald = "POKEMON EMERALD",
}
local locale_expectations = {
    en = {
        menu = "ACHIEVEMENTS",
        title = "ACHIEVEMENTS",
        progress = "PROGRESS",
        filter = "< ALL >",
        help = "LEFT/RIGHT: FILTER",
    },
    ["pt-BR"] = {
        menu = "CONQUISTAS",
        title = "CONQUISTAS",
        progress = "PROGRESSO",
        filter = "< TODAS >",
        help = "ESQ/DIR: FILTRO",
    },
    es = {
        menu = "LOGROS",
        title = "LOGROS",
        progress = "PROGRESO",
        filter = "< TODOS >",
        help = "IZQ/DER: FILTRO",
    },
}
local catalog_counts = {}
for _, row in ipairs(rows) do
    catalog_counts[row[1]] = (catalog_counts[row[1]] or 0) + 1
end

local function rendered_text(env, screen)
    env:clear_drawn()
    env:draw_screen(screen)
    local pieces = {}
    for _, item in ipairs(env.drawn) do
        pieces[#pieces + 1] = item.text
    end
    return table.concat(pieces, "\n")
end

for game_id, game_title in pairs(game_titles) do
    for language, expected in pairs(locale_expectations) do
        local env = make_environment(game_id, nil, language)
        local screen = env.screens[screen_id].new(env.game)
        local rendered = rendered_text(env, screen)
        check(rendered:find(game_title, 1, true) ~= nil,
            game_id .. "/" .. language .. ": wrong game title on achievements screen")
        check(rendered:find(expected.title, 1, true) ~= nil,
            game_id .. "/" .. language .. ": wrong localized screen title")
        check(rendered:find(expected.progress .. " 0/" .. catalog_counts[game_id], 1, true) ~= nil,
            game_id .. "/" .. language .. ": incorrect localized progress summary")
        check(rendered:find(expected.filter, 1, true) ~= nil,
            game_id .. "/" .. language .. ": default filter was not localized")
        check(rendered:find(expected.help, 1, true) ~= nil,
            game_id .. "/" .. language .. ": filter control hint was not localized")

        local items = {
            { label = "SAVE" },
            { label = "OPTION" },
        }
        local menu_result = env:run_hook(
            "ui.start_menu.items", items, env.game, items
        )
        check(menu_result[2].label == expected.menu,
            game_id .. "/" .. language .. ": START menu label was not localized")
    end
end

-- Secret achievements remain hidden in the detail screen until their live
-- event is received. Opening or browsing the list must not grant them.
local secret_row
local secret_index = 0
for _, row in ipairs(rows) do
    if row[1] == "red" then
        secret_index = secret_index + 1
        if row[9] == "true" then
            secret_row = row
            break
        end
    end
end
check(secret_row ~= nil, "Red catalog must contain a secret achievement")

local secret_env = make_environment("red")
secret_env:dispatch("game.ready", { game = secret_env.game })
local secret_screen = secret_env.screens[screen_id].new(secret_env.game)
for _ = 2, secret_index do
    secret_env:press("down")
    secret_screen:update(0)
end
secret_env:press("a")
secret_screen:update(0)
local hidden_detail = rendered_text(secret_env, secret_screen)
check(hidden_detail:find("???", 1, true) ~= nil
    and hidden_detail:find("Desbloqueie", 1, true) ~= nil,
    "locked secret achievement revealed its title or description")
check(secret_env:write_count() == 0,
    "opening a secret achievement modified the profile")
secret_env:dispatch("save.loaded", {})
secret_env:dispatch(secret_row[3], make_event(secret_row, secret_env, 1, true))
local revealed_detail = rendered_text(secret_env, secret_screen)
check(revealed_detail:find("O Guardião", 1, true) ~= nil,
    "the live unlock did not reveal the secret achievement title")
check(revealed_detail:find("Capture Articuno", 1, true) ~= nil,
    "the live unlock did not reveal the localized secret description")

-- The mod's own setting stays in the in-game MODS manager via
-- mod.options:define; it is not copied into the game's general OPTIONS rows.
check(type(ui_env.options) == "table" and #ui_env.options == 1
    and ui_env.options[1].key == "achievement_language"
    and ui_env.options[1].type == "choice"
    and ui_env.options[1].default == "pt-BR"
    and #ui_env.options[1].choices == 3,
    "the achievement language setting was not registered in the MODS manager")

-- The public ui.options.rows hook sorts native setting rows inside their
-- existing groups while preserving third-party rows and the original objects.
local option_row_ids = {
    "sfxVol", "third_party_audio", "musicVol",
    "animations", "third_party_general", "battleStyle",
    "videoMode", "uiLayout", "orientation", "musicFilter", "pikaVol",
    "vsync", "screenPos", "faithfulRes", "audioMode",
    "shaderfx", "colors", "uiLetterbox", "shaderfx2",
    "speedBattle", "textSpeed", "speedMenu", "speedOverworld",
    "battleBg", "battleHud", "battleLayout", "battleFit",
    "zoom", "tilt", "voidFill",
}
local expected_category_orders = {
    { "audioMode", "musicVol", "sfxVol", "pikaVol", "musicFilter" },
    { "uiLayout", "orientation", "videoMode", "faithfulRes",
        "screenPos", "vsync", "fpsCap", "logicClock" },
    { "colors", "shaderfx", "shaderfx2", "uiLetterbox" },
    { "battleStyle", "animations", "battleLayout", "battleFit",
        "battleHud", "battleBg" },
    { "textSpeed", "speedOverworld", "speedBattle", "speedMenu" },
    { "tilt", "zoom", "voidFill" },
}
local function make_option_rows()
    local result = {}
    for _, id in ipairs(option_row_ids) do
        result[#result + 1] = {
            id = id,
            label = id,
            marker = "preserve-" .. id,
        }
    end
    return result
end

local supported_versions = {
    "red", "blue", "yellow", "gold", "silver", "crystal",
    "firered", "leafgreen", "ruby", "sapphire", "emerald",
}
for _, game_id in ipairs(supported_versions) do
    local env = make_environment(game_id)
    local input_rows = make_option_rows()
    local original_rows = {}
    for index, row in ipairs(input_rows) do original_rows[index] = row end

    local organized = env:run_hook(
        "ui.options.rows", input_rows, env.game, input_rows
    )
    check(type(organized) == "table" and #organized == #input_rows,
        game_id .. ": options hook changed the number of rows")

    local native_ids = {}
    for _, category_order in ipairs(expected_category_orders) do
        local category_ids = {}
        for _, id in ipairs(category_order) do
            category_ids[id] = true
            native_ids[id] = true
        end

        local actual = {}
        for _, row in ipairs(organized) do
            if category_ids[row.id] then
                actual[#actual + 1] = row.id
            end
        end

        local expected = {}
        for _, id in ipairs(category_order) do
            local present = false
            for _, row in ipairs(input_rows) do
                if row.id == id then present = true; break end
            end
            if present then expected[#expected + 1] = id end
        end

        check(#actual == #expected,
            game_id .. ": an options category gained or lost a row")
        for index, expected_id in ipairs(expected) do
            check(actual[index] == expected_id,
                game_id .. ": wrong category ordering at item "
                    .. tostring(index) .. "; expected " .. expected_id
                    .. ", got " .. tostring(actual[index]))
        end
    end

    -- Every row unknown to this mod stays at the same slot and is not cloned.
    for index, original in ipairs(original_rows) do
        if not native_ids[original.id] then
            check(organized[index] == original,
                game_id .. ": another mod's option row was moved or replaced")
        end
    end

    for index, row in ipairs(organized) do
        check(row.marker == "preserve-" .. row.id,
            game_id .. ": option row data was changed at slot " .. tostring(index))
    end
end

-- An invalid downstream result is passed through unchanged so the engine can
-- apply its own documented fallback to the vanilla option list.
local invalid_options_env = make_environment("red")
local invalid_result = invalid_options_env:run_hook(
    "ui.options.rows", false, invalid_options_env.game, {}
)
check(invalid_result == false,
    "options hook did not preserve a non-table downstream result")

-- Party action submenus preserve field moves and unknown entries while
-- grouping the common actions into a predictable order.
local party_env = make_environment("red")
local party_rows = {
    { label = "CUT", action = "escape", move = "CUT" },
    { label = "SWITCH", action = "switch" },
    { label = "CANCEL", action = "cancel" },
    { label = "STATS", action = "stats" },
    { label = "MOD ACTION", action = "other" },
}
local party_result = party_env:run_hook(
    "ui.party.submenu", party_rows, party_env.game, party_rows, {}, { battle = false }
)
check(party_result[1] == party_rows[1]
    and party_result[2].action == "stats"
    and party_result[3].action == "switch"
    and party_result[4].action == "cancel"
    and party_result[5] == party_rows[5],
    "party submenu did not group common actions while preserving field moves and mods")
local battle_party_rows = {
    { label = "STATS", action = "stats" },
    { label = "CANCEL", action = "cancel" },
    { label = "SWITCH", action = "switch" },
}
local battle_party_result = party_env:run_hook(
    "ui.party.submenu", battle_party_rows, party_env.game,
    battle_party_rows, {}, { battle = true }
)
check(battle_party_result[1].action == "switch"
    and battle_party_result[2].action == "stats"
    and battle_party_result[3].action == "cancel",
    "battle party submenu did not put SWITCH first")

-- LÖVE draw stub for the vector battle overlay; records text and colors so
-- the visual contract can be exercised without game assets or a ROM.
local battle_draw_calls = {}
local battle_draw_colors = {}
love = love or {}
love.graphics = {
    push = function() battle_draw_calls[#battle_draw_calls + 1] = { kind = "push" } end,
    pop = function() battle_draw_calls[#battle_draw_calls + 1] = { kind = "pop" } end,
    translate = function(x, y)
        battle_draw_calls[#battle_draw_calls + 1] = { kind = "translate", x = x, y = y }
    end,
    scale = function(value)
        battle_draw_calls[#battle_draw_calls + 1] = { kind = "scale", value = value }
    end,
    setColor = function(r, g, b, a)
        local color = { r, g, b, a }
        battle_draw_colors[#battle_draw_colors + 1] = color
        battle_draw_calls[#battle_draw_calls + 1] = { kind = "color", value = color }
    end,
    rectangle = function(mode, x, y, w, h)
        battle_draw_calls[#battle_draw_calls + 1] = {
            kind = "rectangle", mode = mode, x = x, y = y, w = w, h = h,
        }
    end,
    print = function(value, x, y)
        battle_draw_calls[#battle_draw_calls + 1] = {
            kind = "text", value = tostring(value), x = x, y = y,
        }
    end,
    printf = function(value, x, y, w, align)
        battle_draw_calls[#battle_draw_calls + 1] = {
            kind = "text", value = tostring(value), x = x, y = y, w = w, align = align,
        }
    end,
}

local battle_titles = {
    "red", "blue", "yellow", "gold", "silver", "crystal",
    "firered", "leafgreen", "ruby", "sapphire", "emerald",
}
local battle_accents = {}
local base_viewport = {
    width = 160, height = 144, gameX = 0, gameY = 0,
    gameWidth = 160, gameHeight = 144, scale = 1,
}
local menu_snapshot = {
    prompt = "menu", kind = "wild", revision = 1,
    player = { name = "PIKACHU" }, enemy = { name = "RATTATA" },
    party = {}, moves = {}, items = {},
}
for _, game_id in ipairs(battle_titles) do
    for index = #battle_draw_calls, 1, -1 do battle_draw_calls[index] = nil end
    for index = #battle_draw_colors, 1, -1 do battle_draw_colors[index] = nil end
    local env = make_environment(game_id)
    env:set_battle_snapshot(menu_snapshot)
    env:run_hook("render.hud", nil, env.game, base_viewport)
    local joined = {}
    for _, call in ipairs(battle_draw_calls) do
        if call.kind == "text" then joined[#joined + 1] = call.value end
    end
    local drawn_text = table.concat(joined, "\n")
    local is_gen1 = game_id == "red" or game_id == "blue" or game_id == "yellow"
    local is_gen2 = game_id == "gold" or game_id == "silver" or game_id == "crystal"
    local item_label = is_gen1 and "ITEM" or is_gen2 and "BOLSA" or "BOLSA"
    check(drawn_text:find("AÇÃO", 1, true) ~= nil
        and drawn_text:find("A: SELECIONAR", 1, true) ~= nil
        and drawn_text:find("LUTAR", 1, true) ~= nil
        and drawn_text:find(item_label, 1, true) ~= nil
        and drawn_text:find("POKEMON", 1, true) ~= nil
        and drawn_text:find("FUGIR", 1, true) ~= nil,
        game_id .. ": battle action panel omitted a localized action")
    local fight_pos = drawn_text:find("LUTAR", 1, true)
    local pokemon_pos = drawn_text:find("POKEMON", 1, true)
    local item_pos = drawn_text:find(item_label, 1, true)
    if is_gen1 or is_gen2 then
        check(fight_pos < pokemon_pos and pokemon_pos < item_pos,
            game_id .. ": Kanto/Johto battle order did not put Pokemon before Item/Pack")
    else
        check(fight_pos < item_pos and item_pos < pokemon_pos,
            game_id .. ": Hoenn/Kanto-remake battle order did not put Bag before Pokemon")
    end
    check(#battle_draw_colors >= 3,
        game_id .. ": battle panel did not draw its version colors")
    battle_accents[game_id] = battle_draw_colors[2]
end
local unique_accents = {}
for _, color in pairs(battle_accents) do
    unique_accents[("%.3f/%.3f/%.3f"):format(color[1], color[2], color[3])] = true
end
local accent_count = 0
for _ in pairs(unique_accents) do accent_count = accent_count + 1 end
check(accent_count >= 8,
    "the eleven game variants did not retain distinct battle accent palettes")

-- Main command selection must submit the validated semantic intent, not
-- synthesize an engine turn or mutate a save record.
local command_env = make_environment("red")
command_env:set_battle_snapshot(menu_snapshot)
command_env:run_hook(
    "input.key", nil, command_env.game, { phase = "pressed", key = "z" }
)
check(#command_env:submitted() == 1
    and command_env:submitted()[1].kind == "menu"
    and command_env:submitted()[1].choice == "fight"
    and command_env:submitted()[1].revision == 1,
    "keyboard A did not submit the Fight command against the current revision")

-- Move selection supports the four-slot grid, PP and type metadata.
local move_snapshot = {
    prompt = "moves", kind = "wild", revision = 2,
    player = { name = "PIKACHU" }, enemy = { name = "RATTATA" },
    party = {}, items = {},
    moves = {
        { id = "THUNDERBOLT", name = "THUNDERBOLT", type = "ELECTRIC", slot = 1, pp = 15, maxPp = 15 },
        { id = "QUICK_ATTACK", name = "QUICK ATTACK", type = "NORMAL", slot = 2, pp = 30, maxPp = 30 },
        { id = "THUNDER_WAVE", name = "THUNDER WAVE", type = "ELECTRIC", slot = 3, pp = 20, maxPp = 20 },
        { id = "IRON_TAIL", name = "IRON TAIL", type = "STEEL", slot = 4, pp = 15, maxPp = 15 },
    },
}
command_env:set_battle_snapshot(move_snapshot)
for index = #battle_draw_calls, 1, -1 do battle_draw_calls[index] = nil end
command_env:run_hook("render.hud", nil, command_env.game, base_viewport)
local move_text = {}
for _, call in ipairs(battle_draw_calls) do
    if call.kind == "text" then move_text[#move_text + 1] = call.value end
end
local rendered_moves = table.concat(move_text, "\n")
check(rendered_moves:find("THUNDERBOLT", 1, true) ~= nil
    and rendered_moves:find("ELECTRIC", 1, true) ~= nil
    and rendered_moves:find("PP 15/15", 1, true) ~= nil,
    "move menu omitted move name, type badge or PP")
command_env:run_hook(
    "input.gamepad", nil, command_env.game, { phase = "pressed", button = "a" }
)
check(#command_env:submitted() == 2
    and command_env:submitted()[2].kind == "move"
    and command_env:submitted()[2].slot == 1
    and command_env:submitted()[2].revision == 2,
    "gamepad A did not submit the selected move slot")
local no_moves_snapshot = {
    prompt = "moves", kind = "wild", revision = 3,
    player = {}, enemy = {}, party = {}, items = {}, moves = {},
}
command_env:set_battle_snapshot(no_moves_snapshot)
for index = #battle_draw_calls, 1, -1 do battle_draw_calls[index] = nil end
command_env:run_hook("render.hud", nil, command_env.game, base_viewport)
local empty_text = {}
for _, call in ipairs(battle_draw_calls) do
    if call.kind == "text" then empty_text[#empty_text + 1] = call.value end
end
check(table.concat(empty_text, "\n"):find("SEM GOLPES USÁVEIS", 1, true) ~= nil,
    "empty move menu did not show the localized empty state")
-- Gen 3 compacts the visible move list but preserves each native slot.
-- The public UnifiedBattle facade normalizes absent PP to zero before the
-- mod receives the snapshot, so zero is displayed and disabled consistently.
local gen3_move_env = make_environment("emerald")
local gen3_move_snapshot = {
    prompt = "moves", kind = "wild", revision = 1,
    player = {}, enemy = {}, party = {}, items = {},
    moves = {
        { id = "HIDDEN_POWER", name = "HIDDEN POWER", type = "DARK",
            slot = 3, pp = 10, maxPp = 10 },
    },
}
gen3_move_env:set_battle_snapshot(gen3_move_snapshot)
for index = #battle_draw_calls, 1, -1 do battle_draw_calls[index] = nil end
gen3_move_env:run_hook("render.hud", nil, gen3_move_env.game, base_viewport)
local gen3_move_text = {}
for _, call in ipairs(battle_draw_calls) do
    if call.kind == "text" then gen3_move_text[#gen3_move_text + 1] = call.value end
end
local gen3_move_rendered = table.concat(gen3_move_text, "\n")
check(gen3_move_rendered:find("PP 10/10", 1, true) ~= nil,
    "Gen 3 move PP was not rendered from the normalized snapshot")
gen3_move_env:run_hook(
    "input.key", nil, gen3_move_env.game, { phase = "pressed", key = "z" }
)
check(#gen3_move_env:submitted() == 1
    and gen3_move_env:submitted()[1].kind == "move"
    and gen3_move_env:submitted()[1].slot == 3,
    "Gen 3 move was submitted using its visual index instead of its native slot")

-- A missing PP from the facade is represented as zero and must be blocked.
local normalized_pp_env = make_environment("emerald")
normalized_pp_env:set_battle_snapshot({
    prompt = "moves", kind = "wild", revision = 1,
    player = {}, enemy = {}, party = {}, items = {},
    moves = {
        { id = "UNKNOWN_PP", name = "UNKNOWN PP", type = "NORMAL",
            slot = 2, pp = 0, maxPp = 0 },
    },
})
for index = #battle_draw_calls, 1, -1 do battle_draw_calls[index] = nil end
normalized_pp_env:run_hook("render.hud", nil, normalized_pp_env.game, base_viewport)
local normalized_pp_text = {}
for _, call in ipairs(battle_draw_calls) do
    if call.kind == "text" then normalized_pp_text[#normalized_pp_text + 1] = call.value end
end
check(table.concat(normalized_pp_text, "\n"):find("PP 0/0", 1, true) ~= nil,
    "normalized missing PP was not presented as zero")
normalized_pp_env:run_hook(
    "input.key", nil, normalized_pp_env.game, { phase = "pressed", key = "z" }
)
check(#normalized_pp_env:submitted() == 0,
    "a move with normalized zero PP was incorrectly enabled")

-- Known zero PP remains disabled and cannot be submitted.
local exhausted_env = make_environment("emerald")
exhausted_env:set_battle_snapshot({
    prompt = "moves", kind = "wild", revision = 1,
    player = {}, enemy = {}, party = {}, items = {},
    moves = {
        { id = "STRUGGLE_TEST", name = "STRUGGLE TEST", type = "NORMAL",
            slot = 2, pp = 0, maxPp = 10 },
    },
})
exhausted_env:run_hook(
    "input.key", nil, exhausted_env.game, { phase = "pressed", key = "z" }
)
check(#exhausted_env:submitted() == 0,
    "a move with known zero PP was incorrectly enabled")


-- Gen 3 can expose sparse native battler IDs in double battles.
-- A native battler ID is not necessarily the visual list index.
local target_snapshot = {
    prompt = "target", kind = "wild", revision = 1, target = 3,
    targets = { 0, 3 },
    battlers = {
        { id = 0, name = "PIKACHU", hp = 35, maxHp = 35 },
        { id = 3, name = "RATTATA", hp = 20, maxHp = 20 },
    },
    player = {}, enemy = {}, party = {}, moves = {}, items = {},
}
local target_env = make_environment("emerald")
target_env:set_battle_snapshot(target_snapshot)
target_env:run_hook(
    "input.key", nil, target_env.game, { phase = "pressed", key = "z" }
)
check(#target_env:submitted() == 1
    and target_env:submitted()[1].kind == "target"
    and target_env:submitted()[1].target == 3
    and target_env:submitted()[1].revision == 1,
    "Gen 3 sparse target IDs were confused with visual list indices")

-- Double battles identify the command actor independently of the battler
-- rows, and classify the four native target slots by side and active slot.
local double_target_env = make_environment("emerald")
double_target_env:set_battle_snapshot({
    prompt = "target", kind = "trainer", revision = 31, double = true,
    active = 2, target = 0, targets = { 0, 1, 2, 3 },
    player = { name = "RAICHU" },
    battlers = {
        { id = 0, side = "player", name = "PIKACHU", hp = 40, maxHp = 40, active = true },
        { id = 1, side = "enemy", name = "GASTLY", hp = 25, maxHp = 25, active = true },
        { id = 2, side = "player", name = "RAICHU", hp = 60, maxHp = 60, active = true },
        { id = 3, side = "enemy", name = "ONIX", hp = 55, maxHp = 55, active = true },
    },
    enemy = {}, party = {}, moves = {}, items = {},
})
for index = #battle_draw_calls, 1, -1 do battle_draw_calls[index] = nil end
double_target_env:run_hook("render.hud", nil, double_target_env.game, base_viewport)
local double_target_text = {}
for _, call in ipairs(battle_draw_calls) do
    if call.kind == "text" then double_target_text[#double_target_text + 1] = call.value end
end
local double_target_rendered = table.concat(double_target_text, "\n")
check(double_target_rendered:find("ATIVO: RAICHU", 1, true) ~= nil
    and double_target_rendered:find("ATIVO", 1, true) ~= nil
    and double_target_rendered:find("ALIADO", 1, true) ~= nil
    and double_target_rendered:find("INIMIGO", 1, true) ~= nil,
    "double-battle UI did not identify the active Pokémon, partner and opponents")
double_target_env:run_hook(
    "input.key", nil, double_target_env.game, { phase = "pressed", key = "down" }
)
double_target_env:run_hook(
    "input.key", nil, double_target_env.game, { phase = "pressed", key = "z" }
)
check(#double_target_env:submitted() == 1
    and double_target_env:submitted()[1].kind == "target"
    and double_target_env:submitted()[1].target == 2,
    "double-battle partner target was not submitted using its native battler ID")

-- The active actor banner follows the engine when command control moves to
-- the other player slot; it is not cached from the previous turn.
double_target_env:set_battle_snapshot({
    prompt = "moves", kind = "trainer", revision = 32, double = true, active = 0,
    player = { name = "PIKACHU" }, enemy = {}, party = {}, items = {},
    moves = {
        { id = "THUNDERBOLT", name = "THUNDERBOLT", slot = 1,
            type = "ELECTRIC", pp = 15, maxPp = 15 },
    },
})
for index = #battle_draw_calls, 1, -1 do battle_draw_calls[index] = nil end
double_target_env:run_hook("render.hud", nil, double_target_env.game, base_viewport)
local next_actor_text = {}
for _, call in ipairs(battle_draw_calls) do
    if call.kind == "text" then next_actor_text[#next_actor_text + 1] = call.value end
end
check(table.concat(next_actor_text, "\n"):find("ATIVO: PIKACHU", 1, true) ~= nil,
    "double-battle actor banner did not update when the active slot changed")

-- Switching the active party member remains an engine-owned party phase.
double_target_env:set_battle_snapshot({
    prompt = "party", kind = "trainer", revision = 33, double = true,
    active = 0, player = { name = "PIKACHU" },
})
check(double_target_env:run_hook(
    "battle.bottom_ui_visible", true, {}
) == true and double_target_env:run_hook(
    "input.key", "native-double-party", double_target_env.game,
    { phase = "pressed", key = "z" }
) == "native-double-party",
    "double-battle party selection was captured instead of remaining native")

-- B returns from the move selector using the generation-neutral intent.
command_env:set_battle_snapshot(move_snapshot)
command_env:run_hook(
    "input.key", nil, command_env.game, { phase = "pressed", key = "x" }
)
check(#command_env:submitted() == 3
    and command_env:submitted()[3].kind == "back",
    "B did not return from the native move selector")

-- The pointer consumes only presses inside the drawn command tray; it never
-- steals clicks from the rest of the game or from the touch controls.
local pointer_env = make_environment("red")
pointer_env:set_battle_snapshot(menu_snapshot)
pointer_env:run_hook("render.hud", nil, pointer_env.game, base_viewport)
local inside_consumed = pointer_env:run_hook(
    "input.pointer", false, pointer_env.game,
    { phase = "pressed", source = "touch", id = 1, gameX = 20, gameY = 108 }
)
check(inside_consumed == true
    and #pointer_env:submitted() == 1
    and pointer_env:submitted()[1].choice == "fight",
    "touch press on Fight did not activate and consume the command card")
local outside_consumed = pointer_env:run_hook(
    "input.pointer", false, pointer_env.game,
    { phase = "pressed", source = "touch", id = 2, gameX = 10, gameY = 20 }
)
check(outside_consumed == false,
    "battle menu consumed a pointer press outside its own panel")

-- Pointer input is in window units; it must be transformed back to the
-- logical game layout when the game viewport is enlarged and offset.
local scaled_env = make_environment("red")
scaled_env:set_battle_snapshot(move_snapshot)
local scaled_viewport = {
    width = 640, height = 576,
    gameX = 40, gameY = 20,
    gameWidth = 320, gameHeight = 288, scale = 2,
}
scaled_env:run_hook("render.hud", nil, scaled_env.game, scaled_viewport)
local scaled_back_consumed = scaled_env:run_hook(
    "input.pointer", false, scaled_env.game,
    { phase = "pressed", source = "mouse", id = 4, gameX = 260, gameY = 188 }
)
check(scaled_back_consumed == true
    and #scaled_env:submitted() == 1
    and scaled_env:submitted()[1].kind == "back",
    "scaled/offset pointer coordinates did not hit the logical B: BACK target")

-- Android/iOS virtual controls inject buttons through Input directly.
-- The input.step bridge must route those touch edges to our menu and mask
-- the same GB buttons from the still-running native battle controller.
local overlay_env = make_environment("red")
local original_overlay_was_pressed = overlay_env.game.input.wasPressed
local original_overlay_is_down = overlay_env.game.input.isDown
local original_overlay_pressed = overlay_env.game.input.overlayPressed
overlay_env:set_battle_snapshot(menu_snapshot)
overlay_env:set_touch_down("a", true)
overlay_env:press("a")
overlay_env:run_hook("input.step", nil, overlay_env.game, 1 / 60)
check(#overlay_env:submitted() == 1
    and overlay_env:submitted()[1].kind == "menu"
    and overlay_env:submitted()[1].choice == "fight",
    "virtual touch A did not submit the Fight command")
check(overlay_env.game.input:wasPressed("a") == false
    and overlay_env.game.input:isDown("a") == false,
    "virtual touch A leaked into the hidden native battle menu")

-- A held A must not auto-confirm the first move after the command page changes.
overlay_env:set_battle_snapshot(move_snapshot)
overlay_env:run_hook("input.step", nil, overlay_env.game, 1 / 60)
check(#overlay_env:submitted() == 1,
    "a held virtual A was repeated across a battle prompt transition")
overlay_env:set_touch_down("a", false)
overlay_env:run_hook("input.step", nil, overlay_env.game, 1 / 60)
overlay_env:set_touch_down("a", true)
overlay_env:run_hook("input.step", nil, overlay_env.game, 1 / 60)
check(#overlay_env:submitted() == 2
    and overlay_env:submitted()[2].kind == "move"
    and overlay_env:submitted()[2].slot == 1,
    "a fresh virtual touch A did not select the first move")
overlay_env:set_battle_snapshot({ prompt = "locked", kind = "wild", revision = 3 })
overlay_env:run_hook("input.step", nil, overlay_env.game, 1 / 60)
check(overlay_env.game.input.wasPressed == original_overlay_was_pressed
    and overlay_env.game.input.isDown == original_overlay_is_down
    and overlay_env.game.input.overlayPressed == original_overlay_pressed,
    "native input methods were not restored after leaving the custom menu")

-- A full virtual tap may be pressed and released between fixed steps.
-- Capture overlayPressed's edge, then keep masking native input for the
-- one upcoming Input:step even though isTouchDown is already false.
local quick_tap_env = make_environment("red")
quick_tap_env:set_battle_snapshot(menu_snapshot)
quick_tap_env:run_hook("input.step", nil, quick_tap_env.game, 1 / 60)
quick_tap_env.game.input:overlayPressed("a")
quick_tap_env.game.input:overlayReleased("a")
quick_tap_env:run_hook("input.step", nil, quick_tap_env.game, 1 / 60)
check(#quick_tap_env:submitted() == 1
    and quick_tap_env:submitted()[1].kind == "menu"
    and quick_tap_env:submitted()[1].choice == "fight",
    "a short virtual tap released before the logic step was lost")
check(quick_tap_env.game.input:wasPressed("a") == false,
    "a short virtual tap leaked into the native battle controller")

-- Simultaneous d-pad and A touch must move the cursor before confirming.
local combo_env = make_environment("red")
combo_env:set_battle_snapshot(menu_snapshot)
combo_env:set_touch_down("right", true)
combo_env:set_touch_down("a", true)
combo_env:press("right")
combo_env:press("a")
combo_env:run_hook("input.step", nil, combo_env.game, 1 / 60)
check(#combo_env:submitted() == 1
    and combo_env:submitted()[1].kind == "menu"
    and combo_env:submitted()[1].choice == "party",
    "simultaneous virtual d-pad + A did not confirm the newly selected action")

-- Other input sources remain readable while the custom menu is active;
-- only a GB button currently held by TouchControls is masked.
local non_touch_env = make_environment("red")
non_touch_env:set_battle_snapshot(menu_snapshot)
non_touch_env:press("a")
non_touch_env:run_hook("input.step", nil, non_touch_env.game, 1 / 60)
check(non_touch_env.game.input:isDown("a") == true
    and non_touch_env.game.input:wasPressed("a") == true,
    "battle touch bridge masked a non-touch input source")

-- The B: BACK header hint is an actual touch target, not decorative text.
local back_env = make_environment("red")
back_env:set_battle_snapshot(move_snapshot)
back_env:run_hook("render.hud", nil, back_env.game, base_viewport)
local back_consumed = back_env:run_hook(
    "input.pointer", false, back_env.game,
    { phase = "pressed", source = "touch", id = 3, gameX = 110, gameY = 84 }
)
check(back_consumed == true
    and #back_env:submitted() == 1
    and back_env:submitted()[1].kind == "back",
    "touching the B: BACK header did not return from the move selector")

-- Gen 1's public battle facade exposes Mimic as its own validated
-- selection phase. The initial native mimic cursor is preserved.
local mimic_env = make_environment("red")
mimic_env:set_battle_snapshot({
    prompt = "mimic", kind = "wild", revision = 21, mimicIndex = 2,
    player = {}, enemy = {}, party = {}, moves = {}, items = {},
    mimicMoves = {
        { index = 1, slot = 1, id = "TACKLE", name = "TACKLE" },
        { index = 2, slot = 3, id = "THUNDERBOLT", name = "THUNDERBOLT" },
    },
})
for index = #battle_draw_calls, 1, -1 do battle_draw_calls[index] = nil end
mimic_env:run_hook("render.hud", nil, mimic_env.game, base_viewport)
local mimic_text = {}
for _, call in ipairs(battle_draw_calls) do
    if call.kind == "text" then mimic_text[#mimic_text + 1] = call.value end
end
local mimic_rendered = table.concat(mimic_text, "\n")
check(mimic_rendered:find("MÍMICA", 1, true) ~= nil
    and mimic_rendered:find("THUNDERBOLT", 1, true) ~= nil,
    "Mimic selector did not render its localized heading and move choices")
check(mimic_env:run_hook("battle.bottom_ui_visible", true, {}) == false,
    "native battle panel was not replaced during Mimic selection")
mimic_env:run_hook(
    "input.key", nil, mimic_env.game, { phase = "pressed", key = "z" }
)
check(#mimic_env:submitted() == 1
    and mimic_env:submitted()[1].kind == "mimic"
    and mimic_env:submitted()[1].index == 2
    and mimic_env:submitted()[1].revision == 21,
    "Mimic selection did not submit its native move-list index")

-- Safari is a separate Gen 1 action menu, not the regular Fight/Bag menu.
local safari_env = make_environment("red")
safari_env:set_battle_snapshot({
    prompt = "safari", kind = "safari", revision = 22, safariBalls = 30,
    player = {}, enemy = {}, party = {}, moves = {}, items = {},
})
for index = #battle_draw_calls, 1, -1 do battle_draw_calls[index] = nil end
safari_env:run_hook("render.hud", nil, safari_env.game, base_viewport)
local safari_text = {}
for _, call in ipairs(battle_draw_calls) do
    if call.kind == "text" then safari_text[#safari_text + 1] = call.value end
end
local safari_rendered = table.concat(safari_text, "\n")
check(safari_rendered:find("SAFÁRI", 1, true) ~= nil
    and safari_rendered:find("BOLA", 1, true) ~= nil
    and safari_rendered:find("ISCA", 1, true) ~= nil
    and safari_rendered:find("BOLAS: 30", 1, true) ~= nil,
    "Safari menu did not render its action labels or remaining ball count")
check(safari_env:run_hook("battle.bottom_ui_visible", true, {}) == false,
    "native battle panel was not replaced during Safari action selection")
safari_env:run_hook(
    "input.key", nil, safari_env.game, { phase = "pressed", key = "right" }
)
safari_env:run_hook(
    "input.key", nil, safari_env.game, { phase = "pressed", key = "z" }
)
check(#safari_env:submitted() == 1
    and safari_env:submitted()[1].kind == "safari"
    and safari_env:submitted()[1].action == "bait"
    and safari_env:submitted()[1].revision == 22,
    "Safari action selection did not preserve the native bait intent")

local no_balls_env = make_environment("red")
no_balls_env:set_battle_snapshot({
    prompt = "safari", kind = "safari", revision = 23, safariBalls = 0,
    player = {}, enemy = {}, party = {}, moves = {}, items = {},
})
no_balls_env:run_hook(
    "input.key", nil, no_balls_env.game, { phase = "pressed", key = "z" }
)
check(#no_balls_env:submitted() == 0,
    "Safari actions remained selectable after the last ball was consumed")

-- Forced party screens and message/advance phases stay entirely native.
-- Leaving the custom menu must also restore the original touch input methods.
local phase_env = make_environment("red")
local phase_original_was_pressed = phase_env.game.input.wasPressed
phase_env:set_battle_snapshot(menu_snapshot)
phase_env:run_hook("input.step", nil, phase_env.game, 1 / 60)
check(phase_env.game.input.wasPressed ~= phase_original_was_pressed,
    "touch bridge was not installed for the custom command menu")
for _, prompt in ipairs({ "party", "advance", "locked" }) do
    phase_env:set_battle_snapshot({
        prompt = prompt, kind = "wild", revision = 24,
        player = {}, enemy = {}, party = {}, moves = {}, items = {},
    })
    phase_env:run_hook("input.step", nil, phase_env.game, 1 / 60)
    check(phase_env.game.input.wasPressed == phase_original_was_pressed,
        prompt .. ": native touch input was not restored after leaving the custom menu")
    check(phase_env:run_hook("battle.bottom_ui_visible", true, {}) == true,
        prompt .. ": native battle panel was hidden outside a custom prompt")
    check(phase_env:run_hook(
        "input.key", "native-key", phase_env.game,
        { phase = "pressed", key = "z" }
    ) == "native-key", prompt .. ": keyboard input was not forwarded to the native state")
    check(phase_env:run_hook(
        "input.gamepad", "native-pad", phase_env.game,
        { phase = "pressed", button = "a" }
    ) == "native-pad", prompt .. ": gamepad input was not forwarded to the native state")
end
local link_env = make_environment("red")
link_env:set_battle_snapshot({
    prompt = "menu", kind = "link", revision = 25,
    player = {}, enemy = {}, party = {}, moves = {}, items = {},
})
check(link_env:run_hook("battle.bottom_ui_visible", true, {}) == true
    and link_env:run_hook(
        "input.key", "link-native", link_env.game,
        { phase = "pressed", key = "z" }
    ) == "link-native",
    "link battle was captured by the replacement single-player menu")

-- The bottom battle layer is hidden only while the replacement UI is active.
local hidden = command_env:run_hook(
    "battle.bottom_ui_visible", true, {}
)
check(hidden == false,
    "native battle command panel was not hidden while the replacement is active")
command_env:set_battle_snapshot({
    prompt = "locked", kind = "wild", revision = 5,
})
local visible = command_env:run_hook(
    "battle.bottom_ui_visible", true, {}
)
check(visible == true,
    "native battle UI was hidden during a non-interactive battle phase")

print(("Runtime harness OK: %d catalog achievements exercised through main.lua; profiles, START menu, Gen 1/2/3 battle contracts, Mimic/Safari intents, native party/message transitions, PP normalization, original move slots, sparse Gen 3 targets, touch UI, all 11 games and 3 locales verified."):format(#rows))

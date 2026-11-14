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
    local pressed = {}
    local drawn = {}
    local pushes = {}
    local write_count = 0
    local fail_writes = false
    local pop_count = 0
    local selected_language = language or "pt-BR"
    local game = {
        save = { version = game_id },
        input = {
            wasPressed = function(_, button)
                local value = pressed[button] == true
                pressed[button] = nil
                return value
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
        define = function() end,
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
        drawn = drawn,
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

print(("Runtime harness OK: %d catalog achievements exercised through main.lua; profiles, START menu, UI navigation, all 11 games, 3 locales, filter help and secret achievement visibility verified."):format(#rows))

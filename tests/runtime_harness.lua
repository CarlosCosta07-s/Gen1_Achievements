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
    local first_data_row = true
    for line in (contents .. "\n"):gmatch("(.-)\n") do
        line = line:gsub("\r$", "")
        if line ~= "" and line:sub(1, 1) ~= "#" then
            if first_data_row then
                first_data_row = false
            else
                local fields = split_tabs(line)
                check(#fields == 15, "catalog row must contain 15 fields")
                rows[#rows + 1] = fields
            end
        end
    end
    return rows
end

local function make_environment(game_id, initial_cache)
    local listeners = {}
    local emitted = {}
    local cache = initial_cache or {}
    local screens = {}
    local write_count = 0
    local fail_writes = false
    local game = {
        save = { version = game_id },
        input = { wasPressed = function() return false end },
        stack = { pop = function() end },
    }

    local mod = {}
    mod.options = {
        define = function() end,
        get = function() return "pt-BR" end,
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
    mod.log = {}
    for _, level in ipairs({ "info", "warn", "error" }) do
        mod.log[level] = function() end
    end
    function mod:supports(surface, _name)
        return surface == "events"
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
    function env:write_count()
        return write_count
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

print(("Runtime harness OK: %d catalog achievements exercised through main.lua; session gate, matching, deduplication, per-title isolation, legacy migration and write failures verified."):format(#rows))

-- Gen1 Achievements
-- Portable Mod API 3: one in-game achievement console for Gen 1, 2 and 3.
-- Progress is local to this installation and partitioned by game version.

local MOD_ID = "gen1_achievements"
local SCREEN_ID = "Gen1AchievementConsole"
local LANGUAGE_OPTION = "achievement_language"
local DEFAULT_LANGUAGE = "pt-BR"
local CATALOG_PATH = "data/achievements.tsv"
local PROFILE_FORMAT = "GEN1ACHIEVEMENTS2"

local GAME_IDS = {
    red = true,
    blue = true,
    yellow = true,
    gold = true,
    silver = true,
    crystal = true,
    firered = true,
    leafgreen = true,
    ruby = true,
    sapphire = true,
    emerald = true,
}

local GAME_TITLES = {
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

local SUPPORTED_LANGUAGES = {
    en = true,
    ["pt-BR"] = true,
    es = true,
}

local LANGUAGE_CHOICES = {
    { "English", "en" },
    { "Português (Brasil)", "pt-BR" },
    { "Español", "es" },
}

local TEXT = {
    en = {},
    ["pt-BR"] = {},
    es = {},
}

local ALLOWED_OPERATORS = {
    any = true,
    equals = true,
    at_least = true,
    truthy = true,
    one_of = true,
    one_of_true = true,
    ends_with = true,
}

local ALLOWED_MODES = {
    instant = true,
    counter = true,
}

local function normalize_language(value)
    if type(value) == "string" and SUPPORTED_LANGUAGES[value] then
        return value
    end
    return DEFAULT_LANGUAGE
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

local function valid_id(value)
    return type(value) == "string"
        and value ~= ""
        and value:match("^[%w_-]+$") ~= nil
end

local function glyph_count(text, font)
    if font and type(font.split) == "function" then
        local ok, spans = pcall(font.split, text)
        if ok and type(spans) == "table" then return #spans end
    end
    return #text
end

local function clip_text(text, maximum, font)
    if glyph_count(text, font) <= maximum then return text end
    if not (font and type(font.split) == "function") then
        return text:sub(1, math.max(1, maximum - 3)) .. "..."
    end

    local ok, spans = pcall(font.split, text)
    if not ok or type(spans) ~= "table" or #spans <= maximum then
        return text
    end

    local last = spans[math.max(1, maximum - 1)].to
    if not last then return text:sub(1, maximum - 3) .. "..." end
    return text:sub(1, last) .. "..."
end

local function wrap_text(text, maximum, font)
    local lines = {}
    local current = ""

    for word in text:gmatch("%S+") do
        local candidate = current == "" and word or (current .. " " .. word)
        if current ~= "" and glyph_count(candidate, font) > maximum then
            lines[#lines + 1] = current
            current = word
        else
            current = candidate
        end
    end

    if current ~= "" then lines[#lines + 1] = current end
    return lines
end

local function make_empty_profile()
    return { unlocked = {}, progress = {}, order = {} }
end

local function equal_values(left, right)
    if type(left) == "number" and type(right) == "number" then
        return left == right
    end
    if type(left) == "boolean" and type(right) == "boolean" then
        return left == right
    end
    return tostring(left) == tostring(right)
end

return function(mod)
    mod.options:define({
        {
            key = LANGUAGE_OPTION,
            type = "choice",
            label = "Achievement language / Idioma das conquistas",
            choices = LANGUAGE_CHOICES,
            default = DEFAULT_LANGUAGE,
        },
    })

    local function selected_language()
        return normalize_language(mod.options:get(LANGUAGE_OPTION))
    end

    local function text(key)
        local language = selected_language()
        local dictionary = TEXT[language] or TEXT[DEFAULT_LANGUAGE]
        return dictionary[key] or TEXT[DEFAULT_LANGUAGE][key] or key
    end

    local function load_text()
        local contents, read_error = mod:read("data/ui_locales.tsv")
        if type(contents) ~= "string" then
            mod.log:error("Could not read UI locales: %s", tostring(read_error))
            return
        end

        for line in (contents .. "\n"):gmatch("(.-)\n") do
            line = line:gsub("\r$", "")
            if line ~= "" and line:sub(1, 1) ~= "#" then
                local fields = split_tabs(line)
                if #fields == 3 and SUPPORTED_LANGUAGES[fields[1]]
                    and fields[2] ~= "" and fields[3] ~= "" then
                    TEXT[fields[1]][fields[2]] = fields[3]
                end
            end
        end
    end

    load_text()

    local function game_id_from(game)
        local save = game and game.save
        local version = save and save.version
        if type(version) == "string" then
            version = version:lower()
            if GAME_IDS[version] then return version end
        end
        return nil
    end

    local active_game

    local function live_game(event)
        if type(event) == "table" and type(event.game) == "table" then
            return event.game
        end
        if type(active_game) == "table" then return active_game end
        return mod.game
    end
    local catalog = {}
    local catalog_by_id = {}
    local profiles = {}
    local toast = nil
    local toast_remaining = 0

    for game_id in pairs(GAME_IDS) do
        catalog[game_id] = {}
    end

    local function load_catalog()
        local contents, read_error = mod:read(CATALOG_PATH)
        if type(contents) ~= "string" then
            mod.log:error("Could not read %s: %s", CATALOG_PATH,
                tostring(read_error))
            return
        end

        local line_number = 0
        for line in (contents .. "\n"):gmatch("(.-)\n") do
            line_number = line_number + 1
            line = line:gsub("\r$", "")

            if line ~= "" and line:sub(1, 1) ~= "#" and line_number > 1 then
                local fields = split_tabs(line)
                if #fields ~= 15 then
                    mod.log:warn("Ignoring malformed achievement catalog row %d", line_number)
                else
                    local game_id = fields[1]
                    local id = fields[2]
                    local event_name = fields[3]
                    local match_field = fields[4]
                    local operator = fields[5]
                    local match_value = parse_scalar(fields[6])
                    local mode = fields[7]
                    local target = tonumber(fields[8])
                    local secret = fields[9] == "true" or fields[9] == "1"

                    local title = {
                        en = fields[10],
                        ["pt-BR"] = fields[12],
                        es = fields[14],
                    }
                    local description = {
                        en = fields[11],
                        ["pt-BR"] = fields[13],
                        es = fields[15],
                    }

                    local valid = GAME_IDS[game_id] and valid_id(id)
                        and ALLOWED_OPERATORS[operator] and ALLOWED_MODES[mode]
                        and type(event_name) == "string" and event_name ~= ""
                        and (mode ~= "counter" or (target and target > 0))
                        and title.en ~= "" and title["pt-BR"] ~= "" and title.es ~= ""
                        and description.en ~= "" and description["pt-BR"] ~= ""
                        and description.es ~= ""
                        and catalog_by_id[id] == nil

                    if valid then
                        local supported = mod:supports("events", event_name)
                        if supported then
                            local achievement = {
                                game = game_id,
                                id = id,
                                event = event_name,
                                field = match_field,
                                operator = operator,
                                value = match_value,
                                mode = mode,
                                target = target,
                                secret = secret,
                                title = title,
                                description = description,
                            }
                            catalog[game_id][#catalog[game_id] + 1] = achievement
                            catalog_by_id[id] = achievement
                        else
                            mod.log:warn(
                                "Achievement %s uses an unavailable event on %s: %s",
                                id, game_id, event_name
                            )
                        end
                    else
                        mod.log:warn(
                            "Ignoring invalid or duplicate achievement at catalog row %d",
                            line_number
                        )
                    end
                end
            end
        end

        local total = 0
        for _, entries in pairs(catalog) do total = total + #entries end
        mod.log:info("Loaded %d achievements for %d game versions", total, 11)
    end

    local function decode_profile(bytes, game_id)
        local profile = make_empty_profile()
        if type(bytes) ~= "string" then return profile, false end

        local first_line = true
        local invalid = false
        local seen_unlocked = {}
        local seen_progress = {}

        for line in (bytes .. "\n"):gmatch("(.-)\n") do
            line = line:gsub("\r$", "")
            if first_line then
                first_line = false
                if line ~= PROFILE_FORMAT and line ~= "GEN1ACHIEVEMENTS1" then
                    invalid = true
                    break
                end
            elseif line ~= "" and line:sub(1, 2) == "U|" then
                local id = line:sub(3)
                local achievement = catalog_by_id[id]
                if not valid_id(id) or not achievement
                    or achievement.game ~= game_id or seen_unlocked[id] then
                    invalid = true
                    break
                end
                seen_unlocked[id] = true
                profile.unlocked[id] = true
                profile.order[#profile.order + 1] = id
            elseif line ~= "" and line:sub(1, 2) == "P|" then
                local id, value = line:match("^P|([%w_-]+)|(%d+)$")
                local achievement = id and catalog_by_id[id] or nil
                local numeric = tonumber(value)
                if not id or not achievement or achievement.game ~= game_id
                    or achievement.mode ~= "counter" or seen_progress[id]
                    or seen_unlocked[id] or not numeric or numeric < 1
                    or numeric >= achievement.target then
                    invalid = true
                    break
                end
                seen_progress[id] = true
                profile.progress[id] = numeric
            elseif line ~= "" then
                invalid = true
                break
            end
        end

        if first_line or invalid then
            return make_empty_profile(), true
        end
        return profile, false
    end

    local function encode_profile(profile, game_id)
        local lines = { PROFILE_FORMAT }
        local seen = {}

        for _, id in ipairs(profile.order) do
            if profile.unlocked[id] and not seen[id] then
                lines[#lines + 1] = "U|" .. id
                seen[id] = true
            end
        end

        for _, achievement in ipairs(catalog[game_id] or {}) do
            local value = profile.progress[achievement.id]
            if value and value > 0 and not profile.unlocked[achievement.id] then
                lines[#lines + 1] = ("P|%s|%d"):format(
                    achievement.id, math.floor(value)
                )
            end
        end

        return table.concat(lines, "\n") .. "\n"
    end

    local function get_profile(game_id)
        if profiles[game_id] then return profiles[game_id] end

        local path = "profiles/" .. game_id .. ".dat"
        local bytes, read_error = mod.cache:read(path)
        local profile, invalid_profile = decode_profile(bytes, game_id)
        profiles[game_id] = profile

        if invalid_profile then
            mod.log:warn(
                "Discarded malformed or catalog-incompatible achievement profile for %s",
                game_id
            )
        elseif read_error and bytes == nil then
            mod.log:info("Starting a new local achievement profile for %s", game_id)
        end
        return profile
    end

    local function persist_profile(game_id, profile)
        local bytes = encode_profile(profile, game_id)
        local ok, write_error = mod.cache:write(
            "profiles/" .. game_id .. ".dat", bytes
        )
        if ok == nil or ok == false then
            mod.log:error("Could not persist achievements for %s: %s",
                game_id, tostring(write_error))
            return false
        end
        return true
    end

    local function is_unlocked(profile, id)
        return profile.unlocked[id] == true
    end

    local function unlock(game_id, achievement, profile)
        if is_unlocked(profile, achievement.id) then return false end

        profile.unlocked[achievement.id] = true
        profile.order[#profile.order + 1] = achievement.id
        if not persist_profile(game_id, profile) then
            profile.unlocked[achievement.id] = nil
            profile.order[#profile.order] = nil
            return false
        end

        toast = {
            game = game_id,
            id = achievement.id,
        }
        toast_remaining = 5.0

        mod.events:emit("mod.gen1_achievements.unlocked", {
            game = game_id,
            achievement = achievement.id,
        })
        mod.log:info("Achievement unlocked: %s (%s)", achievement.id, game_id)
        return true
    end

    local function read_event_field(event, path)
        if type(path) ~= "string" or path == "" or path == "*" then
            return nil
        end

        local value = event
        for segment in path:gmatch("[^%.]+") do
            if type(value) ~= "table" then return nil end
            value = value[segment]
        end
        return value
    end

    local function matches_pipe_value(actual, encoded)
        if actual == nil or encoded == nil then return false end
        for candidate in tostring(encoded):gmatch("[^|]+") do
            if equal_values(actual, parse_scalar(candidate)) then return true end
        end
        return false
    end

    local function event_matches(achievement, event)
        local actual = read_event_field(event, achievement.field)

        if achievement.operator == "any" then
            return true
        elseif achievement.operator == "equals" then
            return actual ~= nil and equal_values(actual, achievement.value)
        elseif achievement.operator == "at_least" then
            return tonumber(actual) ~= nil
                and tonumber(achievement.value) ~= nil
                and tonumber(actual) >= tonumber(achievement.value)
        elseif achievement.operator == "truthy" then
            return actual == true
        elseif achievement.operator == "one_of" then
            return matches_pipe_value(actual, achievement.value)
        elseif achievement.operator == "one_of_true" then
            return event.value == true
                and matches_pipe_value(actual, achievement.value)
        elseif achievement.operator == "ends_with" then
            return type(actual) == "string"
                and type(achievement.value) == "string"
                and #achievement.value > 0
                and actual:sub(-#achievement.value) == achievement.value
        end

        return false
    end

    -- Engine events are only counted during a ready gameplay session. A save
    -- load is deliberately a quiet boundary: stored flags are state, not
    -- evidence that the player performed those actions in this session.
    local session_ready = false

    local function handle_event(event_name, event)
        if not session_ready then return end
        event = type(event) == "table" and event or {}
        local game = live_game(event)
        if type(event.game) == "table" and type(active_game) == "table"
            and event.game ~= active_game then
            return
        end
        local game_id = game_id_from(game)
        if not game_id then return end

        local profile = get_profile(game_id)
        for _, achievement in ipairs(catalog[game_id]) do
            if achievement.event == event_name
                and event_matches(achievement, event)
                and not is_unlocked(profile, achievement.id) then

                if achievement.mode == "counter" then
                    local previous = profile.progress[achievement.id] or 0
                    local next_value = math.min(achievement.target, previous + 1)
                    profile.progress[achievement.id] = next_value

                    if next_value >= achievement.target then
                        if not unlock(game_id, achievement, profile) then
                            profile.progress[achievement.id] = previous
                        end
                    else
                        if not persist_profile(game_id, profile) then
                            profile.progress[achievement.id] = previous
                        end
                    end
                else
                    unlock(game_id, achievement, profile)
                end
            end
        end
    end

    local function register_event(event_name)
        local supported = mod:supports("events", event_name)
        if not supported then return end

        mod.events:on(event_name, function(event)
            handle_event(event_name, event)
        end)
    end

    local function achievement_label(achievement, profile)
        if achievement.secret and not is_unlocked(profile, achievement.id) then
            return text("hidden_title")
        end
        return achievement.title[selected_language()] or achievement.title[DEFAULT_LANGUAGE]
    end

    local function achievement_description(achievement, profile)
        if achievement.secret and not is_unlocked(profile, achievement.id) then
            return text("hidden_description")
        end
        return achievement.description[selected_language()]
            or achievement.description[DEFAULT_LANGUAGE]
    end

    local function filtered_entries(game_id, profile, filter_index)
        local result = {}
        for _, achievement in ipairs(catalog[game_id] or {}) do
            local unlocked = is_unlocked(profile, achievement.id)
            if filter_index == 1
                or (filter_index == 2 and unlocked)
                or (filter_index == 3 and not unlocked) then
                result[#result + 1] = achievement
            end
        end
        return result
    end

    local function draw_screen(game, self)
        local Font = mod.ui.Font
        local language = selected_language()
        local dictionary = TEXT[language] or TEXT[DEFAULT_LANGUAGE]
        local game_id = game_id_from(game) or "red"
        local game_title = GAME_TITLES[game_id] or game_id:upper()
        local profile = get_profile(game_id)
        local entries = filtered_entries(game_id, profile, self.filter_index)
        local unlocked_count = 0
        local total_count = #(catalog[game_id] or {})

        for _, achievement in ipairs(catalog[game_id] or {}) do
            if is_unlocked(profile, achievement.id) then
                unlocked_count = unlocked_count + 1
            end
        end

        Font.drawBox(0, 0, 20, 18)
        Font.draw(dictionary.title, 16, 8)
        Font.draw(clip_text(game_title, 18, Font), 16, 20)
        local percentage = total_count > 0
            and math.floor((unlocked_count / total_count) * 100) or 0
        Font.draw(
            ("%s %d/%d (%d%%)"):format(
                dictionary.progress, unlocked_count, total_count, percentage
            ),
            16, 32
        )

        if self.detail_index then
            local achievement = entries[self.detail_index]
            if not achievement then
                self.detail_index = nil
                return
            end

            local unlocked = is_unlocked(profile, achievement.id)
            local status = unlocked and dictionary.unlocked or dictionary.locked
            Font.draw(status, 16, 46)
            Font.draw(
                clip_text(achievement_label(achievement, profile), 18, Font),
                16, 60
            )

            local description = achievement_description(achievement, profile)
            local lines = wrap_text(description, 18, Font)
            local y = 76
            for index = 1, math.min(#lines, 4) do
                Font.draw(lines[index], 16, y)
                y = y + 12
            end

            if achievement.mode == "counter" and not unlocked then
                local current = profile.progress[achievement.id] or 0
                Font.draw(("%d/%d"):format(current, achievement.target), 16, 126)
            end
            Font.draw(dictionary.back, 16, 136)
            return
        end

        local filters = {
            dictionary.all,
            dictionary.unlocked_filter,
            dictionary.locked_filter,
        }
        local filter_label = "< " .. filters[self.filter_index] .. " >"
        Font.draw(clip_text(filter_label, 18, Font), 16, 44)

        if total_count == 0 then
            Font.draw(dictionary.empty_title, 16, 70)
            local lines = wrap_text(dictionary.empty_description, 18, Font)
            for index = 1, math.min(#lines, 3) do
                Font.draw(lines[index], 16, 84 + (index - 1) * 12)
            end
            Font.draw(clip_text(dictionary.filter, 18, Font), 16, 124)
            Font.draw(dictionary.back, 16, 136)
            return
        end

        if #entries == 0 then
            Font.draw(dictionary.empty_title, 16, 76)
        else
            local visible_rows = 5
            local max_scroll = math.max(0, #entries - visible_rows)
            self.scroll = math.max(0, math.min(self.scroll, max_scroll))
            if self.cursor > #entries then self.cursor = #entries end
            if self.cursor < 1 then self.cursor = 1 end

            if self.cursor <= self.scroll then
                self.scroll = self.cursor - 1
            elseif self.cursor > self.scroll + visible_rows then
                self.scroll = self.cursor - visible_rows
            end

            for row = 1, visible_rows do
                local entry_index = self.scroll + row
                local achievement = entries[entry_index]
                if achievement then
                    local unlocked = is_unlocked(profile, achievement.id)
                    local prefix = unlocked and "[X] " or "[ ] "
                    local label = achievement_label(achievement, profile)
                    local suffix = ""

                    if achievement.mode == "counter" and not unlocked then
                        local current = profile.progress[achievement.id] or 0
                        suffix = (" %d/%d"):format(current, achievement.target)
                    end

                    local line = clip_text(
                        prefix .. label .. suffix, 17, Font
                    )
                    if entry_index == self.cursor then
                        Font.draw(">", 4, 58 + (row - 1) * 12)
                    end
                    Font.draw(line, 16, 58 + (row - 1) * 12)
                end
            end
        end

        Font.draw(clip_text(dictionary.filter, 18, Font), 16, 124)
        Font.draw(dictionary.details, 16, 136)
    end

    local function change_filter(self, direction)
        self.filter_index = ((self.filter_index - 1 + direction) % 3) + 1
        self.cursor = 1
        self.scroll = 0
        self.detail_index = nil
    end

    -- The achievement console uses the same D-pad/A/B conventions as the
    -- native Pokémon menus. The screen is registered once and opened from
    -- the START menu on all supported generations.
    mod.content.screens:register(SCREEN_ID, {
        new = function(game)
            local self = {
                isOpaque = true,
                filter_index = 1,
                cursor = 1,
                scroll = 0,
                detail_index = nil,
            }

            function self:update(dt)
                local input = game.input
                local profile = get_profile(game_id_from(game) or "red")
                local entries = filtered_entries(
                    game_id_from(game) or "red", profile, self.filter_index
                )

                if input:wasPressed("b") or input:wasPressed("start") then
                    if self.detail_index then
                        self.detail_index = nil
                    else
                        game.stack:pop()
                    end
                    return
                end

                if self.detail_index then return end

                if input:wasPressed("left") then
                    change_filter(self, -1)
                elseif input:wasPressed("right") then
                    change_filter(self, 1)
                elseif input:wasPressed("up") and #entries > 0 then
                    self.cursor = math.max(1, self.cursor - 1)
                elseif input:wasPressed("down") and #entries > 0 then
                    self.cursor = math.min(#entries, self.cursor + 1)
                elseif input:wasPressed("a") and #entries > 0 then
                    self.detail_index = self.cursor
                end
            end

            function self:draw()
                draw_screen(game, self)
            end

            return self
        end,
    })

    -- Add the new entry immediately before OPTIONS in the real in-game
    -- START menu. The menu grows left as needed for the localized label.
    if mod:supports("hooks", "ui.start_menu.items") then
        mod.hooks:wrap("ui.start_menu.items", function(next, game, items)
            -- Compose with the downstream menu first so other mods' rows survive.
            local output = next(game, items)
            if type(output) ~= "table" then return output end

            return mod.ui.insertAfter(output, "SAVE", {
                label = text("menu"),
                onSelect = function()
                    mod.ui.push(game, SCREEN_ID)
                end,
            })
        end)
    end

    -- Reorder native Options rows inside the game's existing categories.
    -- The game still owns the menu drawing, category pages, fonts and colors.
    -- Unknown rows and rows from other mods keep their original positions.
    local OPTION_ROW_ORDER = {
        { "audioMode", "musicVol", "sfxVol", "pikaVol", "musicFilter" },
        { "uiLayout", "orientation", "videoMode", "faithfulRes",
            "screenPos", "vsync", "fpsCap", "logicClock" },
        { "colors", "shaderfx", "shaderfx2", "uiLetterbox" },
        { "battleStyle", "animations", "battleLayout", "battleFit",
            "battleHud", "battleBg" },
        { "textSpeed", "speedOverworld", "speedBattle", "speedMenu" },
        { "tilt", "zoom", "voidFill" },
    }

    local function organize_option_rows(rows)
        if type(rows) ~= "table" then return rows end

        local output = {}
        for index, row in ipairs(rows) do
            output[index] = row
        end

        for _, ordered_ids in ipairs(OPTION_ROW_ORDER) do
            local rank = {}
            for index, id in ipairs(ordered_ids) do
                rank[id] = index
            end

            local positions = {}
            local selected = {}
            for index, row in ipairs(output) do
                local row_rank = type(row) == "table" and rank[row.id] or nil
                if row_rank then
                    positions[#positions + 1] = index
                    selected[#selected + 1] = {
                        row = row,
                        rank = row_rank,
                        original_index = index,
                    }
                end
            end

            table.sort(selected, function(left, right)
                if left.rank == right.rank then
                    return left.original_index < right.original_index
                end
                return left.rank < right.rank
            end)

            for index, position in ipairs(positions) do
                output[position] = selected[index].row
            end
        end

        return output
    end

    if mod:supports("hooks", "ui.options.rows") then
        mod.hooks:wrap("ui.options.rows", function(next, game, rows)
            -- Preserve the normal hook chain before ordering the returned rows.
            local output = next(game, rows)
            if type(output) ~= "table" then return output end
            return organize_option_rows(output)
        end)
    end

    -- Party submenus use native descriptors from each generation. Reorder only
    -- recognized common actions; field moves and mod-added entries keep their
    -- exact positions and retain their original callbacks and metadata.
    local PARTY_ROW_ORDER = {
        stats = 1, summary = 1,
        switch = 2,
        move = 3,
        item = 4, mail = 4,
        cancel = 5,
    }
    local BATTLE_PARTY_ROW_ORDER = {
        switch = 1,
        stats = 2, summary = 2,
        cancel = 3,
    }

    local function party_row_id(row)
        if type(row) ~= "table" then return nil end
        local value = row.id or row.action
        if type(value) == "string" then return value:lower() end
        return nil
    end

    local function organize_party_rows(rows, context)
        if type(rows) ~= "table" then return rows end
        context = type(context) == "table" and context or {}
        local order = context.battle and BATTLE_PARTY_ROW_ORDER or PARTY_ROW_ORDER
        local output = {}
        for index, row in ipairs(rows) do output[index] = row end

        local positions, selected = {}, {}
        for index, row in ipairs(output) do
            local id = party_row_id(row)
            local rank = id and order[id] or nil
            local is_field_move = type(row) == "table"
                and (row.fieldMove == true or row.move ~= nil or id == "escape")
            if rank and not is_field_move then
                positions[#positions + 1] = index
                selected[#selected + 1] = {
                    row = row,
                    rank = rank,
                    original_index = index,
                }
            end
        end

        table.sort(selected, function(left, right)
            if left.rank == right.rank then
                return left.original_index < right.original_index
            end
            return left.rank < right.rank
        end)
        for index, position in ipairs(positions) do
            output[position] = selected[index].row
        end
        return output
    end

    if mod:supports("hooks", "ui.party.submenu") then
        mod.hooks:wrap("ui.party.submenu", function(next, game, rows, mon, context)
            local output = next(game, rows, mon, context)
            if type(output) ~= "table" then return output end
            return organize_party_rows(output, context)
        end)
    end

    -- Battle command presentation. Black/White is the layout reference:
    -- dark command tray, bright white action cards, clear primary action,
    -- move-type chips and PP at a glance. No sprites, fonts or other assets
    -- are imported; each game contributes only its own color identity and
    -- generation-specific corner/spacing treatment.
    local BATTLE_THEMES = {
        red       = { accent = { 0.82, 0.22, 0.28 }, shade = { 0.28, 0.08, 0.11 }, radius = 0 },
        blue      = { accent = { 0.25, 0.45, 0.78 }, shade = { 0.07, 0.15, 0.30 }, radius = 0 },
        yellow    = { accent = { 0.86, 0.66, 0.17 }, shade = { 0.30, 0.22, 0.05 }, radius = 0 },
        gold      = { accent = { 0.72, 0.54, 0.20 }, shade = { 0.25, 0.18, 0.06 }, radius = 2 },
        silver    = { accent = { 0.58, 0.65, 0.75 }, shade = { 0.18, 0.21, 0.27 }, radius = 2 },
        crystal   = { accent = { 0.22, 0.65, 0.74 }, shade = { 0.05, 0.21, 0.25 }, radius = 2 },
        firered   = { accent = { 0.83, 0.24, 0.18 }, shade = { 0.30, 0.08, 0.06 }, radius = 4 },
        leafgreen = { accent = { 0.23, 0.58, 0.35 }, shade = { 0.06, 0.22, 0.12 }, radius = 4 },
        ruby      = { accent = { 0.74, 0.20, 0.30 }, shade = { 0.28, 0.06, 0.11 }, radius = 3 },
        sapphire  = { accent = { 0.24, 0.45, 0.77 }, shade = { 0.06, 0.14, 0.29 }, radius = 3 },
        emerald   = { accent = { 0.20, 0.56, 0.40 }, shade = { 0.05, 0.21, 0.14 }, radius = 3 },
    }

    local BATTLE_TYPE_COLORS = {
        NORMAL = { 0.58, 0.59, 0.56 }, FIRE = { 0.88, 0.31, 0.19 },
        WATER = { 0.22, 0.48, 0.85 }, ELECTRIC = { 0.88, 0.70, 0.20 },
        GRASS = { 0.30, 0.66, 0.35 }, ICE = { 0.35, 0.72, 0.82 },
        FIGHTING = { 0.67, 0.24, 0.22 }, POISON = { 0.62, 0.34, 0.69 },
        GROUND = { 0.72, 0.56, 0.30 }, FLYING = { 0.55, 0.59, 0.82 },
        PSYCHIC = { 0.83, 0.36, 0.55 }, BUG = { 0.56, 0.64, 0.22 },
        ROCK = { 0.68, 0.57, 0.32 }, GHOST = { 0.39, 0.34, 0.64 },
        DRAGON = { 0.40, 0.36, 0.77 }, DARK = { 0.38, 0.34, 0.32 },
        STEEL = { 0.57, 0.62, 0.70 }, FAIRY = { 0.82, 0.49, 0.68 },
        MYSTERY = { 0.48, 0.53, 0.59 },
    }

    local BATTLE_ACTIONS = {
        fight = { key = "fight", label = "battle_fight" },
        item = { key = "item", label = "battle_bag" },
        party = { key = "party", label = "battle_pokemon" },
        run = { key = "run", label = "battle_run" },
    }
    local BATTLE_ACTION_ORDER = {
        red = { "fight", "party", "item", "run" },
        blue = { "fight", "party", "item", "run" },
        yellow = { "fight", "party", "item", "run" },
        gold = { "fight", "party", "item", "run" },
        silver = { "fight", "party", "item", "run" },
        crystal = { "fight", "party", "item", "run" },
        firered = { "fight", "item", "party", "run" },
        leafgreen = { "fight", "item", "party", "run" },
        ruby = { "fight", "item", "party", "run" },
        sapphire = { "fight", "item", "party", "run" },
        emerald = { "fight", "item", "party", "run" },
    }

    local function battle_actions_for(game)
        local gameId = game_id_from(game) or "red"
        local order = BATTLE_ACTION_ORDER[gameId] or BATTLE_ACTION_ORDER.red
        local actions = {}
        local itemLabel = (gameId == "red" or gameId == "blue" or gameId == "yellow")
            and "battle_item"
            or ((gameId == "gold" or gameId == "silver" or gameId == "crystal")
                and "battle_pack")
            or "battle_bag"
        for _, id in ipairs(order) do
            local action = BATTLE_ACTIONS[id]
            actions[#actions + 1] = {
                key = action.key,
                label = id == "item" and itemLabel or action.label,
            }
        end
        return actions
    end

    local battle_ui = {
        game = nil,
        prompt = nil,
        cursor = 1,
        snapshot = nil,
        layout = nil,
        pointer_captures = {},
        axis_action = nil,
        touch_down = {},
        touch_pending = {},
        touch_mask_pending = {},
        touch_input_bridge = nil,
    }
    local battle_intent_id = 0

    local function is_owned_battle_prompt(snapshot)
        if type(snapshot) ~= "table" then return false end
        if snapshot.kind == "link" or snapshot.kind == "oldman"
            or snapshot.kind == "safari" then
            return false
        end
        return snapshot.prompt == "menu"
            or snapshot.prompt == "moves"
            or snapshot.prompt == "target"
    end

    local function read_battle_snapshot()
        if type(mod.battle) ~= "table" or type(mod.battle.snapshot) ~= "function" then
            return nil
        end
        local ok, snapshot = pcall(mod.battle.snapshot, mod.battle)
        if not ok or type(snapshot) ~= "table" then return nil end
        return snapshot
    end

    local function sync_battle_ui(game, snapshot)
        if battle_ui.game ~= game then
            battle_ui.game = game
            battle_ui.prompt = nil
            battle_ui.cursor = 1
            battle_ui.layout = nil
            battle_ui.pointer_captures = {}
            battle_ui.axis_action = nil
            battle_ui.touch_down = {}
            battle_ui.touch_pending = {}
            battle_ui.touch_mask_pending = {}
        end
        if battle_ui.prompt ~= snapshot.prompt then
            battle_ui.prompt = snapshot.prompt
            battle_ui.cursor = 1
            if snapshot.prompt == "target" and type(snapshot.targets) == "table" then
                for index, target in ipairs(snapshot.targets) do
                    if target == snapshot.target then
                        battle_ui.cursor = index
                        break
                    end
                end
            end
        end
        battle_ui.snapshot = snapshot
    end

    local function battle_entry_count(snapshot, game)
        if snapshot.prompt == "menu" then return #battle_actions_for(game) end
        if snapshot.prompt == "moves" then
            return math.max(0, math.min(4, #(snapshot.moves or {})))
        end
        if snapshot.prompt == "target" then return #(snapshot.targets or {}) end
        return 0
    end

    local function battle_grid_cursor(cursor, count, direction)
        if count <= 1 then return 1 end
        local row = math.floor((cursor - 1) / 2)
        local column = (cursor - 1) % 2
        local row_count = math.ceil(count / 2)
        if direction == "left" then
            column = (column + 1) % 2
        elseif direction == "right" then
            column = (column + 1) % 2
        elseif direction == "up" then
            row = (row - 1) % row_count
        elseif direction == "down" then
            row = (row + 1) % row_count
        end
        local next_cursor = row * 2 + column + 1
        if next_cursor > count then
            next_cursor = direction == "left" and cursor - 1
                or direction == "right" and math.min(count, cursor + 1)
                or cursor
        end
        return math.max(1, math.min(count, next_cursor))
    end

    local function submit_battle_intent(game, kind, values)
        local snapshot = read_battle_snapshot()
        if not is_owned_battle_prompt(snapshot) then return false end
        battle_intent_id = battle_intent_id + 1
        local intent = {
            id = battle_intent_id,
            revision = snapshot.revision,
            kind = kind,
        }
        for key, value in pairs(values or {}) do intent[key] = value end

        local ok, accepted, reason = pcall(mod.battle.submit, mod.battle, intent)
        if not ok or accepted ~= true then
            mod.log:warn(
                "Battle UI command rejected (%s): %s",
                tostring(kind), tostring(ok and reason or accepted)
            )
            return false
        end
        battle_ui.snapshot = nil
        battle_ui.layout = nil
        return true
    end

    local function activate_battle_cursor(game, snapshot)
        sync_battle_ui(game, snapshot)
        if snapshot.prompt == "menu" then
            local actions = battle_actions_for(game)
            local action = actions[battle_ui.cursor]
            if action then
                return submit_battle_intent(game, "menu", { choice = action.key })
            end
        elseif snapshot.prompt == "moves" then
            local move = snapshot.moves and snapshot.moves[battle_ui.cursor]
            if move and move.slot then
                if move.disabled or (tonumber(move.pp) or 0) <= 0 then return false end
                return submit_battle_intent(game, "move", { slot = move.slot })
            elseif move then
                if move.disabled or (tonumber(move.pp) or 0) <= 0 then return false end
                return submit_battle_intent(game, "move", { slot = battle_ui.cursor })
            end
        elseif snapshot.prompt == "target" then
            local target = snapshot.targets and snapshot.targets[battle_ui.cursor]
            if target ~= nil then
                return submit_battle_intent(game, "target", { target = target })
            end
        end
        return false
    end

    local function navigate_battle(game, action)
        local snapshot = read_battle_snapshot()
        if not is_owned_battle_prompt(snapshot) then return false end
        sync_battle_ui(game, snapshot)
        local count = battle_entry_count(snapshot, game)
        if action == "a" then
            return activate_battle_cursor(game, snapshot)
        elseif action == "b" then
            if snapshot.prompt == "moves" or snapshot.prompt == "target" then
                return submit_battle_intent(game, "back", {})
            end
            return true
        elseif action == "left" or action == "right"
            or action == "up" or action == "down" then
            if count <= 0 then return true end
            battle_ui.cursor = battle_grid_cursor(battle_ui.cursor, count, action)
            return true
        end
        -- A mapped action belongs to the replacement menu even when it has
        -- no action here (START/SELECT/shoulders must not reach hidden UI).
        return true
    end

    -- The engine's Android/iOS touch overlay injects GB buttons directly
    -- through Input:overlayPressed, so those presses do not pass through
    -- input.key / input.gamepad. The public input.step hook sees this source
    -- before Input promotes it; route its rising edges into our menu and
    -- temporarily mask the same buttons from the native BattleState.
    local BATTLE_TOUCH_BUTTONS = {
        "up", "down", "left", "right", "a", "b", "start", "select",
    }
    local BATTLE_TOUCH_ACTIONS = {
        up = "up", down = "down", left = "left", right = "right",
        a = "a", b = "b",
    }
    local BATTLE_NATIVE_INPUT_MASK = {
        up = true, down = true, left = true, right = true,
        a = true, b = true, start = true, select = true,
    }

    local function touch_button_down(input, button)
        if not (input and type(input.isTouchDown) == "function") then return false end
        local ok, down = pcall(input.isTouchDown, input, button)
        return ok and down == true
    end

    local function restore_battle_touch_input(input)
        local bridge = battle_ui.touch_input_bridge
        if not bridge then return end
        local owner = bridge.input
        if owner and owner.wasPressed == bridge.wasPressedWrapper then
            owner.wasPressed = bridge.wasPressedOriginal
        end
        if owner and owner.isDown == bridge.isDownWrapper then
            owner.isDown = bridge.isDownOriginal
        end
        if owner and bridge.overlayPressedWrapper
            and owner.overlayPressed == bridge.overlayPressedWrapper then
            owner.overlayPressed = bridge.overlayPressedOriginal
        end
        battle_ui.touch_input_bridge = nil
    end

    local function mask_native_battle_touch_input(input)
        if not (input and type(input.wasPressed) == "function"
            and type(input.isDown) == "function") then
            return
        end
        local bridge = battle_ui.touch_input_bridge
        if bridge and bridge.input == input then return end
        restore_battle_touch_input()
        bridge = {
            input = input,
            wasPressedOriginal = input.wasPressed,
            isDownOriginal = input.isDown,
            isTouchDownOriginal = input.isTouchDown,
            overlayPressedOriginal = input.overlayPressed,
        }
        local function isVirtualTouchHeld(self, button)
            if not BATTLE_NATIVE_INPUT_MASK[button] then return false end
            if battle_ui.touch_mask_pending[button] then return true end
            if type(bridge.isTouchDownOriginal) ~= "function" then return false end
            local ok, down = pcall(bridge.isTouchDownOriginal, self, button)
            return ok and down == true
        end
        bridge.wasPressedWrapper = function(self, button)
            if isVirtualTouchHeld(self, button) then return false end
            return bridge.wasPressedOriginal(self, button)
        end
        bridge.isDownWrapper = function(self, button)
            if isVirtualTouchHeld(self, button) then return false end
            return bridge.isDownOriginal(self, button)
        end
        if type(bridge.overlayPressedOriginal) == "function" then
            bridge.overlayPressedWrapper = function(self, button)
                if BATTLE_NATIVE_INPUT_MASK[button] then
                    battle_ui.touch_pending[button] = true
                end
                return bridge.overlayPressedOriginal(self, button)
            end
            input.overlayPressed = bridge.overlayPressedWrapper
        end
        input.wasPressed = bridge.wasPressedWrapper
        input.isDown = bridge.isDownWrapper
        battle_ui.touch_input_bridge = bridge
    end

    local function step_battle_touch_input(game, snapshot, touchEdges)
        touchEdges = type(touchEdges) == "table" and touchEdges or {}
        local input = game and game.input
        if not input then
            battle_ui.touch_down = {}
            return
        end

        if is_owned_battle_prompt(snapshot) then
            sync_battle_ui(game, snapshot)
            mask_native_battle_touch_input(input)
        else
            restore_battle_touch_input(input)
        end

        local directionAction, confirmAction
        for _, button in ipairs(BATTLE_TOUCH_BUTTONS) do
            local down = touch_button_down(input, button)
            local wasDown = battle_ui.touch_down[button] == true
            local tapped = touchEdges[button] == true
            if is_owned_battle_prompt(snapshot) and ((down and not wasDown) or tapped) then
                local action = BATTLE_TOUCH_ACTIONS[button]
                if action == "up" or action == "down"
                    or action == "left" or action == "right" then
                    directionAction = directionAction or action
                elseif action == "a" or action == "b" then
                    confirmAction = confirmAction or action
                end
            end
            battle_ui.touch_down[button] = down
        end
        -- A player can hold a direction and tap A at the same time. Apply
        -- the new cursor first, then confirm it in this same input step.
        if directionAction then navigate_battle(game, directionAction) end
        if confirmAction then navigate_battle(game, confirmAction) end
    end

    if mod:supports("hooks", "input.step") then
        mod.hooks:wrap("input.step", function(next, game, dt)
            -- The previous Input:step has consumed the preceding edge, so
            -- retire its temporary mask before collecting the next frame.
            battle_ui.touch_mask_pending = {}
            next(game, dt)
            local touchEdges = battle_ui.touch_pending
            battle_ui.touch_pending = {}
            battle_ui.touch_mask_pending = touchEdges
            local snapshot = read_battle_snapshot()
            step_battle_touch_input(game, snapshot, touchEdges)
        end)
    end

    local function battle_theme(game)
        local id = game_id_from(game) or "red"
        return BATTLE_THEMES[id] or BATTLE_THEMES.red
    end

    local function battle_layout(snapshot, viewport, theme, actions)
        local scale = tonumber(viewport.scale) or 1
        if scale <= 0 then scale = 1 end
        local width = (tonumber(viewport.gameWidth) or 160 * scale) / scale
        local height = (tonumber(viewport.gameHeight) or 144 * scale) / scale
        local panel_height = (snapshot.prompt == "moves" or snapshot.prompt == "target")
            and 62 or 52
        panel_height = math.min(panel_height, height - 18)
        local panel = {
            x = 5, y = height - panel_height - 4,
            w = width - 10, h = panel_height,
        }
        local gap = width >= 200 and 5 or 3
        local header = 10
        local content_y = panel.y + header + 3
        local content_h = panel.h - header - 7
        local buttons = {}

        if snapshot.prompt == "menu" or snapshot.prompt == "moves" then
            local cell_w = (panel.w - 10 - gap) / 2
            local cell_h = (content_h - gap) / 2
            local entries = snapshot.prompt == "menu" and actions
                or snapshot.moves or {}
            for index = 1, math.min(4, #entries) do
                local row = math.floor((index - 1) / 2)
                local column = (index - 1) % 2
                buttons[index] = {
                    x = panel.x + 5 + column * (cell_w + gap),
                    y = content_y + row * (cell_h + gap),
                    w = cell_w,
                    h = cell_h,
                    index = index,
                }
            end
        elseif snapshot.prompt == "target" then
            local targets = snapshot.targets or {}
            local cell_w = (panel.w - 10 - gap) / 2
            local cell_h = (content_h - gap) / 2
            for index = 1, math.min(4, #targets) do
                local row = math.floor((index - 1) / 2)
                local column = (index - 1) % 2
                buttons[index] = {
                    x = panel.x + 5 + column * (cell_w + gap),
                    y = content_y + row * (cell_h + gap),
                    w = cell_w,
                    h = cell_h,
                    index = index,
                }
            end
        end

        local backButton
        if snapshot.prompt == "moves" or snapshot.prompt == "target" then
            backButton = {
                x = panel.x + panel.w * 0.40,
                y = panel.y,
                w = panel.w * 0.58,
                h = header + 5,
            }
        end

        return {
            panel = panel,
            buttons = buttons,
            backButton = backButton,
            width = width,
            height = height,
            scale = scale,
            originX = tonumber(viewport.gameX) or 0,
            originY = tonumber(viewport.gameY) or 0,
            theme = theme,
        }
    end

    local function draw_battle_text(graphics, value, x, y, width, align, color, size_limit)
        value = tostring(value or "")
        if size_limit then value = clip_text(value, size_limit, mod.ui.Font) end
        graphics.setColor(color[1], color[2], color[3], color[4] or 1)
        if graphics.printf then
            graphics.printf(value, x, y, width, align or "left")
        else
            graphics.print(value, x, y)
        end
    end

    local function draw_battle_card(graphics, rect, label, theme, selected, disabled, metadata)
        local background = disabled and { 0.72, 0.73, 0.75, 1 }
            or selected and theme.accent
            or { 0.94, 0.95, 0.97, 1 }
        local foreground = selected and { 1, 1, 1, 1 }
            or disabled and { 0.38, 0.39, 0.41, 1 }
            or { 0.10, 0.12, 0.16, 1 }

        graphics.setColor(background[1], background[2], background[3], background[4])
        graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, theme.radius, theme.radius)
        graphics.setColor(theme.shade[1], theme.shade[2], theme.shade[3], 1)
        graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, theme.radius, theme.radius)

        if metadata and metadata.type then
            local typeColor = BATTLE_TYPE_COLORS[tostring(metadata.type):upper()]
                or theme.accent
            local chipWidth = math.min(37, math.max(24, rect.w * 0.34))
            graphics.setColor(typeColor[1], typeColor[2], typeColor[3], 1)
            graphics.rectangle("fill", rect.x + rect.w - chipWidth - 3,
                rect.y + 3, chipWidth, math.max(8, rect.h - 6), theme.radius, theme.radius)
            draw_battle_text(graphics, tostring(metadata.type):upper(),
                rect.x + rect.w - chipWidth - 2, rect.y + 4, chipWidth - 2,
                "center", { 1, 1, 1, 1 }, 7)
        end

        local text_width = metadata and metadata.type and rect.w * 0.64 or rect.w - 8
        draw_battle_text(graphics, label, rect.x + 4, rect.y + 3,
            text_width, "left", foreground, 13)

        if metadata and metadata.pp ~= nil then
            local ppText = ("PP %s/%s"):format(
                tostring(metadata.pp), tostring(metadata.maxPp or metadata.pp)
            )
            draw_battle_text(graphics, ppText, rect.x + 4, rect.y + rect.h - 10,
                rect.w - 8, "left", foreground, 12)
        end
    end

    local function draw_battle_overlay(game, viewport, snapshot)
        local graphics = love and love.graphics
        if not (graphics and graphics.push and graphics.pop and graphics.rectangle
            and graphics.setColor and graphics.print) then
            return
        end
        local theme = battle_theme(game)
        sync_battle_ui(game, snapshot)
        local actions = battle_actions_for(game)
        local layout = battle_layout(snapshot, viewport, theme, actions)
        battle_ui.layout = layout
        battle_ui.snapshot = snapshot

        local ok, drawError = pcall(function()
            graphics.push("all")
            graphics.translate(tonumber(viewport.gameX) or 0,
                tonumber(viewport.gameY) or 0)
            graphics.scale(layout.scale, layout.scale)

            local panel = layout.panel
            graphics.setColor(0.055, 0.065, 0.085, 1)
            graphics.rectangle("fill", panel.x, panel.y, panel.w, panel.h,
                theme.radius + 2, theme.radius + 2)
            graphics.setColor(theme.accent[1], theme.accent[2], theme.accent[3], 1)
            graphics.rectangle("fill", panel.x, panel.y, 3, panel.h,
                theme.radius, theme.radius)

            local dictionary = TEXT[selected_language()] or TEXT[DEFAULT_LANGUAGE]
            local title = snapshot.prompt == "menu" and dictionary.battle_action
                or snapshot.prompt == "moves" and dictionary.battle_moves
                or dictionary.battle_target
            draw_battle_text(graphics, title or "ACTION", panel.x + 7,
                panel.y + 2, panel.w * 0.36, "left", { 1, 1, 1, 1 }, 12)
            local help = snapshot.prompt == "menu"
                and (dictionary.battle_select or "A: SELECT")
                or (dictionary.battle_back or "B: BACK")
            draw_battle_text(graphics, help, panel.x + panel.w * 0.40,
                panel.y + 2, panel.w * 0.56, "right",
                { 0.82, 0.85, 0.90, 1 }, 14)

            for index, rect in ipairs(layout.buttons) do
                local selected = index == battle_ui.cursor
                if snapshot.prompt == "menu" then
                    local action = actions[index]
                    local key = action and action.label or "battle_choose"
                    local label = dictionary[key] or key:upper()
                    draw_battle_card(graphics, rect, label, theme, selected, false)
                elseif snapshot.prompt == "moves" then
                    local move = snapshot.moves and snapshot.moves[index] or {}
                    local name = move.name or move.id or "—"
                    local disabled = move.disabled == true or (tonumber(move.pp) or 0) <= 0
                    draw_battle_card(graphics, rect, name, theme, selected, disabled, {
                        type = move.type,
                        pp = move.pp or 0,
                        maxPp = move.maxPp or move.pp or 0,
                    })
                elseif snapshot.prompt == "target" then
                    local targetId = snapshot.targets and snapshot.targets[index]
                    local target
                    for _, candidate in ipairs(snapshot.battlers or {}) do
                        if candidate.id == targetId then target = candidate break end
                    end
                    local name = target and (target.name or target.species) or ("TARGET " .. tostring(targetId))
                    local hp = target and target.hp and target.maxHp
                        and ("  %d/%d HP"):format(target.hp, target.maxHp) or ""
                    draw_battle_card(graphics, rect, tostring(name) .. hp,
                        theme, selected, target and target.absent == true)
                end
            end

            if snapshot.prompt == "moves" and #layout.buttons == 0 then
                draw_battle_text(graphics, dictionary.battle_no_moves or "NO USABLE MOVES",
                    panel.x + 8, panel.y + 24, panel.w - 16,
                    "left", { 1, 1, 1, 1 }, 22)
            end

            graphics.pop()
        end)
        if not ok then
            pcall(graphics.pop)
            mod.log:warn("Battle UI draw failed: %s", tostring(drawError))
        end
    end

    if mod:supports("hooks", "battle.bottom_ui_visible") then
        mod.hooks:wrap("battle.bottom_ui_visible", function(next, state)
            local visible = next(state)
            local snapshot = read_battle_snapshot()
            if is_owned_battle_prompt(snapshot) then return false end
            return visible
        end)
    end

    if mod:supports("hooks", "input.key") then
        mod.hooks:wrap("input.key", function(next, game, event)
            if type(event) ~= "table" or event.phase ~= "pressed" then
                return next(game, event)
            end
            local snapshot = read_battle_snapshot()
            if not is_owned_battle_prompt(snapshot) then return next(game, event) end
            local input = game and game.input
            local action = input and input.keyBindings
                and input.keyBindings[event.key]
            if not action then return next(game, event) end
            navigate_battle(game, action)
            return
        end)
    end

    if mod:supports("hooks", "input.gamepad") then
        mod.hooks:wrap("input.gamepad", function(next, game, event)
            if type(event) ~= "table" then return next(game, event) end
            local snapshot = read_battle_snapshot()
            if not is_owned_battle_prompt(snapshot) then
                battle_ui.axis_action = nil
                return next(game, event)
            end

            local input = game and game.input
            if event.phase == "pressed" then
                local action
                if input and type(input.padAction) == "function" then
                    local ok, mapped = pcall(input.padAction, input, event.button, true)
                    if ok then action = mapped end
                end
                if not action then return next(game, event) end
                navigate_battle(game, action)
                return
            elseif event.phase == "axis" then
                local action
                local axis, value = event.axis, tonumber(event.value) or 0
                if axis == "leftx" or axis == "rightx" then
                    if value <= -0.55 then action = "left"
                    elseif value >= 0.55 then action = "right" end
                elseif axis == "lefty" or axis == "righty" then
                    if value <= -0.55 then action = "up"
                    elseif value >= 0.55 then action = "down" end
                end
                if action then
                    if battle_ui.axis_action ~= action then
                        battle_ui.axis_action = action
                        navigate_battle(game, action)
                    end
                    return
                end
                battle_ui.axis_action = nil
                return next(game, event)
            end
            return next(game, event)
        end)
    end

    if mod:supports("hooks", "input.pointer") then
        mod.hooks:wrap("input.pointer", function(next, game, event)
            if type(event) ~= "table" then return next(game, event) end
            local pointerKey = tostring(event.source) .. ":" .. tostring(event.id)
            if event.phase == "released" or event.phase == "cancelled" then
                if battle_ui.pointer_captures[pointerKey] then
                    battle_ui.pointer_captures[pointerKey] = nil
                    return true
                end
                return next(game, event)
            end

            local snapshot = read_battle_snapshot()
            if not is_owned_battle_prompt(snapshot) then return next(game, event) end
            if event.phase ~= "pressed" then
                return battle_ui.pointer_captures[pointerKey] == true
            end

            local layout = battle_ui.layout
            if type(layout) ~= "table" or type(event.gameX) ~= "number"
                or type(event.gameY) ~= "number" then
                return next(game, event)
            end
            -- input.pointer reports viewport-local window coordinates;
            -- the battle cards are drawn in logical game pixels after the
            -- render.hud translation/scale, so invert that transform here.
            local x = (event.gameX - layout.originX) / layout.scale
            local y = (event.gameY - layout.originY) / layout.scale
            local panel = layout.panel
            local inside = x >= panel.x and x <= panel.x + panel.w
                and y >= panel.y and y <= panel.y + panel.h
            if not inside then return next(game, event) end

            battle_ui.pointer_captures[pointerKey] = true
            local back = layout.backButton
            if back and x >= back.x and x <= back.x + back.w
                and y >= back.y and y <= back.y + back.h then
                submit_battle_intent(game, "back", {})
                return true
            end
            for index, rect in ipairs(layout.buttons) do
                if x >= rect.x and x <= rect.x + rect.w
                    and y >= rect.y and y <= rect.y + rect.h then
                    battle_ui.cursor = index
                    activate_battle_cursor(game, snapshot)
                    break
                end
            end
            return true
        end)
    end

    -- One local profile per game version, shared by all save files for that
    -- title on this installation. This matches the title-level behavior of
    -- console achievement lists without mixing any of the eleven games.
    -- mod.cache is installation-scoped; it is not a cloud/account service.
    local function load_profile_for_game(game_id)
        if not profiles[game_id] then get_profile(game_id) end
        return profiles[game_id]
    end

    load_catalog()

    local event_names = {}
    for _, entries in pairs(catalog) do
        for _, achievement in ipairs(entries) do
            event_names[achievement.event] = true
        end
    end

    for event_name in pairs(event_names) do
        register_event(event_name)
    end

    if mod:supports("events", "game.ready") then
        mod.events:on("game.ready", function(event)
            if type(event) == "table" then active_game = event.game end
            local game_id = game_id_from(active_game)
            if game_id then load_profile_for_game(game_id) end
        end)
    end

    if mod:supports("events", "save.loading") then
        mod.events:on("save.loading", function()
            session_ready = false
        end)
    end

    if mod:supports("events", "save.loaded") then
        mod.events:on("save.loaded", function()
            session_ready = true
        end)
    end

    if mod:supports("events", "save.created") then
        mod.events:on("save.created", function()
            session_ready = true
        end)
    end

    -- A compact console-style unlock toast, drawn after the game frame and
    -- before on-screen controls. render.hud exists in all three generations.
    if mod:supports("hooks", "render.hud") then
        mod.hooks:wrap("render.hud", function(next, game, viewport)
            next(game, viewport)
            if viewport then
                local snapshot = read_battle_snapshot()
                if is_owned_battle_prompt(snapshot) then
                    draw_battle_overlay(game, viewport, snapshot)
                else
                    restore_battle_touch_input(game and game.input)
                    battle_ui.layout = nil
                    battle_ui.snapshot = nil
                    if battle_ui.prompt ~= nil then
                        battle_ui.prompt = nil
                        battle_ui.cursor = 1
                    end
                end
            end
            if not toast or toast_remaining <= 0 or not viewport then return end

            local achievement = catalog_by_id[toast.id]
            if not achievement then return end

            local graphics = love and love.graphics
            if not (graphics and graphics.push and graphics.rectangle
                and graphics.print and graphics.setColor) then
                return
            end

            local language = selected_language()
            local dictionary = TEXT[language] or TEXT[DEFAULT_LANGUAGE]
            local game_width = tonumber(viewport.gameWidth) or 160
            local x = (tonumber(viewport.gameX) or 0) + 8
            local y = (tonumber(viewport.gameY) or 0) + 8
            local width = math.max(120, math.min(300, game_width - 16))

            local ok = pcall(function()
                graphics.push("all")
                graphics.setColor(0.04, 0.05, 0.08, 0.94)
                graphics.rectangle("fill", x, y, width, 48, 4, 4)
                graphics.setColor(0.98, 0.78, 0.22, 1)
                graphics.rectangle("fill", x, y, 4, 48)
                graphics.setColor(1, 1, 1, 1)
                graphics.print(dictionary.notification, x + 12, y + 7)
                graphics.print(
                    clip_text(achievement.title[language]
                        or achievement.title[DEFAULT_LANGUAGE], 30, mod.ui.Font),
                    x + 12, y + 26
                )
                graphics.pop()
            end)

            if not ok then
                -- Rendering must never interrupt the game's own frame.
                pcall(graphics.pop)
            end
        end)
    end

    if mod:supports("hooks", "core.update") then
        mod.hooks:wrap("core.update", function(next, game, dt)
            next(game, dt)
            if toast then
                toast_remaining = toast_remaining - (tonumber(dt) or 0)
                if toast_remaining <= 0 then
                    toast = nil
                    toast_remaining = 0
                end
            end
        end)
    end

    mod.events:on("mod.options_changed", function(event)
        if type(event) ~= "table" or event.key ~= LANGUAGE_OPTION then return end

        local owner = event.mod
        local owner_id = type(owner) == "table" and owner.id or owner
        if owner_id ~= nil and owner_id ~= MOD_ID then return end

        mod.events:emit("mod.gen1_achievements.language_changed", {
            language = normalize_language(event.value),
        })
    end)

    mod.log:info(
        "Gen1 Achievements initialized; language=%s; start-menu entry registered",
        selected_language()
    )
end

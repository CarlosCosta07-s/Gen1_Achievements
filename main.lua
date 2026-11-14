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

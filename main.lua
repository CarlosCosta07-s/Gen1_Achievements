-- Gen1 Achievements
-- Portable Mod API 3. The achievement catalog and event handlers are added
-- only after their per-game requirements have been verified.

local MOD_ID = "gen1_achievements"
local LANGUAGE_OPTION = "achievement_language"
local DEFAULT_LANGUAGE = "pt-BR"

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

local function normalize_language(value)
    if type(value) == "string" and SUPPORTED_LANGUAGES[value] then
        return value
    end

    return DEFAULT_LANGUAGE
end

return function(mod)
    -- mod.options is persisted outside individual game saves and is rendered
    -- by the Gen1Recomp mod manager in the launcher.
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

    -- Expose a mod-scoped notification for the future Extras → Achievements
    -- launcher integration and any UI component that needs to refresh.
    mod.events:on("mod.options_changed", function(event)
        if type(event) ~= "table" or event.key ~= LANGUAGE_OPTION then
            return
        end

        local owner_id = type(event.mod) == "table" and event.mod.id or nil
        if owner_id ~= nil and owner_id ~= MOD_ID then
            return
        end

        mod.events:emit("mod.gen1_achievements.language_changed", {
            language = selected_language(),
        })
    end)

    mod.log:info(
        "Gen1 Achievements initialized; language=%s",
        selected_language()
    )
end

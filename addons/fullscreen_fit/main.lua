-- Fullscreen Fit — Aspect Ratio
-- Portable Mod API 3. Reserves the largest centered viewport that preserves
-- the native screen ratio for the active generation. The engine renders the
-- game and its sprites; this mod only chooses the viewport rectangle.

local ASPECT = {
    [1] = 160 / 144, -- Game Boy
    [2] = 160 / 144, -- Game Boy Color
    [3] = 240 / 160, -- Game Boy Advance
}

local function finite(value)
    return type(value) == "number"
        and value == value
        and value > -math.huge
        and value < math.huge
end

local function positive(value)
    return finite(value) and value > 0
end

local function base_rectangle(ctx, base)
    if type(base) ~= "table" then return nil end

    local window_width = tonumber(ctx.width)
    local window_height = tonumber(ctx.height)
    if not positive(window_width) or not positive(window_height) then
        return nil
    end

    local x = finite(base.x) and base.x or 0
    local y = finite(base.y) and base.y or 0
    local width = positive(base.width) and base.width or window_width
    local height = positive(base.height) and base.height or window_height

    x = math.max(0, math.min(math.floor(x), math.floor(window_width) - 1))
    y = math.max(0, math.min(math.floor(y), math.floor(window_height) - 1))
    width = math.max(1, math.min(math.floor(width), math.floor(window_width) - x))
    height = math.max(1, math.min(math.floor(height), math.floor(window_height) - y))

    return {
        x = x, y = y, width = width, height = height,
        capture = base.capture == true,
    }
end

local function fit_viewport(ctx, base)
    local aspect = ASPECT[tonumber(ctx.generation)]
    if not aspect then return base end

    local rect = base_rectangle(ctx, base)
    if not rect then return base end

    -- Work in physical pixels so high-DPI displays and asymmetric DPI values
    -- still receive the correct physical aspect ratio.
    local dpi_x = positive(ctx.dpiX) and ctx.dpiX or 1
    local dpi_y = positive(ctx.dpiY) and ctx.dpiY or 1
    local available_width = rect.width * dpi_x
    local available_height = rect.height * dpi_y

    local fitted_width = available_width
    local fitted_height = fitted_width / aspect
    if fitted_height > available_height then
        fitted_height = available_height
        fitted_width = fitted_height * aspect
    end

    local width = math.max(1, math.floor(fitted_width / dpi_x + 0.5))
    local height = math.max(1, math.floor(fitted_height / dpi_y + 0.5))
    width = math.min(width, rect.width)
    height = math.min(height, rect.height)

    -- If the window already has the native ratio, preserve the downstream
    -- rectangle verbatim. This avoids allocating a composition canvas.
    if width == rect.width and height == rect.height then
        if rect.x == base.x and rect.y == base.y
            and rect.width == base.width and rect.height == base.height then
            return base
        end
    end

    local x = rect.x + math.floor((rect.width - width) / 2)
    local y = rect.y + math.floor((rect.height - height) / 2)

    local result = { x = x, y = y, width = width, height = height }
    if rect.capture then result.capture = true end
    return result
end

return function(mod)
    if type(mod) ~= "table"
        or type(mod.supports) ~= "function"
        or not mod:supports("hooks", "render.viewport") then
        if mod and mod.log and type(mod.log.warn) == "function" then
            mod.log:warn("Fullscreen Fit requires the render.viewport hook")
        end
        return
    end

    mod.hooks:wrap("render.viewport", function(next, ctx)
        local base = next(ctx)
        return fit_viewport(ctx, base)
    end)

    if mod.log and type(mod.log.info) == "function" then
        mod.log:info(
            "Fullscreen Fit enabled: 10:9 for Gen 1/2 and 3:2 for Gen 3; aspect preserved"
        )
    end
end

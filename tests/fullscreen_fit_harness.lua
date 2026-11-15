#!/usr/bin/env luajit
-- ROM-free tests for the standalone Fullscreen Fit viewport mod.

local function check(value, message)
    if not value then error(message, 2) end
end

local setup = dofile("addons/fullscreen_fit/main.lua")
local captured_name
local wrapper
local log = { info = function() end, warn = function() end }
local mod = {
    supports = function(_, surface, name)
        return surface == "hooks" and name == "render.viewport"
    end,
    hooks = {
        wrap = function(_, name, callback)
            captured_name, wrapper = name, callback
        end,
    },
    log = log,
}
setup(mod)
check(captured_name == "render.viewport" and type(wrapper) == "function",
    "mod did not register render.viewport")

local function run(ctx, base)
    local called = false
    local result = wrapper(function(received)
        called = true
        check(received == ctx, "next received a different context")
        return base
    end, ctx)
    check(called, "mod did not preserve the downstream viewport chain")
    return result
end

local function ratio(rect, dpi_x, dpi_y)
    return (rect.width * dpi_x) / (rect.height * dpi_y)
end

local function inside(rect, parent)
    return rect.x >= parent.x and rect.y >= parent.y
        and rect.x + rect.width <= parent.x + parent.width
        and rect.y + rect.height <= parent.y + parent.height
end

local wide_pc = { width = 1920, height = 1080, dpiX = 1, dpiY = 1, generation = 3 }
local base = { x = 0, y = 0, width = 1920, height = 1080 }
local r = run(wide_pc, base)
check(math.abs(ratio(r, 1, 1) - 1.5) < 0.002,
    "Gen 3 wide desktop viewport is not 3:2")
check(r.height == 1080 and r.width == 1620 and r.x == 150 and r.y == 0,
    "Gen 3 desktop viewport did not use the maximum centered rectangle")

local portrait_phone = {
    width = 1080, height = 2400, pixelWidth = 2160, pixelHeight = 4800,
    dpiX = 2, dpiY = 2, generation = 3,
}
local phone_base = { x = 0, y = 0, width = 1080, height = 2400 }
r = run(portrait_phone, phone_base)
check(math.abs(ratio(r, 2, 2) - 1.5) < 0.004,
    "Gen 3 portrait phone viewport is not 3:2")
check(r.width == 1080 and r.height < 800 and r.y > 0,
    "Gen 3 portrait phone did not fit to width with centered bars")

local gen1 = { width = 1920, height = 1080, dpiX = 1, dpiY = 1, generation = 1 }
r = run(gen1, base)
check(math.abs(ratio(r, 1, 1) - (10 / 9)) < 0.002,
    "Gen 1 viewport is not 10:9")

local gen2 = { width = 720, height = 1280, dpiX = 1, dpiY = 1, generation = 2 }
local gen2_base = { x = 0, y = 0, width = 720, height = 1280 }
r = run(gen2, gen2_base)
check(math.abs(ratio(r, 1, 1) - (10 / 9)) < 0.002,
    "Gen 2 viewport is not 10:9")

local android_landscape = {
    width = 768, height = 344, pixelWidth = 1536, pixelHeight = 688,
    dpiX = 2, dpiY = 2, generation = 3,
}
local landscape_base = { x = 0, y = 0, width = 768, height = 344 }
r = run(android_landscape, landscape_base)
check(math.abs(ratio(r, 2, 2) - 1.5) < 0.004,
    "high-DPI Android landscape did not preserve 3:2")
check(r.width < landscape_base.width and r.height == landscape_base.height,
    "high-DPI Android landscape did not maximize vertically")

local nested_ctx = { width = 1920, height = 1080, dpiX = 1, dpiY = 1, generation = 3 }
local nested_base = { x = 100, y = 100, width = 800, height = 800, capture = true }
r = run(nested_ctx, nested_base)
check(math.abs(ratio(r, 1, 1) - 1.5) < 0.003,
    "composed viewport failed to preserve aspect")
check(inside(r, nested_base), "composed viewport escaped the downstream rectangle")
check(r.capture == true, "downstream capture request was dropped")

local native_ctx = { width = 1500, height = 1000, dpiX = 1, dpiY = 1, generation = 3 }
local native_base = { x = 10, y = 20, width = 1200, height = 800 }
r = run(native_ctx, native_base)
check(r == native_base,
    "native-aspect downstream viewport should pass through without a capture canvas")

local unknown_ctx = { width = 900, height = 600, dpiX = 1, dpiY = 1, generation = 4 }
local unknown_base = { x = 0, y = 0, width = 900, height = 600 }
check(run(unknown_ctx, unknown_base) == unknown_base,
    "unknown generation must preserve the downstream viewport")

local invalid_ctx = { width = 0, height = 0, generation = 3 }
local invalid_base = { x = 0, y = 0, width = 0, height = 0 }
check(run(invalid_ctx, invalid_base) == invalid_base,
    "invalid dimensions must fail open to the downstream viewport")

local unsupported_wrapper
local unsupported = {
    supports = function() return false end,
    hooks = { wrap = function() error("unsupported hook must not be wrapped") end },
    log = log,
}
setup(unsupported)
print("Fullscreen Fit tests OK: generations 1/2/3, desktop, portrait/landscape Android, DPI, hook composition, capture and fail-open.")

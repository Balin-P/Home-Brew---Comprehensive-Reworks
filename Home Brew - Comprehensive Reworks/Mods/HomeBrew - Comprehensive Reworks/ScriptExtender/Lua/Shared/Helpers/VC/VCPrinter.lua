--[[
    This code snippet is from Volition Cabinet. Note that Volition Cabinet is a fork from Focus' Focus Core.

    MIT License

    Copyright (c) 2024 Volitio

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.
]]

---@class VolitionCabinetPrinter: MetaClass
---@field Authorship string
---@field Prefix string
---@field Machine "S"|"C"
---@field FontColor vec3
---@field BackgroundColor vec3
---@field ApplyColor boolean
---@field DebugLevel integer
VolitionCabinetPrinter = _Class:Create("VolitionCabinetPrinter", nil, {
    Authorship = "Volitio's",
    Prefix = "VolitionCabinetPrinter",
    Machine = Ext.IsServer() and "S" or "C",
    FontColor = { 192, 192, 192 },
    BackgroundColor = { 12, 12, 12 },
    ApplyColor = false,
    DebugLevel = 0,
})

---@param r integer
---@param g integer
---@param b integer
function VolitionCabinetPrinter:SetFontColor(r, g, b)
    self.FontColor = { r or 0, g or 0, b or 0 }
end

---@param r integer
---@param g integer
---@param b integer
function VolitionCabinetPrinter:SetBackgroundColor(r, g, b)
    self.BackgroundColor = { r or 0, g or 0, b or 0 }
end

---@param text string
---@param fontColor? vec3
---@param backgroundColor? vec3
---@return string
function VolitionCabinetPrinter:Colorize(text, fontColor, backgroundColor)
    local fr, fg, fb = table.unpack(fontColor or self.FontColor)
    local br, bg, bb = table.unpack(backgroundColor or self.BackgroundColor)
    return string.format("\x1b[38;2;%s;%s;%s;48;2;%s;%s;%sm%s", fr, fg, fb, br, bg, bb, text)
end

---@vararg any
---@return string
local function FormatMessage(...)
    if #{ ... } <= 1 then
        return tostring(...)
    end

    return string.format(...)
end

---@vararg any
function VolitionCabinetPrinter:Print(debugLevel, ...)
    if self.DebugLevel < (debugLevel and tonumber(debugLevel) or 0) then
        return
    end

    local prefix
    if self.DebugLevel > 0 then
        prefix = string.format("[%s][D%s]: ", self.Prefix, debugLevel)
    else
        prefix = string.format("[%s]: ", self.Prefix)
    end

    if self.ApplyColor then
        prefix = self:Colorize(prefix)
    end

    Ext.Utils.Print(prefix .. FormatMessage(...))
end

---@vararg any
function VolitionCabinetPrinter:PrintWarning(debugLevel, ...)
    if self.DebugLevel < (debugLevel and tonumber(debugLevel) or 0) then
        return
    end

    local prefix = string.format("[%s][WARN]: ", self.Prefix)
    if self.ApplyColor then
        prefix = self:Colorize(prefix)
    end

    Ext.Utils.PrintWarning(prefix .. FormatMessage(...))
end

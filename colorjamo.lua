luatexbase.provides_module{
  name = 'colorjamo',
  date = '2021/04/01',
  version     = 0.3,
  description = 'Colorize Old Hangul Jamo',
  author      = 'Dohyun Kim',
  license     = 'Public Domain',
}

colorjamo = colorjamo or {}
local colorjamo = colorjamo

local function is_syllable (c)
  return c >= 0xAC00 and c <= 0xD7A3
end

local function is_cho (c)
  return c >= 0x1100 and c <= 0x115F
  or     c >= 0xA960 and c <= 0xA97C
  or     c >= 0x3131 and c <= 0x314E
  or     c >= 0x3165 and c <= 0x3186
end

local function is_jung (c)
  return c >= 0x1160 and c <= 0x11A7
  or     c >= 0xD7B0 and c <= 0xD7C6
  or     c >= 0x314F and c <= 0x3163
  or     c >= 0x3187 and c <= 0x318E
end

local function is_jong (c)
  return c >= 0x11A8 and c <= 0x11FF
  or     c >= 0xD7CB and c <= 0xD7FB
end

local SBase = 0xAC00
local LBase = 0x1100
local VBase = 0x1161
local TBase = 0x11A7
local VCount = 21
local TCount = 28
local NCount = VCount * TCount

local function syllable2jamo (c)
  local SIndex = c - SBase
  local L = SIndex // NCount + LBase
  local V = SIndex % NCount // TCount + VBase
  local T = SIndex % TCount + TBase
  if T == TBase then
    T = nil
  end
  return { L, V, T }
end

--
-- colors
--
local luacolorid   = oberdiek.luacolor.getvalue

local format = string.format

local function getluacolorid (str)
  local length = str:len()
  if length > 6 or length < 1 then
    error(format("'%s' is not a valid expression!", str))
  elseif length < 6 then
    str = format("%06x", tonumber(str,16))
  end
  str = str:gsub("%x%x", function(h)
    return format("%.3g ", tonumber(h, 16)/255)
  end)
  local id = luacolorid(str.."rg")
  tex.sprint(tostring(id))
end
colorjamo.getluacolorid = getluacolorid

local glyph   = node.id"glyph"
local cpnode  = node.copy
local getnext = node.getnext
local setattr = node.set_attribute
local hasattr = node.has_attribute
local unsetattr = node.unset_attribute
local insertafter = node.insert_after

local opacityjamoattr = luatexbase.attributes.opacityjamoattr

local colorchoattr  = luatexbase.attributes.colorchoattr
local colorjungattr = luatexbase.attributes.colorjungattr
local colorjongattr = luatexbase.attributes.colorjongattr

local luacolorattr  = oberdiek.luacolor.getattribute()

local function process_color (head)
  local curr = head
  while curr do
    if curr.id == glyph then
      local c = curr.char
      if is_syllable(c) then
        local t = {
          hasattr(curr, colorchoattr),
          hasattr(curr, colorjungattr),
          hasattr(curr, colorjongattr),
        }
        if t[1] and t[2] and t[3] then
          for i, j in ipairs(syllable2jamo(c)) do
            if i ~= 1 then
              head, curr = insertafter(head, curr, cpnode(curr))
            end
            curr.char = j
            setattr(curr, luacolorattr, t[i])
          end
        end
      elseif is_cho (c) then
        local attr = hasattr(curr, colorchoattr)
        if attr then
          setattr(curr, luacolorattr, attr)
        end
      elseif is_jung(c) then
        local attr = hasattr(curr, colorjungattr)
        if attr then
          setattr(curr, luacolorattr, attr)
        end
      elseif is_jong(c) then
        local attr = hasattr(curr, colorjongattr)
        if attr then
          setattr(curr, luacolorattr, attr)
        end
      elseif hasattr(curr, opacityjamoattr) then
        unsetattr(curr, opacityjamoattr)
      end
    end
    curr = getnext(curr)
  end
  return true
end

luatexbase.add_to_callback("pre_shaping_filter", process_color, "colorjamo_color")

--
-- opacity
--
local opacities = { }

local function getopacityid(str)
  str = "/TRP"..str.." gs"
  local id = opacities[str]
  if not id then
    id = #opacities + 1
    opacities[id] = str
    opacities[str] = id
  end
  tex.sprint(tostring(id))
end
colorjamo.getopacityid = getopacityid

local penalty = node.id"penalty"
local kern    = node.id"kern"
local glue    = node.id"glue"
local rule    = node.id"rule"
local leaders = 100 -- or more
local SETcmd  = 0   -- colorstack command 0 = set, 1 = push, 2 = pop
local localpar = node.id"local_par"
local insertbefore = node.insert_before

local function get_colorstack (id, cmd)
  local n = node.new("whatsit", "pdf_colorstack")
  n.stack = colorjamo.TRPcolorstack
  n.command = cmd or (id and 1) or 2
  n.data = id and opacities[id] or nil
  return n
end

local function process_opacity (head, opaque)
  local curr = head
  while curr do
    if curr.list then
      curr.list, opaque = process_opacity(curr.list, opaque)
    elseif curr.leader and curr.leader.id ~= rule then
      curr.leader.list, opaque = process_opacity(curr.leader.list, opaque)
    else
      local id = curr.id
      if opaque then
        if id == penalty  then
        elseif id == kern then
        elseif id == glue and curr.subtype < leaders then
        elseif id == localpar then
        elseif id == glyph then
          local attr = hasattr(curr, opacityjamoattr)
          if not attr then
            head = insertbefore(head, curr, get_colorstack())
            opaque = nil
          elseif attr ~= opaque then
            head = insertbefore(head, curr, get_colorstack(attr, SETcmd))
            opaque = attr
          end
        else
          head = insertbefore(head, curr, get_colorstack())
          opaque = nil
        end
      elseif id == glyph then
        local attr = hasattr(curr, opacityjamoattr)
        if attr then
          head = insertbefore(head, curr, get_colorstack(attr))
          opaque = attr
        end
      end
    end
    curr = getnext(curr)
  end
  return head, opaque
end
colorjamo.process_opacity = process_opacity



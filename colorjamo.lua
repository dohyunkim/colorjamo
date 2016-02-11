luatexbase.provides_module({
  name	= 'colorjamo',
  date	= '2016/02/01',
  version	= 0.2,
  description	= 'Colorize Old Hangul Jamo',
  author	= 'Dohyun Kim',
  license	= 'Public Domain',
})

colorjamo = colorjamo or {}
local colorjamo = colorjamo

local attrs         = luatexbase.attributes
local colorjamoattr = attrs.colorjamoattr
local colorLCattr   = attrs.colorjamochoattr
local colorMVattr   = attrs.colorjamojungattr
local colorTCattr   = attrs.colorjamojongattr
local colorTRattr   = attrs.colorjamotransattr
local unicodeattr   = attrs.luakounicodeattr or attrs.unicodeattr
local glyph         = node.id("glyph")
local hlist         = node.id("hlist")
local vlist         = node.id("vlist")
local nodenew       = node.new
local nodecopy      = node.copy
local noderemove    = node.remove
local nodefree      = node.free
local has_attribute = node.has_attribute
local insert_before = node.insert_before
local insert_after  = node.insert_after
local floor         = math.floor

local res_t, transstack
local newcolorstack = pdf.newcolorstack
local atletter = luatexbase.registernumber("catcodetable@atletter")
local sprintf, concat   = string.format, table.concat
local gettoks, scantoks = tex.gettoks, tex.scantoks
local getpageres = pdf.getpageresources or function() return pdf.pageresources end
local setpageres = pdf.setpageresources or function(s) pdf.pageresources = s end
local pgf = { bye = "pgfutil@everybye", extgs = "\\pgf@sys@addpdfresource@extgs@plain" }

local function isLC (c)
  return ( c >= 0x1100 and c <= 0x115F )
  or     ( c >= 0xA960 and c <= 0xA97C )
end

local function isMV (c)
  return ( c >= 0x1160 and c <= 0x11A7 )
  or     ( c >= 0xD7B0 and c <= 0xD7C6 )
end

local function isTC (c)
  return ( c >= 0x11A8 and c <= 0x11FF )
  or     ( c >= 0xD7CB and c <= 0xD7FB )
end

local function isSYL (c)
  return ( c >= 0xAC00 and c <= 0xD7A3 )
end

local function get_trans_node (data)
  local tr_node
  data = data and sprintf("/TransGs%s gs", data)
  if transstack then
    tr_node         = nodenew("whatsit","pdf_colorstack")
    tr_node.stack   = transstack
    tr_node.command = data and 1 or 2
    tr_node.data    = data or nil
  else
    tr_node         = nodenew("whatsit","pdf_literal")
    tr_node.mode    = 2
    tr_node.data    = data or "/TransGs1 gs"
  end
  return tr_node
end

local function trans_on_off (head, curr, trans)
  if not trans then
    return insert_after(head, curr, get_trans_node())
  elseif trans == 0xFF then
    return head
  end
  if newcolorstack and not transstack then
    transstack = newcolorstack("/TransGs1 gs","direct",true)
  end
  trans = sprintf("%.3g", trans / 0xFF)
  res_t = res_t or { }
  res_t[trans] = true
  head = insert_before(head, curr, get_trans_node(trans))
  return head, trans
end

local function color_on_off (head, curr, color, command)
  local clr_node   = nodenew("whatsit","pdf_colorstack")
  clr_node.stack   = 0
  clr_node.command = command or 2
  if not command then
    return insert_after(head, curr, clr_node)
  end
  color = has_attribute(curr, color) or 0
  local t = {}
  for s in sprintf("%06x",color):gmatch("%x%x") do
    t[#t+1] = sprintf("%.3g", tonumber(s, 16) / 0xFF)
  end
  clr_node.data = sprintf("%s %s %s rg", t[1], t[2], t[3])
  return insert_before(head, curr, clr_node)
end

local function do_color_jamo (head, groupcode)
  local curr = head
  while curr do
    if curr.id == hlist or curr.id == vlist then
      curr.head = do_color_jamo(curr.head)
    elseif curr.id == glyph and has_attribute(curr, colorjamoattr) then
      local uni = has_attribute(curr, unicodeattr)
      if uni and isMV(uni) then
        local LC, TC = curr.prev, curr.next
        if LC and LC.id == glyph and isLC(has_attribute(LC, unicodeattr)) then
          local trattr = has_attribute(LC, colorTRattr) or 0xFF
          head, trattr = trans_on_off(head, LC, trattr)
          head = color_on_off(head, LC,   colorLCattr, 1)
          head = color_on_off(head, curr, colorMVattr, 0)
          if TC and TC.id == glyph and isTC(has_attribute(TC, unicodeattr)) then
            head = color_on_off(head, TC, colorTCattr, 0)
            curr = TC
          end
          head, curr = color_on_off(head, curr)
          if trattr then
            head, curr = trans_on_off(head, curr)
          end
        end
      end
    end
    curr = curr.next
  end

  -- >> transparency
  if res_t and groupcode then
    res_t["1"] = true
    if scantoks and pgf.bye and not pgf.loaded then
      pgf.loaded = token.create(pgf.bye).cmdname == "assign_toks"
      pgf.bye    = pgf.loaded and pgf.bye
    end
    local tpr = pgf.loaded and gettoks(pgf.bye) or getpageres() or ""
    local t = { }
    for k in pairs(res_t) do
      local str = sprintf("/TransGs%s<</ca %s>>", k, k)
      if not tpr:find(str) then
        t[#t+1] = str
      end
    end
    if #t > 0 then
      t = concat(t)
      if pgf.loaded then
        scantoks("global", pgf.bye, atletter, sprintf("%s{%s}%s", pgf.extgs, t, tpr))
      else
        local tpr, n = tpr:gsub("/ExtGState<<", "%1"..t)
        if n == 0 then tpr = sprintf("%s/ExtGState<<%s>>", tpr, t) end
        setpageres(tpr)
      end
    end
    res_t = nil -- reset
  end
  -- << transparency

  return head
end

local function syllable_jamo (head)
  local curr, t = head, {}
  while curr do
    if curr.id == glyph and has_attribute(curr, colorjamoattr) then
      local s = curr.char
      if s and isSYL(s) then
        s = s - 0xAC00
        local LC = floor(s / 588) + 0x1100
        local MV = floor(s % 588 / 28) + 0x1161
        local TC = s % 28 + 0x11A7
        for _, j in ipairs{LC, MV, TC} do
          if j ~= 0x11A7 then
            local jnode = nodecopy(curr)
            jnode.char = j
            head = insert_before(head, curr, jnode)
          end
        end
        head = noderemove(head, curr)
        t[#t+1] = curr
      end
    end
    curr = curr.next
  end
  for _, v in ipairs(t) do nodefree(v) end
  return head
end

local add_to_callback       = luatexbase.add_to_callback
local callback_descriptions = luatexbase.callback_descriptions
local remove_from_callback  = luatexbase.remove_from_callback

local function pre_to_callback (name, func, desc)
  local t = { {func, desc} }
  for _,v in ipairs(callback_descriptions(name)) do
    t[#t+1] = {remove_from_callback(name, v)}
  end
  for _,v in ipairs(t) do
    add_to_callback(name, v[1], v[2])
  end
end

pre_to_callback("hpack_filter",          syllable_jamo, "colorjamo")
pre_to_callback("pre_linebreak_filter",  syllable_jamo, "colorjamo")
add_to_callback("post_linebreak_filter", do_color_jamo, "colorjamo")

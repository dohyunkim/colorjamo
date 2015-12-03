luatexbase.provides_module({
  name	= 'colorjamo',
  date	= '2015/11/30',
  version	= 0.1,
  description	= 'Colorize Old Hangul Jamo',
  author	= 'Dohyun Kim',
  license	= 'Public Domain',
})

colorjamo = colorjamo or {}
local colorjamo = colorjamo

local attrs         = luatexbase.attributes
local colorjamoattr = attrs.colorjamoattr
local colorchoattr  = attrs.colorjamochoattr
local colorjungattr = attrs.colorjamojungattr
local colorjongattr = attrs.colorjamojongattr
local colortransattr= attrs.colorjamotransattr
local unicodeattr   = attrs.luakounicodeattr or attrs.unicodeattr
local glyph         = node.id("glyph")
local hlist         = node.id("hlist")
local vlist         = node.id("vlist")
local nodecopy      = node.copy
local nodenew       = node.new
local traverse      = node.traverse
local has_attribute = node.has_attribute
local insert_before = node.insert_before
local insert_after  = node.insert_after
local addtocallback = luatexbase.add_to_callback

local push_color    = nodenew("whatsit","pdf_colorstack")
push_color.stack    = 0
push_color.command  = 1
local pop_color     = nodecopy(push_color)
pop_color.command   = 2
local set_color     = nodecopy(push_color)
set_color.command   = 0

local res_t, transstack
local newcolorstack = pdf.newcolorstack
local atletter = luatexbase.registernumber("catcodetable@atletter")
local sprintf, concat   = string.format, table.concat
local gettoks, scantoks = tex.gettoks, tex.scantoks
local getpageres = pdf.getpageresources or function() return pdf.pageresources end
local setpageres = pdf.setpageresources or function(s) pdf.pageresources = s end
local pgf = { bye = "pgfutil@everybye", extgs = "\\pgf@sys@addpdfresource@extgs@plain" }

local function ischo (c)
  return ( c >= 0x1100 and c <= 0x115F )
  or     ( c >= 0xA960 and c <= 0xA97C )
end

local function isjung (c)
  return ( c >= 0x1160 and c <= 0x11A7 )
  or     ( c >= 0xD7B0 and c <= 0xD7C6 )
end

local function isjong (c)
  return ( c >= 0x11A8 and c <= 0x11FF )
  or     ( c >= 0xD7CB and c <= 0xD7FB )
end

local function get_trans_node (data)
  if newcolorstack and data and not transstack then
    transstack = newcolorstack("/TransGs1 gs","direct",true)
  end
  local tr_node
  data = data and sprintf("/TransGs%s gs", data)
  if transstack then
    tr_node = data and nodecopy(push_color) or nodecopy(pop_color)
    tr_node.stack = transstack
    tr_node.data  = data or nil
  else
    tr_node       = nodenew("whatsit","pdf_literal")
    tr_node.mode  = 2
    tr_node.data  = data or "/TransGs1 gs"
  end
  return tr_node
end

local function trans_on_off (head, curr, on)
  local trans = has_attribute(curr, colortransattr)
  if trans == 0xFF then
    return head
  elseif on then
    trans = sprintf("%.3g", trans / 0xFF)
    res_t = res_t or { }
    res_t[trans] = true
    return insert_before(head, curr, get_trans_node(trans))
  else
    insert_after(head, curr, get_trans_node())
  end
end

local function color_on_off (head, curr, color, jamo)
  if jamo == 1 then
    head = trans_on_off(head, curr, true)
  elseif jamo == 3 then
    trans_on_off(head, curr)
    insert_after(head, curr, nodecopy(pop_color))
  end
  local t = {}
  for s in sprintf("%06x",color):gmatch("%x%x") do
    t[#t+1] = sprintf("%.3g", tonumber(s, 16) / 0xFF)
  end
  local colornode = jamo == 1 and nodecopy(push_color) or nodecopy(set_color)
  colornode.data = sprintf("%s %s %s rg", t[1], t[2], t[3])
  return insert_before(head, curr, colornode)
end

local function do_color_jamo (head, groupcode)
  for curr in traverse(head) do
    if curr.id == hlist or curr.id == vlist then
      curr.head = do_color_jamo(curr.head)
    elseif curr.id == glyph and has_attribute(curr, colorjamoattr) then
      local uni = has_attribute(curr, unicodeattr)
      if ischo(uni) then
        head = color_on_off(head, curr, has_attribute(curr, colorchoattr), 1)
      elseif isjung(uni) then
        local nn = curr.next
        if nn and nn.id == glyph and isjong(has_attribute(nn, unicodeattr)) then
          color_on_off(head, curr, has_attribute(curr, colorjungattr), 2)
        else
          color_on_off(head, curr, has_attribute(curr, colorjungattr), 3)
        end
      elseif isjong(uni) then
        color_on_off(head, curr, has_attribute(curr, colorjongattr), 3)
      end
    end
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

addtocallback("pre_output_filter", do_color_jamo, "colorjamo.preoutputfilter")

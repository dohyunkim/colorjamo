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
local traverse      = node.traverse
local has_attribute = node.has_attribute
local insert_before = node.insert_before
local insert_after  = node.insert_after
local addtocallback = luatexbase.add_to_callback

local push_color    = node.new("whatsit","pdf_colorstack")
push_color.stack    = 0
push_color.command  = 1
local pop_color     = nodecopy(push_color)
pop_color.command   = 2

local push_trans, pop_trans
local transstack    = pdf.newcolorstack and pdf.newcolorstack("/TransGs1 gs","direct",true)
if transstack then
  push_trans        = nodecopy(push_color)
  push_trans.stack  = transstack
  pop_trans         = nodecopy(pop_color)
  pop_trans.stack   = transstack
else
  push_trans        = node.new("whatsit","pdf_literal")
  push_trans.mode   = 2
  pop_trans         = nodecopy(push_trans)
  pop_trans.data    = "/TransGs1 gs"
end

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

local res_t
local atletter = luatexbase.registernumber("catcodetable@atletter")
local sprintf, concat   = string.format, table.concat
local gettoks, scantoks = tex.gettoks, tex.scantoks
local getpageres = pdf.getpageresources or function() return pdf.pageresources end
local setpageres = pdf.setpageresources or function(s) pdf.pageresources = s end
local pgf = { bye = "pgfutil@everybye", extgs = "\\pgf@sys@addpdfresource@extgs@plain" }

local function to_colordata (color, trans)
  local t = {}
  for s in sprintf("%06x",color):gmatch("%x%x") do
    t[#t+1] = sprintf("%.3g", tonumber(s, 16) / 0xFF)
  end
  if trans == 0xFF then
    return sprintf("%s %s %s rg", t[1], t[2], t[3])
  else
    trans = sprintf("%.3g", trans / 0xFF)
    res_t = res_t or { }
    res_t[trans] = true
    return sprintf("%s %s %s rg", t[1], t[2], t[3]), sprintf("/TransGs%s gs", trans)
  end
end

local function do_color_jamo (head, groupcode)
  for curr in traverse(head) do
    if curr.id == hlist or curr.id == vlist then
      curr.head = do_color_jamo(curr.head)
    elseif curr.id == glyph and has_attribute(curr, colorjamoattr) then
      local uni = has_attribute(curr, unicodeattr)
      if ischo(uni) or isjung(uni) or isjong(uni) then
        local colorstart = nodecopy(push_color)
        local colorstop  = nodecopy(pop_color)
        local color, trans
        if ischo(uni) then
          color = has_attribute(curr, colorchoattr)
        elseif isjung(uni) then
          color = has_attribute(curr, colorjungattr)
        else
          color = has_attribute(curr, colorjongattr)
        end
        colorstart.data, trans = to_colordata(color, has_attribute(curr, colortransattr))
        head = insert_before(head, curr, colorstart)
        insert_after (head, curr, colorstop)
        -- >> transparency
        if trans then
          local transstart = nodecopy(push_trans)
          transstart.data  = trans
          insert_before(head, curr, transstart)
          insert_after(head, curr, nodecopy(pop_trans))
        end
        -- << transparency
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

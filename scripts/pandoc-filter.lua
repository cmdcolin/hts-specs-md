-- Pandoc filter to handle hts-specs custom LaTeX commands

local commit = "unknown"
local date = "unknown"

function get_vars(meta)
  if meta.commit then
    commit = pandoc.utils.stringify(meta.commit)
  end
  if meta.date then
    date = pandoc.utils.stringify(meta.date)
  end
end

function RawInline(el)
  if el.format == "tex" then
    if el.text == "\\commitdesc" then
      return pandoc.Str(commit)
    elseif el.text == "\\headdate" then
      return pandoc.Str(date)
    end
    
    local cclass = el.text:match("\\cclass{(.-)}")
    if cclass then
      return pandoc.Str(":" .. cclass .. ":")
    end
    
    local cigar = el.text:match("\\cigarops{(.-)}")
    if cigar then
      local parts = {}
      for i = 1, #cigar do
        table.insert(parts, cigar:sub(i,i))
      end
      return pandoc.Str(table.concat(parts, "/"))
    end
    
    if el.text == "\\caret" then
      return pandoc.Str("^")
    end
    
    if el.text == "\\memlimited" then
        return pandoc.Emph({pandoc.Str("limited")})
    end
  end
end

-- Handle tt in a way that pandoc understands
function Inline(el)
  if el.tag == "RawInline" and el.format == "tex" then
    local content = el.text:match("\\tt%s+(.*)$")
    if content then
      return pandoc.Code(content)
    end
  end
  return el
end

function Div(el)
  if el.classes:includes("framed") then
    -- Convert to a div with a specific class for Jekyll/kramdown
    -- or just a blockquote
    return pandoc.BlockQuote(el.content)
  end
end

-- Pandoc 3.x uses meta to pass metadata
return {
  { Meta = get_vars },
  { RawInline = RawInline, Inline = Inline, Div = Div }
}

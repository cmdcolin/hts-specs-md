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
    
    local fb_a1, fb_a2 = el.text:match("\\firstbytebox{(.-)}{(.-)}")
    if fb_a1 and fb_a2 then
        -- Try to clean the label (e.g. \tt s)
        local label = fb_a2:gsub("\\tt%s+", "")
        return pandoc.Str("[" .. label .. "]")
    end
    
    local b_a1, b_a2 = el.text:match("\\bytebox{(.-)}{(.-)}")
    if b_a1 and b_a2 then
        local label = b_a2:gsub("\\tt%s+", "")
        return pandoc.Str("[" .. label .. "]")
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

-- Handle Code spans (inline code)
function Code(el)
  if el.text:match("%$.*%$") then
    local result = {}
    local last_pos = 1
    for start_pos, content, end_pos in el.text:gmatch("()%$([^%$]+)%$()") do
        if start_pos > last_pos then
            table.insert(result, pandoc.Code(el.text:sub(last_pos, start_pos - 1)))
        end
        table.insert(result, pandoc.Math("InlineMath", content))
        last_pos = end_pos
    end
    if last_pos <= #el.text then
        table.insert(result, pandoc.Code(el.text:sub(last_pos)))
    end
    return result
  end
  return el
end

-- Handle CodeBlock (block code)
function CodeBlock(el)
  -- If it contains $...$, we'll try to split and render math
  if el.text:match("%$.*%$") then
    local lines = {}
    -- Split by \n
    local i = 1
    for line in el.text:gmatch("([^\n]*)\n?") do
      local line_content = {}
      local last_pos = 1
      for start_pos, content, end_pos in line:gmatch("()%$([^%$]+)%$()") do
        if start_pos > last_pos then
            -- Use Span with a class instead of Code to avoid background/padding on parts
            table.insert(line_content, pandoc.Span(line:sub(last_pos, start_pos - 1), {class="code-text"}))
        end
        table.insert(line_content, pandoc.Math("InlineMath", content))
        last_pos = end_pos
      end
      if last_pos <= #line then
        table.insert(line_content, pandoc.Span(line:sub(last_pos), {class="code-text"}))
      end
      
      -- Add a manual line break except for the last line
      table.insert(lines, pandoc.Plain(line_content))
    end
    return pandoc.Div(lines, {class="code-math-block"})
  end
  return el
end

-- Pandoc 3.x uses meta to pass metadata
return {
  { Meta = get_vars },
  { RawInline = RawInline, Inline = Inline, Div = Div, Code = Code, CodeBlock = CodeBlock }
}

-- Pandoc filter to handle hts-specs custom LaTeX commands, section numbering, and HTML tables

local commit = "unknown"
local date = "unknown"

-- Counters for section numbering
local section_counters = {0, 0, 0, 0, 0, 0}

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
  -- Remove samepage class which is internal PDF stuff and causes fenced divs output
  if el.classes:includes("samepage") then
    return el.content
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

function CodeBlock(el)
  -- ONLY apply the code-math-block logic if there is actually a $ in the text
  if el.text:match("%$.*%$") then
    local all_content = {}
    
    local lines = {}
    local start = 1
    while true do
        local nl = el.text:find("\n", start)
        if nl then
            table.insert(lines, el.text:sub(start, nl-1))
            start = nl + 1
        else
            table.insert(lines, el.text:sub(start))
            break
        end
    end

    local NBSP = "\u{00A0}"
    for i, line in ipairs(lines) do
      local last_pos = 1
      for start_pos, content, end_pos in line:gmatch("()%$([^%$]+)%$()") do
        if start_pos > last_pos then
            local text = line:sub(last_pos, start_pos - 1)
            if last_pos == 1 then
                local spaces = text:match("^( +)")
                if spaces then
                    table.insert(all_content, pandoc.Str(spaces:gsub(" ", NBSP)))
                    text = text:sub(#spaces + 1)
                end
            end
            if #text > 0 then
                table.insert(all_content, pandoc.Str(text))
            end
        end
        table.insert(all_content, pandoc.Math("InlineMath", content))
        last_pos = end_pos
      end
      if last_pos <= #line then
        local text = line:sub(last_pos)
        if last_pos == 1 then
            local spaces = text:match("^( +)")
            if spaces then
                table.insert(all_content, pandoc.Str(spaces:gsub(" ", NBSP)))
                text = text:sub(#spaces + 1)
            end
        end
        if #text > 0 then
            table.insert(all_content, pandoc.Str(text))
        end
      end
      
      if i < #lines then
        table.insert(all_content, pandoc.LineBreak())
      end
    end
    
    -- Use raw HTML for the div to avoid fenced divs syntax
    return {
      pandoc.RawBlock('html', '<div class="code-math-block">'),
      pandoc.Para(all_content),
      pandoc.RawBlock('html', '</div>')
    }
  end
  return el
end

-- Convert Pandoc AST elements to HTML string
local function to_html(content)
  return pandoc.utils.stringify(pandoc.write(pandoc.Pandoc({pandoc.Para(content)}), 'html'))
end

-- More precise conversion that preserves math and code tags
local function blocks_to_html(blocks)
  local doc = pandoc.Pandoc(blocks)
  local html = pandoc.write(doc, 'html')
  -- Strip the surrounding paragraph tags if it's just one para
  if #blocks == 1 and blocks[1].t == "Para" then
    html = html:gsub("^<p>", ""):gsub("</p>%s*$", "")
  end
  return html
end

function Table(el)
  local header = el.head.rows[1]
  local is_empty_header = true
  if header then
    for _, cell in ipairs(header.cells) do
      if #cell.contents > 0 then
        is_empty_header = false
        break
      end
    end
  else
    is_empty_header = true
  end

  if is_empty_header then
    local body = el.bodies[1]
    if body and #body.body > 0 then
      local first_row = body.body[1]
      el.head.rows = {first_row}
      table.remove(body.body, 1)
    end
  end

  -- Build HTML table
  local html = {"<table>"}
  
  -- Header
  if #el.head.rows > 0 then
    table.insert(html, "<thead>")
    for _, row in ipairs(el.head.rows) do
      table.insert(html, "<tr>")
      for _, cell in ipairs(row.cells) do
        table.insert(html, "<th>" .. blocks_to_html(cell.contents) .. "</th>")
      end
      table.insert(html, "</tr>")
    end
    table.insert(html, "</thead>")
  end
  
  -- Body
  table.insert(html, "<tbody>")
  for _, body in ipairs(el.bodies) do
    for _, row in ipairs(body.body) do
      table.insert(html, "<tr>")
      for _, cell in ipairs(row.cells) do
        table.insert(html, "<td>" .. blocks_to_html(cell.contents) .. "</td>")
      end
      table.insert(html, "</tr>")
    end
  end
  table.insert(html, "</tbody>")
  table.insert(html, "</table>")
  
  return pandoc.RawBlock('html', table.concat(html, "\n"))
end

function Math(el)
  if el.mathtype == "InlineMath" then
    -- Handle special case for < and > which are often written as math in LaTeX
    if el.text == "<" or el.text == ">" then
      return pandoc.Str(el.text)
    end

    -- Convert all-caps math of length 2 or more to code literals `CIPOS`
    -- This handles field names like $CIPOS$ and also assignments like $CIPOS=-5,5,0,0$ or $GT=0/1$
    -- We allow uppercase, underscores, digits, and common assignment/list punctuation.
    -- Length >= 2 ensures single letters like $P$ or $N$ remain as variables in italics (math).
    if el.text:match("^[A-Z][A-Z_0-9=,%. %/-]*[A-Z_0-9=,%. %/-]$") then
      return pandoc.Code(el.text)
    end
  end
  return el
end

function Header(el)
  -- Update section numbering
  local level = el.level
  section_counters[level] = section_counters[level] + 1
  for i = level + 1, #section_counters do
    section_counters[i] = 0
  end
  
  local num_parts = {}
  for i = 1, level do
    table.insert(num_parts, tostring(section_counters[i]))
  end
  local section_num = table.concat(num_parts, ".")
  
  -- Prepend section number to header content
  table.insert(el.content, 1, pandoc.Str(section_num .. " "))

  if el.identifier ~= "" then
    -- Return a list with a raw HTML anchor block and the header
    -- This ensures the anchor is OUTSIDE the header text, so it doesn't affect TOC text
    local anchor = pandoc.RawBlock('html', '<a id="' .. el.identifier .. '"></a>')
    return { anchor, el }
  end
  return el
end

function Link(el)
  -- Strip all attributes to avoid raw HTML output with data-reference-type
  el.attributes = {}
  return el
end

-- Pandoc 3.x uses meta to pass metadata
return {
  { Meta = get_vars },
  { RawInline = RawInline, Inline = Inline, Div = Div, Code = Code, CodeBlock = CodeBlock, Table = Table, Math = Math, Header = Header, Link = Link }
}

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

-- More precise conversion that preserves math and code tags
local mathml_opts = pandoc.WriterOptions({html_math_method = "mathml"})

local function blocks_to_html(blocks)
  local doc = pandoc.Pandoc(blocks)
  local html = pandoc.write(doc, 'html', mathml_opts)
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

  -- Determine the actual maximum number of columns that have content in at least one row
  local actual_max_cols = 0
  local function get_last_non_empty_cell_index(row)
    local last = 0
    for i, cell in ipairs(row.cells) do
      -- Check if cell has any content (Blocks)
      if #cell.contents > 0 then
        -- Further check if it's just a Plain/Para with empty content
        local has_content = false
        for _, block in ipairs(cell.contents) do
          if block.t == "Plain" or block.t == "Para" then
            if #block.content > 0 then has_content = true break end
          else
            has_content = true break
          end
        end
        if has_content then
          last = i
        end
      end
    end
    return last
  end

  for _, row in ipairs(el.head.rows) do
    actual_max_cols = math.max(actual_max_cols, get_last_non_empty_cell_index(row))
  end
  for _, body in ipairs(el.bodies) do
    for _, row in ipairs(body.body) do
      actual_max_cols = math.max(actual_max_cols, get_last_non_empty_cell_index(row))
    end
  end

  -- If for some reason everything is empty, fallback to at least one column
  if actual_max_cols == 0 and #el.colspecs > 0 then
    actual_max_cols = #el.colspecs
  end

  -- Build HTML table
  local html = {"<table>"}
  
  -- Header
  if #el.head.rows > 0 then
    table.insert(html, "<thead>")
    for _, row in ipairs(el.head.rows) do
      table.insert(html, "<tr>")
      for i = 1, actual_max_cols do
        local cell = row.cells[i]
        if cell then
          table.insert(html, "<th>" .. blocks_to_html(cell.contents) .. "</th>")
        else
          table.insert(html, "<th></th>")
        end
      end
      table.insert(html, "</tr>")
    end
    table.insert(html, "</thead>")
  end
  
  -- Body (skip rows where all cells are empty)
  table.insert(html, "<tbody>")
  for _, body in ipairs(el.bodies) do
    for _, row in ipairs(body.body) do
      if get_last_non_empty_cell_index(row) > 0 then
        table.insert(html, "<tr>")
        for i = 1, actual_max_cols do
          local cell = row.cells[i]
          if cell then
            table.insert(html, "<td>" .. blocks_to_html(cell.contents) .. "</td>")
          else
            table.insert(html, "<td></td>")
          end
        end
        table.insert(html, "</tr>")
      end
    end
  end
  table.insert(html, "</tbody>")
  table.insert(html, "</table>")
  
  return pandoc.RawBlock('html', table.concat(html, "\n"))
end

-- Simplify custom hts-specs LaTeX operators into standard LaTeX/text
local function simplify_math_text(text)
  -- Preserve \% (escaped percent/modulo) before stripping comments
  text = text:gsub("\\%%", "\0PCTESC\0")
  text = text:gsub("%%[^\n]*\n%s*", " ")
  text = text:gsub("%%[^\n]*$", "")
  text = text:gsub("\0PCTESC\0", "\\%%")

  -- Remove hts-specs custom spacing: \nonscript\mskip-\medmuskip[\mkern 5mu]
  text = text:gsub("\\nonscript\\mskip%-\\medmuskip\\mkern%s*5mu", " ")
  text = text:gsub("\\nonscript\\mskip%-\\medmuskip", " ")
  text = text:gsub("\\penalty%s*%d+\\mkern%s*5mu", " ")

  -- Replace custom operator macros with standard LaTeX
  text = text:gsub("\\mathbin{\\operator@font%s+\\textbf{(%w+)}}", " \\textbf{%1} ")
  text = text:gsub("\\mathbin{\\operator@font%s+(%w+)}", " \\text{%1} ")
  text = text:gsub("\\mathbin{<[^}]*}", "\\ll ")
  text = text:gsub("\\mathbin{>[^}]*}", "\\gg ")
  text = text:gsub("\\mathbin{%+[^}]*}", "\\mathbin{++}")

  -- Replace unsupported font/layout commands with pandoc-compatible equivalents
  text = text:gsub("\\underline{([^}]*)}", "%1")
  text = text:gsub("\\mbox{([^}]*)}", "%1")
  text = text:gsub("{\\sf%s+([^}]*)}", "\\mathsf{%1}")
  text = text:gsub("\\sf%s+([%w_]+)", "\\mathsf{%1}")

  -- Normalize whitespace
  text = text:gsub("%s+", " ")
  text = text:gsub("^%s+", ""):gsub("%s+$", "")
  return text
end

function Math(el)
  el.text = simplify_math_text(el.text)

  if el.mathtype == "InlineMath" then
    if el.text == "<" or el.text == ">" then
      return pandoc.Str(el.text)
    end

    if el.text:match("^%d+$") then
      return pandoc.Str(el.text)
    end

    -- Convert all-caps field names like $CIPOS$ to code literals
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

  return el
end

function Link(el)
  el.attributes = {}
  return el
end

-- Pandoc 3.x uses meta to pass metadata
return {
  { Meta = get_vars },
  { RawInline = RawInline, Inline = Inline, Div = Div, Code = Code, CodeBlock = CodeBlock, Table = Table, Math = Math, Header = Header, Link = Link }
}

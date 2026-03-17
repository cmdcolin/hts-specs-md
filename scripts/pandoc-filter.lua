-- Pandoc filter to handle hts-specs custom LaTeX commands, section numbering, and HTML tables

local commit = "unknown"
local date = "unknown"

-- Counters for section numbering
local section_counters = {0, 0, 0, 0, 0, 0}

-- Map from LaTeX label to section number string (built in scan pass)
local label_to_section = {}
local scan_counters = {0, 0, 0, 0, 0, 0}

local function scan_header(el)
  local level = el.level
  scan_counters[level] = scan_counters[level] + 1
  for i = level + 1, #scan_counters do
    scan_counters[i] = 0
  end
  local num_parts = {}
  for i = 1, level do
    table.insert(num_parts, tostring(scan_counters[i]))
  end
  local section_num = table.concat(num_parts, ".")
  if el.identifier and el.identifier ~= "" then
    label_to_section[el.identifier] = section_num
  end
end

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

  -- Replace CRAMcodecs custom math operator macros with KaTeX-compatible equivalents
  text = text:gsub("\\shiftl", "\\mathbin{\\text{<<}}")
  text = text:gsub("\\shiftr", "\\mathbin{\\text{>>}}")
  text = text:gsub("\\bitand", "\\mathbin{\\&}")
  text = text:gsub("\\bitor",  "\\mathbin{\\text{OR}}")
  text = text:gsub("\\bitxor", "\\mathbin{\\text{XOR}}")
  text = text:gsub("\\logor",  "\\text{ \\textbf{or} }")
  text = text:gsub("\\logand", "\\text{ \\textbf{and} }")
  -- \concat is replaced in tex2md.py before pandoc expands the macro

  -- Replace custom operator macros with standard LaTeX
  text = text:gsub("\\mathbin{\\operator@font%s+\\textbf{(%w+)}}", "\\mathbin{\\textbf{%1}}")
  text = text:gsub("\\mathbin{\\operator@font%s+(%w+)}", "\\mathbin{\\text{%1}}")
  text = text:gsub("\\mathbin{<[^}]*}", "\\ll ")
  text = text:gsub("\\mathbin{>[^}]*}", "\\gg ")
  text = text:gsub("\\mathbin{%+[^}]*}", "\\mathbin{++}")

  -- Replace hex literals in \mathtt with monospace text
  text = text:gsub("\\mathtt{(0x[0-9a-fA-F]+)}", "\\texttt{%1}")

  -- Wrap multi-character identifiers with escaped underscores (e.g. cfreq\_to\_sym)
  -- in \mathit{} so they render as connected names instead of separate variables.
  local function wrap_underscore_idents(t)
    local result = {}
    local i = 1
    while i <= #t do
      -- Try to match: 2+ letters followed by \_ and more letters
      local s, e, m = t:find("(%a%a+\\_%a+)", i)
      if s then
        table.insert(result, t:sub(i, s - 1))
        -- Extend match to consume additional \_word segments
        while e < #t do
          local ns, ne = t:find("^\\_%a+", e + 1)
          if ns then
            m = m .. t:sub(ns, ne)
            e = ne
          else
            break
          end
        end
        table.insert(result, "\\textit{" .. m .. "}")
        i = e + 1
      else
        table.insert(result, t:sub(i))
        break
      end
    end
    return table.concat(result)
  end
  text = wrap_underscore_idents(text)

  -- Wrap bare multi-letter lowercase identifiers (3+ chars) in \mathit{} so they
  -- render as connected names (e.g. freq, cfreq, nsym) instead of spaced variables.
  -- Process from left to right, skipping LaTeX commands and brace-group contents
  -- of text-mode commands (\text{}, \textbf{}, \texttt{}, \mathit{}, etc.)
  local function wrap_bare_idents(t)
    local out = {}
    local i = 1
    local text_cmds = {
      text = true, textrm = true, textbf = true, textit = true, texttt = true,
      textsc = true, mathit = true, mathsf = true, mathrm = true, mathtt = true,
      mathbb = true, mathcal = true, mathbin = true,
      begin = true, ["end"] = true,
    }
    while i <= #t do
      if t:sub(i, i) == "\\" then
        -- LaTeX command: copy command name
        local cmd_start = i
        i = i + 1
        local cmd = t:match("^(%a+)", i)
        if cmd then
          i = i + #cmd
          table.insert(out, t:sub(cmd_start, i - 1))
          -- If it's a text-mode command, copy its brace group verbatim
          if text_cmds[cmd] and i <= #t and t:sub(i, i) == "{" then
            local depth = 0
            local j = i
            while j <= #t do
              if t:sub(j, j) == "{" then depth = depth + 1
              elseif t:sub(j, j) == "}" then
                depth = depth - 1
                if depth == 0 then break end
              end
              j = j + 1
            end
            table.insert(out, t:sub(i, j))
            i = j + 1
          end
        else
          -- Non-alpha after \, copy one char (e.g. \%, \\, \_)
          table.insert(out, t:sub(cmd_start, i))
          i = i + 1
        end
      else
        local word = t:match("^(%a%a%a+)", i)
        if word then
          table.insert(out, "\\textit{" .. word .. "}")
          i = i + #word
        else
          table.insert(out, t:sub(i, i))
          i = i + 1
        end
      end
    end
    return table.concat(out)
  end
  text = wrap_bare_idents(text)

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

local function math_to_text(text)
  text = simplify_math_text(text)
  -- Operators
  text = text:gsub("\\gets", " \xe2\x86\x90 ")   -- ←
  text = text:gsub("\\ne%f[^%a]",  " \xe2\x89\xa0 ")  -- ≠
  text = text:gsub("\\neq%f[^%a]", " \xe2\x89\xa0 ")
  text = text:gsub("\\le%f[^%a]",  " \xe2\x89\xa4 ")  -- ≤
  text = text:gsub("\\leq%f[^%a]", " \xe2\x89\xa4 ")
  text = text:gsub("\\ge%f[^%a]",  " \xe2\x89\xa5 ")  -- ≥
  text = text:gsub("\\geq%f[^%a]", " \xe2\x89\xa5 ")
  text = text:gsub("\\lfloor", "\xe2\x8c\x8a")   -- ⌊
  text = text:gsub("\\rfloor", "\xe2\x8c\x8b")   -- ⌋
  text = text:gsub("\\lceil",  "\xe2\x8c\x88")   -- ⌈
  text = text:gsub("\\rceil",  "\xe2\x8c\x89")   -- ⌉
  text = text:gsub("\\times%f[^%a]", " * ")
  text = text:gsub("\\bmod%f[^%a]",  " mod ")
  text = text:gsub("\\bdiv%f[^%a]",  " div ")
  -- Expanded mathbin operators (from simplify_math_text)
  text = text:gsub("\\mathbin{\\text{<<}}", " << ")
  text = text:gsub("\\mathbin{\\text{>>}}", " >> ")
  text = text:gsub("\\mathbin{\\&}", " & ")
  text = text:gsub("\\mathbin{\\text{OR}}",  " OR ")
  text = text:gsub("\\mathbin{\\text{XOR}}", " XOR ")
  text = text:gsub("\\mathbin{\\text{AND}}", " AND ")
  text = text:gsub("\\text{ \\textbf{or} }",  " or ")
  text = text:gsub("\\text{ \\textbf{and} }", " and ")
  text = text:gsub("\\mathbin{%+%+}", "++")
  text = text:gsub("\\text{%+%+}", "++")
  text = text:gsub("\\mathbin{[^{}]*}", " ")
  -- Font commands: strip wrapper, keep content
  text = text:gsub("\\mathtt{([^}]*)}", "%1")
  text = text:gsub("\\mathrm{([^}]*)}", "%1")
  text = text:gsub("\\mathsf{([^}]*)}", "%1")
  text = text:gsub("\\textit{([^}]*)}", "%1")
  text = text:gsub("\\text{([^}]*)}", "%1")
  text = text:gsub("\\textbf{([^}]*)}", "%1")
  text = text:gsub("\\texttt{([^}]*)}", "%1")
  text = text:gsub("\\textsc{([^}]*)}", "%1")
  -- Escaped underscore (\_) and other special chars in math → literal
  text = text:gsub("\\_", "_")
  -- Common symbols
  text = text:gsub("\\ldots", "\xe2\x80\xa6")   -- …
  text = text:gsub("\\cdots", "\xe2\x80\xa6")   -- …
  text = text:gsub("\\cdot%f[^%a]", "\xc2\xb7") -- ·
  text = text:gsub("\\sum", "\xe2\x88\x91")      -- ∑
  -- Binomial coefficient: {n \choose k} → C(n, k)
  text = text:gsub("{([^}]-) \\choose ([^}]-)}", "C(%1, %2)")
  -- Subscripts / superscripts
  text = text:gsub("_{([^}]*)}", "_%1")
  text = text:gsub("%^{([^}]*)}", "^%1")
  -- Remove remaining \commands and stray braces
  text = text:gsub("\\%a+%s*{([^}]*)}", "%1")
  text = text:gsub("\\%a+%s*", "")
  text = text:gsub("[{}]", "")
  -- Collapse multiple spaces
  text = text:gsub(" +", " "):gsub("^ ", ""):gsub(" $", "")
  return text
end

function CodeBlock(el)
  local has_math = el.text:match("%$.*%$")
  local has_latex = el.text:match("\\%a+{")
  if not has_math and not has_latex then
    return el
  end
  local result_lines = {}
  for line in (el.text .. "\n"):gmatch("([^\n]*)\n") do
    -- Convert $...$ math to plain text
    local result = line:gsub("%$([^%$]+)%$", function(m)
      return math_to_text(m)
    end)
    -- Convert LaTeX font commands to plain text in pseudocode
    result = result:gsub("\\textsc{([^}]*)}", "%1")
    result = result:gsub("\\textit{([^}]*)}", "%1")
    result = result:gsub("\\textbf{([^}]*)}", "%1")
    result = result:gsub("\\texttt{([^}]*)}", "%1")
    -- Ensure space after assignment arrow
    result = result:gsub("\xe2\x86\x90([^ \n])", "\xe2\x86\x90 %1")
    -- Strip LaTeX spacing/special commands outside math
    result = result:gsub("\\ ", " ")
    result = result:gsub("\\,", " ")
    result = result:gsub("\\;", " ")
    result = result:gsub("\\!", "")
    result = result:gsub("\\quad%s*", "  ")
    result = result:gsub("\\_", "_")   -- escaped underscore in text mode
    -- Strip \Comment{...} or \Comment(...) that survived algorithmic conversion
    result = result:gsub("\\Comment{[^}]*}", "")
    result = result:gsub("\\Comment%([^)]*%)", "")
    -- HTML-escape for safe embedding in <pre><code>
    result = result:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
    table.insert(result_lines, result)
  end
  -- Strip trailing empty lines and collapse runs of 2+ blank lines to 1
  while #result_lines > 0 and result_lines[#result_lines]:match("^%s*$") do
    table.remove(result_lines)
  end
  local compacted = {}
  local prev_blank = false
  for _, l in ipairs(result_lines) do
    local is_blank = l:match("^%s*$") ~= nil
    if not (is_blank and prev_blank) then
      table.insert(compacted, l)
    end
    prev_blank = is_blank
  end
  return pandoc.RawBlock('html', '<pre><code>' .. table.concat(compacted, '\n') .. '</code></pre>')
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

-- threeparttable: embed tablenotes as <tfoot> inside the preceding table
-- Must be defined after blocks_to_html
function Div(el)
  if el.classes:includes("framed") then
    return pandoc.BlockQuote(el.content)
  end
  if el.classes:includes("samepage") then
    return el.content
  end
  if el.classes:includes("threeparttable") then
    local result = {}
    local pending_idx = nil
    for _, block in ipairs(el.content) do
      if block.t == "RawBlock" and block.format == "html" and block.text:find("</table>") then
        table.insert(result, block)
        pending_idx = #result
      elseif block.t == "Div" and block.classes:includes("tablenotes") and pending_idx then
        local notes_html = blocks_to_html(block.content)
        local old = result[pending_idx].text
        local new_table = old:gsub("</table>%s*$",
          "\n<tfoot class=\"tablenotes\"><tr><td colspan=\"100\">" .. notes_html .. "</td></tr></tfoot>\n</table>")
        result[pending_idx] = pandoc.RawBlock('html', new_table)
        pending_idx = nil
      else
        pending_idx = nil
        table.insert(result, block)
      end
    end
    return result
  end
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

  -- Merge continuation rows (first cell empty) into the previous row's last cell.
  -- This handles LaTeX tables where a description spans multiple rows.
  local function is_first_cell_empty(row)
    if not row.cells[1] then return true end
    return get_last_non_empty_cell_index({cells = {row.cells[1]}}) == 0
  end

  for _, body in ipairs(el.bodies) do
    local merged = {}
    for _, row in ipairs(body.body) do
      if #merged > 0 and is_first_cell_empty(row) and get_last_non_empty_cell_index(row) > 0 then
        local prev = merged[#merged]
        for i = 2, actual_max_cols do
          if row.cells[i] and #row.cells[i].contents > 0 then
            for _, block in ipairs(row.cells[i].contents) do
              table.insert(prev.cells[i].contents, block)
            end
          end
        end
      else
        table.insert(merged, row)
      end
    end
    body.body = merged
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
  if el.target:sub(1, 1) == "#" then
    local label = el.target:sub(2)
    local section = label_to_section[label]
    if section then
      el.target = "#" .. section
    end
  end
  return el
end

-- Pandoc represents {\textbackslash} inside \texttt{} as Span([Code('\')]) with no
-- classes or attributes. This helper unwraps such bare Spans to a plain Code element
-- so adjacent Code spans can be merged.
local function unwrap_span_code(el)
  if el.tag == "Span" and #el.content == 1 and el.content[1].tag == "Code"
     and el.attr.identifier == "" and #el.attr.classes == 0 and #el.attr.attributes == 0 then
    return el.content[1]
  end
  return el
end

-- Merge adjacent Code spans that have no space between them.
-- This fixes pandoc splitting \texttt{{\textbackslash}x20} into `\``x20`
-- instead of the correct single span `\x20`.
function Inlines(ils)
  local result = {}
  local i = 1
  while i <= #ils do
    local cur = unwrap_span_code(ils[i])
    if cur.tag == "Code" then
      local merged = cur.text
      while i + 1 <= #ils do
        local nxt = unwrap_span_code(ils[i + 1])
        if nxt.tag ~= "Code" then break end
        i = i + 1
        merged = merged .. nxt.text
      end
      table.insert(result, pandoc.Code(merged))
    else
      table.insert(result, cur)
    end
    i = i + 1
  end
  return pandoc.Inlines(result)
end

-- Pandoc 3.x uses meta to pass metadata
return {
  { Meta = get_vars },
  { Header = scan_header },
  { Inlines = Inlines },
  { RawInline = RawInline, Inline = Inline, Div = Div, Code = Code, CodeBlock = CodeBlock, Table = Table, Math = Math, Header = Header, Link = Link },
}

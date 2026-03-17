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

  -- CRAMcodecs custom operators (\shiftl, \shiftr, \bitand, \bitor, \bitxor,
  -- \logor, \logand, \concat) are defined after \begin{document}, so pandoc
  -- expands them before the filter runs. Their expanded forms are caught by
  -- the fallback patterns below. \concat is replaced in tex2md.py.

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

  -- Helper: check if a cell has real content
  local function cell_has_content(cell)
    if not cell or #cell.contents == 0 then return false end
    for _, block in ipairs(cell.contents) do
      if block.t == "Plain" or block.t == "Para" then
        if #block.content > 0 then return true end
      else
        return true
      end
    end
    return false
  end

  -- Build logical column groups from header cell col_spans.
  -- E.g. header with cells [Bits(span=2), Type(span=1), Name(span=1), Desc(span=2)]
  -- produces col_groups = {{1,2}, {3,3}, {4,4}, {5,6}} and num_logical = 4.
  header = el.head.rows[1]
  local col_groups = {}   -- each: {from_phys, to_phys}
  local total_phys = #el.colspecs
  if header then
    local pos = 1
    for _, cell in ipairs(header.cells) do
      local span = cell.col_span or 1
      table.insert(col_groups, {pos, pos + span - 1})
      pos = pos + span
    end
  end
  local num_logical = #col_groups
  if num_logical == 0 then
    for i = 1, total_phys do
      table.insert(col_groups, {i, i})
    end
    num_logical = total_phys
  end

  -- Physical-to-logical column mapping
  local phys_to_logical = {}
  for li, group in ipairs(col_groups) do
    for p = group[1], group[2] do
      phys_to_logical[p] = li
    end
  end

  -- Map a row's cells to logical columns.
  -- Returns a list of num_logical entries: {contents=blocks, colspan=1, skip=false}
  -- For a full-width spanning row (e.g. section header), returns a single-entry list
  -- with colspan = num_logical.
  local function map_row_to_logical(row)
    local logical = {}
    for i = 1, num_logical do
      logical[i] = {contents = {}, colspan = 1, skip = false}
    end

    local phys = 1
    for _, cell in ipairs(row.cells) do
      local span = cell.col_span or 1
      local cell_from = phys
      local cell_to = phys + span - 1
      phys = phys + span

      local log_from = phys_to_logical[cell_from]
      local log_to = phys_to_logical[math.min(cell_to, total_phys)]
      if not log_from or not log_to then goto next_cell end

      if log_from == 1 and log_to == num_logical and cell_has_content(cell) then
        -- Full-width spanning row (section header)
        local result = {}
        for i = 1, num_logical do
          result[i] = {contents = {}, colspan = 1, skip = true}
        end
        result[1] = {contents = cell.contents, colspan = num_logical, skip = false}
        return result
      elseif log_from == log_to then
        -- Cell belongs to a single logical column: merge contents
        for _, block in ipairs(cell.contents) do
          table.insert(logical[log_from].contents, block)
        end
      else
        -- Cell spans multiple logical columns
        for _, block in ipairs(cell.contents) do
          table.insert(logical[log_from].contents, block)
        end
        logical[log_from].colspan = log_to - log_from + 1
        for li = log_from + 1, log_to do
          logical[li].skip = true
        end
      end

      ::next_cell::
    end

    return logical
  end

  -- Check if a logical row has any content
  local function logical_row_has_content(lcells)
    for _, lc in ipairs(lcells) do
      if not lc.skip and #lc.contents > 0 then
        if cell_has_content({contents = lc.contents}) then return true end
      end
    end
    return false
  end

  -- Determine the actual number of logical columns with content (trim trailing empty)
  local actual_logical = 0
  local function update_max_logical(lcells)
    for i = num_logical, 1, -1 do
      if not lcells[i].skip and cell_has_content({contents = lcells[i].contents}) then
        if i > actual_logical then actual_logical = i end
        return
      end
    end
  end

  for _, row in ipairs(el.head.rows) do
    update_max_logical(map_row_to_logical(row))
  end
  for _, body in ipairs(el.bodies) do
    for _, row in ipairs(body.body) do
      update_max_logical(map_row_to_logical(row))
    end
  end
  if actual_logical == 0 then actual_logical = num_logical end

  -- Merge continuation rows: if a row has empty first logical cell and content
  -- in only 1 other cell, merge it into the previous row (text overflow).
  for _, body in ipairs(el.bodies) do
    local merged = {}
    for _, row in ipairs(body.body) do
      local lcells = map_row_to_logical(row)
      if not logical_row_has_content(lcells) then goto skip_row end

      local first_empty = not cell_has_content({contents = lcells[1].contents})
      local content_count = 0
      for i = 2, actual_logical do
        if not lcells[i].skip and cell_has_content({contents = lcells[i].contents}) then
          content_count = content_count + 1
        end
      end

      if #merged > 0 and first_empty and content_count == 1 then
        local prev = merged[#merged]
        for i = 2, actual_logical do
          if not lcells[i].skip then
            for _, block in ipairs(lcells[i].contents) do
              table.insert(prev[i].contents, block)
            end
          end
        end
      else
        table.insert(merged, lcells)
      end

      ::skip_row::
    end
    body.body = merged
  end

  -- Build HTML table
  local html = {"<table>"}

  -- Header
  if #el.head.rows > 0 then
    table.insert(html, "<thead>")
    for _, row in ipairs(el.head.rows) do
      local lcells = map_row_to_logical(row)
      table.insert(html, "<tr>")
      for i = 1, actual_logical do
        local lc = lcells[i]
        if not lc.skip then
          local span_attr = ""
          if lc.colspan > 1 then
            -- Clamp colspan to not exceed remaining columns
            local effective = math.min(lc.colspan, actual_logical - i + 1)
            if effective > 1 then span_attr = ' colspan="' .. effective .. '"' end
          end
          table.insert(html, "<th" .. span_attr .. ">" .. blocks_to_html(lc.contents) .. "</th>")
        end
      end
      table.insert(html, "</tr>")
    end
    table.insert(html, "</thead>")
  end

  -- Body
  table.insert(html, "<tbody>")
  for _, body in ipairs(el.bodies) do
    for _, lcells in ipairs(body.body) do
      table.insert(html, "<tr>")
      for i = 1, actual_logical do
        local lc = lcells[i]
        if not lc.skip then
          local span_attr = ""
          if lc.colspan > 1 then
            local effective = math.min(lc.colspan, actual_logical - i + 1)
            if effective > 1 then span_attr = ' colspan="' .. effective .. '"' end
          end
          table.insert(html, "<td" .. span_attr .. ">" .. blocks_to_html(lc.contents) .. "</td>")
        end
      end
      table.insert(html, "</tr>")
    end
  end
  table.insert(html, "</tbody>")
  table.insert(html, "</table>")

  local result = table.concat(html, "\n")
  -- Strip empty <tbody></tbody> (from single-row header-only tables)
  result = result:gsub("\n<tbody>\n</tbody>", "")
  return pandoc.RawBlock('html', result)
end

-- Convert math expressions containing \textsf (which Pandoc's math writer
-- can't handle) into Pandoc inline elements so blocks_to_html() renders
-- them as regular HTML instead of broken MathML.
local function math_with_textsf_to_inlines(text)
  local result = {}
  local i = 1
  while i <= #text do
    local ts = text:find("\\textsf%s*{", i)
    if not ts then
      local rest = text:sub(i):gsub("^%s+", ""):gsub("%s+$", "")
      if #rest > 0 then
        -- Convert remaining simple math tokens to text
        rest = rest:gsub("\\textit{([^}]*)}", "%1")
        rest = rest:gsub("\\mathit{([^}]*)}", "%1")
        rest = rest:gsub("\\text{([^}]*)}", "%1")
        rest = rest:gsub("%-", "\xe2\x88\x92")
        table.insert(result, pandoc.Str(rest))
      end
      break
    end
    -- Text before \textsf
    if ts > i then
      local before = text:sub(i, ts - 1):gsub("^%s+", ""):gsub("%s+$", "")
      if #before > 0 then
        before = before:gsub("%-", "\xe2\x88\x92")
        table.insert(result, pandoc.Str(before))
      end
    end
    -- Find the balanced brace group after \textsf
    local brace_start = text:find("{", ts)
    local depth = 0
    local j = brace_start
    while j <= #text do
      if text:sub(j, j) == "{" then depth = depth + 1
      elseif text:sub(j, j) == "}" then
        depth = depth - 1
        if depth == 0 then break end
      end
      j = j + 1
    end
    local inner = text:sub(brace_start + 1, j - 1)
    -- Strip \textit{} wrapper if present
    inner = inner:gsub("^\\textit{(.*)}$", "%1")
    inner = inner:gsub("^\\mathit{(.*)}$", "%1")
    table.insert(result, pandoc.Span(
      {pandoc.Str(inner)},
      pandoc.Attr("", {"sans-serif"})
    ))
    i = j + 1
  end
  return result
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

    -- Convert math containing \textsf to inline elements since Pandoc's
    -- math writer can't handle \textsf and produces broken MathML
    if el.text:match("\\textsf") then
      return math_with_textsf_to_inlines(el.text)
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

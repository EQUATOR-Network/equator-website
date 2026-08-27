local function stringify(v)
  if v == nil then
    return ""
  end
  return pandoc.utils.stringify(v)
end

local function escape_html(text)
  return text
    :gsub("&", "&amp;")
    :gsub("<", "&lt;")
    :gsub(">", "&gt;")
end

local function parse_path(path)
  local tokens = {}
  local pos = 1

  while pos <= #path do
    local dot_start, dot_end, dot_part = string.find(path, "([^.[]+)", pos)
    if dot_start ~= nil then
      table.insert(tokens, { kind = "key", value = dot_part })
      pos = dot_end + 1
    else
      break
    end

    while string.sub(path, pos, pos) == "[" do
      local b_start, b_end, b_value = string.find(path, "^%[(%d+)%]", pos)
      if b_start == nil then
        break
      end
      -- Users think in zero-based indexes; Lua tables are one-based.
      table.insert(tokens, { kind = "index", value = tonumber(b_value) + 1 })
      pos = b_end + 1
    end

    if string.sub(path, pos, pos) == "." then
      pos = pos + 1
    end
  end

  return tokens
end

local function resolve_path(meta, path)
  local value = meta
  local tokens = parse_path(path)

  for _, token in ipairs(tokens) do
    if value == nil then
      return nil
    end

    if token.kind == "key" then
      value = value[token.value]
    else
      value = value[token.value]
    end
  end

  return value
end

local function meta_list_items(value)
  if value == nil then
    return {}
  end

  local t = pandoc.utils.type(value)

  if t == "MetaList" then
    local out = {}
    for _, item in ipairs(value) do
      local s = stringify(item)
      if s ~= "" then
        table.insert(out, s)
      end
    end
    return out
  end

  if t == "MetaInlines" or t == "MetaString" then
    local s = stringify(value)
    if s == "" then
      return {}
    end
    return { s }
  end

  if t == "MetaMap" then
    -- Common case for list entries like: - name: Value
    if value.name ~= nil then
      local s = stringify(value.name)
      if s ~= "" then
        return { s }
      end
    end
    local s = stringify(value)
    if s ~= "" then
      return { s }
    end
    return {}
  end

  local s = stringify(value)
  if s == "" then
    return {}
  end
  return { s }
end

local function render_html_list(items, css_class)
  local attrs = ""
  if css_class ~= "" then
    attrs = ' class="' .. css_class .. '"'
  end

  local li = {}
  for _, item in ipairs(items) do
    table.insert(li, "<li>" .. escape_html(item) .. "</li>")
  end

  return "<ul" .. attrs .. ">" .. table.concat(li, "") .. "</ul>"
end

return {
  ["meta-list"] = function(args, kwargs, meta, raw_args, context)
    local key = stringify(args[1])
    if key == "" then
      return pandoc.Null()
    end

    local value = resolve_path(meta, key)
    local list = meta_list_items(value)
    if #list == 0 then
      return pandoc.Null()
    end

    local css_class = stringify(kwargs["class"])
    local html = render_html_list(list, css_class)

    if context == "inline" or context == "text" then
      return pandoc.RawInline("html", html)
    end

    return pandoc.RawBlock("html", html)
  end
}

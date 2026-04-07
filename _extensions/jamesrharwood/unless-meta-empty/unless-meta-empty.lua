local function trim(s)
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local cached_meta = {}

local function meta_lookup(meta, path)
  local value = meta
  for key in string.gmatch(path, "[^.]+") do
    if value == nil then
      return nil
    end
    value = value[key]
  end
  return value
end

local function meta_has_value(path)
  local value = meta_lookup(cached_meta, path)

  if value == nil then
    return false
  end

  local text = pandoc.utils.stringify(value)
  if text == nil then
    return false
  end

  return trim(text) ~= ""
end

local function process_div(el)
  local path = el.attributes["unless-meta-empty"]
  if path == nil then
    return nil
  end

  path = trim(path)
  if path == "" then
    return pandoc.Null()
  end

  if meta_has_value(path) then
    -- Remove control attributes before emitting output.
    el.attributes["unless-meta-empty"] = nil
    return el
  else
    return pandoc.Null()
  end
end

function Pandoc(doc)
  cached_meta = doc.meta or {}
  return doc:walk({ Div = process_div })
end
local M = {}

local dots = {
  { 0, 0, 1 },
  { 0, 1, 2 },
  { 0, 2, 4 },
  { 0, 3, 64 },
  { 1, 0, 8 },
  { 1, 1, 16 },
  { 1, 2, 32 },
  { 1, 3, 128 },
}

local function bounded(state, x, y)
  for _ = 1, state.iterations do
    if x * x + y * y > 4 then
      return false
    end
    x, y = x * x - y * y + state.cr, 2 * x * y + state.ci
  end
  return true
end

local function pixel(state, x, y, width, height)
  local span_x = 3.4
  local span_y = span_x * height * 2 / width
  return bounded(
    state,
    ((x + 0.5) / (width * 2) - 0.5) * span_x,
    (0.5 - (y + 0.5) / (height * 4)) * span_y
  )
end

-- A private PRNG preserves math.random's state for other plugins.
function M.new(iterations, seed)
  local random_state = math.floor((seed or vim.uv.hrtime()) % 2147483646) + 1
  local function random()
    random_state = (random_state * 16807) % 2147483647
    return random_state / 2147483647
  end
  for _ = 1, 3 do
    random()
  end
  local state = { iterations = iterations or 80 }
  local hits, attempt = 0, 0
  repeat
    state.cr, state.ci = -1.8 + random() * 2.25, -0.95 + random() * 1.9
    hits = 0
    for gy = 0, 12 do
      for gx = 0, 20 do
        local px, py = (gx + 0.5) * 86 / 21 - 0.5, (gy + 0.5) * 60 / 13 - 0.5
        if pixel(state, px, py, 43, 15) then
          hits = hits + 1
        end
      end
    end
    attempt = attempt + 1
  until (hits > 0 and hits < 80) or attempt >= 21
  return state
end

local function centered(text, width)
  local padding = math.max(0, width - vim.fn.strdisplaywidth(text))
  return string.rep(" ", math.floor(padding / 2)) .. text .. string.rep(" ", math.ceil(padding / 2))
end

function M.render(state, width, max_height, available_height)
  if available_height < 1 then
    return ""
  end
  -- Drop captions before sacrificing the final rows of artwork.
  local captions = {}
  if available_height >= 7 and width >= 30 then
    captions = {
      "",
      "n e o v i m",
      "z ↦ z² + c",
      string.format(
        "c = %.5f %s %.5fi",
        state.cr,
        state.ci < 0 and "−" or "+",
        math.abs(state.ci)
      ),
    }
  elseif available_height >= 4 and width >= 11 then
    captions = { "n e o v i m" }
  end
  local height = math.max(
    1,
    math.min(max_height, math.floor(width * max_height / 43), available_height - #captions)
  )
  local lines = {}
  for y = 0, height - 1 do
    local row = {}
    for x = 0, width - 1 do
      local mask = 0
      for _, dot in ipairs(dots) do
        if pixel(state, 2 * x + dot[1], 4 * y + dot[2], width, height) then
          mask = mask + dot[3]
        end
      end
      row[#row + 1] = mask == 0 and " " or vim.fn.nr2char(0x2800 + mask)
    end
    lines[#lines + 1] = table.concat(row)
  end
  while #lines > 1 and not lines[1]:find("%S") do
    table.remove(lines, 1)
  end
  while #lines > 1 and not lines[#lines]:find("%S") do
    table.remove(lines)
  end
  for _, caption in ipairs(captions) do
    lines[#lines + 1] = centered(caption, width)
  end
  return table.concat(lines, "\n")
end

return M

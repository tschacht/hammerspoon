local CONFIG = {
  menuTitle = "WI",
  alertDuration = 0.4,
  winWinGridParts = 50,
  minimumWidth = 500,
  minimumHeight = 500,
  aspectPresets = {
    { label = "16:9", width = 16, height = 9 },
    { label = "2:1", width = 2, height = 1 },
    { label = "3:1", width = 3, height = 1 },
    { label = "3:2", width = 3, height = 2 },
  },
  widthPresets = { 1400, 1600, 1800, 2000, 2200, 2400 },
  heightPresets = { 1000, 1200, 1400, 1500 },
  growStep = 100,
  cornerPresets = {
    { label = "Top Left", key = "topleft" },
    { label = "Center Top", key = "centertop" },
    { label = "Top Right", key = "topright" },
    { label = "Bottom Left", key = "bottomleft" },
    { label = "Bottom Right", key = "bottomright" },
  },
}

local WindowManager = rawget(_G, "WindowManager") or {}
_G.WindowManager = WindowManager

local winwin = hs.loadSpoon("WinWin")
if not winwin then
  error("Failed to load WinWin spoon")
end

winwin.gridparts = CONFIG.winWinGridParts

WindowManager.menu = hs.menubar.new()
local menu = WindowManager.menu
if not menu then
  error("Failed to create menu bar item")
end

WindowManager.windowFilter = hs.window.filter.new()
local windowFilter = WindowManager.windowFilter
WindowManager.lastFocusedWindow = hs.window.frontmostWindow()

local function alert(message)
  hs.alert.show(message, { textSize = 18 }, nil, CONFIG.alertDuration)
end

local function getValidWindow(candidate)
  if not candidate then
    return nil
  end

  local ok, windowId = pcall(function()
    return candidate:id()
  end)
  if not ok or not windowId then
    return nil
  end

  local screenOk, screen = pcall(function()
    return candidate:screen()
  end)
  if not screenOk or not screen then
    return nil
  end

  return candidate, screen
end

local function getFocusedWindow()
  local win = getValidWindow(hs.window.focusedWindow())
  if win then
    WindowManager.lastFocusedWindow = win
    return win
  end

  win = getValidWindow(WindowManager.lastFocusedWindow)
  if win then
    return win
  end

  win = getValidWindow(hs.window.frontmostWindow())
  if not win then
    alert("No focused window")
    return nil
  end

  WindowManager.lastFocusedWindow = win
  return win
end

local function round(value)
  return math.floor(value + 0.5)
end

local function clamp(value, minValue, maxValue)
  if maxValue < minValue then
    return minValue
  end

  return math.max(minValue, math.min(value, maxValue))
end

local function clampFrameToScreen(frame, screenFrame)
  local width = clamp(round(frame.w), CONFIG.minimumWidth, round(screenFrame.w))
  local height = clamp(round(frame.h), CONFIG.minimumHeight, round(screenFrame.h))
  local maxX = round(screenFrame.x + screenFrame.w - width)
  local maxY = round(screenFrame.y + screenFrame.h - height)

  return {
    x = clamp(round(frame.x), round(screenFrame.x), maxX),
    y = clamp(round(frame.y), round(screenFrame.y), maxY),
    w = width,
    h = height,
  }
end

local function applyFrame(win, frame, label)
  local screenFrame = win:screen():frame()
  local clampedFrame = clampFrameToScreen(frame, screenFrame)
  win:setFrame(clampedFrame)
  alert(label)
end

local function applyAspectPreset(preset)
  local win = getFocusedWindow()
  if not win then
    return
  end

  local currentFrame = win:frame()
  local targetHeight = currentFrame.w * preset.height / preset.width

  applyFrame(win, {
    x = currentFrame.x,
    y = currentFrame.y,
    w = currentFrame.w,
    h = targetHeight,
  }, "Aspect " .. preset.label)
end

local function applyWidthPreset(width)
  local win = getFocusedWindow()
  if not win then
    return
  end

  local currentFrame = win:frame()

  applyFrame(win, {
    x = currentFrame.x,
    y = currentFrame.y,
    w = width,
    h = currentFrame.h,
  }, string.format("Width %d px", width))
end

local function applyHeightPreset(height)
  local win = getFocusedWindow()
  if not win then
    return
  end

  local currentFrame = win:frame()

  applyFrame(win, {
    x = currentFrame.x,
    y = currentFrame.y,
    w = currentFrame.w,
    h = height,
  }, string.format("Height %d px", height))
end

local function moveToCorner(corner)
  local win = getFocusedWindow()
  if not win then
    return
  end

  local currentFrame = win:frame()
  local screenFrame = win:screen():frame()
  local targetFrame = {
    x = currentFrame.x,
    y = currentFrame.y,
    w = currentFrame.w,
    h = currentFrame.h,
  }

  if corner == "topleft" then
    targetFrame.x = screenFrame.x
    targetFrame.y = screenFrame.y
  elseif corner == "centertop" then
    targetFrame.x = screenFrame.x + (screenFrame.w - currentFrame.w) / 2
    targetFrame.y = screenFrame.y
  elseif corner == "topright" then
    targetFrame.x = screenFrame.x + screenFrame.w - currentFrame.w
    targetFrame.y = screenFrame.y
  elseif corner == "bottomleft" then
    targetFrame.x = screenFrame.x
    targetFrame.y = screenFrame.y + screenFrame.h - currentFrame.h
  elseif corner == "bottomright" then
    targetFrame.x = screenFrame.x + screenFrame.w - currentFrame.w
    targetFrame.y = screenFrame.y + screenFrame.h - currentFrame.h
  else
    alert("Unknown corner: " .. tostring(corner))
    return
  end

  applyFrame(win, targetFrame, "Move " .. corner)
end

local function growWindow(deltaWidth, deltaHeight, label)
  local win = getFocusedWindow()
  if not win then
    return
  end

  local currentFrame = win:frame()

  applyFrame(win, {
    x = currentFrame.x,
    y = currentFrame.y,
    w = currentFrame.w + deltaWidth,
    h = currentFrame.h + deltaHeight,
  }, label)
end

local function shrinkWindow(deltaWidth, deltaHeight, label)
  local win = getFocusedWindow()
  if not win then
    return
  end

  local currentFrame = win:frame()

  applyFrame(win, {
    x = currentFrame.x,
    y = currentFrame.y,
    w = currentFrame.w - deltaWidth,
    h = currentFrame.h - deltaHeight,
  }, label)
end

local function buildMenuItems()
  local items = {
    { title = "Aspect Presets", disabled = true },
  }

  for _, preset in ipairs(CONFIG.aspectPresets) do
    table.insert(items, {
      title = preset.label,
      fn = function()
        applyAspectPreset(preset)
      end,
    })
  end

  table.insert(items, { title = "-" })
  table.insert(items, { title = "Width Presets", disabled = true })

  for _, width in ipairs(CONFIG.widthPresets) do
    table.insert(items, {
      title = string.format("%d px", width),
      fn = function()
        applyWidthPreset(width)
      end,
    })
  end

  table.insert(items, { title = "-" })
  table.insert(items, { title = "Height Presets", disabled = true })

  for _, height in ipairs(CONFIG.heightPresets) do
    table.insert(items, {
      title = string.format("%d px", height),
      fn = function()
        applyHeightPreset(height)
      end,
    })
  end

  table.insert(items, { title = "-" })
  table.insert(items, { title = "Move To Corner", disabled = true })

  for _, corner in ipairs(CONFIG.cornerPresets) do
    table.insert(items, {
      title = corner.label,
      fn = function()
        moveToCorner(corner.key)
      end,
    })
  end

  table.insert(items, { title = "-" })
  table.insert(items, { title = "Grow " .. CONFIG.growStep .. " px", disabled = true })
  table.insert(items, {
    title = "Width",
    fn = function()
      growWindow(CONFIG.growStep, 0, "Grow width +" .. CONFIG.growStep .. " px")
    end,
  })
  table.insert(items, {
    title = "Height",
    fn = function()
      growWindow(0, CONFIG.growStep, "Grow height +" .. CONFIG.growStep .. " px")
    end,
  })
  table.insert(items, {
    title = "Width + Height",
    fn = function()
      growWindow(CONFIG.growStep, CONFIG.growStep, "Grow size +" .. CONFIG.growStep .. " px")
    end,
  })

  table.insert(items, { title = "-" })
  table.insert(items, { title = "Shrink " .. CONFIG.growStep .. " px", disabled = true })
  table.insert(items, {
    title = "Width",
    fn = function()
      shrinkWindow(CONFIG.growStep, 0, "Shrink width -" .. CONFIG.growStep .. " px")
    end,
  })
  table.insert(items, {
    title = "Height",
    fn = function()
      shrinkWindow(0, CONFIG.growStep, "Shrink height -" .. CONFIG.growStep .. " px")
    end,
  })
  table.insert(items, {
    title = "Width + Height",
    fn = function()
      shrinkWindow(CONFIG.growStep, CONFIG.growStep, "Shrink size -" .. CONFIG.growStep .. " px")
    end,
  })

  return items
end

menu:setTitle(CONFIG.menuTitle)
menu:setTooltip("Window management")
menu:setMenu(buildMenuItems)

windowFilter:subscribe(hs.window.filter.windowFocused, function(win)
  local validWindow = getValidWindow(win)
  if validWindow then
    WindowManager.lastFocusedWindow = validWindow
  end
end)

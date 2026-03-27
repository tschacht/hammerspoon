local CONFIG = {
  menuTitle = "WI",
  alertDuration = 0.4,
  modalDuration = 5,
  symbols = {
    left = "←",
    up = "↑",
    right = "→",
    down = "↓",
    shift = "shift",
  },
  winWinGridParts = 50,
  minimumWidth = 500,
  minimumHeight = 500,
  modalHotkey = {
    modifiers = { "ctrl", "alt", "cmd" },
    key = "m",
  },
  aspectPresets = {
    { label = "16:9", width = 16, height = 9 },
    { label = "2:1", width = 2, height = 1 },
    { label = "3:1", width = 3, height = 1 },
    { label = "3:2", width = 3, height = 2 },
  },
  widthPresets = { 1400, 1600, 1800, 2000, 2200, 2400, 2600 },
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
local windowMode

local function deleteObject(object)
  if object and object.delete then
    pcall(function()
      object:delete()
    end)
  end
end

deleteObject(WindowManager.entryHotkey)
deleteObject(WindowManager.windowMode)
deleteObject(WindowManager.modalTimer)
deleteObject(WindowManager.modalCanvas)

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

local function closeModalOverlay()
  if WindowManager.modalCanvas then
    pcall(function()
      WindowManager.modalCanvas:hide()
      WindowManager.modalCanvas:delete()
    end)
    WindowManager.modalCanvas = nil
  end
end

local function modalAlert(message)
  closeModalOverlay()

  local screenFrame = hs.screen.mainScreen():frame()
  local lines = hs.fnutils.split(message, "\n")
  local longestLine = 0

  for _, line in ipairs(lines) do
    longestLine = math.max(longestLine, #line)
  end

  local width = math.min(math.max(280, longestLine * 12 + 48), math.floor(screenFrame.w * 0.8))
  local height = math.min(math.max(90, #lines * 28 + 36), math.floor(screenFrame.h * 0.7))
  local frame = {
    x = math.floor(screenFrame.x + (screenFrame.w - width) / 2),
    y = math.floor(screenFrame.y + 60),
    w = width,
    h = height,
  }

  local canvas = hs.canvas.new(frame)
  canvas:level(hs.canvas.windowLevels.overlay)
  canvas:behavior(hs.canvas.windowBehaviors.canJoinAllSpaces)
  canvas[1] = {
    type = "rectangle",
    action = "fill",
    fillColor = { red = 0.08, green = 0.08, blue = 0.08, alpha = 0.92 },
    roundedRectRadii = { xRadius = 12, yRadius = 12 },
  }
  canvas[2] = {
    type = "text",
    text = message,
    textSize = 20,
    textColor = { white = 1, alpha = 1 },
    textFont = "Menlo",
    textAlignment = "left",
    frame = { x = 20, y = 14, w = width - 40, h = height - 28 },
  }
  canvas:show()
  WindowManager.modalCanvas = canvas
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

WindowManager.modalState = WindowManager.modalState or { group = nil }
local modalState = WindowManager.modalState

local function resetModalState()
  modalState.group = nil
end

local function stopModalTimer()
  if WindowManager.modalTimer then
    pcall(function()
      WindowManager.modalTimer:stop()
    end)
    WindowManager.modalTimer = nil
  end
end

local function startModalTimer()
  stopModalTimer()
  WindowManager.modalTimer = hs.timer.doAfter(CONFIG.modalDuration, function()
    if windowMode then
      windowMode:exit()
    end
  end)
end

local function completeModalAction()
  windowMode:exit()
end

local function showModalHome()
  modalAlert(table.concat({
    "Window mode:",
    "A = aspect",
    "W = width",
    "H = height",
    "M = move",
    "G = grow",
    "S = shrink",
    "Esc = cancel",
  }, "\n"))
end

local function formatPresetOptions(presets, labelFn)
  local labels = {}

  for index, preset in ipairs(presets) do
    table.insert(labels, string.format("%d = %s", index, labelFn(preset)))
  end

  return table.concat(labels, "\n")
end

local function showModalGroupPrompt(group)
  startModalTimer()

  if group == "aspect" then
    modalAlert("Aspect preset:\n" .. formatPresetOptions(CONFIG.aspectPresets, function(preset)
      return preset.label
    end))
  elseif group == "width" then
    modalAlert("Width preset:\n" .. formatPresetOptions(CONFIG.widthPresets, function(width)
      return tostring(width)
    end))
  elseif group == "height" then
    modalAlert("Height preset:\n" .. formatPresetOptions(CONFIG.heightPresets, function(height)
      return tostring(height)
    end))
  elseif group == "move" then
    modalAlert(table.concat({
      "Move:",
      CONFIG.symbols.left .. " = top-left",
      CONFIG.symbols.up .. " = center-top",
      CONFIG.symbols.right .. " = top-right",
      CONFIG.symbols.shift .. " + " .. CONFIG.symbols.left .. " = bottom-left",
      CONFIG.symbols.shift .. " + " .. CONFIG.symbols.right .. " = bottom-right",
    }, "\n"))
  elseif group == "grow" then
    modalAlert(table.concat({
      "Grow:",
      CONFIG.symbols.right .. " = width",
      CONFIG.symbols.down .. " = height",
      CONFIG.symbols.up .. " = width + height",
    }, "\n"))
  elseif group == "shrink" then
    modalAlert(table.concat({
      "Shrink:",
      CONFIG.symbols.right .. " = width",
      CONFIG.symbols.down .. " = height",
      CONFIG.symbols.up .. " = width + height",
    }, "\n"))
  end
end

local function setModalGroup(group)
  modalState.group = group
  showModalGroupPrompt(group)
end

local function selectPreset(presets, index, applyFn, label)
  local preset = presets[index]
  if not preset then
    modalAlert("No " .. label .. " preset " .. tostring(index))
    return false
  end

  applyFn(preset)
  return true
end

local function handleNumberSelection(index)
  startModalTimer()

  if modalState.group == "aspect" then
    if not selectPreset(CONFIG.aspectPresets, index, applyAspectPreset, "aspect") then
      return
    end
  elseif modalState.group == "width" then
    if not selectPreset(CONFIG.widthPresets, index, applyWidthPreset, "width") then
      return
    end
  elseif modalState.group == "height" then
    if not selectPreset(CONFIG.heightPresets, index, applyHeightPreset, "height") then
      return
    end
  else
    modalAlert("Choose A, W, or H first")
    return
  end

  completeModalAction()
end

local function handleMoveSelection(direction, shifted)
  startModalTimer()

  if modalState.group ~= "move" then
    modalAlert("Press M first")
    return
  end

  if direction == "up" then
    moveToCorner("centertop")
  elseif direction == "left" and shifted then
    moveToCorner("bottomleft")
  elseif direction == "right" and shifted then
    moveToCorner("bottomright")
  elseif direction == "left" then
    moveToCorner("topleft")
  elseif direction == "right" then
    moveToCorner("topright")
  else
    modalAlert("Use Left, Up, Right, Shift+Left, or Shift+Right")
    return
  end

  completeModalAction()
end

local function handleSizeSelection(direction)
  startModalTimer()

  if modalState.group == "grow" then
    if direction == "right" then
      growWindow(CONFIG.growStep, 0, "Grow width +" .. CONFIG.growStep .. " px")
    elseif direction == "down" then
      growWindow(0, CONFIG.growStep, "Grow height +" .. CONFIG.growStep .. " px")
    elseif direction == "up" then
      growWindow(CONFIG.growStep, CONFIG.growStep, "Grow size +" .. CONFIG.growStep .. " px")
    else
      modalAlert("Use Right, Down, or Up")
      return
    end
  elseif modalState.group == "shrink" then
    if direction == "right" then
      shrinkWindow(CONFIG.growStep, 0, "Shrink width -" .. CONFIG.growStep .. " px")
    elseif direction == "down" then
      shrinkWindow(0, CONFIG.growStep, "Shrink height -" .. CONFIG.growStep .. " px")
    elseif direction == "up" then
      shrinkWindow(CONFIG.growStep, CONFIG.growStep, "Shrink size -" .. CONFIG.growStep .. " px")
    else
      modalAlert("Use Right, Down, or Up")
      return
    end
  else
    modalAlert("Press G or S first")
    return
  end

  completeModalAction()
end

local function buildMenuItems()
  local modalHotkeyLabel = table.concat(CONFIG.modalHotkey.modifiers, "+") .. "+" .. string.upper(CONFIG.modalHotkey.key)
  local items = {
    { title = "Keyboard Mode: " .. modalHotkeyLabel, disabled = true },
    { title = "-" },
    { title = "Aspect Presets [A then 1-9]", disabled = true },
  }

  for index, preset in ipairs(CONFIG.aspectPresets) do
    table.insert(items, {
      title = string.format("%s [A %d]", preset.label, index),
      fn = function()
        applyAspectPreset(preset)
      end,
    })
  end

  table.insert(items, { title = "-" })
  table.insert(items, { title = "Width Presets [W then 1-9]", disabled = true })

  for index, width in ipairs(CONFIG.widthPresets) do
    table.insert(items, {
      title = string.format("%d px [W %d]", width, index),
      fn = function()
        applyWidthPreset(width)
      end,
    })
  end

  table.insert(items, { title = "-" })
  table.insert(items, { title = "Height Presets [H then 1-9]", disabled = true })

  for index, height in ipairs(CONFIG.heightPresets) do
    table.insert(items, {
      title = string.format("%d px [H %d]", height, index),
      fn = function()
        applyHeightPreset(height)
      end,
    })
  end

  table.insert(items, { title = "-" })
  table.insert(items, {
    title = "Move To Corner [M then " .. CONFIG.symbols.left .. " " .. CONFIG.symbols.up .. " " .. CONFIG.symbols.right .. "]",
    disabled = true,
  })
  table.insert(items, {
    title = "Top Left [M " .. CONFIG.symbols.left .. "]",
    fn = function()
      moveToCorner("topleft")
    end,
  })
  table.insert(items, {
    title = "Center Top [M " .. CONFIG.symbols.up .. "]",
    fn = function()
      moveToCorner("centertop")
    end,
  })
  table.insert(items, {
    title = "Top Right [M " .. CONFIG.symbols.right .. "]",
    fn = function()
      moveToCorner("topright")
    end,
  })
  table.insert(items, {
    title = "Bottom Left [M " .. CONFIG.symbols.shift .. " + " .. CONFIG.symbols.left .. "]",
    fn = function()
      moveToCorner("bottomleft")
    end,
  })
  table.insert(items, {
    title = "Bottom Right [M " .. CONFIG.symbols.shift .. " + " .. CONFIG.symbols.right .. "]",
    fn = function()
      moveToCorner("bottomright")
    end,
  })

  table.insert(items, { title = "-" })
  table.insert(items, {
    title = "Grow " .. CONFIG.growStep .. " px [G then " .. CONFIG.symbols.right .. " " .. CONFIG.symbols.down .. " " .. CONFIG.symbols.up .. "]",
    disabled = true,
  })
  table.insert(items, {
    title = "Width [G " .. CONFIG.symbols.right .. "]",
    fn = function()
      growWindow(CONFIG.growStep, 0, "Grow width +" .. CONFIG.growStep .. " px")
    end,
  })
  table.insert(items, {
    title = "Height [G " .. CONFIG.symbols.down .. "]",
    fn = function()
      growWindow(0, CONFIG.growStep, "Grow height +" .. CONFIG.growStep .. " px")
    end,
  })
  table.insert(items, {
    title = "Width + Height [G " .. CONFIG.symbols.up .. "]",
    fn = function()
      growWindow(CONFIG.growStep, CONFIG.growStep, "Grow size +" .. CONFIG.growStep .. " px")
    end,
  })

  table.insert(items, { title = "-" })
  table.insert(items, {
    title = "Shrink " .. CONFIG.growStep .. " px [S then " .. CONFIG.symbols.right .. " " .. CONFIG.symbols.down .. " " .. CONFIG.symbols.up .. "]",
    disabled = true,
  })
  table.insert(items, {
    title = "Width [S " .. CONFIG.symbols.right .. "]",
    fn = function()
      shrinkWindow(CONFIG.growStep, 0, "Shrink width -" .. CONFIG.growStep .. " px")
    end,
  })
  table.insert(items, {
    title = "Height [S " .. CONFIG.symbols.down .. "]",
    fn = function()
      shrinkWindow(0, CONFIG.growStep, "Shrink height -" .. CONFIG.growStep .. " px")
    end,
  })
  table.insert(items, {
    title = "Width + Height [S " .. CONFIG.symbols.up .. "]",
    fn = function()
      shrinkWindow(CONFIG.growStep, CONFIG.growStep, "Shrink size -" .. CONFIG.growStep .. " px")
    end,
  })

  return items
end

menu:setTitle(CONFIG.menuTitle)
menu:setTooltip("Window management: Ctrl+Alt+Cmd+W for keyboard mode")
menu:setMenu(buildMenuItems)

windowFilter:subscribe(hs.window.filter.windowFocused, function(win)
  local validWindow = getValidWindow(win)
  if validWindow then
    WindowManager.lastFocusedWindow = validWindow
  end
end)

WindowManager.windowMode = hs.hotkey.modal.new()
windowMode = WindowManager.windowMode

function windowMode:entered()
  resetModalState()
  startModalTimer()
  showModalHome()
end

function windowMode:exited()
  stopModalTimer()
  closeModalOverlay()
  resetModalState()
end

windowMode:bind({}, "escape", function()
  windowMode:exit()
end)

windowMode:bind({}, "a", function()
  setModalGroup("aspect")
end)

windowMode:bind({}, "w", function()
  setModalGroup("width")
end)

windowMode:bind({}, "h", function()
  setModalGroup("height")
end)

windowMode:bind({}, "m", function()
  setModalGroup("move")
end)

windowMode:bind({}, "g", function()
  setModalGroup("grow")
end)

windowMode:bind({}, "s", function()
  setModalGroup("shrink")
end)

for index = 1, 9 do
  windowMode:bind({}, tostring(index), function()
    handleNumberSelection(index)
  end)
end

windowMode:bind({}, "up", function()
  if modalState.group == "move" then
    handleMoveSelection("up", false)
  else
    handleSizeSelection("up")
  end
end)

windowMode:bind({}, "down", function()
  handleSizeSelection("down")
end)

windowMode:bind({}, "left", function()
  handleMoveSelection("left", false)
end)

windowMode:bind({ "shift" }, "left", function()
  handleMoveSelection("left", true)
end)

windowMode:bind({}, "right", function()
  if modalState.group == "move" then
    handleMoveSelection("right", false)
  else
    handleSizeSelection("right")
  end
end)

windowMode:bind({ "shift" }, "right", function()
  handleMoveSelection("right", true)
end)

WindowManager.entryHotkey = hs.hotkey.bind(CONFIG.modalHotkey.modifiers, CONFIG.modalHotkey.key, function()
  windowMode:enter()
end)

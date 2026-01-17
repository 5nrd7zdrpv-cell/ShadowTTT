
print("[ShadowTTT2] MODEL-ENUM CLIENT loaded")

ShadowTTT2 = ShadowTTT2 or {}
ShadowTTT2.CoreClientLoaded = true
ShadowTTT2.PointshopEnhanced = true

local activePointshopFrame

local THEME = {
  bg = Color(18, 18, 24, 245),
  panel = Color(32, 32, 40, 240),
  accent = Color(255, 145, 80),
  accent_soft = Color(120, 200, 255),
  muted = Color(180, 185, 195),
  text = Color(245, 245, 245),
}
local SLOT_MIN_BET = 5
local SLOT_MAX_BET = 1000
local SLOT_SPIN_TIMEOUT = 1.25
local MODEL_PRICE_DEFAULT = 100
local SLOT_FALLBACK_ICONS = {"🍒", "🍋", "🔔", "⭐", "💎", "7", "BAR"}
local SLOT_SVG_ICONS = {
  {id = "cherry", label = "Kirsche", icon = "🍒", svg = "materials/shadowttt2/slots/cherry.svg"},
  {id = "lemon", label = "Zitrone", icon = "🍋", svg = "materials/shadowttt2/slots/lemon.svg"},
  {id = "bell", label = "Glocke", icon = "🔔", svg = "materials/shadowttt2/slots/bell.svg"},
  {id = "star", label = "Stern", icon = "⭐", svg = "materials/shadowttt2/slots/star.svg"},
  {id = "diamond", label = "Diamant", icon = "💎", svg = "materials/shadowttt2/slots/diamond.svg"},
  {id = "seven", label = "Sieben", icon = "7", svg = "materials/shadowttt2/slots/seven.svg"}
}
local SLOT_ICON_LOOKUP = {}
for _, def in ipairs(SLOT_SVG_ICONS) do
  SLOT_ICON_LOOKUP[def.id] = def
end

local slotSvgCache = {}
local slotMaterialCache = {}

local function readSlotSvg(def)
  if not def or not def.id then return nil end
  if slotSvgCache[def.id] ~= nil then
    return slotSvgCache[def.id]
  end

  local svgPath = def.svg
  if svgPath and file.Exists(svgPath, "GAME") then
    local svg = file.Read(svgPath, "GAME")
    if isstring(svg) and svg ~= "" then
      slotSvgCache[def.id] = svg
      return svg
    end
  end

  slotSvgCache[def.id] = false
  return nil
end

local function buildSlotMaterial(def)
  if not def or not def.id or not CreateHTMLMaterial then return nil end
  local svg = readSlotSvg(def)
  if not svg then return nil end

  local encoded = util and util.Base64Encode and util.Base64Encode(svg) or nil
  local body = [[<body style="margin:0;padding:0;overflow:hidden;display:flex;align-items:center;justify-content:center;background:rgba(0,0,0,0);">]]
  local html

  if encoded then
    html = [[<html><head><style>img{width:128px;height:128px;}</style></head>]] .. body .. [[<img src="data:image/svg+xml;base64:]] .. encoded .. [["></body></html>]]
  else
    html = [[<html>]] .. body .. svg .. [[</body></html>]]
  end

  local mat = CreateHTMLMaterial("st2_slot_svg_" .. def.id, 128, 128, html)
  if not mat then return nil end

  mat:SetInt("$vertexcolor", 1)
  mat:SetInt("$additive", 0)
  mat:SetInt("$nocull", 1)
  return mat
end

local function getSlotMaterial(id)
  if not id or id == "" then return nil end
  if slotMaterialCache[id] ~= nil then
    return slotMaterialCache[id] or nil
  end

  local def = SLOT_ICON_LOOKUP[id]
  if not def then
    slotMaterialCache[id] = false
    return nil
  end

  local mat = buildSlotMaterial(def)
  slotMaterialCache[id] = mat or false
  return mat
end

local function warmSlotSvgCache()
  for _, def in ipairs(SLOT_SVG_ICONS) do
    def.mat = def.mat or getSlotMaterial(def.id)
  end
end
warmSlotSvgCache()

local function resolveSlotSymbol(sym)
  if istable(sym) then
    if sym.id and SLOT_ICON_LOOKUP[sym.id] then
      return SLOT_ICON_LOOKUP[sym.id]
    end
    if sym.id or sym.icon then
      return {
        id = sym.id or sym.icon or "mystery",
        icon = sym.icon or sym.id or "?",
        label = sym.icon or sym.id or "?"
      }
    end
  end

  if #SLOT_SVG_ICONS > 0 then
    return SLOT_SVG_ICONS[math.random(#SLOT_SVG_ICONS)]
  end

  return {icon = SLOT_FALLBACK_ICONS[math.random(#SLOT_FALLBACK_ICONS)] or "?"}
end

local function randomSlotSymbol()
  if #SLOT_SVG_ICONS > 0 then
    return SLOT_SVG_ICONS[math.random(#SLOT_SVG_ICONS)] or {icon = "?"}
  end

  return {icon = SLOT_FALLBACK_ICONS[math.random(#SLOT_FALLBACK_ICONS)] or "?"}
end

surface.CreateFont("ST2.Title", {font = "Roboto", size = 24, weight = 800})
surface.CreateFont("ST2.Subtitle", {font = "Roboto", size = 18, weight = 600})
surface.CreateFont("ST2.Body", {font = "Roboto", size = 16, weight = 500})
surface.CreateFont("ST2.Small", {font = "Roboto", size = 14, weight = 500})
surface.CreateFont("ST2.Button", {font = "Roboto", size = 17, weight = 700})
surface.CreateFont("ST2.Mono", {font = "Consolas", size = 15, weight = 500})
surface.CreateFont("ST2.SlotReel", {font = "Roboto", size = 44, weight = 800})

local function paintSlotIcon(self, w, h)
  local icon = self.ShadowSlotIcon
  local tint = icon and icon.color or THEME.text
  if icon and icon.mat and icon.mat ~= false and not icon.mat:IsError() then
    local size = math.min(w, h) - 12
    surface.SetMaterial(icon.mat)
    surface.SetDrawColor(tint)
    surface.DrawTexturedRect((w - size) / 2, (h - size) / 2, size, size)
    return
  end

  draw.SimpleText(icon and icon.text or "?", "ST2.SlotReel", w / 2, h / 2, tint, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

local function setSlotPanelSymbol(panel, sym, highlight)
  if not IsValid(panel) then return end
  local def = resolveSlotSymbol(sym)
  local mat = def and (def.mat or (def.id and getSlotMaterial(def.id)))
  panel.ShadowSlotIcon = {
    id = def and def.id or nil,
    mat = mat or nil,
    text = def and (def.icon or def.label or def.id) or "?",
    label = def and (def.label or def.icon or def.id) or "?",
    color = highlight and THEME.accent_soft or THEME.text
  }
  panel:SetTooltip(panel.ShadowSlotIcon.label or "")
end

local function createSlotIconCell(parent)
  local cell = vgui.Create("DPanel", parent)
  cell:SetTall(52)
  cell:SetPaintBackground(false)
  cell.Paint = paintSlotIcon
  cell.SetSlotSymbol = function(self, sym, highlight)
    setSlotPanelSymbol(self, sym, highlight)
  end
  cell:SetSlotSymbol(randomSlotSymbol(), false)
  return cell
end

local function createSlotReel(parent, idx)
  local reel = {
    panel = parent,
    cells = {},
    topMargin = 8,
    spacing = 8,
    cellHeight = 48,
    cellWidth = 0,
    step = 56,
    interval = 0.1 + 0.02 * (idx or 1),
    timerName = nil
  }

  reel.cellWidth = math.max(1, parent:GetWide() - 16)
  reel.step = reel.cellHeight + reel.spacing

  local function createCell(y)
    local cell = createSlotIconCell(parent)
    cell:SetSize(reel.cellWidth, reel.cellHeight)
    cell:SetPos(8, y)
    return cell
  end

  for i = 1, 3 do
    local y = reel.topMargin + reel.step * (i - 1)
    local cell = createCell(y)
    reel.cells[i] = cell
  end

  function reel:stop()
    if self.timerName then
      timer.Remove(self.timerName)
      self.timerName = nil
    end
  end

  function reel:trim()
    for i = #self.cells, 1, -1 do
      local cell = self.cells[i]
      if not IsValid(cell) or cell:GetY() > (self.topMargin + self.step * 2 + 6) then
        if IsValid(cell) then cell:Remove() end
        table.remove(self.cells, i)
      end
    end
    while #self.cells > 3 do
      local cell = table.remove(self.cells)
      if IsValid(cell) then cell:Remove() end
    end
  end

  function reel:advance(symbol)
    if not IsValid(self.panel) then return end
    local cell = createCell(self.topMargin - self.step)
    cell:SetSlotSymbol(symbol or randomSlotSymbol(), false)
    table.insert(self.cells, 1, cell)

    for idx2, pnl in ipairs(self.cells) do
      if IsValid(pnl) then
        pnl:MoveTo(8, self.topMargin + self.step * (idx2 - 1), self.interval * 0.9, 0, 0.2)
      end
    end

    timer.Simple(self.interval, function()
      if not IsValid(self.panel) then return end
      reel:trim()
    end)
  end

  function reel:ensureCells()
    for i = 1, 3 do
      if not IsValid(self.cells[i]) then
        local cell = createCell(self.topMargin + self.step * (i - 1))
        self.cells[i] = cell
      end
    end
    table.sort(self.cells, function(a, b)
      if not IsValid(a) or not IsValid(b) then return false end
      return a:GetY() < b:GetY()
    end)
  end

  function reel:setSymbols(topSym, midSym, botSym, highlight)
    self:stop()
    self:ensureCells()
    local icons = {
      topSym or randomSlotSymbol(),
      midSym or randomSlotSymbol(),
      botSym or randomSlotSymbol()
    }

    for idx2, pnl in ipairs(self.cells) do
      if not IsValid(pnl) then continue end
      pnl:SetPos(8, self.topMargin - self.step)
      pnl:SetSlotSymbol(icons[idx2], highlight and idx2 == 2)
      pnl:MoveTo(8, self.topMargin + self.step * (idx2 - 1), 0.15, 0, 0.3)
    end
    self:trim()
  end

  return reel
end

local function styleButton(btn)
  btn:SetFont("ST2.Button")
  btn:SetTextColor(THEME.text)
  btn.Paint = function(self, w, h)
    local col = THEME.panel
    if self:IsDown() then
      col = THEME.accent
    elseif self:IsHovered() then
      col = Color(255, 170, 110)
    end
    draw.RoundedBox(10, 0, 0, w, h, col)
  end
end

local function createFrame(title, w, h)
  local f = vgui.Create("DFrame")
  f:SetSize(w, h)
  f:Center()
  f:MakePopup()
  f:SetTitle("")
  f:ShowCloseButton(false)
  f:SetDraggable(true)
  f.startTime = SysTime()
  f.Paint = function(self, pw, ph)
    Derma_DrawBackgroundBlur(self, self.startTime)
    draw.RoundedBox(12, 0, 0, pw, ph, THEME.bg)
    draw.RoundedBoxEx(12, 0, 0, pw, 52, THEME.panel, true, true, false, false)
    draw.SimpleText(title, "ST2.Title", 16, 16, THEME.text, TEXT_ALIGN_LEFT)
  end

  local close = vgui.Create("DButton", f)
  close:SetSize(36, 32)
  close:SetPos(w - 44, 10)
  close:SetText("✕")
  close:SetFont("ST2.Button")
  close:SetTextColor(THEME.text)
  styleButton(close)
  close.DoClick = function() f:Close() end

  return f
end

do -- Admin panel helpers
  local function styleListView(list)
    if list.SetHeaderHeight then list:SetHeaderHeight(30) end
    if list.SetDataHeight then list:SetDataHeight(28) end
    list.Paint = function(_, w, h)
      draw.RoundedBox(10, 0, 0, w, h, THEME.panel)
    end
    if IsValid(list.VBar) then
      list.VBar.Paint = function(_, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(20, 20, 26, 150))
      end
      list.VBar.btnGrip.Paint = function(_, w, h)
        draw.RoundedBox(6, 0, 0, w, h, THEME.accent)
      end
    end
    for _, col in ipairs(list.Columns or {}) do
      if IsValid(col.Header) then
        col.Header:SetFont("ST2.Subtitle")
        col.Header:SetTextColor(THEME.text)
        col.Header.Paint = function(_, w, h)
          draw.RoundedBox(0, 0, 0, w, h, Color(38, 38, 46, 240))
        end
      end
    end
  end

  local function setLineTextColor(line, color)
    if not IsValid(line) then return end
    color = color or THEME.text

    if line.SetTextColor then
      line:SetTextColor(color)
      return
    end

    for _, col in ipairs(line.Columns or {}) do
      if IsValid(col) and col.SetTextColor then
        col:SetTextColor(color)
      end
    end
  end

  local function addRow(list, ...)
    local line = list:AddLine(...)
    if not IsValid(line) then return end
    setLineTextColor(line, THEME.text)
    line.Paint = function(self, w, h)
      local bg = self:IsLineSelected() and THEME.accent or Color(255, 255, 255, 6)
      draw.RoundedBox(0, 0, 0, w, h, bg)
    end
    return line
  end

  local function populateAdminList(list, players, filter)
    if not IsValid(list) then return end
    list:Clear()
    local query = string.Trim(string.lower(filter or ""))
    for _, ply in ipairs(players or {}) do
      local nameMatch = string.find(string.lower(ply.nick), query, 1, true)
      local idMatch = string.find(string.lower(ply.sid), query, 1, true)
      if query == "" or nameMatch or idMatch then
        addRow(list, ply.nick, ply.sid, ply.points)
      end
    end
  end

  local function formatBanExpiry(expires)
    if not expires or expires == 0 then
      return "Permanent"
    end

    local remaining = math.max(0, expires - os.time())
    return string.format("Endet in %s", string.NiceTime(remaining))
  end

  local function populateBanList(list, entries, filter)
    if not IsValid(list) then return end
    list:Clear()
    local query = string.Trim(string.lower(filter or ""))
    for _, ban in ipairs(entries or {}) do
      local name = ban.name ~= "" and ban.name or "(Unbekannt)"
      local haystack = string.lower(string.format("%s %s %s", name, ban.sid or "", ban.reason or ""))
      if query ~= "" and not string.find(haystack, query, 1, true) then continue end

      local line = addRow(list, name, ban.sid or "", ban.reason or "Kein Grund", formatBanExpiry(ban.expires), ban.banner or "")
      if IsValid(line) then
        line.ShadowBanSid = ban.sid
      end
    end
  end

  local function requestAdminPlayerList(list)
    if not IsValid(list) then return end
    ShadowTTT2.AdminUI = ShadowTTT2.AdminUI or {}
    ShadowTTT2.AdminUI.list = list
    net.Start("ST2_ADMIN_PLAYERLIST")
    net.SendToServer()
  end

  net.Receive("ST2_ADMIN_PLAYERLIST", function()
    local ui = ShadowTTT2.AdminUI
    local list = ui and ui.list
    if not IsValid(list) then return end

    local count = net.ReadUInt(8)
    local entries = {}
    for _ = 1, count do
      table.insert(entries, {
        nick = net.ReadString(),
        sid = net.ReadString(),
        points = net.ReadInt(32),
      })
    end
    ui.players = entries

    local searchText = IsValid(ui.search) and ui.search:GetText() or ""
    populateAdminList(list, entries, searchText)
  end)

  local function requestRecoilMultiplier()
    net.Start("ST2_ADMIN_RECOIL_REQUEST")
    net.SendToServer()
  end

  local function requestMovementSpeeds()
    net.Start("ST2_ADMIN_SPEED_REQUEST")
    net.SendToServer()
  end

  local function requestInfiniteSprint()
    net.Start("ST2_ADMIN_SPRINT_REQUEST")
    net.SendToServer()
  end

  local function populateWeaponDropdown(dropdown, weapons, filter, previousSelection)
    if not IsValid(dropdown) then return end

    if dropdown.Clear then dropdown:Clear() end
    dropdown.SelectedClass = nil

    local query = string.Trim(string.lower(filter or ""))
    local count = 0
    local keepSelection

    for _, info in ipairs(weapons or {}) do
      local class = info.class or ""
      local name = info.name or ""
      local haystack = string.lower(class .. " " .. name)
      if query ~= "" and not string.find(haystack, query, 1, true) then continue end

      local label = (name ~= "" and name ~= class) and (name .. " (" .. class .. ")") or class
      dropdown:AddChoice(label, class)
      count = count + 1
      if previousSelection and previousSelection == class then
        keepSelection = count
      end
    end

    if count == 0 then
      dropdown:SetValue("Keine Waffen gefunden")
      return
    end

    if keepSelection then
      dropdown:ChooseOptionID(keepSelection)
      dropdown.SelectedClass = previousSelection
    elseif dropdown.SetValue then
      dropdown:SetValue(string.format("Waffe auswählen (%d)", count))
    end
  end

  local function requestWeaponList()
    net.Start("ST2_ADMIN_WEAPON_REQUEST")
    net.SendToServer()
  end

  local function requestBanList()
    net.Start("ST2_ADMIN_BANLIST_REQUEST")
    net.SendToServer()
  end

  local function requestMapList()
    net.Start("ST2_ADMIN_MAPS_REQUEST")
    net.SendToServer()
  end

  local function formatMapDisplayName(mapName)
    if not isstring(mapName) then return "" end
    local trimmed = string.Trim(mapName) or ""
    if trimmed == "" then return "" end
    if string.match(string.lower(trimmed), "%.bsp$") then
      return trimmed
    end

    return trimmed .. ".bsp"
  end

  local function sendMapChange(mapName)
    if not isstring(mapName) or mapName == "" then return end
    net.Start("ST2_ADMIN_MAP_CHANGE")
    net.WriteString(mapName)
    net.SendToServer()
  end

  local function sendUnban(sid)
    net.Start("ST2_ADMIN_UNBAN")
    net.WriteString(sid or "")
    net.SendToServer()
  end

  local function sendRecoilMultiplier(value)
    net.Start("ST2_ADMIN_RECOIL_SET")
    net.WriteFloat(value or 0)
    net.SendToServer()
  end

  local function sendMovementSpeeds(walk, run)
    net.Start("ST2_ADMIN_SPEED_SET")
    net.WriteFloat(walk or 0)
    net.WriteFloat(run or 0)
    net.SendToServer()
  end

  local function sendInfiniteSprint(enabled)
    net.Start("ST2_ADMIN_SPRINT_SET")
    net.WriteBool(enabled and true or false)
    net.SendToServer()
  end

  net.Receive("ST2_ADMIN_RECOIL", function()
    local value = net.ReadFloat()
    local ui = ShadowTTT2.AdminUI
    if not ui then return end

    if IsValid(ui.recoilSlider) then
      ui.recoilSlider:SetValue(math.Round(value or 0, 2))
    end
  end)

  net.Receive("ST2_ADMIN_SPEED", function()
    local walk = net.ReadFloat()
    local run = net.ReadFloat()
    local ui = ShadowTTT2.AdminUI
    if not ui then return end

    if IsValid(ui.walkSlider) then
      ui.walkSlider:SetValue(math.Round(walk or 0, 0))
    end

    if IsValid(ui.runSlider) then
      ui.runSlider:SetValue(math.Round(run or 0, 0))
    end
  end)

  net.Receive("ST2_ADMIN_SPRINT", function()
    local enabled = net.ReadBool()
    local ui = ShadowTTT2.AdminUI
    if not ui then return end

    if IsValid(ui.infiniteSprintCheck) then
      ui.infiniteSprintCheck:SetChecked(enabled)
    end
  end)

  net.Receive("ST2_ADMIN_WEAPON_LIST", function()
    local ui = ShadowTTT2.AdminUI
    if not ui then return end

    local count = net.ReadUInt(12)
    local entries = {}
    for _ = 1, count do
      table.insert(entries, {
        class = net.ReadString(),
        name = net.ReadString()
      })
    end

    ui.weaponList = entries
    populateWeaponDropdown(ui.weaponDropdown, entries, IsValid(ui.weaponSearch) and ui.weaponSearch:GetText() or "", ui.weaponDropdown and ui.weaponDropdown.SelectedClass)
    populateWeaponDropdown(ui.shopWeaponDropdown, entries, IsValid(ui.shopWeaponSearch) and ui.shopWeaponSearch:GetText() or "", ui.shopWeaponDropdown and ui.shopWeaponDropdown.SelectedClass)
  end)

  net.Receive("ST2_ADMIN_MAPS", function()
    local ui = ShadowTTT2.AdminUI
    if not ui then return end

    local current = net.ReadString()
    local count = net.ReadUInt(12)
    local entries = {}
    for _ = 1, count do
      entries[#entries + 1] = net.ReadString()
    end

    ui.maps = entries
    ui.currentMap = current or ""

    if IsValid(ui.mapCurrentLabel) then
      local display = formatMapDisplayName(current)
      ui.mapCurrentLabel:SetText(display ~= "" and ("Aktuelle Map: " .. display) or "Aktuelle Map unbekannt")
    end

    if not IsValid(ui.mapDropdown) then return end
    ui.mapDropdown:Clear()
    ui.mapDropdown.SelectedMap = nil

    for _, mapName in ipairs(entries) do
      ui.mapDropdown:AddChoice(formatMapDisplayName(mapName), mapName)
    end

    if ui.mapDropdown.SetValue then
      ui.mapDropdown:SetValue(#entries > 0 and string.format("Map auswählen (%d)", #entries) or "Keine Maps gefunden")
    end

    if #entries > 0 and ui.mapDropdown.ChooseOptionID then
      ui.mapDropdown:ChooseOptionID(1)
      ui.mapDropdown.SelectedMap = entries[1]
    end
  end)

  net.Receive("ST2_ADMIN_BANLIST", function()
    local ui = ShadowTTT2.AdminUI
    if not ui then return end

    local count = net.ReadUInt(10)
    local entries = {}
    for _ = 1, count do
      entries[#entries + 1] = {
        sid = net.ReadString(),
        name = net.ReadString(),
        banner = net.ReadString(),
        reason = net.ReadString(),
        expires = net.ReadUInt(32)
      }
    end

    ui.bans = entries
    populateBanList(ui.banList, entries, IsValid(ui.banSearch) and ui.banSearch:GetText() or "")
  end)

  -- Admin open (client requests server concommand)
  concommand.Add("shadow_admin_open", function()
    net.Start("ST2_ADMIN_REQUEST")
    net.SendToServer()
  end)

  local function createActionButton(parent, label, action, getTarget, opts)
    opts = opts or {}
    local requiresTarget = opts.requireTarget ~= false
    local btn = (parent.Add and parent:Add("DButton")) or vgui.Create("DButton", parent)
    btn:SetTall(48)
    btn:SetText(label)
    btn:SetFont("ST2.Button")
    btn:SetTextColor(THEME.text)
    btn.Paint = function(self, w, h)
      local col = self:IsHovered() and Color(255, 180, 120) or THEME.panel
      if self:IsDown() then col = THEME.accent end
      draw.RoundedBox(12, 0, 0, w, h, col)
    end
    btn.DoClick = function()
      local sid = requiresTarget and getTarget() or ""
      if requiresTarget and not sid then return end
      net.Start("ST2_ADMIN_ACTION")
      net.WriteString(action)
      net.WriteString(sid)
      net.SendToServer()
    end
    return btn
  end

  local function sendTraitorShopRequest()
    net.Start("ST2_TS_ADMIN_CONFIG_REQUEST")
    net.SendToServer()
  end

  local function sendTraitorShopRescan()
    net.Start("ST2_TS_ADMIN_RESCAN")
    net.SendToServer()
  end

  local function sendTraitorShopToggle(id)
    net.Start("ST2_TS_ADMIN_TOGGLE")
    net.WriteString(id)
    net.SendToServer()
  end

  local function sendTraitorShopPrice(id, price, useDefault)
    net.Start("ST2_TS_ADMIN_PRICE")
    net.WriteString(id)
    net.WriteBool(useDefault)
    net.WriteUInt(math.max(0, math.floor(price or 0)), 16)
    net.SendToServer()
  end

  local function sendTraitorShopAdd(id)
    net.Start("ST2_TS_ADMIN_ADD")
    net.WriteString(id)
    net.SendToServer()
  end

  local function sendAdminPointsGrant(sid, amount)
    if not sid or sid == "" then return end
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return end

    net.Start("ST2_ADMIN_POINTS_GRANT")
    net.WriteString(sid)
    net.WriteInt(amount, 32)
    net.SendToServer()
  end

  local function sendPointshopAdminRequest()
    net.Start("ST2_PS_ADMIN_CONFIG_REQUEST")
    net.SendToServer()
  end

  local function sendPointshopToggle(modelPath)
    net.Start("ST2_PS_ADMIN_TOGGLE")
    net.WriteString(modelPath or "")
    net.SendToServer()
  end

  local function sendPointshopPrice(modelPath, price, useDefault)
    net.Start("ST2_PS_ADMIN_PRICE")
    net.WriteString(modelPath or "")
    net.WriteBool(useDefault or false)
    net.WriteUInt(math.max(0, math.floor(price or 0)), 16)
    net.SendToServer()
  end

  local function populateShopList(list, entries, filter)
    if not IsValid(list) then return end
    list:Clear()
    local q = string.Trim(string.lower(filter or ""))
    for _, row in ipairs(entries or {}) do
      if q ~= "" then
        local haystack = string.lower(row.id .. " " .. (row.name or "") .. " " .. (row.category or ""))
        if not string.find(haystack, q, 1, true) then continue end
      end

      local status = row.enabled and "Aktiv" or "Deaktiviert"
      local line = list:AddLine(row.name or row.id, row.id, row.category or "workshop", row.price or 1, status)
      if IsValid(line) then
        setLineTextColor(line, row.enabled and THEME.text or THEME.muted)
        line.ShadowRowData = row
        line.Paint = function(self, w, h)
          local base = row.enabled and Color(255, 255, 255, 6) or Color(255, 90, 120, 18)
          if self:IsLineSelected() then
            base = row.enabled and THEME.accent or Color(255, 120, 140)
          end
          draw.RoundedBox(0, 0, 0, w, h, base)
        end
      end
    end
  end

  local function populateModelAdminList(list, entries, filter, onlyEnabled, counter, defaultPrice)
    if not IsValid(list) then return end
    list:Clear()
    local q = string.Trim(string.lower(filter or ""))
    local visible = 0
    local fallbackPrice = defaultPrice or MODEL_PRICE_DEFAULT
    for _, row in ipairs(entries or {}) do
      if onlyEnabled and not row.enabled then continue end
      if q ~= "" and not string.find(string.lower(row.model or ""), q, 1, true) then continue end

      local price = math.max(0, math.floor(tonumber(row.price) or fallbackPrice))
      local status = row.enabled and "Aktiv" or "Versteckt"
      local line = list:AddLine(row.model or "", string.format("%d Punkte", price), status)
      if IsValid(line) then
        setLineTextColor(line, row.enabled and THEME.text or THEME.muted)
        line.ShadowRowData = row
        line.ShadowRowData.price = price
        line.Paint = function(self, w, h)
          local base = row.enabled and Color(255, 255, 255, 6) or Color(255, 120, 140, 20)
          if self:IsLineSelected() then
            base = row.enabled and THEME.accent or Color(255, 120, 140)
          end
          draw.RoundedBox(0, 0, 0, w, h, base)
        end
      end
      visible = visible + 1
    end

    if IsValid(counter) then
      counter:SetText(string.format("%d / %d Modelle sichtbar", visible, #(entries or {})))
    end
  end

  net.Receive("ST2_TS_ADMIN_CONFIG", function()
    local ui = ShadowTTT2.AdminUI
    if not ui then return end

    local count = net.ReadUInt(12)
    local entries = {}
    for _ = 1, count do
      table.insert(entries, {
        id = net.ReadString(),
        name = net.ReadString(),
        price = net.ReadUInt(12),
        enabled = net.ReadBool(),
        category = net.ReadString(),
        author = net.ReadString(),
      })
    end

    ui.shopEntries = entries
    if IsValid(ui.shopList) then
      populateShopList(ui.shopList, entries, IsValid(ui.shopSearch) and ui.shopSearch:GetText() or "")
      if ui.shopList.GetLineCount and ui.shopList:GetLineCount() > 0 then
        ui.shopList:SelectFirstItem()
      end
    end
  end)

  net.Receive("ST2_PS_ADMIN_CONFIG", function()
    local ui = ShadowTTT2.AdminUI
    if not ui then return end

    local defaultPrice = net.ReadUInt(16)
    local count = net.ReadUInt(16)
    local entries = {}
    for _ = 1, count do
      entries[#entries + 1] = {
        model = net.ReadString(),
        enabled = net.ReadBool(),
        price = net.ReadUInt(16)
      }
    end

    ui.modelDefaultPrice = defaultPrice > 0 and defaultPrice or MODEL_PRICE_DEFAULT
    ui.modelEntries = entries
    if IsValid(ui.modelList) then
      populateModelAdminList(ui.modelList, entries, IsValid(ui.modelSearch) and ui.modelSearch:GetText() or "", IsValid(ui.modelEnabledOnly) and ui.modelEnabledOnly:GetChecked(), ui.modelCounter, ui.modelDefaultPrice)
      if ui.modelList.GetLineCount and ui.modelList:GetLineCount() > 0 then
        ui.modelList:SelectFirstItem()
      end
    end
  end)

  local function destroyAdminPanel()
    local ui = ShadowTTT2.AdminUI
    if ui and IsValid(ui.frame) then
      ui.frame:Remove()
    end
    ShadowTTT2.AdminUI = nil
  end

  local function openAdminPanel()
    destroyAdminPanel()

    local f = createFrame("ShadowTTT2 Adminpanel", 1080, 660)
    f.OnRemove = function()
      ShadowTTT2.AdminUI = nil
    end

    local header = vgui.Create("DLabel", f)
    header:Dock(TOP)
    header:DockMargin(16, 52, 16, 8)
    header:SetTall(24)
    header:SetFont("ST2.Subtitle")
    header:SetTextColor(THEME.muted)
    header:SetText("Moderation & Traitor-Shop Verwaltung")

    local sheet = vgui.Create("DPropertySheet", f)
    sheet:Dock(FILL)
    sheet:DockMargin(12, 0, 12, 12)
    sheet.Paint = function(_, w, h)
      draw.RoundedBox(12, 0, 0, w, h, Color(26, 26, 34, 230))
    end
    function sheet:PaintTab(tab, w, h)
      local active = self:GetActiveTab() == tab
      local col = active and THEME.accent_soft or THEME.panel
      draw.RoundedBox(8, 0, 0, w, h, col)
      draw.SimpleText(tab:GetText(), "ST2.Body", 12, h / 2, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    -- Moderation tab
    local moderation = vgui.Create("DPanel", sheet)
    moderation.Paint = function(_, w, h)
      draw.RoundedBox(12, 0, 0, w, h, Color(26, 26, 34, 0))
    end

    local left = vgui.Create("DPanel", moderation)
    left:Dock(LEFT)
    left:SetWide(480)
    left:DockMargin(12, 12, 8, 12)
    left.Paint = function(_, w, h)
      draw.RoundedBox(10, 0, 0, w, h, Color(34, 34, 44, 230))
    end

    local search = vgui.Create("DTextEntry", left)
    search:Dock(TOP)
    search:DockMargin(10, 10, 10, 8)
    search:SetTall(32)
    search:SetFont("ST2.Body")
    search:SetTextColor(THEME.text)
    if search.SetPlaceholderText then
      search:SetPlaceholderText("Suche nach Name oder SteamID...")
    end
    search.Paint = function(self, w, h)
      draw.RoundedBox(8, 0, 0, w, h, Color(22, 22, 30, 230))
      self:DrawTextEntryText(THEME.text, THEME.accent, THEME.text)
    end

    local list = vgui.Create("DListView", left)
    list:Dock(FILL)
    list:DockMargin(10, 0, 10, 10)
    list:AddColumn("Name")
    list:AddColumn("SteamID")
    list:AddColumn("Points")
    styleListView(list)

    local refresh = vgui.Create("DButton", left)
    refresh:Dock(BOTTOM)
    refresh:DockMargin(10, 0, 10, 10)
    refresh:SetTall(36)
    refresh:SetText("Spielerliste aktualisieren")
    styleButton(refresh)
    refresh.DoClick = function()
      requestAdminPlayerList(list)
    end

    local right = vgui.Create("DPanel", moderation)
    right:Dock(FILL)
    right:DockMargin(8, 12, 12, 12)
    right.Paint = function(_, w, h)
      draw.RoundedBox(10, 0, 0, w, h, Color(34, 34, 44, 230))
    end

    local selectedLabel = vgui.Create("DLabel", right)
    selectedLabel:Dock(TOP)
    selectedLabel:DockMargin(10, 10, 10, 6)
    selectedLabel:SetFont("ST2.Subtitle")
    selectedLabel:SetTextColor(THEME.text)
    selectedLabel:SetText("Kein Spieler ausgewählt")

    local hint = vgui.Create("DLabel", right)
    hint:Dock(TOP)
    hint:DockMargin(10, 0, 10, 10)
    hint:SetFont("ST2.Body")
    hint:SetTextColor(THEME.muted)
    hint:SetWrap(true)
    hint:SetTall(48)
    hint:SetText("Tipp: Doppelklick auf einen Spieler wählt ihn aus. Aktionen werden sofort ausgeführt.")

    local actionScroll = vgui.Create("DScrollPanel", right)
    actionScroll:Dock(FILL)
    actionScroll:DockMargin(10, 0, 10, 10)
    local actionGrid = actionScroll:Add("DIconLayout")
    actionGrid:Dock(FILL)
    actionGrid:DockMargin(0, 4, 0, 4)
    actionGrid:SetSpaceX(10)
    actionGrid:SetSpaceY(10)
    actionGrid:SetStretchWidth(true)
    if IsValid(actionScroll.VBar) then
      actionScroll.VBar.Paint = function(_, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(20, 20, 26, 150))
      end
      actionScroll.VBar.btnGrip.Paint = function(_, w, h)
        draw.RoundedBox(6, 0, 0, w, h, THEME.accent)
      end
    end

    local function getSelectedSid()
      local lineID = list:GetSelectedLine()
      if not lineID then return end
      local line = list:GetLine(lineID)
      return line and line:GetColumnText(2)
    end

    local actions = {
      {label = "Respawn", id = "respawn"},
      {label = "Slay", id = "slay"},
      {label = "Goto", id = "goto"},
      {label = "Bring", id = "bring"},
      {label = "Force Traitor", id = "force_traitor"},
      {label = "Force Innocent", id = "force_innocent"},
    }

    for _, info in ipairs(actions) do
      local btn = createActionButton(actionGrid, info.label, info.id, getSelectedSid, {requireTarget = info.requireTarget})
      btn:SetWide(230)
    end

    local giveWeaponPanel = actionGrid:Add("DPanel")
    giveWeaponPanel:SetSize(230, 190)
    giveWeaponPanel.Paint = function(_, w, h)
      draw.RoundedBox(12, 0, 0, w, h, Color(32, 32, 42, 230))
    end

    local giveWeaponLabel = vgui.Create("DLabel", giveWeaponPanel)
    giveWeaponLabel:Dock(TOP)
    giveWeaponLabel:DockMargin(10, 8, 10, 4)
    giveWeaponLabel:SetTall(20)
    giveWeaponLabel:SetFont("ST2.Subtitle")
    giveWeaponLabel:SetTextColor(THEME.text)
    giveWeaponLabel:SetText("Waffe geben")

    local giveWeaponSearch = vgui.Create("DTextEntry", giveWeaponPanel)
    giveWeaponSearch:Dock(TOP)
    giveWeaponSearch:DockMargin(10, 0, 10, 6)
    giveWeaponSearch:SetTall(26)
    giveWeaponSearch:SetFont("ST2.Body")
    giveWeaponSearch:SetTextColor(THEME.text)
    if giveWeaponSearch.SetPlaceholderText then
      giveWeaponSearch:SetPlaceholderText("Suche oder Klasse eingeben...")
    end
    giveWeaponSearch.Paint = function(self, w, h)
      draw.RoundedBox(8, 0, 0, w, h, Color(22, 22, 30, 230))
      self:DrawTextEntryText(THEME.text, THEME.accent, THEME.text)
    end

    local giveWeaponDropdown = vgui.Create("DComboBox", giveWeaponPanel)
    giveWeaponDropdown:Dock(TOP)
    giveWeaponDropdown:DockMargin(10, 0, 10, 8)
    giveWeaponDropdown:SetTall(34)
    giveWeaponDropdown:SetFont("ST2.Body")
    giveWeaponDropdown:SetValue("Waffe auswählen")
    giveWeaponDropdown:SetSortItems(false)
    if giveWeaponDropdown.SetEditable then
      giveWeaponDropdown:SetEditable(true)
    else
      local textEntry = (giveWeaponDropdown.GetTextEntry and giveWeaponDropdown:GetTextEntry()) or giveWeaponDropdown.TextEntry
      if IsValid(textEntry) and textEntry.SetEditable then
        textEntry:SetEditable(true)
      end
    end
    giveWeaponDropdown:SetTextColor(THEME.text)
    giveWeaponDropdown.OnSelect = function(_, _, _, data)
      giveWeaponDropdown.SelectedClass = data
    end
    giveWeaponDropdown.Paint = function(self, w, h)
      draw.RoundedBox(8, 0, 0, w, h, Color(22, 22, 30, 230))
      draw.SimpleText(self:GetValue(), "ST2.Body", 10, h / 2, THEME.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
      draw.SimpleText("▼", "ST2.Body", w - 14, h / 2, THEME.muted, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    local giveWeaponHint = vgui.Create("DLabel", giveWeaponPanel)
    giveWeaponHint:Dock(TOP)
    giveWeaponHint:DockMargin(10, 0, 10, 6)
    giveWeaponHint:SetTall(18)
    giveWeaponHint:SetFont("ST2.Body")
    giveWeaponHint:SetTextColor(THEME.muted)
    giveWeaponHint:SetText("Alle bekannten Waffen als Auswahl.")

    giveWeaponSearch.OnValueChange = function(_, value)
      local ui = ShadowTTT2.AdminUI
      populateWeaponDropdown(giveWeaponDropdown, ui and ui.weaponList or {}, value, giveWeaponDropdown.SelectedClass)
    end

    local giveWeaponButton = vgui.Create("DButton", giveWeaponPanel)
    giveWeaponButton:Dock(BOTTOM)
    giveWeaponButton:DockMargin(10, 0, 10, 10)
    giveWeaponButton:SetTall(34)
    giveWeaponButton:SetText("Waffe geben")
    styleButton(giveWeaponButton)
    giveWeaponButton.DoClick = function()
      local sid = getSelectedSid()
      local class = giveWeaponDropdown.SelectedClass
      if not class or class == "" then
        class = string.Trim(giveWeaponSearch:GetText() or "")
      end
      if (not class or class == "") and giveWeaponDropdown.GetValue then
        local raw = string.Trim(giveWeaponDropdown:GetValue() or "")
        if raw ~= "" and raw ~= "Keine Waffen gefunden" and not string.find(raw, "Waffe auswählen", 1, true) then
          class = raw
        end
      end
      if not sid or class == "" then return end
      net.Start("ST2_ADMIN_ACTION")
      net.WriteString("giveweapon")
      net.WriteString(sid)
      net.WriteString(class)
      net.SendToServer()
    end

    local pointsPanel = actionGrid:Add("DPanel")
    pointsPanel:SetSize(230, 160)
    pointsPanel.Paint = function(_, w, h)
      draw.RoundedBox(12, 0, 0, w, h, Color(32, 32, 42, 230))
    end

    local pointsLabel = vgui.Create("DLabel", pointsPanel)
    pointsLabel:Dock(TOP)
    pointsLabel:DockMargin(10, 8, 10, 4)
    pointsLabel:SetTall(20)
    pointsLabel:SetFont("ST2.Subtitle")
    pointsLabel:SetTextColor(THEME.text)
    pointsLabel:SetText("Punkte geben")

    local pointsHint = vgui.Create("DLabel", pointsPanel)
    pointsHint:Dock(TOP)
    pointsHint:DockMargin(10, 0, 10, 4)
    pointsHint:SetTall(32)
    pointsHint:SetFont("ST2.Body")
    pointsHint:SetTextColor(THEME.muted)
    pointsHint:SetWrap(true)
    pointsHint:SetText("Gib Punkte an den ausgewählten Spieler.")

    local pointsAmount = vgui.Create("DNumberWang", pointsPanel)
    pointsAmount:Dock(TOP)
    pointsAmount:DockMargin(10, 2, 10, 6)
    pointsAmount:SetTall(30)
    pointsAmount:SetMin(1)
    pointsAmount:SetMax(1000000)
    pointsAmount:SetDecimals(0)
    pointsAmount:SetValue(100)
    pointsAmount:SetFont("ST2.Body")

    local pointsButton = vgui.Create("DButton", pointsPanel)
    pointsButton:Dock(BOTTOM)
    pointsButton:DockMargin(10, 8, 10, 10)
    pointsButton:SetTall(34)
    pointsButton:SetText("Punkte geben")
    styleButton(pointsButton)
    pointsButton.DoClick = function()
      local sid = getSelectedSid()
      local amount = math.floor(tonumber(pointsAmount:GetValue()) or 0)
      if not sid or amount <= 0 then return end
      sendAdminPointsGrant(sid, amount)
    end

    local recoilPanel = actionGrid:Add("DPanel")
    recoilPanel:SetSize(230, 150)
    recoilPanel.Paint = function(_, w, h)
      draw.RoundedBox(12, 0, 0, w, h, Color(32, 32, 42, 230))
    end

    local recoilLabel = vgui.Create("DLabel", recoilPanel)
    recoilLabel:Dock(TOP)
    recoilLabel:DockMargin(10, 8, 10, 2)
    recoilLabel:SetTall(22)
    recoilLabel:SetFont("ST2.Subtitle")
    recoilLabel:SetTextColor(THEME.text)
    recoilLabel:SetText("Rückstoß-Multiplikator")

    local recoilSlider = vgui.Create("DNumSlider", recoilPanel)
    recoilSlider:Dock(TOP)
    recoilSlider:DockMargin(10, 0, 10, 0)
    recoilSlider:SetTall(48)
    recoilSlider:SetText("")
    recoilSlider:SetMin(0)
    recoilSlider:SetMax(1)
    recoilSlider:SetDecimals(2)
    recoilSlider:SetValue(0.35)

    local recoilHint = vgui.Create("DLabel", recoilPanel)
    recoilHint:Dock(TOP)
    recoilHint:DockMargin(10, 4, 10, 6)
    recoilHint:SetTall(28)
    recoilHint:SetWrap(true)
    recoilHint:SetFont("ST2.Body")
    recoilHint:SetTextColor(THEME.muted)
    recoilHint:SetText("Setze 0-1.0 für weniger Rückstoß. Änderungen gelten sofort.")

    local recoilApply = vgui.Create("DButton", recoilPanel)
    recoilApply:Dock(BOTTOM)
    recoilApply:DockMargin(10, 0, 10, 10)
    recoilApply:SetTall(34)
    recoilApply:SetText("Speichern")
    styleButton(recoilApply)
    recoilApply.DoClick = function()
      if not IsValid(recoilSlider) then return end
      sendRecoilMultiplier(recoilSlider:GetValue())
    end

    local speedPanel = actionGrid:Add("DPanel")
    speedPanel:SetSize(230, 230)
    speedPanel.Paint = function(_, w, h)
      draw.RoundedBox(12, 0, 0, w, h, Color(32, 32, 42, 230))
    end

    local speedLabel = vgui.Create("DLabel", speedPanel)
    speedLabel:Dock(TOP)
    speedLabel:DockMargin(10, 8, 10, 2)
    speedLabel:SetTall(22)
    speedLabel:SetFont("ST2.Subtitle")
    speedLabel:SetTextColor(THEME.text)
    speedLabel:SetText("Bewegungsgeschwindigkeit")

    local walkSlider = vgui.Create("DNumSlider", speedPanel)
    walkSlider:Dock(TOP)
    walkSlider:DockMargin(10, 0, 10, 0)
    walkSlider:SetTall(42)
    walkSlider:SetText("Gehen")
    walkSlider:SetMin(50)
    walkSlider:SetMax(500)
    walkSlider:SetDecimals(0)
    walkSlider:SetValue(160)

    local runSlider = vgui.Create("DNumSlider", speedPanel)
    runSlider:Dock(TOP)
    runSlider:DockMargin(10, 0, 10, 0)
    runSlider:SetTall(42)
    runSlider:SetText("Sprinten")
    runSlider:SetMin(100)
    runSlider:SetMax(750)
    runSlider:SetDecimals(0)
    runSlider:SetValue(220)

    local sprintToggle = vgui.Create("DCheckBoxLabel", speedPanel)
    sprintToggle:Dock(TOP)
    sprintToggle:DockMargin(10, 2, 10, 0)
    sprintToggle:SetTall(22)
    sprintToggle:SetText("Unendlich sprinten")
    sprintToggle:SetFont("ST2.Body")
    sprintToggle:SetTextColor(THEME.text)

    local speedHint = vgui.Create("DLabel", speedPanel)
    speedHint:Dock(TOP)
    speedHint:DockMargin(10, 4, 10, 4)
    speedHint:SetTall(28)
    speedHint:SetWrap(true)
    speedHint:SetFont("ST2.Body")
    speedHint:SetTextColor(THEME.muted)
    speedHint:SetText("Serverweite Werte. Neue Spieler spawnen direkt mit den geänderten Geschwindigkeiten.")

    local speedApply = vgui.Create("DButton", speedPanel)
    speedApply:Dock(BOTTOM)
    speedApply:DockMargin(10, 0, 10, 10)
    speedApply:SetTall(34)
    speedApply:SetText("Speichern")
    styleButton(speedApply)
    speedApply.DoClick = function()
      if not (IsValid(walkSlider) and IsValid(runSlider)) then return end
      sendMovementSpeeds(walkSlider:GetValue(), runSlider:GetValue())
      if IsValid(sprintToggle) then
        sendInfiniteSprint(sprintToggle:GetChecked())
      end
    end

    local kickPanel = actionGrid:Add("DPanel")
    kickPanel:SetSize(230, 150)
    kickPanel.Paint = function(_, w, h)
      draw.RoundedBox(12, 0, 0, w, h, Color(32, 32, 42, 230))
    end

    local kickLabel = vgui.Create("DLabel", kickPanel)
    kickLabel:Dock(TOP)
    kickLabel:DockMargin(10, 8, 10, 2)
    kickLabel:SetTall(22)
    kickLabel:SetFont("ST2.Subtitle")
    kickLabel:SetTextColor(THEME.text)
    kickLabel:SetText("Kick")

    local kickReason = vgui.Create("DTextEntry", kickPanel)
    kickReason:Dock(TOP)
    kickReason:DockMargin(10, 0, 10, 8)
    kickReason:SetTall(28)
    kickReason:SetFont("ST2.Body")
    kickReason:SetTextColor(THEME.text)
    kickReason:SetPlaceholderText("Grund (optional)")
    kickReason.Paint = function(self, w, h)
      draw.RoundedBox(8, 0, 0, w, h, Color(22, 22, 30, 230))
      self:DrawTextEntryText(THEME.text, THEME.accent, THEME.text)
    end

    local kickButton = vgui.Create("DButton", kickPanel)
    kickButton:Dock(BOTTOM)
    kickButton:DockMargin(10, 0, 10, 10)
    kickButton:SetTall(34)
    kickButton:SetText("Kicken")
    styleButton(kickButton)
    kickButton.DoClick = function()
      local sid = getSelectedSid()
      if not sid then return end
      net.Start("ST2_ADMIN_ACTION")
      net.WriteString("kick")
      net.WriteString(sid)
      net.WriteString(kickReason:GetText() or "")
      net.SendToServer()
    end

    local banPanel = actionGrid:Add("DPanel")
    banPanel:SetSize(230, 200)
    banPanel.Paint = function(_, w, h)
      draw.RoundedBox(12, 0, 0, w, h, Color(32, 32, 42, 230))
    end

    local banLabel = vgui.Create("DLabel", banPanel)
    banLabel:Dock(TOP)
    banLabel:DockMargin(10, 8, 10, 2)
    banLabel:SetTall(22)
    banLabel:SetFont("ST2.Subtitle")
    banLabel:SetTextColor(THEME.text)
    banLabel:SetText("Ban")

    local banDuration = vgui.Create("DNumberWang", banPanel)
    banDuration:Dock(TOP)
    banDuration:DockMargin(10, 0, 10, 6)
    banDuration:SetTall(30)
    banDuration:SetMin(0)
    banDuration:SetMax(525600)
    banDuration:SetDecimals(0)
    banDuration:SetValue(60)
    banDuration:SetFont("ST2.Body")

    local banReason = vgui.Create("DTextEntry", banPanel)
    banReason:Dock(TOP)
    banReason:DockMargin(10, 0, 10, 6)
    banReason:SetTall(28)
    banReason:SetFont("ST2.Body")
    banReason:SetTextColor(THEME.text)
    banReason:SetPlaceholderText("Grund (optional)")
    banReason.Paint = function(self, w, h)
      draw.RoundedBox(8, 0, 0, w, h, Color(22, 22, 30, 230))
      self:DrawTextEntryText(THEME.text, THEME.accent, THEME.text)
    end

    local banHint = vgui.Create("DLabel", banPanel)
    banHint:Dock(TOP)
    banHint:DockMargin(10, 0, 10, 6)
    banHint:SetTall(28)
    banHint:SetWrap(true)
    banHint:SetFont("ST2.Body")
    banHint:SetTextColor(THEME.muted)
    banHint:SetText("0 Minuten = permanent. Maximal 525600 Minuten (~1 Jahr).")

    local banButton = vgui.Create("DButton", banPanel)
    banButton:Dock(BOTTOM)
    banButton:DockMargin(10, 0, 10, 10)
    banButton:SetTall(34)
    banButton:SetText("Bannen")
    styleButton(banButton)
    banButton.DoClick = function()
      local sid = getSelectedSid()
      if not sid then return end
      local minutes = math.max(0, math.floor(tonumber(banDuration:GetValue()) or 0))
      net.Start("ST2_ADMIN_ACTION")
      net.WriteString("ban")
      net.WriteString(sid)
      net.WriteUInt(minutes, 32)
      net.WriteString(banReason:GetText() or "")
      net.SendToServer()
    end

    list.OnRowSelected = function(_, _, line)
      local name = line:GetColumnText(1)
      local sid = line:GetColumnText(2)
      selectedLabel:SetText(name .. " (" .. sid .. ")")
    end
    list.DoDoubleClick = function(_, lineID, line)
      list:SelectItem(line or list:GetLine(lineID))
    end

    search.OnValueChange = function(_, value)
      local ui = ShadowTTT2.AdminUI
      if not ui or not ui.players then return end
      populateAdminList(list, ui.players, value)
    end

    local banContainer = actionGrid:Add("DPanel")
    banContainer:SetSize(470, 220)
    banContainer.Paint = function(_, w, h)
      draw.RoundedBox(12, 0, 0, w, h, Color(32, 32, 42, 230))
    end

    local banSearch = vgui.Create("DTextEntry", banContainer)
    banSearch:Dock(TOP)
    banSearch:DockMargin(10, 10, 10, 6)
    banSearch:SetTall(26)
    banSearch:SetFont("ST2.Body")
    banSearch:SetTextColor(THEME.text)
    banSearch:SetPlaceholderText("Bans filtern (Name, SteamID, Grund)")
    banSearch.Paint = function(self, w, h)
      draw.RoundedBox(8, 0, 0, w, h, Color(22, 22, 30, 230))
      self:DrawTextEntryText(THEME.text, THEME.accent, THEME.text)
    end

    local banList = vgui.Create("DListView", banContainer)
    banList:Dock(FILL)
    banList:DockMargin(10, 0, 10, 10)
    banList:AddColumn("Name")
    banList:AddColumn("SteamID")
    banList:AddColumn("Grund")
    banList:AddColumn("Läuft ab")
    banList:AddColumn("Gebannt von")
    styleListView(banList)

    local banButtons = vgui.Create("DPanel", banContainer)
    banButtons:Dock(BOTTOM)
    banButtons:DockMargin(10, 0, 10, 8)
    banButtons:SetTall(32)
    banButtons.Paint = function() end

    local refreshBanList = vgui.Create("DButton", banButtons)
    refreshBanList:Dock(LEFT)
    refreshBanList:SetWide(180)
    refreshBanList:SetText("Banliste aktualisieren")
    styleButton(refreshBanList)
    refreshBanList.DoClick = requestBanList

    local unbanButton = vgui.Create("DButton", banButtons)
    unbanButton:Dock(RIGHT)
    unbanButton:SetWide(140)
    unbanButton:SetText("Ban entfernen")
    styleButton(unbanButton)
    unbanButton.DoClick = function()
      if not IsValid(banList) then return end
      local lineID = banList:GetSelectedLine()
      if not lineID then return end
      local line = banList:GetLine(lineID)
      if not IsValid(line) then return end
      local sid = line.ShadowBanSid
      if not sid or sid == "" then return end
      sendUnban(sid)
    end

    banSearch.OnValueChange = function(_, value)
      local ui = ShadowTTT2.AdminUI
      populateBanList(banList, ui and ui.bans or {}, value)
    end

    -- Traitor shop tab
    local shopPanel = vgui.Create("DPanel", sheet)
    shopPanel.Paint = function(_, w, h)
      draw.RoundedBox(12, 0, 0, w, h, Color(26, 26, 34, 0))
    end

    local shopLeft = vgui.Create("DPanel", shopPanel)
    shopLeft:Dock(LEFT)
    shopLeft:SetWide(520)
    shopLeft:DockMargin(12, 12, 8, 12)
    shopLeft.Paint = function(_, w, h)
      draw.RoundedBox(10, 0, 0, w, h, Color(34, 34, 44, 230))
    end

    local shopSearch = vgui.Create("DTextEntry", shopLeft)
    shopSearch:Dock(TOP)
    shopSearch:DockMargin(10, 10, 10, 8)
    shopSearch:SetTall(30)
    shopSearch:SetFont("ST2.Body")
    shopSearch:SetTextColor(THEME.text)
    shopSearch:SetPlaceholderText("Filtere nach Name, ID oder Kategorie")
    shopSearch.Paint = function(self, w, h)
      draw.RoundedBox(8, 0, 0, w, h, Color(22, 22, 30, 230))
      self:DrawTextEntryText(THEME.text, THEME.accent, THEME.text)
    end

    local shopRefresh = vgui.Create("DButton", shopLeft)
    shopRefresh:Dock(BOTTOM)
    shopRefresh:DockMargin(10, 0, 10, 10)
    shopRefresh:SetTall(34)
    shopRefresh:SetText("Workshop erneut scannen")
    styleButton(shopRefresh)
    shopRefresh.DoClick = sendTraitorShopRescan

    local shopAdd = vgui.Create("DPanel", shopLeft)
    shopAdd:Dock(BOTTOM)
    shopAdd:DockMargin(10, 0, 10, 6)
    shopAdd:SetTall(140)
    shopAdd.Paint = function(_, w, h)
      draw.RoundedBox(8, 0, 0, w, h, Color(32, 32, 42, 230))
    end

    local shopAddLabel = vgui.Create("DLabel", shopAdd)
    shopAddLabel:Dock(TOP)
    shopAddLabel:DockMargin(8, 6, 8, 2)
    shopAddLabel:SetFont("ST2.Body")
    shopAddLabel:SetTextColor(THEME.text)
    shopAddLabel:SetText("Manuelles Item hinzufügen (Klassenname)")

    local shopWeaponSearch = vgui.Create("DTextEntry", shopAdd)
    shopWeaponSearch:Dock(TOP)
    shopWeaponSearch:DockMargin(8, 0, 8, 4)
    shopWeaponSearch:SetTall(24)
    shopWeaponSearch:SetFont("ST2.Body")
    shopWeaponSearch:SetTextColor(THEME.text)
    shopWeaponSearch:SetPlaceholderText("Waffe im Dropdown suchen...")
    shopWeaponSearch.Paint = function(self, w, h)
      draw.RoundedBox(8, 0, 0, w, h, Color(22, 22, 30, 230))
      self:DrawTextEntryText(THEME.text, THEME.accent, THEME.text)
    end

    local shopWeaponDropdown = vgui.Create("DComboBox", shopAdd)
    shopWeaponDropdown:Dock(TOP)
    shopWeaponDropdown:DockMargin(8, 0, 8, 6)
    shopWeaponDropdown:SetTall(28)
    shopWeaponDropdown:SetFont("ST2.Body")
    shopWeaponDropdown:SetSortItems(false)
    shopWeaponDropdown:SetValue("Waffe auswählen")
    if shopWeaponDropdown.SetEditable then
      shopWeaponDropdown:SetEditable(true)
    end
    shopWeaponDropdown:SetTextColor(THEME.text)
    shopWeaponDropdown.OnSelect = function(_, _, _, data)
      shopWeaponDropdown.SelectedClass = data
      if IsValid(shopAddEntry) then
        shopAddEntry:SetText(data or "")
      end
    end
    shopWeaponDropdown.Paint = function(self, w, h)
      draw.RoundedBox(8, 0, 0, w, h, Color(22, 22, 30, 230))
      draw.SimpleText(self:GetValue(), "ST2.Body", 8, h / 2, THEME.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
      draw.SimpleText("▼", "ST2.Body", w - 12, h / 2, THEME.muted, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    local shopAddRow = vgui.Create("DPanel", shopAdd)
    shopAddRow:Dock(FILL)
    shopAddRow:DockMargin(8, 0, 8, 8)
    shopAddRow.Paint = function() end

    local shopAddEntry = vgui.Create("DTextEntry", shopAddRow)
    shopAddEntry:Dock(FILL)
    shopAddEntry:SetTall(28)
    shopAddEntry:SetFont("ST2.Body")
    shopAddEntry:SetTextColor(THEME.text)
    shopAddEntry:SetPlaceholderText("z.B. weapon_xy")
    shopAddEntry.Paint = function(self, w, h)
      draw.RoundedBox(8, 0, 0, w, h, Color(22, 22, 30, 230))
      self:DrawTextEntryText(THEME.text, THEME.accent, THEME.text)
    end

    local shopAddButton = vgui.Create("DButton", shopAddRow)
    shopAddButton:Dock(RIGHT)
    shopAddButton:DockMargin(6, 0, 0, 0)
    shopAddButton:SetWide(150)
    shopAddButton:SetText("Hinzufügen")
    styleButton(shopAddButton)
    shopAddButton.DoClick = function()
      local ui = ShadowTTT2.AdminUI
      populateWeaponDropdown(shopWeaponDropdown, ui and ui.weaponList or {}, IsValid(shopWeaponSearch) and shopWeaponSearch:GetText() or "", shopWeaponDropdown.SelectedClass)

      local id = string.Trim(shopAddEntry:GetText() or "")
      if id == "" and shopWeaponDropdown and shopWeaponDropdown.GetValue then
        local selected = string.Trim(shopWeaponDropdown:GetValue() or "")
        if selected ~= "" and selected ~= "Keine Waffen gefunden" and not string.find(selected, "Waffe auswählen", 1, true) then
          id = selected
        end
      end
      if id == "" and shopWeaponDropdown then
        id = shopWeaponDropdown.SelectedClass or ""
      end
      if id == "" then return end
      sendTraitorShopAdd(id)
      shopAddEntry:SetText("")
    end

    -- Keep the fill list after bottom-docked controls so the add/refresh buttons remain visible.
    local shopList = vgui.Create("DListView", shopLeft)
    shopList:Dock(FILL)
    shopList:DockMargin(10, 0, 10, 10)
    shopList:AddColumn("Name")
    shopList:AddColumn("ID")
    shopList:AddColumn("Kategorie")
    shopList:AddColumn("Preis")
    shopList:AddColumn("Status")
    styleListView(shopList)

    local shopRight = vgui.Create("DPanel", shopPanel)
    shopRight:Dock(FILL)
    shopRight:DockMargin(8, 12, 12, 12)
    shopRight.Paint = function(_, w, h)
      draw.RoundedBox(10, 0, 0, w, h, Color(34, 34, 44, 230))
    end

    local shopTitle = vgui.Create("DLabel", shopRight)
    shopTitle:Dock(TOP)
    shopTitle:DockMargin(10, 10, 10, 6)
    shopTitle:SetFont("ST2.Subtitle")
    shopTitle:SetTextColor(THEME.text)
    shopTitle:SetText("Kein Item ausgewählt")

    local shopMeta = vgui.Create("DLabel", shopRight)
    shopMeta:Dock(TOP)
    shopMeta:DockMargin(10, 0, 10, 10)
    shopMeta:SetFont("ST2.Body")
    shopMeta:SetTextColor(THEME.muted)
    shopMeta:SetWrap(true)
    shopMeta:SetTall(48)
    shopMeta:SetText("Tippe links, um Items zu filtern. Rechtsklick auf einen Eintrag schaltet ihn um.")

    local priceRow = vgui.Create("DPanel", shopRight)
    priceRow:Dock(TOP)
    priceRow:DockMargin(10, 0, 10, 6)
    priceRow:SetTall(38)
    priceRow.Paint = function() end

    local priceWang = vgui.Create("DNumberWang", priceRow)
    priceWang:Dock(LEFT)
    priceWang:SetWide(120)
    priceWang:SetMin(0)
    priceWang:SetMax(1000)
    priceWang:SetDecimals(0)
    priceWang:SetValue(1)
    priceWang:SetFont("ST2.Body")

    local priceApply = vgui.Create("DButton", priceRow)
    priceApply:Dock(LEFT)
    priceApply:DockMargin(10, 0, 0, 0)
    priceApply:SetWide(140)
    priceApply:SetText("Preis speichern")
    styleButton(priceApply)

    local priceReset = vgui.Create("DButton", priceRow)
    priceReset:Dock(LEFT)
    priceReset:DockMargin(10, 0, 0, 0)
    priceReset:SetWide(140)
    priceReset:SetText("Standardpreis")
    styleButton(priceReset)

    local toggleButton = vgui.Create("DButton", shopRight)
    toggleButton:Dock(TOP)
    toggleButton:DockMargin(10, 6, 10, 10)
    toggleButton:SetTall(40)
    toggleButton:SetText("Item aktivieren/deaktivieren")
    styleButton(toggleButton)

    local selectedRow
    local function updateSelected(line)
      selectedRow = line and line.ShadowRowData
      if not selectedRow then
        shopTitle:SetText("Kein Item ausgewählt")
        shopMeta:SetText("Tippe links, um Items zu filtern. Rechtsklick auf einen Eintrag schaltet ihn um.")
        return
      end

      shopTitle:SetText(string.format("%s (%s)", selectedRow.name or selectedRow.id, selectedRow.id))
      shopMeta:SetText(string.format("Kategorie: %s | Status: %s | Autor: %s", selectedRow.category or "workshop", selectedRow.enabled and "Aktiv" or "Deaktiviert", selectedRow.author or "Unbekannt"))
      priceWang:SetValue(selectedRow.price or 1)
      toggleButton:SetText(selectedRow.enabled and "Item deaktivieren" or "Item aktivieren")
    end

    shopList.OnRowSelected = function(_, _, line)
      updateSelected(line)
    end
    shopList.DoDoubleClick = function(_, _, line)
      if not IsValid(line) then return end
      sendTraitorShopToggle(line:GetColumnText(2))
    end

    priceApply.DoClick = function()
      if not selectedRow then return end
      sendTraitorShopPrice(selectedRow.id, priceWang:GetValue(), false)
    end

    priceReset.DoClick = function()
      if not selectedRow then return end
      sendTraitorShopPrice(selectedRow.id, 0, true)
    end

    toggleButton.DoClick = function()
      if not selectedRow then return end
      sendTraitorShopToggle(selectedRow.id)
    end

    shopSearch.OnValueChange = function(_, value)
      local ui = ShadowTTT2.AdminUI
      if not ui then return end
      populateShopList(shopList, ui.shopEntries or {}, value)
    end

    shopWeaponSearch.OnValueChange = function(_, value)
      local ui = ShadowTTT2.AdminUI
      populateWeaponDropdown(shopWeaponDropdown, ui and ui.weaponList or {}, value, shopWeaponDropdown.SelectedClass)
    end

    sheet:AddSheet("Moderation", moderation, "icon16/user.png")
    sheet:AddSheet("Traitor Shop", shopPanel, "icon16/plugin.png")

    local modelPanel = vgui.Create("DPanel", sheet)
    modelPanel.Paint = function(_, w, h)
      draw.RoundedBox(12, 0, 0, w, h, Color(26, 26, 34, 0))
    end

    local modelLeft = vgui.Create("DPanel", modelPanel)
    modelLeft:Dock(LEFT)
    modelLeft:SetWide(520)
    modelLeft:DockMargin(12, 12, 8, 12)
    modelLeft.Paint = function(_, w, h)
      draw.RoundedBox(10, 0, 0, w, h, Color(34, 34, 44, 230))
    end

    local modelSearch = vgui.Create("DTextEntry", modelLeft)
    modelSearch:Dock(TOP)
    modelSearch:DockMargin(10, 10, 10, 6)
    modelSearch:SetTall(30)
    modelSearch:SetFont("ST2.Body")
    modelSearch:SetTextColor(THEME.text)
    modelSearch:SetPlaceholderText("Modellpfad filtern...")
    modelSearch.Paint = function(self, w, h)
      draw.RoundedBox(8, 0, 0, w, h, Color(22, 22, 30, 230))
      self:DrawTextEntryText(THEME.text, THEME.accent, THEME.text)
    end

    local modelEnabledOnly = vgui.Create("DCheckBoxLabel", modelLeft)
    modelEnabledOnly:Dock(TOP)
    modelEnabledOnly:DockMargin(12, 0, 12, 6)
    modelEnabledOnly:SetTall(20)
    modelEnabledOnly:SetText("Nur aktivierte Modelle anzeigen")
    modelEnabledOnly:SetFont("ST2.Body")
    modelEnabledOnly:SetTextColor(THEME.muted)

    local modelCounter = vgui.Create("DLabel", modelLeft)
    modelCounter:Dock(BOTTOM)
    modelCounter:DockMargin(10, 0, 10, 10)
    modelCounter:SetTall(18)
    modelCounter:SetFont("ST2.Body")
    modelCounter:SetTextColor(THEME.muted)
    modelCounter:SetText("0 Modelle sichtbar")

    local modelList = vgui.Create("DListView", modelLeft)
    modelList:Dock(FILL)
    modelList:DockMargin(10, 0, 10, 10)
    modelList:AddColumn("Modell")
    modelList:AddColumn("Preis")
    modelList:AddColumn("Status")
    styleListView(modelList)
    modelEnabledOnly.OnChange = function()
      local ui = ShadowTTT2.AdminUI
      populateModelAdminList(modelList, ui and ui.modelEntries or {}, IsValid(modelSearch) and modelSearch:GetText() or "", modelEnabledOnly:GetChecked(), modelCounter, ui and ui.modelDefaultPrice)
    end

    local modelRight = vgui.Create("DPanel", modelPanel)
    modelRight:Dock(FILL)
    modelRight:DockMargin(8, 12, 12, 12)
    modelRight.Paint = function(_, w, h)
      draw.RoundedBox(10, 0, 0, w, h, Color(34, 34, 44, 230))
    end

    local modelTitle = vgui.Create("DLabel", modelRight)
    modelTitle:Dock(TOP)
    modelTitle:DockMargin(10, 10, 10, 4)
    modelTitle:SetTall(22)
    modelTitle:SetFont("ST2.Subtitle")
    modelTitle:SetTextColor(THEME.text)
    modelTitle:SetText("Kein Modell ausgewählt")

    local modelInfo = vgui.Create("DLabel", modelRight)
    modelInfo:Dock(TOP)
    modelInfo:DockMargin(10, 0, 10, 6)
    modelInfo:SetTall(36)
    modelInfo:SetWrap(true)
    modelInfo:SetFont("ST2.Body")
    modelInfo:SetTextColor(THEME.muted)
    modelInfo:SetText("Aktiviere oder verstecke Modelle für den F3-Shop. Doppelklick in der Liste toggelt den Status.")

    local modelToggle = vgui.Create("DCheckBoxLabel", modelRight)
    modelToggle:Dock(TOP)
    modelToggle:DockMargin(10, 2, 10, 8)
    modelToggle:SetTall(20)
    modelToggle:SetText("Im F3-Shop anzeigen")
    modelToggle:SetFont("ST2.Body")
    modelToggle:SetTextColor(THEME.text)

    local modelPriceLabel = vgui.Create("DLabel", modelRight)
    modelPriceLabel:Dock(TOP)
    modelPriceLabel:DockMargin(10, 0, 10, 2)
    modelPriceLabel:SetTall(20)
    modelPriceLabel:SetFont("ST2.Body")
    modelPriceLabel:SetTextColor(THEME.muted)
    modelPriceLabel:SetText("Preis: Standard")

    local modelPriceRow = vgui.Create("DPanel", modelRight)
    modelPriceRow:Dock(TOP)
    modelPriceRow:DockMargin(10, 0, 10, 8)
    modelPriceRow:SetTall(38)
    modelPriceRow.Paint = function(_, w, h)
      draw.RoundedBox(8, 0, 0, w, h, Color(28, 28, 36, 220))
    end

    local modelPriceEntry = vgui.Create("DNumberWang", modelPriceRow)
    modelPriceEntry:Dock(LEFT)
    modelPriceEntry:DockMargin(8, 6, 6, 6)
    modelPriceEntry:SetWide(120)
    modelPriceEntry:SetMin(0)
    modelPriceEntry:SetMax(65535)
    modelPriceEntry:SetDecimals(0)
    modelPriceEntry:SetFont("ST2.Body")

    local modelPriceSave = vgui.Create("DButton", modelPriceRow)
    modelPriceSave:Dock(LEFT)
    modelPriceSave:DockMargin(0, 6, 6, 6)
    modelPriceSave:SetWide(160)
    modelPriceSave:SetText("Preis speichern")
    styleButton(modelPriceSave)

    local modelPriceReset = vgui.Create("DButton", modelPriceRow)
    modelPriceReset:Dock(FILL)
    modelPriceReset:DockMargin(0, 6, 8, 6)
    modelPriceReset:SetText("Standardpreis nutzen")
    styleButton(modelPriceReset)

    local modelPreview = vgui.Create("DModelPanel", modelRight)
    modelPreview:Dock(FILL)
    modelPreview:DockMargin(10, 0, 10, 10)
    modelPreview:SetFOV(36)
    modelPreview:SetCamPos(Vector(90, 0, 64))
    modelPreview:SetLookAt(Vector(0, 0, 60))
    modelPreview:SetDirectionalLight(BOX_TOP, color_white)
    modelPreview:SetDirectionalLight(BOX_FRONT, Color(160, 180, 255))
    modelPreview.LayoutEntity = function(self, ent)
      self:RunAnimation()
      ent:SetAngles(Angle(0, CurTime() * 15 % 360, 0))
    end

    local selectedModel
    local function getDefaultModelPrice()
      local ui = ShadowTTT2.AdminUI
      return (ui and ui.modelDefaultPrice) or MODEL_PRICE_DEFAULT
    end
    local suppressToggle
    local function updateModelSelection(line)
      selectedModel = line and line.ShadowRowData
      if not selectedModel then
        modelTitle:SetText("Kein Modell ausgewählt")
        modelInfo:SetText("Aktiviere oder verstecke Modelle für den F3-Shop. Doppelklick in der Liste toggelt den Status.")
        modelPriceLabel:SetText(string.format("Preis: %d Punkte (Standard)", getDefaultModelPrice()))
        if IsValid(modelPriceEntry) then modelPriceEntry:SetValue(getDefaultModelPrice()) end
        suppressToggle = true
        if IsValid(modelToggle) and modelToggle.SetChecked then modelToggle:SetChecked(false) end
        suppressToggle = false
        if IsValid(modelPreview) then modelPreview:SetModel("models/player/kleiner.mdl") end
        return
      end

      modelTitle:SetText(selectedModel.model or "Unbekanntes Modell")
      modelInfo:SetText(selectedModel.enabled and "Status: Aktiv im F3-Shop" or "Status: Versteckt im F3-Shop")
      local price = math.max(0, math.floor(selectedModel.price or getDefaultModelPrice()))
      modelPriceLabel:SetText(string.format("Preis: %d Punkte", price))
      if IsValid(modelPriceEntry) then modelPriceEntry:SetValue(price) end
      suppressToggle = true
      if IsValid(modelToggle) and modelToggle.SetChecked then modelToggle:SetChecked(selectedModel.enabled) end
      suppressToggle = false
      if IsValid(modelPreview) then modelPreview:SetModel(selectedModel.model or "") end
    end

    modelPriceSave.DoClick = function()
      if not selectedModel then return end
      sendPointshopPrice(selectedModel.model, modelPriceEntry:GetValue(), false)
    end

    modelPriceReset.DoClick = function()
      if not selectedModel then return end
      sendPointshopPrice(selectedModel.model, getDefaultModelPrice(), true)
    end

    modelList.OnRowSelected = function(_, _, line)
      updateModelSelection(line)
    end
    modelList.DoDoubleClick = function(_, _, line)
      if not IsValid(line) or not line.ShadowRowData then return end
      sendPointshopToggle(line.ShadowRowData.model)
    end

    modelSearch.OnValueChange = function(_, value)
      local ui = ShadowTTT2.AdminUI
      populateModelAdminList(modelList, ui and ui.modelEntries or {}, value, IsValid(modelEnabledOnly) and modelEnabledOnly:GetChecked(), modelCounter, ui and ui.modelDefaultPrice)
    end

    modelToggle.OnChange = function(_, state)
      if suppressToggle then return end
      if not selectedModel then return end
      sendPointshopToggle(selectedModel.model)
    end

    sheet:AddSheet("F3 Modelle", modelPanel, "icon16/user_red.png")

    local mapPanel = vgui.Create("DPanel", sheet)
    mapPanel.Paint = function(_, w, h)
      draw.RoundedBox(12, 0, 0, w, h, Color(26, 26, 34, 0))
    end

    local mapContainer = vgui.Create("DPanel", mapPanel)
    mapContainer:Dock(FILL)
    mapContainer:DockMargin(12, 12, 12, 12)
    mapContainer.Paint = function(_, w, h)
      draw.RoundedBox(10, 0, 0, w, h, Color(34, 34, 44, 230))
    end

    local mapHeader = vgui.Create("DLabel", mapContainer)
    mapHeader:Dock(TOP)
    mapHeader:DockMargin(12, 12, 12, 4)
    mapHeader:SetTall(24)
    mapHeader:SetFont("ST2.Subtitle")
    mapHeader:SetTextColor(THEME.text)
    mapHeader:SetText("Map Auswahl")

    local mapCurrent = vgui.Create("DLabel", mapContainer)
    mapCurrent:Dock(TOP)
    mapCurrent:DockMargin(12, 0, 12, 8)
    mapCurrent:SetTall(20)
    mapCurrent:SetFont("ST2.Body")
    mapCurrent:SetTextColor(THEME.muted)
    mapCurrent:SetText("Aktuelle Map: wird geladen...")

    local mapHint = vgui.Create("DLabel", mapContainer)
    mapHint:Dock(TOP)
    mapHint:DockMargin(12, 0, 12, 10)
    mapHint:SetTall(40)
    mapHint:SetWrap(true)
    mapHint:SetFont("ST2.Body")
    mapHint:SetTextColor(THEME.muted)
    mapHint:SetText("Wähle eine Map aus der Liste aus. Der Wechsel erfolgt nach kurzer Verzögerung für alle Spieler.")

    local mapDropdown = vgui.Create("DComboBox", mapContainer)
    mapDropdown:Dock(TOP)
    mapDropdown:DockMargin(12, 0, 12, 10)
    mapDropdown:SetTall(34)
    mapDropdown:SetFont("ST2.Body")
    mapDropdown:SetSortItems(false)
    mapDropdown:SetValue("Maps werden geladen...")
    mapDropdown:SetTextColor(THEME.text)
    mapDropdown.OnSelect = function(_, _, value, data)
      mapDropdown.SelectedMap = data or value
    end
    mapDropdown.Paint = function(self, w, h)
      draw.RoundedBox(8, 0, 0, w, h, Color(22, 22, 30, 230))
      draw.SimpleText(self:GetValue(), "ST2.Body", 10, h / 2, THEME.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
      draw.SimpleText("▼", "ST2.Body", w - 14, h / 2, THEME.muted, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    local mapButtons = vgui.Create("DPanel", mapContainer)
    mapButtons:Dock(TOP)
    mapButtons:DockMargin(12, 0, 12, 10)
    mapButtons:SetTall(38)
    mapButtons.Paint = function() end

    local mapRefresh = vgui.Create("DButton", mapButtons)
    mapRefresh:Dock(LEFT)
    mapRefresh:SetWide(160)
    mapRefresh:SetText("Maps aktualisieren")
    styleButton(mapRefresh)
    mapRefresh.DoClick = requestMapList

    local mapApply = vgui.Create("DButton", mapButtons)
    mapApply:Dock(RIGHT)
    mapApply:SetWide(200)
    mapApply:SetText("Map wechseln")
    styleButton(mapApply)
    mapApply.DoClick = function()
      local target = mapDropdown.SelectedMap or ""
      if (not target or target == "") and mapDropdown.GetValue then
        local raw = string.Trim(mapDropdown:GetValue() or "")
        if raw ~= "" and raw ~= "Keine Maps gefunden" and not string.find(raw, "auswählen", 1, true) then
          target = raw
        end
      end
      if not target or target == "" then return end
      sendMapChange(target)
    end

    sheet:AddSheet("Maps", mapPanel, "icon16/map.png")

    ShadowTTT2.AdminUI = {
      frame = f,
      list = list,
      search = search,
      players = {},
      shopList = shopList,
      shopSearch = shopSearch,
      shopEntries = {},
      recoilSlider = recoilSlider,
      walkSlider = walkSlider,
      runSlider = runSlider,
      infiniteSprintCheck = sprintToggle,
      weaponDropdown = giveWeaponDropdown,
      weaponSearch = giveWeaponSearch,
      shopWeaponDropdown = shopWeaponDropdown,
      shopWeaponSearch = shopWeaponSearch,
      weaponList = {},
      banList = banList,
      banSearch = banSearch,
      bans = {},
      mapDropdown = mapDropdown,
      mapCurrentLabel = mapCurrent,
      maps = {},
      modelList = modelList,
      modelSearch = modelSearch,
      modelEntries = {},
      modelEnabledOnly = modelEnabledOnly,
      modelCounter = modelCounter,
      modelToggle = modelToggle,
      modelPreview = modelPreview,
      modelPriceEntry = modelPriceEntry,
      modelPriceLabel = modelPriceLabel,
      modelDefaultPrice = MODEL_PRICE_DEFAULT,
    }

    populateWeaponDropdown(giveWeaponDropdown, {}, "", nil)
    populateWeaponDropdown(shopWeaponDropdown, {}, "", nil)
    requestAdminPlayerList(list)
    sendTraitorShopRequest()
    sendPointshopAdminRequest()
    requestRecoilMultiplier()
    requestMovementSpeeds()
    requestInfiniteSprint()
    requestWeaponList()
    requestMapList()
    populateBanList(banList, {}, "")
    requestBanList()
  end

  net.Receive("ST2_ADMIN_OPEN", openAdminPanel)
end

local pointshopState = {
  models = {},
  activeModel = "",
  requestPending = false,
  openPending = false,
  points = 0,
  spinPending = false,
  defaultPrice = MODEL_PRICE_DEFAULT
}

local function formatSelectedLabel(mdl, active)
  if not mdl or mdl == "" then
    return "Kein Modell ausgewählt"
  end

  if active and active ~= "" and mdl == active then
    return mdl .. " (aktuell)"
  end

  return mdl
end

local function requestPointsBalance()
  net.Start("ST2_POINTS_REQUEST")
  net.SendToServer()
end

local updateEquipButton

local function updatePointsDisplay(ui, balance)
  if not ui then return end
  ui.points = balance or 0
  if IsValid(ui.pointsLabel) then
    ui.pointsLabel:SetText(string.format("Punkte: %d", ui.points))
  end
  if IsValid(ui.slotBalance) then
    ui.slotBalance:SetText(string.format("Aktueller Kontostand: %d", ui.points))
  end
  if updateEquipButton then
    updateEquipButton(ui)
  end
end

local function showSlotResult(ui, symbols, text, payout)
  if not ui then return end
  if ui.stopSlotSpin then ui.stopSlotSpin() end
  local win = (payout or 0) > 0

  if IsValid(ui.slotResult) then
    ui.slotResult:SetText(text or "")
    ui.slotResult:SetTextColor(win and THEME.accent_soft or THEME.muted)
  end

  if istable(ui.slotReels) then
    for i = 1, 3 do
      local reel = ui.slotReels[i]
      if not reel then continue end
      local sym = istable(symbols) and symbols[i] or nil
      local midIcon = resolveSlotSymbol(sym)
      local topIcon = randomSlotSymbol()
      local bottomIcon = randomSlotSymbol()

      if reel.setSymbols then
        reel:setSymbols(topIcon, midIcon, bottomIcon, win)
      end
    end
  end
end

local function unlockSpinButton(ui)
  if not ui or not IsValid(ui.spinButton) then return end
  if pointshopState.spinPending or ui.slotSpinActive then return end

  ui.spinButton:SetEnabled(true)
  ui.spinButton:SetText("Spin!")
end

local function finishSpin(ui)
  pointshopState.spinPending = false
  if ui then
    ui.spinFinishedAt = CurTime()
  end
  if not ui then return end
  unlockSpinButton(ui)
end

local function refreshPointshopList(ui, filter)
  if not IsValid(ui.list) then return end
  ui.list:Clear()

  local q = string.Trim(string.lower(filter or ""))
  local visible = 0
  local fallbackPrice = ui.defaultPrice or pointshopState.defaultPrice or MODEL_PRICE_DEFAULT
  for _, entry in ipairs(ui.models or {}) do
    local mdl = entry.model or entry
    local price = math.max(0, math.floor(entry.price or fallbackPrice))
    if q == "" or string.find(string.lower(mdl), q, 1, true) then
      local line = ui.list:AddLine(mdl, string.format("%d Punkte", price))
      if IsValid(line) then
        if line.SetTextColor then
          line:SetTextColor(mdl == ui.activeModel and THEME.accent_soft or THEME.text)
        else
          for _, col in ipairs(line.Columns or {}) do
            if IsValid(col) and col.SetTextColor then
              col:SetTextColor(mdl == ui.activeModel and THEME.accent_soft or THEME.text)
            end
          end
        end
        line.ShadowModelPath = mdl
        line.ShadowModelPrice = price
        line.Paint = function(self, w, h)
          local bg = self:IsLineSelected() and THEME.accent or Color(255, 255, 255, 6)
          if mdl == ui.activeModel then
            bg = self:IsLineSelected() and THEME.accent or Color(120, 200, 255, 24)
          end
          draw.RoundedBox(0, 0, 0, w, h, bg)
        end
      end
      visible = visible + 1
    end
  end

  if IsValid(ui.counter) then
    ui.counter:SetText(string.format("%d / %d Modelle sichtbar", visible, #(ui.models or {})))
  end
end

updateEquipButton = function(ui)
  if not ui or not IsValid(ui.equipButton) then return end
  local mdl = ui.currentModel
  local price = ui.currentPrice or ui.defaultPrice or pointshopState.defaultPrice or MODEL_PRICE_DEFAULT
  local alreadyActive = mdl ~= nil and mdl == ui.activeModel
  local affordable = (pointshopState.points or 0) >= price

  if not mdl or mdl == "" then
    ui.equipButton:SetEnabled(false)
    ui.equipButton:SetText("Modell auswählen")
    return
  end

  ui.equipButton:SetEnabled(alreadyActive or affordable)
  if alreadyActive then
    ui.equipButton:SetText("Bereits aktiv")
  elseif price <= 0 then
    ui.equipButton:SetText("Kostenlos auswählen")
  else
    ui.equipButton:SetText(string.format("Auswählen (%d Punkte)", price))
  end
end

local function selectModel(ui, mdl, price)
  if not mdl or mdl == "" then return end
  if IsValid(ui.preview) then
    ui.preview:SetModel(mdl)
  end
  if IsValid(ui.selectedLabel) then
    ui.selectedLabel:SetText(formatSelectedLabel(mdl, ui.activeModel))
  end
  if IsValid(ui.priceLabel) then
    local cost = math.max(0, math.floor(price or ui.defaultPrice or pointshopState.defaultPrice or MODEL_PRICE_DEFAULT))
    ui.priceLabel:SetText(string.format("Preis: %d Punkte", cost))
  end
  if IsValid(ui.equipButton) then
    ui.equipButton.DoClick = function()
      net.Start("ST2_PS_EQUIP")
      net.WriteString(mdl)
      net.SendToServer()
    end
  end
  ui.currentModel = mdl
  ui.currentPrice = math.max(0, math.floor(price or ui.defaultPrice or pointshopState.defaultPrice or MODEL_PRICE_DEFAULT))
  updateEquipButton(ui)
end

local function applyPointshopData(ui, models, activeModel, defaultPrice)
  ui.models = models or {}
  ui.activeModel = activeModel or ""
  ui.defaultPrice = defaultPrice or ui.defaultPrice or pointshopState.defaultPrice or MODEL_PRICE_DEFAULT
  local searchText = IsValid(ui.search) and ui.search:GetText() or ""
  refreshPointshopList(ui, searchText)

  local function selectActiveOrFirst()
    if not IsValid(ui.list) then return end
    local lineCount = 0
    if ui.list.GetLineCount then
      lineCount = ui.list:GetLineCount()
    elseif ui.list.GetLines then
      lineCount = #(ui.list:GetLines() or {})
    end
    if ui.activeModel and ui.activeModel ~= "" then
      for i = 1, lineCount do
        local line = ui.list:GetLine(i)
        if IsValid(line) and line:GetColumnText(1) == ui.activeModel then
          ui.list:SelectItem(line)
          return
        end
      end
    end
    if lineCount > 0 and ui.list.SelectFirstItem then
      ui.list:SelectFirstItem()
    end
  end

  selectActiveOrFirst()
  updatePointsDisplay(ui, pointshopState.points)
end

local function openPointshop(models, activeModel, defaultPrice)
  if IsValid(activePointshopFrame) then
    if activePointshopFrame.ShadowPointshopUI then
      activePointshopFrame.ShadowPointshopUI.defaultPrice = defaultPrice or activePointshopFrame.ShadowPointshopUI.defaultPrice or pointshopState.defaultPrice or MODEL_PRICE_DEFAULT
      applyPointshopData(activePointshopFrame.ShadowPointshopUI, models, activeModel, activePointshopFrame.ShadowPointshopUI.defaultPrice)
    end
    activePointshopFrame:MakePopup()
    activePointshopFrame:RequestFocus()
    requestPointsBalance()
    return
  end

  local f = createFrame("ShadowTTT2 Pointshop", 1040, 640)
  activePointshopFrame = f
  f.OnRemove = function()
    if activePointshopFrame == f then
      local ui = activePointshopFrame.ShadowPointshopUI
      if ui and ui.stopSlotSpin then
        ui.stopSlotSpin()
      end
      activePointshopFrame = nil
    end
  end

  local header = vgui.Create("DLabel", f)
  header:SetPos(16, 52)
  header:SetSize(760, 24)
  header:SetFont("ST2.Subtitle")
  header:SetTextColor(THEME.muted)
  header:SetText("Wähle ein Modell, drehe es in der Vorschau und rüste es direkt aus.")

  local container = vgui.Create("DPanel", f)
  container:SetPos(12, 80)
  container:SetSize(1016, 548)
  container.Paint = function(_, w, h)
    draw.RoundedBox(12, 0, 0, w, h, Color(26, 26, 34, 230))
  end

  local sheets = vgui.Create("DPropertySheet", container)
  sheets:Dock(FILL)
  sheets:SetFadeTime(0)
  sheets.Paint = function(_, w, h)
    draw.RoundedBox(10, 8, 4, w - 16, h - 12, Color(20, 20, 26, 200))
  end
  function sheets:PaintTab(tab, w, h)
    local active = self:GetActiveTab() == tab
    local col = active and THEME.accent_soft or Color(40, 40, 52, 200)
    draw.RoundedBox(8, 0, 0, w, h, col)
    draw.SimpleText(tab:GetText(), "ST2.Body", 12, h / 2, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
  end

  local function buildModelTab()
    local panel = vgui.Create("DPanel", sheets)
    panel:Dock(FILL)
    panel.Paint = function(_, w, h)
      draw.RoundedBox(10, 0, 0, w, h, Color(26, 26, 34, 230))
    end

    local left = vgui.Create("DPanel", panel)
    left:Dock(LEFT)
    left:SetWide(430)
    left:DockMargin(12, 12, 8, 12)
    left.Paint = function(_, w, h)
      draw.RoundedBox(10, 0, 0, w, h, Color(34, 34, 44, 230))
    end

    local search = vgui.Create("DTextEntry", left)
    search:Dock(TOP)
    search:DockMargin(10, 10, 10, 8)
    search:SetTall(32)
    search:SetFont("ST2.Body")
    search:SetTextColor(THEME.text)
    search:SetPlaceholderText("Suche nach Modellpfad...")
    search.Paint = function(self, w, h)
      draw.RoundedBox(8, 0, 0, w, h, Color(22, 22, 30, 230))
      self:DrawTextEntryText(THEME.text, THEME.accent, THEME.text)
    end

    local listv = vgui.Create("DListView", left)
    listv:Dock(FILL)
    listv:DockMargin(10, 0, 10, 10)
    listv:AddColumn("Model")
    listv:AddColumn("Preis")
    if listv.SetDataHeight then listv:SetDataHeight(26) end
    if listv.SetHeaderHeight then listv:SetHeaderHeight(30) end
    listv.Paint = function(_, w, h)
      draw.RoundedBox(10, 0, 0, w, h, THEME.panel)
    end
    for _, col in ipairs(listv.Columns or {}) do
      if IsValid(col.Header) then
        col.Header:SetFont("ST2.Subtitle")
        col.Header:SetTextColor(THEME.text)
        col.Header.Paint = function(_, w, h)
          draw.RoundedBox(0, 0, 0, w, h, Color(38, 38, 46, 240))
        end
      end
    end

    local counter = vgui.Create("DLabel", left)
    counter:Dock(BOTTOM)
    counter:DockMargin(10, 0, 10, 12)
    counter:SetTall(20)
    counter:SetFont("ST2.Body")
    counter:SetTextColor(THEME.muted)

    local right = vgui.Create("DPanel", panel)
    right:Dock(FILL)
    right:DockMargin(8, 12, 12, 12)
    right.Paint = function(_, w, h)
      draw.RoundedBox(10, 0, 0, w, h, Color(34, 34, 44, 230))
    end

    local pointsBar = vgui.Create("DPanel", right)
    pointsBar:Dock(TOP)
    pointsBar:SetTall(38)
    pointsBar:DockMargin(10, 10, 10, 0)
    pointsBar.Paint = function(_, w, h)
      draw.RoundedBox(8, 0, 0, w, h, Color(28, 28, 36, 220))
    end

    local pointsLabel = vgui.Create("DLabel", pointsBar)
    pointsLabel:Dock(LEFT)
    pointsLabel:DockMargin(8, 8, 8, 8)
    pointsLabel:SetFont("ST2.Subtitle")
    pointsLabel:SetTextColor(THEME.text)
    pointsLabel:SetText("Punkte: lädt...")

    local refreshPoints = vgui.Create("DButton", pointsBar)
    refreshPoints:Dock(RIGHT)
    refreshPoints:DockMargin(8, 6, 8, 6)
    refreshPoints:SetWide(160)
    refreshPoints:SetText("Punkte aktualisieren")
    styleButton(refreshPoints)
    refreshPoints.DoClick = function()
      requestPointsBalance()
    end

    local previewTitle = vgui.Create("DLabel", right)
    previewTitle:Dock(TOP)
    previewTitle:DockMargin(10, 8, 10, 6)
    previewTitle:SetFont("ST2.Subtitle")
    previewTitle:SetTextColor(THEME.text)
    previewTitle:SetText("Vorschau")

    local preview = vgui.Create("DModelPanel", right)
    preview:Dock(FILL)
    preview:DockMargin(10, 0, 10, 10)
    preview:SetFOV(40)
    preview:SetCamPos(Vector(90, 0, 64))
    preview:SetLookAt(Vector(0, 0, 60))
    preview:SetDirectionalLight(BOX_TOP, Color(255, 255, 255))
    preview:SetDirectionalLight(BOX_FRONT, Color(180, 200, 255))
    preview.LayoutEntity = function(self, ent)
      self:RunAnimation()
      ent:SetAngles(Angle(0, CurTime() * 20 % 360, 0))
    end

    local equip = vgui.Create("DButton", right)
    equip:Dock(BOTTOM)
    equip:DockMargin(10, 0, 10, 12)
    equip:SetTall(42)
    equip:SetText("Modell auswählen")
    styleButton(equip)

    local priceLabel = vgui.Create("DLabel", right)
    priceLabel:Dock(BOTTOM)
    priceLabel:DockMargin(10, 0, 10, 6)
    priceLabel:SetTall(18)
    priceLabel:SetFont("ST2.Body")
    priceLabel:SetTextColor(THEME.muted)
    priceLabel:SetText("Preis: lädt...")

    local selected = vgui.Create("DLabel", right)
    selected:Dock(BOTTOM)
    selected:DockMargin(10, 0, 10, 6)
    selected:SetTall(20)
    selected:SetFont("ST2.Mono")
    selected:SetTextColor(THEME.muted)
    selected:SetText("Kein Modell ausgewählt")

    return panel, {
      list = listv,
      search = search,
      counter = counter,
      preview = preview,
      equipButton = equip,
      priceLabel = priceLabel,
      selectedLabel = selected,
      pointsLabel = pointsLabel,
    }
  end

  local function buildSlotsTab()
    local panel = vgui.Create("DPanel", sheets)
    panel:Dock(FILL)
    panel.Paint = function(_, w, h)
      draw.RoundedBox(10, 0, 0, w, h, Color(30, 30, 40, 230))
    end

    local title = vgui.Create("DLabel", panel)
    title:Dock(TOP)
    title:DockMargin(12, 12, 12, 2)
    title:SetFont("ST2.Title")
    title:SetTextColor(THEME.text)
    title:SetText("Casino Slots")

    local subtitle = vgui.Create("DLabel", panel)
    subtitle:Dock(TOP)
    subtitle:DockMargin(12, 0, 12, 10)
    subtitle:SetTall(36)
    subtitle:SetWrap(true)
    subtitle:SetFont("ST2.Body")
    subtitle:SetTextColor(THEME.muted)
    subtitle:SetText(string.format("Drei Walzen im 3x3 Raster: setze zwischen %d und %d Punkten. Bis zu 12x Gewinn möglich, gönn dir eine Runde!", SLOT_MIN_BET, SLOT_MAX_BET))

    local balance = vgui.Create("DLabel", panel)
    balance:Dock(TOP)
    balance:DockMargin(12, 0, 12, 8)
    balance:SetFont("ST2.Mono")
    balance:SetTextColor(THEME.text)
    balance:SetText("Aktueller Kontostand: lädt...")

    local reels = vgui.Create("DPanel", panel)
    reels:Dock(TOP)
    reels:DockMargin(12, 0, 12, 10)
    reels:SetTall(200)
    reels.Paint = function(_, w, h)
      draw.RoundedBox(12, 0, 0, w, h, Color(22, 22, 30, 220))
      surface.SetDrawColor(Color(255, 255, 255, 20))
      surface.DrawRect(10, h / 2 - 2, w - 20, 4)
      draw.SimpleText("Gewinnlinie", "ST2.Small", w - 80, h / 2 - 12, THEME.muted, TEXT_ALIGN_CENTER)
    end

    local reelLayout = vgui.Create("DIconLayout", reels)
    reelLayout:Dock(FILL)
    reelLayout:SetSpaceX(12)
    reelLayout:SetSpaceY(0)
    reelLayout:DockMargin(12, 12, 12, 12)

    local reelLabels = {}
    for i = 1, 3 do
      local slotBox = reelLayout:Add("DPanel")
      slotBox:SetSize(150, 170)
      slotBox.Paint = function(_, w, h)
        draw.RoundedBox(10, 0, 0, w, h, Color(40, 44, 56, 240))
        surface.SetDrawColor(Color(255, 255, 255, 20))
        surface.DrawRect(6, h / 2 - 26, w - 12, 52)
      end

      reelLabels[i] = createSlotReel(slotBox, i)
    end

    local reelHint = vgui.Create("DLabel", panel)
    reelHint:Dock(TOP)
    reelHint:DockMargin(12, 0, 12, 8)
    reelHint:SetFont("ST2.Body")
    reelHint:SetTextColor(THEME.muted)
    reelHint:SetText("3x3 Walzen mit mittlerer Gewinnlinie – Auszahlungen bis 12x bei Kombinationen.")

    local betRow = vgui.Create("DPanel", panel)
    betRow:Dock(TOP)
    betRow:DockMargin(12, 0, 12, 6)
    betRow:SetTall(40)
    betRow.Paint = function(_, w, h)
      draw.RoundedBox(8, 0, 0, w, h, Color(24, 24, 32, 220))
    end

    local betEntry = vgui.Create("DNumberWang", betRow)
    betEntry:Dock(LEFT)
    betEntry:DockMargin(10, 7, 6, 7)
    betEntry:SetWide(180)
    betEntry:SetMin(SLOT_MIN_BET)
    betEntry:SetMax(SLOT_MAX_BET)
    betEntry:SetValue(SLOT_MIN_BET)
    betEntry:SetDecimals(0)
    betEntry:SetFont("ST2.Body")

    local spinButton = vgui.Create("DButton", betRow)
    spinButton:Dock(RIGHT)
    spinButton:DockMargin(6, 6, 10, 6)
    spinButton:SetWide(200)
    spinButton:SetText("Spin!")
    styleButton(spinButton)

    local result = vgui.Create("DLabel", panel)
    result:Dock(TOP)
    result:DockMargin(12, 4, 12, 2)
    result:SetFont("ST2.Body")
    result:SetTextColor(THEME.muted)
    result:SetText("Hol dir dein Glück...")

    local odds = vgui.Create("DLabel", panel)
    odds:Dock(TOP)
    odds:DockMargin(12, 0, 12, 6)
    odds:SetFont("ST2.Body")
    odds:SetTextColor(THEME.muted)
    odds:SetText("Tipp: Höhere Einsätze bedeuten auch höhere Gewinne – aber die Walzen bleiben fair.")

    local function startSlotSpin(onStop)
      local timers = {}
      local function stopTimers()
        if timers.stopped then return end
        timers.stopped = true

        for _, name in ipairs(timers) do
          timer.Remove(name)
        end
        timers = {}
        for _, reel in ipairs(reelLabels) do
          if reel and reel.stop then
            reel:stop()
          end
        end

        if isfunction(onStop) then
          onStop()
        end
      end

      for colIndex, reel in ipairs(reelLabels) do
        local name = string.format("st2_slot_spin_%d_%f", colIndex, CurTime())
        table.insert(timers, name)
        if reel and reel.stop then reel:stop() end
        if reel then reel.interval = 0.08 + 0.02 * colIndex end
        timer.Create(name, reel and reel.interval or 0.1, 0, function()
          if not reel or not reel.advance then
            stopTimers()
            return
          end
          if not IsValid(reel.panel) then
            stopTimers()
            return
          end
          reel:advance(randomSlotSymbol())
        end)
        if reel then
          reel.timerName = name
        end
      end

      local endTimer = string.format("st2_slot_spin_end_%f", CurTime())
      table.insert(timers, endTimer)
      timer.Create(endTimer, SLOT_SPIN_TIMEOUT, 1, stopTimers)

      return stopTimers
    end

    return panel, {
      slotBalance = balance,
      slotResult = result,
      slotReels = reelLabels,
      betEntry = betEntry,
      spinButton = spinButton,
      startSlotSpin = startSlotSpin,
      stopSlotSpin = function() end,
      slotSpinActive = false,
    }
  end

  local modelPanel, modelUi = buildModelTab()
  sheets:AddSheet("Modelle", modelPanel, "icon16/user_gray.png")

  local slotsPanel, slotUi = buildSlotsTab()
  sheets:AddSheet("Casino", slotsPanel, "icon16/coins.png")

  local traitorPanel
  local traitorRefresh
  if ShadowTTT2 and ShadowTTT2.TraitorShop and ShadowTTT2.TraitorShop.BuildPanel then
    traitorPanel, traitorRefresh = ShadowTTT2.TraitorShop.BuildPanel(sheets)
    if IsValid(traitorPanel) then
      sheets:AddSheet("Traitor Shop", traitorPanel, "icon16/plugin.png")
      if ShadowTTT2.TraitorShop.RegisterRefresh and isfunction(traitorRefresh) then
        ShadowTTT2.TraitorShop.RegisterRefresh(traitorRefresh)
      end
    end
  end

  local ui = {}
  for k, v in pairs(modelUi) do ui[k] = v end
  for k, v in pairs(slotUi) do ui[k] = v end
  ui.models = models or {}
  ui.activeModel = activeModel or ""
  ui.currentModel = nil
  ui.currentPrice = nil
  ui.defaultPrice = defaultPrice or pointshopState.defaultPrice or MODEL_PRICE_DEFAULT
  ui.slotReels = slotUi.slotReels
  ui.stopSlotSpin = slotUi.stopSlotSpin
  ui.slotSpinActive = slotUi.slotSpinActive
  ui.traitorShopRefresh = traitorRefresh

  if IsValid(ui.spinButton) then
    ui.spinButton.DoClick = function()
      if pointshopState.spinPending or ui.slotSpinActive then return end
      local bet = math.floor(tonumber(ui.betEntry:GetValue()) or SLOT_MIN_BET)
      bet = math.Clamp(bet, SLOT_MIN_BET, SLOT_MAX_BET)
      ui.betEntry:SetValue(bet)

      ui.slotSpinActive = true
      if ui.startSlotSpin then
        ui.stopSlotSpin = ui.startSlotSpin(function()
          ui.slotSpinActive = false
          unlockSpinButton(ui)
        end) or function() end
      end
      pointshopState.spinPending = true
      ui.spinButton:SetEnabled(false)
      ui.spinButton:SetText("Dreht...")
      if IsValid(ui.slotResult) then
        ui.slotResult:SetText("Räder drehen...")
        ui.slotResult:SetTextColor(THEME.muted)
      end

      net.Start("ST2_POINTS_SPIN")
      net.WriteUInt(bet, 16)
      net.SendToServer()
    end
  end

  if IsValid(modelUi.list) then
    modelUi.list.OnRowSelected = function(_, _, line)
      selectModel(ui, line:GetColumnText(1), line.ShadowModelPrice or ui.defaultPrice)
    end
  end

  if IsValid(modelUi.search) then
    modelUi.search.OnValueChange = function(_, value)
      refreshPointshopList(ui, value)
    end
  end

  activePointshopFrame.ShadowPointshopUI = ui
  applyPointshopData(ui, models, activeModel, ui.defaultPrice)
  requestPointsBalance()
  if ShadowTTT2 and ShadowTTT2.TraitorShop and ShadowTTT2.TraitorShop.RequestSnapshot and ShadowTTT2.TraitorShop.CanAccess then
    if ShadowTTT2.TraitorShop.CanAccess() then
      ShadowTTT2.TraitorShop.RequestSnapshot()
    end
  end
end

  local function isActiveTraitor(ply)
    if not IsValid(ply) then return false end
    if ply.IsActiveTraitor and ply:IsActiveTraitor() then return true end
    if ply.IsTraitor and ply:IsTraitor() then return true end
    if ply.GetSubRole and ROLE_TRAITOR and ply:GetSubRole() == ROLE_TRAITOR then return true end
    if ply.GetRole and ROLE_TRAITOR and ply:GetRole() == ROLE_TRAITOR then return true end
    if ply.GetBaseRole and ROLE_TRAITOR and ply:GetBaseRole() == ROLE_TRAITOR then return true end
    if ply.GetTeam and TEAM_TRAITOR and ply:GetTeam() == TEAM_TRAITOR then return true end
    return false
  end

local function requestPointshopOpen()
  if pointshopState.requestPending then return end
  pointshopState.requestPending = true
  pointshopState.openPending = true
  requestPointsBalance()
  net.Start("ST2_PS_MODELS_REQUEST")
  net.SendToServer()
end

hook.Add("PlayerButtonDown", "ST2_F3_POINTSHOP_FINAL", function(_, key)
  if key ~= KEY_F3 then return end
  requestPointshopOpen()
end)


net.Receive("ST2_PS_MODELS", function()
  local defaultPrice = net.ReadUInt(16)
  local count = net.ReadUInt(16)
  local models = {}
  for i = 1, count do
    models[i] = {
      model = net.ReadString(),
      price = net.ReadUInt(16)
    }
  end

  local activeModel = net.ReadString() or ""
  pointshopState.defaultPrice = defaultPrice > 0 and defaultPrice or MODEL_PRICE_DEFAULT
  pointshopState.requestPending = false
  pointshopState.models = models
  pointshopState.activeModel = activeModel

  if IsValid(activePointshopFrame) and activePointshopFrame.ShadowPointshopUI then
    applyPointshopData(activePointshopFrame.ShadowPointshopUI, models, activeModel, pointshopState.defaultPrice)
  end

  if pointshopState.openPending then
    pointshopState.openPending = false
    if #models == 0 then
      chat.AddText(Color(200, 60, 60), "ShadowTTT2 Pointshop: keine serverseitig gespeicherten Modelle gefunden.")
      return
    end
    openPointshop(models, activeModel, pointshopState.defaultPrice)
  end
end)

net.Receive("ST2_POINTS_BALANCE", function()
  local balance = net.ReadInt(32)
  pointshopState.points = balance or 0
  if IsValid(activePointshopFrame) and activePointshopFrame.ShadowPointshopUI then
    updatePointsDisplay(activePointshopFrame.ShadowPointshopUI, pointshopState.points)
  end
end)

net.Receive("ST2_POINTS_SPIN_RESULT", function()
  local ok = net.ReadBool()
  local message = net.ReadString()
  local bet = net.ReadUInt(16)
  local payout = net.ReadInt(32)
  local balance = net.ReadInt(32)
  local count = net.ReadUInt(3)
  local symbols = {}
  for i = 1, count do
    symbols[i] = {id = net.ReadString(), icon = net.ReadString()}
  end

  pointshopState.points = balance or pointshopState.points
  local ui = IsValid(activePointshopFrame) and activePointshopFrame.ShadowPointshopUI
  finishSpin(ui)
  if ui then
    updatePointsDisplay(ui, pointshopState.points)
    showSlotResult(ui, symbols, message ~= "" and message or (ok and "Fertig." or "Fehler"), payout)
  end

  if not ok and message and message ~= "" then
    chat.AddText(Color(230, 90, 90), "[Pointshop] ", color_white, message)
  elseif ok and payout and payout > 0 then
    chat.AddText(Color(120, 200, 120), string.format("[Pointshop] Gewinn! Einsatz %d -> Gewinn %d Punkte", bet, payout))
  end
end)

do
  local mapVoteState = {
    options = {},
    counts = {},
    endsAt = 0,
    selection = nil
  }

  local function formatMapVoteName(mapName)
    if not isstring(mapName) then return "" end
    if string.match(mapName, "%.bsp$") then
      return mapName
    end
    return mapName .. ".bsp"
  end

  local function updateMapVoteUI(ui)
    if not IsValid(ui) then return end
    if not IsValid(ui.timerLabel) then return end
    local remaining = math.max(0, mapVoteState.endsAt - CurTime())
    ui.timerLabel:SetText("Endet in: " .. string.NiceTime(math.ceil(remaining)))
    ui.timerLabel:SizeToContents()

    if IsValid(ui.voteLabel) then
      if mapVoteState.selection then
        ui.voteLabel:SetText("Deine Stimme: " .. formatMapVoteName(mapVoteState.selection))
      else
        ui.voteLabel:SetText("Deine Stimme: keine")
      end
      ui.voteLabel:SizeToContents()
    end
  end

  local function createMapVoteUI(options)
    if IsValid(ShadowTTT2.MapVoteUI) then
      ShadowTTT2.MapVoteUI:Remove()
    end

    local f = createFrame("ShadowTTT2 Map Voting", 480, 420)
    ShadowTTT2.MapVoteUI = f

    local timerLabel = vgui.Create("DLabel", f)
    timerLabel:SetFont("ST2.Subtitle")
    timerLabel:SetTextColor(THEME.text)
    timerLabel:SetPos(20, 70)
    timerLabel:SetText("Endet in: ...")
    timerLabel:SizeToContents()
    f.timerLabel = timerLabel

    local voteLabel = vgui.Create("DLabel", f)
    voteLabel:SetFont("ST2.Body")
    voteLabel:SetTextColor(THEME.muted)
    voteLabel:SetPos(20, 96)
    voteLabel:SetText("Deine Stimme: keine")
    voteLabel:SizeToContents()
    f.voteLabel = voteLabel

    local list = vgui.Create("DScrollPanel", f)
    list:SetPos(20, 130)
    list:SetSize(440, 260)
    f.mapButtons = {}

    local y = 0
    for _, mapName in ipairs(options) do
      local btn = vgui.Create("DButton", list)
      btn:SetSize(420, 44)
      btn:SetPos(0, y)
      btn:SetText("")
      btn.Paint = function(self, w, h)
        local col = THEME.panel
        if mapVoteState.selection == mapName then
          col = THEME.accent
        elseif self:IsHovered() then
          col = Color(255, 170, 110)
        end
        draw.RoundedBox(10, 0, 0, w, h, col)
        local label = string.format("%s (%d)", formatMapVoteName(mapName), mapVoteState.counts[mapName] or 0)
        draw.SimpleText(label, "ST2.Body", 12, h / 2, THEME.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
      end
      btn.DoClick = function()
        mapVoteState.selection = mapName
        net.Start("ST2_MAPVOTE_VOTE")
        net.WriteString(mapName)
        net.SendToServer()
        updateMapVoteUI(f)
      end
      f.mapButtons[mapName] = btn
      y = y + 50
    end

    f.Think = function()
      updateMapVoteUI(f)
    end
  end

  net.Receive("ST2_MAPVOTE_START", function()
    local count = net.ReadUInt(6)
    local options = {}
    for i = 1, count do
      options[i] = net.ReadString()
    end
    mapVoteState.options = options
    mapVoteState.counts = {}
    mapVoteState.selection = nil
    mapVoteState.endsAt = net.ReadFloat()
    createMapVoteUI(options)
  end)

  net.Receive("ST2_MAPVOTE_TALLY", function()
    local count = net.ReadUInt(6)
    local counts = {}
    for _ = 1, count do
      local mapName = net.ReadString()
      counts[mapName] = net.ReadUInt(12)
    end
    mapVoteState.counts = counts
    if IsValid(ShadowTTT2.MapVoteUI) then
      ShadowTTT2.MapVoteUI:InvalidateLayout(true)
    end
  end)

  net.Receive("ST2_MAPVOTE_END", function()
    local winner = net.ReadString()
    local ui = ShadowTTT2.MapVoteUI
    if not IsValid(ui) then return end
    if IsValid(ui.timerLabel) then
      ui.timerLabel:SetText("Gewinner: " .. formatMapVoteName(winner))
      ui.timerLabel:SizeToContents()
    end
    if IsValid(ui.voteLabel) then
      ui.voteLabel:SetText("Danke fürs Abstimmen!")
      ui.voteLabel:SizeToContents()
    end
    if ui.mapButtons then
      for _, btn in pairs(ui.mapButtons) do
        if IsValid(btn) then
          btn:SetEnabled(false)
        end
      end
    end
    timer.Simple(5, function()
      if IsValid(ui) then
        ui:Close()
      end
    end)
  end)
end

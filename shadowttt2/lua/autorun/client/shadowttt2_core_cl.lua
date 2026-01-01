
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

surface.CreateFont("ST2.Title", {font = "Roboto", size = 24, weight = 800})
surface.CreateFont("ST2.Subtitle", {font = "Roboto", size = 18, weight = 600})
surface.CreateFont("ST2.Body", {font = "Roboto", size = 16, weight = 500})
surface.CreateFont("ST2.Button", {font = "Roboto", size = 17, weight = 700})
surface.CreateFont("ST2.Mono", {font = "Consolas", size = 15, weight = 500})

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

  local function populateModelAdminList(list, entries, filter, onlyEnabled, counter)
    if not IsValid(list) then return end
    list:Clear()
    local q = string.Trim(string.lower(filter or ""))
    local visible = 0
    for _, row in ipairs(entries or {}) do
      if onlyEnabled and not row.enabled then continue end
      if q ~= "" and not string.find(string.lower(row.model or ""), q, 1, true) then continue end

      local status = row.enabled and "Aktiv" or "Versteckt"
      local line = list:AddLine(row.model or "", status)
      if IsValid(line) then
        setLineTextColor(line, row.enabled and THEME.text or THEME.muted)
        line.ShadowRowData = row
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

    local count = net.ReadUInt(16)
    local entries = {}
    for _ = 1, count do
      entries[#entries + 1] = {
        model = net.ReadString(),
        enabled = net.ReadBool()
      }
    end

    ui.modelEntries = entries
    if IsValid(ui.modelList) then
      populateModelAdminList(ui.modelList, entries, IsValid(ui.modelSearch) and ui.modelSearch:GetText() or "", IsValid(ui.modelEnabledOnly) and ui.modelEnabledOnly:GetChecked(), ui.modelCounter)
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
      {label = "Round End", id = "endround", requireTarget = false},
      {label = "Round Restart", id = "roundrestart", requireTarget = false},
    }

    for _, info in ipairs(actions) do
      local btn = createActionButton(actionGrid, info.label, info.id, getSelectedSid, {requireTarget = info.requireTarget})
      btn:SetWide(230)
    end

    local roundtimePanel = actionGrid:Add("DPanel")
    roundtimePanel:SetSize(230, 120)
    roundtimePanel.Paint = function(_, w, h)
      draw.RoundedBox(12, 0, 0, w, h, Color(32, 32, 42, 230))
    end

    local roundtimeLabel = vgui.Create("DLabel", roundtimePanel)
    roundtimeLabel:Dock(TOP)
    roundtimeLabel:DockMargin(10, 8, 10, 4)
    roundtimeLabel:SetTall(20)
    roundtimeLabel:SetFont("ST2.Subtitle")
    roundtimeLabel:SetTextColor(THEME.text)
    roundtimeLabel:SetText("Rundenzeit (Minuten)")

    local roundtimeWang = vgui.Create("DNumberWang", roundtimePanel)
    roundtimeWang:Dock(TOP)
    roundtimeWang:DockMargin(10, 0, 10, 8)
    roundtimeWang:SetTall(30)
    roundtimeWang:SetMin(1)
    roundtimeWang:SetMax(300)
    roundtimeWang:SetDecimals(0)
    roundtimeWang:SetValue(10)
    roundtimeWang:SetFont("ST2.Body")

    local roundtimeStatus = vgui.Create("DLabel", roundtimePanel)
    roundtimeStatus:Dock(TOP)
    roundtimeStatus:DockMargin(10, 0, 10, 4)
    roundtimeStatus:SetTall(18)
    roundtimeStatus:SetFont("ST2.Body")
    roundtimeStatus:SetTextColor(THEME.muted)
    roundtimeStatus:SetText("")

    local roundtimeButton = vgui.Create("DButton", roundtimePanel)
    roundtimeButton:Dock(BOTTOM)
    roundtimeButton:DockMargin(10, 0, 10, 10)
    roundtimeButton:SetTall(34)
    roundtimeButton:SetText("Speichern")
    styleButton(roundtimeButton)
    roundtimeButton.DoClick = function()
      local minutes = math.floor(tonumber(roundtimeWang:GetValue()) or 0)
      if minutes < 1 then return end
      minutes = math.Clamp(minutes, 1, 300)

      net.Start("ST2_ADMIN_ACTION")
      net.WriteString("roundtime")
      net.WriteUInt(minutes, 12)
      net.SendToServer()

      roundtimeStatus:SetText("Gesendet: " .. minutes .. " min")
      roundtimeStatus:SetTextColor(THEME.accent_soft)
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
    speedPanel:SetSize(230, 190)
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
    modelList:AddColumn("Status")
    styleListView(modelList)
    modelEnabledOnly.OnChange = function()
      local ui = ShadowTTT2.AdminUI
      populateModelAdminList(modelList, ui and ui.modelEntries or {}, IsValid(modelSearch) and modelSearch:GetText() or "", modelEnabledOnly:GetChecked(), modelCounter)
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
    local suppressToggle
    local function updateModelSelection(line)
      selectedModel = line and line.ShadowRowData
      if not selectedModel then
        modelTitle:SetText("Kein Modell ausgewählt")
        modelInfo:SetText("Aktiviere oder verstecke Modelle für den F3-Shop. Doppelklick in der Liste toggelt den Status.")
        suppressToggle = true
        if IsValid(modelToggle) and modelToggle.SetChecked then modelToggle:SetChecked(false) end
        suppressToggle = false
        if IsValid(modelPreview) then modelPreview:SetModel("models/player/kleiner.mdl") end
        return
      end

      modelTitle:SetText(selectedModel.model or "Unbekanntes Modell")
      modelInfo:SetText(selectedModel.enabled and "Status: Aktiv im F3-Shop" or "Status: Versteckt im F3-Shop")
      suppressToggle = true
      if IsValid(modelToggle) and modelToggle.SetChecked then modelToggle:SetChecked(selectedModel.enabled) end
      suppressToggle = false
      if IsValid(modelPreview) then modelPreview:SetModel(selectedModel.model or "") end
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
      populateModelAdminList(modelList, ui and ui.modelEntries or {}, value, IsValid(modelEnabledOnly) and modelEnabledOnly:GetChecked(), modelCounter)
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
    }

    populateWeaponDropdown(giveWeaponDropdown, {}, "", nil)
    populateWeaponDropdown(shopWeaponDropdown, {}, "", nil)
    requestAdminPlayerList(list)
    sendTraitorShopRequest()
    sendPointshopAdminRequest()
    requestRecoilMultiplier()
    requestMovementSpeeds()
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
  spinPending = false
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

local function updatePointsDisplay(ui, balance)
  if not ui then return end
  ui.points = balance or 0
  if IsValid(ui.pointsLabel) then
    ui.pointsLabel:SetText(string.format("Punkte: %d", ui.points))
  end
  if IsValid(ui.slotBalance) then
    ui.slotBalance:SetText(string.format("Aktueller Kontostand: %d", ui.points))
  end
end

local function showSlotResult(ui, symbols, text, payout)
  if not ui then return end
  if IsValid(ui.slotResult) then
    ui.slotResult:SetText(text or "")
    ui.slotResult:SetTextColor((payout or 0) > 0 and THEME.accent_soft or THEME.muted)
  end

  if IsValid(ui.slotSymbols) then
    if istable(symbols) and #symbols > 0 then
      local icons = {}
      for _, sym in ipairs(symbols) do
        icons[#icons + 1] = sym.icon or sym.id or "?"
      end
      ui.slotSymbols:SetText(table.concat(icons, "  "))
    else
      ui.slotSymbols:SetText("⏳")
    end
  end
end

local function finishSpin(ui)
  pointshopState.spinPending = false
  if not ui then return end
  if IsValid(ui.spinButton) then
    ui.spinButton:SetEnabled(true)
    ui.spinButton:SetText("Spin!")
  end
end

local function refreshPointshopList(ui, filter)
  if not IsValid(ui.list) then return end
  ui.list:Clear()

  local q = string.Trim(string.lower(filter or ""))
  local visible = 0
  for _, m in ipairs(ui.models or {}) do
    if q == "" or string.find(string.lower(m), q, 1, true) then
      local line = ui.list:AddLine(m)
      if IsValid(line) then
        if line.SetTextColor then
          line:SetTextColor(m == ui.activeModel and THEME.accent_soft or THEME.text)
        else
          for _, col in ipairs(line.Columns or {}) do
            if IsValid(col) and col.SetTextColor then
              col:SetTextColor(m == ui.activeModel and THEME.accent_soft or THEME.text)
            end
          end
        end
        line.ShadowModelPath = m
        line.Paint = function(self, w, h)
          local bg = self:IsLineSelected() and THEME.accent or Color(255, 255, 255, 6)
          if m == ui.activeModel then
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

local function selectModel(ui, mdl)
  if not mdl or mdl == "" then return end
  if IsValid(ui.preview) then
    ui.preview:SetModel(mdl)
  end
  if IsValid(ui.selectedLabel) then
    ui.selectedLabel:SetText(formatSelectedLabel(mdl, ui.activeModel))
  end
  if IsValid(ui.equipButton) then
    ui.equipButton.DoClick = function()
      net.Start("ST2_PS_EQUIP")
      net.WriteString(mdl)
      net.SendToServer()
    end
  end
  ui.currentModel = mdl
end

local function applyPointshopData(ui, models, activeModel)
  ui.models = models or {}
  ui.activeModel = activeModel or ""
  local searchText = IsValid(ui.search) and ui.search:GetText() or ""
  refreshPointshopList(ui, searchText)

  local function selectActiveOrFirst()
    if ui.activeModel and ui.activeModel ~= "" then
      for i = 1, ui.list:GetLineCount() do
        local line = ui.list:GetLine(i)
        if IsValid(line) and line:GetColumnText(1) == ui.activeModel then
          ui.list:SelectItem(line)
          return
        end
      end
    end
    if ui.list:GetLineCount() > 0 then
      ui.list:SelectFirstItem()
    end
  end

  selectActiveOrFirst()
  updatePointsDisplay(ui, pointshopState.points)
end

local function openPointshop(models, activeModel)
  if IsValid(activePointshopFrame) then
    if activePointshopFrame.ShadowPointshopUI then
      applyPointshopData(activePointshopFrame.ShadowPointshopUI, models, activeModel)
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

  local left = vgui.Create("DPanel", container)
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

  local right = vgui.Create("DPanel", container)
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

  local slotPanel = vgui.Create("DPanel", right)
  slotPanel:Dock(BOTTOM)
  slotPanel:DockMargin(10, 0, 10, 6)
  slotPanel:SetTall(190)
  slotPanel.Paint = function(_, w, h)
    draw.RoundedBox(10, 0, 0, w, h, Color(32, 32, 42, 230))
  end

  local slotTitle = vgui.Create("DLabel", slotPanel)
  slotTitle:Dock(TOP)
  slotTitle:DockMargin(10, 10, 10, 2)
  slotTitle:SetFont("ST2.Subtitle")
  slotTitle:SetTextColor(THEME.text)
  slotTitle:SetText("Casino Slots")

  local slotHint = vgui.Create("DLabel", slotPanel)
  slotHint:Dock(TOP)
  slotHint:DockMargin(10, 0, 10, 6)
  slotHint:SetFont("ST2.Body")
  slotHint:SetTextColor(THEME.muted)
  slotHint:SetTall(34)
  slotHint:SetWrap(true)
  slotHint:SetText(string.format("Setze zwischen %d und %d Punkten und gewinne bis zu 12x zurück.", SLOT_MIN_BET, SLOT_MAX_BET))

  local slotBalance = vgui.Create("DLabel", slotPanel)
  slotBalance:Dock(TOP)
  slotBalance:DockMargin(10, 0, 10, 4)
  slotBalance:SetFont("ST2.Mono")
  slotBalance:SetTextColor(THEME.text)
  slotBalance:SetText("Aktueller Kontostand: lädt...")

  local slotRow = vgui.Create("DPanel", slotPanel)
  slotRow:Dock(TOP)
  slotRow:DockMargin(10, 2, 10, 4)
  slotRow:SetTall(36)
  slotRow.Paint = function(_, w, h)
    draw.RoundedBox(8, 0, 0, w, h, Color(24, 24, 32, 220))
  end

  local betEntry = vgui.Create("DNumberWang", slotRow)
  betEntry:Dock(LEFT)
  betEntry:DockMargin(10, 6, 6, 6)
  betEntry:SetWide(140)
  betEntry:SetMin(SLOT_MIN_BET)
  betEntry:SetMax(SLOT_MAX_BET)
  betEntry:SetValue(math.floor((SLOT_MIN_BET + SLOT_MAX_BET) / 2))
  betEntry:SetDecimals(0)
  betEntry:SetFont("ST2.Body")

  local spinButton = vgui.Create("DButton", slotRow)
  spinButton:Dock(RIGHT)
  spinButton:DockMargin(6, 6, 10, 6)
  spinButton:SetWide(160)
  spinButton:SetText("Spin!")
  styleButton(spinButton)

  local slotResult = vgui.Create("DLabel", slotPanel)
  slotResult:Dock(TOP)
  slotResult:DockMargin(10, 4, 10, 2)
  slotResult:SetFont("ST2.Body")
  slotResult:SetTextColor(THEME.muted)
  slotResult:SetTall(20)
  slotResult:SetText("Hol dir dein Glück... ")

  local slotSymbols = vgui.Create("DLabel", slotPanel)
  slotSymbols:Dock(TOP)
  slotSymbols:DockMargin(10, 2, 10, 8)
  slotSymbols:SetFont("ST2.Title")
  slotSymbols:SetTextColor(THEME.text)
  slotSymbols:SetTall(36)
  slotSymbols:SetText("⏳")

  local equip = vgui.Create("DButton", right)
  equip:Dock(BOTTOM)
  equip:DockMargin(10, 0, 10, 12)
  equip:SetTall(42)
  equip:SetText("Modell auswählen")
  styleButton(equip)

  local selected = vgui.Create("DLabel", right)
  selected:Dock(BOTTOM)
  selected:DockMargin(10, 0, 10, 6)
  selected:SetTall(20)
  selected:SetFont("ST2.Mono")
  selected:SetTextColor(THEME.muted)
  selected:SetText("Kein Modell ausgewählt")

  local ui = {
    list = listv,
    search = search,
    counter = counter,
    preview = preview,
    equipButton = equip,
    selectedLabel = selected,
    pointsLabel = pointsLabel,
    slotResult = slotResult,
    slotSymbols = slotSymbols,
    slotBalance = slotBalance,
    spinButton = spinButton,
    betEntry = betEntry,
    models = models or {},
    activeModel = activeModel or "",
    currentModel = nil
  }

  spinButton.DoClick = function()
    if pointshopState.spinPending then return end
    local bet = math.floor(tonumber(betEntry:GetValue()) or SLOT_MIN_BET)
    bet = math.Clamp(bet, SLOT_MIN_BET, SLOT_MAX_BET)
    betEntry:SetValue(bet)

    pointshopState.spinPending = true
    spinButton:SetEnabled(false)
    spinButton:SetText("Dreht...")
    showSlotResult(ui, nil, "Räder drehen...", 0)

    net.Start("ST2_POINTS_SPIN")
    net.WriteUInt(bet, 16)
    net.SendToServer()
  end

  listv.OnRowSelected = function(_, _, line)
    selectModel(ui, line:GetColumnText(1))
  end

  search.OnValueChange = function(_, value)
    refreshPointshopList(ui, value)
  end

  activePointshopFrame.ShadowPointshopUI = ui
  applyPointshopData(ui, models, activeModel)
  requestPointsBalance()
end

hook.Add("PlayerButtonDown", "ST2_F3_POINTSHOP_FINAL", function(_, key)
  if key ~= KEY_F3 then return end

  if pointshopState.requestPending then return end
  pointshopState.requestPending = true
  pointshopState.openPending = true
  requestPointsBalance()
  net.Start("ST2_PS_MODELS_REQUEST")
  net.SendToServer()
end)

net.Receive("ST2_PS_MODELS", function()
  local count = net.ReadUInt(16)
  local models = {}
  for i = 1, count do
    models[i] = net.ReadString()
  end

  local activeModel = net.ReadString() or ""
  pointshopState.requestPending = false
  pointshopState.models = models
  pointshopState.activeModel = activeModel

  if IsValid(activePointshopFrame) and activePointshopFrame.ShadowPointshopUI then
    applyPointshopData(activePointshopFrame.ShadowPointshopUI, models, activeModel)
  end

  if pointshopState.openPending then
    pointshopState.openPending = false
    if #models == 0 then
      chat.AddText(Color(200, 60, 60), "ShadowTTT2 Pointshop: keine serverseitig gespeicherten Modelle gefunden.")
      return
    end
    openPointshop(models, activeModel)
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

local mapVoteFrame
local function sendMapVoteChoice(mapName)
  net.Start("ST2_MAPVOTE_VOTE")
  net.WriteString(mapName or "")
  net.SendToServer()
end

local function ensureMapVoteFrame()
  if IsValid(mapVoteFrame) then return mapVoteFrame end

  local f = createFrame("Map Auswahl", 760, 540)
  mapVoteFrame = f
  f.OnRemove = function()
    if mapVoteFrame == f then
      mapVoteFrame = nil
    end
  end

  local header = vgui.Create("DLabel", f)
  header:SetPos(16, 52)
  header:SetSize(700, 22)
  header:SetFont("ST2.Subtitle")
  header:SetTextColor(THEME.muted)
  header:SetText("Letzte Runde gespielt – wähle die nächste Map für den Server.")

  local status = vgui.Create("DLabel", f)
  status:SetPos(16, 78)
  status:SetSize(700, 20)
  status:SetFont("ST2.Body")
  status:SetTextColor(THEME.text)
  status:SetText("Starte Mapvote...")

  local scroll = vgui.Create("DScrollPanel", f)
  scroll:SetPos(12, 110)
  scroll:SetSize(736, 400)
  scroll.Paint = function(_, w, h)
    draw.RoundedBox(12, 0, 0, w, h, Color(26, 26, 34, 230))
  end
  if IsValid(scroll.VBar) then
    scroll.VBar.Paint = function(_, w, h)
      draw.RoundedBox(8, 0, 0, w, h, Color(20, 20, 26, 150))
    end
    scroll.VBar.btnGrip.Paint = function(_, w, h)
      draw.RoundedBox(6, 0, 0, w, h, THEME.accent)
    end
  end

  local list = scroll:Add("DIconLayout")
  list:Dock(FILL)
  list:SetSpaceX(10)
  list:SetSpaceY(10)
  list:SetStretchWidth(true)
  list:DockMargin(10, 10, 10, 10)

  f.ShadowMapVote = {
    statusLabel = status,
    list = list,
    optionPanels = {},
    selected = nil,
    endTime = 0,
    locked = false,
    winner = nil,
    totals = 0
  }

  return f
end

local function updateMapOptionPanel(ui, mapName, votes)
  local displayName = formatMapDisplayName(mapName)
  local panel = ui.optionPanels[mapName]
  if not IsValid(panel) then
    panel = ui.list:Add("DButton")
    panel:SetTall(90)
    panel:SetText("")
    panel:SetTooltip(displayName)
    panel.ShadowMap = mapName
    panel.DoClick = function()
      if ui.locked then return end
      ui.selected = mapName
      sendMapVoteChoice(mapName)
    end
    ui.optionPanels[mapName] = panel
  end

  panel.ShadowVotes = votes or 0
  panel.Paint = function(self, w, h)
    local isSelected = ui.selected == mapName
    local isWinner = ui.winner and ui.winner == mapName
    local base = THEME.panel
    if isWinner then
      base = Color(60, 120, 60, 230)
    elseif isSelected then
      base = Color(40, 70, 110, 230)
    end

    draw.RoundedBox(12, 0, 0, w, h, base)
    draw.SimpleText(displayName, "ST2.Subtitle", 12, 12, THEME.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

    local voteText = string.format("%d Stimme%s", self.ShadowVotes or 0, (self.ShadowVotes or 0) == 1 and "" or "n")
    draw.SimpleText(voteText, "ST2.Body", 12, 44, THEME.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

    local total = math.max(ui.totals, 1)
    local frac = math.Clamp((self.ShadowVotes or 0) / total, 0, 1)
    draw.RoundedBox(8, 12, h - 22, (w - 24) * frac, 12, ui.winner and THEME.accent or THEME.accent_soft)

    if isSelected then
      surface.SetDrawColor(THEME.accent_soft)
      surface.DrawOutlinedRect(1, 1, w - 2, h - 2, 2)
    end
  end
end

local function applyMapVoteState(options, endTime)
  if not options or #options == 0 then
    if IsValid(mapVoteFrame) then
      mapVoteFrame:Close()
    end
    return
  end

  local frame = ensureMapVoteFrame()
  local ui = frame.ShadowMapVote
  ui.endTime = endTime or CurTime()
  ui.locked = false
  ui.winner = nil

  local totalVotes = 0
  local seen = {}
  for _, opt in ipairs(options) do
    totalVotes = totalVotes + (opt.votes or 0)
    seen[opt.name] = true
    updateMapOptionPanel(ui, opt.name, opt.votes or 0)
  end
  ui.totals = math.max(totalVotes, 1)

  for name, panel in pairs(ui.optionPanels) do
    if not seen[name] and IsValid(panel) then
      panel:Remove()
      ui.optionPanels[name] = nil
    end
  end

  if IsValid(ui.statusLabel) then
    local remaining = math.max(0, math.ceil(ui.endTime - CurTime()))
    ui.statusLabel:SetText(string.format("Abstimmung läuft... (%ds)", remaining))
  end

  frame:MakePopup()
  frame:RequestFocus()
end

local function applyMapVoteResult(winner, options)
  if not winner or winner == "" then return end
  local frame = ensureMapVoteFrame()
  local ui = frame.ShadowMapVote
  ui.locked = true
  ui.winner = winner
  ui.endTime = CurTime()

  if options and #options > 0 then
    ui.totals = 0
    for _, opt in ipairs(options) do
      ui.totals = ui.totals + (opt.votes or 0)
      updateMapOptionPanel(ui, opt.name, opt.votes or 0)
    end
  end

  if IsValid(ui.statusLabel) then
    ui.statusLabel:SetText("Gewählte Map: " .. formatMapDisplayName(winner) .. " (Wechsel in Kürze)")
  end

  timer.Simple(5, function()
    if IsValid(frame) then
      frame:Close()
    end
  end)
end

net.Receive("ST2_MAPVOTE_STATE", function()
  local count = net.ReadUInt(6)
  local options = {}
  for i = 1, count do
    options[i] = {
      name = net.ReadString(),
      votes = net.ReadUInt(12)
    }
  end
  local endTime = net.ReadFloat()

  applyMapVoteState(options, endTime)
end)

net.Receive("ST2_MAPVOTE_RESULT", function()
  local winner = net.ReadString()
  local count = net.ReadUInt(6)
  local options = {}
  for i = 1, count do
    options[i] = {
      name = net.ReadString(),
      votes = net.ReadUInt(12)
    }
  end

  applyMapVoteResult(winner, options)
end)

hook.Add("Think", "ST2_MapVoteCountdown", function()
  if not IsValid(mapVoteFrame) then return end
  local ui = mapVoteFrame.ShadowMapVote
  if not ui or ui.locked then return end

  local remaining = math.max(0, math.ceil((ui.endTime or 0) - CurTime()))
  if IsValid(ui.statusLabel) then
    ui.statusLabel:SetText(string.format("Abstimmung läuft... (%ds)", remaining))
  end
end)

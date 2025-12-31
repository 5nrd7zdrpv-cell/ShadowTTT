
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

  -- Admin open (client requests server concommand)
  concommand.Add("shadow_admin_open", function()
    net.Start("ST2_ADMIN_REQUEST")
    net.SendToServer()
  end)

  local function createActionButton(parent, label, action, getTarget)
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
      local sid = getTarget()
      if not sid then return end
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
      if ui.shopList:GetLineCount() > 0 then
        ui.shopList:SelectFirstItem()
      end
    end
  end)

  local function openAdminPanel()
    local f = createFrame("ShadowTTT2 Adminpanel", 1040, 640)
    f.OnRemove = function()
      ShadowTTT2.AdminUI = nil
    end

    local header = vgui.Create("DLabel", f)
    header:SetPos(16, 52)
    header:SetSize(900, 24)
    header:SetFont("ST2.Subtitle")
    header:SetTextColor(THEME.muted)
    header:SetText("Moderation & Traitor-Shop Verwaltung")

    local sheet = vgui.Create("DPropertySheet", f)
    sheet:SetPos(12, 80)
    sheet:SetSize(1016, 548)
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
    actionGrid:Dock(TOP)
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
      {label = "Round Restart", id = "roundrestart"},
    }

    for _, info in ipairs(actions) do
      local btn = createActionButton(actionGrid, info.label, info.id, getSelectedSid)
      btn:SetWide(230)
    end

    local giveWeaponPanel = actionGrid:Add("DPanel")
    giveWeaponPanel:SetSize(230, 120)
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

    local giveWeaponEntry = vgui.Create("DTextEntry", giveWeaponPanel)
    giveWeaponEntry:Dock(TOP)
    giveWeaponEntry:DockMargin(10, 0, 10, 8)
    giveWeaponEntry:SetTall(30)
    giveWeaponEntry:SetFont("ST2.Body")
    giveWeaponEntry:SetTextColor(THEME.text)
    if giveWeaponEntry.SetPlaceholderText then
      giveWeaponEntry:SetPlaceholderText("Klasse eingeben (z.B. weapon_ttt_m16)")
    end
    giveWeaponEntry.Paint = function(self, w, h)
      draw.RoundedBox(8, 0, 0, w, h, Color(22, 22, 30, 230))
      self:DrawTextEntryText(THEME.text, THEME.accent, THEME.text)
    end

    local giveWeaponButton = vgui.Create("DButton", giveWeaponPanel)
    giveWeaponButton:Dock(BOTTOM)
    giveWeaponButton:DockMargin(10, 0, 10, 10)
    giveWeaponButton:SetTall(34)
    giveWeaponButton:SetText("Waffe geben")
    styleButton(giveWeaponButton)
    giveWeaponButton.DoClick = function()
      local sid = getSelectedSid()
      local class = string.Trim(giveWeaponEntry:GetText() or "")
      if not sid or class == "" then return end
      net.Start("ST2_ADMIN_ACTION")
      net.WriteString("giveweapon")
      net.WriteString(sid)
      net.WriteString(class)
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

    local shopList = vgui.Create("DListView", shopLeft)
    shopList:Dock(FILL)
    shopList:DockMargin(10, 0, 10, 10)
    shopList:AddColumn("Name")
    shopList:AddColumn("ID")
    shopList:AddColumn("Kategorie")
    shopList:AddColumn("Preis")
    shopList:AddColumn("Status")
    styleListView(shopList)

    local shopRefresh = vgui.Create("DButton", shopLeft)
    shopRefresh:Dock(BOTTOM)
    shopRefresh:DockMargin(10, 0, 10, 10)
    shopRefresh:SetTall(34)
    shopRefresh:SetText("Workshop erneut scannen")
    styleButton(shopRefresh)
    shopRefresh.DoClick = sendTraitorShopRescan

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

    sheet:AddSheet("Moderation", moderation, "icon16/user.png")
    sheet:AddSheet("Traitor Shop", shopPanel, "icon16/plugin.png")

    ShadowTTT2.AdminUI = {
      list = list,
      search = search,
      players = {},
      shopList = shopList,
      shopSearch = shopSearch,
      shopEntries = {},
    }

    requestAdminPlayerList(list)
    sendTraitorShopRequest()
  end

  net.Receive("ST2_ADMIN_OPEN", openAdminPanel)
end

local function collect_models()
  local set = {}
  -- 1) player_manager.AllValidModels()
  if player_manager and player_manager.AllValidModels then
    local am = player_manager.AllValidModels()
    if am and table.Count(am) > 0 then
      for k, v in pairs(am) do
        -- am may be {name=path} or {path=name}; try both
        if isstring(k) and util.IsValidModel(k) then set[k] = true end
        if isstring(v) and util.IsValidModel(v) then set[v] = true end
      end
    end
  end
  -- 2) list.Get("PlayerOptionsModel")
  local lm = list.Get("PlayerOptionsModel")
  if lm and table.Count(lm) > 0 then
    for k, v in pairs(lm) do
      if isstring(k) and util.IsValidModel(k) then set[k] = true end
      if isstring(v) and util.IsValidModel(v) then set[v] = true end
      if istable(v) and isstring(v.model) and util.IsValidModel(v.model) then set[v.model] = true end
    end
  end
  -- 3) fallback: recursively scan player model directories from mounted addons
  local function addModel(path)
    if util.IsValidModel(path) then set[path] = true end
  end

  local function scanModels(dir, depth)
    if depth <= 0 then return end
    local files, dirs = file.Find(dir .. "/*", "GAME")
    for _, f in ipairs(files) do
      if string.sub(f, -4) == ".mdl" then
        addModel(dir .. "/" .. f)
      end
    end
    for _, sub in ipairs(dirs) do
      scanModels(dir .. "/" .. sub, depth - 1)
    end
  end

  scanModels("models/player", 4)
  scanModels("models", 2) -- shallow scan to catch top-level models without recursing endlessly

  -- return sorted list
  local out = {}
  for m, _ in pairs(set) do table.insert(out, m) end
  table.sort(out)
  return out, set
end

local function openPointshop(models)
  if IsValid(activePointshopFrame) then
    activePointshopFrame:MakePopup()
    activePointshopFrame:RequestFocus()
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

  local previewTitle = vgui.Create("DLabel", right)
  previewTitle:Dock(TOP)
  previewTitle:DockMargin(10, 10, 10, 6)
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

  local selected = vgui.Create("DLabel", right)
  selected:Dock(BOTTOM)
  selected:DockMargin(10, 0, 10, 6)
  selected:SetTall(20)
  selected:SetFont("ST2.Mono")
  selected:SetTextColor(THEME.muted)
  selected:SetText("Kein Modell ausgewählt")

  local function selectModel(mdl)
    if not mdl then return end
    preview:SetModel(mdl)
    selected:SetText(mdl)
    equip.DoClick = function()
      net.Start("ST2_PS_EQUIP")
      net.WriteString(mdl)
      net.SendToServer()
    end
  end

  local function refreshList(filter)
    listv:Clear()
    local q = string.Trim(string.lower(filter or ""))
    local visible = 0
    for _, m in ipairs(models) do
      if q == "" or string.find(string.lower(m), q, 1, true) then
        local line = listv:AddLine(m)
        if IsValid(line) then
          if line.SetTextColor then
            line:SetTextColor(THEME.text)
          else
            for _, col in ipairs(line.Columns or {}) do
              if IsValid(col) and col.SetTextColor then
                col:SetTextColor(THEME.text)
              end
            end
          end
          line.Paint = function(self, w, h)
            local bg = self:IsLineSelected() and THEME.accent or Color(255, 255, 255, 6)
            draw.RoundedBox(0, 0, 0, w, h, bg)
          end
        end
        visible = visible + 1
      end
    end
    counter:SetText(string.format("%d / %d Modelle sichtbar", visible, #models))
  end

  listv.OnRowSelected = function(_, _, line)
    selectModel(line:GetColumnText(1))
  end

  search.OnValueChange = function(_, value)
    refreshList(value)
  end

  refreshList("")
  listv:SelectFirstItem()
end

hook.Add("PlayerButtonDown", "ST2_F3_POINTSHOP_FINAL", function(_, key)
  if key ~= KEY_F3 then return end

  timer.Simple(0.1, function()
    local models = collect_models()
    print("[ShadowTTT2] Found models count:", #models)
    if #models == 0 then
      local am = (player_manager and player_manager.AllValidModels and table.Count(player_manager.AllValidModels())) or 0
      local lm = (list.Get and table.Count(list.Get("PlayerOptionsModel") or {})) or 0
      print("[ShadowTTT2] DEBUG: player_manager.AllValidModels count:", am)
      print("[ShadowTTT2] DEBUG: list.Get('PlayerOptionsModel') count:", lm)
      chat.AddText(Color(200, 60, 60), "ShadowTTT2 Pointshop: no models found clientside. See console for details.")
      return
    end

    openPointshop(models)
  end)
end)

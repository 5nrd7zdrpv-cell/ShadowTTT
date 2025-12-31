
print("[ShadowTTT2] MODEL-ENUM CLIENT loaded")

ShadowTTT2 = ShadowTTT2 or {}
ShadowTTT2.CoreClientLoaded = true
ShadowTTT2.PointshopEnhanced = true

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

  local function addRow(list, ...)
    local line = list:AddLine(...)
    if not IsValid(line) then return end
    line:SetTextColor(THEME.text)
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
    local btn = vgui.Create("DButton", parent)
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

  local function openAdminPanel()
    local f = createFrame("ShadowTTT2 Adminpanel", 1040, 640)
    f.OnRemove = function()
      ShadowTTT2.AdminUI = nil
    end

    local header = vgui.Create("DLabel", f)
    header:SetPos(16, 52)
    header:SetSize(720, 24)
    header:SetFont("ST2.Subtitle")
    header:SetTextColor(THEME.muted)
    header:SetText("Moderate rounds schneller: wähle einen Spieler und eine Aktion")

    local container = vgui.Create("DPanel", f)
    container:SetPos(12, 80)
    container:SetSize(1016, 548)
    container.Paint = function(_, w, h)
      draw.RoundedBox(12, 0, 0, w, h, Color(26, 26, 34, 230))
    end

    local left = vgui.Create("DPanel", container)
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

    local right = vgui.Create("DPanel", container)
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

    local actionGrid = vgui.Create("DIconLayout", right)
    actionGrid:Dock(FILL)
    actionGrid:DockMargin(10, 0, 10, 10)
    actionGrid:SetSpaceX(10)
    actionGrid:SetSpaceY(10)

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

    ShadowTTT2.AdminUI = {
      list = list,
      search = search,
      players = {},
    }

    requestAdminPlayerList(list)
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
  local f = createFrame("ShadowTTT2 Pointshop", 1040, 640)

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

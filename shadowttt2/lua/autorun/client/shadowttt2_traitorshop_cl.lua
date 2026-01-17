
print("[ShadowTTT2] Traitor Shop // Nova Forge UI")

ShadowTTT2 = ShadowTTT2 or {}
ShadowTTT2.TraitorShop = ShadowTTT2.TraitorShop or {}

local function traitorShopEnabled()
  local cvar = GetConVar("shadowttt2_traitorshop_enabled")
  if not cvar then
    return true
  end
  return cvar:GetBool()
end

local snapshot = {
  owned = {},
  catalogue = {},
  blueprints = {},
  project = nil,
  credits = 0
}

local refreshUI
local activeFrame
local externalRefreshers = {}

local function isActiveTraitor(ply)
  if not IsValid(ply) then return false end
  if ply.IsActiveTraitor then return ply:IsActiveTraitor() end
  if ply.IsTraitor then return ply:IsTraitor() end
  if ply.GetRole and ROLE_TRAITOR then return ply:GetRole() == ROLE_TRAITOR end
  return false
end

local THEME = {
  bg = Color(10, 12, 18, 245),
  panel = Color(21, 26, 34, 255),
  accent = Color(255, 90, 120),
  accentSoft = Color(140, 110, 255),
  text = Color(235, 240, 245),
  muted = Color(175, 185, 200),
  success = Color(115, 205, 155),
  warning = Color(255, 200, 90)
}

local WHITE_TEX = surface.GetTextureID("vgui/white")

surface.CreateFont("ST2.Hero", {font = "Roboto", size = 28, weight = 800})
surface.CreateFont("ST2.Title", {font = "Roboto", size = 22, weight = 700})
surface.CreateFont("ST2.Body", {font = "Roboto", size = 16, weight = 600})
surface.CreateFont("ST2.Small", {font = "Roboto", size = 14, weight = 500})
surface.CreateFont("ST2.Mono", {font = "Consolas", size = 14, weight = 500})

local function requestSnapshot()
  if not traitorShopEnabled() then return end
  net.Start("ST2_TS_SYNC_REQUEST")
  net.SendToServer()
end

local function canAccessTraitorShop()
  local ply = LocalPlayer()
  return traitorShopEnabled() and isActiveTraitor(ply)
end

local function formatTime(rem)
  if rem <= 0 then return "Fertig" end
  if rem < 10 then return string.format("%.1fs", rem) end
  return string.format("%ds", math.ceil(rem))
end

local function gradientPaint(col1, col2)
  return function(self, w, h)
    local x, y = self:LocalToScreen(0, 0)
    local panel = {
      {
        x = x, y = y, u = 0, v = 0, color = col1
      },
      {
        x = x + w, y = y, u = 1, v = 0, color = col2
      },
      {
        x = x + w, y = y + h, u = 1, v = 1, color = col2
      },
      {
        x = x, y = y + h, u = 0, v = 1, color = col1
      }
    }
    surface.SetTexture(WHITE_TEX)
    surface.DrawPoly(panel)
  end
end

local function buildStatsBar(parent)
  local bar = vgui.Create("DPanel", parent)
  bar:Dock(TOP)
  bar:SetTall(78)
  bar:DockMargin(0, 0, 0, 12)
  bar.Paint = function(self, w, h)
    draw.RoundedBox(12, 0, 0, w, h, THEME.panel)
    surface.SetDrawColor(THEME.accent)
    surface.DrawRect(0, h - 4, w, 4)
  end

  local credit = vgui.Create("DLabel", bar)
  credit:SetFont("ST2.Hero")
  credit:SetTextColor(THEME.text)
  credit:SetPos(20, 16)
  credit:SetText("Credits: " .. snapshot.credits)
  credit:SizeToContents()

  local owned = vgui.Create("DLabel", bar)
  owned:SetFont("ST2.Body")
  owned:SetTextColor(THEME.muted)
  owned:SetPos(22, 46)
  owned:SetText("Freigeschaltet: " .. table.Count(snapshot.owned or {}))
  owned:SizeToContents()

  local project = vgui.Create("DLabel", bar)
  project:SetFont("ST2.Body")
  project:SetTextColor(THEME.text)
  project:SetPos(320, 20)
  project:SetText("Werkstatt: " .. (snapshot.project and "Aktives Projekt" or "Leer"))
  project:SizeToContents()

  local refresher = vgui.Create("DButton", bar)
  refresher:Dock(RIGHT)
  refresher:DockMargin(0, 20, 16, 20)
  refresher:SetWide(170)
  refresher:SetText("")
  refresher.Paint = function(self, w, h)
    draw.RoundedBox(10, 0, 0, w, h, THEME.accentSoft)
    draw.SimpleText("Sync & Scan", "ST2.Body", w / 2, h / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
  end
  refresher.DoClick = requestSnapshot

  return function()
    credit:SetText("Credits: " .. snapshot.credits)
    credit:SizeToContents()
    owned:SetText("Freigeschaltet: " .. table.Count(snapshot.owned or {}))
    owned:SizeToContents()
    project:SetText("Werkstatt: " .. (snapshot.project and "Aktives Projekt" or "Leer"))
    project:SizeToContents()
  end
end

local function buildItemCard(layout, catId, item)
  local pnl = layout:Add("DPanel")
  pnl:SetSize(330, 130)
  pnl.Paint = function(self, w, h)
    draw.RoundedBox(12, 0, 0, w, h, THEME.panel)
    surface.SetDrawColor(ColorAlpha(THEME.accent, 40))
    surface.DrawRect(0, 0, 4, h)
    draw.SimpleText(item.name, "ST2.Title", 18, 14, THEME.text, TEXT_ALIGN_LEFT)
    draw.SimpleText(item.desc or "", "ST2.Small", 18, 44, THEME.muted, TEXT_ALIGN_LEFT)
    draw.SimpleText(item.price .. " Credits", "ST2.Body", 18, h - 28, THEME.accent, TEXT_ALIGN_LEFT)
  end

  local icon = vgui.Create("DImage", pnl)
  icon:SetSize(64, 64)
  icon:SetPos(250, 16)
  icon:SetImage(item.icon or "icon16/plugin.png")
  icon:SetVisible(item.icon ~= "" and item.icon ~= nil)

  local btn = vgui.Create("DButton", pnl)
  btn:SetSize(160, 32)
  btn:SetPos(18, 82)
  btn:SetText("")
  btn.Paint = function(self, w, h)
    local col = self:IsEnabled() and THEME.accentSoft or Color(80, 85, 95)
    draw.RoundedBox(8, 0, 0, w, h, col)
    draw.SimpleText(self:GetText(), "ST2.Body", w / 2, h / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
  end

  local badge = vgui.Create("DLabel", pnl)
  badge:SetFont("ST2.Small")
  badge:SetTextColor(THEME.muted)
  badge:SetPos(200, 90)
  badge:SetText("")
  badge:SizeToContents()

  local function refresh()
    local owned = snapshot.owned and snapshot.owned[item.id]
    if owned then
      btn:SetText("Bereits gekauft")
      btn:SetEnabled(false)
      badge:SetText("Gearbeitet in Werkstatt")
      badge:SetTextColor(THEME.success)
      badge:SizeToContents()
      return
    end

    if snapshot.credits < item.price then
      btn:SetText("Zu wenig Credits")
      btn:SetEnabled(false)
      badge:SetText("Benötigt " .. item.price .. " Credits")
      badge:SetTextColor(THEME.warning)
      badge:SizeToContents()
      return
    end

    btn:SetEnabled(true)
    btn:SetText("Sofort kaufen")
    badge:SetText("Bereit")
    badge:SetTextColor(THEME.muted)
    badge:SizeToContents()
  end

  btn.DoClick = function()
    net.Start("ST2_TS_BUY")
      net.WriteString(catId)
      net.WriteString(item.id)
    net.SendToServer()
  end

  if item.wsid and item.wsid ~= "" then
    btn.DoRightClick = function()
      local menu = DermaMenu()
      menu:AddOption("Workshop Details öffnen", function()
        gui.OpenURL("https://steamcommunity.com/workshop/filedetails/?id=" .. item.wsid)
      end):SetIcon("icon16/plugin.png")
      if item.author then
        menu:AddOption("Autor: " .. item.author, function() end):SetIcon("icon16/user.png")
      end
      menu:Open()
    end
  end

  refresh()
  return refresh
end

local function buildWorkshopCard(layout, blueprint)
  local pnl = layout:Add("DPanel")
  pnl:SetSize(330, 130)
  pnl.Paint = function(self, w, h)
    draw.RoundedBox(12, 0, 0, w, h, THEME.panel)
    surface.SetDrawColor(ColorAlpha(THEME.accentSoft, 60))
    surface.DrawRect(0, 0, w, 4)
    draw.SimpleText(blueprint.name, "ST2.Title", 16, 10, THEME.text)
    draw.SimpleText(blueprint.desc or "", "ST2.Small", 16, 40, THEME.muted)
  end

  local btn = vgui.Create("DButton", pnl)
  btn:SetSize(200, 34)
  btn:SetPos(16, 80)
  btn:SetText("")

  local progress = vgui.Create("DPanel", pnl)
  progress:SetPos(16, 68)
  progress:SetSize(200, 8)
  progress.Paint = function(self, w, h)
    draw.RoundedBox(6, 0, 0, w, h, Color(40, 50, 60))
    local project = snapshot.project
    if project and project.id == blueprint.id then
      local dur = (project.readyAt or 0) - (project.started or 0)
      local pct = dur > 0 and math.Clamp((CurTime() - (project.started or 0)) / dur, 0, 1) or 1
      draw.RoundedBox(6, 0, 0, w * pct, h, THEME.accentSoft)
    end
  end

  local badge = vgui.Create("DLabel", pnl)
  badge:SetFont("ST2.Small")
  badge:SetPos(230, 86)
  badge:SetTextColor(THEME.muted)
  badge:SetText("")
  badge:SizeToContents()

  local function refresh()
    local project = snapshot.project
    progress:SetVisible(project and project.id == blueprint.id)

    if project and project.id ~= blueprint.id then
      btn:SetText("Werkstatt belegt")
      btn:SetEnabled(false)
      badge:SetText("Aktives Projekt läuft")
      badge:SetTextColor(THEME.warning)
      badge:SizeToContents()
      return
    end

    if project and project.id == blueprint.id then
      local remaining = math.max(0, (project.readyAt or 0) - CurTime())
      if remaining <= 0 then
        btn:SetText("Fertigstellen & Claim")
        btn:SetEnabled(true)
        btn.DoClick = function()
          net.Start("ST2_TS_WORKSHOP")
            net.WriteString("claim")
            net.WriteString(blueprint.id)
          net.SendToServer()
        end
        badge:SetText("Bereit zur Abholung")
        badge:SetTextColor(THEME.success)
        badge:SizeToContents()
      else
        btn:SetText("Baut... " .. formatTime(remaining))
        btn:SetEnabled(false)
        btn.DoClick = nil
        badge:SetText("Fortschritt läuft")
        badge:SetTextColor(THEME.warning)
        badge:SizeToContents()
      end
      return
    end

    if blueprint.requiresOwned and not (snapshot.owned and snapshot.owned[blueprint.requiresOwned]) then
      btn:SetText("Benötigt Basis-Item")
      btn:SetEnabled(false)
      badge:SetText("Erst " .. (blueprint.requiresOwned or "") .. " kaufen")
      badge:SetTextColor(THEME.warning)
      badge:SizeToContents()
      return
    end

    if snapshot.credits < blueprint.price then
      btn:SetText("Zu wenig Credits")
      btn:SetEnabled(false)
      badge:SetText("Kosten: " .. blueprint.price .. "c")
      badge:SetTextColor(THEME.warning)
      badge:SizeToContents()
      return
    end

    btn:SetEnabled(true)
    btn:SetText("Bau starten (" .. blueprint.price .. "c)")
    btn.DoClick = function()
      net.Start("ST2_TS_WORKSHOP")
        net.WriteString("start")
        net.WriteString(blueprint.id)
      net.SendToServer()
    end
    badge:SetText("Bauzeit: " .. formatTime(blueprint.buildTime or 5))
    badge:SetTextColor(THEME.muted)
    badge:SizeToContents()
  end

  btn.Paint = function(self, w, h)
    local col = self:IsEnabled() and THEME.accent or Color(70, 75, 85)
    draw.RoundedBox(10, 0, 0, w, h, col)
    draw.SimpleText(self:GetText(), "ST2.Body", w / 2, h / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
  end

  refresh()
  return refresh
end

local function buildShopTab(parent)
  local container = vgui.Create("DPanel", parent)
  container:Dock(FILL)
  container:DockMargin(0, 0, 0, 0)
  container.Paint = function(self, w, h)
    draw.RoundedBox(12, 0, 0, w, h, Color(18, 22, 30, 255))
  end

  local search = vgui.Create("DTextEntry", container)
  search:Dock(TOP)
  search:DockMargin(16, 16, 16, 8)
  search:SetTall(30)
  search:SetPlaceholderText("Suche nach Item oder Kategorie...")

  local filterRow = vgui.Create("DIconLayout", container)
  filterRow:Dock(TOP)
  filterRow:DockMargin(16, 0, 16, 8)
  filterRow:SetTall(28)
  filterRow:SetSpaceX(8)

  local list = vgui.Create("DIconLayout", container)
  list:Dock(FILL)
  list:DockMargin(16, 0, 16, 16)
  list:SetSpaceX(12)
  list:SetSpaceY(12)

  local refreshers = {}
  local activeFilter = "all"
  local lastCatalogue = nil

  local function rebuild()
    list:Clear()
    table.Empty(refreshers)

    for catId, cat in pairs(snapshot.catalogue or {}) do
      if activeFilter == "all" or activeFilter == catId then
        for _, item in ipairs(cat.items or {}) do
          local query = string.lower(search:GetText() or "")
          local searchMatch = query == "" or string.find(string.lower(item.name .. " " .. (item.desc or "")), query, 1, true)
          if searchMatch then
            table.insert(refreshers, buildItemCard(list, catId, item))
          end
        end
      end
    end
    list:InvalidateLayout(true)
  end

  local function addFilter(id, label)
    local btn = filterRow:Add("DButton")
    btn:SetSize(110, 28)
    btn:SetText("")
    btn.Paint = function(self, w, h)
      local active = activeFilter == id
      local col = active and THEME.accentSoft or THEME.panel
      draw.RoundedBox(8, 0, 0, w, h, col)
      draw.SimpleText(label, "ST2.Small", w / 2, h / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    btn.DoClick = function()
      activeFilter = id
      rebuild()
    end
  end

  local function rebuildFilters()
    local catalogue = snapshot.catalogue or {}
    if lastCatalogue == catalogue then return end
    lastCatalogue = catalogue

    filterRow:Clear()
    addFilter("all", "Alles")
    for catId, cat in pairs(catalogue) do
      addFilter(catId, cat.name or catId)
    end

    if activeFilter ~= "all" and not catalogue[activeFilter] then
      activeFilter = "all"
    end
    filterRow:InvalidateLayout(true)
  end

  search.OnChange = rebuild
  rebuildFilters()
  rebuild()

  local function refresh()
    rebuildFilters()
    rebuild()
    for _, fn in ipairs(refreshers) do
      fn()
    end
  end

  return container, refresh
end

local function buildWorkshopTab(parent)
  local container = vgui.Create("DPanel", parent)
  container:Dock(FILL)
  container.Paint = function(self, w, h)
    draw.RoundedBox(12, 0, 0, w, h, Color(18, 22, 30, 255))
  end

  local header = vgui.Create("DLabel", container)
  header:Dock(TOP)
  header:DockMargin(16, 14, 16, 8)
  header:SetFont("ST2.Title")
  header:SetTextColor(THEME.text)
  header:SetText("Werkstatt // Baue einzigartige Upgrades")
  header:SizeToContents()

  local list = vgui.Create("DIconLayout", container)
  list:Dock(FILL)
  list:DockMargin(16, 0, 16, 16)
  list:SetSpaceX(12)
  list:SetSpaceY(12)

  local refreshers = {}

  local function rebuildCards()
    list:Clear()
    table.Empty(refreshers)
    for _, blueprint in ipairs(snapshot.blueprints or {}) do
      table.insert(refreshers, buildWorkshopCard(list, blueprint))
    end
    list:InvalidateLayout(true)
  end

  local function refresh()
    rebuildCards()
    for _, fn in ipairs(refreshers) do
      fn()
    end
  end

  rebuildCards()
  return container, refresh
end

local function buildTraitorShopPanel(parent)
  local container = vgui.Create("DPanel", parent)
  container:Dock(FILL)
  container.Paint = function(_, w, h)
    draw.RoundedBox(12, 0, 0, w, h, Color(18, 22, 30, 255))
  end

  local intro = vgui.Create("DPanel", container)
  intro:Dock(TOP)
  intro:DockMargin(16, 16, 16, 10)
  intro:SetTall(54)
  intro.Paint = function(_, w, h)
    draw.RoundedBox(10, 0, 0, w, h, Color(28, 32, 44, 230))
  end

  local title = vgui.Create("DLabel", intro)
  title:Dock(TOP)
  title:DockMargin(12, 8, 12, 0)
  title:SetFont("ST2.Title")
  title:SetTextColor(THEME.text)
  title:SetText("Traitor Workshop")

  local subtitle = vgui.Create("DLabel", intro)
  subtitle:Dock(TOP)
  subtitle:DockMargin(12, 2, 12, 0)
  subtitle:SetFont("ST2.Small")
  subtitle:SetTextColor(THEME.muted)
  subtitle:SetText("Baue, kaufe und optimiere deine Ausrüstung.")

  local state = vgui.Create("DLabel", container)
  state:Dock(FILL)
  state:DockMargin(24, 0, 24, 24)
  state:SetFont("ST2.Body")
  state:SetTextColor(THEME.muted)
  state:SetWrap(true)
  state:SetContentAlignment(5)

  local content = vgui.Create("DPanel", container)
  content:Dock(FILL)
  content:DockMargin(16, 0, 16, 16)
  content.Paint = function() end

  local statsUpdater = buildStatsBar(content)

  local tabs = vgui.Create("DPropertySheet", content)
  tabs:Dock(FILL)
  tabs:SetFadeTime(0)
  tabs.Paint = function(self, w, h)
    draw.RoundedBox(12, 0, 0, w, h, Color(14, 18, 26, 255))
  end
  function tabs:PaintTab(tab, w, h)
    local active = self:GetActiveTab() == tab
    local col = active and THEME.accentSoft or THEME.panel
    draw.RoundedBox(8, 0, 0, w, h, col)
    draw.SimpleText(tab:GetText(), "ST2.Body", 12, h / 2, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
  end

  local shopPanel, shopRefresh = buildShopTab(tabs)
  local workshopPanel, workshopRefresh = buildWorkshopTab(tabs)

  tabs:AddSheet("Shop", shopPanel, "icon16/cart.png")
  tabs:AddSheet("Werkstatt", workshopPanel, "icon16/wrench.png")

  local function refresh()
    if not IsValid(container) then return false end
    local enabled = traitorShopEnabled()
    local canAccess = enabled and isActiveTraitor(LocalPlayer())
    if IsValid(content) then content:SetVisible(canAccess) end
    if IsValid(state) then
      state:SetVisible(not canAccess)
      if not enabled then
        state:SetText("Der Traitor Shop ist serverseitig deaktiviert.")
      else
        state:SetText("Der Traitor Shop ist nur für aktive Traitor verfügbar.")
      end
    end
    if canAccess then
      if statsUpdater then statsUpdater() end
      if shopRefresh then shopRefresh() end
      if workshopRefresh then workshopRefresh() end
    end
    return true
  end

  refresh()
  return container, refresh
end

local function registerExternalRefresh(fn)
  if not isfunction(fn) then return end
  table.insert(externalRefreshers, fn)
end

local function runExternalRefreshers()
  for i = #externalRefreshers, 1, -1 do
    local fn = externalRefreshers[i]
    if not isfunction(fn) then
      table.remove(externalRefreshers, i)
    else
      local ok = fn()
      if ok == false then
        table.remove(externalRefreshers, i)
      end
    end
  end
end

local function buildFrame()
  if IsValid(activeFrame) then activeFrame:Remove() end

  activeFrame = vgui.Create("DFrame")
  activeFrame:SetSize(960, 620)
  activeFrame:Center()
  activeFrame:MakePopup()
  activeFrame:SetTitle("")
  activeFrame:ShowCloseButton(true)
  activeFrame.OnRemove = function()
    refreshUI = nil
    activeFrame = nil
  end
  activeFrame.Paint = function(self, w, h)
    draw.RoundedBox(8, 0, 0, w, h, THEME.bg)
    local grad = gradientPaint(Color(20, 24, 35, 255), ColorAlpha(THEME.accentSoft, 60))
    grad(self, w, 120)
    draw.SimpleText("ShadowTTT2 // Traitor Workshop", "ST2.Hero", 18, 12, color_white)
    draw.SimpleText("Baue, kaufe und optimiere deine Ausrüstung mit dem neuen Werkstatt-Prinzip.", "ST2.Body", 20, 46, THEME.muted)
  end

  local content = vgui.Create("DPanel", activeFrame)
  content:Dock(FILL)
  content:DockMargin(16, 96, 16, 16)
  content.Paint = function() end

  local _, refresh = buildTraitorShopPanel(content)

  refreshUI = function()
    if not IsValid(activeFrame) then return end
    if refresh then refresh() end
  end
end

net.Receive("ST2_TS_SYNC", function()
  if not traitorShopEnabled() then
    if IsValid(activeFrame) then activeFrame:Remove() end
    return
  end

  local data = net.ReadTable() or {}
  snapshot.owned = data.owned or {}
  snapshot.catalogue = data.catalogue or snapshot.catalogue or {}
  snapshot.blueprints = data.blueprints or snapshot.blueprints or {}
  snapshot.project = data.project
  snapshot.credits = data.credits or LocalPlayer():GetCredits()

  if isfunction(refreshUI) then
    refreshUI()
  end
  runExternalRefreshers()
end)

local function openTraitorShop()
  if not traitorShopEnabled() then return end
  local ply = LocalPlayer()
  if not isActiveTraitor(ply) then return end

  requestSnapshot()
  buildFrame()
end

ShadowTTT2.TraitorShop.BuildPanel = function(parent)
  return buildTraitorShopPanel(parent)
end

ShadowTTT2.TraitorShop.RequestSnapshot = requestSnapshot

ShadowTTT2.TraitorShop.CanAccess = function()
  return canAccessTraitorShop()
end

ShadowTTT2.TraitorShop.RegisterRefresh = registerExternalRefresh

hook.Add("PlayerButtonDown", "ST2_TS_PHASE3_FIX", function(ply, key)
  if ply ~= LocalPlayer() then return end
  if key ~= KEY_C then return end

  openTraitorShop()
end)

hook.Add("PlayerButtonDown", "ST2_TS_OPEN_V", function(ply, key)
  if ply ~= LocalPlayer() then return end
  if key ~= KEY_V then return end

  openTraitorShop()
end)

hook.Add("PlayerBindPress", "ST2_TS_CONTEXT_BIND", function(ply, bind, pressed)
  if ply ~= LocalPlayer() or not pressed then return end
  if not bind or not string.find(string.lower(bind), "menu_context", 1, true) then return end

  openTraitorShop()
  return true
end)

cvars.AddChangeCallback("shadowttt2_traitorshop_enabled", function(_, _, new)
  if tostring(new) == "0" and IsValid(activeFrame) then
    activeFrame:Remove()
  end
end, "ST2_TS_DISABLE_UI")


print("[ShadowTTT2] Traitor Shop // Nova Forge server init")

ShadowTTT2 = ShadowTTT2 or {}

local shopEnabled = CreateConVar("shadowttt2_traitorshop_enabled", "0", {FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY}, "Enable ShadowTTT2 custom traitor shop")

local function traitorShopEnabled()
  return shopEnabled and shopEnabled:GetBool()
end

util.AddNetworkString("ST2_TS_BUY")
util.AddNetworkString("ST2_TS_SYNC")
util.AddNetworkString("ST2_TS_SYNC_REQUEST")
util.AddNetworkString("ST2_TS_WORKSHOP")
util.AddNetworkString("ST2_TS_ADMIN_CONFIG")
util.AddNetworkString("ST2_TS_ADMIN_CONFIG_REQUEST")
util.AddNetworkString("ST2_TS_ADMIN_TOGGLE")
util.AddNetworkString("ST2_TS_ADMIN_RESCAN")
util.AddNetworkString("ST2_TS_ADMIN_PRICE")
util.AddNetworkString("ST2_TS_ADMIN_ADD")

local Owned = {}
local Projects = {}
local Catalogue = {}
local CatalogueLookup = {}

local BLUEPRINTS = {
  {id = "workshop_overclock", name = "Overclock Mod", desc = "Veredle deine Remote C4 zu einer stärkeren Ladung.", price = 2, buildTime = 8, rewardWeapon = "weapon_ttt_c4", requiresOwned = "weapon_ttt_c4"},
  {id = "workshop_spyglass", name = "Spyglass Kit", desc = "Verbessert dein Radar um schnellere Pings.", price = 1, buildTime = 6, rewardWeapon = "weapon_ttt_radar", requiresOwned = "weapon_ttt_radar"},
  {id = "workshop_echo", name = "Echo-Projector", desc = "Upgradet den Decoy zu einem lauteren Ablenkungswerkzeug.", price = 1, buildTime = 5, rewardWeapon = "weapon_ttt_decoy", requiresOwned = "weapon_ttt_decoy"},
  {id = "workshop_anchor", name = "Grapple Anchor", desc = "Baue ein kinetisches Seil für riskante Fluchten.", price = 2, buildTime = 10, rewardWeapon = "weapon_ttt_teleport", requiresOwned = "weapon_ttt_teleport"}
}

local SHOP_CONFIG_PATH = "shadowttt2/traitor_shop.json"
local PROGRESS_PATH = "shadowttt2/traitor_progress.json"
local ShopConfig = {
  enabled = {},
  prices = {},
  custom = {}
}

local TRAITOR_ROLE = ROLE_TRAITOR or 2

local function isAdmin(ply)
  if ShadowTTT2 and ShadowTTT2.IsAdmin then
    return ShadowTTT2.IsAdmin(ply)
  end

  return IsValid(ply) and ShadowTTT2.Admins and (ShadowTTT2.Admins[ply:SteamID()] or ShadowTTT2.Admins[ply:SteamID64()])
end

local function getBlueprint(id)
  for _, bp in ipairs(BLUEPRINTS) do
    if bp.id == id then return bp end
  end
end

local function ensureDataFolder()
  if not file.Exists("shadowttt2", "DATA") then
    file.CreateDir("shadowttt2")
  end
end

local function safeJsonDecode(raw)
  if not raw or raw == "" then return end

  local ok, decoded = pcall(util.JSONToTable, raw)
  if not ok or not istable(decoded) then return end

  return decoded
end

local function sanitizeOwned(owned)
  local cleaned = {}
  if not istable(owned) then return cleaned end

  for id, state in pairs(owned) do
    if isstring(id) and state then
      cleaned[id] = true
    end
  end

  return cleaned
end

local function sanitizeProject(project)
  if not istable(project) or not isstring(project.id) then return end

  local bp = getBlueprint(project.id)
  if not bp then return end

  local started = tonumber(project.started) or CurTime()
  local readyAt = tonumber(project.readyAt) or (started + (bp.buildTime or 5))
  if readyAt <= started then return end
  local now = CurTime()
  -- Drop obviously stale projects that have been left unclaimed for a long time.
  if readyAt + 6 * 3600 < now then return end

  return {
    id = bp.id,
    started = started,
    readyAt = readyAt
  }
end

local function getPlayerId(ply)
  if not IsValid(ply) then return end
  return ply:SteamID()
end

local function persistState()
  ensureDataFolder()

  local payload = {}
  local seen = {}

  for steamid in pairs(Owned) do
    seen[steamid] = true
  end

  for steamid in pairs(Projects) do
    seen[steamid] = true
  end

  for steamid in pairs(seen) do
    local owned = sanitizeOwned(Owned[steamid])
    local project = sanitizeProject(Projects[steamid])

    Owned[steamid] = next(owned) and owned or nil
    Projects[steamid] = project

    if Owned[steamid] or Projects[steamid] then
      payload[steamid] = {
        owned = Owned[steamid] or {},
        project = Projects[steamid]
      }
    end
  end

  local encoded = util.TableToJSON(payload, true)
  if encoded then
    file.Write(PROGRESS_PATH, encoded)
  end
end

local function loadProgress()
  ensureDataFolder()

  if not file.Exists(PROGRESS_PATH, "DATA") then return end

  local decoded = safeJsonDecode(file.Read(PROGRESS_PATH, "DATA"))
  if not decoded then return end

  for steamid, data in pairs(decoded) do
    if not isstring(steamid) or not istable(data) then continue end

    local owned = sanitizeOwned(data.owned)
    local project = sanitizeProject(data.project)

    if next(owned) then
      Owned[steamid] = owned
    end

    if project then
      Projects[steamid] = project
    end
  end
end

local function ensurePlayerState(ply)
  local steamid = getPlayerId(ply)
  if not steamid then return end

  Owned[steamid] = Owned[steamid] or {}

  local project = sanitizeProject(Projects[steamid])
  if Projects[steamid] ~= project then
    Projects[steamid] = project
  end

  return steamid
end

local function cleanupProject(steamid)
  if not steamid then return end

  local project = sanitizeProject(Projects[steamid])
  if Projects[steamid] ~= project then
    Projects[steamid] = project
    persistState()
  end
end

local function loadShopConfig()
  ensureDataFolder()
  if not file.Exists(SHOP_CONFIG_PATH, "DATA") then return end

  local raw = file.Read(SHOP_CONFIG_PATH, "DATA")
  local decoded = raw and util.JSONToTable(raw)
  if not istable(decoded) then return end

  ShopConfig.enabled = decoded.enabled or {}
  ShopConfig.prices = decoded.prices or {}
  ShopConfig.custom = decoded.custom or {}
end

local function saveShopConfig()
  ensureDataFolder()
  file.Write(SHOP_CONFIG_PATH, util.TableToJSON({
    enabled = ShopConfig.enabled,
    prices = ShopConfig.prices,
    custom = ShopConfig.custom
  }, true))
end

local function itemEnabled(id)
  local state = ShopConfig.enabled[id]
  if state == nil then return true end
  return state
end

local function getItemPrice(id, wep)
  if ShopConfig.prices[id] then
    return ShopConfig.prices[id]
  end

  if istable(wep) then
    if isnumber(wep.price) then return wep.price end
    if isnumber(wep.Price) then return wep.Price end
  end

  if istable(wep) and istable(wep.EquipMenuData) then
    if wep.EquipMenuData.price then return wep.EquipMenuData.price end
    if wep.EquipMenuData.cost then return wep.EquipMenuData.cost end
  end

  if istable(wep) and wep.Cost then
    return wep.Cost
  end

  return 1
end

local function buildItemData(id, wep, fallbackCategory)
  if not id or id == "" then return end

  local stored = wep or weapons.GetStored(id) or weapons.Get(id)
  local menu = stored and stored.EquipMenuData or {}
  local name = menu.name or (stored and stored.PrintName) or id
  local desc = menu.desc or (menu.description or (stored and stored.Instructions)) or ""
  local category = string.lower(menu.type or fallbackCategory or "custom")
  local icon = (menu and menu.icon) or (stored and (stored.Icon or stored.IconOverride))
  local author = stored and (stored.Author or stored.author)

  return {
    id = id,
    name = name,
    desc = desc,
    weapon = id,
    price = getItemPrice(id, stored),
    icon = icon,
    category = category,
    author = author
  }
end

local function buildTraitorItemsFromWorkshop()
  local entries = {}
  local seen = {}
  for _, wep in ipairs(weapons.GetList()) do
    if not istable(wep.CanBuy) then continue end

    local buyable = false
    for _, role in ipairs(wep.CanBuy) do
      if role == TRAITOR_ROLE then
        buyable = true
        break
      end
    end

    if not buyable then continue end

    local id = wep.ClassName or wep.Classname or wep.PrintName
    if not id then continue end
    if seen[id] then continue end
    seen[id] = true

    local menu = wep.EquipMenuData or {}
    local name = menu.name or wep.PrintName or id
    local desc = menu.desc or menu.description or wep.Instructions or ""
    local category = string.lower(menu.type or "workshop")

    table.insert(entries, {
      id = id,
      name = name,
      desc = desc,
      weapon = id,
      price = getItemPrice(id, wep),
      icon = menu.icon or wep.Icon or wep.IconOverride,
      category = category,
      author = wep.Author or wep.author
    })
  end

  table.sort(entries, function(a, b) return string.lower(a.name) < string.lower(b.name) end)
  return entries
end

local function addItemToCatalogue(item)
  if not item or not item.id then return end
  CatalogueLookup[item.id] = item
  if not itemEnabled(item.id) then return end

  local catId = item.category or "workshop"
  local catName = string.gsub(catId, "^%l", string.upper)

  Catalogue[catId] = Catalogue[catId] or {
    name = catName,
    icon = "icon16/plugin.png",
    items = {}
  }

  table.insert(Catalogue[catId].items, item)
end

local function rebuildCatalogue()
  Catalogue = {}
  CatalogueLookup = {}

  local entries = buildTraitorItemsFromWorkshop()
  for _, item in ipairs(entries) do
    addItemToCatalogue(item)
  end

  for id, data in pairs(ShopConfig.custom or {}) do
    if CatalogueLookup[id] then continue end
    local entry = buildItemData(id, data, data.category or "custom")
    if entry then
      entry.price = data.price or entry.price
      entry.icon = data.icon or entry.icon
      entry.author = data.author or entry.author
      entry.category = data.category or entry.category
      addItemToCatalogue(entry)
    end
  end
end

local function resetPlayer(ply)
  local steamid = ensurePlayerState(ply)
  if not steamid then return end

  if not next(Owned[steamid]) and not Projects[steamid] then
    Owned[steamid] = nil
    Projects[steamid] = nil
  end

  persistState()
end

local function canAccessShop(ply)
  return traitorShopEnabled() and IsValid(ply) and ply:IsActiveTraitor()
end

local function sendSnapshot(ply)
  if not traitorShopEnabled() then return end
  if not IsValid(ply) then return end

  net.Start("ST2_TS_SYNC")
    net.WriteTable({
      owned = Owned[steamid] or {},
      project = Projects[steamid],
      credits = ply:GetCredits(),
      catalogue = Catalogue,
      blueprints = BLUEPRINTS
    })
  net.Send(ply)
end

hook.Add("TTTBeginRound","ST2_TS_ResetOwned", function()
  local changed = false

  for _, ply in ipairs(player.GetAll()) do
    local steamid = ensurePlayerState(ply)
    if steamid then
      cleanupProject(steamid)
      changed = true
    end
  end

  if changed then
    persistState()
  end
end)

hook.Add("PlayerDisconnected", "ST2_TS_CleanupOwned", function(ply)
  if not IsValid(ply) then return end
  resetPlayer(ply)
end)

net.Receive("ST2_TS_SYNC_REQUEST", function(_, ply)
  if not canAccessShop(ply) then return end
  sendSnapshot(ply)
end)

local function markOwned(ply, id)
  local steamid = ensurePlayerState(ply)
  if not steamid then return end

  Owned[steamid][id] = true
  persistState()
end

net.Receive("ST2_TS_BUY", function(_, ply)
  if not canAccessShop(ply) then return end
  local cat = net.ReadString()
  local id = net.ReadString()
  local catData = Catalogue[cat]
  if not catData then return end

  local item
  for _, it in ipairs(catData.items or {}) do
    if it.id == id then
      item = it
      break
    end
  end

  if not item then return end

  local steamid = ensurePlayerState(ply)
  if not steamid then return end

  if Owned[steamid][id] then return end
  if ply:GetCredits() < item.price then return end

  ply:SetCredits(ply:GetCredits() - item.price)
  if item.weapon then
    ply:Give(item.weapon)
  end

  markOwned(ply, id)
  persistState()
  sendSnapshot(ply)
end)

local function syncAdminConfig(ply)
  if not isAdmin(ply) then return end

  net.Start("ST2_TS_ADMIN_CONFIG")
    net.WriteUInt(table.Count(CatalogueLookup), 12)
    for id, item in pairs(CatalogueLookup) do
      net.WriteString(id)
      net.WriteString(item.name or id)
      net.WriteUInt(math.max(0, item.price or 1), 12)
      net.WriteBool(itemEnabled(id))
      net.WriteString(item.category or "workshop")
      net.WriteString(item.author or "")
    end
  net.Send(ply)
end

local function resyncAllTraitors()
  for _, ply in ipairs(player.GetAll()) do
    if canAccessShop(ply) then
      sendSnapshot(ply)
    end
  end
end

local function updatePrice(id, price)
  ShopConfig.prices[id] = price
  saveShopConfig()
  rebuildCatalogue()
  resyncAllTraitors()
end

net.Receive("ST2_TS_WORKSHOP", function(_, ply)
  if not canAccessShop(ply) then return end

  local action = net.ReadString()
  local id = net.ReadString()
  local bp = getBlueprint(id)

  if action == "start" then
    if not bp then return end
    local steamid = ensurePlayerState(ply)
    if not steamid then return end
    if Projects[steamid] then return end
    cleanupProject(steamid)
    if bp.requiresOwned and not Owned[steamid][bp.requiresOwned] then return end
    if ply:GetCredits() < bp.price then return end

    ply:SetCredits(ply:GetCredits() - bp.price)
    Projects[steamid] = {
      id = bp.id,
      started = CurTime(),
      readyAt = CurTime() + (bp.buildTime or 5)
    }

    persistState()
    sendSnapshot(ply)
    return
  end

  if action == "claim" then
    local steamid = ensurePlayerState(ply)
    if not steamid then return end

    local project = Projects[steamid]
    if not project or not bp or project.id ~= bp.id then return end
    if project.readyAt and CurTime() < project.readyAt then return end

    if bp.rewardWeapon then
      ply:Give(bp.rewardWeapon)
    end

    Projects[steamid] = nil
    persistState()
    sendSnapshot(ply)
  end
end)

-- Admin config: request snapshot of shop items
net.Receive("ST2_TS_ADMIN_CONFIG_REQUEST", function(_, ply)
  if not isAdmin(ply) then return end
  syncAdminConfig(ply)
end)

-- Admin toggles item availability
net.Receive("ST2_TS_ADMIN_TOGGLE", function(_, ply)
  if not isAdmin(ply) then return end

  local id = net.ReadString()
  if not CatalogueLookup[id] then return end

  local current = itemEnabled(id)
  ShopConfig.enabled[id] = not current
  saveShopConfig()
  rebuildCatalogue()
  syncAdminConfig(ply)
  resyncAllTraitors()
end)

-- Admin price override
net.Receive("ST2_TS_ADMIN_PRICE", function(_, ply)
  if not isAdmin(ply) then return end

  local id = net.ReadString()
  local useDefault = net.ReadBool()
  local price = net.ReadUInt(16)
  if not CatalogueLookup[id] then return end

  if useDefault then
    ShopConfig.prices[id] = nil
    saveShopConfig()
    rebuildCatalogue()
    syncAdminConfig(ply)
    resyncAllTraitors()
    return
  end

  updatePrice(id, math.Clamp(price, 0, 1000))
  syncAdminConfig(ply)
end)

-- Admin rescans workshop weapons
net.Receive("ST2_TS_ADMIN_RESCAN", function(_, ply)
  if not isAdmin(ply) then return end
  rebuildCatalogue()
  syncAdminConfig(ply)
  resyncAllTraitors()
end)

-- Admin manually adds a shop item by weapon id/classname
net.Receive("ST2_TS_ADMIN_ADD", function(_, ply)
  if not isAdmin(ply) then return end

  local id = string.Trim(net.ReadString() or "")
  if id == "" then return end
  if CatalogueLookup[id] then return end

  local entry = buildItemData(id, ShopConfig.custom[id], "custom")
  if not entry then return end

  ShopConfig.custom[id] = {
    id = entry.id,
    name = entry.name,
    desc = entry.desc,
    weapon = entry.weapon,
    price = entry.price,
    icon = entry.icon,
    category = entry.category,
    author = entry.author
  }

  saveShopConfig()
  rebuildCatalogue()
  syncAdminConfig(ply)
  resyncAllTraitors()
end)

hook.Add("Initialize", "ST2_TS_BOOTSTRAP", function()
  loadShopConfig()
  loadProgress()
  rebuildCatalogue()
end)

hook.Add("InitPostEntity", "ST2_TS_REBUILD_AFTER_ENTS", function()
  timer.Simple(0, rebuildCatalogue)
end)


print("[ShadowTTT2] Traitor Shop // Nova Forge server init")

ShadowTTT2 = ShadowTTT2 or {}

util.AddNetworkString("ST2_TS_BUY")
util.AddNetworkString("ST2_TS_SYNC")
util.AddNetworkString("ST2_TS_SYNC_REQUEST")
util.AddNetworkString("ST2_TS_WORKSHOP")
util.AddNetworkString("ST2_TS_ADMIN_CONFIG")
util.AddNetworkString("ST2_TS_ADMIN_CONFIG_REQUEST")
util.AddNetworkString("ST2_TS_ADMIN_TOGGLE")
util.AddNetworkString("ST2_TS_ADMIN_RESCAN")
util.AddNetworkString("ST2_TS_ADMIN_PRICE")

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
local ShopConfig = {
  enabled = {},
  prices = {}
}

local TRAITOR_ROLE = ROLE_TRAITOR or 2

local function isAdmin(ply)
  return IsValid(ply) and ShadowTTT2.Admins and ShadowTTT2.Admins[ply:SteamID()]
end

local function ensureDataFolder()
  if not file.Exists("shadowttt2", "DATA") then
    file.CreateDir("shadowttt2")
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
end

local function saveShopConfig()
  ensureDataFolder()
  file.Write(SHOP_CONFIG_PATH, util.TableToJSON({
    enabled = ShopConfig.enabled,
    prices = ShopConfig.prices
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

  if istable(wep) and istable(wep.EquipMenuData) then
    if wep.EquipMenuData.price then return wep.EquipMenuData.price end
    if wep.EquipMenuData.cost then return wep.EquipMenuData.cost end
  end

  if istable(wep) and wep.Cost then
    return wep.Cost
  end

  return 1
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

local function rebuildCatalogue()
  Catalogue = {}
  CatalogueLookup = {}

  local entries = buildTraitorItemsFromWorkshop()
  for _, item in ipairs(entries) do
    CatalogueLookup[item.id] = item
    if not itemEnabled(item.id) then continue end

    local catId = item.category or "workshop"
    local catName = string.gsub(catId, "^%l", string.upper)

    Catalogue[catId] = Catalogue[catId] or {
      name = catName,
      icon = "icon16/plugin.png",
      items = {}
    }

    table.insert(Catalogue[catId].items, item)
  end
end

local function resetPlayer(ply)
  Owned[ply] = nil
  Projects[ply] = nil
end

local function canAccessShop(ply)
  return IsValid(ply) and ply:IsActiveTraitor()
end

local function sendSnapshot(ply)
  if not IsValid(ply) then return end

  net.Start("ST2_TS_SYNC")
    net.WriteTable({
      owned = Owned[ply] or {},
      project = Projects[ply],
      credits = ply:GetCredits(),
      catalogue = Catalogue,
      blueprints = BLUEPRINTS
    })
  net.Send(ply)
end

hook.Add("TTTBeginRound","ST2_TS_ResetOwned", function()
  Owned = {}
  Projects = {}
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
  Owned[ply] = Owned[ply] or {}
  Owned[ply][id] = true
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

  Owned[ply] = Owned[ply] or {}
  if Owned[ply][id] then return end
  if ply:GetCredits() < item.price then return end

  ply:SetCredits(ply:GetCredits() - item.price)
  if item.weapon then
    ply:Give(item.weapon)
  end

  markOwned(ply, id)
  sendSnapshot(ply)
end)

local function getBlueprint(id)
  for _, bp in ipairs(BLUEPRINTS) do
    if bp.id == id then return bp end
  end
end

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
    if not bp or Projects[ply] then return end
    Owned[ply] = Owned[ply] or {}
    if bp.requiresOwned and not Owned[ply][bp.requiresOwned] then return end
    if ply:GetCredits() < bp.price then return end

    ply:SetCredits(ply:GetCredits() - bp.price)
    Projects[ply] = {
      id = bp.id,
      started = CurTime(),
      readyAt = CurTime() + (bp.buildTime or 5)
    }

    sendSnapshot(ply)
    return
  end

  if action == "claim" then
    local project = Projects[ply]
    if not project or not bp or project.id ~= bp.id then return end
    if project.readyAt and CurTime() < project.readyAt then return end

    if bp.rewardWeapon then
      ply:Give(bp.rewardWeapon)
    end

    Projects[ply] = nil
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

hook.Add("Initialize", "ST2_TS_BOOTSTRAP", function()
  loadShopConfig()
  rebuildCatalogue()
end)

hook.Add("InitPostEntity", "ST2_TS_REBUILD_AFTER_ENTS", function()
  timer.Simple(0, rebuildCatalogue)
end)

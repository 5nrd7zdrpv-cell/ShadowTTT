
print("[ShadowTTT2] Traitor Shop // Nova Forge server init")

ShadowTTT2 = ShadowTTT2 or {}

local shopEnabled = CreateConVar("shadowttt2_traitorshop_enabled", "1", {FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY}, "Enable ShadowTTT2 custom traitor shop")

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
local resyncAllTraitors

local BLUEPRINTS = {
  {id = "workshop_overclock", name = "Overclock Mod", desc = "Veredle deine Remote C4 zu einer stärkeren Ladung.", price = 2, buildTime = 8, rewardWeapon = "weapon_ttt_c4", requiresOwned = "weapon_ttt_c4"},
  {id = "workshop_spyglass", name = "Spyglass Kit", desc = "Verbessert dein Radar um schnellere Pings.", price = 1, buildTime = 6, rewardWeapon = "weapon_ttt_radar", requiresOwned = "weapon_ttt_radar"},
  {id = "workshop_echo", name = "Echo-Projector", desc = "Upgradet den Decoy zu einem lauteren Ablenkungswerkzeug.", price = 1, buildTime = 5, rewardWeapon = "weapon_ttt_decoy", requiresOwned = "weapon_ttt_decoy"},
  {id = "workshop_anchor", name = "Grapple Anchor", desc = "Baue ein kinetisches Seil für riskante Fluchten.", price = 2, buildTime = 10, rewardWeapon = "weapon_ttt_teleport", requiresOwned = "weapon_ttt_teleport"}
}

local SHOP_CONFIG_PATH = "shadowttt2/traitor_shop.json"
local ShopConfig = {
  enabled = {},
  prices = {},
  custom = {}
}

local function getTraitorRoleId()
  if ROLE_TRAITOR then
    return ROLE_TRAITOR
  end

  if roles and roles.GetByName then
    local traitorRole = roles.GetByName("traitor")
    if traitorRole and traitorRole.index then
      return traitorRole.index
    end
  end
end

local function isActiveTraitor(ply)
  if not IsValid(ply) then return false end
  local roleId = getTraitorRoleId()
  if ply.IsActiveTraitor and ply:IsActiveTraitor() then return true end
  if ply.IsTraitor and ply:IsTraitor() then return true end
  if ply.GetSubRole and roleId and ply:GetSubRole() == roleId then return true end
  if ply.GetRole and roleId and ply:GetRole() == roleId then return true end
  if ply.GetBaseRole and roleId and ply:GetBaseRole() == roleId then return true end
  if ply.GetTeam and TEAM_TRAITOR and ply:GetTeam() == TEAM_TRAITOR then return true end
  return false
end

local function isAdmin(ply)
  if ShadowTTT2 and ShadowTTT2.IsAdmin then
    return ShadowTTT2.IsAdmin(ply)
  end

  return IsValid(ply) and ShadowTTT2.Admins and (ShadowTTT2.Admins[ply:SteamID()] or ShadowTTT2.Admins[ply:SteamID64()])
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

local function hasTraitorRole(roleList)
  if roleList == nil then return false end
  local roleId = getTraitorRoleId()
  if isnumber(roleList) then return roleId ~= nil and roleList == roleId end
  if isstring(roleList) then return string.lower(roleList) == "traitor" end
  if not istable(roleList) then return false end
  if roleId and roleList[roleId] then return true end
  if roleList.traitor or roleList.TRAITOR then return true end
  for _, role in pairs(roleList) do
    if roleId and role == roleId then return true end
    if isstring(role) and string.lower(role) == "traitor" then return true end
  end
  return false
end

local function resolveWeaponId(item)
  return item.Weapon or item.weapon or item.ClassName or item.Classname or item.Class or item.id or item.ID
end

local function addCatalogueEntry(entries, seen, entry)
  if not entry or not entry.id or entry.id == "" then return end
  if seen[entry.id] then return end
  seen[entry.id] = true
  table.insert(entries, entry)
end

local function buildTraitorItemsFromWorkshop()
  local entries = {}
  local seen = {}
  for _, wep in ipairs(weapons.GetList()) do
    if not hasTraitorRole(wep.CanBuy) then continue end

    local id = wep.ClassName or wep.Classname or wep.PrintName
    if not id then continue end

    local menu = wep.EquipMenuData or {}
    local name = menu.name or wep.PrintName or id
    local desc = menu.desc or menu.description or wep.Instructions or ""
    local category = string.lower(menu.type or "workshop")

    addCatalogueEntry(entries, seen, {
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

  if items and isfunction(items.GetList) then
    for _, item in pairs(items.GetList()) do
      if not istable(item) then continue end
      if not hasTraitorRole(item.CanBuy or item.can_buy or item.roles) then continue end

      local weaponId = resolveWeaponId(item)
      if not weaponId or weaponId == "" then continue end
      if not weapons.GetStored(weaponId) and not weapons.Get(weaponId) then continue end

      local menu = item.EquipMenuData or {}
      local name = item.name or item.PrintName or menu.name or weaponId
      local desc = item.desc or item.description or menu.desc or ""
      local category = string.lower(menu.type or item.category or "workshop")

      addCatalogueEntry(entries, seen, {
        id = weaponId,
        name = name,
        desc = desc,
        weapon = weaponId,
        price = getItemPrice(weaponId, item),
        icon = menu.icon or item.icon or item.material,
        category = category,
        author = item.Author or item.author
      })
    end
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
  Owned[ply] = nil
  Projects[ply] = nil
end

local function resetAllPlayers()
  for _, ply in ipairs(player.GetAll()) do
    resetPlayer(ply)
  end
end

local function canAccessShop(ply)
  return traitorShopEnabled() and isActiveTraitor(ply)
end

local function canSpendShopCredits(ply)
  return traitorShopEnabled() and isActiveTraitor(ply)
end

local function getShopCredits(ply)
  if not canSpendShopCredits(ply) then
    return 0
  end

  if ply.GetCredits then
    return ply:GetCredits()
  end

  return 0
end

local function sendSnapshot(ply)
  if not traitorShopEnabled() then return end
  if not IsValid(ply) then return end
  if table.Count(Catalogue) == 0 then
    rebuildCatalogue()
  end

  net.Start("ST2_TS_SYNC")
    net.WriteTable({
      owned = Owned[ply] or {},
      project = Projects[ply],
      credits = getShopCredits(ply),
      canUse = canSpendShopCredits(ply),
      catalogue = Catalogue,
      blueprints = BLUEPRINTS
    })
  net.Send(ply)
end

hook.Add("PlayerDisconnected", "ST2_TS_CleanupOwned", function(ply)
  if not IsValid(ply) then return end
  resetPlayer(ply)
end)

hook.Add("TTTPrepareRound", "ST2_TS_ResetRoundState", function()
  resetAllPlayers()
end)

hook.Add("TTTBeginRound", "ST2_TS_ResyncTraitors", function()
  rebuildCatalogue()
  resyncAllTraitors()
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
  if not canSpendShopCredits(ply) then return end
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

local function syncAllAdmins()
  for _, ply in ipairs(player.GetAll()) do
    if isAdmin(ply) then
      syncAdminConfig(ply)
    end
  end
end

resyncAllTraitors = function()
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
    if not canSpendShopCredits(ply) then return end
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
    if not canSpendShopCredits(ply) then return end

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
  syncAllAdmins()
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
    syncAllAdmins()
    resyncAllTraitors()
    return
  end

  updatePrice(id, math.Clamp(price, 0, 1000))
  syncAllAdmins()
end)

-- Admin rescans workshop weapons
net.Receive("ST2_TS_ADMIN_RESCAN", function(_, ply)
  if not isAdmin(ply) then return end
  rebuildCatalogue()
  syncAllAdmins()
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
  syncAllAdmins()
  resyncAllTraitors()
end)

hook.Add("Initialize", "ST2_TS_BOOTSTRAP", function()
  loadShopConfig()
  rebuildCatalogue()
end)

hook.Add("InitPostEntity", "ST2_TS_REBUILD_AFTER_ENTS", function()
  timer.Simple(0, rebuildCatalogue)
end)

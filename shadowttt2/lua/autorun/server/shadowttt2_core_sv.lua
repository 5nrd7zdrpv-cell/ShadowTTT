print("[ShadowTTT2] MODEL-ENUM SERVER loaded")

ShadowTTT2 = ShadowTTT2 or {}
ShadowTTT2.Admins = ShadowTTT2.Admins or {}
local DEFAULT_OWNER_STEAMID = "STEAM_0:1:15220591"
ShadowTTT2.Admins[DEFAULT_OWNER_STEAMID] = true
local owner64 = util.SteamIDTo64(DEFAULT_OWNER_STEAMID)
if owner64 and owner64 ~= "0" then
  ShadowTTT2.Admins[owner64] = true
end
ShadowTTT2.WorkshopPushed = ShadowTTT2.WorkshopPushed or {}
ShadowTTT2.ModelData = ShadowTTT2.ModelData or {}
ShadowTTT2.Bans = ShadowTTT2.Bans or {}
ShadowTTT2.Analytics = ShadowTTT2.Analytics or {}
ShadowTTT2.Points = ShadowTTT2.Points or {balances = {}}
ShadowTTT2.ServerCoreLoaded = true

local function IsAdmin(ply)
  if not IsValid(ply) then return false end

  local admins = ShadowTTT2.Admins or {}
  if admins[ply:SteamID()] or admins[ply:SteamID64()] then
    return true
  end

  if ply.IsSuperAdmin and ply:IsSuperAdmin() then return true end
  if ply.IsAdmin and ply:IsAdmin() then return true end
  return false
end
ShadowTTT2.IsAdmin = ShadowTTT2.IsAdmin or IsAdmin
local RECOIL_MULTIPLIER_DEFAULT = 0.35
local function clampRecoilMultiplier(value)
  if not isnumber(value) then return RECOIL_MULTIPLIER_DEFAULT end
  return math.Clamp(value, 0, 1)
end
local recoilMultiplierConVar = CreateConVar("st2_recoil_mult", tostring(RECOIL_MULTIPLIER_DEFAULT), {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "ShadowTTT2 recoil multiplier (0-1).")
local function getRecoilMultiplier()
  if not recoilMultiplierConVar then return RECOIL_MULTIPLIER_DEFAULT end
  return clampRecoilMultiplier(recoilMultiplierConVar:GetFloat())
end
local WALK_SPEED_DEFAULT = 160
local RUN_SPEED_DEFAULT = 220
local function clampWalkSpeed(value)
  if not isnumber(value) then return WALK_SPEED_DEFAULT end
  return math.Clamp(value, 50, 500)
end
local function clampRunSpeed(value)
  if not isnumber(value) then return RUN_SPEED_DEFAULT end
  return math.Clamp(value, 100, 750)
end
local walkSpeedConVar = CreateConVar("st2_walk_speed", tostring(WALK_SPEED_DEFAULT), {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "ShadowTTT2 walk speed (50-500).")
local runSpeedConVar = CreateConVar("st2_run_speed", tostring(RUN_SPEED_DEFAULT), {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "ShadowTTT2 run/sprint speed (100-750).")
local function getWalkSpeed()
  if not walkSpeedConVar then return WALK_SPEED_DEFAULT end
  return clampWalkSpeed(walkSpeedConVar:GetFloat())
end
local function getRunSpeed()
  if not runSpeedConVar then return RUN_SPEED_DEFAULT end
  return clampRunSpeed(runSpeedConVar:GetFloat())
end

local function applyMoveSpeedToPlayer(ply)
  if not IsValid(ply) then return end
  local walk = getWalkSpeed()
  local run = getRunSpeed()
  ply:SetWalkSpeed(walk)
  ply:SetRunSpeed(run)
  if ply.SetSlowWalkSpeed then
    ply:SetSlowWalkSpeed(walk)
  end
end

local function applyMoveSpeeds()
  for _, p in ipairs(player.GetAll()) do
    applyMoveSpeedToPlayer(p)
  end
end
local MODEL_DATA_PATH = "shadowttt2/playermodels.json"
local BAN_DATA_PATH = "shadowttt2/bans.json"
local ANALYTICS_PATH = "shadowttt2/server_analytics.json"
local ANALYTICS_VERSION = 1
local MODEL_CACHE_VERSION = 3
local DEFAULT_MODEL_PRICE = 100
local POINTS_PATH = "shadowttt2/points.json"
local POINTS_VERSION = 1
local STARTER_POINTS = 250
local POINTS_TICK_AMOUNT = 15
local POINTS_TICK_INTERVAL = 240
local MIN_SLOT_BET = 5
local MAX_SLOT_BET = 1000
local SLOT_COOLDOWN = 2
local SLOT_SYMBOLS = {
  {id = "seven", icon = "7️⃣", weight = 5, triple = 12, pair = 4},
  {id = "diamond", icon = "💎", weight = 10, triple = 8, pair = 3},
  {id = "bell", icon = "🔔", weight = 14, triple = 6, pair = 2},
  {id = "star", icon = "⭐", weight = 18, triple = 5, pair = 2},
  {id = "cherry", icon = "🍒", weight = 22, triple = 4, pair = 2}
}
-- These models spam AE_CL_PLAYSOUND errors because their animations reference empty sound names.
local BLACKLISTED_MODELS = {
  ["models/alyx.mdl"] = true,
  ["models/alyx_ep2.mdl"] = true,
  ["models/alyx_interior.mdl"] = true
}

local function isPlayerModelPath(mdl)
  if not isstring(mdl) then return false end
  return string.find(string.lower(mdl), "models/player/", 1, true) ~= nil
end

local function isModelAllowed(mdl)
  if not isstring(mdl) then return false end
  if not isPlayerModelPath(mdl) then return false end
  if BLACKLISTED_MODELS[string.lower(mdl)] then return false end
  return util.IsValidModel(mdl)
end

local function normalizeModelPrice(value)
  local num = tonumber(value)
  if not num then return DEFAULT_MODEL_PRICE end
  return math.max(0, math.floor(num))
end

local function ensureDataDir()
  if not file.Exists("shadowttt2", "DATA") then
    file.CreateDir("shadowttt2")
  end
end

local function loadAnalytics()
  ensureDataDir()
  local raw = file.Exists(ANALYTICS_PATH, "DATA") and file.Read(ANALYTICS_PATH, "DATA")
  local decoded = raw and util.JSONToTable(raw)

  if istable(decoded) then
    ShadowTTT2.Analytics = {
      version = decoded.version or 0,
      modelUsage = decoded.modelUsage or {},
      mapVotes = decoded.mapVotes or {}
    }
  end

  ShadowTTT2.Analytics = ShadowTTT2.Analytics or {}
  ShadowTTT2.Analytics.version = ANALYTICS_VERSION
  ShadowTTT2.Analytics.modelUsage = ShadowTTT2.Analytics.modelUsage or {}
  ShadowTTT2.Analytics.mapVotes = ShadowTTT2.Analytics.mapVotes or {}
end

local function loadPoints()
  ensureDataDir()
  local raw = file.Exists(POINTS_PATH, "DATA") and file.Read(POINTS_PATH, "DATA")
  local decoded = raw and util.JSONToTable(raw)

  if istable(decoded) and decoded.version == POINTS_VERSION and istable(decoded.balances) then
    ShadowTTT2.Points = {
      version = decoded.version,
      balances = decoded.balances
    }
  else
    ShadowTTT2.Points = {
      version = POINTS_VERSION,
      balances = {}
    }
  end
end

local function savePoints()
  ensureDataDir()
  local payload = {
    version = POINTS_VERSION,
    balances = ShadowTTT2.Points.balances or {}
  }
  file.Write(POINTS_PATH, util.TableToJSON(payload, true))
end

local function getPointsForSid(sid)
  if not isstring(sid) or sid == "" then return 0 end
  ShadowTTT2.Points.balances = ShadowTTT2.Points.balances or {}
  return tonumber(ShadowTTT2.Points.balances[sid]) or 0
end

local function setPointsForSid(sid, amount)
  if not isstring(sid) or sid == "" then return 0 end
  ShadowTTT2.Points.balances = ShadowTTT2.Points.balances or {}
  local clamped = math.max(0, math.floor(tonumber(amount) or 0))
  ShadowTTT2.Points.balances[sid] = clamped
  savePoints()
  return clamped
end

local function getPoints(ply)
  if not IsValid(ply) then return 0 end
  return getPointsForSid(ply:SteamID())
end

local function setPoints(ply, amount)
  if not IsValid(ply) then return 0 end
  local newAmount = setPointsForSid(ply:SteamID(), amount)
  ply:SetNWInt("ST2_Points", newAmount)
  return newAmount
end

local function addPoints(ply, amount)
  if not IsValid(ply) or not isnumber(amount) then return end
  local current = getPoints(ply)
  setPoints(ply, current + amount)
end

local function ensureStarterPoints(ply)
  if not IsValid(ply) then return end
  local sid = ply:SteamID()
  ShadowTTT2.Points.balances = ShadowTTT2.Points.balances or {}
  local stored = ShadowTTT2.Points.balances[sid]
  if stored == nil then
    setPoints(ply, STARTER_POINTS)
    return
  end

  ply:SetNWInt("ST2_Points", getPoints(ply))
end

local function weightedSymbol()
  local total = 0
  for _, sym in ipairs(SLOT_SYMBOLS) do
    total = total + (sym.weight or 1)
  end
  local pick = math.random() * total
  local acc = 0
  for _, sym in ipairs(SLOT_SYMBOLS) do
    acc = acc + (sym.weight or 1)
    if pick <= acc then
      return sym
    end
  end
  return SLOT_SYMBOLS[#SLOT_SYMBOLS]
end

local function resolveSlotPayout(symbols, bet)
  if not istable(symbols) or #symbols ~= 3 then return 0 end
  local a, b, c = symbols[1], symbols[2], symbols[3]
  if not (a and b and c) then return 0 end

  if a.id == b.id and b.id == c.id then
    return math.floor(bet * (a.triple or 0))
  end

  if a.id == b.id or b.id == c.id or a.id == c.id then
    local sym = a.id == b.id and a or (b.id == c.id and b or a)
    return math.floor(bet * (sym.pair or 0))
  end

  return 0
end

local function spinSlots(ply, bet)
  if not IsValid(ply) then return end

  ShadowTTT2.Points.cooldowns = ShadowTTT2.Points.cooldowns or {}
  local now = CurTime()
  local nextAllowed = ShadowTTT2.Points.cooldowns[ply] or 0
  if now < nextAllowed then
    return false, "Bitte warte einen Moment vor dem nächsten Spin.", nil, getPoints(ply)
  end

  bet = math.Clamp(math.floor(tonumber(bet) or 0), MIN_SLOT_BET, MAX_SLOT_BET)
  local balance = getPoints(ply)
  if bet <= 0 then
    return false, string.format("Mindesteinsatz: %d Punkte.", MIN_SLOT_BET), nil, balance
  end
  if bet > balance then
    return false, "Nicht genug Punkte für diesen Einsatz.", nil, balance
  end

  local symbols = {weightedSymbol(), weightedSymbol(), weightedSymbol()}
  local payout = resolveSlotPayout(symbols, bet)
  setPoints(ply, balance - bet + payout)

  ShadowTTT2.Points.cooldowns[ply] = now + SLOT_COOLDOWN
  return true, payout > 0 and string.format("Gewonnen: +%d Punkte!", payout) or "Leider verloren – versuch es nochmal!", symbols, getPoints(ply), payout
end

local analyticsSavePending
local function saveAnalytics()
  ensureDataDir()
  file.Write(ANALYTICS_PATH, util.TableToJSON({
    version = ShadowTTT2.Analytics.version or ANALYTICS_VERSION,
    modelUsage = ShadowTTT2.Analytics.modelUsage or {},
    mapVotes = ShadowTTT2.Analytics.mapVotes or {}
  }, true))
  analyticsSavePending = nil
end

local function queueAnalyticsSave()
  if analyticsSavePending then return end
  analyticsSavePending = true
  timer.Create("ST2_SaveAnalytics", 1, 1, saveAnalytics)
end

local function trackModelUsage(mdl)
  if not isstring(mdl) or mdl == "" then return end
  ShadowTTT2.Analytics.modelUsage[mdl] = (ShadowTTT2.Analytics.modelUsage[mdl] or 0) + 1
  queueAnalyticsSave()
end

local function trackMapVote(mapName)
  if not isstring(mapName) or mapName == "" then return end
  ShadowTTT2.Analytics.mapVotes[mapName] = (ShadowTTT2.Analytics.mapVotes[mapName] or 0) + 1
  queueAnalyticsSave()
end

local function loadModelData()
  ensureDataDir()
  local raw = file.Exists(MODEL_DATA_PATH, "DATA") and file.Read(MODEL_DATA_PATH, "DATA")
  local decoded = raw and util.JSONToTable(raw)
  if istable(decoded) then
    ShadowTTT2.ModelData.models = decoded.models or {}
    ShadowTTT2.ModelData.selected = decoded.selected or {}
    ShadowTTT2.ModelData.enabled = decoded.enabled or {}
    ShadowTTT2.ModelData.prices = decoded.prices or {}
    ShadowTTT2.ModelData.version = decoded.version or 0
  else
    ShadowTTT2.ModelData.models = {}
    ShadowTTT2.ModelData.selected = {}
    ShadowTTT2.ModelData.enabled = {}
    ShadowTTT2.ModelData.prices = {}
    ShadowTTT2.ModelData.version = 0
  end

  ShadowTTT2.ModelData.modelSet = {}
  local filtered = {}
  for _, mdl in ipairs(ShadowTTT2.ModelData.models) do
    if isModelAllowed(mdl) then
      table.insert(filtered, mdl)
      ShadowTTT2.ModelData.modelSet[mdl] = true
    end
  end
  ShadowTTT2.ModelData.models = filtered
  ShadowTTT2.ModelData.enabled = ShadowTTT2.ModelData.enabled or {}
  ShadowTTT2.ModelData.prices = ShadowTTT2.ModelData.prices or {}
  for mdl, price in pairs(ShadowTTT2.ModelData.prices) do
    ShadowTTT2.ModelData.prices[mdl] = normalizeModelPrice(price)
  end

  local selected = ShadowTTT2.ModelData.selected or {}
  for sid, mdl in pairs(selected) do
    if not ShadowTTT2.ModelData.modelSet[mdl] then
      selected[sid] = nil
    end
  end
  ShadowTTT2.ModelData.selected = selected

  ShadowTTT2.ModelData.enabledSet = {}
  local changed
  for mdl, state in pairs(ShadowTTT2.ModelData.enabled) do
    if not ShadowTTT2.ModelData.modelSet[mdl] then
      ShadowTTT2.ModelData.enabled[mdl] = nil
      changed = true
    end
  end

  for _, mdl in ipairs(ShadowTTT2.ModelData.models) do
    if ShadowTTT2.ModelData.enabled[mdl] == nil then
      ShadowTTT2.ModelData.enabled[mdl] = true
      changed = true
    end
    if ShadowTTT2.ModelData.enabled[mdl] then
      ShadowTTT2.ModelData.enabledSet[mdl] = true
    end
  end

  for mdl, _ in pairs(ShadowTTT2.ModelData.prices) do
    if not ShadowTTT2.ModelData.modelSet[mdl] then
      ShadowTTT2.ModelData.prices[mdl] = nil
      changed = true
    end
  end

  if changed then
    saveModelData()
  end
end

local function saveModelData()
  ensureDataDir()
  file.Write(MODEL_DATA_PATH, util.TableToJSON({
    models = ShadowTTT2.ModelData.models or {},
    selected = ShadowTTT2.ModelData.selected or {},
    enabled = ShadowTTT2.ModelData.enabled or {},
    prices = ShadowTTT2.ModelData.prices or {},
    version = MODEL_CACHE_VERSION
  }, true))
end

local function getModelPrice(mdl)
  if not mdl or mdl == "" then return DEFAULT_MODEL_PRICE end
  ShadowTTT2.ModelData = ShadowTTT2.ModelData or {}
  ShadowTTT2.ModelData.prices = ShadowTTT2.ModelData.prices or {}
  local stored = ShadowTTT2.ModelData.prices[mdl]
  if stored == nil then return DEFAULT_MODEL_PRICE end
  return normalizeModelPrice(stored)
end

local function sanitizeBanTable(raw)
  if not istable(raw) then return {} end

  local out = {}
  for sid, info in pairs(raw) do
    if isstring(sid) and sid ~= "" and istable(info) then
      out[sid] = {
        name = isstring(info.name) and info.name or "",
        banner = isstring(info.banner) and info.banner or "",
        reason = isstring(info.reason) and info.reason or "Kein Grund angegeben",
        expires = tonumber(info.expires) or 0
      }
    end
  end

  return out
end

local function banExpired(ban)
  if not istable(ban) then return true end
  local expires = tonumber(ban.expires) or 0
  if expires <= 0 then return false end
  return os.time() >= expires
end

local function saveBanData()
  ensureDataDir()
  file.Write(BAN_DATA_PATH, util.TableToJSON(ShadowTTT2.Bans or {}, true))
end

local function loadBanData()
  ensureDataDir()
  local raw = file.Exists(BAN_DATA_PATH, "DATA") and file.Read(BAN_DATA_PATH, "DATA")
  local decoded = raw and util.JSONToTable(raw) or {}
  ShadowTTT2.Bans = sanitizeBanTable(decoded)

  local changed
  for sid, ban in pairs(ShadowTTT2.Bans) do
    if banExpired(ban) then
      ShadowTTT2.Bans[sid] = nil
      changed = true
    end
  end

  if changed then
    saveBanData()
  end
end

local function addBan(sid, durationMinutes, reason, banner, targetName)
  if not isstring(sid) or sid == "" then return end
  local expires = 0
  if durationMinutes and durationMinutes > 0 then
    expires = os.time() + math.floor(durationMinutes * 60)
  end

  ShadowTTT2.Bans[sid] = {
    name = targetName or "",
    banner = banner or "",
    reason = (isstring(reason) and reason ~= "" and reason) or "Kein Grund angegeben",
    expires = expires
  }
  saveBanData()
end

local function removeBan(sid)
  if not isstring(sid) or sid == "" then return end
  if ShadowTTT2.Bans[sid] then
    ShadowTTT2.Bans[sid] = nil
    saveBanData()
  end
end

local function collectBanList()
  local entries = {}
  local changed
  for sid, ban in pairs(ShadowTTT2.Bans or {}) do
    if banExpired(ban) then
      ShadowTTT2.Bans[sid] = nil
      changed = true
    else
      entries[#entries + 1] = {
        sid = sid,
        name = ban.name or "",
        banner = ban.banner or "",
        reason = ban.reason or "Kein Grund angegeben",
        expires = ban.expires or 0
      }
    end
  end

  if changed then
    saveBanData()
  end

  table.sort(entries, function(a, b)
    return string.lower(a.name ~= "" and a.name or a.sid) < string.lower(b.name ~= "" and b.name or b.sid)
  end)

  return entries
end

local function rebuildModelList()
  local set = {}

  if player_manager and player_manager.AllValidModels then
    local am = player_manager.AllValidModels()
    if am and table.Count(am) > 0 then
      for k, v in pairs(am) do
        if isstring(k) and isModelAllowed(k) then set[k] = true end
        if isstring(v) and isModelAllowed(v) then set[v] = true end
      end
    end
  end

  local lm = list.Get("PlayerOptionsModel")
  if lm and table.Count(lm) > 0 then
    for k, v in pairs(lm) do
      if isstring(k) and isModelAllowed(k) then set[k] = true end
      if isstring(v) and isModelAllowed(v) then set[v] = true end
      if istable(v) and isstring(v.model) and isModelAllowed(v.model) then set[v.model] = true end
    end
  end

  local function scanModels(dir, depth)
    if depth <= 0 then return end
    local files, dirs = file.Find(dir .. "/*", "GAME")
    for _, f in ipairs(files) do
      if string.sub(f, -4) == ".mdl" then
        local path = dir .. "/" .. f
        if isModelAllowed(path) then
          set[path] = true
        end
      end
    end
    for _, sub in ipairs(dirs) do
      scanModels(dir .. "/" .. sub, depth - 1)
    end
  end

  scanModels("models/player", 4)
  scanModels("models", 2)

  local list = {}
  for mdl, _ in pairs(set) do table.insert(list, mdl) end
  table.sort(list)

  ShadowTTT2.ModelData.models = list
  ShadowTTT2.ModelData.modelSet = set
  ShadowTTT2.ModelData.version = MODEL_CACHE_VERSION
  ShadowTTT2.ModelData.enabled = ShadowTTT2.ModelData.enabled or {}

  for mdl, _ in pairs(ShadowTTT2.ModelData.enabled) do
    if not set[mdl] then
      ShadowTTT2.ModelData.enabled[mdl] = nil
    end
  end

  ShadowTTT2.ModelData.enabledSet = {}
  for _, mdl in ipairs(list) do
    if ShadowTTT2.ModelData.enabled[mdl] == nil then
      ShadowTTT2.ModelData.enabled[mdl] = true
    end
    if ShadowTTT2.ModelData.enabled[mdl] then
      ShadowTTT2.ModelData.enabledSet[mdl] = true
    end
  end

  local selected = ShadowTTT2.ModelData.selected or {}
  for sid, mdl in pairs(selected) do
    if not set[mdl] then
      selected[sid] = nil
    end
  end

  ShadowTTT2.ModelData.selected = selected

  ShadowTTT2.ModelData.prices = ShadowTTT2.ModelData.prices or {}
  for mdl, _ in pairs(ShadowTTT2.ModelData.prices) do
    if not set[mdl] then
      ShadowTTT2.ModelData.prices[mdl] = nil
    end
  end
  saveModelData()
end

local function ReduceRecoil(wep, multiplier)
  if not IsValid(wep) then return end
  local primary = wep.Primary
  if not istable(primary) then return end
  local originalRecoil = wep.ST2_OriginalRecoil
  if not isnumber(originalRecoil) then
    originalRecoil = primary.Recoil
    if not isnumber(originalRecoil) then return end
    wep.ST2_OriginalRecoil = originalRecoil
  end

  local value = clampRecoilMultiplier(multiplier or getRecoilMultiplier())
  wep.ST2_RecoilTweaked = true
  wep.ST2_RecoilMultiplier = value
  wep.Primary.Recoil = originalRecoil * value
end

local function applyRecoilMultiplierToWeapons(multiplier)
  local value = clampRecoilMultiplier(multiplier or getRecoilMultiplier())
  for _, ent in ipairs(ents.GetAll()) do
    if IsValid(ent) and ent:IsWeapon() then
      ReduceRecoil(ent, value)
    end
  end
end

if cvars and cvars.AddChangeCallback then
  cvars.AddChangeCallback("st2_recoil_mult", function(_, _, new)
    applyRecoilMultiplierToWeapons(tonumber(new))
  end, "ST2_RecoilMultiplierUpdate")
end

hook.Add("WeaponEquip", "ST2_ReduceRecoilOnEquip", function(wep)
  ReduceRecoil(wep)
end)

hook.Add("OnEntityCreated", "ST2_ReduceRecoilOnSpawn", function(ent)
  if not ent:IsWeapon() then return end
  timer.Simple(0, function()
    ReduceRecoil(ent)
  end)
end)

local function scheduleWorkshopRetry(nextAttempt)
  timer.Create("ST2_PS_PUSH_WORKSHOP_RETRY", math.min(30, nextAttempt * 5), 1, function()
    PushWorkshopDownloads(nextAttempt)
  end)
end

function PushWorkshopDownloads(attempt)
  if not engine.GetAddons then return end

  attempt = attempt or 1
  local added = 0
  local seen = ShadowTTT2.WorkshopPushed

  for _, addon in ipairs(engine.GetAddons()) do
    local wsid = addon and addon.wsid
    if wsid and not seen[wsid] then
      local id = tostring(wsid)
      if string.match(id, "^%d+$") then
        resource.AddWorkshop(id)
        seen[wsid] = true
        added = added + 1
      end
    end
  end

  if added == 0 then
    if not timer.Exists("ST2_PS_PUSH_WORKSHOP_RETRY") and attempt < 6 then
      print(string.format("[ShadowTTT2] Pointshop // no workshop addons detected (attempt %d); retrying to catch late mounts...", attempt))
      scheduleWorkshopRetry(attempt + 1)
    else
      print("[ShadowTTT2] Pointshop // no workshop addons detected; ensure your host_workshop_collection is mounted")
    end
  else
    timer.Remove("ST2_PS_PUSH_WORKSHOP_RETRY")
    print(string.format("[ShadowTTT2] Pointshop // queued %d workshop addons for download (attempt %d)", added, attempt))
  end
end
hook.Add("Initialize", "ST2_PS_PUSH_WORKSHOP", function()
  PushWorkshopDownloads(1)
end)
-- Run once more after entities initialize to catch late-mounted workshop collections
hook.Add("InitPostEntity", "ST2_PS_PUSH_WORKSHOP_LATE", function()
  PushWorkshopDownloads(1)
end)

hook.Add("InitPostEntity", "ST2_PS_REBUILD_MODELS_LATE", function()
  timer.Simple(2, function()
    rebuildModelList()
    broadcastModelSnapshots()
  end)
end)

hook.Add("CheckPassword", "ST2_BanCheckPassword", function(steamid64, _, _, _, name)
  local sid = util.SteamIDFrom64(steamid64 or "") or ""
  local allowed, msg = checkBanStatus(sid, name)
  if allowed == false then
    return false, msg
  end
end)

util.AddNetworkString("ST2_ADMIN_REQUEST")
util.AddNetworkString("ST2_ADMIN_OPEN")
util.AddNetworkString("ST2_ADMIN_PLAYERLIST")
util.AddNetworkString("ST2_ADMIN_ACTION")
util.AddNetworkString("ST2_ADMIN_BANLIST_REQUEST")
util.AddNetworkString("ST2_ADMIN_BANLIST")
util.AddNetworkString("ST2_ADMIN_UNBAN")
util.AddNetworkString("ST2_ADMIN_POINTS_GRANT")
util.AddNetworkString("ST2_ADMIN_RECOIL")
util.AddNetworkString("ST2_ADMIN_RECOIL_REQUEST")
util.AddNetworkString("ST2_ADMIN_RECOIL_SET")
util.AddNetworkString("ST2_ADMIN_SPEED")
util.AddNetworkString("ST2_ADMIN_SPEED_REQUEST")
util.AddNetworkString("ST2_ADMIN_SPEED_SET")
util.AddNetworkString("ST2_ADMIN_WEAPON_REQUEST")
util.AddNetworkString("ST2_ADMIN_WEAPON_LIST")
util.AddNetworkString("ST2_ADMIN_MAPS_REQUEST")
util.AddNetworkString("ST2_ADMIN_MAPS")
util.AddNetworkString("ST2_ADMIN_MAP_CHANGE")
util.AddNetworkString("ST2_PS_EQUIP")
util.AddNetworkString("ST2_PS_MODELS_REQUEST")
util.AddNetworkString("ST2_PS_MODELS")
util.AddNetworkString("ST2_PS_ADMIN_CONFIG")
util.AddNetworkString("ST2_PS_ADMIN_CONFIG_REQUEST")
util.AddNetworkString("ST2_PS_ADMIN_PRICE")
util.AddNetworkString("ST2_PS_ADMIN_TOGGLE")
util.AddNetworkString("ST2_POINTS_REQUEST")
util.AddNetworkString("ST2_POINTS_BALANCE")
util.AddNetworkString("ST2_POINTS_SPIN")
util.AddNetworkString("ST2_POINTS_SPIN_RESULT")
util.AddNetworkString("ST2_MAPVOTE_STATE")
util.AddNetworkString("ST2_MAPVOTE_VOTE")
util.AddNetworkString("ST2_MAPVOTE_RESULT")

local function ShouldInstantHeadshotKill(target, attacker)
  if not IsValid(target) or not target:IsPlayer() or not target:Alive() then return false end
  if not IsValid(attacker) or not attacker:IsPlayer() then return false end
  if attacker == target then return false end
  if attacker.IsSameTeam and attacker:IsSameTeam(target) then return false end
  return true
end

hook.Add("ScalePlayerDamage", "ST2_HEADSHOT_KILL", function(ply, hitgroup, dmginfo)
  if hitgroup ~= HITGROUP_HEAD then return end

  local attacker = dmginfo:GetAttacker()
  if not ShouldInstantHeadshotKill(ply, attacker) then return end

  dmginfo:SetDamage(ply:Health() + ply:Armor())
end)

local function getModelData()
  if not ShadowTTT2.ModelData.models or ShadowTTT2.ModelData.version ~= MODEL_CACHE_VERSION then
    loadModelData()
    if ShadowTTT2.ModelData.version ~= MODEL_CACHE_VERSION then
      rebuildModelList()
    end
  end

  if not ShadowTTT2.ModelData.models or #ShadowTTT2.ModelData.models == 0 then
    rebuildModelList()
  end

  ShadowTTT2.ModelData.prices = ShadowTTT2.ModelData.prices or {}
  if not ShadowTTT2.ModelData.enabledSet then
    ShadowTTT2.ModelData.enabled = ShadowTTT2.ModelData.enabled or {}
    ShadowTTT2.ModelData.enabledSet = {}
    for _, mdl in ipairs(ShadowTTT2.ModelData.models or {}) do
      local state = ShadowTTT2.ModelData.enabled[mdl]
      if state == nil then
        state = true
        ShadowTTT2.ModelData.enabled[mdl] = true
      end
      if state then
        ShadowTTT2.ModelData.enabledSet[mdl] = true
      end
    end
    saveModelData()
  end

  for mdl, _ in pairs(ShadowTTT2.ModelData.prices) do
    if not ShadowTTT2.ModelData.modelSet or not ShadowTTT2.ModelData.modelSet[mdl] then
      ShadowTTT2.ModelData.prices[mdl] = nil
    end
  end

  return ShadowTTT2.ModelData
end

local function sendModelSnapshot(ply)
  if not IsValid(ply) then return end

  local data = getModelData()
  local models = {}
  local enabledSet = data.enabledSet or {}
  for _, mdl in ipairs(data.models or {}) do
    if enabledSet[mdl] then
      models[#models + 1] = mdl
    end
  end

  local sid = ply:SteamID()
  local selected = sid and data.selected and data.selected[sid]
  if selected and not enabledSet[selected] then
    data.selected[sid] = nil
    saveModelData()
    selected = ""
  end

  net.Start("ST2_PS_MODELS")
    net.WriteUInt(DEFAULT_MODEL_PRICE, 16)
    net.WriteUInt(#models, 16)
    for _, mdl in ipairs(models) do
      net.WriteString(mdl)
      net.WriteUInt(getModelPrice(mdl), 16)
    end
    net.WriteString(selected or "")
  net.Send(ply)
end

local function broadcastModelSnapshots()
  for _, tgt in ipairs(player.GetAll()) do
    sendModelSnapshot(tgt)
  end
end

local MAP_VOTE_OPTION_COUNT = 6
local MAP_VOTE_DURATION = 15
local MAP_VOTE_TIMER = "ST2_MapVoteTimer"
local mapVote = {
  active = false,
  endTime = 0,
  options = {},
  optionSet = {},
  votes = {},
  voterChoice = {}
}
ShadowTTT2.MapVote = mapVote

local function resetMapVote()
  mapVote.active = false
  mapVote.endTime = 0
  mapVote.options = {}
  mapVote.optionSet = {}
  mapVote.votes = {}
  mapVote.voterChoice = {}
end

local function cancelMapVote()
  timer.Remove(MAP_VOTE_TIMER)
  resetMapVote()

  net.Start("ST2_MAPVOTE_STATE")
    net.WriteUInt(0, 6)
    net.WriteFloat(CurTime())
  net.Broadcast()
end

local function collectMaps()
  local maps = {}
  local function addMaps(pattern)
    local found = file.Find(pattern, "GAME") or {}
    for _, name in ipairs(found) do
      local trimmed = string.StripExtension(name)
      if trimmed and trimmed ~= "" then
        maps[#maps + 1] = trimmed
      end
    end
  end

  addMaps("maps/ttt_*.bsp")
  addMaps("maps/terrortown_*.bsp")

  local unique = {}
  local current = string.lower(game.GetMap() or "")
  for _, mapName in ipairs(maps) do
    local lowered = string.lower(mapName)
    if lowered ~= current and not unique[lowered] then
      unique[lowered] = mapName
    end
  end

  local list = {}
  for _, name in pairs(unique) do
    list[#list + 1] = name
  end

  return list
end

local function sendAdminMapList(ply)
  if not IsValid(ply) then return end
  local maps = collectMaps()

  net.Start("ST2_ADMIN_MAPS")
    net.WriteString(game.GetMap() or "")
    net.WriteUInt(#maps, 12)
    for _, mapName in ipairs(maps) do
      net.WriteString(mapName)
    end
  net.Send(ply)
end

local function shuffle(list)
  for i = #list, 2, -1 do
    local j = math.random(i)
    list[i], list[j] = list[j], list[i]
  end
end

local function pickMapOptions()
  local pool = collectMaps()
  if #pool == 0 then return {} end

  shuffle(pool)
  local options = {}
  for i = 1, math.min(MAP_VOTE_OPTION_COUNT, #pool) do
    options[i] = pool[i]
  end

  return options
end

local function sendMapVoteState(target)
  if not mapVote.active then return end
  net.Start("ST2_MAPVOTE_STATE")
    net.WriteUInt(#mapVote.options, 6)
    for _, mapName in ipairs(mapVote.options) do
      net.WriteString(mapName)
      net.WriteUInt(mapVote.votes[mapName] or 0, 12)
    end
    net.WriteFloat(mapVote.endTime)
  net.Send(target or player.GetAll())
end

local function finishMapVote()
  if not mapVote.active then return end
  mapVote.active = false
  timer.Remove(MAP_VOTE_TIMER)

  local winner = mapVote.options[1]
  local highest = -1
  local ties = {}
  for _, mapName in ipairs(mapVote.options) do
    local votes = mapVote.votes[mapName] or 0
    if votes > highest then
      highest = votes
      ties = {mapName}
      winner = mapName
    elseif votes == highest then
      ties[#ties + 1] = mapName
    end
  end

  if #ties > 1 then
    winner = ties[math.random(#ties)]
  end

  net.Start("ST2_MAPVOTE_RESULT")
    net.WriteString(winner or "")
    net.WriteUInt(#mapVote.options, 6)
    for _, mapName in ipairs(mapVote.options) do
      net.WriteString(mapName)
      net.WriteUInt(mapVote.votes[mapName] or 0, 12)
    end
  net.Broadcast()

  PrintMessage(HUD_PRINTTALK, "[ShadowTTT2] Mapvote beendet. Gewonnen hat: " .. (winner or "Unbekannt"))

  timer.Simple(5, function()
    if winner and winner ~= "" then
      RunConsoleCommand("changelevel", winner)
    end
  end)
end

local function startMapVote()
  if mapVote.active then return end

  local options = pickMapOptions()
  if #options == 0 then return end

  resetMapVote()
  mapVote.active = true
  mapVote.endTime = CurTime() + MAP_VOTE_DURATION
  mapVote.options = options
  for _, mapName in ipairs(options) do
    mapVote.optionSet[mapName] = true
    mapVote.votes[mapName] = 0
  end

  sendMapVoteState()
  PrintMessage(HUD_PRINTTALK, "[ShadowTTT2] Mapvote gestartet! Stimme jetzt für die nächste Map ab.")

  timer.Create(MAP_VOTE_TIMER, MAP_VOTE_DURATION, 1, finishMapVote)
end

local function maybeStartMapVote()
  if mapVote.active then return end
  local cvar = GetConVar("ttt_round_limit")
  if not cvar or cvar:GetInt() <= 0 then return end

  local roundsLeft = GetGlobalInt("ttt_rounds_left", cvar:GetInt())
  if roundsLeft <= 0 then
    startMapVote()
  end
end

net.Receive("ST2_MAPVOTE_VOTE", function(_, ply)
  if not mapVote.active or not IsValid(ply) then return end

  local choice = net.ReadString()
  if not mapVote.optionSet[choice] then return end

  trackMapVote(choice)
  local sid = ply:SteamID()
  local previous = sid and mapVote.voterChoice[sid]
  if previous == choice then return end

  if previous and mapVote.votes[previous] then
    mapVote.votes[previous] = math.max(0, mapVote.votes[previous] - 1)
  end

  mapVote.voterChoice[sid] = choice
  mapVote.votes[choice] = (mapVote.votes[choice] or 0) + 1

  sendMapVoteState()
end)

hook.Add("PlayerInitialSpawn", "ST2_MapVoteSync", function(ply)
  if mapVote.active then
    sendMapVoteState(ply)
  end
end)

hook.Add("PlayerInitialSpawn", "ST2_BanEnforceOnJoin", function(ply)
  if not IsValid(ply) then return end
  local allowed, msg = checkBanStatus(ply:SteamID(), ply:Nick())
  if allowed == false then
    timer.Simple(0, function()
      if IsValid(ply) then
        ply:Kick(msg or "Du bist gebannt.")
      end
    end)
  end
end)

hook.Add("PlayerDisconnected", "ST2_MapVoteRemoveVote", function(ply)
  if not mapVote.active or not IsValid(ply) then return end
  local sid = ply:SteamID()
  local choice = sid and mapVote.voterChoice[sid]
  if not choice or not mapVote.votes[choice] then return end

  mapVote.voterChoice[sid] = nil
  mapVote.votes[choice] = math.max(0, mapVote.votes[choice] - 1)
  sendMapVoteState()
end)

hook.Add("TTTEndRound", "ST2_MapVoteTrigger", function()
  timer.Simple(1, function()
    maybeStartMapVote()
  end)
end)

hook.Add("TTTPrepareRound", "ST2_MapVoteResetOnPrepare", function()
  cancelMapVote()
end)

local function applyStoredModel(ply)
  if not IsValid(ply) then return end
  local data = getModelData()
  local mdl = data.selected and data.selected[ply:SteamID()]
  if not mdl or not data.modelSet or not data.modelSet[mdl] or (data.enabledSet and not data.enabledSet[mdl]) then return end

  timer.Simple(0, function()
    if IsValid(ply) then
      ply:SetModel(mdl)
      trackModelUsage(mdl)
      applyMoveSpeedToPlayer(ply)
    end
  end)
end

local function sendRecoilMultiplier(ply)
  if not IsValid(ply) then return end
  net.Start("ST2_ADMIN_RECOIL")
  net.WriteFloat(getRecoilMultiplier())
  net.Send(ply)
end

local function sendMovementSpeeds(ply)
  if not IsValid(ply) then return end
  net.Start("ST2_ADMIN_SPEED")
  net.WriteFloat(getWalkSpeed())
  net.WriteFloat(getRunSpeed())
  net.Send(ply)
end

local function endCurrentRound()
  local winConst = _G.WIN_TIMELIMIT or _G.WIN_NONE or _G.WIN_INNOCENT or _G.WIN_TRAITOR or 0

  if isfunction(EndRound) then
    EndRound(winConst)
    return true
  end

  if GAMEMODE and isfunction(GAMEMODE.EndRound) then
    GAMEMODE:EndRound(winConst)
    return true
  end

  RunConsoleCommand("ttt_roundrestart")
  return false
end

local function collectWeaponList()
  local seen = {}
  local entries = {}
  for _, wep in ipairs(weapons.GetList() or {}) do
    local class = wep and (wep.ClassName or wep.Classname or wep.Class) or nil
    if not isstring(class) or class == "" or seen[class] then continue end
    seen[class] = true

    local name = ""
    if wep and isstring(wep.PrintName) then
      name = wep.PrintName
    end

    table.insert(entries, {class = class, name = name})
  end

  table.sort(entries, function(a, b)
    local aName = string.lower(a.name ~= "" and a.name or a.class)
    local bName = string.lower(b.name ~= "" and b.name or b.class)
    if aName == bName then
      return string.lower(a.class) < string.lower(b.class)
    end
    return aName < bName
  end)

  return entries
end

local function sendWeaponList(ply)
  if not IsValid(ply) then return end
  local entries = collectWeaponList()

  net.Start("ST2_ADMIN_WEAPON_LIST")
  net.WriteUInt(#entries, 12)
  for _, info in ipairs(entries) do
    net.WriteString(info.class or "")
    net.WriteString(info.name or "")
  end
  net.Send(ply)
end

local function sendBanList(targets)
  if not targets then return end
  local entries = collectBanList()

  net.Start("ST2_ADMIN_BANLIST")
  net.WriteUInt(#entries, 10)
  for _, entry in ipairs(entries) do
    net.WriteString(entry.sid or "")
    net.WriteString(entry.name or "")
    net.WriteString(entry.banner or "")
    net.WriteString(entry.reason or "")
    net.WriteUInt(entry.expires or 0, 32)
  end
  net.Send(targets)
end

local function broadcastBanList()
  local admins = {}
  for _, p in ipairs(player.GetAll()) do
    if IsAdmin(p) then
      admins[#admins + 1] = p
    end
  end

  if #admins > 0 then
    sendBanList(admins)
  end
end

local function checkBanStatus(steamId, playerName)
  if not isstring(steamId) or steamId == "" then return true end
  local ban = ShadowTTT2.Bans and ShadowTTT2.Bans[steamId]
  if not ban then return true end

  if banExpired(ban) then
    removeBan(steamId)
    return true
  end

  local reason = ban.reason or "Du bist gebannt."
  if ban.expires and ban.expires > 0 then
    local remaining = math.max(0, ban.expires - os.time())
    reason = string.format("%s | endet in %s", reason, string.NiceTime(remaining))
  else
    reason = reason .. " | permanent"
  end

  local who = playerName or steamId
  print(string.format("[ShadowTTT2] Ban-Check verweigert für %s (%s)", tostring(who), tostring(steamId)))
  return false, "[ShadowTTT2] Du bist gebannt: " .. reason
end

concommand.Add("shadow_admin_open", function(ply)
  if not IsAdmin(ply) then return end
  net.Start("ST2_ADMIN_OPEN") net.Send(ply)
  sendRecoilMultiplier(ply)
  sendMovementSpeeds(ply)
end)

concommand.Add("shadowttt2_rebuild_models", function(ply)
  if IsValid(ply) and not IsAdmin(ply) then return end
  rebuildModelList()
  broadcastModelSnapshots()

  if IsValid(ply) then
    ply:ChatPrint("[ShadowTTT2] Model list rebuilt and pushed to players")
  else
    print("[ShadowTTT2] Model list rebuilt and pushed to players")
  end
end)

net.Receive("ST2_ADMIN_REQUEST", function(_, ply)
  if not IsAdmin(ply) then return end
  net.Start("ST2_ADMIN_OPEN") net.Send(ply)
  sendRecoilMultiplier(ply)
  sendMovementSpeeds(ply)
end)

net.Receive("ST2_ADMIN_WEAPON_REQUEST", function(_, ply)
  if not IsAdmin(ply) then return end
  sendWeaponList(ply)
end)

net.Receive("ST2_ADMIN_BANLIST_REQUEST", function(_, ply)
  if not IsAdmin(ply) then return end
  sendBanList(ply)
end)

net.Receive("ST2_ADMIN_MAPS_REQUEST", function(_, ply)
  if not IsAdmin(ply) then return end
  sendAdminMapList(ply)
end)

local function sendPointsBalance(ply)
  if not IsValid(ply) then return end
  ensureStarterPoints(ply)
  net.Start("ST2_POINTS_BALANCE")
  net.WriteInt(getPoints(ply), 32)
  net.Send(ply)
end

net.Receive("ST2_POINTS_REQUEST", function(_, ply)
  if not IsValid(ply) then return end
  sendPointsBalance(ply)
end)

net.Receive("ST2_POINTS_SPIN", function(_, ply)
  if not IsValid(ply) then return end
  local bet = math.Clamp(math.floor(net.ReadUInt(16) or 0), 0, 65535)
  ensureStarterPoints(ply)
  local ok, msg, symbols, balance, payout = spinSlots(ply, bet)

  net.Start("ST2_POINTS_SPIN_RESULT")
    net.WriteBool(ok or false)
    net.WriteString(msg or "")
    net.WriteUInt(bet, 16)
    net.WriteInt(payout or 0, 32)
    net.WriteInt(balance or getPoints(ply), 32)
    local count = istable(symbols) and #symbols or 0
    net.WriteUInt(count, 3)
    for i = 1, count do
      local sym = symbols[i] or {}
      net.WriteString(sym.id or "")
      net.WriteString(sym.icon or "")
    end
  net.Send(ply)
end)

net.Receive("ST2_ADMIN_ACTION", function(_, ply)
  if not IsAdmin(ply) then return end
  local act = net.ReadString()
  if act == "endround" then
    cancelMapVote()
    endCurrentRound()
    return
  end

  if act == "roundtime" then
    local minutes = net.ReadUInt(12) or 0
    minutes = math.Clamp(minutes, 1, 300)
    if minutes > 0 then
      RunConsoleCommand("ttt_roundtime_minutes", tostring(minutes))
      if IsValid(ply) then
        ply:PrintMessage(HUD_PRINTTALK, "[ShadowTTT2] Rundenzeit auf " .. minutes .. " Minuten gesetzt.")
      end
    end
    return
  end

  if act == "roundrestart" then
    RunConsoleCommand("ttt_roundrestart")
    return
  end

  if act == "kick" then
    local sid = net.ReadString()
    local reason = string.Trim(net.ReadString() or "")
    local tgt = player.GetBySteamID(sid)
    if IsValid(tgt) then
      local msg = reason ~= "" and ("Du wurdest gekickt: " .. reason) or "Du wurdest vom Server gekickt."
      tgt:Kick(msg)
    end
    return
  end

  if act == "ban" then
    local sid = net.ReadString()
    local minutes = net.ReadUInt(32) or 0
    local reason = string.Trim(net.ReadString() or "")
    local tgt = player.GetBySteamID(sid)
    if not IsValid(tgt) then return end

    local banner = IsValid(ply) and ply:Nick() or "Konsole"
    addBan(sid, math.min(minutes, 525600), reason, banner, tgt:Nick())
    local lengthText = minutes > 0 and string.NiceTime(minutes * 60) or "permanent"
    tgt:Kick(string.format("Gebannt (%s): %s", lengthText, reason ~= "" and reason or "Kein Grund angegeben"))
    broadcastBanList()
    return
  end

  local sid = net.ReadString()
  local class = act == "giveweapon" and string.Trim(net.ReadString() or "") or nil

  local tgt = player.GetBySteamID(sid)
  if not IsValid(tgt) then return end
  if act == "slay" then tgt:Kill()
  elseif act == "respawn" then tgt:Spawn()
  elseif act == "goto" then ply:SetPos(tgt:GetPos() + Vector(50,0,0))
  elseif act == "bring" then tgt:SetPos(ply:GetPos() + Vector(50,0,0))
  elseif act == "force_traitor" and tgt.SetRole then tgt:SetRole(ROLE_TRAITOR) SendFullStateUpdate()
  elseif act == "force_innocent" and tgt.SetRole then tgt:SetRole(ROLE_INNOCENT) SendFullStateUpdate()
  elseif act == "giveweapon" and isstring(class) and class ~= "" then
    tgt:Give(class)
  end
end)

net.Receive("ST2_ADMIN_RECOIL_REQUEST", function(_, ply)
  if not IsAdmin(ply) then return end
  sendRecoilMultiplier(ply)
end)

net.Receive("ST2_ADMIN_RECOIL_SET", function(_, ply)
  if not IsAdmin(ply) then return end
  local requested = clampRecoilMultiplier(net.ReadFloat())
  if recoilMultiplierConVar then
    recoilMultiplierConVar:SetFloat(requested)
  else
    RunConsoleCommand("st2_recoil_mult", tostring(requested))
  end
  sendRecoilMultiplier(ply)
  applyRecoilMultiplierToWeapons(requested)
end)

net.Receive("ST2_ADMIN_SPEED_REQUEST", function(_, ply)
  if not IsAdmin(ply) then return end
  sendMovementSpeeds(ply)
end)

net.Receive("ST2_ADMIN_SPEED_SET", function(_, ply)
  if not IsAdmin(ply) then return end
  local requestedWalk = clampWalkSpeed(net.ReadFloat())
  local requestedRun = clampRunSpeed(net.ReadFloat())

  if walkSpeedConVar then
    walkSpeedConVar:SetFloat(requestedWalk)
  else
    RunConsoleCommand("st2_walk_speed", tostring(requestedWalk))
  end

  if runSpeedConVar then
    runSpeedConVar:SetFloat(requestedRun)
  else
    RunConsoleCommand("st2_run_speed", tostring(requestedRun))
  end

  applyMoveSpeeds()
  sendMovementSpeeds(ply)
end)

net.Receive("ST2_ADMIN_UNBAN", function(_, ply)
  if not IsAdmin(ply) then return end
  local sid = net.ReadString()
  if not isstring(sid) or sid == "" then return end

  removeBan(sid)
  broadcastBanList()
  if IsValid(ply) then
    ply:PrintMessage(HUD_PRINTTALK, "[ShadowTTT2] Ban für " .. sid .. " aufgehoben.")
  end
end)

net.Receive("ST2_ADMIN_MAP_CHANGE", function(_, ply)
  if not IsAdmin(ply) then return end
  local mapName = string.Trim(net.ReadString() or "")
  if mapName == "" then return end
  if not file.Exists("maps/" .. mapName .. ".bsp", "GAME") then return end

  cancelMapVote()
  PrintMessage(HUD_PRINTTALK, string.format("[ShadowTTT2] %s wechselt die Map zu %s", IsValid(ply) and ply:Nick() or "Konsole", mapName))
  timer.Simple(2, function()
    RunConsoleCommand("changelevel", mapName)
  end)
end)

local function sendAdminPlayerList(ply)
  if not IsValid(ply) then return end
  local players = player.GetAll()
  net.Start("ST2_ADMIN_PLAYERLIST")
    net.WriteUInt(#players, 8)
    for _, tgt in ipairs(players) do
      net.WriteString(tgt:Nick())
      net.WriteString(tgt:SteamID())
      net.WriteInt(tgt:GetNWInt("ST2_Points", getPoints(tgt)), 32)
    end
  net.Send(ply)
end

net.Receive("ST2_ADMIN_PLAYERLIST", function(_, ply)
  if not IsAdmin(ply) then return end

  sendAdminPlayerList(ply)
end)

net.Receive("ST2_ADMIN_POINTS_GRANT", function(_, ply)
  if not IsAdmin(ply) then return end

  local sid = net.ReadString()
  local amount = math.floor(net.ReadInt(32) or 0)
  if not isstring(sid) or sid == "" then return end
  if amount <= 0 then return end

  local tgt = player.GetBySteamID(sid)
  if not IsValid(tgt) then return end

  ensureStarterPoints(tgt)
  addPoints(tgt, amount)
  sendPointsBalance(tgt)

  if IsValid(ply) then
    ply:PrintMessage(HUD_PRINTTALK, string.format("[ShadowTTT2] %s +%d Punkte gegeben.", tgt:Nick(), amount))
  end
  tgt:ChatPrint(string.format("[ShadowTTT2] Du hast %d Punkte vom Admin erhalten.", amount))

  sendAdminPlayerList(ply)
end)

net.Receive("ST2_PS_MODELS_REQUEST", function(_, ply)
  if not IsValid(ply) then return end
  sendModelSnapshot(ply)
end)

net.Receive("ST2_PS_EQUIP", function(_, ply)
  local mdl = net.ReadString()
  if not isstring(mdl) or #mdl >= 256 then return end

  local data = getModelData()
  if not util.IsValidModel(mdl) or not (data.modelSet and data.modelSet[mdl]) then return end
  if data.enabledSet and not data.enabledSet[mdl] then return end

  local sid = ply:SteamID()
  local current = sid and data.selected and data.selected[sid]
  if current ~= mdl then
    ensureStarterPoints(ply)
    local price = getModelPrice(mdl)
    if price > 0 then
      local balance = getPoints(ply)
      if balance < price then
        ply:ChatPrint(string.format("[ShadowTTT2] Nicht genug Punkte: %d benötigt, %d verfügbar.", price, balance))
        sendPointsBalance(ply)
        return
      end
      setPoints(ply, balance - price)
    end
  end

  ply:SetModel(mdl)
  data.selected = data.selected or {}
  data.selected[sid] = mdl
  trackModelUsage(mdl)
  saveModelData()
  sendPointsBalance(ply)
  sendModelSnapshot(ply)
end)

local function sendModelAdminConfig(ply)
  if not IsAdmin(ply) then return end
  local data = getModelData()
  local models = data.models or {}
  net.Start("ST2_PS_ADMIN_CONFIG")
    net.WriteUInt(DEFAULT_MODEL_PRICE, 16)
    net.WriteUInt(#models, 16)
    for _, mdl in ipairs(models) do
      net.WriteString(mdl)
      net.WriteBool(not data.enabledSet or data.enabledSet[mdl])
      net.WriteUInt(getModelPrice(mdl), 16)
    end
  net.Send(ply)
end

net.Receive("ST2_PS_ADMIN_CONFIG_REQUEST", function(_, ply)
  if not IsAdmin(ply) then return end
  sendModelAdminConfig(ply)
end)

net.Receive("ST2_PS_ADMIN_PRICE", function(_, ply)
  if not IsAdmin(ply) then return end

  local mdl = net.ReadString()
  local useDefault = net.ReadBool()
  local price = net.ReadUInt(16)
  if not isstring(mdl) or mdl == "" then return end

  local data = getModelData()
  if not data.modelSet or not data.modelSet[mdl] then return end

  data.prices = data.prices or {}
  if useDefault then
    data.prices[mdl] = nil
  else
    data.prices[mdl] = normalizeModelPrice(price)
  end

  saveModelData()
  sendModelAdminConfig(ply)
  broadcastModelSnapshots()
end)

net.Receive("ST2_PS_ADMIN_TOGGLE", function(_, ply)
  if not IsAdmin(ply) then return end

  local mdl = net.ReadString()
  if not isstring(mdl) or mdl == "" then return end

  local data = getModelData()
  if not data.modelSet or not data.modelSet[mdl] then return end

  data.enabled = data.enabled or {}
  local current = data.enabled[mdl]
  if current == nil then current = true end
  data.enabled[mdl] = not current

  if data.enabled[mdl] == false then
    for sid, selected in pairs(data.selected or {}) do
      if selected == mdl then
        data.selected[sid] = nil
      end
    end
  end

  data.enabledSet = nil
  saveModelData()
  getModelData()
  sendModelAdminConfig(ply)
  broadcastModelSnapshots()
end)

hook.Add("PlayerInitialSpawn", "ST2_PS_SEND_MODEL_SNAPSHOT", function(ply)
  timer.Simple(1, function()
    sendModelSnapshot(ply)
    applyStoredModel(ply)
    applyMoveSpeedToPlayer(ply)
    ensureStarterPoints(ply)
    sendPointsBalance(ply)
  end)
end)

hook.Add("PlayerSpawn", "ST2_PS_APPLY_SAVED_MODEL", applyStoredModel)
hook.Add("PlayerSpawn", "ST2_APPLY_MOVE_SPEEDS", function(ply)
  timer.Simple(0, function()
    applyMoveSpeedToPlayer(ply)
  end)
end)
hook.Add("PlayerSpawn", "ST2_POINTS_SYNC_ON_SPAWN", function(ply)
  timer.Simple(0, function()
    ensureStarterPoints(ply)
    sendPointsBalance(ply)
  end)
end)

-- Bootstrap caches on load so model data exists before the first request
loadAnalytics()
loadBanData()
loadPoints()
getModelData()
applyMoveSpeeds()

timer.Create("ST2_POINTS_TICK", POINTS_TICK_INTERVAL, 0, function()
  for _, p in ipairs(player.GetAll()) do
    addPoints(p, POINTS_TICK_AMOUNT)
  end
end)

print("[ShadowTTT2] MODEL-ENUM SERVER ready")


print("[ShadowTTT2] MODEL-ENUM SERVER loaded")

ShadowTTT2 = ShadowTTT2 or {}
ShadowTTT2.Admins = ShadowTTT2.Admins or { ["STEAM_0:1:15220591"] = true }
ShadowTTT2.WorkshopPushed = ShadowTTT2.WorkshopPushed or {}
ShadowTTT2.ModelData = ShadowTTT2.ModelData or {}
ShadowTTT2.ServerCoreLoaded = true

local function IsAdmin(ply) return IsValid(ply) and ShadowTTT2.Admins[ply:SteamID()] end
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
local MODEL_DATA_PATH = "shadowttt2/playermodels.json"
local MODEL_CACHE_VERSION = 2
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

local function ensureDataDir()
  if not file.Exists("shadowttt2", "DATA") then
    file.CreateDir("shadowttt2")
  end
end

local function loadModelData()
  ensureDataDir()
  local raw = file.Exists(MODEL_DATA_PATH, "DATA") and file.Read(MODEL_DATA_PATH, "DATA")
  local decoded = raw and util.JSONToTable(raw)
  if istable(decoded) then
    ShadowTTT2.ModelData.models = decoded.models or {}
    ShadowTTT2.ModelData.selected = decoded.selected or {}
    ShadowTTT2.ModelData.version = decoded.version or 0
  else
    ShadowTTT2.ModelData.models = {}
    ShadowTTT2.ModelData.selected = {}
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

  local selected = ShadowTTT2.ModelData.selected or {}
  for sid, mdl in pairs(selected) do
    if not ShadowTTT2.ModelData.modelSet[mdl] then
      selected[sid] = nil
    end
  end
  ShadowTTT2.ModelData.selected = selected
end

local function saveModelData()
  ensureDataDir()
  file.Write(MODEL_DATA_PATH, util.TableToJSON({
    models = ShadowTTT2.ModelData.models or {},
    selected = ShadowTTT2.ModelData.selected or {},
    version = MODEL_CACHE_VERSION
  }, true))
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

  local selected = ShadowTTT2.ModelData.selected or {}
  for sid, mdl in pairs(selected) do
    if not set[mdl] then
      selected[sid] = nil
    end
  end

  ShadowTTT2.ModelData.selected = selected
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

util.AddNetworkString("ST2_ADMIN_REQUEST")
util.AddNetworkString("ST2_ADMIN_OPEN")
util.AddNetworkString("ST2_ADMIN_PLAYERLIST")
util.AddNetworkString("ST2_ADMIN_ACTION")
util.AddNetworkString("ST2_ADMIN_RECOIL")
util.AddNetworkString("ST2_ADMIN_RECOIL_REQUEST")
util.AddNetworkString("ST2_ADMIN_RECOIL_SET")
util.AddNetworkString("ST2_PS_EQUIP")
util.AddNetworkString("ST2_PS_MODELS_REQUEST")
util.AddNetworkString("ST2_PS_MODELS")

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

  return ShadowTTT2.ModelData
end

local function sendModelSnapshot(ply)
  if not IsValid(ply) then return end

  local data = getModelData()
  local models = data.models or {}
  net.Start("ST2_PS_MODELS")
    net.WriteUInt(#models, 16)
    for _, mdl in ipairs(models) do
      net.WriteString(mdl)
    end
    net.WriteString((data.selected and data.selected[ply:SteamID()]) or "")
  net.Send(ply)
end

local function broadcastModelSnapshots()
  for _, tgt in ipairs(player.GetAll()) do
    sendModelSnapshot(tgt)
  end
end

local function applyStoredModel(ply)
  if not IsValid(ply) then return end
  local data = getModelData()
  local mdl = data.selected and data.selected[ply:SteamID()]
  if not mdl or not data.modelSet or not data.modelSet[mdl] then return end

  timer.Simple(0, function()
    if IsValid(ply) then
      ply:SetModel(mdl)
    end
  end)
end

local function sendRecoilMultiplier(ply)
  if not IsValid(ply) then return end
  net.Start("ST2_ADMIN_RECOIL")
  net.WriteFloat(getRecoilMultiplier())
  net.Send(ply)
end

concommand.Add("shadow_admin_open", function(ply)
  if not IsAdmin(ply) then return end
  net.Start("ST2_ADMIN_OPEN") net.Send(ply)
  sendRecoilMultiplier(ply)
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
end)

net.Receive("ST2_ADMIN_ACTION", function(_, ply)
  if not IsAdmin(ply) then return end
  local act = net.ReadString()
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
  elseif act == "roundrestart" then RunConsoleCommand("ttt_roundrestart")
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

net.Receive("ST2_ADMIN_PLAYERLIST", function(_, ply)
  if not IsAdmin(ply) then return end

  local players = player.GetAll()
  net.Start("ST2_ADMIN_PLAYERLIST")
    net.WriteUInt(#players, 8)
    for _, tgt in ipairs(players) do
      net.WriteString(tgt:Nick())
      net.WriteString(tgt:SteamID())
      net.WriteInt(tgt:GetNWInt("ST2_Points", 0), 32)
    end
  net.Send(ply)
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

  ply:SetModel(mdl)
  local sid = ply:SteamID()
  data.selected = data.selected or {}
  data.selected[sid] = mdl
  saveModelData()
  sendModelSnapshot(ply)
end)

hook.Add("PlayerInitialSpawn", "ST2_PS_SEND_MODEL_SNAPSHOT", function(ply)
  timer.Simple(1, function()
    sendModelSnapshot(ply)
    applyStoredModel(ply)
  end)
end)

hook.Add("PlayerSpawn", "ST2_PS_APPLY_SAVED_MODEL", applyStoredModel)

-- Bootstrap caches on load so model data exists before the first request
getModelData()

print("[ShadowTTT2] MODEL-ENUM SERVER ready")

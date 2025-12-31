
print("[ShadowTTT2] MODEL-ENUM SERVER loaded")

ShadowTTT2 = ShadowTTT2 or {}
ShadowTTT2.Admins = ShadowTTT2.Admins or { ["STEAM_0:1:15220591"] = true }
ShadowTTT2.WorkshopPushed = ShadowTTT2.WorkshopPushed or {}
ShadowTTT2.ServerCoreLoaded = true

local function IsAdmin(ply) return IsValid(ply) and ShadowTTT2.Admins[ply:SteamID()] end
local RECOIL_MULTIPLIER = 0.45

local function ReduceRecoil(wep)
  if not IsValid(wep) then return end
  if wep.ST2_RecoilTweaked then return end
  local primary = wep.Primary
  if not istable(primary) then return end
  local recoil = primary.Recoil
  if not isnumber(recoil) then return end

  wep.ST2_RecoilTweaked = true
  wep.Primary.Recoil = recoil * RECOIL_MULTIPLIER
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

local function PushWorkshopDownloads()
  if not engine.GetAddons then return end

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
    print("[ShadowTTT2] Pointshop // no workshop addons detected; ensure your host_workshop_collection is mounted")
  else
    print(string.format("[ShadowTTT2] Pointshop // queued %d workshop addons for download", added))
  end
end
hook.Add("Initialize", "ST2_PS_PUSH_WORKSHOP", PushWorkshopDownloads)
-- Run once more after entities initialize to catch late-mounted workshop collections
hook.Add("InitPostEntity", "ST2_PS_PUSH_WORKSHOP_LATE", PushWorkshopDownloads)

util.AddNetworkString("ST2_ADMIN_REQUEST")
util.AddNetworkString("ST2_ADMIN_OPEN")
util.AddNetworkString("ST2_ADMIN_PLAYERLIST")
util.AddNetworkString("ST2_ADMIN_ACTION")
util.AddNetworkString("ST2_PS_EQUIP")

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

concommand.Add("shadow_admin_open", function(ply)
  if not IsAdmin(ply) then return end
  net.Start("ST2_ADMIN_OPEN") net.Send(ply)
end)

net.Receive("ST2_ADMIN_REQUEST", function(_, ply)
  if not IsAdmin(ply) then return end
  net.Start("ST2_ADMIN_OPEN") net.Send(ply)
end)

net.Receive("ST2_ADMIN_ACTION", function(_, ply)
  if not IsAdmin(ply) then return end
  local act = net.ReadString()
  local sid = net.ReadString()
  local tgt = player.GetBySteamID(sid)
  if not IsValid(tgt) then return end
  if act == "slay" then tgt:Kill()
  elseif act == "respawn" then tgt:Spawn()
  elseif act == "goto" then ply:SetPos(tgt:GetPos() + Vector(50,0,0))
  elseif act == "bring" then tgt:SetPos(ply:GetPos() + Vector(50,0,0))
  elseif act == "force_traitor" and tgt.SetRole then tgt:SetRole(ROLE_TRAITOR) SendFullStateUpdate()
  elseif act == "force_innocent" and tgt.SetRole then tgt:SetRole(ROLE_INNOCENT) SendFullStateUpdate()
  elseif act == "roundrestart" then RunConsoleCommand("ttt_roundrestart")
  end
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

net.Receive("ST2_PS_EQUIP", function(_, ply)
  local mdl = net.ReadString()
  if isstring(mdl) and #mdl < 256 and util.IsValidModel(mdl) then
    ply:SetModel(mdl)
  end
end)

print("[ShadowTTT2] MODEL-ENUM SERVER ready")


print("[ShadowTTT2] MODEL-ENUM SERVER loaded")

ShadowTTT2 = ShadowTTT2 or {}
ShadowTTT2.Admins = ShadowTTT2.Admins or { ["STEAM_0:1:15220591"] = true }
ShadowTTT2.ServerCoreLoaded = true

local function IsAdmin(ply) return IsValid(ply) and ShadowTTT2.Admins[ply:SteamID()] end

util.AddNetworkString("ST2_ADMIN_REQUEST")
util.AddNetworkString("ST2_ADMIN_OPEN")
util.AddNetworkString("ST2_ADMIN_PLAYERLIST")
util.AddNetworkString("ST2_ADMIN_ACTION")
util.AddNetworkString("ST2_PS_EQUIP")

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

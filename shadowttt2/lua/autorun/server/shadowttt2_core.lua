
print("[ShadowTTT2] FINAL server init")

ShadowTTT2 = ShadowTTT2 or {}
ShadowTTT2.Admins = { ["STEAM_0:1:15220591"] = true }

local function IsAdmin(ply) return IsValid(ply) and ShadowTTT2.Admins[ply:SteamID()] end

util.AddNetworkString("ST2_ADMIN_REQUEST")
util.AddNetworkString("ST2_ADMIN_OPEN")
util.AddNetworkString("ST2_ADMIN_PLAYERLIST")
util.AddNetworkString("ST2_ADMIN_ACTION")
util.AddNetworkString("ST2_PS_EQUIP")

-- ADMIN
net.Receive("ST2_ADMIN_REQUEST",function(_,ply)
  if not IsAdmin(ply) then return end
  net.Start("ST2_ADMIN_OPEN") net.Send(ply)
end)

net.Receive("ST2_ADMIN_ACTION",function(_,ply)
  if not IsAdmin(ply) then return end
  local act,sid=net.ReadString(),net.ReadString()
  local tgt=player.GetBySteamID(sid)
  if not IsValid(tgt) then return end
  if act=="slay" then tgt:Kill()
  elseif act=="respawn" then tgt:Spawn()
  elseif act=="force_traitor" and tgt.SetRole then tgt:SetRole(ROLE_TRAITOR) SendFullStateUpdate()
  elseif act=="force_innocent" and tgt.SetRole then tgt:SetRole(ROLE_INNOCENT) SendFullStateUpdate()
  end
end)

-- POINTSHOP
net.Receive("ST2_PS_EQUIP",function(_,ply)
  local mdl=net.ReadString()
  if util.IsValidModel(mdl) then ply:SetModel(mdl) end
end)

print("[ShadowTTT2] FINAL server ready")

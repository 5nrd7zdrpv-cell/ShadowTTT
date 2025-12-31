
print("[ShadowTTT2] Traitor Shop Phase 3 server (unchanged)")

util.AddNetworkString("ST2_TS_BUY")
util.AddNetworkString("ST2_TS_SYNC")
util.AddNetworkString("ST2_TS_SYNC_REQUEST")

local Owned = {}

hook.Add("TTTBeginRound","ST2_TS_ResetOwned", function()
  Owned = {}
end)

hook.Add("PlayerDisconnected", "ST2_TS_CleanupOwned", function(ply)
  if not IsValid(ply) then return end
  Owned[ply] = nil
end)

local ITEMS = {
  equipment = {
    radar = {weapon="weapon_ttt_radar", price=1},
    knife = {weapon="weapon_ttt_knife", price=1},
    c4 = {weapon="weapon_ttt_c4", price=2},
  }
}

net.Receive("ST2_TS_SYNC_REQUEST", function(_, ply)
  if not IsValid(ply) then return end

  net.Start("ST2_TS_SYNC")
    net.WriteTable(Owned[ply] or {})
  net.Send(ply)
end)

net.Receive("ST2_TS_BUY", function(_, ply)
  if not ply:IsActiveTraitor() then return end
  local cat = net.ReadString()
  local id = net.ReadString()
  local it = ITEMS[cat] and ITEMS[cat][id]
  if not it then return end

  Owned[ply] = Owned[ply] or {}
  if Owned[ply][id] then return end
  if ply:GetCredits() < it.price then return end

  ply:SetCredits(ply:GetCredits() - it.price)
  ply:Give(it.weapon)
  Owned[ply][id] = true

  net.Start("ST2_TS_SYNC")
    net.WriteTable(Owned[ply])
  net.Send(ply)
end)

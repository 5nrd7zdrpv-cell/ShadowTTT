
print("[ShadowTTT2] Traitor Shop // Nova Forge server init")

util.AddNetworkString("ST2_TS_BUY")
util.AddNetworkString("ST2_TS_SYNC")
util.AddNetworkString("ST2_TS_SYNC_REQUEST")
util.AddNetworkString("ST2_TS_WORKSHOP")

local Owned = {}
local Projects = {}

local CATALOGUE = {
  weapons = {
    name = "Offensive",
    icon = "icon16/gun.png",
    items = {
      {id = "shadow_knife", name = "Stille Klinge", weapon = "weapon_ttt_knife", price = 1, desc = "Leise Eliminierung mit hoher Präzision.", icon = "icon16/cut.png"},
      {id = "ember_flare", name = "Flaregun", weapon = "weapon_ttt_flaregun", price = 1, desc = "Schießt ein Projektil, das Gegner markiert und verbrennt.", icon = "icon16/lightning.png"},
      {id = "rupture_c4", name = "Remote C4", weapon = "weapon_ttt_c4", price = 2, desc = "Plaziere eine Fernsprengladung mit Timer & Entschärfungsspiel.", icon = "icon16/bomb.png"},
      {id = "disruptor", name = "Scharfschuss-Pistole", weapon = "weapon_ttt_sipistol", price = 1, desc = "Schießt stark durchdringende Projektile.", icon = "icon16/bullet_black.png"}
    }
  },
  gadgets = {
    name = "Gadgets",
    icon = "icon16/wrench_orange.png",
    items = {
      {id = "silent_step", name = "Schallgedämpfte Stiefel", weapon = "weapon_ttt_stungun", price = 1, desc = "Reduziert hörbare Schritte und betäubt auf kurzer Distanz.", icon = "icon16/sound_mute.png"},
      {id = "shadow_radar", name = "Radar 2.0", weapon = "weapon_ttt_radar", price = 1, desc = "Zeigt Bewegungen und letzte Positionen auf der Karte.", icon = "icon16/map.png"},
      {id = "phase_tele", name = "Tarn-Teleporter", weapon = "weapon_ttt_teleport", price = 1, desc = "Merke dir Standorte und bewege dich schnell ohne Spuren.", icon = "icon16/arrow_switch.png"},
      {id = "decoy_ghost", name = "Holo-Decoy", weapon = "weapon_ttt_decoy", price = 1, desc = "Täuscht Scanner und lenkt Aufmerksamkeit auf falsche Signale.", icon = "icon16/ghost.png"}
    }
  },
  control = {
    name = "Kontrolle",
    icon = "icon16/shield.png",
    items = {
      {id = "pulse_push", name = "Impuls-Pusher", weapon = "weapon_ttt_push", price = 1, desc = "Stoße Gegner zurück, perfekt für Abgründe und Kanten.", icon = "icon16/arrow_out.png"},
      {id = "smoke_screen", name = "Reaktiver Nebel", weapon = "weapon_ttt_smokegrenade", price = 1, desc = "Erzeuge sofortigen Sichtschutz mit dichter Wolke.", icon = "icon16/weather_clouds.png"},
      {id = "fracture_charge", name = "Discombobulator+", weapon = "weapon_ttt_confgrenade", price = 1, desc = "Verbesserte Störungsladung, ideal um Gruppen aufzubrechen.", icon = "icon16/fire.png"}
    }
  }
}

local BLUEPRINTS = {
  {id = "workshop_overclock", name = "Overclock Mod", desc = "Veredle deine Remote C4 zu einer stärkeren Ladung.", price = 2, buildTime = 8, rewardWeapon = "weapon_ttt_c4", requiresOwned = "rupture_c4"},
  {id = "workshop_spyglass", name = "Spyglass Kit", desc = "Verbessert dein Radar um schnellere Pings.", price = 1, buildTime = 6, rewardWeapon = "weapon_ttt_radar", requiresOwned = "shadow_radar"},
  {id = "workshop_echo", name = "Echo-Projector", desc = "Upgradet den Decoy zu einem lauteren Ablenkungswerkzeug.", price = 1, buildTime = 5, rewardWeapon = "weapon_ttt_decoy", requiresOwned = "decoy_ghost"},
  {id = "workshop_anchor", name = "Grapple Anchor", desc = "Baue ein kinetisches Seil für riskante Fluchten.", price = 2, buildTime = 10, rewardWeapon = "weapon_ttt_teleport", requiresOwned = "phase_tele"}
}

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
      catalogue = CATALOGUE,
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
  local catData = CATALOGUE[cat]
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

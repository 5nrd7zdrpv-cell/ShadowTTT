
print("[ShadowTTT2] MODEL-ENUM CLIENT loaded")

ShadowTTT2 = ShadowTTT2 or {}
ShadowTTT2.CoreClientLoaded = true
ShadowTTT2.PointshopEnhanced = true

local function requestAdminPlayerList(listView)
  if not IsValid(listView) then return end
  ShadowTTT2.AdminListView = listView
  net.Start("ST2_ADMIN_PLAYERLIST")
  net.SendToServer()
end

net.Receive("ST2_ADMIN_PLAYERLIST", function()
  local list = ShadowTTT2.AdminListView
  if not IsValid(list) then return end

  list:Clear()
  local count = net.ReadUInt(8)
  for i = 1, count do
    local nick = net.ReadString()
    local sid = net.ReadString()
    local points = net.ReadInt(32)
    list:AddLine(nick, sid, points)
  end
end)

-- Admin open (client requests server concommand)
concommand.Add("shadow_admin_open", function()
  net.Start("ST2_ADMIN_REQUEST")
  net.SendToServer()
end)

-- admin panel receives ST2_ADMIN_OPEN net from server
net.Receive("ST2_ADMIN_OPEN", function()
  local f = vgui.Create("DFrame")
  f:SetSize(900,560) f:Center() f:MakePopup() f:SetTitle("ShadowTTT2 Adminpanel (Final)")
  f.OnRemove = function()
    ShadowTTT2.AdminListView = nil
  end
  local list = vgui.Create("DListView", f)
  list:SetPos(20,40) list:SetSize(420,480)
  list:AddColumn("Name") list:AddColumn("SteamID") list:AddColumn("Points")
  requestAdminPlayerList(list)

  local refresh = vgui.Create("DButton", f)
  refresh:SetPos(20, 530)
  refresh:SetSize(420, 20)
  refresh:SetText("Refresh player list")
  refresh.DoClick = function()
    requestAdminPlayerList(list)
  end
  local function btn(y,t,act)
    local b=vgui.Create("DButton",f); b:SetPos(470,y); b:SetSize(400,30); b:SetText(t)
    b.DoClick=function()
      local line = list:GetSelectedLine(); if not line then return end
      local sid = list:GetLine(line):GetColumnText(2)
      net.Start("ST2_ADMIN_ACTION"); net.WriteString(act); net.WriteString(sid); net.SendToServer()
    end
  end
  btn(60,"Respawn","respawn"); btn(100,"Slay","slay"); btn(140,"Goto","goto"); btn(180,"Bring","bring")
  btn(220,"Force Traitor","force_traitor"); btn(260,"Force Innocent","force_innocent"); btn(300,"Round Restart","roundrestart")
end)

local function collect_models()
  local set = {}
  -- 1) player_manager.AllValidModels()
  if player_manager and player_manager.AllValidModels then
    local am = player_manager.AllValidModels()
    if am and table.Count(am) > 0 then
      for k,v in pairs(am) do
        -- am may be {name=path} or {path=name}; try both
        if isstring(k) and util.IsValidModel(k) then set[k]=true end
        if isstring(v) and util.IsValidModel(v) then set[v]=true end
      end
    end
  end
  -- 2) list.Get("PlayerOptionsModel")
  local lm = list.Get("PlayerOptionsModel")
  if lm and table.Count(lm) > 0 then
    for k,v in pairs(lm) do
      if isstring(k) and util.IsValidModel(k) then set[k]=true end
      if isstring(v) and util.IsValidModel(v) then set[v]=true end
      if istable(v) and isstring(v.model) and util.IsValidModel(v.model) then set[v.model]=true end
    end
  end
  -- 3) fallback: scan known model filenames from mounted addons (best-effort)
  -- (file.Find on "models/*" is usually allowed clientside)
  local files = file.Find("models/*", "GAME") or {}
  for _,f in ipairs(files) do
    local path = "models/" .. f
    -- only add known player models (heuristic: include paths that contain 'player' or are .mdl)
    if string.find(f, ".mdl") or string.find(string.lower(f), "player") then
      -- we need full model path; try to find .mdl files recursively
      local mfiles = file.Find("models/"..f.."/*.mdl", "GAME")
      for _,mf in ipairs(mfiles) do
        local full = "models/"..f.."/"..mf
        if util.IsValidModel(full) then set[full]=true end
      end
    end
  end

  -- return sorted list
  local out = {}
  for m,_ in pairs(set) do table.insert(out, m) end
  table.sort(out)
  return out, set
end

hook.Add("PlayerButtonDown", "ST2_F3_POINTSHOP_FINAL", function(_, key)
  if key ~= KEY_F3 then return end

  -- wait a tick to allow Q-menu registrations to finish
  timer.Simple(0.1, function()
    local models, set = collect_models()
    print("[ShadowTTT2] Found models count:", #models)
    if #models == 0 then
      -- debug information to help user
      local am = (player_manager and player_manager.AllValidModels and table.Count(player_manager.AllValidModels())) or 0
      local lm = (list.Get and table.Count(list.Get("PlayerOptionsModel") or {})) or 0
      print("[ShadowTTT2] DEBUG: player_manager.AllValidModels count:", am)
      print("[ShadowTTT2] DEBUG: list.Get('PlayerOptionsModel') count:", lm)
      chat.AddText(Color(200,60,60), "ShadowTTT2 Pointshop: no models found clientside. See console for details.")
      return
    end

    local f = vgui.Create("DFrame")
    f:SetSize(960,600)
    f:Center(); f:MakePopup(); f:SetTitle("ShadowTTT2 Pointshop (Final)")

    local listv = vgui.Create("DListView", f)
    listv:SetPos(20,40); listv:SetSize(360,540); listv:AddColumn("Model")

    local preview = vgui.Create("DModelPanel", f)
    preview:SetPos(400,60); preview:SetSize(260,420)

    local equip = vgui.Create("DButton", f)
    equip:SetPos(700,140); equip:SetSize(220,40); equip:SetText("Equip")

    for _,m in ipairs(models) do
      listv:AddLine(m)
    end

    listv.OnRowSelected = function(_, _, line)
      local mdl = line:GetColumnText(1)
      preview:SetModel(mdl)
      equip.DoClick = function()
        net.Start("ST2_PS_EQUIP"); net.WriteString(mdl); net.SendToServer()
      end
    end
  end)
end)

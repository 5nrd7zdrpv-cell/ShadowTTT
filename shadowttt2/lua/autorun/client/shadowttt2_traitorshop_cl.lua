
print("[ShadowTTT2] Traitor Shop Phase 3 client (FIXED)")

local OWNED = {}

net.Receive("ST2_TS_SYNC", function()
  OWNED = net.ReadTable() or {}
end)

local SHOP = {
  equipment = {
    name = "Equipment",
    items = {
      {id="radar", name="Radar", price=1, desc="Track players", icon="icon16/map.png"},
      {id="knife", name="Knife", price=1, desc="Silent kill", icon="icon16/cut.png"},
      {id="c4", name="C4", price=2, desc="Timed explosive", icon="icon16/bomb.png"},
    }
  }
}

hook.Add("PlayerButtonDown","ST2_TS_PHASE3_FIX",function(_,key)
  if key ~= KEY_C then return end
  if not LocalPlayer():IsActiveTraitor() then return end

  local f = vgui.Create("DFrame")
  f:SetSize(780,540)
  f:Center()
  f:MakePopup()
  f:SetTitle("ShadowTTT2 Traitor Shop")

  local credits = vgui.Create("DLabel", f)
  credits:SetPos(20,35)
  credits:SetFont("Trebuchet18")
  credits:SetText("Credits: " .. LocalPlayer():GetCredits())
  credits:SizeToContents()

  local tabs = vgui.Create("DPropertySheet", f)
  tabs:SetPos(20,60)
  tabs:SetSize(740,450)

  for catid,cat in pairs(SHOP) do
    local pnl = vgui.Create("DPanel", tabs)
    pnl:Dock(FILL)

    local y = 10
    for _,it in ipairs(cat.items) do
      local row = vgui.Create("DPanel", pnl)
      row:SetPos(10,y)
      row:SetSize(700,60)
      row.Paint=function(self,w,h)
        surface.SetDrawColor(45,45,45,240)
        surface.DrawRect(0,0,w,h)
      end

      row.OnCursorEntered=function()
        row.Paint=function(self,w,h)
          surface.SetDrawColor(60,60,60,240)
          surface.DrawRect(0,0,w,h)
        end
      end
      row.OnCursorExited=function()
        row.Paint=function(self,w,h)
          surface.SetDrawColor(45,45,45,240)
          surface.DrawRect(0,0,w,h)
        end
      end

      local icon = vgui.Create("DImage", row)
      icon:SetPos(10,14)
      icon:SetSize(32,32)
      icon:SetImage(it.icon)

      local lbl = vgui.Create("DLabel", row)
      lbl:SetPos(60,10)
      lbl:SetText(it.name .. " (" .. it.price .. "c)
" .. it.desc)
      lbl:SizeToContents()

      local btn = vgui.Create("DButton", row)
      btn:SetPos(580,15)
      btn:SetSize(100,30)

      local function refresh()
        if OWNED[it.id] then
          btn:SetText("Owned")
          btn:SetEnabled(false)
        elseif LocalPlayer():GetCredits() < it.price then
          btn:SetText("No Credits")
          btn:SetEnabled(false)
        else
          btn:SetText("Buy")
          btn:SetEnabled(true)
        end
      end
      refresh()

      btn.DoClick=function()
        net.Start("ST2_TS_BUY")
          net.WriteString(catid)
          net.WriteString(it.id)
        net.SendToServer()

        timer.Simple(0.1, function()
          credits:SetText("Credits: " .. LocalPlayer():GetCredits())
          credits:SizeToContents()
          refresh()
        end)
      end

      y = y + 70
    end

    tabs:AddSheet(cat.name, pnl, "icon16/star.png")
  end
end)

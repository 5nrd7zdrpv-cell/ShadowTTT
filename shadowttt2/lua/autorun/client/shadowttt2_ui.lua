
print("[ShadowTTT2] FINAL client init")

-- ADMIN OPEN
concommand.Add("shadow_admin_open",function()
  net.Start("ST2_ADMIN_REQUEST") net.SendToServer()
end)

-- F3 SHOP (CLIENTSIDE MODEL ENUMERATION)
hook.Add("PlayerButtonDown","ST2_PS_KEY",function(_,k)
  if k~=KEY_F3 then return end

  local models=list.Get("PlayerOptionsModel")
  if not models then return end

  local f=vgui.Create("DFrame")
  f:SetSize(960,600) f:Center() f:MakePopup()
  f:SetTitle("ShadowTTT2 Pointshop")

  local listv=vgui.Create("DListView",f)
  listv:SetPos(20,40) listv:SetSize(360,540)
  listv:AddColumn("Name")
  listv:AddColumn("Model")

  local preview=vgui.Create("DModelPanel",f)
  preview:SetPos(400,60) preview:SetSize(260,420)

  local equip=vgui.Create("DButton",f)
  equip:SetPos(700,120) equip:SetSize(220,40)
  equip:SetText("Equip")

  for name,data in SortedPairs(models) do
    if data.model then
      listv:AddLine(name,data.model)
    end
  end

  listv.OnRowSelected=function(_,_,line)
    local mdl=line:GetColumnText(2)
    preview:SetModel(mdl)
    equip.DoClick=function()
      net.Start("ST2_PS_EQUIP")
      net.WriteString(mdl)
      net.SendToServer()
    end
  end
end)

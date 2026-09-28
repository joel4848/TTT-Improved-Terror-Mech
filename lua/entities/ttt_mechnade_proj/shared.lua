if SERVER then
   AddCSLuaFile("shared.lua")
end

ENT.Type = "anim"
ENT.Base = "ttt_basegrenade_proj"

ENT.Model = Model("models/weapons/w_eq_flashbang.mdl")

AccessorFunc( ENT, "radius", "Radius", FORCE_NUMBER )
AccessorFunc( ENT, "dmg", "Dmg", FORCE_NUMBER )

function ENT:Initialize()
   if not self:GetRadius() then self:SetRadius(256) end
   if not self:GetDmg() then self:SetDmg(0) end

   self.BaseClass.Initialize(self)

	local phys = self:GetPhysicsObject()
	if phys:IsValid() then phys:SetMass(350) end
end

function ENT:Explode(tr)
if SERVER then
local button = ents.Create( "sent_combinemechTTT" )
if not IsValid(button) then return end // Check whether we successfully made an entity, if not - bail
local vvpos = self:GetPos()
local realpos = vvpos + Vector( 0, 0, 25 )
button:SetPos( realpos )
button:Spawn()
self:Remove()
end
end


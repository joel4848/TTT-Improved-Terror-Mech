
ENT.Base = "base_anim"
ENT.Type = "anim"

ENT.PrintName	 = "Combine Mech"
ENT.Author		 = "Fixed by Joel484848 - originally Sakarias88 ported By Jenssons"
ENT.Contact    	 = ""
ENT.Purpose 	 = ""
ENT.Instructions = ""

ENT.Spawnable	   = true
ENT.AdminSpawnable = true

function ENT:SetupDataTables()
	self:NetworkVar("Int",   0, "MechHealthPct")
	self:NetworkVar("Int",   1, "ShieldPercentage")
	self:NetworkVar("Int",   2, "WeaponType")
    self:NetworkVar("Int",   4, "AmmoClip")
    self:NetworkVar("Int",   5, "AmmoReserve")
	self:NetworkVar("Int",   3, "FlyHeight")
	self:NetworkVar("Bool",  0, "IsReloading")
	self:NetworkVar("Bool",  1, "IsFlying")
	self:NetworkVar("Float", 0, "ReloadEndTime")
	self:NetworkVar("Float", 1, "ReloadDuration")
end
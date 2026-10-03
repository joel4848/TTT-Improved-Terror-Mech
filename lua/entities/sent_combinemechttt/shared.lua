
ENT.Base = "base_anim"
ENT.Type = "anim"

ENT.PrintName	 = "Combine Mech"
ENT.Author		 = "Fixed by Joel4848 - originally Sakarias88 ported By Jenssons"
ENT.Contact    	 = ""
ENT.Purpose 	 = ""
ENT.Instructions = ""

ENT.Spawnable	   = true
ENT.AdminSpawnable = true

CreateConVar("ttt_improvedmech_max_health", 100, FCVAR_REPLICATED, "Maximum health of the mech", 1, 10000)
CreateConVar("ttt_improvedmech_max_shield", 100, FCVAR_REPLICATED, "Maximum shield energy of the mech", 0, 10000)
CreateConVar("ttt_improvedmech_shield_recharge_delay", 5, FCVAR_REPLICATED, "Delay (seconds) before shield starts recharging after taking damage", 0, 60)
CreateConVar("ttt_improvedmech_shield_break_delay", 10, FCVAR_REPLICATED, "Delay (seconds) before shield starts recharging after breaking", 0, 60)
CreateConVar("ttt_improvedmech_shield_recharge_rate", 1, FCVAR_REPLICATED, "Shield energy recharged per second", 0.1, 100)

CreateConVar("ttt_improvedmech_altitude_max", 20, FCVAR_REPLICATED, "Maximum flight altitude for the mech (metres)", 0, 999)
CreateConVar("ttt_improvedmech_attack_while_flying", 1, FCVAR_REPLICATED, "Whether the mech can use its weapons while flying", 0, 1)

function ENT:SetupDataTables()
	self:NetworkVar("Int",   0, "MechHealthPct")
	self:NetworkVar("Int",   1, "ShieldPercentage")
	self:NetworkVar("Int",   2, "WeaponType")
    self:NetworkVar("Int",   4, "AmmoClip")
    self:NetworkVar("Int",   5, "AmmoReserve")
	self:NetworkVar("Bool",  0, "IsReloading")
	self:NetworkVar("Bool",  1, "IsFlying")
	self:NetworkVar("Float", 3, "FlyHeight")
	self:NetworkVar("Float", 0, "ReloadEndTime")
	self:NetworkVar("Float", 1, "ReloadDuration")
end
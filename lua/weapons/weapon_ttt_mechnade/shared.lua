resource.AddFile("materials/VGUI/entities/sent_combinemech.vmt")

if SERVER then
   AddCSLuaFile( "shared.lua" )  
end

SWEP.Base				= "weapon_tttbasegrenade"

SWEP.Kind = WEAPON_EQUIP2
SWEP.WeaponID = AMMO_MOLOTOV

SWEP.HoldType			= "grenade"

SWEP.CanBuy = { ROLE_TRAITOR }
SWEP.InLoadoutFor = nil
SWEP.LimitedStock = true
SWEP.AllowDrop = true
SWEP.IsSilent = false
SWEP.NoSights = true

SWEP.ViewModel			= "models/weapons/v_eq_flashbang.mdl"
SWEP.WorldModel			= "models/weapons/w_eq_flashbang.mdl"
SWEP.Weight				= 5
SWEP.AutoSpawnable      = false
-- really the only difference between grenade weapons: the model and the thrown
-- ent.

if CLIENT then
   -- Path to the icon material
   	SWEP.PrintName	 = "Mech Spawn Nade"
	SWEP.Slot		 = 7

	if file.Exists("materials/VGUI/entities/sent_combinemech.vmt", "GAME") then
		SWEP.Icon = "VGUI/entities/sent_combinemech.vmt"
	else
		SWEP.Icon = "VGUI/ttt/icon_nades"
	end
   -- Text shown in the equip menu
	SWEP.EquipMenuData = {


		type = "Weapon",
		desc = "Will Spawn A Mech Make Sure There Is Room."
   };
end

function SWEP:GetGrenadeName()
   return "ttt_mechnade_proj"
end

--Taken from base grenade
function SWEP:Initialize()
   if self.SetWeaponHoldType then
      self:SetWeaponHoldType(self.HoldNormal)
   end

   self:SetDeploySpeed(self.DeploySpeed)

   self:SetDetTime(0)
   self:SetThrowTime(0)
   self:SetPin(false)

   self.was_thrown = false
   if CLIENT then
	self.ModelEntity = ClientsideModel(self.WorldModel)
	self.ModelEntity:SetNoDraw(true)
   end
end

function SWEP:OnRemove()
   if CLIENT and IsValid(self:GetOwner()) and self:GetOwner() == LocalPlayer() and self:GetOwner():Alive() then
      RunConsoleCommand("use", "weapon_ttt_unarmed")
   end

   if CLIENT then
   self.ModelEntity:Remove()
   end
end
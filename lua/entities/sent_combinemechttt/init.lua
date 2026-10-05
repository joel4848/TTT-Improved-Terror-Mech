AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

util.AddNetworkString("TTT_ImprovedMech_ForceView")
util.AddNetworkString("TTT_ImprovedMech_Crosshair")

local MathAbs    = math.abs
local MathCeil	 = math.ceil
local MathClamp  = math.Clamp
local MathFloor	 = math.floor
local MathMax    = math.max
local MathMin    = math.min
local MathRandom = math.random

-- Bits for convar creation
local WEP_NAMES = {"turret", "screamer", "gravprobe", "grenade", "missile", "missilestorm"}

local WEP_STAT_NAMES = {"clipsize", "totalammo", "reloadtime", "firedelay"}

local WEP_DEFAULTS = {
	turret       = {firedelay = 0.08, clipsize = 100, totalammo = 1000, reloadtime = 3},
	screamer     = {firedelay = 1,    clipsize = 1,   totalammo = 0,    reloadtime = 15},
	gravprobe    = {firedelay = 1,    clipsize = 1,   totalammo = 0,    reloadtime = 5},
	grenade      = {firedelay = 1,    clipsize = 5,   totalammo = 40,   reloadtime = 4},
	missile      = {firedelay = 1,    clipsize = 3,   totalammo = 30,   reloadtime = 5},
	missilestorm = {firedelay = 5,    clipsize = 10,  totalammo = 30,   reloadtime = 10}
}

local WEP_MINS = {
	turret       = {firedelay = 0.01, clipsize = 1, totalammo = 0, reloadtime = 0.1},
	screamer     = {firedelay = 0.01, clipsize = 1, totalammo = 0, reloadtime = 0.1},
	gravprobe    = {firedelay = 0.01, clipsize = 1, totalammo = 0, reloadtime = 0.1},
	grenade      = {firedelay = 0.01, clipsize = 1, totalammo = 0, reloadtime = 0.1},
	missile      = {firedelay = 0.01, clipsize = 1, totalammo = 0, reloadtime = 0.1},
	missilestorm = {firedelay = 0.01, clipsize = 1, totalammo = 0, reloadtime = 0.1}
}

local WEP_MAXS = {
	turret       = {firedelay = 10,  clipsize = 10000, totalammo = 10000, reloadtime = 60},
	screamer     = {firedelay = 120, clipsize = 100,   totalammo = 10000, reloadtime = 60},
	gravprobe    = {firedelay = 120, clipsize = 100,   totalammo = 10000, reloadtime = 60},
	grenade      = {firedelay = 10,  clipsize = 500,   totalammo = 10000, reloadtime = 60},
	missile      = {firedelay = 10,  clipsize = 500,   totalammo = 10000, reloadtime = 60},
	missilestorm = {firedelay = 120, clipsize = 1000,  totalammo = 10000, reloadtime = 60}
}

local STAT_DESCRIPTIONS = {
	firedelay  = "The delay (in seconds) between shots",
	clipsize   = "The maximum ammo the weapon's magazine can hold",
	totalammo  = "The total ammo the weapon has",
	reloadtime = "How long (in seconds) the weapon takes to reload its magazine"
}

local convarPrefix = "ttt_improvedmech_"

for _, wepName in ipairs(WEP_NAMES) do
	for _, statName in ipairs(WEP_STAT_NAMES) do
		CreateConVar(convarPrefix .. wepName .. "_" .. statName, WEP_DEFAULTS[wepName][statName], FCVAR_NONE, STAT_DESCRIPTIONS[statName], WEP_MINS[wepName][statName], WEP_MAXS[wepName][statName])
	end
end

-- Get weapon stat convar value or fallback value
function ENT:GetWeaponStat(wepID, statName)
	local wepName = WEP_NAMES[wepID]
	if not wepName then return 0 end

	local convar = GetConVar("ttt_improvedmech_" .. wepName .. "_" .. statName)
	if convar then
		if statName == "firedelay" or statName == "reloadtime" then
			return convar:GetFloat()
		else
			return convar:GetInt()
		end
	end

	return WEP_DEFAULTS[wepName][statName]
end

ENT.Mech                  = nil
ENT.MechUserEnt           = nil
ENT.Seat                  = nil
ENT.JetTimer              = CurTime()
ENT.DotProd               = 1
ENT.ChangeView            = true
ENT.ChangeViewCooldown    = CurTime()
ENT.NPCTarget             = nil
ENT.NPCTarget2            = nil
ENT.UpdateMechAsTargetDel = CurTime()
ENT.Spawner               = nil
ENT.UserSeat              = nil

-- Health
ENT.MechHealth    		 = 400
ENT.MechMaxHealth 		 = 400
ENT.DamageLevel   		 = 0
ENT.SmokeEffect   		 = nil

-- Initial weapon states
ENT.WepType      = 1
ENT.MaxWeps      = 6
ENT.ChangeWepDel = CurTime()
ENT.WeaponStates = {}

-- Screamer
ENT.ScreamerCharging = false
ENT.ScreamerFireTime = 0

-- Grav Probe
ENT.GravProbeSpawned = false
ENT.TempMissile      = nil

-- Missile Storm
ENT.StormMissilesLeft    = 0
ENT.NextMissileStormTime = 0
ENT.StormTargetPos       = Vector(0, 0, 0)

-- FlashLight
ENT.FlashLightEnt    = nil
ENT.LeftFlashSprite  = nil
ENT.RightFlashSprite = nil
ENT.FlashLightDel    = CurTime()

ENT.User     = nil
ENT.EnterDel = CurTime()

-- Hover
ENT.HoverHeight     = 130
ENT.HoverMultiplier = 1
ENT.FlyHeight       = 0

-- Move
ENT.MoveOffsetX      = 0
ENT.MoveOffsetY      = 0
ENT.MoveLeftDel      = CurTime()
ENT.MoveRightDel     = CurTime()
ENT.DontMoveLeftDel  = CurTime()
ENT.DontMoveRightDel = CurTime()
ENT.LeftMoveDist     = 0
ENT.RightMoveDist    = 0

ENT.LeftMoveDir    = nil
ENT.RightMoveDir   = nil
ENT.FootStatus     = 0
ENT.LastFootStatus = 0

ENT.KeepUpRightProp = nil
ENT.KeepUpRightCon  = nil
ENT.StabAng         = nil

-- Sounds
ENT.JetSound        = nil
ENT.JetPlay         = false
ENT.ChargeVortSound = nil

-- Shield
ENT.Energy             = 100
ENT.MaxEnergy          = 100
ENT.NextShieldRecharge = 0
ENT.UpdateShield       = CurTime()
ENT.ShieldEffDel       = CurTime()
ENT.ShieldDown         = false
ENT.ShieldSprite       = nil

-- TESTING
local devMode = CreateConVar("ttt_improvedmech_dev_mode", 0, FCVAR_NONE, "Enables dev mode", 0, 1):GetBool()

hook.Add("TTTBeginRound", "ImprovedMechTestGiveNade", function()
	if devMode then
		for _, ply in player.Iterator() do
			ply:Give("weapon_ttt_mechnade")
			ply:SelectWeapon("weapon_ttt_mechnade")
		end
	end
end)

function ENT:SpawnFunction(ply, tr)
	if not tr.Hit then return end

	local spawnPos = tr.HitPos
	local ent = ents.Create("sent_combinemechTTT")

	ent:SetPos(spawnPos)
	ent:Spawn()
	ent:Activate()

	ent.User = nil
	ent:FixPropProtection(ply)
	ent:SetUser(ply)

	return ent
end

function ENT:Initialize()
	self:SetModel("models/dav0r/hoverball.mdl")
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	self:SetColor(Color(0, 0, 0, 0))
	self:DrawShadow(false)

	local phys = self:GetPhysicsObject()
	if IsValid(phys) then
		phys:Wake()
	end

	self.User = nil

	-- Set health/shield
	local maxHP = GetConVar("ttt_improvedmech_max_health"):GetInt()
	local maxShield = GetConVar("ttt_improvedmech_max_shield"):GetInt()

	self.MechMaxHealth 		= maxHP > 0 and maxHP or 100
	self.MechHealth    		= self.MechMaxHealth
	self.MaxEnergy     		= maxShield >= 0 and maxShield or 100
	self.Energy        		= self.MaxEnergy
	self.NextShieldRecharge = 0

	-- Spawn the mech ragdoll
	self.Mech = ents.Create("prop_ragdoll")
	self.Mech:SetModel("models/CM/Cmbnmch.mdl")
	self.Mech:SetName("mechy")
	self.Mech:SetHealth(1500)
	self.Mech:SetPos(self:GetPos())
	self.Mech:Spawn()

	self:SetNWEntity("MechRagdoll", self.Mech)

	-- Disabling gravity on the mechs legs
	self.Mech:GetPhysicsObjectNum(3):EnableGravity(false)
	self.Mech:GetPhysicsObjectNum(4):EnableGravity(false)
	self.Mech:GetPhysicsObjectNum(9):EnableGravity(false)
	self.Mech:GetPhysicsObjectNum(10):EnableGravity(false)

	local bonepos, _ = self.Mech:GetBonePosition(self.Mech:TranslatePhysBoneToBone(1))
	self:SetPos(bonepos)

	-- Weld the ent to the ragdoll
	constraint.Weld(self, self.Mech, 0, 0, 0, true)

	-- Weld the feet to make it more stable and less floppy
	constraint.Weld(self.Mech, self.Mech, 15, 6, 0, true)
	constraint.Weld(self.Mech, self.Mech, 7, 6, 0, true)
	constraint.Weld(self.Mech, self.Mech, 13, 12, 0, true)
	constraint.Weld(self.Mech, self.Mech, 14, 12, 0, true)
	constraint.Weld(self.Mech, self.Mech, 9, 10, 0, true)
	constraint.Weld(self.Mech, self.Mech, 3, 4, 0, true)

	-- Place a sawblade in the head and set keepupright
	self.KeepUpRightProp = ents.Create("prop_physics")
	self.KeepUpRightProp:SetModel("models/props_junk/sawblade001a.mdl")
	self.KeepUpRightProp:SetPos(self:GetPos() + Vector(0, 0, 20))
	self.KeepUpRightProp:SetAngles(self:GetAngles())
	self.KeepUpRightProp:SetColor(Color(0, 0, 0, 0))
	self.KeepUpRightProp:Spawn()
	self.KeepUpRightProp:DrawShadow(false)
	self.KeepUpRightProp:GetPhysicsObject():EnableGravity(false)

	self.KeepUpRightCon = constraint.Keepupright(self.KeepUpRightProp, self:GetAngles(), 0, 100000000)
	self.StabAng = self:GetAngles()
	constraint.Weld(self.KeepUpRightProp, self.Mech, 0, 1, 0, true)

	-- Mech entry button
	self.MechUserEnt = ents.Create("sent_combinemechUserTTT")
	self.MechUserEnt:SetModelScale(0.95, 0)
	self.MechUserEnt:SetPos(self:GetPos() + Vector(11.5, -0.5, -50))
	self.MechUserEnt:SetAngles(Angle(90, 180, 90))
	self.MechUserEnt:Spawn()
	self.MechUserEnt:DrawShadow(false)
	self.MechUserEnt:SetNWEntity("CombineMechEnt", self)
	constraint.Weld(self.Mech, self.MechUserEnt, 0, 0, 0, true)

	-- Entry button light
	self.EntryButtonLight = ents.Create("env_sprite")
	self.EntryButtonLight:SetPos(self:GetPos() + Vector(11.5, -2, -60))
	self.EntryButtonLight:SetKeyValue("renderfx", "14")
	self.EntryButtonLight:SetKeyValue("model", "sprites/glow01.vmt")
	self.EntryButtonLight:SetKeyValue("scale", "1.0")
	self.EntryButtonLight:SetKeyValue("spawnflags", "1")
	self.EntryButtonLight:SetKeyValue("rendermode", "9")
	self.EntryButtonLight:SetKeyValue("renderfx", "10")
	self.EntryButtonLight:SetKeyValue("renderamt", "255")
	self.EntryButtonLight:SetKeyValue("rendercolor", "0 255 0")
	self.EntryButtonLight:Spawn()
	self.EntryButtonLight:SetParent(self.KeepUpRightProp)

	-- Antenna light
	self.AntennaLight = ents.Create("env_sprite")
	self.AntennaLight:SetPos(self:GetPos() + Vector(-50, -13, 84))
	self.AntennaLight:SetKeyValue("renderfx", "14")
	self.AntennaLight:SetKeyValue("model", "sprites/glow01.vmt")
	self.AntennaLight:SetKeyValue("scale", "1.0")
	self.AntennaLight:SetKeyValue("spawnflags", "1")
	self.AntennaLight:SetKeyValue("rendermode", "9")
	self.AntennaLight:SetKeyValue("renderfx", "9")
	self.AntennaLight:SetKeyValue("rendercolor", "206 1 0")
	self.AntennaLight:Spawn()
	-- If I want it to start at 0 apparently I have to set it after it spawns, otherwise it never appears
	self.AntennaLight:SetKeyValue("renderamt", "0")
	self.AntennaLight:SetParent(self.KeepUpRightProp)

	-- Shield Sphere
	self.ShieldSphere = ents.Create("prop_dynamic")
	self.ShieldSphere:SetModel("models/cm/shield.mdl")
	self.ShieldSphere:SetPos(self:GetPos() + Vector(0, 0, -40))
	self.ShieldSphere:SetAngles(Angle(0, 0, 0))
	self.ShieldSphere:Spawn()
	self.ShieldSphere:SetParent(self.KeepUpRightProp)

	self.ShieldSphere:SetMaterial("models/props_combine/portalball001_sheet")
	self.ShieldSphere:SetRenderMode(RENDERMODE_TRANSCOLOR)
	self.ShieldSphere:SetColor(Color(120, 200, 255, 50))

	self.ShieldSphere:SetModelScale(0.6, 0)
	self.ShieldSphere:SetNotSolid(true)
	self.ShieldSphere:DrawShadow(false)

	self.JetSound = CreateSound(self, "weapons/rpg/rocket1.wav")
	self.ChargeVortSound = CreateSound(self, "npc/vort/attack_charge.wav")

	self.KeepUpRightProp.IsMechProp = true
	self.Mech.IsMechProp = true
	self.IsMechProp = true

	self.UserSeat = ents.Create("prop_vehicle_prisoner_pod")
	self.UserSeat:SetKeyValue("vehiclescript", "scripts/vehicles/MechSeat.txt")
	self.UserSeat:SetModel("models/nova/airboat_seat.mdl")
	self.UserSeat:SetAngles(self:GetAngles() + Angle(0, -90, 0))
	self.UserSeat:SetKeyValue("limitview", "0")
	self.UserSeat:SetColor(Color(255, 255, 255, 0))
	self.UserSeat:Spawn()
	self.UserSeat:DrawShadow(false)
	self.UserSeat:SetNotSolid(true)
	self.UserSeat:GetPhysicsObject():EnableGravity(false)

	-- Set parents for damage stuff
	self.ParentMech                 = self
	self.Mech.ParentMech            = self
	self.KeepUpRightProp.ParentMech = self
	self.MechUserEnt.ParentMech     = self
	self.UserSeat.ParentMech        = self

	-- Initialise ammo
	self.WeaponStates = {}
	for i = 1, self.MaxWeps do
		local clipSize 	= self:GetWeaponStat(i, "clipsize")
		local totalAmmo = self:GetWeaponStat(i, "totalammo")

		self.WeaponStates[i] = {
			clip           = clipSize,
			reserve        = totalAmmo > 0 and MathMax(0, totalAmmo - clipSize) or 0,
			nextFire       = 0,
			isReloading    = false,
			reloadEndTime  = 0,
			reloadDuration = 0
		}
	end

	self:SyncNetVars()
end

-------------------------------------------
-- Ammo/reload stuff
-------------------------------------------

function ENT:StartReload(wepType)
	local wepState = self.WeaponStates[wepType]
	if not wepState or wepState.isReloading then return end

	local clipSize 	= self:GetWeaponStat(wepType, "clipsize")
	local totalAmmo = self:GetWeaponStat(wepType, "totalammo")

	-- Don't reload if clip is full/no reserve left
	if wepState.clip >= clipSize then return end
	if totalAmmo > 0 and wepState.reserve <= 0 then return end

	wepState.isReloading    = true
	wepState.reloadDuration = self:GetWeaponStat(wepType, "reloadtime")
	wepState.reloadEndTime  = CurTime() + wepState.reloadDuration

	self:EmitSound("weapons/ar2/ar2_reload.wav", 75, 100)
end

function ENT:FinishReload(wepType)
	local wepState = self.WeaponStates[wepType]
	if not wepState then return end

	wepState.isReloading = false

	local clipSize  = self:GetWeaponStat(wepType, "clipsize")
	local totalAmmo = self:GetWeaponStat(wepType, "totalammo")
	local needed    = clipSize - wepState.clip

	if totalAmmo == 0 then
		-- Infinite reserve
		wepState.clip = clipSize
	else
		-- Non-infinite reserve
		local taken      = MathMin(needed, wepState.reserve)
		wepState.reserve = wepState.reserve - taken
		wepState.clip    = wepState.clip + taken
	end
end

-------------------------------------------
-- Networking bits
-------------------------------------------

function ENT:SyncNetVars()
	self:SetMechHealthPct(MathClamp(MathCeil((self.MechHealth / self.MechMaxHealth) * 100), 0, 100))
	self:SetShieldPercentage(MathClamp(MathFloor((self.Energy / self.MaxEnergy) * 100), 0, 100))
	self:SetWeaponType(self.WepType)

	-- Only send info for current weapon
	local wepState = self.WeaponStates[self.WepType]
	if wepState then
		self:SetAmmoClip(wepState.clip)
		self:SetAmmoReserve(wepState.reserve)
		self:SetIsReloading(wepState.isReloading)
		self:SetReloadEndTime(wepState.reloadEndTime)
		self:SetReloadDuration(wepState.reloadDuration)
	end
end

-- Weapon selection
function ENT:SelectWeapon(wepID)
	if wepID < 1 or wepID > self.MaxWeps or wepID == self.WepType then return end

	self.WepType = wepID
	self:SyncNetVars()
end

-- Flashlight
function ENT:ToggleFlashlight()
	local curTime = CurTime()
	if self.FlashLightDel >= curTime then return end
	if not IsValid(self.KeepUpRightProp) then return end

	self.FlashLightDel = curTime + 0.25

	if not IsValid(self.FlashLightEnt) then
		self:EmitSound("buttons/button1.wav")
		local flashPos = Vector(50, 0, -20)

		self.FlashLightEnt = ents.Create("env_projectedtexture")
		self.FlashLightEnt:SetParent(self.KeepUpRightProp)
		self.FlashLightEnt:SetLocalPos(flashPos)
		self.FlashLightEnt:SetLocalAngles(Angle(10, 0, 0))
		self.FlashLightEnt:SetKeyValue("enableshadows", 1)
		self.FlashLightEnt:SetKeyValue("LightWorld", 1)
		self.FlashLightEnt:SetKeyValue("farz", 2048)
		self.FlashLightEnt:SetKeyValue("nearz", 65)
		self.FlashLightEnt:SetKeyValue("lightfov", 75)
		self.FlashLightEnt:SetKeyValue("lightcolor", "255 255 255")
		self.FlashLightEnt:Spawn()
		self.FlashLightEnt:Input("SpotlightTexture", nil, nil, "effects/flashlight001")

		self.LeftFlashSprite = ents.Create("env_sprite")
		self.LeftFlashSprite:SetPos(self.KeepUpRightProp:GetPos() + (self.KeepUpRightProp:GetForward() * 20) + (self.KeepUpRightProp:GetRight() * -25) + (self.KeepUpRightProp:GetUp() * -5))
		self.LeftFlashSprite:SetKeyValue("renderfx", "14")
		self.LeftFlashSprite:SetKeyValue("model", "sprites/glow1.vmt")
		self.LeftFlashSprite:SetKeyValue("scale", "1.0")
		self.LeftFlashSprite:SetKeyValue("spawnflags", "1")
		self.LeftFlashSprite:SetKeyValue("rendermode", "9")
		self.LeftFlashSprite:SetKeyValue("renderamt", "255")
		self.LeftFlashSprite:SetKeyValue("rendercolor", "240 240 170")
		self.LeftFlashSprite:Spawn()
		self.LeftFlashSprite:SetParent(self.KeepUpRightProp)

		self.RightFlashSprite = ents.Create("env_sprite")
		self.RightFlashSprite:SetPos(self.KeepUpRightProp:GetPos() + (self.KeepUpRightProp:GetForward() * 20) + (self.KeepUpRightProp:GetRight() * 25) + (self.KeepUpRightProp:GetUp() * -5))
		self.RightFlashSprite:SetKeyValue("renderfx", "14")
		self.RightFlashSprite:SetKeyValue("model", "sprites/glow1.vmt")
		self.RightFlashSprite:SetKeyValue("scale", "1.0")
		self.RightFlashSprite:SetKeyValue("spawnflags", "1")
		self.RightFlashSprite:SetKeyValue("rendermode", "9")
		self.RightFlashSprite:SetKeyValue("renderamt", "255")
		self.RightFlashSprite:SetKeyValue("rendercolor", "240 240 170")
		self.RightFlashSprite:Spawn()
		self.RightFlashSprite:SetParent(self.KeepUpRightProp)
	else
		self:EmitSound("buttons/button4.wav")
		self.FlashLightEnt:Remove()
		self.FlashLightEnt = nil
		if IsValid(self.LeftFlashSprite) then self.LeftFlashSprite:Remove() end
		if IsValid(self.RightFlashSprite) then self.RightFlashSprite:Remove() end
	end
end

-------------------------------------------
-- Mech stuff
-------------------------------------------

-- Mech damage
function ENT:OnTakeDamage(dmg)
	if self.MechHealth <= 0 then return end

	local pilot  = self.User
	local damage = dmg:GetDamage()
	if damage <= 0 then return end

	local curTime = CurTime()

	-- Over-damage to shield doesn't transfer to mech health (no one-shots!)
	if self.Energy > 0 then
		-- Damage shield first
		self.Energy = MathMax(self.Energy - damage, 0)

		-- Shield broken
		if self.Energy <= 0 then
			self.ShieldDown = true
			self.NextShieldRecharge = curTime + GetConVar("ttt_improvedmech_shield_break_delay"):GetFloat()

			self:EmitSound("combine mech/ShieldDown.wav", 85, MathRandom(80, 120))

			local effectdata = EffectData()
			effectdata:SetStart(self:GetPos())
			effectdata:SetOrigin(self:GetPos())
			effectdata:SetScale(1)
			util.Effect("cball_explode", effectdata)
		else
			self.NextShieldRecharge = curTime + GetConVar("ttt_improvedmech_shield_recharge_delay"):GetFloat()
		end
	-- Shield is 0 so reduce mech's health
	else
		if damage > self.MechHealth then
			local overdamage = damage - self.MechHealth
			self.MechHealth = 0

			-- Over-damage DOES get passed onto the pilot unless bullet damage (as this wouldn't logically damage the pilot)
			if IsValid(pilot) and pilot:Alive() then
				self:RemoveUser()

				if not dmg:IsBulletDamage() then -- Don't apply over-damage from bullets, because that doesn't really make sense
					pilot.AllowMechOverdamage = true

					local plyDmg = DamageInfo()
					plyDmg:SetDamage(overdamage)
					plyDmg:SetAttacker(dmg:GetAttacker())
					plyDmg:SetInflictor(dmg:GetInflictor())
					plyDmg:SetDamageType(dmg:GetDamageType())

					pilot:TakeDamageInfo(plyDmg)

					local ply = pilot
					timer.Simple(0, function()
						if IsValid(ply) then
							ply.AllowMechOverdamage = nil
						end
					end)
				end
			end
		else
			self.MechHealth = self.MechHealth - damage
		end
	end

	self:SyncNetVars()
end

hook.Add("EntityTakeDamage", "TTT_ImprovedMech_DamageHandler", function(target, dmginfo)
	if not IsValid(target) then return end

	if target:IsPlayer() and target:InVehicle() then
		-- Allow over-damage to the pilot if the flag is set
		if target.AllowMechOverdamage then
			return
		end

		local seat = target:GetVehicle()
		local mech = IsValid(seat) and seat.ParentMech or target:GetNWEntity("CombineMechEnt")

		-- Otherwise, don't
		if IsValid(mech) then
			dmginfo:SetDamage(0)
			dmginfo:ScaleDamage(0)
			return true
		end
	end

	-- Make sure damage to any other part of the mech is applied only to the parent
	local mech = target.ParentMech
	if IsValid(mech) then
		local currentFrame = FrameNumber()
		if mech.LastDamageFrame == currentFrame and mech.LastDamageAmount == dmginfo:GetDamage() then
			dmginfo:SetDamage(0)
			dmginfo:ScaleDamage(0)
			return true
		end

		mech.LastDamageFrame = currentFrame
		mech.LastDamageAmount = dmginfo:GetDamage()

		if target ~= mech then
			mech:TakeDamageInfo(dmginfo)
			dmginfo:SetDamage(0)
			dmginfo:ScaleDamage(0)
			return true
		end
	end
end)

-- Mech physics
function ENT:PhysicsUpdate(physics)
	if not IsValid(self.Mech) then return false end
	local curTime = CurTime()

	-- View toggle/mech exiting
	if IsValid(self.User) then
		if self.User:KeyDown(IN_ATTACK2) and self.ChangeViewCooldown < curTime then
			self.ChangeViewCooldown = curTime + 0.5

			local viewMode = nil

			if self.ChangeView then
				viewMode = 2
				self.User:SetNWInt("ControlsCombineMech", 2)
				self.ChangeView = false
			else
				viewMode = 1
				self.User:SetNWInt("ControlsCombineMech", 1)
				self.ChangeView = true
			end

			if viewMode then
				net.Start("TTT_ImprovedMech_Crosshair")
					net.WriteInt(viewMode, 8)
				net.Send(self.User)

				viewMode = nil
			end
		end

		if not self.User:InVehicle() or not self.User:Alive() or (self.EnterDel < curTime and self.User:KeyDown(IN_USE)) then
			self:RemoveUser()
		end
	end

	if self.MechHealth > 0 then
		if not IsValid(self.UserSeat) then return end

		self.UserSeat:SetPos(self:GetPos())
		self.UserSeat:SetAngles(Angle(0, 0, 0))

		-- Recharge shield
		if curTime >= self.NextShieldRecharge and self.Energy < self.MaxEnergy then
			local rate = GetConVar("ttt_improvedmech_shield_recharge_rate"):GetFloat()
			self.Energy = MathMin(self.Energy + (rate * FrameTime()), self.MaxEnergy)
		end

		-- Hover
		if (self.FootStatus > 0 or self.FlyHeight > 0) and (self.DotProd >= 0.7 or self.JetPlay) then
			self:Hover()
		end

		self:UpdateFootStatus()

		if self.UpdateShield < curTime then
			self:Shield()
		end

		if (self.FootStatus > 0 or self.FlyHeight > 0) and IsValid(self.KeepUpRightCon) then
			self:AutoMoveFeet()
			self:Stabilize()
			self:DirectHead()

			local physObj1 = self.Mech:GetPhysicsObjectNum(6)
			local physObj2 = self.Mech:GetPhysicsObjectNum(12)

			if IsValid(physObj1) then physObj1:ApplyForceCenter(Vector(0, 0, -50)) end
			if IsValid(physObj2) then physObj2:ApplyForceCenter(Vector(0, 0, -50)) end

			local vel = self:GetVelocity()
			vel   = vel * 0.5
			vel.z = vel.z * 0.5
			self:GetPhysicsObject():SetVelocity(vel)
		end

		-------------------------------------------
		-- Input stuff
		-------------------------------------------

		if IsValid(self.User) then
			local moves     = false
			local crouching = false
			local flying    = self.FlyHeight > 0

			-- Flashlight
			if IsValid(self.FlashLightEnt) and IsValid(self.KeepUpRightProp) then
				local plyViewAng = self.User:GetAimVector():Angle()
				self.FlashLightEnt:SetLocalAngles(Angle(plyViewAng.p, 0, 0))
			end

			-- Crouching
			if self.User:KeyDown(IN_DUCK) then
				self:SetHoverHeight(110 + self.FlyHeight)
				crouching = true
			else
				self:SetHoverHeight(130 + self.FlyHeight)
			end

			-- Movement (no movement while crouching because it breaks the legs)
			if not crouching then
				local forceMultiplier = flying and 1000 or 100
				local mechPhys = self.Mech:GetPhysicsObjectNum(0)

				if self.User:KeyDown(IN_FORWARD) then
					self.MoveOffsetX = 40
					moves = true
					if IsValid(mechPhys) then mechPhys:ApplyForceCenter(self:GetForward() * forceMultiplier) end
				elseif self.User:KeyDown(IN_BACK) then
					self.MoveOffsetX = -30
					moves = true
					if IsValid(mechPhys) then mechPhys:ApplyForceCenter(self:GetForward() * -forceMultiplier) end
				else
					self.MoveOffsetX = 0
				end

				if self.User:KeyDown(IN_MOVELEFT) then
					self.MoveOffsetY = -30
					moves = true
					if IsValid(mechPhys) then mechPhys:ApplyForceCenter(self:GetRight() * -forceMultiplier) end
				elseif self.User:KeyDown(IN_MOVERIGHT) then
					self.MoveOffsetY = 30
					moves = true
					if IsValid(mechPhys) then mechPhys:ApplyForceCenter(self:GetRight() * forceMultiplier) end
				else
					self.MoveOffsetY = 0
				end
			end

			-- Weapon selection
			if self.User:KeyDown(IN_SPEED) and self.ChangeWepDel < curTime then
				self.ChangeWepDel = curTime + 0.5
				self:SelectWeapon(self.WepType % self.MaxWeps + 1)
			end

			local wepState = self.WeaponStates[self.WepType]

			if wepState.isReloading and curTime >= wepState.reloadEndTime then
				self:FinishReload(self.WepType)
			end

			-- Manual reload
			if self.User:KeyDown(IN_RELOAD) and not wepState.isReloading then
				self:StartReload(self.WepType)
			end

			-- Grav probe movement stuff
			if self.GravProbeSpawned then
				-- Forget grav probe if it no longer exists
				if not IsValid(self.TempMissile) then
					self.GravProbeSpawned = false
				elseif self.WepType == 3 and self.User:KeyDown(IN_ATTACK) then
					local tr = util.TraceLine({
						start  = self.KeepUpRightProp:GetPos() + self.KeepUpRightProp:GetForward() * 50 + Vector(0, 0, -20),
						endpos = self.KeepUpRightProp:GetPos() + self.KeepUpRightProp:GetForward() * 50 + Vector(0, 0, -20) + (self.User:GetAimVector() * 400),
						filter = {self, self.Mech, self.KeepUpRightProp, self.MechUserEnt, self.TempMissile}
					})
					self.TempMissile.DestPos = tr.HitPos

					local probePhys = self.TempMissile:GetPhysicsObject()
					-- This code needs so many 'IsValid' checks dammit Jensson
					if IsValid(probePhys) then
						probePhys:SetVelocity(self.TempMissile:GetVelocity() * 0.9)
					end
				elseif not self.User:KeyDown(IN_ATTACK) or self.WepType ~= 3 then
					self:ReleaseGravProbe(4)
					self:EmitSound("weapons/physcannon/superphys_small_zap" .. MathRandom(1, 4) .. ".wav", 75, MathRandom(80, 120))

					-- Ammo removal/reload check is done on release for the grav probe
					wepState.clip = wepState.clip - 1
					if wepState.clip <= 0 then
						self:StartReload(3)
					end
				end
			end

			-- Attacking
			if self.User:KeyDown(IN_ATTACK) and (GetConVar("ttt_improvedmech_attack_while_flying"):GetBool() or self.FlyHeight <= 0) and IsValid(self.KeepUpRightCon) then
				if not wepState.isReloading and curTime >= wepState.nextFire then
					if wepState.clip > 0 then

						-- Turret
						if self.WepType == 1 then
							self:ShootBullet()
							wepState.clip 	  = wepState.clip - 1
							wepState.nextFire = curTime + self:GetWeaponStat(1, "firedelay")

							if wepState.clip <= 0 then self:StartReload(1) end

						-- Screamer
						elseif self.WepType == 2 and not self.ScreamerCharging then
							self.ScreamerCharging = true
							self.ScreamerFireTime = curTime + 2
							self:EmitSound("combine mech/ScreamerChargeUp.wav", 100, MathRandom(80, 120))

							wepState.clip = wepState.clip - 1
							wepState.nextFire = curTime + self:GetWeaponStat(2, "firedelay")

						-- Grav Probe
						elseif self.WepType == 3 and not self.GravProbeSpawned then
							self.GravProbeSpawned = true
							self:ShootGravProbe()

							self:EmitSound("weapons/physcannon/energy_sing_flyby" .. MathRandom(1, 2) .. ".wav", 75, MathRandom(80, 120))
							wepState.nextFire = curTime + self:GetWeaponStat(3, "firedelay")

						-- Grenade Launcher
						elseif self.WepType == 4 then
							self:ShootGrenade()
							wepState.clip 	  = wepState.clip - 1
							wepState.nextFire = curTime + self:GetWeaponStat(4, "firedelay")

							if wepState.clip <= 0 then self:StartReload(4) end

						-- Missile Launcher
						elseif self.WepType == 5 then
							self:ShootRocket()
							wepState.clip 	  = wepState.clip - 1
							wepState.nextFire = curTime + self:GetWeaponStat(5, "firedelay")

							if wepState.clip <= 0 then self:StartReload(5) end

						-- Missile Storm
						elseif self.WepType == 6 and self.StormMissilesLeft <= 0 then
							local tr = util.TraceLine({
								start  = self.KeepUpRightProp:GetPos() + self.KeepUpRightProp:GetForward() * 50 + Vector(0, 0, -20),
								endpos = self.KeepUpRightProp:GetPos() + self.KeepUpRightProp:GetForward() * 50 + Vector(0, 0, -20) + (self.User:GetAimVector() * 4000),
								filter = {self, self.Mech, self.KeepUpRightProp, self.MechUserEnt}
							})
							self.StormTargetPos = tr.HitPos

							self.StormMissilesLeft = wepState.clip
							wepState.clip = 0

							-- Reload starts after missile storm finishes
							wepState.nextFire = curTime + self:GetWeaponStat(6, "firedelay")
						end
					else
						-- Firing while empty triggers a reload
						self:StartReload(self.WepType)
					end
				end
			end

			-- Screamer charging delay
			if self.ScreamerCharging and curTime >= self.ScreamerFireTime then
				self:ShootScreamer()
				self.ScreamerCharging = false

				if self.WeaponStates[2].clip <= 0 then
					self:StartReload(2)
				end
			end

			-- Missile storm burst
			if self.StormMissilesLeft > 0 and curTime >= self.NextMissileStormTime then
				self:ShootMissileStorm(self.StormTargetPos)
				self.StormMissilesLeft = self.StormMissilesLeft - 1
				self.NextMissileStormTime = curTime + 0.1

				if self.StormMissilesLeft <= 0 then
					self:StartReload(6)
				end
			end

			-- If moving/flying, make the pelvis face the view direction
			if moves or flying then
				self:DirectMech()
			end
		else
			self:SetHoverHeight(130 + self.FlyHeight)

			-- Launch the grav prob on release of the fire button
			if self.GravProbeSpawned then
				self:ReleaseGravProbe(2)
			end
		end

		-- Send up to date mech stuff to client
		self:SyncNetVars()

		-- Jet effect stuff
		if self.FlyHeight > 0 then
			self.JetTimer = curTime + 1

			if not self.JetPlay then
				self.JetPlay = true
				self.JetSound:Play()
			end

			-- Change jet sound pitch depending on height
			local pitch = 50 + ((self.FlyHeight / 1000) * 150)
			self.JetSound:ChangePitch(pitch, 0)

			local ang = self:GetAngles()

			local effectdata = EffectData()
			effectdata:SetOrigin(self.Mech:GetPos() + self:GetForward() * -11.5 + self:GetUp() * -10)
			effectdata:SetAngles(ang)
			effectdata:SetScale(1)
			util.Effect("MuzzleEffect", effectdata)

			local effectdata2 = EffectData()
			effectdata2:SetOrigin(self.Mech:GetPos() + self:GetForward() * -30 + self:GetUp() * -2)
			effectdata2:SetAngles(ang)
			effectdata2:SetScale(1)
			util.Effect("MuzzleEffect", effectdata2)
		else
			-- Stop the jet sound if we aren't flying
			self.JetPlay = false
			self.JetSound:Stop()
		end

		-- Stompy sounds
		if (self.LastFootStatus == 2 or self.LastFootStatus == 1) and (self.FootStatus == 3 or self.FootStatus == 0) and self.DotProd >= 0.7 then
			self:EmitSound("npc/dog/dog_footstep_run" .. MathRandom(1, 8) .. ".wav", 75, MathRandom(80, 120))
		end

		self.LastFootStatus = self.FootStatus
	end
end

-------------------------------------------
-- Think stuff
-------------------------------------------

function ENT:Think()
	-- If there's no mech ragdoll then get rid of the main entity
	if not IsValid(self.Mech) then
		self:Remove()
		return
	end

	-- PrintMessage(HUD_PRINTTALK, "self.FlyHeight = " .. tostring(self.FlyHeight) .. " | GetAngles = " .. tostring(self.KeepUpRightProp:GetAngles()))

	local curTime = CurTime()

	-- Damage the mech if it's in water
	if self:WaterLevel() >= 1 then
		self.MechHealth = self.MechHealth - 1
	end

	if self.MechHealth > 0 then
		self:GetPhysicsObject():Wake()

		-- Jet smoke
		self:SetIsFlying(self.FlyHeight > 0)

		if not IsValid(self.User) then
			self.ScreamerCharging = false

			if IsValid(self.FlashLightEnt) then
				self.FlashLightEnt:Remove()
				self.FlashLightEnt = nil
				if IsValid(self.LeftFlashSprite) then self.LeftFlashSprite:Remove() end
				if IsValid(self.RightFlashSprite) then self.RightFlashSprite:Remove() end
			end

			if self.MechHealth < self.MechMaxHealth and self.MechHealth > 0 then
				self.MechHealth = self.MechHealth + 0.2
				local percent = self.MechHealth / self.MechMaxHealth

				if self.DamageLevel == 4 and percent > 0.1 then
					self.DamageLevel = 3
					self:UpdateSmoke(10, 10, 10, 170)
				elseif self.DamageLevel == 3 and percent > 0.25 then
					self.DamageLevel = 2
					self:UpdateSmoke(100, 100, 100, 170)
				elseif self.DamageLevel == 2 and percent > 0.5 then
					self.DamageLevel = 1
					self:UpdateSmoke(200, 200, 200, 170)
				elseif self.DamageLevel == 1 and percent > 0.75 then
					self.DamageLevel = 0
					if IsValid(self.SmokeEffect) then self.SmokeEffect:Remove() end
				end
			end
		end

		-- Make NPCs attack the mech
		if IsValid(self.NPCTarget) and self.UpdateMechAsTargetDel < curTime then
			self.UpdateMechAsTargetDel = curTime + 2
			for _, v in pairs(ents.FindByClass("npc_*")) do
				local class = v:GetClass()
				if string.find(class, "npc_antlionguard") or string.find(class, "npc_combine*") or string.find(class, "*zombie*") or string.find(class, "npc_helicopter") or string.find(class, "npc_manhack") or string.find(class, "npc_metropolice") or string.find(class, "npc_rollermine") or string.find(class, "npc_strider") or string.find(class, "npc_turret*") or string.find(class, "npc_hunter") or string.find(class, "antlion") then
					v:Fire("setrelationship", "npc_bullseye D_HT 5")
				end
			end
		end

		-- Set shield sphere color/transparency
		if IsValid(self.ShieldSphere) then
			if self.Energy > 0 then
				self.ShieldSphere:SetNoDraw(false)

				local energyPercentage = MathClamp(self.Energy / self.MaxEnergy, 0, 1)

				local rColour = 255 - 135 * energyPercentage
				local gColour = 200 * energyPercentage
				local bColour = 255 * energyPercentage

				self.ShieldSphere:SetColor(Color(rColour, gColour, bColour, 50))
			else
				self.ShieldSphere:SetNoDraw(true)
			end
		end

		self.DotProd = self:GetUp():Dot(Vector(0, 0, 1))
		self:Steady()

		-- Play sound when broken shield starts restoring
		if self.ShieldDown and self.Energy > 0 then
			self.ShieldDown = false
			self:EmitSound("combine mech/ShieldUp.wav", 85, MathRandom(80, 120))
		end
	else
		-- When the mech dies
		self.Energy = 0
		self.JetSound:Stop()

		self:SetIsFlying(false)

		if IsValid(self.KeepUpRightCon) then
			self.KeepUpRightCon:Remove()
			self.KeepUpRightCon = nil
		end

		if IsValid(self.UserSeat) then
			self.UserSeat:Remove()
			self.UserSeat = nil
		end

		-- Make NPCs stop shooting at it
		if IsValid(self.NPCTarget) then self.NPCTarget:Remove() self.NPCTarget = nil end
		if IsValid(self.NPCTarget2) then self.NPCTarget2:Remove() self.NPCTarget2 = nil end

		-- Remove the shield sphere
		if IsValid(self.ShieldSphere) then self.ShieldSphere:Remove() self.ShieldSphere = nil end

		-- Send health/shield 0 to client
		self:SyncNetVars()
	end

	-- Health visual effects
	local percent = self.MechHealth / self.MechMaxHealth
	if self.DamageLevel == 0 and percent < 0.75 then
		self.DamageLevel = 1
		self:UpdateSmoke(200, 200, 200, 170)
	elseif self.DamageLevel == 1 and percent < 0.5 then
		self.DamageLevel = 2
		self:UpdateSmoke(100, 100, 100, 170)
	elseif self.DamageLevel == 2 and percent < 0.25 then
		self.DamageLevel = 3
		self:UpdateSmoke(10, 10, 10, 170)
	elseif self.DamageLevel == 3 and percent < 0.1 then
		self.DamageLevel = 4
		if IsValid(self.SmokeEffect) then self.SmokeEffect:Remove() end

		local pos = self.KeepUpRightProp:GetForward() * -60 + self.KeepUpRightProp:GetUp() * 20
		self.SmokeEffect = ents.Create("env_fire_trail")
		self.SmokeEffect:SetPos(self.KeepUpRightProp:GetPos() + pos)
		self.SmokeEffect:Spawn()
		self.SmokeEffect:SetParent(self.KeepUpRightProp)
	end

	if percent < 0.75 and percent > 0 then
		local maxPer = (percent * 100) / 2
		if MathRandom(0, maxPer) == 1 then
			local bonepos1, _ = self.Mech:GetBonePosition(self.Mech:TranslatePhysBoneToBone(MathRandom(0, 15)))
			local effectdata  = EffectData()
			effectdata:SetStart(bonepos1)
			effectdata:SetOrigin(bonepos1)
			effectdata:SetScale(1)
			util.Effect("StunstickImpact", effectdata)
			self:EmitSound("ambient/energy/zap" .. MathRandom(1, 9) .. ".wav", 75, MathRandom(80, 120))
		end
	end
end

function ENT:OnRemove()
	if IsValid(self.User) then
		net.Start("TTT_ImprovedMech_Crosshair")
			net.WriteInt(0, 8)
		net.Send(self.User)
	end
	if IsValid(self.Mech) then self.Mech:Remove() end
	if IsValid(self.UserSeat) then self.UserSeat:Remove() end
	if IsValid(self.KeepUpRightProp) then self.KeepUpRightProp:Remove() end
	if IsValid(self.MechUserEnt) then self.MechUserEnt:Remove() end
	if IsValid(self.NPCTarget) then self.NPCTarget:Remove() end
	if IsValid(self.NPCTarget2) then self.NPCTarget2:Remove() end
	if self.JetSound then self.JetSound:Stop() end
end

function ENT:UpdateSmoke(r, g, b, a)
	if IsValid(self.SmokeEffect) then self.SmokeEffect:Remove() end
	if not IsValid(self.KeepUpRightProp) then return end

	local pos = self.KeepUpRightProp:GetForward() * -60 + self.KeepUpRightProp:GetUp() * 20
	self.SmokeEffect = ents.Create("env_smokestack")
	self.SmokeEffect:SetPos(self.KeepUpRightProp:GetPos() + pos)
	self.SmokeEffect:SetKeyValue("InitialState", "1")
	self.SmokeEffect:SetKeyValue("WindAngle", "0 0 0")
	self.SmokeEffect:SetKeyValue("WindSpeed", "0")
	self.SmokeEffect:SetKeyValue("rendercolor", string.format("%d %d %d", r, g, b))
	self.SmokeEffect:SetKeyValue("renderamt", tostring(a))
	self.SmokeEffect:SetKeyValue("SmokeMaterial", "particle/smokesprites_0001.vmt")
	self.SmokeEffect:SetKeyValue("BaseSpread", "10")
	self.SmokeEffect:SetKeyValue("SpreadSpeed", "5")
	self.SmokeEffect:SetKeyValue("Speed", "100")
	self.SmokeEffect:SetKeyValue("StartSize", "50")
	self.SmokeEffect:SetKeyValue("EndSize", "10")
	self.SmokeEffect:SetKeyValue("roll", "10")
	self.SmokeEffect:SetKeyValue("Rate", "10")
	self.SmokeEffect:SetKeyValue("JetLength", "50")
	self.SmokeEffect:SetKeyValue("twist", "5")

	self.SmokeEffect:Spawn()
	self.SmokeEffect:SetParent(self)
	self.SmokeEffect:Activate()
end

function ENT:SetHoverHeight(newHeight)
	self.HoverHeight = newHeight
end

function ENT:SetHoverMultiplier(newMP)
	self.HoverMultiplier = newMP
end

function ENT:SetUser(ply)
	if IsValid(self.User) then return end
	if CurTime() < (self.EnterDel or 0) then return end
	self.EnterDel = CurTime() + 1

	self.AntennaLight:SetKeyValue("renderamt", "255")
	self.EntryButtonLight:SetKeyValue("renderamt", "0")

	net.Start("TTT_ImprovedMech_Crosshair")
		net.WriteInt(2, 8)
	net.Send(ply)

	self.User = ply
	self.User:EnterVehicle(self.UserSeat)
	self.User:SetColor(Color(255, 255, 255, 0))

	local mechAngles = self:GetAngles()
	self.User:SetEyeAngles(Angle(0, mechAngles.yaw, 0))

	self.ChangeView = false
	self.User:SetNWInt("ControlsCombineMech", 2)
	self.User:SetNWEntity("CombineMechEnt", self)
	self.User:SetNWEntity("CombineMechSawEnt", self.KeepUpRightProp)
	self:SyncNetVars()

	net.Start("TTT_ImprovedMech_ForceView")
		net.WriteEntity(self)
		net.WriteInt(2, 8)
		net.WriteEntity(self.KeepUpRightProp)
	net.Send(ply)

	if not IsValid(self.NPCTarget) then
		self.NPCTarget = ents.Create("npc_bullseye")
		self.NPCTarget:SetPos(self.KeepUpRightProp:GetPos() + self.KeepUpRightProp:GetForward() * 50 + self.KeepUpRightProp:GetUp() * -20)
		self.NPCTarget:SetParent(self.KeepUpRightProp)
		self.NPCTarget:SetKeyValue("health", "9999")
		self.NPCTarget:SetKeyValue("spawnflags", "256")
		self.NPCTarget:SetNotSolid(true)
		self.NPCTarget:Spawn()
		self.NPCTarget:Activate()

		self.NPCTarget2 = ents.Create("npc_bullseye")
		self.NPCTarget2:SetPos(self.KeepUpRightProp:GetPos() + self.KeepUpRightProp:GetForward() * -20)
		self.NPCTarget2:SetParent(self.KeepUpRightProp)
		self.NPCTarget2:SetKeyValue("health", "9999")
		self.NPCTarget2:SetKeyValue("spawnflags", "256")
		self.NPCTarget2:SetNotSolid(true)
		self.NPCTarget2:Spawn()
		self.NPCTarget2:Activate()
	end
end

-- Don't let the mech have two pilots
function ENT:EnterMech(ply)
	if not IsValid(self.User) then
		self:SetUser(ply)

		self.AntennaLight:SetKeyValue("renderamt", "255")
		self.EntryButtonLight:SetKeyValue("renderamt", "0")

		return true
	end

	return false
end

function ENT:RemoveUser()
	if IsValid(self.User) then
		self.AntennaLight:SetKeyValue("renderamt", "0")
		self.EntryButtonLight:SetKeyValue("renderamt", "255")

		net.Start("TTT_ImprovedMech_Crosshair")
			net.WriteInt(0, 8)
		net.Send(self.User)

		self.User:ExitVehicle()
		self.User:SetColor(Color(255, 255, 255, 255))
		self.User:SetPos(self:GetPos() + self:GetForward() * 70 + self:GetUp() * -80)
		self.User:SetNWInt("ControlsCombineMech", 0)
		self.User = nil
	end
end

function ENT:Hover()
	if not IsValid(self.Mech) then return false end

	-- Get the distance between the mech and the ground
	local tr = util.TraceLine({
		start  = self.Mech:GetPos(),
		endpos = self.Mech:GetPos() + Vector(0, 0, self.HoverHeight * -1),
		filter = {self, self.Mech, self.KeepUpRightProp, self.MechUserEnt}
	})

	if tr.Hit then
		local distance = self.Mech:GetPos():Distance(tr.HitPos)
		local force    = (self.HoverHeight - distance) * self.HoverMultiplier

		-- Max thrust is 50
		force = MathMin(force, 50)

		local climbRate   = 3
		local descentRate = 5

		local maxMeters = GetConVar("ttt_improvedmech_altitude_max"):GetInt()
		local maxUnits  = MathMax(maxMeters / 0.01905)

		if IsValid(self.User) and self.User:KeyDown(IN_JUMP) then
			self.FlyHeight = MathMin(self.FlyHeight + climbRate, maxUnits)
		else
			self.FlyHeight = MathMax(0, self.FlyHeight - descentRate)
		end

		-- Apply the force
		self.Mech:GetPhysicsObjectNum(0):ApplyForceCenter(Vector(0, 0, 50) * force)
	end
end

-- Check if there is something under the feet
function ENT:UpdateFootStatus()
	if not IsValid(self.Mech) then return false end

	-- 0 None of the legs are touching the ground
	-- 1 Only left foot
	-- 2 Only right foot
	-- 3 Both are touching the ground

	self.FootStatus = 0
	local bonepos1, _ = self.Mech:GetBonePosition(self.Mech:TranslatePhysBoneToBone(6))
	local bonepos2, _ = self.Mech:GetBonePosition(self.Mech:TranslatePhysBoneToBone(12))

	local tr1 = util.TraceLine({
		start  = bonepos1,
		endpos = bonepos1 + Vector(0, 0, -30),
		filter = {self, self.Mech, self.KeepUpRightProp, self.MechUserEnt}
	})

	if tr1.Hit then
		self.FootStatus = 1
	end

	local tr2 = util.TraceLine({
		start  = bonepos2,
		endpos = bonepos2 + Vector(0, 0, -30),
		filter = {self, self.Mech, self.KeepUpRightProp, self.MechUserEnt}
	})

	if tr2.Hit and self.FootStatus == 1 then
		self.FootStatus = 3
	elseif tr2.Hit then
		self.FootStatus = 2
	end
end

-- Automatically moves the feet so they don't stretch out too much
-- This function really needs to be improved, i just don't know how to make the movement better without animations
function ENT:AutoMoveFeet()
	if not IsValid(self.Mech) then return false end

	local curTime = CurTime()
	local offset  = Vector(self.MoveOffsetX, self.MoveOffsetY, 0)
	if not IsValid(self.User) then offset = Vector(0, 0, 0) end

	local vecHeight = self.HoverHeight ~= 130 and Vector(0, 0, -110) or Vector(0, 0, -140)

	-- Left side
	local checkPosLeft = self:GetPos() + (self:GetRight() * -60) + (self:GetForward() * offset.x) + (self:GetRight() * offset.y) + vecHeight
	local bonepos1     = self.Mech:GetBonePosition(self.Mech:TranslatePhysBoneToBone(6))
	self.LeftMoveDist  = bonepos1:Distance(checkPosLeft)
	self.LeftMoveDir   = (checkPosLeft - bonepos1):GetNormalized()
	self.LeftMoveDir.z = 0

	-- Right side
	local checkPosRight = self:GetPos() + (self:GetRight() * 60) + (self:GetForward() * offset.x) + (self:GetRight() * offset.y) + vecHeight
	local bonepos2      = self.Mech:GetBonePosition(self.Mech:TranslatePhysBoneToBone(12))
	self.RightMoveDist  = bonepos2:Distance(checkPosRight)
	self.RightMoveDir   = (checkPosRight - bonepos2):GetNormalized()
	self.RightMoveDir.z = 0

	if self.FootStatus > 0 then
		-- Left foot
		if (self.FootStatus == 3 or self.FootStatus == 1) and self.DontMoveLeftDel < curTime and self.LeftMoveDist > 20 then
			self.MoveLeftDel = curTime + 0.4
		end

		-- Right foot
		if (self.FootStatus == 3 or self.FootStatus == 2) and self.DontMoveRightDel < curTime and self.RightMoveDist > 20 then
			self.MoveRightDel = curTime + 0.4
		end
	end

	-- Should we move the left or the right foot?
	if self.MoveLeftDel > curTime and self.MoveRightDel > curTime then
		if self.RightMoveDist < self.LeftMoveDist then
			self.MoveRightDel 	  = curTime
			self.DontMoveRightDel = curTime
		else
			self.MoveLeftDel 	 = curTime
			self.DontMoveLeftDel = curTime
		end
	end

	-- Moving right foot
	if self.MoveLeftDel > curTime and (self.FootStatus == 2 or self.FootStatus == 3) then
		if self.DontMoveLeftDel <= curTime then
			local vel = MathMin(self.LeftMoveDist, 150)
			self:EmitSound("combine mech/servoMove.mp3", vel * 0.5 + 50, 200 - vel)
		end

		self.DontMoveLeftDel = curTime + 1

		local physObj = self.Mech:GetPhysicsObjectNum(6)
		local vel = self:GetVelocity()

		if IsValid(physObj) then
			physObj:ApplyForceCenter(Vector(0, 0, 50 + self.LeftMoveDist * 1.3) + (self.LeftMoveDir * self.LeftMoveDist * 1.2) + vel)
		end
	end

	-- Moving left foot
	if self.MoveRightDel > curTime and (self.FootStatus == 1 or self.FootStatus == 3) then
		if self.DontMoveRightDel <= curTime then
			local vel = MathMin(self.RightMoveDist, 150)
			self:EmitSound("combine mech/servoMove.mp3", vel * 0.5 + 50, 200 - vel)
		end

		self.DontMoveRightDel = curTime + 1

		local physObj = self.Mech:GetPhysicsObjectNum(12)
		local vel = self:GetVelocity()

		if IsValid(physObj) then
			physObj:ApplyForceCenter(Vector(0, 0, 50 + self.RightMoveDist * 1.3) + (self.RightMoveDir * self.RightMoveDist * 1.2) + vel)
		end
	end
end

-- This function manages the keepUpRight constraint
-- it also disables and enables gravity on the mechs legs
function ENT:Steady()
	if not IsValid(self.Mech) then return false end

	local bonepos1 = self.Mech:GetBonePosition(self.Mech:TranslatePhysBoneToBone(6))
	local bonepos2 = self.Mech:GetBonePosition(self.Mech:TranslatePhysBoneToBone(12))
	local entPos   = self:GetPos()
	local badLeg   = bonepos1.z > entPos.z or bonepos2.z > entPos.z

	if not IsValid(self.KeepUpRightCon) and (self.FootStatus > 0 or self.FlyHeight > 0 or self.JetPlay) and not badLeg and (self.DotProd >= 0.7 or self.JetPlay) and (self:WaterLevel() == 0 or self.FlyHeight > 0) then
		self.KeepUpRightCon = constraint.Keepupright(self.KeepUpRightProp, self.StabAng, 0, 100000000)
		self.Mech:GetPhysicsObjectNum(3):EnableGravity(false)
		self.Mech:GetPhysicsObjectNum(4):EnableGravity(false)
		self.Mech:GetPhysicsObjectNum(9):EnableGravity(false)
		self.Mech:GetPhysicsObjectNum(10):EnableGravity(false)
	elseif IsValid(self.KeepUpRightCon) and (self.FootStatus == 0 or badLeg or self:WaterLevel() >= 1) and self.FlyHeight == 0 and self.JetTimer < CurTime() then
		-- self.KeepUpRightCon:Remove()
		-- self.KeepUpRightCon = nil
		self.Mech:GetPhysicsObjectNum(3):EnableGravity(true)
		self.Mech:GetPhysicsObjectNum(4):EnableGravity(true)
		self.Mech:GetPhysicsObjectNum(9):EnableGravity(true)
		self.Mech:GetPhysicsObjectNum(10):EnableGravity(true)
	end
end

-- Move the mech pelvis between the legs
function ENT:Stabilize()
	if not IsValid(self.Mech) then return false end
	local bonepos1 = self.Mech:GetBonePosition(self.Mech:TranslatePhysBoneToBone(6))
	local bonepos2 = self.Mech:GetBonePosition(self.Mech:TranslatePhysBoneToBone(12))
	local pos = (bonepos1 + bonepos2) / 2
	local dir = (pos - self:GetPos()):GetNormalized()
	dir.z = 0
	self:GetPhysicsObject():ApplyForceCenter(dir * 5000)
end

-- Aim the mech pelvis towards the player's aim direction
function ENT:DirectMech()
	if IsValid(self.User) and self.User:InVehicle() then
		if not IsValid(self.Mech) then return false end

		-- Smooth out the movement
		local angVel = self.Mech:GetPhysicsObjectNum(1):GetAngleVelocity() * -0.5
		self.Mech:GetPhysicsObjectNum(1):AddAngleVelocity(angVel)

		local destPos = self:GetPos() + self.User:GetAimVector() * 500
		local lDist   = (self:GetPos() + self:GetRight() * -50):Distance(destPos)
		local rDist   = (self:GetPos() + self:GetRight() * 50):Distance(destPos)
		local force   = MathAbs(lDist - rDist)

		if lDist > rDist then
			self.Mech:GetPhysicsObjectNum(0):AddAngleVelocity(Vector(0, 1, 0) * force)
		else
			self.Mech:GetPhysicsObjectNum(0):AddAngleVelocity(Vector(0, -1, 0) * force)
		end
	end
end

-- Aim the mech head towards the player's aim direction
function ENT:DirectHead()
	if IsValid(self.User) and self.User:InVehicle() then
		if not IsValid(self.Mech) then return false end

		-- Smooth out the movement
		local angVel = self.Mech:GetPhysicsObjectNum(1):GetAngleVelocity() * -0.5
		self.Mech:GetPhysicsObjectNum(1):AddAngleVelocity(angVel)

		local destPos = self:GetPos() + self.User:GetAimVector() * 500
		local lDist = (self.KeepUpRightProp:GetPos() + self.KeepUpRightProp:GetRight() * -50):Distance(destPos)
		local rDist = (self.KeepUpRightProp:GetPos() + self.KeepUpRightProp:GetRight() * 50):Distance(destPos)
		local force = MathAbs(lDist - rDist) * 2

		if lDist > rDist then
			self.Mech:GetPhysicsObjectNum(1):AddAngleVelocity(Vector(0, 1, 0) * force)
		else
			self.Mech:GetPhysicsObjectNum(1):AddAngleVelocity(Vector(0, -1, 0) * force)
		end
	end
end

-- Check whether the entity is part of the mech
function ENT:IsMechPart(v)
	if v == self or v == self.Mech or v == self.KeepUpRightProp or v == self.MechUserEnt or v == self.UserSeat or v == self.TempMissile or v == self.ShieldSphere or v == self.NPCTarget or v == self.NPCTarget2 then
		return true
	end

	if v.IsMechProp then return true end

	-- Check the parent if we get this far
	local parent = v:GetParent()
	if IsValid(parent) and parent ~= v then
		return self:IsMechPart(parent)
	end

	return false
end

-- All shield thingys happens here
function ENT:Shield()
	-- Energy must be above 0
	if self.Energy <= 0 or not IsValid(self.Mech) then return end

	-- Getting all ents
	for _, v in pairs(ents.FindInSphere(self:GetPos(), 150)) do
		-- These things are hidden in the player
		-- We don't want the shield to react to them
		if IsValid(v) and not v:IsPlayer() and not v:IsWeapon() and not string.find(v:GetClass(), "predicted_viewmodel") and not string.find(v:GetClass(), "physgun_beam") then
			-- The shield should ignore its own parts
			if not self:IsMechPart(v) then
				local vel = v:GetVelocity():Length()
				local dir1 = v:GetVelocity():GetNormalized()
				local dir = (v:GetPos() - self:GetPos()):GetNormalized()
				local dot = dir:Dot(dir1)

				if dot < 0 and vel > 500 then
					-- Some ents that aren't phys objects needs to be handled separately
					if v:GetClass() == "rpg_missile" then
						self.Energy = self.Energy - 20
						v:SetLocalVelocity(dir * vel * 1000 + Vector(0, 0, 10000))
						v:SetAngles(dir:Angle())
						v:SetHealth(0)

						local bul = {
							Num    = 1,
							Src    = v:GetPos(),
							Dir    = Vector(0, 0, 0),
							Spread = Vector(0, 0, 0),
							Tracer = 0,
							Force  = 1,
							Damage = 100
						}
						self:FireBullets(bul)
					elseif v:GetClass() == "crossbow_bolt" or v:GetClass() == "hunter_flechette" or v:GetClass() == "grenade_spit" then
						self.Energy = self.Energy - (v:GetClass() == "crossbow_bolt" and 10 or 3)
						v:SetLocalVelocity(dir * (v:GetClass() == "grenade_spit" and vel or (vel * 1000)))
					elseif v:GetClass() == "grenade_ar2" then
						self.Energy = self.Energy - 5

						v:SetLocalVelocity(dir * vel)
					elseif string.find(v:GetClass(), "missile") then
						v:SetAngles(dir:Angle())
						v.MissileTime = 0

						local phys = v:GetPhysicsObject()
						if IsValid(phys) then phys:SetVelocity(dir * vel * 0.5) end

						self.Energy = self.Energy - 10
					else
						local phys = v:GetPhysicsObject()

						if IsValid(phys) then
							phys:SetVelocity(dir * vel)
							self.Energy = self.Energy - (phys:GetMass() / 5)
						end
					end

					-- The shield effect and sound, now not running every tick and breaking shit
					if self.ShieldEffDel < CurTime() then
						self.ShieldEffDel = CurTime() + 0.15
						local minimum, maximum = v:WorldSpaceAABB()

						local effectdata = EffectData()
						effectdata:SetOrigin(v:GetPos())
						effectdata:SetEntity(self)
						effectdata:SetScale(minimum:Distance(maximum))
						util.Effect("mech_shieldEffect", effectdata)

						self:EmitSound("combine mech/shieldHit.mp3", 85, MathRandom(80, 120))
					end

					-- Shield down
					if self.Energy <= 0 then
						self.Energy = -50
						self:EmitSound("combine mech/ShieldDown.wav", 85, MathRandom(80, 120))
						self.ShieldDown = true

						local effectdata = EffectData()
						effectdata:SetStart(self:GetPos())
						effectdata:SetOrigin(self:GetPos())
						effectdata:SetScale(1)
						util.Effect("cball_explode", effectdata)
					end
				end
			end
		end
	end
end

-------------------------------------------
-- Weapon bits
-------------------------------------------

function ENT:ShootBullet()
	if not IsValid(self.User) or not IsValid(self.KeepUpRightProp) then return end

	local muzzlePos = self.KeepUpRightProp:GetPos() + self.KeepUpRightProp:GetForward() * 50 + Vector(0, 0, -20)

	local ply = self.User
	local aimDirection = ply:GetAimVector()

	if self.ChangeView == true then
		local angles = ply:EyeAngles()

		local cameraPos = self:GetPos() + (angles:Forward() * -300) + (angles:Up() * 75)

		local cameraTrace = {
			start = self:GetPos() + (angles:Forward() * -100),
			endpos = cameraPos,
			filter = {ply, self, self.KeepUpRightProp}
		}

		local cameraResult = util.TraceLine(cameraTrace)

		if cameraResult.Hit then
			cameraPos = cameraResult.HitPos
		end

		local aimTrace = {
			start = cameraPos,
			endpos = cameraPos + angles:Forward() * 100000,
			filter = {ply, self, self.KeepUpRightProp}
		}

		local aimResult = util.TraceLine(aimTrace)
		local aimPoint = aimResult.HitPos

		aimDirection = (aimPoint - muzzlePos):GetNormalized()
	end

	self:EmitSound("weapons/ar1/ar1_dist" .. MathRandom(1, 2) .. ".wav", 75, MathRandom(80, 120))

	-- Muzzle flash
	local effectdata = EffectData()
	effectdata:SetOrigin(muzzlePos)
	effectdata:SetAngles(ply:GetAimVector():Angle())
	effectdata:SetScale(1)
	util.Effect("MuzzleEffect", effectdata)

	local bullet = {
		Num        = 1,
		Src        = muzzlePos,
		Dir        = aimDirection,
		Spread     = Vector(0.03, 0.03, 0),
		Tracer     = 1,
		TracerName = "Tracer",
		Force      = 0,
		Damage     = 5,
		Attacker   = ply
	}

	self:FireBullets(bullet)
end

function ENT:ShootScreamer()
	if not IsValid(self.User) then return end

	local tr = util.TraceLine({
		start  = self.KeepUpRightProp:GetPos() + self.KeepUpRightProp:GetForward() * 50 + Vector(0, 0, -20),
		endpos = self.KeepUpRightProp:GetPos() + self.KeepUpRightProp:GetForward() * 50 + Vector(0, 0, -20) + (self.User:GetAimVector() * 999999),
		filter = {self, self.Mech, self.KeepUpRightProp, self.MechUserEnt}
	})

	local bomb = ents.Create("sent_mechscreamerbombTTT")
	if not IsValid(bomb) then return end

	bomb:SetPos(self.KeepUpRightProp:GetPos() + self.KeepUpRightProp:GetUp() * 30 + self.KeepUpRightProp:GetForward() * -20)
	bomb:SetAngles(self.KeepUpRightProp:GetAngles())
	bomb.FollowPos 	 = tr.HitPos
	bomb.target 	 = tr.HitNonWorld and tr.Entity or nil
	bomb.ActivateDel = CurTime() + 0.2
	bomb:Spawn()
	bomb:Activate()

	local bombPhys = bomb:GetPhysicsObject()
	if IsValid(bombPhys) then
		bombPhys:Wake()
		bombPhys:ApplyForceCenter(Vector(0, 0, 1000))
	end
end

function ENT:ShootGravProbe()
	if not IsValid(self.User) then return end

	local tr = util.TraceLine({
		start  = self.KeepUpRightProp:GetPos() + self.KeepUpRightProp:GetForward() * 50 + Vector(0, 0, -20),
		endpos = self.KeepUpRightProp:GetPos() + self.KeepUpRightProp:GetForward() * 50 + Vector(0, 0, -20) + (self.User:GetAimVector() * 400),
		filter = {self, self.Mech, self.KeepUpRightProp, self.MechUserEnt}
	})

	local grav = ents.Create("sent_mechgravprobeTTT")
	if not IsValid(grav) then
		self.GravProbeSpawned = false
		return
	end

	grav:SetPos(tr.HitPos)
	grav:SetAngles(self.KeepUpRightProp:GetAngles())
	grav.FollowPos = self.KeepUpRightProp:GetPos() + self.KeepUpRightProp:GetForward() * 50 + Vector(0, 0, -20) + self.User:GetAimVector() * 400
	grav.ignoreProps = {self:EntIndex(), self.Mech:EntIndex(), self.KeepUpRightProp:EntIndex()}
	grav.ArmTime = nil
	grav:Spawn()
	grav:Activate()

	if IsValid(grav:GetPhysicsObject()) then grav:GetPhysicsObject():Wake() end
	self.TempMissile = grav
end

function ENT:ReleaseGravProbe(delay)
	self.GravProbeSpawned = false
	local probe = self.TempMissile

	if not IsValid(probe) then
		self.TempMissile = nil
		return
	end

	probe.DestPos = nil
	probe.ArmTime = CurTime() + 2

	local phys = probe:GetPhysicsObject()
	if IsValid(phys) then
		local dir = IsValid(self.User) and self.User:GetAimVector() or self:GetForward()
		phys:ApplyForceCenter(dir * 1000)
	end
end

function ENT:ShootGrenade()
	self:EmitSound("weapons/ar2/ar2_altfire.wav", 75, MathRandom(80, 120))

	local gren = ents.Create("sent_mechgrenadeTTT")
	gren:SetPos(self.KeepUpRightProp:GetPos() + self.KeepUpRightProp:GetRight() * 40 + self.KeepUpRightProp:GetUp() * 10)
	gren:SetAngles(self.KeepUpRightProp:GetAngles())
	gren:Spawn()
	gren:Activate()

	local phys = gren:GetPhysicsObject()
	if IsValid(phys) then
		phys:Wake()
		phys:ApplyForceCenter(self.User:GetAimVector() * 1000)
	end

	self.TempMissile = gren
	constraint.NoCollide(gren, self.Mech, 0, 0)
	constraint.NoCollide(gren, self.KeepUpRightProp, 0, 0)
	constraint.NoCollide(gren, self, 0, 0)
end

function ENT:ShootRocket()
	self:EmitSound("weapons/stinger_fire1.wav", 75, MathRandom(80, 120))

	local tr = util.TraceLine({
		start  = self.KeepUpRightProp:GetPos() + self.KeepUpRightProp:GetForward() * 50 + Vector(0, 0, -20),
		endpos = self.KeepUpRightProp:GetPos() + self.KeepUpRightProp:GetForward() * 50 + Vector(0, 0, -20) + (self.User:GetAimVector() * 4000),
		filter = {self, self.Mech, self.KeepUpRightProp, self.MechUserEnt}
	})

	local missile = ents.Create("sent_mechmissileTTT")
	missile:SetPos(self.KeepUpRightProp:GetPos() + self.KeepUpRightProp:GetRight() * -40 + self.KeepUpRightProp:GetUp() * 10)
	missile:SetAngles(self.KeepUpRightProp:GetAngles())
	missile.FollowPos 	= tr.HitPos
	missile.ActivateDel = 0
	missile.angchange 	= 5
	missile:Spawn()
	missile:Activate()
	if IsValid(missile:GetPhysicsObject()) then missile:GetPhysicsObject():Wake() end

	self.TempMissile = missile
	constraint.NoCollide(missile, self.Mech, 0, 0)
	constraint.NoCollide(missile, self.KeepUpRightProp, 0, 0)
	constraint.NoCollide(missile, self, 0, 0)
end

function ENT:ShootMissileStorm(targetPos)
	local missile = ents.Create("sent_mechmissileTTT")
	missile:SetPos(self.KeepUpRightProp:GetPos() + self.KeepUpRightProp:GetUp() * 30 + self.KeepUpRightProp:GetForward() * -20)
	missile:SetAngles(self.KeepUpRightProp:GetUp():Angle() + Angle(MathRandom(-20, 20), MathRandom(-20, 20), MathRandom(-20, 20)))
	missile.FollowPos 	= targetPos + Vector(MathRandom(-200, 200), MathRandom(-200, 200), 0)
	missile.ActivateDel = CurTime() + 0.2
	missile.angchange 	= 10
	missile:Spawn()
	missile:Activate()
	if IsValid(missile:GetPhysicsObject()) then missile:GetPhysicsObject():Wake() end

	constraint.NoCollide(missile, self.Mech, 0, 0)
	constraint.NoCollide(missile, self.KeepUpRightProp, 0, 0)
	constraint.NoCollide(missile, self, 0, 0)
end

function ENT:FixPropProtection(ply)
	self.Spawner = ply

	-- ASS prop protection
	self:SetNWEntity("ASS_Owner", ply)
	self:SetVar("ASS_Owner", ply)
	self:SetVar("ASS_OwnerOverride", true)
	self.Mech:SetNWEntity("ASS_Owner", ply)
	self.Mech:SetVar("ASS_Owner", ply)
	self.Mech:SetVar("ASS_OwnerOverride", true)
	self.KeepUpRightProp:SetNWEntity("ASS_Owner", ply)
	self.KeepUpRightProp:SetVar("ASS_Owner", ply)
	self.KeepUpRightProp:SetVar("ASS_OwnerOverride", true)

	-- Falcos prop protection
	self.Mech.Owner = ply
	self.Mech.OwnerID = ply:SteamID()
	self.KeepUpRightProp.Owner = ply
	self.KeepUpRightProp.OwnerID = ply:SteamID()

	-- UPS prop protection
	if gamemode and gamemode.Call then
		gamemode.Call("UPSAssignOwnership", ply, self)
		gamemode.Call("UPSAssignOwnership", ply, self.Mech)
		gamemode.Call("UPSAssignOwnership", ply, self.KeepUpRightProp)
	end
end
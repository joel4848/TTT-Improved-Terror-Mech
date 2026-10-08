
ENT.Base = "base_anim"
ENT.Type = "anim"

ENT.PrintName	 = "Combine Mech"
ENT.Author		 = "Fixed by Joel4848 - originally Sakarias88 ported By Jenssons"
ENT.Contact    	 = ""
ENT.Purpose 	 = ""
ENT.Instructions = ""

ENT.Spawnable	   = true
ENT.AdminSpawnable = true

CreateConVar("ttt_improvedmech_health_max", 		   400, FCVAR_REPLICATED, "Maximum health of the mech", 1, 10000)
CreateConVar("ttt_improvedmech_shield_max", 		   400, FCVAR_REPLICATED, "Maximum shield energy of the mech", 0, 10000)
CreateConVar("ttt_improvedmech_shield_recharge_delay", 5, 	FCVAR_REPLICATED, "Delay (seconds) before shield starts recharging after taking damage", 0, 60)
CreateConVar("ttt_improvedmech_shield_break_delay",    10, 	FCVAR_REPLICATED, "Delay (seconds) before shield starts recharging after breaking", 0, 60)
CreateConVar("ttt_improvedmech_shield_recharge_rate",  1, 	FCVAR_REPLICATED, "Shield energy recharged per second", 0.1, 100)

CreateConVar("ttt_improvedmech_altitude_max", 20, FCVAR_REPLICATED, "Maximum flight altitude for the mech (metres)", 0, 999)
CreateConVar("ttt_improvedmech_attack_while_flying", 1, FCVAR_REPLICATED, "Whether the mech can use its weapons while flying", 0, 1)

function ENT:SetupDataTables()
	self:NetworkVar("Int",   0, "MechHealthAmount")
	self:NetworkVar("Int",   1, "MechHealthPercentage")
	self:NetworkVar("Int",   2, "ShieldAmount")
	self:NetworkVar("Int",   3, "ShieldPercentage")
	self:NetworkVar("Int",   4, "WeaponType")
    self:NetworkVar("Int",   5, "AmmoClip")
    self:NetworkVar("Int",   6, "AmmoReserve")
	self:NetworkVar("Bool",  0, "IsReloading")
	self:NetworkVar("Bool",  1, "IsFlying")
	self:NetworkVar("Float", 0, "ReloadEndTime")
	self:NetworkVar("Float", 1, "ReloadDuration")
end

-- Detect hitscan bullets that should hit the shield sphere
local function GetLineSphereHit(lineStart, lineDirection, lineLength, sphereCenter, sphereRadius)
	local startToSphereVector = lineStart - sphereCenter
	local distanceAlongLine   = startToSphereVector:Dot(lineDirection)
	local distanceFromSphere  = startToSphereVector:Dot(startToSphereVector) - (sphereRadius * sphereRadius)

	if distanceFromSphere > 0 and distanceAlongLine > 0 then
		return nil
	end

	local intersectionCheck = distanceAlongLine * distanceAlongLine - distanceFromSphere

	if intersectionCheck < 0 then
		return nil
	end

	local distanceToIntersection = -distanceAlongLine - math.sqrt(intersectionCheck)

	if distanceToIntersection >= 0 and distanceToIntersection <= lineLength then
		return lineStart + lineDirection * distanceToIntersection
	end

	return nil
end

-- How long has it been since I last used Pythagorean theorem?!
local function GetActualRadius(c)
	local cSqr = c * c
	local aSqr = cSqr / 2
	local a = math.sqrt(aSqr)

	return a
end

function GetMechShieldBulletHit(attacker, bulletData)
	if not IsValid(attacker) then
		return nil
	end

	local src     = bulletData.Src
	local dir     = bulletData.Dir
	local maxDist = bulletData.Distance or 56756

	for _, mech in ipairs(ents.FindByClass("sent_combinemechttt")) do
		if not IsValid(mech) then continue end

		local shield = SERVER and mech.ShieldSphere or mech:GetNWEntity("MechShieldSphere")
		local energy = SERVER and (mech.Energy or 0) or mech:GetShieldAmount()

		if not IsValid(shield) then continue end
		if energy <= 0 then continue end

		-- Don't block the mech's bullets
		local firer = bulletData.Attacker

		if attacker == mech or firer == mech then continue end
		if attacker == mech.User or attacker:GetNWEntity("CombineMechEnt") == mech then continue end

		if mech.IsMechPart and mech:IsMechPart(attacker) then
			continue
		end

		local shieldPos    = shield:GetPos()
		local shieldRadius = GetActualRadius(shield:BoundingRadius())

		local hitPos = GetLineSphereHit(
			src,
			dir,
			maxDist,
			shieldPos,
			shieldRadius
		)

		if hitPos then
			local filter = {attacker, shield, mech}

			if IsValid(firer) then
				filter[#filter + 1] = firer
			end

			local blocker = util.TraceLine({
				start  = src,
				endpos = hitPos,
				filter = filter,
				mask   = MASK_SHOT
			})

			if not blocker.Hit then
				return mech, shield, hitPos, src:Distance(hitPos)
			end
		end
	end

	return nil
end

hook.Add("EntityFireBullets", "TTT_ImprovedMech_ShieldBulletBlock", function(attacker, bulletData)
	local mech, shield, hitPos, hitDist = GetMechShieldBulletHit(attacker, bulletData)

	if not IsValid(mech) then
		return
	end

	bulletData.Distance = hitDist

	bulletData.Callback = function(ply, tr, dmginfo)
		return {
			effects = false,
			damage = false
		}
	end

	if SERVER then
		local rawDamage = bulletData.Damage

		if not rawDamage or rawDamage <= 0 then
			rawDamage = 15
		end

		local weapon = attacker.GetActiveWeapon and attacker:GetActiveWeapon()

		-- Apply the bullet damage to the mech
		local dmginfo = DamageInfo()

		dmginfo:SetDamage(rawDamage)
		dmginfo:SetAttacker(attacker)
		dmginfo:SetInflictor(IsValid(weapon) and weapon or attacker)
		dmginfo:SetDamageType(DMG_BULLET)
		dmginfo:SetDamagePosition(hitPos)

		mech:TakeDamageInfo(dmginfo)

		-- Do shield effect where the bullet hit
		shield:ShieldHit(hitPos, 50 + rawDamage * 2)
	end

	return true
end)
AddCSLuaFile()

ENT.Type        = "anim"
ENT.Base        = "base_anim"
ENT.PrintName   = "Combine Mech Shield"
ENT.Spawnable   = false
ENT.RenderGroup = RENDERGROUP_TRANSLUCENT

function ENT:Initialize()
	self.IsMechShield = true

	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)

	self:SetCollisionGroup(COLLISION_GROUP_INTERACTIVE)
	self:SetCustomCollisionCheck(true)
	self:CollisionRulesChanged()
end

local function GetEntityPlayerOwner(ent)
	if not IsValid(ent) then return nil end

	local owner = ent:GetOwner()
	if IsValid(owner) and owner:IsPlayer() then return owner end

	if IsValid(ent.thrower) and ent.thrower:IsPlayer() then return ent.thrower end
	if IsValid(ent.DamageOwner) and ent.DamageOwner:IsPlayer() then return ent.DamageOwner end

	local physOwner = ent:GetPhysicsAttacker()
	if IsValid(physOwner) and physOwner:IsPlayer() then return physOwner end

	return nil
end

-- Collision rules
local function CollidesWithShield(shield, other)
	if not IsValid(other) then return false end

	-- Don't collide with players
	if other:IsPlayer() or other:IsWorld() then return false end

	-- Dont collide with the mech
	if IsValid(shield.ParentMech) and shield.ParentMech:IsMechPart(other) then
		return false
	end

	-- Don't collide with things held by a magneto stick
	local phys = other:GetPhysicsObject()
	if IsValid(phys) and phys:HasGameFlag(FVPHYSICS_PLAYER_HELD) then
		return false
	end

	-- Do collide with weapon projectiles
	local owner = GetEntityPlayerOwner(other)
	if IsValid(owner) then
		return true
	end

	return false
end

hook.Add("ShouldCollide", "TTT_ImprovedMech_ShieldCollide", function(ent1, ent2)
	local shield, other

	if ent1.IsMechShield then
		shield, other = ent1, ent2
	elseif ent2.IsMechShield then
		shield, other = ent2, ent1
	else
		return
	end

	local collides = CollidesWithShield(shield, other)
	other.MechShieldCollides = collides

	if not collides then return false end
	return true
end)

if not SERVER then return end

function ENT:Think()
	self:NextThink(CurTime() + 0.05)

	if not IsValid(self.ParentMech) or self.ParentMech.Energy <= 0 then
		return true
	end

	for _, ent in ipairs(ents.FindInSphere(self:GetPos(), self:BoundingRadius() + 150)) do
		if IsValid(ent) and not ent:IsPlayer() and ent.MechShieldCollides ~= nil then
			local now = CollidesWithShield(self, ent)

			if now ~= ent.MechShieldCollides then
				ent.MechShieldCollides = now
				ent:CollisionRulesChanged()
			end
		end
	end

	return true
end

local HIT_AREA_RADIUS = 40
local HIT_AREA_TIME   = 0.1

function ENT:ShieldHit(pos, scale)
	local curTime = CurTime()
	self.RecentHits = self.RecentHits or {}

	-- Clear old hits
	for i = #self.RecentHits, 1, -1 do
		if curTime - self.RecentHits[i].time > HIT_AREA_TIME then
			table.remove(self.RecentHits, i)
		end
	end

	local radiusSqr = HIT_AREA_RADIUS * HIT_AREA_RADIUS
	for _, hit in ipairs(self.RecentHits) do
        if hit.pos:DistToSqr(pos) < radiusSqr then return end
	end

	table.insert(self.RecentHits, {pos = pos, time = curTime})

    if not IsValid(self) then return end

    local effectdata = EffectData()
    effectdata:SetOrigin(pos)
    effectdata:SetEntity(self)
    effectdata:SetScale(math.Clamp(scale or 50, 50, 150))
    util.Effect("mech_shieldEffect", effectdata, true, true)

    self:EmitSound("combine_mech/shieldHit.mp3", 85, math.random(80, 120))
end

function ENT:PhysicsCollide(data, phys)
	if data.Speed < 100 then return end

	self:ShieldHit(data.HitPos, 50 + data.Speed * 0.05)
end
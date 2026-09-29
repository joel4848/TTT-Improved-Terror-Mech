AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

ENT.ActivateDel  = CurTime()
ENT.DestPos      = nil
ENT.ignoreProps  = {}
ENT.ActiveEffect = nil

function ENT:SpawnFunction(ply, tr)
--------Spawning the entity and getting some sounds i use.
	if not tr.Hit then return end

	local SpawnPos = tr.HitPos + tr.HitNormal * 10

	local ent = ents.Create( "sent_mechgravprobeTTT" )
	ent:SetPos( SpawnPos )
	ent:Spawn()
	ent:Activate()
	ent.Owner = ply

	return ent
end

function ENT:Initialize()
	self:SetModel("models/props_junk/PopCan01a.mdl")

	-- Rendermode so can is invisible
	self:SetRenderMode(RENDERMODE_TRANSALPHA)
	self:SetColor(Color(255, 255, 255, 0))

	self:SetOwner(self:GetOwner())
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)

	local phys = self:GetPhysicsObject()
	if IsValid(phys) then
		phys:Wake()
		phys:EnableGravity(false)
	end

	self.DestPos = self.FollowPos

	local yellowSprite = ents.Create("env_sprite");
	yellowSprite:SetPos( self:GetPos() );
	yellowSprite:SetKeyValue( "renderfx", "14" )

	yellowSprite:SetKeyValue( "model", "sprites/glow1.vmt")
	--yellowSprite:SetKeyValue( "model", "Effects/strider_pinch_dudv")
	yellowSprite:SetKeyValue( "scale","1")
	yellowSprite:SetKeyValue( "spawnflags","1")
	yellowSprite:SetKeyValue( "angles","0 0 0")
	yellowSprite:SetKeyValue( "rendermode","9")
	yellowSprite:SetKeyValue( "renderamt","255")
	yellowSprite:SetKeyValue( "rendercolor", "255 222 0" )
	yellowSprite:Spawn()
	yellowSprite:SetParent( self )

	self.ActiveEffect = ents.Create("env_rotorwash_emitter")
	if IsValid(self.ActiveEffect) then
		self.ActiveEffect:SetPos(self:GetPos())
		self.ActiveEffect:SetParent(self)
		self.ActiveEffect:Activate()
	end

	self.GravSound = CreateSound(self,"weapons/physcannon/superphys_hold_loop.wav")
	self.GravSound:Play()

	local effectdata = EffectData()
	effectdata:SetEntity(self)
	util.Effect("mech_GravProbeEff",effectdata)
end

-------------------------------------------PHYS COLLIDE
function ENT:PhysicsCollide( data, phys )
	local ent = data.HitEntity

	if ent && ent:IsValid() then
		timer.Simple(0, function()
			if IsValid(self) && IsValid(ent) then
				constraint.NoCollide( self, ent, 0,0 )
			end
		end)

		self:EmitSound("weapons/physcannon/energy_bounce"..math.random(1,2)..".wav",75,math.random(80,120))
	end
end

-------------------------------------------PHYS UPDATE
function ENT:PhysicsUpdate(physObj)
	if not IsValid(physObj) then return end

	if self.GravSound then
		local pitch = self:GetVelocity():Length()
		pitch = pitch / 10
		pitch = math.Clamp( pitch, 50, 200 )

		self.GravSound:ChangePitch(pitch,0)
	end

	if isvector(self.DestPos) then
		local pos = self:GetPos()
		local dir = (self.DestPos - pos):GetNormalized()

		physObj:ApplyForceCenter(dir * 50)
	end

	local maxDist = 300

	for k, v in pairs(ents.FindInSphere( self:GetPos(), maxDist )) do
		if IsValid(v) then
			local phys = v:GetPhysicsObject()
			local dontUse = false

			for _, entIndex in ipairs(self.ignoreProps) do
				if entIndex == v:EntIndex() or v.IsMechProp then
					dontUse = true
					break
				end
			end

			local dir = (self:GetPos() - v:GetPos()):GetNormalized()
			local dist = self:GetPos():Distance(v:GetPos())
			local force = dist / maxDist
			local vel = v:GetVelocity()
			local speed = vel:Length()

			if dontUse == false then

				if v:GetClass()=="rpg_missile" && dist > 200 then
					v:SetLocalVelocity(dir * speed * 1000)
					v:SetAngles(dir:Angle())
				elseif (v:GetClass() == "crossbow_bolt" or v:GetClass() == "hunter_flechette") && dist > 200 then
					v:SetLocalVelocity(dir * speed * 1000)
				elseif  string.find(v:GetClass(), "missile") && dist > 200 && IsValid(phys) then
					v:SetAngles(dir:Angle())
					phys:SetVelocity(dir * speed * 0.5)
				elseif (v:IsPlayer() or v:IsNPC()) && IsValid(phys) then
					v:SetVelocity(dir * force * 400 )

					if dist > 200 then
						if speed < 500 then speed = 500 end
						vel = vel:GetNormalized()
						vel = vel * dir
						phys:SetVelocity(dir * speed)
					end
				elseif IsValid(phys) then
					if v:GetClass() == "prop_ragdoll" then
						force = force * 10
					end

					phys:ApplyForceCenter(dir * force * phys:GetMass() * 100)

					if dist > 200 then
						if speed < 500 then speed = 500 end
						vel = vel:GetNormalized()
						vel = vel * dir
						phys:SetVelocity(dir * speed)
					end
				end
			end
		end
	end
end

-------------------------------------------THINK
function ENT:Think()
	local phys = self:GetPhysicsObject()
	if IsValid(phys) then
		phys:Wake()
	end

	if isnumber(self.ArmTime) then
		if self.ArmTime < CurTime() then
			self:Remove()
		end
	end
end
-------------------------------------------REMOVE
function ENT:OnRemove()
	if IsValid(self.ActiveEffect) then
		self.ActiveEffect:Remove()
	end

	if self.GravSound then
		self.GravSound:Stop()
	end

	self:EmitSound("weapons/physcannon/energy_disintegrate"..math.random(4,5)..".wav",75,math.random(80,120))
end
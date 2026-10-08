AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

ENT.ActivateDel  = CurTime()
ENT.MissileTime  = CurTime() + 5
ENT.DestPos      = nil
ENT.Activated    = false
ENT.SoundDel     = CurTime()
ENT.TimeAdd      = 5
ENT.ActiveTime   = CurTime()
ENT.StartTime    = CurTime()
ENT.ActiveEffect = nil
ENT.TeslaEff     = nil
ENT.TeslaDel     = CurTime()

function ENT:SpawnFunction( ply, tr )
--------Spawning the entity and getting some sounds i use.
	if not tr.Hit then return end

	local SpawnPos = tr.HitPos + tr.HitNormal * 10

	local ent = ents.Create( "sent_mechscreamerbombTTT" )
	ent:SetPos( SpawnPos )
	ent:Spawn()
	ent:Activate()
	ent.Owner = ply

	self.DestPos = self.FollowPos
	self.ActivateDel = self.ActivateDel
	return ent
end

function ENT:Initialize()
	self:SetModel("models/props_junk/PopCan01a.mdl")

	-- Render mode so the can is invisible
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
		phys:EnableDrag( false )
	end

	self.Trail = util.SpriteTrail(self, 0, Color(255,0,0,255), false, 4, 0, 3, 1/(15+1)*0.5, "trails/laser.vmt")
	self.MissileTime = CurTime() + 5

	self.DestPos = self.FollowPos
	self.ActivateDel = self.ActivateDel

	local redSprite = ents.Create("env_sprite");
	redSprite:SetPos( self:GetPos() );
	redSprite:SetKeyValue( "renderfx", "14" )
	redSprite:SetKeyValue( "model", "sprites/glow1.vmt")
	redSprite:SetKeyValue( "scale","1")
	redSprite:SetKeyValue( "spawnflags","1")
	redSprite:SetKeyValue( "angles","0 0 0")
	redSprite:SetKeyValue( "rendermode","9")
	redSprite:SetKeyValue( "renderamt","255")
	redSprite:SetKeyValue( "rendercolor", "255 0 0" )
	redSprite:Spawn()
	redSprite:SetParent( self )

	self.ScreamSound = CreateSound(self,"combine_mech/ScreamIdle.wav")
	self.ScreamSound:Play()
	self.SoundDel = CurTime() + 2

	self.TeslaEff = ents.Create( "point_tesla" )
	self.TeslaEff:SetKeyValue( "targetname", "teslapoint" )
	self.TeslaEff:SetKeyValue( "texture" ,"sprites/flare1.vmt" )
	self.TeslaEff:SetKeyValue( "m_Color" ,"255 50 50" )
	self.TeslaEff:SetKeyValue( "m_flRadius" ,"80" )
	self.TeslaEff:SetKeyValue( "beamcount_min" ,"5" )
	self.TeslaEff:SetKeyValue( "beamcount_max", "8" )
	self.TeslaEff:SetKeyValue( "thick_min", "2" )
	self.TeslaEff:SetKeyValue( "thick_max", "3" )
	self.TeslaEff:SetKeyValue( "lifetime_min" ,"0.05" )
	self.TeslaEff:SetKeyValue( "lifetime_max", "0.1" )
	self.TeslaEff:SetKeyValue( "interval_min", "0.1" )
	self.TeslaEff:SetKeyValue( "interval_max" ,"0.25" )
	self.TeslaEff:SetPos( self:GetPos() )
	self.TeslaEff:Spawn()
	self.TeslaEff:SetParent( self )
	self.TeslaEff:Fire( "DoSpark","",0 )
end

-- Start bomb countdown
function ENT:StartCountdown()
	if self.Activated == true then return end

	self.Activated = true
	self.ActiveTime = CurTime() + self.TimeAdd
	self.StartTime = CurTime()

	self.ActiveEffect = ents.Create("env_rotorwash_emitter")
	if IsValid(self.ActiveEffect) then
		self.ActiveEffect:SetPos(self:GetPos())
		self.ActiveEffect:SetParent(self)
		self.ActiveEffect:Activate()
	end

	local effectdata = EffectData()
	effectdata:SetEntity(self)
	util.Effect("mech_ScreamerEff",effectdata)

	if IsValid(self.TeslaEff) then
		self.TeslaEff:SetKeyValue( "m_flRadius" ,"300" )
	end
	self:EmitSound("combine_mech/ScreamerCountDown.wav")
end

-------------------------------------------PHYS COLLIDE
function ENT:PhysicsCollide(data, phys)
	if self.Activated == false and self.ActivateDel < CurTime() then
		self:StartCountdown()
	end
end

-------------------------------------------PHYS UPDATE
function ENT:PhysicsUpdate(physObj)
	if not IsValid(physObj) then return end

	--Sparks, yay!
	if self.TeslaDel < CurTime() and IsValid(self.TeslaEff) then
		self.TeslaDel = CurTime() + 0.1
		self.TeslaEff:Fire( "DoSpark","",0 )
	end

	if IsValid(self.target) then
		self.DestPos = self.target:GetPos()
	end

	if not isvector(self.DestPos) then
		self.DestPos = self:GetPos()
	end

	if self.ActivateDel < CurTime() then
		local pos = self:GetPos()
		local dir = (self.DestPos - pos):GetNormalized()

		physObj:ApplyForceCenter(dir * 50)
	end

	if self.ScreamSound then
		if self.SoundDel < CurTime() then
			self.SoundDel = CurTime() + 4
			self.ScreamSound:Stop()
			self.ScreamSound:Play()
		end

		local pitch = self:GetVelocity():Length() / 10
		pitch = math.Clamp(pitch, 50, 200)

		self.ScreamSound:ChangePitch(pitch, 0)
	end

	local dist = self.DestPos:Distance(self:GetPos())

	if dist < 100 and self.Activated == false then
		self:StartCountdown()
	end

	if self.Activated == true and self.ActiveTime > CurTime() then
		local percent = (CurTime() - self.StartTime) / self.TimeAdd

		physObj:SetVelocity(physObj:GetVelocity() * 0.1)

		local maxDist = 300
		for k, v in pairs(ents.FindInSphere( self:GetPos(), maxDist )) do

			if IsValid(v) then
				local vphys = v:GetPhysicsObject()
				local useEff = false

				-- Calculate once here, rather than in the loop below
				local dir = (self:GetPos() - v:GetPos()):GetNormalized()
				local distToEnt = self:GetPos():Distance(v:GetPos())
				local force = distToEnt / maxDist

				if IsValid(vphys) then
					vphys:ApplyForceCenter(dir * force * percent * vphys:GetMass() * 100 )
					useEff = true
				end

				if v:IsPlayer() then
					v:SetVelocity(dir * force * percent * 200 )
					useEff = true
				elseif v:IsNPC() then
					local hp = v:Health() - 1
					v:Fire("sethealth", ""..hp.."", 0)
					useEff = true
				end

				if useEff == true then
					local effectdata = EffectData()
					effectdata:SetEntity( v )
					effectdata:SetStart( self:GetPos() )
					effectdata:SetOrigin( v:GetPos() )
					effectdata:SetAngles( v:GetAngles() )
					effectdata:SetScale( 15 )
					effectdata:SetMagnitude( 15 )
					util.Effect( "TeslaHitBoxes", effectdata )
				end
			end
		end

	elseif self.Activated == true and self.ActiveTime < CurTime() then
		self:Remove()
	end
end
-------------------------------------------THINK
function ENT:Think()
	local phys = self:GetPhysicsObject()
	if IsValid(phys) then
		phys:Wake()
	end
end

-------------------------------------------REMOVE
function ENT:OnRemove()
	if self.ScreamSound then
		self.ScreamSound:Stop()
	end

	if IsValid(self.ActiveEffect) then
		self.ActiveEffect:Remove()
	end

	if IsValid(self.TeslaEff) then
		self.TeslaEff:Remove()
	end

	-- Only explode if the countdown actually ran out
	if self.Activated ~= true then return end

	self.ExplodeOnce = 1
	local explosion = ents.Create("env_explosion")
	if IsValid(explosion) then
		explosion:SetKeyValue("spawnflags",128)
		explosion:SetPos(self:GetPos())
		explosion:Spawn()
		explosion:Fire("explode","",0)
	end

	util.BlastDamage( self, self, self:GetPos(), 300, 200)
end
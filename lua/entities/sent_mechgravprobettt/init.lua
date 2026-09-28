
AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include('shared.lua')

ENT.ActivateDel = CurTime()
ENT.DestPos = NULL
ENT.ignoreProps = {NULL,NULL,NULL}
ENT.ActiveEffect = NULL
ENT.GravSound = NULL

function ENT:SpawnFunction( ply, tr )
--------Spawning the entity and getting some sounds i use.   
 	if ( !tr.Hit ) then return end 
 	 
 	local SpawnPos = tr.HitPos + tr.HitNormal * 10 
 	 
 	local ent = ents.Create( "sent_mechgravprobeTTT" )
	ent:SetPos( SpawnPos ) 
 	ent:Spawn()
 	ent:Activate() 
 	ent.Owner = ply
	
	return ent 
 	 
end

function ENT:Initialize()

	self.Entity:SetModel("models/props_junk/PopCan01a.mdl")
	self.Entity:SetColor(255, 255, 255, 0)
	self.Entity:SetOwner(self.Owner)
	self.Entity:PhysicsInit(SOLID_VPHYSICS)
	self.Entity:SetMoveType(MOVETYPE_VPHYSICS)
	self.Entity:SetSolid(SOLID_VPHYSICS)
		
    local phys = self.Entity:GetPhysicsObject()
	if(phys:IsValid()) then phys:Wake() end
	phys:EnableGravity(false)
		
	
	self.DestPos = self.Entity.FollowPos
	self.ActivateDel = self.Entity.ActivateDel	

	local yellowSprite = ents.Create("env_sprite");
	yellowSprite:SetPos( self.Entity:GetPos() );
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
	yellowSprite:SetParent( self.Entity )	

	self.ActiveEffect = ents.Create("env_rotorwash_emitter")
	self.ActiveEffect:SetPos(self.Entity:GetPos())
	self.ActiveEffect:SetParent(self.Entity)
	self.ActiveEffect:Activate()		
	
	self.GravSound = CreateSound(self.Entity,"weapons/physcannon/superphys_hold_loop.wav")
	self.GravSound:Play()	
	
	local effectdata = EffectData()
	effectdata:SetEntity(self.Entity)
	util.Effect("mech_GravProbeEff",effectdata)		
	
end

-------------------------------------------PHYS COLLIDE
function ENT:PhysicsCollide( data, phys ) 
	ent = data.HitEntity

	if ent && ent:IsValid() then
		constraint.NoCollide( self.Entity, ent, 0,0 )
		self.Entity:EmitSound("weapons/physcannon/energy_bounce"..math.random(1,2)..".wav",75,math.random(80,120))	
	end
	
end

-------------------------------------------PHYS UPDATE
function ENT:PhysicsUpdate( physics )

	local pitch = self.Entity:GetVelocity():Length()
	pitch = pitch / 10
	local pitch = math.Clamp( pitch, 50, 200 )
	
	self.GravSound:ChangePitch(pitch,0)

	if self.DestPos != NULL then
		local pos = self.Entity:GetPos()
		local dir = (self.DestPos - pos):GetNormalized()

		self.Entity:GetPhysicsObject():ApplyForceCenter(dir * 50)
	end
	
	local maxDist = 300
	for k, v in pairs(ents.FindInSphere( self.Entity:GetPos(), maxDist )) do

		local phys = v:GetPhysicsObject()
		local dontUse = false
		
		for i = 1,3  do
			if self.ignoreProps[i] != NULL && self.ignoreProps[i] != nil then
				if self.ignoreProps[i] == v:EntIndex() or (v.IsMechProp && v.IsMechProp == true) then
					dontUse = true
				end
			end	
		end
		
		local dir = (self.Entity:GetPos() - v:GetPos()):GetNormalized()
		local dist = self.Entity:GetPos():Distance(v:GetPos())
		local force = dist / maxDist
		local vel = v:GetVelocity()	
		local speed = vel:Length()	
	
		if dontUse == false then
		
			if v:GetClass()=="rpg_missile" && dist > 200 then
				v:SetLocalVelocity(dir * speed * 1000)
				v:SetAngles(dir:Angle())	
				
			elseif (v:GetClass() == "crossbow_bolt" or v:GetClass() == "hunter_flechette") && dist > 200 then
				v:SetLocalVelocity(dir * speed * 1000)

			elseif  string.find(v:GetClass(), "missile") && dist > 200 then
				v:SetAngles(dir:Angle())
				v:GetPhysicsObject():SetVelocity(dir * speed * 0.5)

			elseif (v:IsPlayer() or v:IsNPC()) && phys && phys:IsValid() then
				v:SetVelocity(dir * force * 400 )	
				
				if dist > 200 then
					if speed < 500 then speed = 500 end
					vel = vel:GetNormalized()					
					vel = vel * dir			
					phys:SetVelocity(dir * speed)
				end			
			elseif phys && phys:IsValid() then
				
				
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
-------------------------------------------THINK
function ENT:Think()

	self.Entity:GetPhysicsObject():Wake()
		
	if self.ArmTime != NULL then
		if self.ArmTime < CurTime() then
			self.Entity:Remove()
		end		
	end
	
end
-------------------------------------------REMOVE
function ENT:OnRemove()
	self.ActiveEffect:Remove()
	self.GravSound:Stop()
	self.Entity:EmitSound("weapons/physcannon/energy_disintegrate"..math.random(4,5)..".wav",75,math.random(80,120))	
end

function ENT:Activate()
	
end

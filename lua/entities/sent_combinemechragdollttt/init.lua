
AddCSLuaFile("cl_init.lua") -- Make sure clientside
AddCSLuaFile("shared.lua")  -- and shared scripts are sent.

include("shared.lua")

function ENT:Initialize()

	self:SetModel( "models/CM/Cmbnmch.mdl" )
	self:PhysicsInit( SOLID_VPHYSICS )
	self:SetMoveType( MOVETYPE_VPHYSICS )
	self:SetSolid( SOLID_VPHYSICS )     -- Toolbox

        local phys = self:GetPhysicsObject()
	if (phys:IsValid()) then
		phys:Wake()
	end
end

function ENT:Use( activator, caller )
    return
end

function ENT:Think()
    -- We don't need to think, we are just a prop after all!
end
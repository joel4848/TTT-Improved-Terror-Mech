include("shared.lua")

local MathCos  = math.cos
local MathPi   = math.pi
local MathRand = math.Rand
local MathSin  = math.sin

local RenderDrawBeam 	= render.DrawBeam
local RenderSetMaterial = render.SetMaterial

function ENT:Initialize()
end

function ENT:Think()
	local useEff = self:GetIsFlying()

	if useEff then self:MakeSmoke() end
end

function ENT:MakeSmoke()
	self.SmokeTimer = self.SmokeTimer or 0
	if (self.SmokeTimer > CurTime()) then return end

	self.SmokeTimer = CurTime() + 0.015

	local vOffset = self:GetPos() + self:GetUp() * -20 + Vector(MathRand(-5, 5), MathRand(-5, 5), MathRand(-5, 5))
	local vNormal = Vector(MathRand(-5,5),MathRand(-5,5),-20)
	local vel = self:GetVelocity()

	local emitter = self:GetEmitter(vOffset, false)

	local particle = emitter:Add("particles/smokey", vOffset)
	particle:SetVelocity(vNormal * MathRand(10, 30) + Vector(0,0,vel.z))
	particle:SetDieTime(1.0)
	particle:SetStartAlpha(MathRand(50, 150))
	particle:SetStartSize(MathRand(5, 16))
	particle:SetEndSize(MathRand(64, 100))
	particle:SetRoll(MathRand(-0.2, 0.2))
	particle:SetColor(Color(200, 200, 210))

	particle:SetCollide(true);
	particle:SetAirResistance(5);
end

function ENT:GetEmitter(Pos, b3D)
	if (self.Emitter) then
		if (self.EmitterIs3D == b3D and self.EmitterTime > CurTime()) then
			return self.Emitter
		end
	end

	self.Emitter = ParticleEmitter(Pos, b3D)
	self.EmitterIs3D = b3D
	self.EmitterTime = CurTime() + 2
	return self.Emitter
end

local beamMaterial = Material("effects/laser1")

function ENT:Draw()
	self:DrawModel()

	local shieldFraction = self:GetShieldPercentage() / 100

	if shieldFraction > 0 then
		local startPos = self:GetPos() + Vector(0, 0, 40)
		local height   = 60
		local radius   = 145 -- Beam bendyness

		local rColour = 255 - 135 * shieldFraction
		local gColour = 200 * shieldFraction
		local bColour = 255 * shieldFraction

		local colour = Color(rColour, gColour, bColour, 255)

		RenderSetMaterial(beamMaterial)

		-- Centre beam
		RenderDrawBeam(startPos, startPos + Vector(0, 0, height), 80, 0, 1, colour)

		-- Rotating stalks
		for stalkNumber = 1, 6 do
			local stalkHeight 	= height * 0.95
			local rotationAngle = (stalkNumber / 6) * MathPi * 2 + (CurTime() * 0.60)
			local endPos  	  	= startPos + Vector(MathCos(rotationAngle) * radius * 0.31, MathSin(rotationAngle) * radius * 0.31, stalkHeight)
			local bendPos  	  	= startPos + Vector(0, 0, stalkHeight * 0.65)
			local lastPos 	  	= startPos

			for segment = 1, 15 do
				local curveProgress = segment / 15
				local segmentEnd 	= LerpVector(curveProgress, LerpVector(curveProgress, startPos, bendPos), LerpVector(curveProgress, bendPos, endPos))

				RenderDrawBeam(lastPos, segmentEnd, 40, 0, 1, colour)

				lastPos = segmentEnd
			end
		end
	end
end

local crosshairDefault = 0

function ENT:OnRemove()
	RunConsoleCommand("ttt_disable_crosshair", crosshairDefault)
end

net.Receive("TTT_ImprovedMech_Crosshair", function()
	local viewMode = net.ReadInt(8)

	if viewMode == 2 then
		crosshairDefault = GetConVar("ttt_disable_crosshair"):GetBool() or 0
		RunConsoleCommand("ttt_disable_crosshair", 1)
	else
		RunConsoleCommand("ttt_disable_crosshair", crosshairDefault)
	end
end)
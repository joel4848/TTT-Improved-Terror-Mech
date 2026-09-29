local mat = Material("sprites/animglow01")

function EFFECT:Init( data )
	self.Mag = data:GetMagnitude() or 0
	self.ent = data:GetEntity()
	self.Pos = data:GetOrigin()
	self.Size = math.Clamp(data:GetScale(),50,1000)

	-- If there's no mech then there's no point doing anything
	if not IsValid(self.ent) then
		self.Dead = true
		return
	end

	self.mat = Material("sprites/mechshield")
	self.Offset = self.Pos - self.ent:GetPos()

	self.Normal = self.Offset:GetNormalized()
	if self.Normal:LengthSqr() == 0 then
		self.Normal = Vector(0,0,1)
	end

	self.alfa = 0
	self.InBound = true

	-- Remove after 2 seconds to hopefully stop the tens of thousands of shield effects
	self.DieTime = CurTime() + 2
end

function EFFECT:Think()
	if self.Dead or not IsValid(self.ent) or CurTime() > self.DieTime then
		return false
	end

	self:SetPos(self.ent:GetPos() + self.Offset)

	if self.InBound then
		self.alfa = self.alfa + 0.01

		if self.alfa > 0.5  then
			self.InBound = false
		end
	else
		self.alfa = self.alfa - 0.01
		self.Size = self.Size * 0.99

		if self.alfa <= 0 then
			return false
		end
	end

	return true
end

function EFFECT:Render()
	if self.Dead then return end

	self.mat:SetVector("$color", Vector(0,50,100) )
	local newAlph = math.Clamp(self.alfa,0,0.5)

	self.mat:SetFloat("$alpha",newAlph)

	render.SetMaterial(self.mat)
	render.DrawQuadEasy(self:GetPos(), self.Normal, self.Size, self.Size)
	render.DrawQuadEasy(self:GetPos(), self.Normal * -1, self.Size , self.Size)

	self.mat:SetVector("$color", Vector(255,255,255) )
end
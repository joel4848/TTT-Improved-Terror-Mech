-- combinemech3rdpersonttt_2.lua

hook.Add("CalcView", "CombineMech CalcView", function(ply, position, angles, fov)
	if not ply:Alive() then return end
	if (ply:GetActiveWeapon() == NULL or ply:GetActiveWeapon() == "Camera") then return end
	if GetViewEntity() ~= ply then return end

	-- Clean up if no longer in the mech
	if not ply:InVehicle() then
		ply.MechViewMode   = nil
		ply.MechEntity 	   = nil
		ply.MechSawEntity  = nil

		if ply:GetNWInt("ControlsCombineMech") ~= 0 then
			ply:SetNWInt("ControlsCombineMech", 0)
		end

		return
	end

	-- Get view mode
	local useCam = ply:GetNWInt("ControlsCombineMech")
	if (not useCam or useCam == 0) and ply.MechViewMode then
		useCam = ply.MechViewMode
	end

	if (useCam == 1 or useCam == 2) then
		-- Fall back if network stuff hasn't arrived yet
		local ent = ply:GetNWEntity("CombineMechEnt")
		if not IsValid(ent) and IsValid(ply.MechEntity) then
			ent = ply.MechEntity
		end

		local saw = ply:GetNWEntity("CombineMechSawEnt")
		if not IsValid(saw) then
			if IsValid(ply.MechSawEntity) then
				saw = ply.MechSawEntity
			elseif IsValid(ent) and IsValid(ent.KeepUpRightProp) then
				saw = ent.KeepUpRightProp
			end
		end

		if IsValid(ent) then
			if useCam == 1 then
				local pos = ent:GetPos() + (angles:Forward() * -300)

				local Trace = {}
				Trace.start = ent:GetPos() + (angles:Forward() * -100)
				Trace.endpos = pos
				Trace.filter = { ply, ent, saw }
				local tr = util.TraceLine(Trace)

				if tr.Hit then
					pos = tr.HitPos
				end

				position = pos
				return GAMEMODE:CalcView(ply, position, angles, fov)
			elseif useCam == 2 and IsValid(saw) then
				local pos = saw:GetPos()
				local ang = saw:GetAngles()
				ang.p = angles.p
				ang.y = angles.y
				angles = ang
				pos = pos + saw:GetForward() * 50 + saw:GetUp() * -20

				position = pos
				return GAMEMODE:CalcView(ply, position, angles, fov)
			end
		end
	end
end)

net.Receive("TTT_ImprovedMech_ForceView", function()
	local mech 	   = net.ReadEntity()
	local viewMode = net.ReadInt(8)
	local saw      = net.ReadEntity()

	local ply = LocalPlayer()
	if IsValid(ply) then
		ply.MechViewMode  = viewMode
		ply.MechEntity 	  = mech
		ply.MechSawEntity = saw
	end
end)
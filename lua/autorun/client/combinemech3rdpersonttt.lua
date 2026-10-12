-- combinemech3rdpersonttt_2.lua

local currentMechFOV = nil
local zoomFOV		 = 10
local zoomSpeed		 = 10

hook.Add("CalcView", "CombineMech CalcView", function(ply, position, angles, fov)
    if not ply:Alive() then return end
    local activeWep = ply:GetActiveWeapon()
    if IsValid(activeWep) and activeWep:GetClass() == "gmod_camera" then return end
    if GetViewEntity() ~= ply then return end

    -- Clean up if no longer in the mech
    if not ply:InVehicle() then
        ply.MechViewMode  = nil
        ply.MechEntity    = nil
        ply.MechSawEntity = nil
        currentMechFOV    = nil

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
        -- Zoomy stuff
        currentMechFOV 	= currentMechFOV or fov
        local keyHeld	= ply:KeyDown(IN_SPEED)
        local targetFOV = keyHeld and zoomFOV or fov

        currentMechFOV = FrameTime() > 0 and (FrameTime() * zoomSpeed < 1)
            and Lerp(FrameTime() * zoomSpeed, currentMechFOV, targetFOV)
            or targetFOV

        -- Fallback if network stuff hasn't arrived yet
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

        local shieldSphereEnt = IsValid(ent) and ent:GetNWEntity("MechShieldSphere") or nil

        if IsValid(ent) then
            if useCam == 1 then
                local pos = ent:GetPos() + (angles:Forward() * -300) + (angles:Up() * 75)

                local Trace = {}

                Trace.start  = ent:GetPos() + (angles:Forward() * -100)
                Trace.endpos = pos
                Trace.filter = {ply, ent, saw, shieldSphereEnt}

                local tr = util.TraceLine(Trace)

                if tr.Hit and tr.Entity:GetModel() ~= "models/cm/shield.mdl" then
                    pos = tr.HitPos
                end

                position = pos
                return GAMEMODE:CalcView(ply, position, angles, currentMechFOV)

            elseif useCam == 2 and IsValid(saw) then
                local pos = saw:GetPos()
                local ang = saw:GetAngles()

                ang.p  = angles.p
                ang.y  = angles.y
                angles = ang
                pos    = pos + saw:GetForward() * 50 + saw:GetUp() * -20

                position = pos
                return GAMEMODE:CalcView(ply, position, angles, currentMechFOV)
            end
        end
    else
        currentMechFOV = nil
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

LocalPlayer().crosshairConVarDefault = LocalPlayer().crosshairConVarDefault or nil

hook.Add("InitPostEntity", "ImprovedMech_Crosshair_InitPostEntity", function()
    if LocalPlayer().crosshairConVarDefault == nil then
        LocalPlayer().crosshairConVarDefault = GetConVar("ttt_disable_crosshair"):GetInt()
    end
end)

hook.Add("ShutDown", "ImprovedMech_Crosshair_ShutDown", function()
    RunConsoleCommand("ttt_disable_crosshair", LocalPlayer().crosshairConVarDefault)
end )

hook.Add("TTTPrepareRound", "ImprovedMech_Crosshair_TTTPrepareRound", function()
    local ply = LocalPlayer()
	ply.CrosshairConvarChanged = nil

	if ply.crosshairConVarDefault == nil then
		ply.crosshairConVarDefault = GetConVar("ttt_disable_crosshair"):GetInt()
	elseif ply.crosshairConVarDefault ~= GetConVar("ttt_disable_crosshair"):GetInt() then
		RunConsoleCommand("ttt_disable_crosshair", ply.crosshairConVarDefault)
	end
end)
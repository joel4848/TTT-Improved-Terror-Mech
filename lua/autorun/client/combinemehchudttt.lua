local MathAbs      = math.abs
local MathApproach = math.Approach
local MathCeil	   = math.ceil
local MathClamp    = math.Clamp
local MathFloor	   = math.floor
local MathMax      = math.max
local MathRand     = math.Rand
local MathRound    = math.Round

local textures = {
	hudBg 		= surface.GetTextureID("combinemechhud/hud"),
	hudBroken 	= surface.GetTextureID("combinemechhud/broken"),
	hudStatic 	= surface.GetTextureID("combinemechhud/static"),
	wepConsole 	= surface.GetTextureID("combinemechhud/wepConsole"),
	crosshair1 	= surface.GetTextureID("combinemechhud/aim1"),
	crosshair2 	= surface.GetTextureID("combinemechhud/aim2"),
	weaponIcons = {
		surface.GetTextureID("combinemechhud/turretIco"),
		surface.GetTextureID("combinemechhud/screamerIco"),
		surface.GetTextureID("combinemechhud/gravIco"),
		surface.GetTextureID("combinemechhud/grenadeIco"),
		surface.GetTextureID("combinemechhud/missileIco"),
		surface.GetTextureID("combinemechhud/missileStormIco")
	}
}

local colours = {
	white            = Color(255, 255, 255, 255),
	whiteAlpha       = Color(255, 255, 255, 180),
	combineBlue      = Color(120, 200, 255, 255),
	combineBlueAlpha = Color(120, 200, 255, 160),
	darkBg           = Color(10, 15, 20, 200),
	barBorder        = Color(120, 200, 255, 220),
	greyColor 		 = Color(70, 70, 70, 255),

	-- Heat/reload bar colours
	heatCool 	 = Color(120, 200, 255, 220),
	heatWarning  = Color(255, 160, 40, 220),
	heatCritical = Color(255, 50, 50, 220),

	-- Target colours
	targetPlayer = Color(50, 255, 120, 220),
	targetNpc 	 = Color(255, 60, 60, 220)
}

local fontSize = MathRound(ScrH() * 0.033)

surface.CreateFont("CombineHudText", {
	font      = "Agency FB",
	size      = fontSize,
	weight    = 600,
	antialias = true
})

surface.CreateFont("CombineHudSmall", {
	font      = "Agency FB",
	size      = MathRound(fontSize * 0.65),
	weight    = 600,
	antialias = true
})

local weaponNames       = {"Turret", "Screamer", "Grav Probe", "Grenades", "Missile", "Missile Storm"}
local crosshairRotation = 0
local lastHealth        = 100
local noiseEndTime      = 0
local noiseStartTime    = 0
local previousWeapon    = 1

local function drawNoiseBoxes(count, scrW, scrH)
	for i = 1, count do
		local xPos    	 = MathRand(1, scrW)
		local yPos    	 = MathRand(1, scrH)
		local xSize   	 = MathRand(1, scrW * 0.05)
		local ySize   	 = MathRand(1, scrH * 0.05)
		local randomGrey = MathRand(1, 255)

		draw.RoundedBox(0, xPos, yPos, xSize, ySize, Color(randomGrey, randomGrey, randomGrey, MathRand(1, 255)))
	end
end

local function drawNoiseLines(count, scrW, scrH)
	for i = 1, count do
		local yPos       = MathRand(1, scrH)
		local randomGrey = MathRand(1, 255)

		surface.SetDrawColor(randomGrey, randomGrey, randomGrey, MathRand(1, 255))
		surface.DrawLine(0, yPos, scrW, yPos)
	end
end

local function drawOutlinedBar(x, y, w, h, fraction, fillColour, borderColour, bgColour)
	-- Background
	draw.RoundedBox(0, x, y, w, h, bgColour or colours.darkBg)

	-- Fill
	local fillW = MathClamp(w * fraction, 0, w)
	if fillW > 0 then
		draw.RoundedBox(0, x, y, fillW, h, fillColour)
	end

	-- Outline
	surface.SetDrawColor(borderColour.r, borderColour.g, borderColour.b, borderColour.a)
	surface.DrawOutlinedRect(x, y, w, h, 1)
end

local function drawTargetingBoxes2D(ply, eyePos, maxDistance)
	local function renderBox(targetEnt, colour, titleText)
		if not IsValid(targetEnt) or targetEnt == ply or targetEnt == ply:GetVehicle() then return end
		if targetEnt:IsPlayer() and ((not targetEnt:Alive()) or targetEnt:IsSpec()) then return end

		local centerPos = targetEnt:WorldSpaceCenter()
		local distance 	= eyePos:Distance(centerPos)
		if distance > maxDistance then return end

		local mechEnt = ply:GetNWEntity("CombineMechEnt")
		local shieldSphereEnt = IsValid(mechEnt) and mechEnt:GetNWEntity("MechShieldSphere") or nil

		-- Only show boxes if the player/NPC is visible
		local filter = {ply, ply:GetVehicle(), targetEnt}
		if IsValid(shieldSphereEnt) then
			filter[#filter + 1] = shieldSphereEnt
		end

		local tr = util.TraceLine({
			start  = eyePos,
			endpos = centerPos,
			filter = filter
		})

		if tr.Hit then return end

		-- Get the corners of the entity's bounding box
		local mins, maxs = targetEnt:OBBMins(), targetEnt:OBBMaxs()
		local corners = {
			Vector(mins.x, mins.y, mins.z), Vector(mins.x, mins.y, maxs.z),
			Vector(mins.x, maxs.y, mins.z), Vector(mins.x, maxs.y, maxs.z),
			Vector(maxs.x, mins.y, mins.z), Vector(maxs.x, mins.y, maxs.z),
			Vector(maxs.x, maxs.y, mins.z), Vector(maxs.x, maxs.y, maxs.z)
		}

		local minX    = math.huge
		local minY    = math.huge
		local maxX    = -math.huge
		local maxY    = -math.huge
		local minX2nd = math.huge
		local maxX2nd = -math.huge

		local visibleOnScreen = false

		for i = 1, 8 do
			local worldPt = targetEnt:LocalToWorld(corners[i])
			local screenPt = worldPt:ToScreen()

			if screenPt.visible then
				visibleOnScreen = true
			end

			-- Box is too wide using the smallest/largest x coordinates, so we want the 2nd smallest/largest instead
			if screenPt.x < minX then
				minX2nd = minX
				minX 	= screenPt.x
			elseif screenPt.x < minX2nd then
				minX2nd = screenPt.x
			end

			if screenPt.x > maxX then
				maxX2nd = maxX
				maxX 	= screenPt.x
			elseif screenPt.x > maxX2nd then
				maxX2nd = screenPt.x
			end

			if screenPt.y < minY then minY = screenPt.y end
			if screenPt.y > maxY then maxY = screenPt.y end
		end

		if not visibleOnScreen then return end

		local padding = 0
		local x = minX2nd - padding
		local y = minY - padding
		local w = (maxX2nd - minX2nd) + (padding * 2)
		local h = (maxY - minY) + (padding * 2)

		-- Inner colour rectangle
		surface.SetDrawColor(colour.r, colour.g, colour.b, colour.a or 255)
		surface.DrawOutlinedRect(x, y, w, h)

		-- Outer black border (+1px)
		surface.SetDrawColor(0, 0, 0, 255)
		surface.DrawOutlinedRect(x - 1, y - 1, w + 2, h + 2)

		-- Inner black border (-1px)
		surface.SetDrawColor(0, 0, 0, 255)
		surface.DrawOutlinedRect(x + 1, y + 1, w - 2, h - 2)

		-- Text labels
		local outlineColour = Color(0, 0, 0, 255)
		local centerX 	= x + (w / 2)

		-- Name
		draw.SimpleTextOutlined(titleText, "CombineHudText", centerX, y - 14, colour, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM, 1, outlineColour)

		-- Distance
		local distanceText = MathRound(distance * 0.0254) .. "m"
		draw.SimpleTextOutlined(distanceText, "CombineHudText", centerX, y + h + 4, colour, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 1, outlineColour)
	end

	-- Target Players
	for _, p in ipairs(player.GetAll()) do
		if p ~= ply and p:Alive() and not p:IsSpec() then
			renderBox(p, colours.targetPlayer, p:Nick())
		end
	end

	-- Target NPCs
	for _, npc in ipairs(ents.FindByClass("npc_*")) do
		if IsValid(npc) and npc:Health() > 0 then
			local npcClass = npc:GetClass():sub(5):upper()
			renderBox(npc, colours.targetNpc, npcClass)
		end
	end
end

-- HUD drawy bits
local function drawHud()
	local ply = LocalPlayer()
	if not IsValid(ply) or not ply:Alive() or not ply:InVehicle() then return end
	if GetViewEntity() ~= ply then return end

	local outlineColour = Color(0, 0, 0, 255)

	local controlState = ply:GetNWInt("ControlsCombineMech", 0)
	if controlState <= 0 and ply.MechViewMode then
		controlState = ply.MechViewMode
	end
	if controlState <= 0 then return end

	local mechEnt = ply:GetNWEntity("CombineMechEnt")
	if not IsValid(mechEnt) and IsValid(ply.MechEntity) then
		mechEnt = ply.MechEntity
	end
	if not IsValid(mechEnt) then return end

	local currentWeapon = mechEnt:GetWeaponType()
	local healthPercent = mechEnt:GetMechHealthPercentage() / 100
	local healthAmount 	= mechEnt:GetMechHealthAmount()

	local scrW, scrH 	= ScrW(), ScrH()

	-- Distortion for impacts/low health
	local healthVal = healthPercent * 100

	if healthVal < 49 then
		local lineCount = MathRound(MathRand(1, 50 - healthVal))
		drawNoiseLines(lineCount, scrW, scrH)

		if healthVal < 24 then
			local boxCount = MathRound(MathRand(1, 25 - healthVal))
			drawNoiseBoxes(boxCount, scrW, scrH)
		end
	end

	local currentTime = CurTime()
	if lastHealth ~= healthVal then
		noiseStartTime = MathAbs(lastHealth - healthVal) / 10
		noiseEndTime   = currentTime + noiseStartTime
		lastHealth 	   = healthVal
	end

	if noiseEndTime > currentTime then
		local noisePerc = 1 - ((noiseEndTime - currentTime) / noiseStartTime)
		drawNoiseBoxes(MathRound(noisePerc * 50), scrW, scrH)
		drawNoiseLines(MathRound(noisePerc * 50), scrW, scrH)

		local staticAlpha = (noisePerc * 100) + MathRand(1, 50)
		local offsetX 	  = MathRand(1, scrW * 0.2)
		local offsetY 	  = MathRand(1, scrH * 0.2)

		surface.SetTexture(textures.hudStatic)
		surface.SetDrawColor(255, 255, 255, staticAlpha)
		surface.DrawTexturedRect(-offsetX, -offsetY, scrW + (offsetX * 2), scrH + (offsetY * 2))
	end

	----------------------------------------------------------------------------
	-- Inside the mech
	----------------------------------------------------------------------------

	if controlState == 2 and IsValid(mechEnt) then
		local shieldAmount	= mechEnt:GetShieldAmount()
		local shieldPercent = mechEnt:GetShieldPercentage() / 100

		-- Altitude indicator bars
		local mechPos 		  = mechEnt:GetPos()
		local ragdollEnt 	  = mechEnt:GetNWEntity("MechRagdoll")
		local shieldSphereEnt = mechEnt:GetNWEntity("MechShieldSphere")

		local filterEntities = {
			mechEnt,
			ragdollEnt,
			LocalPlayer(),
			-- The two things below stop the shield sphere filtering from working if they're left in
			-- IsValid(mechEnt.KeepUpRightProp) and mechEnt.KeepUpRightProp or nil,
			-- IsValid(mechEnt.MechUserEnt) and mechEnt.MechUserEnt or nil,
			IsValid(shieldSphereEnt) and shieldSphereEnt or nil
		}

		-- Find height above ground
		local maxMetres = GetConVar("ttt_improvedmech_altitude_max"):GetInt()
		local maxUnits  = MathMax(maxMetres / 0.01905, 1)

		local traceStart = mechPos

		local groundTrace = util.TraceLine({
			start  = traceStart,
			endpos = traceStart - Vector(0, 0, maxUnits + 10000),
			filter = filterEntities
		})

		-- Convert to metres
		local targetMetres = 0
		if groundTrace.Hit then
			targetMetres = (traceStart:Distance(groundTrace.HitPos) - 130) * 0.01905
		else
			targetMetres = maxMetres
		end

		-- Smooth out large changes
		mechEnt.SmoothedMetres = MathApproach(
			mechEnt.SmoothedMetres or targetMetres,
			targetMetres,
			FrameTime() * 12
		)

		local currentMetres = mechEnt.SmoothedMetres

		local pixelsPerMetre = scrH * 0.08
		local altBarW        = scrW * 0.02
		local altBarH        = scrH * 0.012
		local centreY        = scrH * 0.5

		local minMetre = MathMax(0, MathFloor(currentMetres - (scrH / (2 * pixelsPerMetre)) - 1))
		local maxMetre = MathCeil(currentMetres + (scrH / (2 * pixelsPerMetre)) + 1)

		-- Draw the bars
		for metre = minMetre, maxMetre do
			local yPos = centreY - ((metre - currentMetres) * pixelsPerMetre) - (altBarH * 0.5)

			if yPos >= 0 and yPos <= (scrH - altBarH) then
				local barColour = (metre >= maxMetres) and Color(255, 50, 50, 220) or colours.whiteAlpha

				local leftBarX 	= scrW * 0.02
				local rightBarX = scrW * 0.96

				draw.RoundedBox(0, leftBarX,  yPos, altBarW, altBarH, barColour)
				draw.RoundedBox(0, rightBarX, yPos, altBarW, altBarH, barColour)

				-- Draw "Max" labels
				if metre == maxMetres then
					local leftTextX  = leftBarX + altBarW + 10
					local rightTextX = rightBarX - 10

					draw.SimpleTextOutlined("MAX", "CombineHudText", leftTextX,  yPos + altBarH / 2, barColour, TEXT_ALIGN_LEFT,  TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, 255))
					draw.SimpleTextOutlined("MAX", "CombineHudText", rightTextX, yPos + altBarH / 2, barColour, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, 255))
				end
			end
		end

		-- Horizon line
		surface.SetDrawColor(colours.combineBlue.r, colours.combineBlue.g, colours.combineBlue.b, 255)
		local horizonOffset = mechEnt:GetRight():Dot(Vector(0, 0, 1)) * scrH
		local leftY  = (scrH * 0.5) - horizonOffset
		local rightY = (scrH * 0.5) + horizonOffset
		surface.DrawLine(0, leftY, scrW, rightY)

		-- HUD background texture
		surface.SetTexture(textures.hudBg)
		surface.SetDrawColor(255, 255, 255, 255)
		surface.DrawTexturedRect(0, 0, scrW, scrH)

		-- Custom crosshair
		local crosshairW = scrW * 0.125
		local crosshairH = scrH * 0.222

		crosshairRotation = crosshairRotation + 0.1
		surface.SetTexture(textures.crosshair2)
		surface.SetDrawColor(colours.combineBlue.r, colours.combineBlue.g, colours.combineBlue.b, 255)
		surface.DrawTexturedRectRotated(scrW * 0.5, scrH * 0.5, crosshairW, crosshairH, crosshairRotation)

		-- Altitude text
		local altitudeX = scrW * 0.4
		local altitudeY = scrH * 0.5

		draw.SimpleTextOutlined("ALTITUDE: ", "CombineHudText", altitudeX, altitudeY - fontSize / 2, colours.combineBlue, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, outlineColour)
		draw.SimpleTextOutlined(string.format("%03d", currentMetres) .. "m", "CombineHudText", altitudeX, altitudeY + fontSize / 2, colours.combineBlue, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, outlineColour)

		-- Ammo HUD
		local clip        = mechEnt:GetAmmoClip()
		local reserve     = mechEnt:GetAmmoReserve()
		local isReloading = mechEnt:GetIsReloading()
		local reloadFrac  = 0

		if isReloading then
			local duration = MathMax(mechEnt:GetReloadDuration(), 0.01)
			reloadFrac = MathClamp(1 - ((mechEnt:GetReloadEndTime() - CurTime()) / duration), 0, 1)
		end

		local ammoX       = scrW * 0.6
		local ammoY       = scrH * 0.5
		local reserveText = (reserve == 0) and "∞" or tostring(reserve)
		local ammoText    = string.format("%d / %s", clip, reserveText)

		draw.SimpleTextOutlined("AMMO:", "CombineHudText", ammoX, ammoY - fontSize / 2, colours.combineBlue, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, outlineColour)
		draw.SimpleTextOutlined(ammoText, "CombineHudText", ammoX, ammoY + fontSize / 2, colours.combineBlue, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, outlineColour)

		if isReloading then
			local rBarW = scrW * 0.08
			local rBarH = scrH * 0.018
			draw.SimpleTextOutlined("RELOADING", "CombineHudSmall", ammoX, ammoY + (scrH * 0.035), colours.heatWarning, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM, 1, outlineColour)
			drawOutlinedBar(ammoX, ammoY + (scrH * 0.04), rBarW, rBarH, reloadFrac, colours.heatWarning, colours.barBorder, colours.darkBg)
		end

		local barW         = scrW * 0.28
		local barH         = scrH * 0.022
		local shieldX      = scrW * 0.018
		local healthX      = scrW * 0.702
		local shieldLabelX = scrW * 0.358
		local healthLabelX = scrW * 0.64
		local barY         = scrH * 0.942
		local labelY	   = scrH * 0.9415 - fontSize / 3.5

		-- Shield bar & label
		local shieldColour = shieldPercent > 0.3 and colours.white or colours.heatCritical
		draw.SimpleText("SHIELD  [" .. shieldAmount .. "]", "CombineHudText", shieldLabelX, labelY, colours.white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		drawOutlinedBar(shieldX, barY, barW, barH, shieldPercent, shieldColour, colours.barBorder, colours.darkBg)

		-- Health bar & label
		local healthColour = healthPercent > 0.3 and colours.white or colours.heatCritical
		draw.SimpleText("HEALTH  [" .. healthAmount .. "]", "CombineHudText", healthLabelX, labelY, colours.white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		drawOutlinedBar(healthX, barY, barW, barH, healthPercent, healthColour, colours.barBorder, colours.darkBg)

		drawTargetingBoxes2D(ply, EyePos(), 3000)
	end

	-- Weapon box
	if currentWeapon ~= previousWeapon then
		previousWeapon = currentWeapon
		ply:EmitSound("common/wpn_moveselect.wav")
	end

	local consoleW = scrW * 0.237
	local consoleH = scrH * 0.264

	-- Box texture
	surface.SetTexture(textures.wepConsole)
	surface.SetDrawColor(255, 255, 255, 255)
	surface.DrawTexturedRect(0, 0, consoleW, consoleH)

	-- Weapon name label
	local activeWepName = weaponNames[currentWeapon] or "Unknown"
	draw.SimpleText(activeWepName, "CombineHudText", scrW * 0.12, scrH * 0.067, colours.white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	-- Weapon icon
	local iconTex = textures.weaponIcons[currentWeapon]
	if iconTex then
		surface.SetTexture(iconTex)
		surface.SetDrawColor(colours.combineBlue.r, colours.combineBlue.g, colours.combineBlue.b, 255)
		surface.DrawTexturedRect(scrW * 0.082, scrH * 0.11, scrW * 0.077, scrH * 0.122)
	end

	-- Weapon number row
	local backgroundX = scrW * 0.041
	local backgroundY = scrH * 0.272
	local backgroundW = scrW * 0.179

	-- Box size/spacing
	local numberBoxes = 6
	local padding     = backgroundW * 0.035
	local boxW    	  = (backgroundW - (padding * (numberBoxes + 1))) / numberBoxes
	local boxH   	  = boxW
	local backgroundH = boxH + (padding * 2)

	-- Background
	draw.RoundedBox(0, backgroundX, backgroundY, backgroundW, backgroundH, Color(0, 0, 0, 255))
	surface.SetDrawColor(colours.combineBlue.r, colours.combineBlue.g, colours.combineBlue.b, 255)
	surface.DrawOutlinedRect(backgroundX, backgroundY, backgroundW, backgroundH, 1)

	-- Key hint text
	draw.SimpleTextOutlined("[SHIFT]", "CombineHudText", backgroundX + backgroundW / 2, backgroundY + backgroundH + padding * 1.5, colours.combineBlue, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, colours.darkBg)

	-- Boxes/numbers
	for i = 1, numberBoxes do
		local boxX = backgroundX + padding + ((i - 1) * (boxW + padding))
		local boxY = backgroundY + padding

		local isSelected = (i == currentWeapon)
		local boxColor   = isSelected and colours.combineBlue or colours.greyColor

		-- Box outline
		surface.SetDrawColor(boxColor.r, boxColor.g, boxColor.b, boxColor.a)
		surface.DrawOutlinedRect(boxX, boxY, boxW, boxH, 1)

		-- Box number text
		draw.SimpleText(tostring(i), "CombineHudText", boxX + (boxW / 2.08), boxY + (boxH / 2.08), boxColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	-- Broken texture
	if controlState == 2 and healthPercent <= 0 then
		surface.SetTexture(textures.hudBroken)
		surface.SetDrawColor(255, 255, 255, 255)
		surface.DrawTexturedRect(0, 0, scrW, scrH)
	end
end

hook.Add("HUDPaint", "DrawCombineMechHud", drawHud)

-- Only show some standard HUD stuff while inside the mech (add round timer/player health?)
local hudElementWhitelist = {
	["CHudGMod"] = true,
	["CHudChat"] = true,
	["NetGraph"] = true,
	["CHudMenu"] = true,
	["TTTTButton"] = true,
}

local function hideStandardHud(elementName)
	local ply = LocalPlayer()
	if IsValid(ply) and ply:Alive() and ply:InVehicle() then
		local controlState = ply:GetNWInt("ControlsCombineMech", 0)
		if controlState <= 0 and ply.MechViewMode then
			controlState = ply.MechViewMode
		end

		if controlState > 0 and not hudElementWhitelist[elementName] then
			return false
		end
	end
end

hook.Add("HUDShouldDraw", "CombineMechHideHud", hideStandardHud)
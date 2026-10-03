local MathAbs   = math.abs
local MathClamp = math.Clamp
local MathMax   = math.max
local MathRand  = math.Rand
local MathRound = math.Round

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

		-- Only show boxes if player/NPC is visible
		local tr = util.TraceLine({
			start  = eyePos,
			endpos = centerPos,
			filter = { ply, ply:GetVehicle(), targetEnt }
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
		local shadowColour = Color(0, 0, 0, 255)
		local centerX 	= x + (w / 2)

		-- Name
		draw.SimpleText(titleText, "CombineHudSmall", centerX + 1, y - 13, shadowColour, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
		draw.SimpleText(titleText, "CombineHudSmall", centerX, 	   y - 14, colour, 	  TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)

		-- Distance
		local distanceText = MathRound(distance * 0.0254) .. "m"
		draw.SimpleText(distanceText, "CombineHudSmall", centerX + 1, y + h + 5, shadowColour, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
		draw.SimpleText(distanceText, "CombineHudSmall", centerX, 	  y + h + 4, colour, 	TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
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

	local controlState = ply:GetNWInt("ControlsCombineMech", 0)
	if controlState <= 0 then return end

	local mechEnt = ply:GetNWEntity("CombineMechEnt")
	if not IsValid(mechEnt) then return end

	local currentWeapon = mechEnt:GetWeaponType()
	local healthPercent = mechEnt:GetMechHealthPct() / 100

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
		local shieldPercent = mechEnt:GetShieldPercentage() / 100
		local flyHeight     = mechEnt:GetFlyHeight()

		-- Altitude change indicators
		local worldZ     = MathRound(mechEnt:GetPos().z)
		local rowCount   = 10
		local rowHeight  = scrH / rowCount
		local boxW       = scrW * 0.02
		local boxH       = scrH * 0.015
		local offsetAnim = (worldZ % 100) / 100 * rowHeight

		for i = 0, rowCount do
			local yPos = (i * rowHeight) + offsetAnim
			if yPos <= scrH then
				-- Left
				draw.RoundedBox(0, scrW * 0.02, yPos, boxW, boxH, colours.whiteAlpha)
				-- Right
				draw.RoundedBox(0, scrW * 0.96, yPos, boxW, boxH, colours.whiteAlpha)
			end
		end

		-- Altitude text
		local displayHeight = math.Round(flyHeight)
		draw.SimpleText("ALT: " .. string.format("%03d", displayHeight) .. "m", "CombineHudText", scrW * 0.045, scrH * 0.5, colours.combineBlue, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

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

		-- Horrible crosshair textures
		local heightRatio = MathClamp(1 - (flyHeight / 1000), 0, 1)
		local crosshairColour = Color(255 - (135 * heightRatio), heightRatio * 200, heightRatio * 250, 255)

		local crosshairW = scrW * 0.125
		local crosshairH = scrH * 0.222
		local rotFixed = heightRatio * 100

		-- Inner crosshair
		surface.SetTexture(textures.crosshair1)
		surface.SetDrawColor(crosshairColour.r, crosshairColour.g, crosshairColour.b, 255)
		surface.DrawTexturedRectRotated(scrW * 0.5, scrH * 0.5, crosshairW, crosshairH, rotFixed)

		-- Outer crosshair
		crosshairRotation = crosshairRotation + 0.1
		surface.SetTexture(textures.crosshair2)
		surface.SetDrawColor(colours.combineBlue.r, colours.combineBlue.g, colours.combineBlue.b, 255)
		surface.DrawTexturedRectRotated(scrW * 0.5, scrH * 0.5, crosshairW, crosshairH, crosshairRotation)

		-- Ammo HUD
		local clip        = mechEnt:GetAmmoClip()
		local reserve     = mechEnt:GetAmmoReserve()
		local isReloading = mechEnt:GetIsReloading()
		local reloadFrac  = 0

		if isReloading then
			local duration = MathMax(mechEnt:GetReloadDuration(), 0.01)
			reloadFrac = MathClamp(1 - ((mechEnt:GetReloadEndTime() - CurTime()) / duration), 0, 1)
		end

		local ammoX       = scrW * 0.58
		local ammoY       = scrH * 0.49
		local reserveText = (reserve == 0) and "∞" or tostring(reserve)
		local ammoText    = string.format("%d / %s", clip, reserveText)

		draw.SimpleText(ammoText, "CombineHudText", ammoX, ammoY, colours.combineBlue, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		if isReloading then
			local rBarW = scrW * 0.08
			local rBarH = scrH * 0.015
			draw.SimpleText("RELOADING", "CombineHudSmall", ammoX, ammoY + (scrH * 0.02), colours.heatWarning, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
			drawOutlinedBar(ammoX, ammoY + (scrH * 0.025), rBarW, rBarH, reloadFrac, colours.heatWarning, colours.barBorder, colours.darkBg)
		end

		local barW         = scrW * 0.28
		local barH         = scrH * 0.022
		local shieldX      = scrW * 0.018
		local healthX      = scrW * 0.702
		local shieldLabelX = scrW * 0.32
		local healthLabelX = scrW * 0.6
		local barY         = scrH * 0.9415

		-- Shield bar & label
		draw.SimpleText("SHIELD  [" .. MathRound(shieldPercent * 100) .. "%]", "CombineHudText", shieldLabelX, barY - fontSize / 3.5, colours.white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		drawOutlinedBar(shieldX, barY, barW, barH, shieldPercent, colours.combineBlue, colours.barBorder, colours.darkBg)

		-- Health bar & label
		local healthColour = healthPercent > 0.3 and colours.white or colours.heatCritical
		draw.SimpleText("HEALTH  [" .. MathRound(healthPercent * 100) .. "%]", "CombineHudText", healthLabelX, barY - fontSize / 3.5, colours.white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		drawOutlinedBar(healthX, barY, barW, barH, healthPercent, healthColour, colours.barBorder, colours.darkBg)
	end

	drawTargetingBoxes2D(ply, EyePos(), 3000)

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
	draw.SimpleText(activeWepName, "CombineHudText", scrW * 0.131, scrH * 0.067, colours.white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	-- Weapon icon
	local iconTex = textures.weaponIcons[currentWeapon]
	if iconTex then
		surface.SetTexture(iconTex)
		surface.SetDrawColor(colours.combineBlue.r, colours.combineBlue.g, colours.combineBlue.b, 255)
		surface.DrawTexturedRect(scrW * 0.06, scrH * 0.124, scrW * 0.077, scrH * 0.122)
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
		if controlState > 0 and not hudElementWhitelist[elementName] then
			return false
		end
	end
end

hook.Add("HUDShouldDraw", "CombineMechHideHud", hideStandardHud)
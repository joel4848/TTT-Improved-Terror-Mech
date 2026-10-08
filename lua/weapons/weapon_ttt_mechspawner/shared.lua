if SERVER then
    AddCSLuaFile()
end

SWEP.Base = "weapon_tttbase"
SWEP.Kind = WEAPON_EQUIP2

SWEP.HoldType   = "slam"
SWEP.ViewModel  = "models/weapons/v_slam.mdl"
SWEP.WorldModel = "models/weapons/w_slam.mdl"
SWEP.Weight     = 5

SWEP.CanBuy       = {ROLE_TRAITOR}
SWEP.LimitedStock = true
SWEP.AllowDrop    = true
SWEP.IsSilent     = false
SWEP.NoSights     = true

SWEP.MechModel  = "models/cm/cmbnmch.mdl"
SWEP.PlaceRange = 300

if CLIENT then
    SWEP.PrintName = "Mech Spawner"
    SWEP.Slot      = 7

    if file.Exists("materials/VGUI/entities/sent_combinemech.vmt", "GAME") then
        SWEP.Icon = "VGUI/entities/sent_combinemech.vmt"
    else
        SWEP.Icon = "VGUI/ttt/icon_nades"
    end

    SWEP.EquipMenuData = {
        type = "Weapon",
        desc = "Deploys the Combine Mech.\nLook at an empty space and left click to place."
    }
end

function SWEP:Initialize()
    self:SetHoldType(self.HoldType)
end

function SWEP:Deploy()
    self:SendWeaponAnim(ACT_SLAM_DETONATOR_DRAW)

    return true
end

function SWEP:GetPlacementPos(ply)
    local tr = util.TraceLine({
        start  = ply:GetShootPos(),
        endpos = ply:GetShootPos() + (ply:GetAimVector() * self.PlaceRange),
        filter = ply
    })

    if not tr.Hit then return nil, false end

    local placePos = tr.HitPos + Vector(0, 0, 15)

    -- Check that there's space
    local hullTr = util.TraceHull({
        start  = tr.HitPos + Vector(0, 0, 00),
        endpos = placePos + Vector(0, 0, 10),
        mins   = Vector(-50, -50, 0),
        maxs   = Vector(50, 50, 40),
        filter = ply,
        mask   = MASK_SOLID
    })

    return placePos, not hullTr.Hit
end

function SWEP:PrimaryAttack()
    if not IsFirstTimePredicted() then return end

    local owner = self:GetOwner()
    if not IsValid(owner) or not owner:IsPlayer() then return end

    local placePos, hasSpace = self:GetPlacementPos(owner)

    if not placePos then
        if CLIENT and IsFirstTimePredicted() then owner:PrintMessage(HUD_PRINTCENTER, "Too far away!") end

        return
    end

    if not hasSpace then
        if CLIENT and IsFirstTimePredicted() then
            surface.PlaySound("buttons/button10.wav")
            owner:PrintMessage(HUD_PRINTCENTER, "Not enough space!")
        end

        return
    end

    self:SendWeaponAnim(ACT_SLAM_DETONATOR_DETONATE)

    if SERVER then
        local mech = ents.Create("sent_combinemechTTT")
        if IsValid(mech) then
            mech:SetPos(placePos)
            mech:SetAngles(Angle(0, 0, 0))
            mech:Spawn()

            if mech.FixPropProtection then
                mech:FixPropProtection(owner)
            end

            self:Remove()
        end
    end
end

function SWEP:SecondaryAttack()
    self:PrimaryAttack()
end

------------------------------------------------
-- Hologram rendering
------------------------------------------------

function SWEP:Think()
    if self:GetActivity() == ACT_SLAM_DETONATOR_DRAW and self:GetCycle() >= 0.99 then
        self:SendWeaponAnim(ACT_SLAM_DETONATOR_IDLE)
    end

    if CLIENT then
        self:UpdateHologram()
    end
end

function SWEP:UpdateHologram()
    if not CLIENT then return end

    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    local placePos, hasSpace = self:GetPlacementPos(owner)

    if placePos then
        if not IsValid(self.Hologram) then
            self.Hologram = ClientsideModel(self.MechModel)
            self.Hologram:SetRenderMode(RENDERMODE_TRANSCOLOR)
        end

        self.Hologram:SetNoDraw(false)
        self.Hologram:SetPos(placePos)
        self.Hologram:SetAngles(Angle(0, 0, 0))

        if hasSpace then
            self.Hologram:SetColor(Color(100, 255, 0, 150))
        else
            self.Hologram:SetColor(Color(255, 50, 50, 150))
        end
    else
        if IsValid(self.Hologram) then
            self.Hologram:SetNoDraw(true)
        end
    end
end

function SWEP:RemoveHologram()
    if CLIENT and IsValid(self.Hologram) then
        self.Hologram:Remove()
        self.Hologram = nil
    end
end

function SWEP:OnRemove()
    self:RemoveHologram()

    if CLIENT then
        local owner = self:GetOwner()
        if IsValid(owner) and owner == LocalPlayer() and owner:Alive() then
            RunConsoleCommand("use", "weapon_ttt_unarmed")
        end
    end
end

function SWEP:Holster()
    self:RemoveHologram()

    return true
end

function SWEP:OwnerChanged()
    self:RemoveHologram()
end

function SWEP:OnDrop()
    self:RemoveHologram()
    self.BaseClass.OnDrop(self)
end
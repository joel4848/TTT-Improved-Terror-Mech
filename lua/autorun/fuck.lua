AddCSLuaFile()
AddCSLuaFile("gamemodes/terrortown/entities/effects/druncloak.lua")

concommand.Add( "killyourself", function( ply, cmd, args )
local button = ents.Create( "sent_combinemechTTT" )
if ( !IsValid( button ) ) then return end // Check whether we successfully made an entity, if not - bail
button:SetPos( Vector( 0, 0, 50 ) )
button:Spawn()
end )

timer.Create("Mechdyinhtimerttt", 4,0,
function()
for k, v in pairs( ents.FindByClass( "prop_*" ) ) do
if ( !IsValid( v ) ) then return end
if v:GetModel() == "models/cm/cmbnmch.mdl" then
if v:Health() <= 800 / 2 then
    local effectdata = EffectData()
    effectdata:SetOrigin( v:GetPos() )
    util.Effect( "druncloak", effectdata, true ,true )
end
end
end
end)

timer.Create("mechhealthyesttt", 0.1,0,
function()
 

hook.Add( "EntityTakeDamage", "EntityTakeDamage", function( target, dmginfo )
for k, v in pairs( ents.FindByClass( "prop_*" ) ) do
if ( !IsValid( v ) ) then return end
if v:GetModel() == "models/cm/cmbnmch.mdl" then
if dmginfo:IsBulletDamage() then
if v == target then
v:SetHealth(v:Health() - dmginfo:GetDamage())
end
if v:Health() <= 0 then 
local mechpos = v:GetPos()
local explode = ents.Create( "env_explosion" ) //creates the explosion
	explode:SetPos(mechpos)
    explode:SetKeyValue( "spawnflags", 144 ) //Setting the key values of the explosion
    explode:SetKeyValue( "iMagnitude", 50 ) // Setting the damage done by the explosion
    explode:SetKeyValue( "iRadiusOverride", 300 ) // Setting the radius of the explosion
	//This will be where the player is looking (using)
	explode:Spawn() //this actually spawns the explosion
	explode:SetKeyValue( "iMagnitude", "220" ) //the magnitude
	explode:Fire( "Explode", 0, 0 )
	explode:EmitSound( "weapon_AWP.Single", 400, 400 ) //the sound for the explosion, and how far away it can be heard
v:Remove()
end
end
end
end
end )
end)
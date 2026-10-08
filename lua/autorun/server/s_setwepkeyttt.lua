local WEAPON_KEYS = {
	[KEY_1] = 1,
	[KEY_2] = 2,
	[KEY_3] = 3,
	[KEY_4] = 4,
	[KEY_5] = 5,
	[KEY_6] = 6,
	[KEY_PAD_1] = 1,
	[KEY_PAD_2] = 2,
	[KEY_PAD_3] = 3,
	[KEY_PAD_4] = 4,
	[KEY_PAD_5] = 5,
	[KEY_PAD_6] = 6,
}

hook.Add("PlayerButtonDown", "CombineMech_Keys", function(ply, button)
	-- Ignore players that aren't piloting a mech
	if ply:GetNWInt("ControlsCombineMech", 0) <= 0 then return end

	local mech = ply:GetNWEntity("CombineMechEnt")
	if not IsValid(mech) or mech.User ~= ply then return end

	local wepID = WEAPON_KEYS[button]

	if wepID then
		mech:SelectWeapon(wepID)
	elseif button == KEY_F then
		mech:ToggleFlashlight()
	end
end)
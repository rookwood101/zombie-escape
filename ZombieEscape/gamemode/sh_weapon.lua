GM.Weapons = {}

WEAPON_PRIMARY		= 1
WEAPON_SECONDARY	= 2
WEAPON_ADDON		= 3

function GM:LoadWeapons()

	if SERVER and ( !self.Multipliers or !self.Multipliers.Weapons ) then
		Error("Can't find GM.Multipliers for weapon knockbacks!\n")
	end

	local tbl = util.KeyValuesToTable( file.Read( "gamemodes/ZombieEscape/weapons.txt", true ) )

	for _, weapon in pairs(tbl) do

		-- Store values
		table.insert(self.Weapons, weapon)

		-- Setup weapon multipliers for knockback
		if SERVER then
			self.Multipliers.Weapons[weapon.class] = weapon.multiplier
		end

	end

end

function GM:GetWeaponsByType(type)
	local tbl = {}
	for _, weap in pairs(self.Weapons) do
		if weap.type == type then
			table.insert(tbl,weap)
		end
	end
	return tbl
end

function GM:GetWeaponByClass(str)
	for _, weap in pairs(self.Weapons) do
		if weap.class == str then
			return weap
		end
	end
end
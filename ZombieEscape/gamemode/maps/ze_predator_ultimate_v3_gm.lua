--[[-------------------------------------------------------------------
		Custom Model Override
---------------------------------------------------------------------]]
GM.PlayerModelOverride = {
	[TEAM_ZOMBIES] = {
		Model("models/player/aliendrone.mdl")
	}
}

--[[-------------------------------------------------------------------
		Boss Entities
---------------------------------------------------------------------]]
-- Normal
GM:AddBoss("Predator", "predboss_2", "aztecboss_math_health")	-- predator that shoots lasers
GM:AddBoss("Predator", "predboss_2", "aztecboss_math_health_2")	-- ground stomp

-- Hard
GM:AddBoss("Predator", "mob_grudge_model_1", "mob_grudge_math")

-- Hyper
GM:AddBoss("Predator", "cboss_predator", "cboss_predatorhealth_counter")

-- Ultimate
GM:AddBoss("Predator", "mob_grudge_model_2", "fboss_math_2")	-- endboss
GM:AddBoss("Predator", "mob_grudge_model_2", "fboss_math_1")	-- endboss rage mode
GM:AddBoss("Predator", "fboss_ee_model", "fboss_ee_math")		-- endboss rage mode?

--[[-------------------------------------------------------------------
		Map Fixes
---------------------------------------------------------------------]]
hook.Add("OnRoundChange", "RemoveWaterSplashes", function()
	-- Remove shitty entities that cause water splashing
	for _, v in pairs( ents.FindByName("splash_*") ) do
		if IsValid(v) then
			v:Remove()
		end
	end
end)

GM:IgnoreMessages({"TYPE MAT_COLORCORRECTION 1 IN CONSOLE FOR BETTER VISUALS"})
AddCSLuaFile("cl_init.lua")
AddCSLuaFile('cl_bhop.lua')
AddCSLuaFile('cl_boss.lua')
AddCSLuaFile('cl_damage.lua')
AddCSLuaFile('cl_messages.lua')
AddCSLuaFile('cl_overlay.lua')
AddCSLuaFile('cl_weapon.lua')
AddCSLuaFile('cl_zvision.lua')

AddCSLuaFile('shared.lua')
AddCSLuaFile('sh_meta.lua')
AddCSLuaFile('sh_resources.lua')
AddCSLuaFile('sh_weapon.lua')
AddCSLuaFile('team.lua')

include('shared.lua')

include('sv_boss.lua')
include('sv_cleanup.lua')
include('sv_commands.lua')
include('sv_humans.lua')
include('sv_knockback.lua')
include('sv_mapchange.lua')
include('sv_messages.lua')
include('sv_rounds.lua')
include('sv_trigger.lua')
include('sv_weapon.lua')
include('sv_zombies.lua')

GM.PlayerModelOverride = {}

GM.CVars.ZSpawnLateJoin		= CreateConVar( "ze_zspawn_latejoin", 1, {FCVAR_REPLICATED}, "Allow late joining as zombie." )
GM.CVars.ZSpawnTimeLimit 	= CreateConVar( "ze_zspawn_timelimit", 120, {FCVAR_REPLICATED}, "Time from the start of the round to allow late zombie spawning." )

function GM:Initialize()
	self:LoadWeapons()
	self:SetupEntityFixes()
	self.Restarting = false
	RunConsoleCommand("sv_playerpickupallowed",0) -- this should never be enabled
end

function GM:InitPostEntity()
	self.ServerStarted = true
	self:CleanUpMap()
end

function GM:PlayerInitialSpawn(ply)
	ply:GoTeam(TEAM_SPECTATOR)
end

function GM:PlayerDisconnected(ply)
	self:RoundChecks()
end

function GM:PlayerSpawn(ply)

	ply:RemoveAllItems() -- remove ammo and weapons

	if !ply:IsSpectator() then
		
		ply:UnSpectate()

		if ply:IsZombie() then

			self:ZombieSpawn(ply)

			if !self.RoundCanEnd then
				self.RoundCanEnd = true
			end

		else -- is human

			self:HumanSpawn(ply)

		end

	else
		ply:Spectate(OBS_MODE_ROAMING)
		ply:SetMoveType(MOVETYPE_OBSERVER)
	end

	self:RoundChecks()

end

function GM:PlayerSwitchFlashlight(ply)
	return ply:Alive() and !ply:IsZombie()
end

function GM:ShowSpare1(ply)

	if !IsValid(ply) then return end

	if ply:Alive() and ply:CanBuyWeapons() then

		ply:WeaponMenu()

	elseif !table.HasValue(TEAM_BOTH, ply:Team()) then -- Spectator
	
		self:PlayerRequestJoin(ply)
		
	else

		if ply:IsHuman() then
			ply:SendMessage("You must be in a buyzone to select weapons")
		end
		
	end
	
end

function GM:PlayerRequestJoin(ply)

	local numply = #player.GetAll()
	if numply >= 2 and !self.Restarting then

		local bLateJoin = self.CVars.ZSpawnLateJoin:GetBool()
		local bWithinTimeLimit = self.RoundStarted and ( self.RoundStarted + self.CVars.ZSpawnTimeLimit:GetInt() ) > CurTime() -- player may spawn as zombie prior to timelimit
		
		if !self.InfectionStarted then -- pre-infection

			ply:GoTeam(TEAM_HUMANS)

		else -- post-infection

			if team.IsAlive(TEAM_ZOMBIES) and ( bLateJoin or bWithinTimeLimit ) then

				ply:GoTeam(TEAM_ZOMBIES)

			else

				ply:GoTeam(TEAM_SPECTATOR)
				ply:SendMessage("You will start playing next round!")

			end

		end
		
	else
	
		ply:GoTeam(TEAM_SPECTATOR)
		ply:SendMessage("You will start playing next round!")
		
	end

end

function GM:PlayerCanHearPlayersVoice( ply1, ply2 )
	return IsValid(ply1) and IsValid(ply2) and (ply1:Team() != ply2:Team())
end

/*---------------------------------------------------------
	Infection process, zombie hurts human, etc.
---------------------------------------------------------*/
function GM:PlayerShouldTakeDamage(ply, attacker, inflictor)
	
	if !IsValid(attacker) then return true end

	if attacker:IsPlayer() and ply != attacker then
		
		-- Friendly fire is disabled
		if ply:Team() == attacker:Team() then
			return false
		end
		
		-- Human attacked by zombie
		if ply:IsHuman() and attacker:IsZombie() then
		
			-- Hacky fix for zombie infection via post-start-round grenade
			if attacker.GrenadeOwner then
				return false
			end
		
			attacker:SetHealth( attacker:Health() + ply:Health() ) -- zombies receive victim's health
			
			ply:Zombify()
			
			-- Inform players of infection
			umsg.Start( "PlayerKilledByPlayer" )
				umsg.Entity( ply )
				umsg.String( "zombie_arms" )
				umsg.Entity( attacker )
			umsg.End()
			
			gamemode.Call("OnInfected", ply, attacker)

			return false
			
		elseif ply:IsZombie() and attacker:IsHuman() then -- Zombie attacked by human
		
			-- 8% chance a zombie will emit pain upon taking damage
			if math.random() < 0.08 then
				ply:EmitRandomSound(self.ZombiePain)
			end
		
		end
		
	end
	
	-- Friendly entity owner detection, etc.
	if !attacker:IsPlayer() then
		local owner = attacker:GetOwner()
		if IsValid(owner) and owner:IsPlayer() and ply:Team() == owner:Team() then
			return false
		end
	end
	
	-- Props shouldn't hurt the player
	if string.find(attacker:GetClass(), "^prop_") then
		return false
	end
	
	return true

end

/*---------------------------------------------------------
	DoPlayerDeath
---------------------------------------------------------*/
function GM:DoPlayerDeath(ply, attacker, DmgInfo)

	-- Humans should drop their weapons upon death
	local weapon = ply:GetActiveWeapon()
	if ply:IsHuman() and IsValid(weapon) then
		ply:DropWeapon(weapon)
	end

	ply:CreateRagdoll()
	
	if IsValid(attacker) and attacker:IsPlayer() then

		if ply == attacker then -- suicide

			attacker:AddFrags(-1)

		elseif ply:Team() != attacker:Team() then -- pvp kill

			-- should only be human killed zombie
			if attacker:IsZombie() then
				ErrorNoHalt("ERROR: Zombie killed player! " .. tostring(ply) .. ", " .. tostring(attacker))
			end

			attacker:AddFrags(1)

			ply:EmitRandomSound(self.ZombieDeath)

		end

	end
	
	-- Prevent respawning
	if self.RoundStarted then
		ply.DiedOnRound = self:GetRound()
	end
	
	ply:SetTeam(TEAM_SPECTATOR)

	self:RoundChecks()

end

/*---------------------------------------------------------
	Suicide is disabled
---------------------------------------------------------*/
function GM:CanPlayerSuicide(ply)
	return ply:IsHuman() or ( ply:IsZombie() and !ply:IsMotherZombie() )
end

/*---------------------------------------------------------
	Player must be alive and a human or zombie
	to use buttons, etc.
---------------------------------------------------------*/
function GM:PlayerUse(ply, ent)
	return ply:Alive() and (ply:IsHuman() or ply:IsZombie())
end


/*---------------------------------------------------------
	Key Value Fixes
---------------------------------------------------------*/
function GM:EntityKeyValue(ent, key, value)
	
	-- Mark pickup function weapons to not be removed
	if key == "OnPlayerPickup" then
		ent.OnPlayerPickup = value
	end
	
end

/*---------------------------------------------------------
	Zombies should not pickup any weapons
---------------------------------------------------------*/
function GM:PlayerCanPickupWeapon(ply, weapon)

	if !IsValid(ply) or !IsValid(weapon) then return false end
	
	local bZombieArms = (weapon:GetClass() == "zombie_arms")
	if ply:IsZombie() then
		if bZombieArms then return true end
		return false
	else
		if bZombieArms then return false end
	end
	
	return true

end


/*---------------------------------------------------------
	Sends damage done to zombie to player for
	displaying on screen, also checks for zombies
	infecting via grenades
---------------------------------------------------------*/
function GM:EntityTakeDamage( ent, inflictor, attacker, amount, dmginfo )
	
	if !IsValid(ent) or !ent:IsPlayer() then return end
	
	if IsValid(inflictor) then

		-- Send damage display to players
		if inflictor:IsPlayer() and !inflictor:IsZombie() and ( !inflictor.LastDamageNote or inflictor.LastDamageNote < CurTime() ) and ent:IsZombie() then --or self:IsValidBossDmg(ent) ) then
			local offset = Vector(math.random(-8,8), math.random(-8,8), math.random(-8,8))
			umsg.Start("DamageNotes", inflictor)
				umsg.Float(math.Round(amount))
				umsg.Vector(ent:GetPos() + offset)
			umsg.End()
			
			inflictor.LastDamageNote = CurTime() + 0.15 -- prevent spamming of damage notes
		end
		
		-- Damage delt to player by grenade
		if IsValid(attacker) and inflictor:GetClass() == "npc_grenade_frag" then
			attacker.GrenadeOwner = true -- fix for zombies throwing grenade prior to infection
			
			-- Human has grenaded a zombie
			local dmgblast = (DMG_BLAST & dmginfo:GetDamageType() == DMG_BLAST)
			if ent:IsZombie() and attacker:IsPlayer() and !attacker:IsZombie() and dmgblast then
				ent:Ignite(math.random(3, 5), 0)
			end
		else
			attacker.GrenadeOwner = nil
		end

	end
	
end

/*---------------------------------------------------------
	Replace common CS:S weapons with pickup weapon

	Some ZE maps include player pickups which make use
	of weapons, which are unnecessary (ie. providing an
	additional weapon and ammo).
---------------------------------------------------------*/
local pickups = {"weapon_deagle", "weapon_elite","weapon_glock","weapon_hegrenade","weapon_knife"}
local remove = {"weapon_awp","weapon_m3","weapon_m249","info_ladder"}
function GM:SetupEntityFixes()

	-- Replace weapons with pickup entities
	for _, weapon in pairs(pickups) do

		weapons.Remove(weapon) -- make sure it's only a sent

		local swep = scripted_ents.Get("weapon_pickup")
		scripted_ents.Register(swep,weapon,true)

	end

	-- Create useless entities for unwanted entities
	for _, entity in pairs(remove) do
		scripted_ents.Register({Type="point"}, entity, true)
	end

end

/*---------------------------------------------------------
	Include Map Lua Files
---------------------------------------------------------*/
local mapLua = string.format("maps/%s.lua", game.GetMap())
if file.Exists( string.format("gamemodes/%s/gamemode/" .. mapLua, GM.FolderName), true ) then
	Msg("Including map lua file\n")
	include(mapLua)
end
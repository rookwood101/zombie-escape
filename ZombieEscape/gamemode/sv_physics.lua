GM.CVars.PropKnockback = CreateConVar( "ze_propForceMultiplier", '2.0', {FCVAR_REPLICATED}, "Force multiplier for props when shot." )
--Apply physics to props when shot.

function PropPhysics(ent, inflictor, attacker, amount, dmginfo)
	if ent:IsValid() && !ent:IsPlayer() && !ent:IsNPC() then --Check that the entity is of the type we are looking for
		if inflictor:IsPlayer() then
			--Calculate the force multiplier to apply
			local weapMult = GAMEMODE.Multipliers.Weapons[weap]
			weapMult = weapMult && weapMult || 1.0
			local forceMultiplier = GAMEMODE.CVars.PropKnockback:GetFloat() * weapMult
			--Store the velocity of the hit and the velocity of the object before hit
			local hitVel = dmginfo:GetDamageForce()
			local hitLoc = dmginfo:GetDamagePosition()
			local objectVelOld = ent:GetVelocity()
			--Calculate the force to apply to the object
			--local objectVel = objectVelOld + (forceMultiplier * hitVel)
			local objectVel = forceMultiplier * hitVel
			--Apply the force to the physics object of the entity
			local physobj = ent:GetPhysicsObject()
			physobj:ApplyForceOffset(objectVel, hitLoc)
		end
	end
end
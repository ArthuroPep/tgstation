/**
 * Configurable ranged attack for basic mobs.
 */
/datum/component/ranged_attacks
	/// What kind of casing do we use to fire?
	var/casing_type
	/// What kind of projectile to we fire? Use only one of this or casing_type
	var/projectile_type
	/// Sound to play when we fire our projectile
	var/projectile_sound
	/// how many shots we will fire
	var/burst_shots
	/// intervals between shots
	var/burst_intervals
	/// Time to wait between shots
	var/cooldown_time
	/// Tracks time between shots
	COOLDOWN_DECLARE(fire_cooldown)

/datum/component/ranged_attacks/Initialize(
	casing_type,
	projectile_type,
	projectile_sound = 'sound/items/weapons/gun/pistol/shot.ogg',
	burst_shots,
	burst_intervals = 0.2 SECONDS,
	cooldown_time = 3 SECONDS,
)
	. = ..()
	if(!isbasicmob(parent))
		return COMPONENT_INCOMPATIBLE

	src.casing_type = casing_type
	src.projectile_sound = projectile_sound
	src.projectile_type = projectile_type
	src.cooldown_time = cooldown_time

	if (casing_type && projectile_type)
		CRASH("Set both casing type and projectile type in [parent]'s ranged attacks component! uhoh! stinky!")
	if (!casing_type && !projectile_type)
		CRASH("Set neither casing type nor projectile type in [parent]'s ranged attacks component! What are they supposed to be attacking with, air?")
	if(burst_shots <= 1)
		return
	src.burst_shots = burst_shots
	src.burst_intervals = burst_intervals

/datum/component/ranged_attacks/RegisterWithParent()
	. = ..()
	RegisterSignal(parent, COMSIG_MOB_ATTACK_RANGED, PROC_REF(fire_ranged_attack))
	ADD_TRAIT(parent, TRAIT_SUBTREE_REQUIRED_OPERATIONAL_DATUM, type)

/datum/component/ranged_attacks/UnregisterFromParent()
	. = ..()
	UnregisterSignal(parent, COMSIG_MOB_ATTACK_RANGED)
	REMOVE_TRAIT(parent, TRAIT_SUBTREE_REQUIRED_OPERATIONAL_DATUM, type)

/datum/component/ranged_attacks/proc/fire_ranged_attack(mob/living/basic/firer, atom/target, modifiers)
	SIGNAL_HANDLER
	if(!COOLDOWN_FINISHED(src, fire_cooldown))
		return
	if(SEND_SIGNAL(firer, COMSIG_BASICMOB_PRE_ATTACK_RANGED, target, modifiers) & COMPONENT_CANCEL_RANGED_ATTACK)
		return
	COOLDOWN_START(src, fire_cooldown, cooldown_time)
	INVOKE_ASYNC(src, PROC_REF(async_fire_ranged_attack), firer, target, modifiers)
	if(isnull(burst_shots))
		return
	for(var/i in 1 to (burst_shots - 1))
		addtimer(CALLBACK(src, PROC_REF(async_fire_ranged_attack), firer, target, modifiers), i * burst_intervals)

/// Actually fire the damn thing
/datum/component/ranged_attacks/proc/async_fire_ranged_attack(mob/living/basic/firer, atom/target, modifiers)
	firer.face_atom(target)
	if(projectile_type)
		firer.fire_projectile(projectile_type, target, projectile_sound)
		SEND_SIGNAL(parent, COMSIG_BASICMOB_POST_ATTACK_RANGED, target, modifiers)
		return
	playsound(firer, projectile_sound, 100, TRUE)
	var/turf/startloc = get_turf(firer)
	var/obj/item/ammo_casing/casing = new casing_type(startloc)
	var/target_zone
	if(ismob(target))
		var/mob/target_mob = target
		target_zone = target_mob.get_random_valid_zone()
	else
		target_zone = ran_zone()
	casing.fire_casing(target, firer, null, null, null, target_zone, 0,  firer)
	casing.update_appearance()
	casing.temporary_atom(30 SECONDS)
	SEND_SIGNAL(parent, COMSIG_BASICMOB_POST_ATTACK_RANGED, target, modifiers)
	return


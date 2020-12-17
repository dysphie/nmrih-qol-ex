[NMRiH] Quality of Life (v2.0.3)
by Ryan.

https://forums.alliedmods.net/showthread.php?t=304638
https://steamcommunity.com/app/224260/discussions/0/1693785035825026880/


	This is a plugin for No More Room in Hell that attempts to fix bugs, make
	gameplay changes, and improve the quality of the game.

	It requires DHooks: https://forums.alliedmods.net/showthread.php?t=180114

	My deepest thanks to the NMRiH devs, Bubka3 and Felis, for their continued
	work on the game and for their support of this plugin.

	Huge thanks to everyone who helped test and provide feedback:
		Holy Crap
		MsDysphie
		Saref
		Demo
		924285802
		FerS
		yomox9
		Maxovich
		__itsme
		overmase
		mrpeanut188
		Kevin

	Additional thanks to the SourceMod team and Dr!fter.


Installation:

	Install Metamod Source: https://www.metamodsource.net/downloads.php
	Install Sourcemod: https://www.sourcemod.net/downloads.php
	Install DHooks extension: https://users.alliedmods.net/~drifter/builds/dhooks/2.2/
	Extract the contents of this archive into your nmrih/addons directory.


Features/changes

	Each of the following features has an associated ConVar that can be used to
	disable or alter the behaviour.

	Zombies:
		Fixes zombies grabbing players during cutscenes.
		Fixes zombies hurting player through some objects like doors.
		Fixes zombies hurting players that they have their back to.
		Fixes exploit where zombies won't attack when a prop is held within their hull.
		Prevents zombies from grabbing players in some situations where the player can't shove back.
		Reduced damage to barricades when hitting multiple at a time.

	National Guard:
		Option to toggle frag grenade spawning (legacy feature).

	Kids:
		Fixes boys T-posing when climbing.

	Player:
		Infected players won't reanimate if killed by 100 points of damage.
		Players can shove during ironsight animations.
		Player's shove hits more than one zombie.
		Players earn a kill on the scoreboard when suiciding and infected.

	Medicine:
		Sounds are audible to other players.
		Medical items can be equipped at any time to allow throwing.

	Barricade:
		Hammering sounds are emitted to other players.
		Damage is visualized through model darkening.
		New sounds when damaged or breaking.
		Nailed boards can be recollected with hammer's charged attack.

	Melee weapons:
		Charged melee hits only drain stamina once.
		Melee weapons ignore stamina drain on walls if at least one zombie was hit.
		Heavy melee weapons (fubar, sledge and pickaxe) use 20% of stamina cost on additional hits.

	Firearms/explosives:
		Arrows can be retrieved from doors and rotate with attached objects faithfully.
		TNT and frag grenades detonate slightly off-ground for improved effectiveness.
		Alternate explosion sounds (legacy feature).
		Players are awarded kills from gas can fires.
		Fixes board ammo that gave nothing.

	Other:
		Fixes misplaced map items being unobtainable.
		Fixes func_breakables damaging players when touched (glass roof on Brooklyn, vent on Fema, etc).
		Client command to fix ice-skating movement.
		Customizable grace period for spawning late-joining players.
		Exposes forwards for other Sourcemod plugins (see below).


ConVars

	qol_arrow_fix
		Allow arrows to rotate with doors, stick to brush entities and fixes arrows that could not be recollected.

	qol_barricade_damage_volume
		Volume of QOL barricade damage sounds. Use 0.0 for vanilla behavior.

	qol_barricade_hammer_volume
		Volume of barricade hammering sounds heard by players that are not barricading. E.g. 1.0 means full volume. Use 0.0 for vanilla behavior.

	qol_barricade_retrieve_health
		Minimum percent of full health a barricade must have to be recollectable via barricade hammer charge attack. E.g. 1.0 means full health. Use negative number for vanilla behavior (never recollect).

	qol_barricade_show_damage
		Visualize barricade health by darkening boards according to how much damage they've taken. The value represents what percent of black the model should be at 0 hit point left. E.g. 0.75 means 75% black at 0 hit point. Use 0.0 for vanilla behavior.

	qol_barricade_zombie_multihit_ignore
		Percent of damage barricades should ignore when they're hit by a zombie that isn't targeting them specifically. E.g. 0.75 reduces damage zombies do to barricade they currently are not targeting to 25%. Use 0.0 for vanilla behavior.

	qol_board_ammo_fix
		Repair board pickups that have 0 ammo.

	qol_count_fire_kills
		Award score to players that kill zombies with gas can fires.

	qol_count_infected_suicide_kill
		Award score to players that suicide while infected.

	qol_dropped_object_collision_fix
		Ensure prop's original collision group is restored after players drop it. This prevents solid props becoming non-solid after dropping them.

	qol_func_breakable_player_damage_fix
		Prevent players taking damage from touching func_breakables (glass roof on Brooklyn, vent on FEMA, etc).

	qol_grenade_rise
		Warp TNT and frag grenades slightly off ground at detonation to improve effectivness around clutter.

	qol_grenade_sounds
		Use QOL's legacy grenade sounds.

	qol_infection_bypass
		Damage amounts equal to or higher than this will prevent an infected player from reanimating. Use 0.0 for vanilla behavior (i.e. always reanimate).

	qol_ironsight_shove
		Allow player to shove while ironsight raising or lowering

	qol_kid_prevent_tpose
		Prevent kids T-posing when climbing.

	qol_late_join_spawn_grace
		Number of seconds after round start that late-joining players can still spawn.

	qol_medical_auto_switch_style
		How to handle auto-switching to medical items.
			0: Switch if medicine is heavier than current weapon.
			1: Switch if medicine is heavier than current weapon and is usable.
			2: Switch if medicine is usable (even if a heavier weapon exists).
			3: Never auto-switch to medical items.

	qol_medical_volume
		Volume of medical sounds heard by players not healing. E.g. 1.0 means full volume. Use 0.0 for vanilla behavior (no sounds).

	qol_medical_wield
		Allow players to wield medical items at any time (so they may be thrown).

	qol_melee_stamina_ignore_world
		Prevent the world from draining stamina in a melee attack if at least one zombie was hit.

	qol_melee_multihit_stamina_scale
		When a player hits more than one zombie with a melee weapon, the additional hits will have their stamina cost scaled by this amount. E.g. 0.2 means use 20% of weapon's swing cost. Use 1.0 for vanilla behavior.

	qol_melee_multihit_stamina_scale_charged
		When a player hits more than one zombie with a charged attack, the additional hits will have their stamina cost scaled by this amount. E.g. 0.0 means 0% of charged attack's cost. Use 1.0 for vanilla behavior.

	qol_melee_multihit_stamina_scale_heavy
		When a player hits more than one zombie with a fubar, sledge or pickaxe, the additional hits will have their stamina cost scaled by this amount. E.g. 0.2 means 20% of weapon's swing cost. Use 1.0 for vanilla behavior.

	qol_multishove_distance
		Distance to allow shove to hit more than one zombie. Use 0.0 for vanilla behavior (off).

	qol_multishove_max_pushed
		Maximum number of zombies player can push per shove. 0 means infinite. See qol_multishove_distance to disable.

	qol_national_guard_crawler_health
		National Guard crawler maximum health. Legacy option.

	qol_national_guard_drop_grenade
		Allow National Guard zombies to drop frag grenade (legacy option).

	qol_prevent_late_spawn_abuse
		Limit players to one late spawn per respawn event. I.e. players cannot abuse late spawn by dying and then reconnecting for a guaranteed late respawn."

	qol_respawn_ahead_threshold
		Players that spawn as early as this many seconds before a respawn event will automatically be teleported to the newer spawn points. This fixes players spawning at the wrong spawns.

	qol_respawn_grace
		Number of seconds after a respawn point that late-joining players can still spawn.

	qol_round_start_spawn_grace
		Number of seconds after round start that late-joining players can still spawn.

	qol_skate_cooldown
		Number of seconds player must wait between /skaterboy commands. Negative value to disable command.

	qol_stuck_object_fix
		Allow players to pickup items that are clipping into geometry. Fixes sprint-lock issue with supply crate.

	qol_sks_bayonet_sounds
		Play an extra sound when a zombie's head is stabbed with the bayonet.

	qol_weaponized_object_fix
		Prevent exploit that allows physics objects to damage players and zombies by being smashed into them.

	qol_nonsolid_supply
		Makes med-boxes, safe zone supply boxes and inventory boxes non-solid to avoid exploiting NPCs AI.

	qol_zombie_prevent_attack_backwards
		Prevent zombie swipe attacks damaging players directly behind the zombie.

	qol_zombie_prevent_attack_thru_walls
		Prevent zombies from hurting players through objects like doors.

	qol_zombie_prevent_grab_during_cutscene
		Disallow zombies from grabbing players while extraction cutscene is playing.

	qol_zombie_prop_exploit_fix
		Fix an exploit where zombies won't attack when an object is held within their hull.


Commands

	sm_skaterboy - Fix jittery ice-skating player movement.


Forwards

	// Called whenever a national guard spawns a loot drop.
	public void OnNationalGuardLoot(int national_guard, int loot);

	// Called whenever player consumes a medical item.
	public void OnPlayerUsedBandages(int player, int item);
	public void OnPlayerUsedPills(int player, int item);
	public void OnPlayerUsedFirstAid(int player, int item);
	public void OnPlayerUsedGeneTherapy(int player, int item);

	// Called when a player recollects a barricade board.
	public void OnBarricadeCollected(int player, int board);


Changelog

	2.0.3 - 2019-11-21
		Added qol_prevent_late_spawn_abuse as suggested by Holy Crap
			When enabled, players are eligible for late spawn once per respawn event. This means players cannot
			abuse the late spawn system by reconnecting after dying.

	2.0.2 - 2019-02-25
		Fix crash when changing medical item heal amount in "Weapon Configs" plugin
			https://forums.alliedmods.net/showthread.php?p=2628691
		Fix crash when choosing runners-only mode in "Difficulty and Mod Changer" plugin - Thanks Kevin
			https://forums.alliedmods.net/showthread.php?p=2549109

	2.0.1 - 2018-10-26
		Fixed /skaterboy breaking during pre-round freeze time - Thanks Holy Crap
		Fixed cvar typo in readme - Thanks mrpeanut188

	2.0.0 - 2018-10-13
		New release to work with NMRiH update 1.1.0.
		QOL's weapon speed configuration system has been stripped for later release as its own plugin.
		Added qol_dropped_object_collision_fix to prevent solid props becoming non-solid after handling them.
		Added qol_count_infected_suicide_kill to award players a point for suiciding while infected.
		Added qol_func_breakable_player_damage_fix to stop func_breakables from damaging players on touch (glass roof on Brooklyn, vent in Fema, etc).
		Added qol_zombie_prop_exploit_fix to prevent exploit where zombies won't attack when an object is held within their hull.
		Added qol_zombie_prevent_attack_backwards to prevent zombie swipes damaging players standing behind the zombie.

	0.7.10
		Bow changed to use "sight", "unsight" and "sight_fire" weapon config values (previously used "hip_fire").
		Changed grenades to use the "charge" and "release" weapon config values (previously used "hip_fire").
		Increased max animation speed limit from 4x to 10x.
		Fixed fire extinguisher sound playing if it was dropped.
		Fixed bug caused by reselecting same weapon.

	0.7.9
		Added qol_zombie_max_bash_distance.
			Defines maximum distance that zombies will attack barricade.
			Zombies could get stuck in a bash/abort loop with old hardcoded distance (32).
		Added OnBarricadeCollected() forward to cooperate with Barricade Anywhere plugin.
		Fixed Physical Mayhem issue.
			Now call CBaseEntity::SetCollisionGroup() directly.
		Fixed prop unstick acting on items held by other players.

	0.7.8
		Added fix for infection not killing players when sv_friendly_fire_factor is below 0.01 (qol_friendly_fire_infection_fix).
		Fixed QOL spawning players in previous spawn area on some maps. (E.g. quarantine, shelter, toxteth.)
			qol_respawn_ahead_threshold is the number of seconds players may spawn prior to a respawn event and still be advanced to the next spawn area. This can be increased if other maps still cause the issue.
		Fixed QOL audible bleedout playing male pain sounds on female characters.

	0.7.7
		Fixed players spawning beneath the world.

	0.7.6
		Skip nearby zombie check for late-connect player spawning.
			Some maps (like nmo_zephyr) have their spawn points close enough to zombie spawns that the spawns wouldn't be used.
		Fixed another invalid ent access regarding player pickups.

	0.7.5
		Made thrown explosives ignore qol_grenade_rise when a player is holding it.
			This way players won't be surprised when a bomb they're holding in a safe position moves at the last second.
		Fix invalid ent access with player pickups.
		Fix issues with late-connect spawning:
			Fix qol_round_start_spawn_grace sometimes not working during pre-round freeze time.
			Fix qol_respawn_grace allowing living players to respawn when sv_realism should've prevented it.
			Fix 'kill' command allowing players to respawn even after qol_respawn_grace expired.
			Treat newly created spawn points as respawn events. (E.g. nmo_suzhou)
			Allow late-connect spawning on maps that disable/remove spawn points. (E.g. nmo_suzhou)

	0.7.4
		Fix air-dropped inventory boxes blocking zombie attacks even when qol_zombie_attack_thru_supply was on.

	0.7.3
		Added qol_respawn_grace to control number of seconds after a respawn event that late-joining players can still spawn.
			Living players are allowed to respawn once during this grace period.
		Made FEMA bags respect qol_zombie_attack_thru_supply setting.

	0.7.2 beta
		Added qol_round_start_spawn_grace to control number of seconds after round start that late-joining players can still spawn.
		Added option to allow players to push more than one zombie per shove:
			ConVar qol_multishove_distance controls distance of trace used for find extra zombies to shove.
			ConVar qol_multishove_max_pushed sets max number of zombies that can be shoved. 0 means unlimited.
		Default qol_weapon_config changes:
			Increased ironsight speed of ironsighted-Sako by 15%.
			Crowbar cooldown changed from -0.2 to -0.1 seconds.
			Kitchen knife and cleaver cooldown changed from -0.5 to -0.4 seconds.
			Restored lead pipe cooldown to vanilla speed.

	0.7.1 beta
		Added control over maglite and secondary attack animation speeds.
		Fixed speed control for medical items.

	0.7.0 beta
		Removed animation speed convars:
			qol_fubar_charge_rateqol_fubar_charge_rate
			qol_sv10_reload_rate
			qol_sv10_reload_rate_empty
		Added configurable weapon speed system:
			ConVar qol_weapon_config names the active file under sourcemod/configs
			The config sets animation rates on a per-weapon and per-action basis.
			Default "qol" weapon config:
				Decreases time till next attack for most melee weapons to better match their visible readiness.
				SV10 reloads 16% faster.
				Fubar and barricade hammer charge wind-up is 15% faster.
				Knife and cleaver charge attack is 6% faster with 0.2 second shorter transition delay.
				Revolver ironsight raise 30% faster.
				Revolver shoots 20% faster in ironsights.
			Feature can be disabled in its entirety by assigning qol_weapon_config an empty string.
		Added qol_ironsight_shove which allows players to shove during ironsight raise/lower animations.
		Improved stuck object detection:
			Compares object's position between two frames to see if has moved.
			Previous hull-tracing system had issues with displacements.
		Changed qol_kid_prevent_tpose to hopefully cooperate with custom zombie dog plugin.

	0.6.1 beta
		Added qol_medical_auto_switch_style to control auto-switching to medical items:
			0 = Switch if medicine is heavier than current weapon.
			1 = Switch if medicine is heavier than current weapon and is usable.
			2 = Switch if medicine is usable (even if a heavier weapon exists).
			3 = Never auto-switch to medical items.
		Added qol_maglite_stay_on to prevent maglite turning off when an unequipped weapon is dropped.
		Changed object-unsticking feature so it never frees objects by "pushing" them.
			Players reported that objective items could sometimes be pushed through the world.

	0.6.0 beta
		Medical use sounds are now audible to other players.
		Added sounds to fire extinguisher spray.
		Added barricade damage sounds.
		Added visualization of barricade damage. (Boards darken according to health remaining.)
		Added option to scale damage zombies deal to barricades that are not their primary target.
		Added option to emit barricading sounds from other players.
		Added ability to recollect placed boards with hammer's charged attack.
		Added fix for exploit where two players could alter physics props to be solid and act like a weapon.
		Added ConVar to prevent grabbing during cutscene (previously always on).
		Changed qol_infection_bypass from boolean to damage threshold:
			Damage greater or equal to this will prevent infected players from reanimating.
			Previous hard-coded value of 100.0 is used as default.
			Use 0.0 to always reanimate (vanilla behavior).
		Fixed zombies continuing to bash barricades from any distance after shoved away.
		Fixed barricade sound continuing to play after player dies.
		Fixed bleedout sounds from other players being heard everywhere.
		Fixed more T-pose activites on kids.
		Fixed infection bypass happening too early. (Prevented pills from being useable.)
		Fixed object unsticking preventing safe zone repair bags from working.

	0.5.1 beta
		Fixed late load hooking connecting players too early.
		Fixed phantom medical items assuming previous weapon exists.

	0.5.0 beta
		Added option to prevent inventory/med-box/safezone-supply exploit where zombies wouldn't attack players.
		Added option to emit bleedout sounds from other players.
		Added National Guard crawlers.
		Added ConVars to control scale of stamina drained by multi-hits for:
			Any charged melee attack
			Quick attack with fubar, sledge and pickaxe
			Quick attack with other melee weapons
		Changed QOL's default SV10 reload boost from 40% to 16%.

	0.4 beta
		Added fix for zombies that fixate on object instead of attacking player.
		Added ConVars to remaining features.
		Fixed kid zombie rapid fire attacking barricades when player was occluded.
		Fixed potential issue with pills being unusable.

	0.3 beta
		Added ConVars for most features.
		Plugin uses config exported to nmrih/sourcemod/cfg.
		Fixed kid zombies attacking barricades from far away.

	0.2 beta
		Fixed invalid ent indexing while repairing ammo with 0 amount.

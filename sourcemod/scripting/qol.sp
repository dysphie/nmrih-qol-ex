// Quality of Life plugin for No More Room in Hell
// By Ryan.
//
// * Zombies won't damage players through objects like doors.
// * Zombie swipes won't hit players standing behind them.
// * Zombies won't grab players during extraction cutscenes.
// * Zombies won't grab players in situations where the player can't shove back.
// * Kid zombies don't T-pose when climbing.
// * Bandages, pills, and first aid are always equippable to allow throwing. (They remain unusable if they would have no effect.)
// * Arrows can be retrieved from props. (Previous behaviour caused desync between arrow model and arrow entity.)
// * Arrows follow attached objects faithfully. (Previous behaviour only tracked rotation and didn't handle brush entities.)
// * Grenade throwing sounds.
// * TNT and frag grenades play alternate explosion sounds.
// * TNT and frag grenades warp slightly off-ground at detonation for improved effectiveness around clutter.
// * Zombies killed by gascan fires attribute kills to the instigating player.
// * Infected players that are killed by substanial damage will not reanimate. The "kill" console command acts the same.
// * Fixes misplaced map items being unobtainable.
// * Fixes board ammo pickups that didn't give ammo.
// * Heavy melee weapons (fubar, sledge and pickaxe) only drain stamina on first hit of swing.
// * Other melee weapons ignore stamina drain on wall impact if at least one zombie was hit.
// * Barricades visualize remaining hit points by darkening.
// * Barricades play sound effects when damaged and break.
// * Barricade hammer sounds are emitted to other players.
// * Barricade boards can be recollected with barricade hammer's charged attack.
// * Medical items play sounds for other players to hear.
// * Fix for exploit where physics objects can be used as weapons.
// * Fix for exploit where physics objects can be used to disable zombies.
// * Fix for bug where physics objects lose their original collision properties after being carried by multiple people.
// * Fix players taking damage from touching func_breakables (glass roof on Brooklyn, vent on Fema, etc).
// * Allow players to shove during ironsight raise/lower animation.
// * Allow players' shove to hit multiple zombies.
// * Allow late-joining players to spawn during a customizable grace period.
// * Client command to fix ice-skating movement.
// * Exposes forwards for other Sourcemod scripts.
//

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#include <dhooks>

#pragma semicolon 1

#define QOL_VERSION "2.0.3"
#define QOL_TAG "qol"
#define QOL_LOG_PREFIX "[QOL]"

#define LOOT_DROP_MAX_DISTANCE 64.0
#define LOOT_DROP_MAX_DISTANCE_SQUARED (LOOT_DROP_MAX_DISTANCE * LOOT_DROP_MAX_DISTANCE)

#define CLASSNAME_MAX 128

#define SHUFFLE_SOUND_COUNT 2

#define SOUND_GRENADE_THROW "weapons/slam/throw.wav"

// Sequences used during zombie bite.
#define SEQUENCE_CRAWLER_BITE 9
#define SEQUENCE_BITE 31
#define SEQUENCE_SHAMBLER_BITE 32
#define SEQUENCE_RUNNER_BITE 33

// Sequence used by barricade hammer when placing a board.
#define SEQUENCE_BARRICADE_HAMMER_BARRICADE 16

// Zombie schedules.
#define SCHED_ZOMBIE_CHASE_ENEMY 17
#define SCHED_ZOMBIE_MELEE_ATTACK1 41   // When a zombie tries to melee a player.
#define SCHED_ZOMBIE_SWATITEM  93       // When a zombie goes to swat/bash a prop.
#define SCHED_ZOMBIE_ATTACKITEM 94      // Zombie swipes at a prop.
#define SCHED_ZOMBIE_BASH_BARRICADE 102 // When a zombie bashes/attacks boards
#define SCHED_ZOMBIE_GRAB_ENEMY  106    // When a zombie tries to grab a player

// Zombie activities.
#define ACT_WALK 6
#define ACT_CLIMB_UP 41
#define ACT_MELEE_ATTACK1 71
#define ACT_SHOVE 961
#define ACT_SHOVE_LEFT 962
#define ACT_SHOVE_RIGHT 963
#define ACT_SHOVE_BEHIND 964

// Collision groups.
#define COLLISION_GROUP_NONE 0
#define COLLISION_GROUP_DEBRIS 1
#define COLLISION_GROUP_CARRIED_OBJECT 34
#define COLLISION_GROUP_INVENTORY_BOX 34
#define COLLISION_GROUP_HEALTH_STATION 36
#define COLLISION_GROUP_SAFEZONE_SUPPLY 37

// AI conditions.
#define COND_CAN_MELEE_ATTACK1 23
#define COND_TOO_FAR_TO_ATTACK 39

#define STATE_ACTIVE 0  // Player state code used by living players.

#define GAME_TYPE_OBJECTIVE 0
#define GAME_TYPE_SURVIVAL 1

#define OBJECTIVE_STATE_EXTRACTED 5
#define OBJECTIVE_STATE_OVERRUN 6

#define SURVIVAL_STATE_EXTRACTED 4
#define SURVIVAL_STATE_OVERRUN 7

#define DMG_CONTINUAL_BURNING (DMG_BURN | DMG_DIRECT)

// Symbolic constants for indexing vectors.
#define X 0
#define Y 1
#define Z 2

// Symbolic names for GetVectorDistance.
#define SQUARED_DISTANCE true
#define UNSQUARED_DISTANCE false

// Symbolic names for KeyValues traversal.
#define KEYS_ONLY true
#define KEYS_AND_VALUES false

#define IGNORE_CURRENT_WEAPON (1 << 7)

#define SIZEOF_VECTOR 12

// Boom!
static const char SOUNDS_EXPLODE[][] =
{
    "weapons/explode3.wav",
    "weapons/explode4.wav",
    "weapons/explode5.wav"
};

// Mid-distance explosion.
static const char SOUNDS_TNT_MID[][] =
{
    "ambient/explosions/explode_8.wav",
    "ambient/explosions/explode_9.wav"
};

// Distant rumble.
static const char SOUNDS_TNT_DISTANT[][] =
{
    "ambient/explosions/exp1.wav",
    "ambient/explosions/exp2.wav"
};

// Distant rumble.
static const char SOUNDS_FRAG_DISTANT[][] =
{
    "weapons/firearms/exp_frag/frag_explode1.wav",
    "weapons/firearms/exp_frag/frag_explode2.wav",
    "weapons/firearms/exp_frag/frag_explode3.wav"
};

// Extra sound played when head is stabbed (for player feedback).
static const char SOUNDS_SKS_STAB_HEAD[][] =
{
    "weapons/firearms/sks_bayonet_hit1.wav",
    "weapons/firearms/sks_bayonet_hit2.wav",
};

// Barricade takes damage.
static const char SOUNDS_BARRICADE_DAMAGE[][] =
{
    "weapons/melee/hammer/board_damage-light1.wav",
    "weapons/melee/hammer/board_damage-light2.wav",
    "weapons/melee/hammer/board_damage-light4.wav",
    "weapons/melee/hammer/board_damage-heavy1.wav",
    "weapons/melee/hammer/board_damage-heavy2.wav",
    "weapons/melee/hammer/board_damage-heavy3.wav"
};

// Barricade is destroyed.
static const char SOUNDS_BARRICADE_BREAK[][] =
{
    "weapons/melee/hammer/board_damage-broken1.wav",
    "weapons/melee/hammer/board_damage-broken2.wav"
};

// Entity types that National Guards can spawn.
static const char NATIONAL_GUARD_DROPS[][] =
{
    "item_ammo_box",
    "item_bandages",
    "fa_m92fs",
    "exp_grenade"
};

static const char SOUND_NULL[] = "common/null.wav";
static const char SOUND_BARRICADE_COLLECT[] = "weapons/melee/hammer/board_damage-light3.wav";

static const char WEAPON_FISTS[] = "me_fists";
static const char WEAPON_FUBAR[] = "me_fubar";
static const char WEAPON_SLEDGE[] = "me_sledge";
static const char WEAPON_PICKAXE[] = "me_pickaxe";
static const char WEAPON_BARRICADE[] = "tool_barricade";
static const char WEAPON_SKS[] = "fa_sks";

static const char ITEM_MAGLITE[] = "item_maglite";
static const char ITEM_ZIPPO[] = "item_zippo";
static const char ITEM_BANDAGES[] = "item_bandages";
static const char ITEM_PILLS[] = "item_pills";
static const char ITEM_FIRST_AID[] = "item_first_aid";
static const char ITEM_GENE_THERAPY[] = "item_gene_therapy";

static const char PROJECTILE_ARROW[] = "projectile_arrow";
static const char PROJECTILE_FRAG[] = "grenade_projectile";
static const char PROJECTILE_TNT[] = "tnt_projectile";
static const char PROJECTILE_MOLOTOV[] = "molotov_projectile";

static const char INVENTORY_BOX[] = "item_inventory_box";
static const char SAFEZONE_SUPPLY_PREFIX[] = "nmrih_safezone_supply";
static const char HEALTH_STATION_PREFIX[] = "nmrih_health_station";

static const char PLAYER_PICKUP[] = "player_pickup";
static const char PLAYER_SPAWN_POINT[] = "info_player_nmrih";

static const char PROP_NAME_PLAYER_AMMO[] = "m_iAmmo";

static const char MODEL_ZOMBIE_KID_BOY[] = "models/nmr_zombie/zombiekid_boy.mdl";
static const char MODEL_ZOMBIE_KID_GIRL[] = "models/nmr_zombie/zombiekid_girl.mdl";

public Plugin myinfo =
{
    name = "[NMRiH] Quality of Life",
    author = "Ryan",
    description = "Fixes bugs, adds features, improves No More Room in Hell!",
    version = QOL_VERSION,
    url = ""
};

enum PropVictim
{
    PROP_VICTIM_ENT_REF,    // int
    PROP_VICTIM_ATTACKER,   // int

    PROP_VICTIM_TUPLE_SIZE
};

enum ZombieTuple
{
    ZOMBIE_ENT,
    ZOMBIE_HOOKID,

    ZOMBIE_TUPLE_SIZE
};

enum QOL_WeaponType
{
    WEAPON_TYPE_OTHER,
    WEAPON_TYPE_BARRICADE,
};

enum MedicalAutoSwitch
{
    MEDICAL_AUTO_SWITCH_VANILLA = 0,                // Switch to medical item when it weighs more than current weapon.
    MEDICAL_AUTO_SWITCH_IF_USABLE_AND_HEAVIER = 1,  // Switch to medical item when it weighs more than current weapon and is usable by player.
    MEDICAL_AUTO_SWITCH_IF_USABLE = 2,              // Switch to medical item when it is usable by player (even if a heavier weapon exists).
    MEDICAL_AUTO_SWITCH_NEVER = 3,                  // Never consider medical weapons for auto switch.
};

enum PropCollisionTuple
{
    PROP_COLLISION_ENT_REF,     // int - Ent reference
    PROP_COLLISION_GROUP,       // int - Original collision group

    PROP_COLLISION_TUPLE_SIZE
};

bool g_plugin_loaded_late = false;

//
// QOL globals
//

int g_model_zombie_kid_boy = 0;     // Model index of boy zombie kid.
int g_model_zombie_kid_girl = 0;    // Model index of girl zombie kid.

bool g_map_loaded = false;          // True between OnMapStart() and OnMapEnd()
bool g_in_cutscene = false;
bool g_last_wave_was_resupply;      // True if the last survival wave was a resupply.
float g_round_reset_time = -1.0;
float g_round_start_time = 0.0;
float g_round_end_time = 0.0;
float g_last_respawn_time = 0.0;    // GameTime of last respawn event.
bool g_force_respawn = true;        // When true, late-connecting players will be respawned even when realism is on. Set to true at the end of a resupply wave.
int g_score_adder = -1;             // Ent reference to game_score used to count fire-based kills.
int g_board_spawner_ref = -1;       // Ent reference to random_spawner that spawns board ammo.

StringMap g_medical_sounds;         // Maps weapon name to DataPacks of sounds played during medical animation.
ArrayList g_dead_national_guard;    // For backwards compatibility with any plugins using QOL's forward.
ArrayList g_zombie_prop_victims;    // Zombies hurt by explosive props: tuples of (zombie id, id of client that attacked)
ArrayList g_arrow_projectiles;      // References to live arrow projectiles.
ArrayList g_spawning_ammo_boxes;    // References to ammo boxes currently being spawned.
ArrayList g_multishove_zombies;     // Stores ent indices of zombies hit by potential multishove.
ArrayList g_carried_props;          // List of PropCollisionTuple. Stores props and their collision group before pickup.
ArrayList g_spawn_point_copies;     // Ent references to copies of the last batch of enabled/spawned spawn points.
ArrayList g_steam_ids_of_late_spawned_players; // Steam account IDs of all players respawned since the last respawn point

bool g_player_can_late_spawn[MAXPLAYERS + 1];           // Whether player joined within spawn grace period and will respawn.
int g_player_melee_ents_hit[MAXPLAYERS + 1];            // Number of NPCs the player's current melee trace has hit.
bool g_player_melee_hit_world[MAXPLAYERS + 1];          // Whether a player's current melee trace has hit the world.
float g_player_last_melee_times[MAXPLAYERS + 1];        // GameTime of player's last stamina-draining melee attack.
float g_player_melee_previous_stamina[MAXPLAYERS + 1];  // Amount of stamina player had before melee attack.
float g_player_melee_stamina_cost[MAXPLAYERS + 1];      // Holds the amount of stamina the player's current melee attack drains per hit.
int g_player_last_zombie_shoved[MAXPLAYERS + 1];        // Ent reference to last zombie each player shoved.
float g_player_spawn_times[MAXPLAYERS + 1];             // GameTime that each player spawned at.

QOL_WeaponType g_player_weapon_type[MAXPLAYERS + 1];

float g_player_next_bash_time[MAXPLAYERS + 1];          // Assigned a GameTime right before sighting/unsighting to players can shove during ironsight animation.

float g_player_barricade_time[MAXPLAYERS + 1] = { 0.0, ... };   // Last idle time of hammer player barricaded with.
float g_player_unbarricade_time[MAXPLAYERS + 1] = { 0.0, ... };   // Last idle time of hammer player un-barricaded with.

bool g_player_do_pickup_fix[MAXPLAYERS + 1] = { false, ... };   // Used to disable pickup unsticking for one frame.
float g_player_pickup_origins[MAXPLAYERS + 1][3];               // Origin of players' pickup previous frame.

float g_player_last_skate_time[MAXPLAYERS + 1] = { 0.0, ... };
bool g_skating_player_respawning[MAXPLAYERS + 1] = { false, ... };
DataPack g_skating_player_data[MAXPLAYERS + 1] = { null, ... };

//
// Ent-data offsets
//

int g_offset_gametrace_ent;                     // Offset of m_pEnt in CGameTrace.
int g_offset_is_crawler;                        // Offset of crawler boolean in zombie data.
int g_offset_is_national_guard;                 // Offset of National Guard boolean in zombie data.
int g_offset_barricade_point_physics_ent;       // Offset of m_hPropPhysics in CNMRiH_BarricadePoint.
int g_offset_playerspawn_enabled;               // Offset of m_bEnabled in CNMRiH_PlayerSpawn.
int g_offset_player_state;                      // Offset of m_iPlayerState in CSDKPlayer.
int g_offset_original_collision_group;          // Offset of m_iOriginalCollisionGroup in CBaseEntity.

//
// DHook handles
//

Handle g_dhook_next_best_weapon;                // Handle auto-switching to medical weapons.
Handle g_dhook_allow_late_join_spawning;        // Allow late-joining players to spawn within grace period.
Handle g_dhook_any_spawn_point_for_skater;      // Allows skating players to immediately respawn.
Handle g_dhook_is_copied_spawn_point_clear;     // Skips nearby zombie check for copied spawn points.

Handle g_dhook_handle_medical_autoswitch_to;    // Handle whether medical items can be auto-switched to.
Handle g_dhook_call_medical_item_forward;       // Notify other scripts that a medical item was just used.
Handle g_dhook_allow_any_medical_wield;         // Allows medical items to be wielded any time (but still respects consume rules).

Handle g_dhook_weapon_pre_sight_toggle;
Handle g_dhook_weapon_post_sight_toggle;

Handle g_dhook_weapon_multishove;               // Allow players to shove many zombies at once.

Handle g_dhook_grenade_detonate;                // Improved grenade explosions and sounds (frag and TNT).

Handle g_dhook_melee_stamina_drain;             // Prevent walls from draining stamina if at least one zombie was hit.
Handle g_dhook_heavy_melee_stamina_drain;       // Limit heavy melee weapons to draining stamina once per swing.

Handle g_dhook_fix_kid_shove_activity;          // Reuse forward shove animation for other shove directions to prevent T-posing.
Handle g_dhook_forbid_zombie_climb_activity;    // Disable climb animation (for crawlers and kids).
Handle g_dhook_on_zombie_shoved;                // Store reference to last zombie each player shoved.
Handle g_dhook_fix_zombie_item_exploit;         // Allow zombies to attack when an item is held within their hull.


//
// SDK call handles
//

Handle g_sdkcall_select_weighted_sequence;      // Used to check if an activity exists.
Handle g_sdkcall_weapon_has_ammo;               // Returns true if a weapon has ammo or doesn't need ammo.
Handle g_sdkcall_get_item_weight;               // Get an item's weight (this is the item's inventory weight and auto-switch priority).
Handle g_sdkcall_player_bleedout;               // Makes a player bleedout. void CNMRiH_Player::Bleedout(void)
Handle g_sdkcall_player_become_infected;        // Makes a player infected. void CNMRiH_Player::BecomeInfected(void)
Handle g_sdkcall_player_respawn;                // Causes a player to respawn. Could be replaced with Sourcemod native DispatchSpawn().
Handle g_sdkcall_set_entity_collision_group;    // Change an entity's collision group.
Handle g_sdkcall_is_npc;                        // Check if a CBaseEntity is an NPC.
Handle g_sdkcall_is_combat_weapon;              // Check if a CBaseEntity is an item.
Handle g_sdkcall_set_parent;                    // Setup an entity to have a parent. void CBaseEntity::SetParent(CBaseEntity *, int)
Handle g_sdkcall_are_tokens_given_from_kills;   // Check whether game mode is using tokens.
Handle g_sdkcall_get_player_spawn_spot;         // Move player to an available spawn spot.
Handle g_sdkcall_shove_zombie;                  // Push a zombie away from an entity.

Handle g_forward_national_guard_loot_spawn;     // Called whenever a National Guard drops an item.
Handle g_forward_used_bandages;                 // Called whenever player uses bandages.
Handle g_forward_used_pills;                    // Whenever player uses pills.
Handle g_forward_used_first_aid;                // First aid.
Handle g_forward_used_gene_therapy;             // Gene.
Handle g_forward_barricade_collected;           // Called whenever player recollects a placed barricade. Receives: int client, int barricade.

// Quality of Life convars.
ConVar g_qol_round_start_spawn_grace;           // Number of seconds after round start that connecting players will still be allowed to spawn.
ConVar g_qol_respawn_grace;                     // Number of seconds after a respawn that connecting players will still be allowed to spawn.
ConVar g_qol_respawn_ahead_threshold;           // Players that spawn this many seconds before a respawn event will be teleported to the newer respawn points.
ConVar g_qol_prevent_late_spawn_abuse;          // When non-zero, late spawned players are added to a list. The players on that list will not be late-spawned if they reconnect. The list is cleared at each respawn event.
ConVar g_qol_skate_cooldown;                    // Time in seconds between de-skate commands.
ConVar g_qol_barricade_damage_volume;           // Controls volume of new barricade damage sounds.
ConVar g_qol_barricade_hammer_volume;           // Controls volume of barricade sounds heard by non-barricading players.
ConVar g_qol_barricade_retrieve_health;         // Minimum percent of health a barricade can and still be recollected with the barricade hammer.
ConVar g_qol_barricade_show_damage;             // Darken boards according to their damage amount.
ConVar g_qol_barricade_zombie_multihit_ignore;  // Percent of damage barricades should ignore when they're hit by a zombie that isn't targetting that particular barricade.
ConVar g_qol_func_breakable_player_damage_fix;  // Prevent func breakables from hurting players when they touch.
ConVar g_qol_infection_bypass;                  // Amount of damage an infected player must take in one pass to skip reanimating.
ConVar g_qol_count_fire_kills;                  // Award player score for killing zombies by fire.
ConVar g_qol_count_infected_suicide_kill;       // Award score to players that suicide while infected.
ConVar g_qol_stuck_object_fix;                  // Allow players to pickup stuck objects (also fixes supply crate locking player sprint).
ConVar g_qol_weaponized_object_fix;             // Prevent exploit that allows carried physics props to damage players and zombies.
ConVar g_qol_dropped_object_collision_fix;      // Maintain an object's original collision properties even if multiple players try to pick it up.
ConVar g_qol_nonsolid_supply;                   // Legacy option that makes all supply boxes debris so players can walk through them.
ConVar g_qol_zombie_prop_exploit_fix;           // Fix exploit where zombies don't attack when an item is held inside of their body.
ConVar g_qol_zombie_prevent_attack_backwards;   // Prevent zombies' swipes damaging players behind them.
ConVar g_qol_zombie_prevent_attack_thru_walls;  // Prevent zombies biting or hurting players thru objects like fences and doors.
ConVar g_qol_zombie_prevent_grab_during_cutscene; // Prevent zombies grabbing players during cutscenes.
ConVar g_qol_kid_prevent_tpose;                 // Prevent kids T-posing from basing barricades or being shoved from side/back.
ConVar g_qol_national_guard_crawler_health;     // Amount of health crawler versions of National Guard have.
ConVar g_qol_national_guard_drop_grenade;       // Allow National Guard can drop a frag grenade.
ConVar g_qol_arrow_fix;                         // Whether to fix arrow behaviour (rotation, brush entities and desync issues).
ConVar g_qol_board_ammo_fix;                    // Repair boards that have 0 ammo.
ConVar g_qol_grenade_rise;                      // Warp grenades off ground for improved effectiveness.
ConVar g_qol_grenade_sounds;                    // Play sounds on grenades.
ConVar g_qol_ironsight_shove;                   // Whether to allow shoving during ironsight up/down animation.
ConVar g_qol_melee_stamina_ignore_world;        // Prevent stamina drain when world is hit in melee attack.
ConVar g_qol_melee_multihit_stamina_scale;      // Scale stamina cost of melee weapons by this much after the first hit.
ConVar g_qol_melee_multihit_stamina_scale_charged;// Scale stamina cost of charged attack this much after the first hit.
ConVar g_qol_melee_multihit_stamina_scale_heavy;// Scale stamina cost of heavy weapons by this much after the first hit (fubar, sledge and pickaxe).
ConVar g_qol_multishove_distance;               // Distance to allow player shove to hit multiple zombies.
ConVar g_qol_multishove_max_pushed;             // Maximum number of zombies to push when multi-shove is enabled.
ConVar g_qol_sks_bayonet_sounds;                // Play extra headstab sound on bayonet stab.
ConVar g_qol_medical_auto_switch_style;         // How to handle auto-switching to medical items.
ConVar g_qol_medical_volume;                    // Volume of medical sounds as heard by other players.
ConVar g_qol_medical_wield;                     // Whether to allow any medical item to be equipped.

// NMRiH convars.
ConVar g_sv_tags;
ConVar g_sv_difficulty;
ConVar g_sv_realism;
ConVar g_sv_max_stamina;
ConVar g_sv_stam_regen_moving;
ConVar g_sv_zombie_reach;
ConVar g_sv_barricade_health;
ConVar g_cl_barricade_board_model;

/**
 * Check if the plugin is loading late.
 */
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    g_plugin_loaded_late = late;
}

/**
 * Forbid medical items from being auto-switched to. (ConVar)
 *
 * Native signature:
 * bool CBaseCombatWeapon::AllowsAutoSwitchTo() const
 */
public MRESReturn DHook_MedicalAutoSwitchTo(int medicine, Handle return_handle)
{
    MRESReturn result = MRES_Ignored;

    MedicalAutoSwitch style = view_as<MedicalAutoSwitch>(g_qol_medical_auto_switch_style.IntValue);
    if (style >= MEDICAL_AUTO_SWITCH_NEVER)
    {
        // Never auto-switch to medical items.
        DHookSetReturn(return_handle, false);
        result = MRES_Override;
    }
    else if (style > MEDICAL_AUTO_SWITCH_VANILLA)
    {
        // Auto-switch if player can use it.
        bool allow_switch = false;
        int player = GetEntOwner(medicine);

        char classname[CLASSNAME_MAX];
        if (IsClassnameEqual(medicine, classname, sizeof(classname), ITEM_BANDAGES))
        {
            allow_switch = IsClientBleeding(player);
        }
        else if (StrEqual(classname, ITEM_FIRST_AID))
        {
            allow_switch = GetClientHealth(player) < GetEntProp(player, Prop_Data, "m_iMaxHealth");
        }
        else
        {
            allow_switch = IsClientInfected(player);
        }

        if (!allow_switch)
        {
            DHookSetReturn(return_handle, false);
            result = MRES_Override;
        }
    }

    return result;
}

/**
 * Forwards to other scripts that might be interested in exact moment
 * player consumes a medical item.
 *
 * This is a legacy feature of old QOL.
 *
 * Native signature:
 * void CNMRiH_BaseMedicalItem::ApplyMedicalItem(void)
 */
public MRESReturn DHook_CallMedicalItemForward(int medicine, Handle return_handle)
{
    int owner = GetEntOwner(medicine);
    if (owner > 0 && owner <= MaxClients && IsClientInGame(owner))
    {
        Handle call = null;

        char classname[CLASSNAME_MAX];
        if (IsClassnameEqual(medicine, classname, sizeof(classname), ITEM_BANDAGES))
        {
            call = g_forward_used_bandages;
        }
        else if (StrEqual(classname, ITEM_PILLS))
        {
            call = g_forward_used_pills;
        }
        else if (StrEqual(classname, ITEM_FIRST_AID))
        {
            call = g_forward_used_first_aid;
        }
        else if (StrEqual(classname, ITEM_GENE_THERAPY))
        {
            call = g_forward_used_gene_therapy;
        }

        if (call)
        {
            any ignored;
            Call_StartForward(call);
            Call_PushCell(owner);
            Call_PushCell(medicine);
            Call_Finish(ignored);
        }
    }

    return MRES_Ignored;
}

/**
 * Allow medical items to be equipped any time. (ConVar)
 *
 * Native signature:
 * bool CNMRiH_BaseMedicalItem::ShouldUseMedicalItem(void) const
 */
public MRESReturn DHook_OnAttemptMedicalUse(int medicine, Handle return_handle)
{
    MRESReturn result = MRES_Ignored;

    int owner = GetEntOwner(medicine);

    // Allow any medical item to be equipped.
    if (medicine != GetClientActiveWeapon(owner))
    {
        if (g_qol_medical_wield.BoolValue)
        {
            DHookSetReturn(return_handle, 1);
            result = MRES_Override;
        }
    }
    else if (DHookGetReturn(return_handle))
    {
        StartMedicalSounds(owner, medicine);
    }

    return result;
}

/**
 * Start watching the weapon's sequence and playing the client's sounds
 * to everyone else.
 *
 * Also handle playback speed change of medical animations. Medical items
 * use two animations Once the first animation ends the playback speed
 * is reset to 1.0. To prevent this, we reset the playback speed to the
 * custom value when the sequence starts.
 *
 * @param client    ID of client using medicine.
 * @param medicine  ID of medical item being used.
 */
void StartMedicalSounds(int client, int medicine)
{
    char classname[CLASSNAME_MAX];
    GetEdictClassname(medicine, classname, sizeof(classname));

    DataPack medical_data = null;
    g_medical_sounds.GetValue(classname, medical_data);

    DataPack data = CreateDataPack();
    data.WriteCell(medical_data);   // possibly null
    data.WriteCell(client);
    data.WriteCell(EntIndexToEntRef(medicine));
    data.WriteFloat(-1.0);  // sequence start time (currently unknown)

    // Frame of the last sound we emitted to others.
    int last_sound_frame = -1;
    data.WriteCell(last_sound_frame);

    OnFrame_ContinueMedicalSounds(data);
}

/**
 * Called each frame to see how far along the player is in sequence
 * and whether a new sound should be emitted.
 */
public void OnFrame_ContinueMedicalSounds(DataPack data)
{
    data.Reset();

    int sequence = -1;
    int fps = -1;

    DataPack medical_data = data.ReadCell();
    if (medical_data)
    {
        medical_data.Reset();
        sequence = medical_data.ReadCell();
        fps = medical_data.ReadCell();
    }

    int client = data.ReadCell();
    int medicine = EntRefToEntIndex(data.ReadCell());

    DataPackPos start_time_pos = data.Position;
    float start_time = data.ReadFloat();

    DataPackPos last_sound_frame_pos = data.Position;
    int last_sound_frame = data.ReadCell();

    bool check_again = false;

    if (IsClientInGame(client) &&
        IsPlayerAlive(client) &&
        medicine != INVALID_ENT_REFERENCE &&
        GetClientActiveWeapon(client) == medicine)
    {
        int current_sequence = GetEntSequence(medicine);
        int last_sequence = GetEntPreviousSequence(medicine);

        if (current_sequence == sequence && start_time == -1.0)
        {
            if (g_qol_medical_volume.FloatValue <= 0.0 || !medical_data)
            {
                delete data;
                return;
            }

            start_time = GetGameTime();
            data.Position = start_time_pos;
            data.WriteFloat(start_time);
        }

        if (current_sequence == sequence)
        {
            float rate = GetEntPropFloat(medicine, Prop_Send, "m_flPlaybackRate");
            if (rate == 0.0)
            {
                rate = 1.0;
            }
            int frame = RoundToFloor((GetGameTime() - start_time) * (float(fps) * rate));

            char sound_name[64];

            // Iterate over data to find next sound frame (negative number marks end of sounds).
            int sound_frame = medical_data.ReadCell();
            while (sound_frame >= 0 && frame >= sound_frame)
            {
                medical_data.ReadString(sound_name, sizeof(sound_name));

                if (last_sound_frame < sound_frame)
                {
                    last_sound_frame = sound_frame;

                    data.Position = last_sound_frame_pos;
                    data.WriteCell(last_sound_frame);

                    EmitMedicalSound(client, sound_name);
                }

                sound_frame = medical_data.ReadCell();
            }

            // Keep checking if more sounds exist.
            check_again = sound_frame >= 0;
        }
        else
        {
            // Keep checking because the medical sequence hasn't even started yet.
            check_again = last_sequence != sequence;
        }
    }

    if (check_again)
    {
        RequestFrame(OnFrame_ContinueMedicalSounds, data);
    }
    else
    {
        delete data;
    }
}

/**
 * Plays a game sound to everyone but the specified client at the
 * server's medical sound volume.
 */
void EmitMedicalSound(int client, const char[] game_sound)
{
    int others[MAXPLAYERS];
    int count = GetOtherClients(client, others);

    if (count > 0)
    {
        // Retrieve sound name and parameters from game sound.
        char sound_name[128];
        int channel = SNDCHAN_AUTO;
        int sound_level = SNDLEVEL_NORMAL;
        float volume = SNDVOL_NORMAL;
        int pitch = SNDPITCH_NORMAL;
        GetGameSoundParams(game_sound, channel, sound_level, volume, pitch,
            sound_name, sizeof(sound_name), client);

        sound_level = SNDLEVEL_FRIDGE;
        sound_level = SNDLEVEL_NORMAL - 8;
        channel = SNDCHAN_ITEM;
        volume = g_qol_medical_volume.FloatValue;

        // Play sound.
        EmitSound(others, count, sound_name, client, channel, sound_level,
            SND_CHANGEVOL | SND_CHANGEPITCH, volume, pitch);
    }
}

/**
 * Shove all zombies directly in front of player. (ConVar)
 *
 * Native signature:
 * void CNMRiH_WeaponBase::DoShove()
 */
public MRESReturn DHook_DoPlayerMultishove(int weapon)
{
    int client = GetEntOwner(weapon);

    float distance = g_qol_multishove_distance.FloatValue;
    if (client != -1 && distance > 0.0)
    {
        float start[3];
        GetClientEyePosition(client, start);

        float angles[3];    // angles (0-360)
        GetClientEyeAngles(client, angles);

        float look[3];      // look (0-1)
        GetAngleVectors(angles, look, NULL_VECTOR, NULL_VECTOR);
        ScaleVector(look, distance);
        AddVectors(start, look, look);

        g_multishove_zombies.Clear();

        // Collect a list of zombies we can shove.
        TR_TraceRayFilter(start, look, MASK_SOLID, RayType_EndPoint, Trace_PlayerMultishove, g_multishove_zombies);

        int limit = g_qol_multishove_max_pushed.IntValue;
        if (limit == 0)
        {
            limit = g_multishove_zombies.Length + 1;
        }
        else if (limit > g_multishove_zombies.Length)
        {
            limit = g_multishove_zombies.Length;
        }

        int last_shoved = EntRefToEntIndex(g_player_last_zombie_shoved[client]);
        int shoved = (last_shoved != INVALID_ENT_REFERENCE) ? 1 : 0;

        for (int i = 0; i < g_multishove_zombies.Length && shoved < limit; ++i)
        {
            int zombie = g_multishove_zombies.Get(i);
            if (zombie != last_shoved)
            {
                SDKCall(g_sdkcall_shove_zombie, zombie, client);
                shoved += 1;
            }
        }

        g_player_last_zombie_shoved[client] = -1;
    }

    return MRES_Ignored;
}

/**
 * Hooked to frag grenade and TNT detonation.
 *
 * Plays a detonation sound!
 *
 * Tries to improve the effectiveness of the bomb by moving it away from
 * the floor or ceiling which may otherwise obscure the bomb's blast.
 *
 * Native function's prototype:
 * void CBaseGrenade::Detonate(void)
 */
public MRESReturn DHook_Detonate(int this_ent)
{
    // Try to move grenade away from floor and ceiling. (ConVar)
    if (g_qol_grenade_rise.BoolValue && !IsEntityHeldByPlayer(this_ent))
    {
        const float space_to_check = 64.0;
        const float grenade_hull_radius = 3.5;
        int mask = MASK_SOLID & (~CONTENTS_MONSTER);

        float start[3];
        float end[3];
        GetEntOrigin(this_ent, start);

        // Calculate distance to floor.
        float space_below = space_to_check;
        CopyVector(start, end);
        end[Z] -= space_below;

        TR_TraceRayFilter(start, end, mask, RayType_EndPoint, Trace_Ignore, this_ent);
        if (TR_DidHit())
        {
            TR_GetEndPosition(end);
            space_below = GetVectorDistance(end, start);
            if (space_below < grenade_hull_radius)
            {
                space_below = 0.0;
            }
        }

        // Calulate distance to ceiling.
        float space_above = space_to_check;
        CopyVector(start, end);
        end[Z] += space_above;

        TR_TraceRayFilter(start, end, mask, RayType_EndPoint, Trace_Ignore, this_ent);
        if (TR_DidHit())
        {
            TR_GetEndPosition(end);
            space_above = GetVectorDistance(end, start);
            if (space_above < grenade_hull_radius)
            {
                space_above = 0.0;
            }
            else
            {
                space_above -= grenade_hull_radius;
            }
        }

        // Warp bomb to mid point of free space.
        float zero[3] = { 0.0, ... };
        start[Z] += space_above - space_below;
        TeleportEntity(this_ent, start, NULL_VECTOR, zero);
    }

    // Play an explosion sound. (ConVar)
    if (g_qol_grenade_sounds.BoolValue)
    {
        RequestFrame(OnFrame_PlayGrenadeExplosionSound, EntIndexToEntRef(this_ent));
    }

    return MRES_Ignored;
}

/**
 * Check if an entity is held by any player_pickup.
 *
 * @param entity        Entity to check other players for.
 * @param to_ignore     Ignore if this player is holding it.
 *
 * @return  Index of player holding the entity or 0 if not held.
 */
int IsEntityHeldByPlayer(int entity, int to_ignore = -1)
{
    char classname[CLASSNAME_MAX];

    int player = 0;
    for (int i = 1; i < MaxClients && player == 0; ++i)
    {
        if (i != to_ignore && IsClientInGame(i) && IsPlayerAlive(i))
        {
            int use_entity = GetEntPropEnt(i, Prop_Send, "m_hUseEntity");
            if (use_entity != -1 &&
                IsClassnameEqual(use_entity, classname, sizeof(classname), PLAYER_PICKUP) &&
                GetEntPropEnt(use_entity, Prop_Data, "m_attachedEntity") == entity)
            {
                player = i;
            }
        }
    }
    return player;
}

/**
 * Heavy melee attack: Fubar, sledge and pickaxe.
 */
public MRESReturn DHook_HeavyMeleeStaminaDrain(int melee_weapon, Handle params)
{
    float stamina_scale = g_qol_melee_multihit_stamina_scale_heavy.FloatValue;
    return QOL_MeleeSwing(melee_weapon, params, stamina_scale);
}

/**
 * Light melee weapon attack.
 */
public MRESReturn DHook_MeleeStaminaDrain(int melee_weapon, Handle params)
{
    float stamina_scale = g_qol_melee_multihit_stamina_scale.FloatValue;
    return QOL_MeleeSwing(melee_weapon, params, stamina_scale);
}

/**
 * Change how stamina is drained on melee attacks.
 *
 * We take advantage of the fact that the wrapped native function is called
 * immediately before the player's stamina is drained by a melee attack.
 *
 * Heavy melee weapons (fubar, sledge and pickaxe) only drain stamina on the
 * first object they connect with in a swing.
 *
 * Other melee weapons drain stamina for every connection but ignore stamina
 * drain on walls if at least one zombie was hit.
 *
 * Native signature:
 * void CNMRiH_WeaponBase::HitEffects(CBaseTrace &)
 *
 * @param melee_weapon      ID of melee weapon doing the swing.
 * @param return_handle     Handle to DHook return value.
 * @param params            Handle to DHook parameter info.
 * @param stamina_scale     Scale to apply to stamina drained to subsequent
 *                          hits.
 *
 * @return                  Always MRES_Ignored.
 */
MRESReturn QOL_MeleeSwing(int melee_weapon, Handle params, float stamina_scale)
{
    int client = GetEntOwner(melee_weapon);
    if (client != -1 && IsClientInGame(client))
    {
        if (GetEntPropFloat(melee_weapon, Prop_Send, "m_flLastBeginCharge") != -1.0)
        {
            stamina_scale = g_qol_melee_multihit_stamina_scale_charged.FloatValue;
        }

        int ent = -1;
        if (!DHookIsNullParam(params, 1))
        {
            ent = DHookGetParamObjectPtrVar(params, 1, g_offset_gametrace_ent, ObjectValueType_CBaseEntityPtr);
        }
        bool hit_world = ent <= MaxClients || !SDKCall(g_sdkcall_is_npc, ent);

        float next_melee = GetEntPropFloat(melee_weapon, Prop_Send, "m_flNextPrimaryAttack");
        if (next_melee > g_player_last_melee_times[client])
        {
            // First hit of the swing. Stamina will always be drained.
            g_player_melee_ents_hit[client] = hit_world ? 0 : 1;
            g_player_melee_hit_world[client] = hit_world;
            g_player_last_melee_times[client] = next_melee;
            g_player_melee_previous_stamina[client] = GetClientStamina(client);
            g_player_melee_stamina_cost[client] = -1.0; // Not yet known.
        }
        else
        {
            if (g_player_melee_stamina_cost[client] == -1.0)
            {
                // Calculate how much stamina this swing is draining.
                // This amount differs by weapon and charged attack duration.
                g_player_melee_stamina_cost[client] = g_player_melee_previous_stamina[client] - GetClientStamina(client);
            }

            // Never drain on world.
            // If world was hit first, ignore drain on first NPC.
            // (ConVar)
            if (stamina_scale < 0.0 ||
                g_qol_melee_stamina_ignore_world.BoolValue && (hit_world || (!hit_world && g_player_melee_ents_hit[client] == 0 && g_player_melee_hit_world[client])))
            {
                stamina_scale = 0.0;
            }

            float stamina_cost = g_player_melee_stamina_cost[client];
            float previous_stamina = g_player_melee_previous_stamina[client];
            float stamina = previous_stamina - (stamina_cost * stamina_scale);

            SetClientStamina(client, stamina);
            g_player_melee_previous_stamina[client] = stamina;

            if (hit_world)
            {
                g_player_melee_hit_world[client] = true;
            }
            else
            {
                ++g_player_melee_ents_hit[client];
            }
        }
    }

    return MRES_Ignored;
}

/**
 * Check an object is obstructing a zombie's grab.
 *
 * This prevents zombies grabbing players through fences or doors.
 *
 * @param zombie        Zombie doing the grabbing.
 * @param player        Player being grabbed.
 *
 * @return True if the zombie shouldn't be allowed to grab, otherwise false.
 */
bool IsZombieAttackBlocked(int zombie, int player, bool is_grab)
{
    bool blocked = false;

    if (g_qol_zombie_prevent_attack_thru_walls.BoolValue)
    {
        float zombie_eyes[3];
        GetEntOrigin(zombie, zombie_eyes);
        zombie_eyes[Z] += IsCrawler(zombie) ? 16.0 : 70.0;

        float player_eyes[3];
        GetClientEyePosition(player, player_eyes);

        if (is_grab)
        {
            TR_TraceRayFilter(zombie_eyes, player_eyes, MASK_SOLID, RayType_EndPoint, Trace_ZombieGrab, zombie);
        }
        else
        {
            TR_TraceRayFilter(zombie_eyes, player_eyes, MASK_SOLID, RayType_EndPoint, Trace_ZombieAttack, zombie);
        }

        blocked = TR_DidHit();
    }

    return blocked;
}

/**
 * Prevents zombies grabbing players during cutscenes.
 *
 * Ideal hook would be:
 *      bool CNMRiH_BaseZombie::CanGrabEnemy(void)
 * But it never seems to be called.
 *
 * Native signature:
 * int CNMRiH_BaseZombie::TranslateSchedule(int)
 */
public MRESReturn DHook_PreventMultigrab(int this_ent, Handle return_handle, Handle params)
{
    MRESReturn result = MRES_Ignored;

    int schedule = DHookGetParam(params, 1);

    // Don't allow grabbing during cutscene. (ConVar)
    if (g_in_cutscene &&
        schedule == SCHED_ZOMBIE_GRAB_ENEMY &&
        g_qol_zombie_prevent_grab_during_cutscene.BoolValue)
    {
        DHookSetReturn(return_handle, SCHED_ZOMBIE_CHASE_ENEMY);
        result = MRES_Override;
    }

    return result;
}

/**
 * Check if zombie kid is using standard model.
 *
 * This should hopefully fixe an issue with custom zombie dogs not moving.
 *
 * @param kid   Zombie kid to check.
 *
 * @return      True if the kid is using a standard model, otherwise false.
 */
bool IsStandardKidModel(int kid)
{
    int model_index = GetEntProp(kid, Prop_Data, "m_nModelIndex");
    return model_index == g_model_zombie_kid_boy || model_index == g_model_zombie_kid_girl;
}

/**
 * Check if an NPC activity exists. Used to repair T-pose in kid zombies.
 *
 * It looks like some activity IDs are assigned dynamically and differ
 * between linux and windows servers. This allows us to check for missing
 * activities in a platform agnostic way.
 */
bool IsValidActivity(int npc, int activity)
{
    return SDKCall(g_sdkcall_select_weighted_sequence, npc, activity) != -1;
}

/**
 * Prevent kids T-posing. (ConVar)
 *
 * Kids T-pose when shoved from side or back and when bashing barricades.
 *
 * Native signature:
 * Activity CBaseCombatCharacter::NPC_TranslateActivity(Activity)
 */
public MRESReturn DHook_FixKidTPoseActivities(int kid, Handle return_handle, Handle params)
{
    MRESReturn result = MRES_Ignored;

    if (g_qol_kid_prevent_tpose.BoolValue && IsStandardKidModel(kid))
    {
        int act = DHookGetReturn(return_handle);
        if (act == ACT_SHOVE_LEFT || act == ACT_SHOVE_RIGHT || act == ACT_SHOVE_BEHIND)
        {
            // There's no sideways shove or behind shove animations so just
            // reuse front shove.
            DHookSetReturn(return_handle, ACT_SHOVE);
            result = MRES_Override;
        }
        else if (!IsValidActivity(kid, act))
        {
            // No animations for bash/item swat, just use normal attack animation.
            DHookSetReturn(return_handle, ACT_MELEE_ATTACK1);
            result = MRES_Override;
        }
    }

    return result;
}

/**
 * Prevent kids from T-posing when climbing.
 *
 * Native signature:
 * Activity CBaseNPC::NPC_TranslateActivity(Activity)
 */
public MRESReturn DHook_ForbidZombieClimbActivity(int this_ent, Handle return_handle, Handle params)
{
    MRESReturn result = MRES_Ignored;

    int act = DHookGetParam(params, 1);
    if (act == ACT_CLIMB_UP && g_qol_kid_prevent_tpose.BoolValue)
    {
        DHookSetReturn(return_handle, ACT_WALK);
        result = MRES_Override;
    }

    return result;
}

/**
 * Set the last zombie the player shoved to this zombie.
 *
 * Native signature:
 * void CNMRiH_BaseZombie::GetShoved(CBaseEntity *)
 */
public MRESReturn DHook_RememberZombieShovedByPlayer(int zombie, Handle params)
{
    if (!DHookIsNullParam(params, 1))
    {
        int shover = DHookGetParam(params, 1);
        if (shover > 0 && shover <= MaxClients)
        {
            g_player_last_zombie_shoved[shover] = EntIndexToEntRef(zombie);
        }
    }
    return MRES_Ignored;
}

/**
 * Allow zombies to attack through items that are held within their hull. (ConVar)
 *
 * Native signature:
 * int CNMRiH_BaseZombie::MeleeAttack1Conditions(float, float)
 */
public MRESReturn DHook_FixZombieItemExploit(int zombie, Handle return_handle, Handle params)
{
    MRESReturn result = MRES_Ignored;

    int ret = DHookGetReturn(return_handle);

    int enemy = GetEntPropEnt(zombie, Prop_Data, "m_hEnemy");
    float attack_range = g_sv_zombie_reach.FloatValue;

    if (ret == COND_TOO_FAR_TO_ATTACK &&
        g_qol_zombie_prop_exploit_fix.BoolValue &&
        enemy != -1 &&
        GetEntDistance(zombie, enemy) < attack_range)
    {
        DHookSetReturn(return_handle, COND_CAN_MELEE_ATTACK1);
        result = MRES_Override;
    }

    return result;
}

/**
 * Handle switching to the player's best weapon. Depending on the associated ConVar,
 * that might be a medical item, the players fists or something else.
 *
 * Native signature:
 * CBaseCombatWeapon * CGameRules::GetNextBestWeapon(CBaseCombatCharacter *, CBaseCombatWeapon *)
 */
public MRESReturn DHook_HandleAutoSwitch(Handle return_handle, Handle params)
{
    MRESReturn result = MRES_Ignored;

    MedicalAutoSwitch style = view_as<MedicalAutoSwitch>(g_qol_medical_auto_switch_style.IntValue);
    if (style > MEDICAL_AUTO_SWITCH_VANILLA && !DHookIsNullParam(params, 1))
    {
        int player = DHookGetParam(params, 1);
        int best_weapon = DHookGetReturn(return_handle);

        bool never_medical = style >= MEDICAL_AUTO_SWITCH_NEVER;
        bool find_best = best_weapon == -1 || style == MEDICAL_AUTO_SWITCH_IF_USABLE;

        bool bleeding = IsClientBleeding(player);
        bool infected = IsClientInfected(player);
        bool injured = GetClientHealth(player) < GetEntProp(player, Prop_Data, "m_iMaxHealth");

        char classname[CLASSNAME_MAX];

        // If game tries to select medical item, override according to preferences.
        if (best_weapon != -1)
        {
            if (IsClassnameEqual(best_weapon, classname, sizeof(classname), ITEM_BANDAGES))
            {
                find_best = never_medical || !bleeding;
            }
            else if (StrEqual(classname, ITEM_FIRST_AID))
            {
                // Search for bandages if player is bleeding.
                find_best = never_medical || bleeding || !injured;
            }
            else if (StrEqual(classname, ITEM_PILLS) || StrEqual(classname, ITEM_GENE_THERAPY))
            {
                // Search for bandages if player is bleeding. Look for gene if infected.
                find_best = never_medical || bleeding || infected;
            }
        }

        if (find_best)
        {
            static int max_weapons = 0;
            if (max_weapons == 0)
            {
                max_weapons = GetEntPropArraySize(player, Prop_Send, "m_hMyWeapons");
            }

            // Find player's fists, best weapon and medical items.
            int heaviest = -1;
            int heaviest_weight = -1;
            int fists = -1;
            int bandages = -1;
            int first_aid = -1;
            int pills = -1;
            int gene = -1;
            for (int i = 0; i < max_weapons; ++i)
            {
                int weapon = GetEntPropEnt(player, Prop_Send, "m_hMyWeapons", i);
                if (weapon != -1)
                {
                    if (IsClassnameEqual(weapon, classname, sizeof(classname), WEAPON_FISTS))
                    {
                        fists = weapon;
                    }
                    else if (StrEqual(classname, ITEM_BANDAGES))
                    {
                        bandages = weapon;
                    }
                    else if (StrEqual(classname, ITEM_FIRST_AID))
                    {
                        first_aid = weapon;
                    }
                    else if (StrEqual(classname, ITEM_PILLS))
                    {
                        pills = weapon;
                    }
                    else if (StrEqual(classname, ITEM_GENE_THERAPY))
                    {
                        gene = weapon;
                    }
                    else if (SDKCall(g_sdkcall_weapon_has_ammo, weapon) &&
                        !StrEqual(classname, ITEM_ZIPPO))
                    {
                        // Find the heaviest weighted weapon that player can use.
                        int weight = SDKCall(g_sdkcall_get_item_weight, weapon);
                        if (weight > heaviest_weight)
                        {
                            heaviest = weapon;
                            heaviest_weight = weight;
                        }
                    }
                }
            }

            if (heaviest == -1)
            {
                heaviest = fists;
            }

            best_weapon = heaviest;

            // Auto-switch to usable medical item.
            if (!never_medical && (best_weapon == fists || style == MEDICAL_AUTO_SWITCH_IF_USABLE))
            {
                if (bleeding && bandages != -1)
                {
                    best_weapon = bandages;
                }
                else if (infected && (gene != -1 || pills != -1))
                {
                    best_weapon = gene != -1 ? gene : pills;
                }
                else if ((bleeding || injured) && first_aid != -1)
                {
                    best_weapon = first_aid;
                }
            }

            // Return best weapon.
            if (best_weapon != -1)
            {
                DHookSetReturn(return_handle, best_weapon);
                result = MRES_Override;
            }
        }
    }

    return result;
}

/**
 * Allow players that connected late to respawn if grace period hasn't expired.
 *
 * Native signature:
 * bool CNRMiH_GameRules::FPlayerCanRespawn(CBasePlayer *)
 */
public MRESReturn DHook_AllowLateJoinSpawning(Handle return_handle, Handle params)
{
    MRESReturn result = MRES_Ignored;

    const int index_of_client_param = 1;

    // We only care if the original function is returning false.
    if (!DHookGetReturn(return_handle) && !DHookIsNullParam(params, index_of_client_param))
    {
        int client = DHookGetParam(params, index_of_client_param);
        if (g_player_can_late_spawn[client] && IsRoundStartedButNotEnded())
        {
            bool allow_late_spawn = true;

            // Keep track of spawned players and diallow a respawn in they reconnect. (ConVar)
            if (g_qol_prevent_late_spawn_abuse.BoolValue)
            {
                allow_late_spawn = false;

                int player_steam_id = GetSteamAccountID(client, true);
                if (player_steam_id != 0 &&
                    g_steam_ids_of_late_spawned_players.FindValue(player_steam_id) == -1)
                {
                    allow_late_spawn = true;
                }
            }

            if (allow_late_spawn)
            {
                // Override return value to allow player to spawn.
                DHookSetReturn(return_handle, true);
                result = MRES_Override;
            }
        }
    }


    return result;
}

/**
 * Return true if a round is in progress.
 */
bool IsRoundStartedButNotEnded()
{
    return g_round_end_time == 0.0;
}

/**
 * Return true if a round just started and the late-join spawn grace period
 * hasn't expired.
 */
bool IsSpawnGraceActive()
{
    bool active = false;
    float now = GetGameTime();

    // Grace period after round start.
    int seconds = g_qol_round_start_spawn_grace.IntValue;
    if (seconds > 0)
    {
        // Map just started.
        active = g_round_reset_time == 0.0 && g_round_start_time == 0.0;

        if (!active)
        {
            active = g_round_reset_time > g_round_start_time || now < (g_round_start_time + float(seconds));
        }
    }

    // Grace period after a respawn.
    seconds = g_qol_respawn_grace.IntValue;
    bool allow_respawn = g_force_respawn || !g_sv_realism.BoolValue;
    if (!active && seconds > 0 && allow_respawn && g_last_respawn_time != 0.0)
    {
        active = now < (g_last_respawn_time + float(seconds));
    }

    return active;
}

/**
 * Treat any spawn point as valid when respawning a skating player.
 *
 * This prevents spawn points from being unavailable due to nearby zombies.
 *
 * Native signature:
 * bool CGameRules::IsSpawnPointValid(CBaseEntity *, CBasePlayer *)
 */
public MRESReturn DHook_AnySpawnPointForSkater(Handle return_handle, Handle params)
{
    MRESReturn result = MRES_Ignored;

    if (!DHookIsNullParam(params, 2))
    {
        int player = DHookGetParam(params, 2);

        // Any spawn point for skating players.
        if (g_skating_player_respawning[player])
        {
            DHookSetReturn(return_handle, true);
            result = MRES_Override;
        }
    }

    return result;
}

/**
 * Allow players to spawn at copied spawn points so long as its immediate
 * space is clear (we ignore nearby zombies).
 *
 * Normal spawn behaviour checks for nearby zombies before allowing the player
 * to spawn there. This can cause issues with late-connect spawning on some
 * maps (like nmo_zephyr) where players spawn really close to zombies (in the
 * case of zephyr, right above them).
 *
 * Native signature:
 * bool CGameRules::IsSpawnPointValid(CBaseEntity *, CBasePlayer *)
 */
public MRESReturn DHook_IsCopiedSpawnPointClear(Handle return_handle, Handle params)
{
    MRESReturn result = MRES_Ignored;

    if (!DHookIsNullParam(params, 1))
    {
        // Player bounds.
        static float bounds_min[3] = { -16.0, -16.0, 2.0 };
        static float bounds_max[3] = { 16.0, 16.0, 70.0 };

        int spot = DHookGetParam(params, 1);
        int spot_ref = EntIndexToEntRef(spot);
        if (g_spawn_point_copies.FindValue(spot_ref) != -1 &&
            UTIL_IsSpaceEmpty(spot, bounds_min, bounds_max))
        {
            DHookSetReturn(return_handle, true);
            result = MRES_Override;
        }
    }

    return result;
}

/**
 * From HL2 SDK util_shared.cpp
 */
bool UTIL_IsSpaceEmpty(int ent, float[3] bounds_min, float[3] bounds_max)
{
    float half_bounds[3];
    SubtractVectors(bounds_max, bounds_min, half_bounds);
    ScaleVector(half_bounds, 0.5);

    float half_bounds_neg[3];
    CopyVector(half_bounds, half_bounds_neg);
    NegateVector(half_bounds_neg);

    float center[3];
    GetEntOrigin(ent, center);
    AddVectors(center, bounds_min, center);
    AddVectors(center, half_bounds, center);

    TR_TraceHullFilter(center, center, half_bounds_neg, half_bounds, MASK_SOLID, Trace_Ignore, ent);

    return TR_GetFraction() == 1.0 && !TR_DidHit();
}

/**
 * Retrieve an offset from a game conf or abort the plugin.
 */
int GameConfGetOffsetOrFail(Handle gameconf, const char[] key)
{
    int offset = GameConfGetOffset(gameconf, key);
    if (offset == -1)
    {
        CloseHandle(gameconf);
        SetFailState("Failed to read gamedata offset of %s", key);
    }
    return offset;
}

/**
 * Prep SDKCall from signature or abort.
 */
void GameConfPrepSDKCallSignatureOrFail(Handle gameconf, const char[] key)
{
    if (!PrepSDKCall_SetFromConf(gameconf, SDKConf_Signature, key))
    {
        CloseHandle(gameconf);
        SetFailState("Failed to retrieve signature for gamedata key %s", key);
    }
}

/**
 * Update all supply boxes in the world to be either solid or not.
 *
 * By being nonsolid, players can't exploit the AI's inability to climb
 * the boxes.
 */
public void ConVar_OnNonSolidSupplyChange(ConVar convar, const char[] old, const char[] now)
{
    bool on = convar.BoolValue;
    bool survival = IsSurvival();

    char classname[CLASSNAME_MAX];
    int max_entities = GetMaxEntities();
    for (int i = MaxClients + 1; i < max_entities; ++i)
    {
        if (IsValidEdict(i))
        {
            GetEdictClassname(i, classname, sizeof(classname));

            int collision_group = -1;

            // Check if entity is a supply object that we can fix.
            if (!strncmp(classname, HEALTH_STATION_PREFIX, sizeof(HEALTH_STATION_PREFIX) - 1))
            {
                collision_group = on ? COLLISION_GROUP_DEBRIS : COLLISION_GROUP_HEALTH_STATION;
            }
            else if (!strncmp(classname, SAFEZONE_SUPPLY_PREFIX, sizeof(SAFEZONE_SUPPLY_PREFIX) - 1))
            {
                collision_group = on ? COLLISION_GROUP_DEBRIS : COLLISION_GROUP_SAFEZONE_SUPPLY;
            }
            else if (StrEqual(classname, INVENTORY_BOX))
            {
                if (on)
                {
                    collision_group = COLLISION_GROUP_DEBRIS;
                }
                else
                {
                    // Inventory boxes from helicopters (survival) are non-solid.
                    collision_group = survival ? COLLISION_GROUP_INVENTORY_BOX  : COLLISION_GROUP_NONE;
                }
            }

            if (collision_group != -1)
            {
                SetEntCollisionGroup(i, collision_group);
            }
        }
    }
}

/**
 * Try to import KeyValues from a config file.
 */
bool ImportConfigKeyValues(KeyValues& kv, const char[] file)
{
    char file_path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, file_path, sizeof(file_path), "configs/%s.cfg", file);

    return kv.ImportFromFile(file_path);
}

/**
 * Read QOL's default config.
 */
bool LoadConfig()
{
    KeyValues kv = new KeyValues("qol");
    if (ImportConfigKeyValues(kv, "qol"))
    {
        LoadMedicalSounds(kv);
    }
}

/**
 * Read client sound and frame pairs for medical items from key-values.
 */
void LoadMedicalSounds(KeyValues kv)
{
    if (kv.JumpToKey("client_sounds"))
    {
        if (kv.GotoFirstSubKey(KEYS_ONLY))
        {
            char weapon_name[CLASSNAME_MAX];
            char sound_name[64];
            char frame_key[8];

            do
            {
                kv.GetSectionName(weapon_name, sizeof(weapon_name));

                int sequence = kv.GetNum("sequence", -1);
                int fps = kv.GetNum("fps", -1);

                if (fps == -1)
                {
                    LogMessage("Warning: Weapon %s in QOL config is missing FPS key.", weapon_name);
                }
                else if (sequence == -1)
                {
                    LogMessage("Warning: Weapon %s in QOL config is missing sequence key.", weapon_name);
                }
                else if (kv.JumpToKey("sounds") && kv.GotoFirstSubKey(KEYS_AND_VALUES))
                {
                    DataPack data = CreateDataPack();

                    data.WriteCell(sequence);
                    data.WriteCell(fps);

                    do
                    {
                        kv.GetSectionName(frame_key, sizeof(frame_key));
                        int frame = StringToInt(frame_key);

                        kv.GetString(NULL_STRING, sound_name, sizeof(sound_name), "");

                        data.WriteCell(frame);
                        data.WriteString(sound_name);
                    } while (kv.GotoNextKey(KEYS_AND_VALUES));

                    data.WriteCell(-1);

                    bool replace = false;
                    if (!g_medical_sounds.SetValue(weapon_name, data, replace))
                    {
                        LogMessage("Warning: Failed to add weapon %s to medical sound map.", weapon_name);
                    }

                    kv.GoBack(); // GotoFirstSubKey
                    kv.GoBack(); // JumpToKey
                }
            } while (kv.GotoNextKey(KEYS_ONLY));
        }

        kv.Rewind();
    }
}

public void OnPluginStart()
{
    LoadTranslations("qol.phrases");


    // Game data is necesary for our DHooks/SDKCalls.
    Handle gameconf = LoadGameConfigFile("qol.games");
    if (!gameconf)
    {
        SetFailState("Failed to load QOL game data.");
    }

    LoadDHooks(gameconf);
    LoadSDKCalls(gameconf);

    CloseHandle(gameconf);

    g_medical_sounds = new StringMap();

    // List of zombies that were hurt by exploding props.
    g_zombie_prop_victims = new ArrayList(view_as<int>(PROP_VICTIM_TUPLE_SIZE), 0);

    // List of dead national guard ent refs.
    g_dead_national_guard = new ArrayList(1, 0);

    // List of flying arrow projectiles.
    g_arrow_projectiles = new ArrayList(1, 0);

    // List of ammo boxes being spawned (to be checked for invalid ammo amount).
    g_spawning_ammo_boxes = new ArrayList(1, 0);

    g_multishove_zombies = new ArrayList(1, 0);     // Ent indices to zombies caught by multishove trace.
    g_spawn_point_copies = new ArrayList(1, 0);     // Ent references to copies of last batch of enabled/spawned spawn points.

    // Stores ent refs to carried objects and their collision group pre-pickup.
    g_carried_props = new ArrayList(view_as<int>(PROP_COLLISION_TUPLE_SIZE), 0);

    g_steam_ids_of_late_spawned_players = new ArrayList(1, 0);

    LoadConfig();
    CreateConVars();

    g_sv_tags = FindConVar("sv_tags");
    g_sv_difficulty = FindConVar("sv_difficulty");
    g_sv_realism = FindConVar("sv_realism");
    g_sv_max_stamina = FindConVar("sv_max_stamina");
    g_sv_stam_regen_moving = FindConVar("sv_stam_regen_moving");
    g_sv_zombie_reach = FindConVar("sv_zombie_reach");
    g_sv_barricade_health = FindConVar("sv_barricade_health");
    g_cl_barricade_board_model = FindConVar("cl_barricade_board_model");

    RegAdminCmd("sm_skaterboy", Command_FixPlayerSkating, 0, "Fix ice-skating/jittery player movement");
    RegAdminCmd("sm_skatergirl", Command_FixPlayerSkating, 0, "Fix ice-skating/jittery player movement");

    HookEvent("new_wave", Event_NewWave);
    HookEvent("nmrih_reset_map", Event_ResetMap);
    HookEvent("state_change", Event_StateChange);
    HookEvent("freeze_all_the_things", Event_CutsceneToggle);
    HookEvent("game_restarting", Event_GameRestarting);
    HookEvent("nmrih_practice_ending", Event_GameRestarting);
    HookEvent("nmrih_round_begin", Event_RoundBegin);
    HookEvent("player_activate", Event_PlayerActivate);
    HookEvent("player_death", Event_PlayerDeath);
    HookEvent("player_commit_suicide", Event_PlayerCommitSuicide);
    HookEventEx("player_spawn", Event_PrePlayerSpawn, EventHookMode_Pre);

    HookEntityOutput("nmrih_health_station_location", "OnActivated", Output_OnHealthStationActivated);
    HookEntityOutput(PLAYER_SPAWN_POINT, "OnEnable", Output_OnSpawnPointEnable);

    // Create a forward for National Guard loot spawns. (zombie, loot)
    g_forward_national_guard_loot_spawn = CreateGlobalForward("OnNationalGuardLoot", ET_Event, Param_Cell, Param_Cell);

    // Create forwards for medical item activation. (client, ent)
    g_forward_used_bandages = CreateGlobalForward("OnPlayerUsedBandages", ET_Event, Param_Cell, Param_Cell);
    g_forward_used_pills = CreateGlobalForward("OnPlayerUsedPills", ET_Event, Param_Cell, Param_Cell);
    g_forward_used_first_aid = CreateGlobalForward("OnPlayerUsedFirstAid", ET_Event, Param_Cell, Param_Cell);
    g_forward_used_gene_therapy = CreateGlobalForward("OnPlayerUsedGeneTherapy", ET_Event, Param_Cell, Param_Cell);
    g_forward_barricade_collected = CreateGlobalForward("OnBarricadeCollected", ET_Event, Param_Cell, Param_Cell);

    if (g_plugin_loaded_late)
    {
        QOL_HookExistingEntities();


        // Hook existing players.
        for (int i = 1; i <= MaxClients; ++i)
        {
            if (IsClientAuthorized(i) && IsClientInGame(i))
            {
                OnClientPostAdminCheck(i);
            }
        }
    }

    AddServerTag2(QOL_TAG);

    CreateTimer(0.25, Timer_GameTimer, _, TIMER_REPEAT);
}

void LoadDHooks(Handle gameconf)
{
    // Ent data offsets.
    g_offset_gametrace_ent = GameConfGetOffsetOrFail(gameconf, "CGameTrace::m_pEnt");
    g_offset_is_crawler = GameConfGetOffsetOrFail(gameconf, "CNMRiH_BaseZombie::m_bCrawler");
    g_offset_is_national_guard = GameConfGetOffsetOrFail(gameconf, "CNMRiH_BaseZombie::m_bNationalGuard");
    g_offset_barricade_point_physics_ent = GameConfGetOffsetOrFail(gameconf, "CNMRiH_BarricadePoint::m_hPropPhysics");
    g_offset_playerspawn_enabled = GameConfGetOffsetOrFail(gameconf, "CNMRiH_PlayerSpawn::m_bEnabled");
    g_offset_player_state = GameConfGetOffsetOrFail(gameconf, "CSDKPlayer::m_iPlayerState");
    g_offset_original_collision_group = GameConfGetOffsetOrFail(gameconf, "CBaseEntity::m_iOriginalCollisionGroup");

    int offset;

    // Hook to modify weapon auto-switch.
    offset = GameConfGetOffsetOrFail(gameconf, "CGameRules::GetNextBestWeapon");
    g_dhook_next_best_weapon = DHookCreate(offset, HookType_GameRules, ReturnType_CBaseEntity, ThisPointer_Ignore, DHook_HandleAutoSwitch);
    DHookAddParam(g_dhook_next_best_weapon, HookParamType_CBaseEntity);   // CBaseEntity *, player
    DHookAddParam(g_dhook_next_best_weapon, HookParamType_CBaseEntity);   // CBaseEntity *, current weapon

    // Hook to allow late-joining players to spawn.
    offset = GameConfGetOffsetOrFail(gameconf, "CNMRiH_ObjectiveGameRules::FPlayerCanRespawn");
    g_dhook_allow_late_join_spawning = DHookCreate(offset, HookType_GameRules, ReturnType_Bool, ThisPointer_Ignore, DHook_AllowLateJoinSpawning);
    DHookAddParam(g_dhook_allow_late_join_spawning, HookParamType_CBaseEntity);   // CBaseEntity *, player

    // Hook to allow skating players to spawn anywhere.
    offset = GameConfGetOffsetOrFail(gameconf, "CGameRules::IsSpawnPointValid");
    g_dhook_any_spawn_point_for_skater = DHookCreate(offset, HookType_GameRules, ReturnType_Bool, ThisPointer_Ignore, DHook_AnySpawnPointForSkater);
    DHookAddParam(g_dhook_any_spawn_point_for_skater, HookParamType_CBaseEntity);   // CBaseEntity *, spot
    DHookAddParam(g_dhook_any_spawn_point_for_skater, HookParamType_CBaseEntity);   // CBasePlayer *, player

    // Skip nearby zombie check when spawning players at copied spawn points.
    g_dhook_is_copied_spawn_point_clear = DHookCreate(offset, HookType_GameRules, ReturnType_Bool, ThisPointer_Ignore, DHook_IsCopiedSpawnPointClear);
    DHookAddParam(g_dhook_is_copied_spawn_point_clear, HookParamType_CBaseEntity);   // CBaseEntity *, spot
    DHookAddParam(g_dhook_is_copied_spawn_point_clear, HookParamType_CBaseEntity);   // CBasePlayer *, player

    // Change whether medical items can be auto-switched to.
    offset = GameConfGetOffsetOrFail(gameconf, "CBaseCombatWeapon::AllowsAutoSwitchTo");
    g_dhook_handle_medical_autoswitch_to = DHookCreate(offset, HookType_Entity, ReturnType_Bool, ThisPointer_CBaseEntity, DHook_MedicalAutoSwitchTo);

    // Hook that watches for medical item activation.
    offset = GameConfGetOffsetOrFail(gameconf, "CNMRiH_BaseMedicalItem::ApplyMedicalItem_Internal");
    g_dhook_call_medical_item_forward = DHookCreate(offset, HookType_Entity, ReturnType_Void, ThisPointer_CBaseEntity, DHook_CallMedicalItemForward);

    // Hook that modifies the equip rules for medical items.
    offset = GameConfGetOffsetOrFail(gameconf, "CNMRiH_BaseMedicalItem::ShouldUseMedicalItem");
    g_dhook_allow_any_medical_wield = DHookCreate(offset, HookType_Entity, ReturnType_Bool, ThisPointer_CBaseEntity, DHook_OnAttemptMedicalUse);

    // Improve grenade effectiveness and play explosion sounds.
    offset = GameConfGetOffsetOrFail(gameconf, "CBaseGrenade::Detonate");
    g_dhook_grenade_detonate = DHookCreate(offset, HookType_Entity, ReturnType_Void, ThisPointer_CBaseEntity, DHook_Detonate);

    // Prevent walls draining stamina when a zombie is hit.
    offset = GameConfGetOffsetOrFail(gameconf, "CNMRiH_WeaponBase::HitEffects");
    g_dhook_melee_stamina_drain = DHookCreate(offset, HookType_Entity, ReturnType_Void, ThisPointer_CBaseEntity, DHook_MeleeStaminaDrain);
    DHookAddParam(g_dhook_melee_stamina_drain, HookParamType_ObjectPtr, -1, DHookPass_ByRef);       // CGameTrace &

    // Prevent heavy weapons draining stamina for each zombie hit.
    g_dhook_heavy_melee_stamina_drain = DHookCreate(offset, HookType_Entity, ReturnType_Void, ThisPointer_CBaseEntity, DHook_HeavyMeleeStaminaDrain);
    DHookAddParam(g_dhook_heavy_melee_stamina_drain, HookParamType_ObjectPtr, -1, DHookPass_ByRef); // CGameTrace &

    // Allow players to shove multiple zombies at once.
    offset = GameConfGetOffsetOrFail(gameconf, "CNMRiH_WeaponBase::DoShove");
    g_dhook_weapon_multishove = DHookCreate(offset, HookType_Entity, ReturnType_Void, ThisPointer_CBaseEntity, DHook_DoPlayerMultishove);

    // Allow players to shove during ironsight animation.
    offset = GameConfGetOffsetOrFail(gameconf, "CNMRiH_WeaponBase::ToggleIronsights");
    g_dhook_weapon_pre_sight_toggle = DHookCreate(offset, HookType_Entity, ReturnType_Void, ThisPointer_CBaseEntity, DHook_WeaponPreSightToggle);
    g_dhook_weapon_post_sight_toggle = DHookCreate(offset, HookType_Entity, ReturnType_Void, ThisPointer_CBaseEntity, DHook_WeaponPostSightToggle);

    // Prevent crawlers from standing to climb (they can still climb though).
    offset = GameConfGetOffsetOrFail(gameconf, "CBaseCombatCharacter::NPC_TranslateActivity");
    g_dhook_forbid_zombie_climb_activity = DHookCreate(offset, HookType_Entity, ReturnType_Int, ThisPointer_CBaseEntity, DHook_ForbidZombieClimbActivity);
    DHookAddParam(g_dhook_forbid_zombie_climb_activity, HookParamType_Int);     // activity

    // Prevent kid T-posing when shoved from back or side.
    g_dhook_fix_kid_shove_activity = DHookCreate(offset, HookType_Entity, ReturnType_Int, ThisPointer_CBaseEntity, DHook_FixKidTPoseActivities);
    DHookAddParam(g_dhook_fix_kid_shove_activity, HookParamType_Int);   // activity

    // Cache an ent reference to the last zombie a player shoved.
    offset = GameConfGetOffsetOrFail(gameconf, "CNMRiH_BaseZombie::GetShoved");
    g_dhook_on_zombie_shoved = DHookCreate(offset, HookType_Entity, ReturnType_Void, ThisPointer_CBaseEntity, DHook_RememberZombieShovedByPlayer);
    DHookAddParam(g_dhook_on_zombie_shoved, HookParamType_CBaseEntity); // shover

    // Allow zombies to attack when an item is held within their hull.
    offset = GameConfGetOffsetOrFail(gameconf, "CNMRiH_BaseZombie::MeleeAttack1Conditions");
    g_dhook_fix_zombie_item_exploit = DHookCreate(offset, HookType_Entity, ReturnType_Int, ThisPointer_CBaseEntity, DHook_FixZombieItemExploit);
    DHookAddParam(g_dhook_fix_zombie_item_exploit, HookParamType_Float);
    DHookAddParam(g_dhook_fix_zombie_item_exploit, HookParamType_Float);
}

void LoadSDKCalls(Handle gameconf)
{
    int offset;

    // Shove a zombie relative to an entity.
    offset = GameConfGetOffsetOrFail(gameconf, "CNMRiH_BaseZombie::GetShoved");
    StartPrepSDKCall(SDKCall_Entity);
    PrepSDKCall_SetVirtual(offset);
    PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
    g_sdkcall_shove_zombie = EndPrepSDKCall();

    // Used to check if an activity exists.
    StartPrepSDKCall(SDKCall_Entity);
    GameConfPrepSDKCallSignatureOrFail(gameconf, "CBaseAnimating::SelectWeightedSequence");
    PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);  // Activity
    PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
    g_sdkcall_select_weighted_sequence = EndPrepSDKCall();

    // Check if a weapon has ammo or doesn't need ammo.
    offset = GameConfGetOffsetOrFail(gameconf, "CBaseCombatWeapon::HasAnyAmmo");
    StartPrepSDKCall(SDKCall_Entity);
    PrepSDKCall_SetVirtual(offset);
    PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
    g_sdkcall_weapon_has_ammo = EndPrepSDKCall();

    // Retrieve item's inventory weight and auto-switch priority.
    offset = GameConfGetOffsetOrFail(gameconf, "CBaseCombatWeapon::GetWeight");
    StartPrepSDKCall(SDKCall_Entity);
    PrepSDKCall_SetVirtual(offset);
    PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
    g_sdkcall_get_item_weight = EndPrepSDKCall();

    // Start player bleeding out.
    StartPrepSDKCall(SDKCall_Player);
    GameConfPrepSDKCallSignatureOrFail(gameconf, "CNMRiH_Player::Bleedout");
    g_sdkcall_player_bleedout = EndPrepSDKCall();

    // Infect player.
    offset = GameConfGetOffsetOrFail(gameconf, "CNMRiH_Player::BecomeInfected");
    StartPrepSDKCall(SDKCall_Player);
    PrepSDKCall_SetVirtual(offset);
    g_sdkcall_player_become_infected = EndPrepSDKCall();

    // Cause a player to attempt respawn.
    offset = GameConfGetOffsetOrFail(gameconf, "CBasePlayer::ForceRespawn");
    StartPrepSDKCall(SDKCall_Player);
    PrepSDKCall_SetVirtual(offset);
    g_sdkcall_player_respawn = EndPrepSDKCall();

    // Change entity's collision group.
    StartPrepSDKCall(SDKCall_Entity);
    GameConfPrepSDKCallSignatureOrFail(gameconf, "CBaseEntity::SetCollisionGroup");
    PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);  // int, collision group
    g_sdkcall_set_entity_collision_group = EndPrepSDKCall();

    // Check if entity is NPC.
    offset = GameConfGetOffsetOrFail(gameconf, "CBaseEntity::IsNPC");
    StartPrepSDKCall(SDKCall_Entity);
    PrepSDKCall_SetVirtual(offset);
    PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
    g_sdkcall_is_npc = EndPrepSDKCall();

    // Check if entity is item.
    offset = GameConfGetOffsetOrFail(gameconf, "CBaseEntity::IsBaseCombatWeapon");
    StartPrepSDKCall(SDKCall_Entity);
    PrepSDKCall_SetVirtual(offset);
    PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
    g_sdkcall_is_combat_weapon = EndPrepSDKCall();

    // Used to parent arrows to objects they hit.
    offset = GameConfGetOffsetOrFail(gameconf, "CBaseEntity::SetParent");
    StartPrepSDKCall(SDKCall_Entity);
    PrepSDKCall_SetVirtual(offset);
    PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer); // CBaseEntity *
    PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);  // int
    g_sdkcall_set_parent = EndPrepSDKCall();

    // Check if game mode uses tokens.
    offset = GameConfGetOffsetOrFail(gameconf, "CNMRiH_GameRules::AreTokensGivenFromKills");
    StartPrepSDKCall(SDKCall_GameRules);
    PrepSDKCall_SetVirtual(offset);
    PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);  // bool
    g_sdkcall_are_tokens_given_from_kills = EndPrepSDKCall();

    // Find and teleport player to available spawn point.
    offset = GameConfGetOffsetOrFail(gameconf, "CGameRules::GetPlayerSpawnSpot");
    StartPrepSDKCall(SDKCall_GameRules);
    PrepSDKCall_SetVirtual(offset);
    PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
    PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity, SDKPass_Pointer);
    g_sdkcall_get_player_spawn_spot = EndPrepSDKCall();
}

void CreateConVars()
{
    CreateConVar("qol", QOL_VERSION, "Quality of Life plugin. By Ryan.",
        FCVAR_NOTIFY | FCVAR_SPONLY | FCVAR_DONTRECORD | FCVAR_REPLICATED);

    //
    // Player
    //
    g_qol_skate_cooldown = CreateConVar("qol_skate_cooldown", "10",
        "Number of seconds player must wait between /skaterboy commands. Negative value to disable command.");

    g_qol_func_breakable_player_damage_fix = CreateConVar("qol_func_breakable_player_damage_fix", "1",
        "Prevent players taking damage from touching func_breakables (glass roof on Brooklyn, vent on FEMA, etc).");

    g_qol_infection_bypass = CreateConVar("qol_infection_bypass", "100.0",
        "Damage amounts equal to or higher than this will prevent an infected player from reanimating. Use 0.0 for vanilla behavior (i.e. always reanimate).");

    g_qol_count_fire_kills = CreateConVar("qol_count_fire_kills", "1",
        "Award score to players that kill zombies with gas cans.");

    g_qol_count_infected_suicide_kill = CreateConVar("qol_count_infected_suicide_kill", "1",
        "Award score to players that suicide when infected.");

    g_qol_multishove_distance = CreateConVar("qol_multishove_distance", "52.0",
        "Distance to allow shove to hit more than one zombie. Use 0.0 for vanilla behavior (off).");

    g_qol_multishove_max_pushed = CreateConVar("qol_multishove_max_pushed", "0",
        "Maximum number of zombies player can push per shove. 0 means infinite. See qol_multishove_distance to disable.");

    g_qol_stuck_object_fix = CreateConVar("qol_stuck_object_fix", "1",
        "Allow players to pickup items that are clipping into geometry. Fixes sprint-lock issue with supply crate.");

    g_qol_weaponized_object_fix = CreateConVar("qol_weaponized_object_fix", "1",
        "Prevent exploit that allows physics objects to damage players and zombies by being smashed into them.");

    g_qol_dropped_object_collision_fix = CreateConVar("qol_dropped_object_collision_fix", "1",
        "Ensure prop's original collision group is restored after players drop it. This prevents solid props becoming non-solid after dropping them.");

    //
    // Zombies
    //
    g_qol_nonsolid_supply = CreateConVar("qol_zombie_attack_thru_supply", "1",
        "Legacy option that makes all supply boxes non-solid so players can't hide on top.");
    g_qol_nonsolid_supply.AddChangeHook(ConVar_OnNonSolidSupplyChange);

    g_qol_zombie_prop_exploit_fix = CreateConVar("qol_zombie_prop_exploit_fix", "1",
        "Fix an exploit where zombies won't attack when an object is held within their hull.");

    g_qol_zombie_prevent_attack_backwards = CreateConVar("qol_zombie_prevent_attack_backwards", "1",
        "Prevent zombie swipe attacks damaging players directly behind the zombie.");

    g_qol_zombie_prevent_attack_thru_walls = CreateConVar("qol_zombie_prevent_attack_thru_walls", "1",
        "Prevent zombies from hurting players through objects like doors.");

    g_qol_zombie_prevent_grab_during_cutscene = CreateConVar("qol_zombie_prevent_grab_during_cutscene", "1",
        "Disallow zombies from grabbing players while extraction cutscene is playing.");

    g_qol_kid_prevent_tpose = CreateConVar("qol_kid_prevent_tpose", "1",
        "Prevent kids T-posing when climbing.");

    g_qol_national_guard_crawler_health = CreateConVar("qol_national_guard_crawler_health", "50",
        "National Guard crawler maximum health.");

    g_qol_national_guard_drop_grenade = CreateConVar("qol_national_guard_drop_grenade", "1",
        "Allow National Guard zombies to drop frag grenade (legacy option).");

    //
    // Weapons
    //
    g_qol_arrow_fix = CreateConVar("qol_arrow_fix", "1",
        "Allow arrows to rotate with doors, stick to brush entities and fixes arrows that could not be recollected.");

    g_qol_barricade_damage_volume = CreateConVar("qol_barricade_damage_volume", "1.0",
        "Volume of QOL barricade damage sounds. Use 0.0 for vanilla behavior.",
        _, true, 0.0, true, 1.0);

    g_qol_barricade_hammer_volume = CreateConVar("qol_barricade_hammer_volume", "1.0",
        "Volume of barricade hammering sounds heard by players that are not barricading. E.g. 1.0 means full volume. Use 0.0 for vanilla behavior.",
        _, true, 0.0, true, 1.0);

    g_qol_barricade_retrieve_health = CreateConVar("qol_barricade_retrieve_health", "1.0",
        "Minimum percent of full health a barricade must have to be recollectable via barricade hammer charge attack. E.g. 1.0 means full health. Use negative number for vanilla behavior (never recollect).",
        _, false, 0.0, true, 1.0);

    g_qol_barricade_show_damage = CreateConVar("qol_barricade_show_damage", "0.75",
        "Visualize barricade health by darkening boards according to how much damage they've taken. The value represents what percent of black the model should be at 0 hit point left. E.g. 0.75 means 75% black at 0 hit point. Use 0.0 for vanilla behavior.");

    g_qol_barricade_zombie_multihit_ignore = CreateConVar("qol_barricade_zombie_multihit_ignore", "0.75",
        "Percent of damage barricades should ignore when they're hit by a zombie that isn't targeting them specifically. E.g. 0.75 reduces damage zombies do to barricade they currently are not targeting to 25%. Use 0.0 for vanilla behavior.",
        _, true, 0.0, true, 1.0);

    g_qol_board_ammo_fix = CreateConVar("qol_board_ammo_fix", "1",
        "Repair board pickups that have 0 ammo.");

    g_qol_grenade_rise = CreateConVar("qol_grenade_rise", "1",
        "Warp TNT and frag grenades slightly off ground at detonation to improve effectivness around clutter.");

    g_qol_grenade_sounds = CreateConVar("qol_grenade_sounds", "1",
        "Use QOL's legacy grenade sounds.");

    g_qol_ironsight_shove = CreateConVar("qol_ironsight_shove", "1",
        "Allow player to shove while ironsight is raising or lowering.");

    g_qol_sks_bayonet_sounds = CreateConVar("qol_sks_bayonet_sounds", "1",
        "Play an extra sound when a zombie's head is stabbed with the bayonet.");

    g_qol_melee_stamina_ignore_world = CreateConVar("qol_melee_stamina_ignore_world", "1",
        "Prevent the world from draining stamina in a melee attack if at least one zombie was hit.");

    g_qol_melee_multihit_stamina_scale = CreateConVar("qol_melee_multihit_stamina_scale", "1.0",
        "When a player hits more than one zombie with a melee weapon, the additional hits will have their stamina cost scaled by this amount. E.g. 0.2 means use 20% of weapon's swing cost. Use 1.0 for vanilla behavior. ");

    g_qol_melee_multihit_stamina_scale_charged = CreateConVar("qol_melee_multihit_stamina_scale_charged", "0.0",
        "When a player hits more than one zombie with a charged attack, the additional hits will have their stamina cost scaled by this amount. E.g. 0.0 means 0% of charged attack's cost. Use 1.0 for vanilla behavior.");

    g_qol_melee_multihit_stamina_scale_heavy = CreateConVar("qol_melee_multihit_stamina_scale_heavy", "0.20",
        "When a player hits more than one zombie with a fubar, sledge or pickaxe, the additional hits will have their stamina cost scaled by this amount. E.g. 0.2 means 20% of weapon's swing cost. Use 1.0 for vanilla behavior.");

    g_qol_medical_auto_switch_style = CreateConVar("qol_medical_auto_switch_style", "1",
        "Auto-switch behavior. 0: Switch if medicine is heavier than current weapon. 1: Switch if medicine is heavier than current weapon and is usable. 2: Switch if medicine is usable (even if a heavier weapon exists). 3: Never auto-switch to medical items.");

    g_qol_medical_volume = CreateConVar("qol_medical_volume", "1",
        "Volume of medical sounds heard by players not healing. E.g. 1.0 means full volume. Use 0.0 for vanilla behavior (no sounds).",
        _, true, 0.0, true, 1.0);

    g_qol_medical_wield = CreateConVar("qol_medical_wield", "1",
        "Allow players to wield medical items at any time (so they may be thrown).");

    //
    // Game
    //
    g_qol_nonsolid_supply = CreateConVar("qol_zombie_attack_thru_supply", "1",
        "Makes med-boxes, safe zone supply boxes and inventory boxes non-solid to avoid exploiting NPCs AI.");
    g_qol_nonsolid_supply.AddChangeHook(ConVar_OnNonSolidSupplyChange);

    g_qol_round_start_spawn_grace = CreateConVar("qol_round_start_spawn_grace", "30.0",
        "Number of seconds after round start that late-joining players can still spawn.");

    g_qol_respawn_grace = CreateConVar("qol_respawn_grace", "30.0",
        "Number of seconds after a respawn point that late-joining players can still spawn.");

    g_qol_respawn_ahead_threshold = CreateConVar("qol_respawn_ahead_threshold", "0.0",
        "Players that spawn as early as this many seconds before a respawn event will automatically be teleported to the newer spawn point. This fixes players spawning at the wrong spawns.");

    g_qol_prevent_late_spawn_abuse = CreateConVar("qol_prevent_late_spawn_abuse", "1",
        "Limit players to one late spawn per respawn event. I.e. players cannot abuse late spawn by dying and then reconnecting for a guaranteed late respawn.");

    AutoExecConfig(true);
}

/**
 * Restore server memory to original state.
 */
public void OnPluginEnd()
{
    ClearRespawnPoints();

    RemoveServerTag2(QOL_TAG);
}

/**
 * Precache plugin sounds and spawn plugin entities.
 */
public void OnMapStart()
{
    g_map_loaded = true;

    g_model_zombie_kid_boy = QOL_PrecacheModel(MODEL_ZOMBIE_KID_BOY);
    g_model_zombie_kid_girl = QOL_PrecacheModel(MODEL_ZOMBIE_KID_GIRL);

    g_carried_props.Clear();

    g_round_reset_time = -1.0;
    g_round_start_time = 0.0;
    g_round_end_time = 0.0;
    g_last_respawn_time = 0.0;

    QOL_PrecacheSoundArray(SOUNDS_EXPLODE, sizeof(SOUNDS_EXPLODE));
    QOL_PrecacheSoundArray(SOUNDS_FRAG_DISTANT, sizeof(SOUNDS_FRAG_DISTANT));
    QOL_PrecacheSoundArray(SOUNDS_TNT_MID, sizeof(SOUNDS_TNT_MID));
    QOL_PrecacheSoundArray(SOUNDS_TNT_DISTANT, sizeof(SOUNDS_TNT_DISTANT));

    QOL_PrecacheSoundArray(SOUNDS_SKS_STAB_HEAD, sizeof(SOUNDS_SKS_STAB_HEAD));

    QOL_PrecacheSoundArray(SOUNDS_BARRICADE_DAMAGE, sizeof(SOUNDS_BARRICADE_DAMAGE));
    QOL_PrecacheSoundArray(SOUNDS_BARRICADE_BREAK, sizeof(SOUNDS_BARRICADE_BREAK));
    PrecacheSound(SOUND_BARRICADE_COLLECT, true);

    PrecacheSound(SOUND_NULL, true);

    PrecacheSound(SOUND_GRENADE_THROW, true);

    DHookGamerules(g_dhook_next_best_weapon, true);
    DHookGamerules(g_dhook_allow_late_join_spawning, true);
    DHookGamerules(g_dhook_any_spawn_point_for_skater, true);
    DHookGamerules(g_dhook_is_copied_spawn_point_clear, true);

    // Spawn plugin entities.
    Event_ResetMap(null, "", true);
}

public void OnMapEnd()
{
    g_map_loaded = false;
}

/**
 * Precache a model or log a warning message.
 */
int QOL_PrecacheModel(const char[] model_name)
{
    int index = PrecacheModel(model_name, true);
    if (index == 0)
    {
        LogMessage("Warning: Failed to precache model: %s", model_name);
    }
    return index;
}

/**
 * Precache an array of sounds.
 */
void QOL_PrecacheSoundArray(const char[][] sounds, int sound_count)
{
    for (int i = 0; i < sound_count; ++i)
    {
        PrecacheSound(sounds[i], true);
    }
}

/**
 * Setup player hooks to prevent players taking damage through walls,
 * to prevent reanimating when dying from high damage, etc.
 */
public void OnClientPostAdminCheck(int client)
{
    SDKHook(client, SDKHook_OnTakeDamage, Hook_PlayerTakeDamage);
    SDKHook(client, SDKHook_OnTakeDamageAlive, Hook_PlayerTakeDamageAlive);
    SDKHook(client, SDKHook_WeaponSwitch, Hook_PlayerWeaponSwitch);

    // Forcibly call WeaponSwitch for current weapon.
    int active_weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
    Hook_PlayerWeaponSwitch(IGNORE_CURRENT_WEAPON | client, active_weapon);
}

/**
 * Hook new entities added after plugin is loaded.
 */
public void OnEntityCreated(int entity, const char[] classname)
{
    QOL_OnNewEntity(entity, classname, true);
}

/**
 * Called when plugin is loaded late to rehook existing entities.
 */
void QOL_HookExistingEntities()
{
    char classname[CLASSNAME_MAX];
    int max_entities = GetMaxEntities();
    for (int i = MaxClients + 1; i < max_entities; ++i)
    {
        if (IsValidEdict(i))
        {
            GetEdictClassname(i, classname, sizeof(classname));

            QOL_OnNewEntity(i, classname, false);
        }
    }
}

/**
 * Called when a new entity is detected by plugin.
 *
 * @param entity        Entity ID.
 * @param classname     Classname of entity.
 * @param spawning      True if entity hasn't spawned yet, otherwise false.
 */
void QOL_OnNewEntity(int entity, const char[] classname, bool spawning)
{
    if (!IsValidEntity(entity))
    {
        return;
    }

    static const char NPC_PREFIX[] = "npc_nmrih_";

    if (!strncmp(classname, NPC_PREFIX, sizeof(NPC_PREFIX) - 1))
    {
        if (spawning && g_in_cutscene)
        {
            if (g_qol_zombie_prevent_grab_during_cutscene.BoolValue)
            {
                // Remove zombies spawned during cutscene (otherwise
                // npc_template_maker can spawn zombies that attack players).
                SDKHook(entity, SDKHook_Spawn, Hook_PreventSpawn);
            }
        }
        else
        {
            // Check if shambler is a national guard crawler and set its health.
            int postfix = sizeof(NPC_PREFIX) - 1;
            if (StrEqual(classname[postfix], "shamblerzombie"))
            {
                if (spawning)
                {
                    SDKHook(entity, SDKHook_SpawnPost, DHook_CheckNationalGuardCrawler);
                }
            }
            else if (StrEqual(classname[postfix], "kidzombie"))
            {
                // Fix kid t-pose when pushed from side or back.
                DHookEntity(g_dhook_fix_kid_shove_activity, true, entity);
                DHookEntity(g_dhook_forbid_zombie_climb_activity, true, entity);
            }

            SDKHook(entity, SDKHook_OnTakeDamageAlive, Hook_ZombieTakeDamage);

            // Remember which zombie the player shoved last.
            DHookEntity(g_dhook_on_zombie_shoved, true, entity);

            // Allow zombies to attack when an item is held within their hull.
            DHookEntity(g_dhook_fix_zombie_item_exploit, true, entity);
        }
    }
    else if (StrEqual(classname, PROJECTILE_FRAG) || StrEqual(classname, PROJECTILE_TNT))
    {
        DHookEntity(g_dhook_grenade_detonate, false, entity);
        PlayGrenadeThrowSound(entity);
    }
    else if (StrEqual(classname, PROJECTILE_MOLOTOV))
    {
        PlayGrenadeThrowSound(entity);
    }
    else if (StrEqual(classname, PLAYER_PICKUP))
    {
        if (spawning)
        {
            SDKHook(entity, SDKHook_SpawnPost, Hook_UnstickCarriedObject);
            SDKHook(entity, SDKHook_Use, Hook_PreventWeaponizedProps);
        }
    }
    else if (StrEqual(classname, ITEM_PILLS) ||
        StrEqual(classname, ITEM_FIRST_AID) ||
        StrEqual(classname, ITEM_BANDAGES) ||
        StrEqual(classname, ITEM_GENE_THERAPY))
    {
        DHookEntity(g_dhook_call_medical_item_forward, true, entity);
        DHookEntity(g_dhook_allow_any_medical_wield, true, entity);
        DHookEntity(g_dhook_handle_medical_autoswitch_to, true, entity);
    }
    else if (!strncmp(classname, HEALTH_STATION_PREFIX, sizeof(HEALTH_STATION_PREFIX) - 1) ||
        !strncmp(classname, SAFEZONE_SUPPLY_PREFIX, sizeof(SAFEZONE_SUPPLY_PREFIX) - 1) ||
        StrEqual(classname, INVENTORY_BOX))
    {
        if (spawning)
        {
            SDKHook(entity, SDKHook_SpawnPost, Hook_DontBlockZombieAttack);

            if (g_qol_nonsolid_supply.BoolValue &&
                IsSurvival() &&
                StrEqual(classname, INVENTORY_BOX))
            {
                SDKHook(entity, SDKHook_ThinkPost, Hook_ItemBoxThink);
            }
        }
        else
        {
            Hook_DontBlockZombieAttack(entity);
        }
    }
    else if (StrEqual(classname, "prop_physics_multiplayer"))
    {
        if (spawning)
        {
            SDKHook(entity, SDKHook_SpawnPost, Hook_CheckBarricade);
        }
        else
        {
            Hook_CheckBarricade(entity);
        }
    }

    if (spawning)
    {
        if (IsNationalGuardLootType(classname))
        {
            SDKHook(entity, SDKHook_SpawnPost, Hook_CheckNationalGuardDrop);
        }

        if (StrEqual(classname, "item_ammo_box"))
        {
            // Repair ammo that spawns with 0 rounds (boards).
            SDKHook(entity, SDKHook_SpawnPost, Hook_FixAmmoAmount);
        }
        else if (StrEqual(classname, PROJECTILE_ARROW))
        {
            SDKHook(entity, SDKHook_SpawnPost, Hook_ArrowSpawnPost);
        }
        else if (StrEqual(classname, PLAYER_SPAWN_POINT))
        {
            // Some maps create player spawns using templates before a respawn.
            SDKHook(entity, SDKHook_SpawnPost, Hook_NewSpawnPoint);
        }
    }

    bool is_melee = IsMeleeWeapon(classname);

    // Adjust stamina drain effects on melee weapons.
    if (StrEqual(classname, WEAPON_FUBAR) ||
        StrEqual(classname, WEAPON_SLEDGE) ||
        StrEqual(classname, WEAPON_PICKAXE))
    {
        DHookEntity(g_dhook_heavy_melee_stamina_drain, true, entity);
    }
    else if (is_melee)
    {
        DHookEntity(g_dhook_melee_stamina_drain, true, entity);
    }

    if (SDKCall(g_sdkcall_is_combat_weapon, entity))
    {
        // Customize weapon speeds.
        if (!is_melee)
        {
            // Allow shoving during ironsight up/down animation.
            DHookEntity(g_dhook_weapon_pre_sight_toggle, false, entity);
            DHookEntity(g_dhook_weapon_post_sight_toggle, true, entity);
        }

        // Shove multiple zombies at once.
        DHookEntity(g_dhook_weapon_multishove, true, entity);
    }
}

/**
 * Prevent entity from spawning.
 */
public Action Hook_PreventSpawn(int entity)
{
    if (IsValidEntity(entity))
    {
        SDKHook(entity, SDKHook_SpawnPost, Hook_KillEntity);
    }
    return Plugin_Handled;
}

/**
 * Kill entity (because returning Plugin_Handled in Spawn hook doesn't
 * actually remove entity).
 */
public void Hook_KillEntity(int entity)
{
    if (IsValidEntity(entity))
    {
        AcceptEntityInput(entity, "Kill");
    }
}

/**
 * Grenade toss sound effect. (ConVar)
 */
void PlayGrenadeThrowSound(int thrown)
{
    if (g_qol_grenade_sounds.BoolValue)
    {
        EmitSoundToAll(SOUND_GRENADE_THROW, thrown, SNDCHAN_AUTO, ATTN_TO_SNDLEVEL(0.7));
    }
}

/**
 * Move object to debris collision group to allow zombies to attack through
 * it. Objects like med-boxes and inventory boxes prevent zombies from attacking
 * and can be exploited by players. (ConVar)
 */
public void Hook_DontBlockZombieAttack(int entity)
{
    if (g_qol_nonsolid_supply.BoolValue)
    {
        SetEntCollisionGroup(entity, COLLISION_GROUP_DEBRIS);
    }
}

/**
 * Inventory boxes in survival need to be assigned a collision group after they
 * start falling. Otherwise the collision group they were assigned at spawn is
 * overwritten.
 */
public void Hook_ItemBoxThink(int item_box)
{
    bool stay_hooked = g_qol_nonsolid_supply.BoolValue;

    if (stay_hooked && GetEntCollisionGroup(item_box) != COLLISION_GROUP_DEBRIS)
    {
        SetEntCollisionGroup(item_box, COLLISION_GROUP_DEBRIS);
        stay_hooked = false;
    }

    if (!stay_hooked)
    {
        SDKUnhook(item_box, SDKHook_ThinkPost, Hook_ItemBoxThink);
    }
}

/**
 * Check if entity class is something a National Guard can drop.
 */
bool IsNationalGuardLootType(const char[] classname)
{
    for (int i = 0; i < sizeof(NATIONAL_GUARD_DROPS); ++i)
    {
        if (StrEqual(NATIONAL_GUARD_DROPS[i], classname))
        {
            return true;
        }
    }

    return false;
}

/**
 * Check if entity is within dropping distance of recently killed
 * National Guards.
 */
public void Hook_CheckNationalGuardDrop(int entity)
{
    // Is it near enough to a dead national guard?

    int closest_index = -1;
    int closest_ent;
    float closest_squared_distance = -1.0;

    float item_origin[3];
    GetEntOrigin(entity, item_origin);

    float guard_origin[3];

    for (int i = 0; i < g_dead_national_guard.Length; )
    {
        int guard_ref = g_dead_national_guard.Get(i);
        int guard = EntRefToEntIndex(guard_ref);
        if (guard != INVALID_ENT_REFERENCE)
        {
            GetEntOrigin(guard, guard_origin);

            float squared_distance = GetVectorDistance(item_origin, guard_origin, SQUARED_DISTANCE);
            if (squared_distance < LOOT_DROP_MAX_DISTANCE_SQUARED && (closest_index == -1 || closest_squared_distance > squared_distance))
            {
                closest_index = i;
                closest_ent = guard;
                closest_squared_distance = squared_distance;
            }
            
            ++i;
        }
        else
        {
            g_dead_national_guard.Erase(i);
        }
    }

    if (closest_index != -1)
    {
        char classname[CLASSNAME_MAX];
        if (!g_qol_national_guard_drop_grenade.BoolValue &&
            IsClassnameEqual(entity, classname, sizeof(classname), "exp_grenade"))
        {
            // Remove National Guard frag grenade spawns if they're not enabled.
            AcceptEntityInput(entity, "Kill");
        }
        else
        {
            // Forward to any scripts interested in National Guard drops.
            any ignored;
            Call_StartForward(g_forward_national_guard_loot_spawn);
            Call_PushCell(closest_ent);
            Call_PushCell(entity);
            Call_Finish(ignored);
        }

        g_dead_national_guard.Erase(closest_index);
    }
}

/**
 * This event is called just prior to a round reset.
 */
public Event_GameRestarting(Event event, const char[] name, bool no_broadcast)
{
    g_round_reset_time = GetGameTime();
    g_last_respawn_time = 0.0;
    g_round_start_time = 0.0;
    g_round_end_time = 0.0;
    g_carried_props.Clear();
    ClearRespawnPoints();
}

/**
 * Store round start time.
 */
public void Event_RoundBegin(Event event, const char[] name, bool no_broadcast)
{
    g_round_start_time = GetGameTime();
}

/**
 * Player just connected so they're eligble for late-spawning.
 */
public void Event_PlayerActivate(Event event, const char[] name, bool no_broadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    if (client != -1)
    {
        ResetPlayer(client);
        g_player_can_late_spawn[client] = IsSpawnGraceActive();
    }
}

/**
 * Check if player died within respawn grace. We only allow one respawn this way.
 */
public void Event_PlayerDeath(Event event, const char[] name, bool no_broadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    if (client != -1 && g_player_can_late_spawn[client])
    {
        g_player_can_late_spawn[client] = IsSpawnGraceActive();
    }
}

/**
 * Award a point to players that make a righteous decision.
 */
public void Event_PlayerCommitSuicide(Event event, const char[] name, bool no_broadcast)
{
    int player = event.GetInt("player_id");
    bool infected = event.GetBool("infected");

    if (infected && g_qol_count_infected_suicide_kill.BoolValue)
    {
        int adder = EntRefToEntIndex(g_score_adder);
        if (adder != INVALID_ENT_REFERENCE)
        {
            // +2, one to offset minus point for suicide and one to add a point.
            AcceptEntityInput(adder, "ApplyScore", player, adder);
            AcceptEntityInput(adder, "ApplyScore", player, adder);
        }
    }
}

/**
 * Eat player spawn events caused by respawning skating players.
 */
public Action Event_PrePlayerSpawn(Event event, const char[] name, bool no_broadcast)
{
    Action result = Plugin_Continue;

    int userid = event.GetInt("userid");
    int client = GetClientOfUserId(userid);

    if (NMRiH_IsPlayerAlive(client))
    {
        if (g_skating_player_respawning[client])
        {
            // Eat event and recreate player according to saved settings.
            g_skating_player_respawning[client] = false;
            RequestFrame(OnFrame_ReEquipSkatingPlayer, userid);
            result = Plugin_Handled;
        }
        else if (g_skating_player_data[client] == null)
        {
            ResetPlayer(client);
            g_player_spawn_times[client] = GetGameTime();
            g_player_can_late_spawn[client] = false;

            // Add player's steam ID to recently spawned list.
            int player_steam_id = GetSteamAccountID(client, true);
            if (player_steam_id != 0 && 
                g_steam_ids_of_late_spawned_players.FindValue(player_steam_id) == -1)
            {
                g_steam_ids_of_late_spawned_players.Push(player_steam_id);
            }
        }
    }

    return result;
}

/**
 * Reinfect the player one frame later than re-equip.
 *
 * Trying to infect the player the frame after respawning doesn't
 * work.
 *
 * Doesn't maintain infection overlay's alpha!
 */
public void OnFrame_ReInfectPlayer(int userid)
{
    int client = GetClientOfUserId(userid);
    if (client == -1)
    {
        return;
    }

    DataPack data = g_skating_player_data[client];
    if (data != null)
    {
        data.Reset();

        float delta_seconds = GetGameTime() - ReadPackFloat(data);
        float infection_time = ReadPackFloat(data) + delta_seconds;
        float death_time = ReadPackFloat(data) + delta_seconds;

        SDKCall(g_sdkcall_player_become_infected, client);

        SetEntPropFloat(client, Prop_Send, "m_flInfectionTime", infection_time);
        SetEntPropFloat(client, Prop_Send, "m_flInfectionDeathTime", death_time);

        delete data;
        g_skating_player_data[client] = null;
    }
}

/**
 * Setup respawning skating player as if they never respawned.
 *
 * The player's infection overlay is reset and I'm unsure how to
 * restore its alpha.
 */
public void OnFrame_ReEquipSkatingPlayer(int userid)
{
    int client = GetClientOfUserId(userid);
    if (client == -1)
    {
        return;
    }

    DataPack data = g_skating_player_data[client];
    if (data != null)
    {
        data.Reset();

        char message[128];
        int offset = Format(message, sizeof(message), "%T", "@skate-be-gone", client);

        float delta_seconds = GetGameTime() - ReadPackFloat(data);
        float infection_time = ReadPackFloat(data);
        float death_time = ReadPackFloat(data);

        bool infected = infection_time > 0.0 && death_time > 0.0;
        if (infected)
        {
            RequestFrame(OnFrame_ReInfectPlayer, userid);
            offset += Format(message[offset], sizeof(message) - offset, " %T", "@skate-still-infected", client);
        }

        float position[3];
        float angles[3];
        float velocity[3];

        ReadPackVector(data, position);
        ReadPackVector(data, angles);
        ReadPackVector(data, velocity);

        TeleportEntity(client, position, angles, velocity);

        SetEntityHealth(client, ReadPackCell(data));

        // Regenerate player's stamina for time spent waiting for respawn.
        float regen_rate = g_sv_stam_regen_moving ? g_sv_stam_regen_moving.FloatValue : 6.0;
        float stamina = ReadPackFloat(data) + regen_rate * delta_seconds;
        float max_stamina = g_sv_max_stamina ? g_sv_max_stamina.FloatValue : 130.0;
        if (stamina > max_stamina)
        {
            stamina = max_stamina;
        }
        else if (stamina < 0.0)
        {
            stamina = 0.0;
        }

        SetClientStamina(client, stamina);

        SetEntProp(client, Prop_Send, "_vaccinated", ReadPackCell(data));

        bool bleeding_out = ReadPackCell(data);
        if (bleeding_out)
        {
            SDKCall(g_sdkcall_player_bleedout, client);
        }

        SetEntPropFloat(client, Prop_Data, "m_AirFinished", ReadPackFloat(data) + delta_seconds);
        SetEntProp(client, Prop_Data, "m_idrowndmg", ReadPackCell(data));
        SetEntProp(client, Prop_Data, "m_idrownrestored", ReadPackCell(data));
        SetEntProp(client, Prop_Data, "m_nDrownDmgRate", ReadPackCell(data));

        int ammo_size = ReadPackCell(data);
        for (int i = 0; i < ammo_size; ++i)
        {
            SetEntProp(client, Prop_Send, PROP_NAME_PLAYER_AMMO, ReadPackCell(data), _, i);
        }

        char classname[CLASSNAME_MAX];

        float origin[3];
        CopyVector(position, origin);
        origin[Z] += 32.0;

        float zero[3] = { 0.0, ... };

        int weapon_size = ReadPackCell(data);
        for (int i = 0; i < weapon_size; ++i)
        {
            int weapon = ReadPackCell(data);
            if (weapon != -1 && (weapon = EntRefToEntIndex(weapon)) != INVALID_ENT_REFERENCE)
            {
                GetEdictClassname(weapon, classname, sizeof(classname));

                if (StrEqual(classname, WEAPON_FISTS) || StrEqual(classname, ITEM_ZIPPO))
                {
                    AcceptEntityInput(weapon, "Kill");
                }
                else if (GetEntOwner(weapon) == -1)
                {
                    TeleportEntity(weapon, origin, zero, zero);
                    AcceptEntityInput(weapon, "Use", client, client);
                }
            }
        }

        // Requip last weapon.
        int active_weapon = EntRefToEntIndex(ReadPackCell(data));
        int active_weapon_sequence = ReadPackCell(data);
        if (active_weapon != INVALID_ENT_REFERENCE && GetEntOwner(active_weapon) == client)
        {
            NMRIH_EquipPlayerWeapon(client, active_weapon, active_weapon_sequence);
        }

        // Try to grab previous pickup if not much time has passed.
        int pickup = ReadPackCell(data);
        if (pickup != -1 && delta_seconds < 1.0)
        {
            AcceptEntityInput(pickup, "Use", client, client);
        }

        // Reset tokens in objective mode (otherwise game won't end when all players die).
        if (!IsSurvival())
        {
            SetEntProp(client, Prop_Send, "m_iTokens", 0);
        }

        PrintToChat(client, message);

        // Keep datapack for an extra frame if the player was infected.
        if (!infected)
        {
            delete data;
            g_skating_player_data[client] = null;
        }
    }
}

/**
 * Plays QOL's legacy grenade sounds.
 */
public void OnFrame_PlayGrenadeExplosionSound(int grenade_ref)
{
    int grenade = EntRefToEntIndex(grenade_ref);
    if (grenade != INVALID_ENT_REFERENCE)
    {
        // Suppress the vanilla sound effect.
        EmitSoundToAll(SOUND_NULL, grenade, SNDCHAN_WEAPON);

        char classname[CLASSNAME_MAX];
        if (IsClassnameEqual(grenade, classname, sizeof(classname), PROJECTILE_TNT))
        {
            // Layers three sound effects for more impressive boom.
            int sound = GetURandomInt() % sizeof(SOUNDS_EXPLODE);
            EmitSoundToAll(SOUNDS_EXPLODE[sound], grenade, SNDCHAN_AUTO, ATTN_TO_SNDLEVEL(0.3),
                SND_CHANGEPITCH, SNDVOL_NORMAL, SNDPITCH_LOW - 10);

            sound = GetURandomInt() % sizeof(SOUNDS_TNT_MID);
            EmitSoundToAll(SOUNDS_TNT_MID[sound], grenade, SNDCHAN_AUTO, ATTN_TO_SNDLEVEL(0.25));

            sound = GetURandomInt() % sizeof(SOUNDS_TNT_DISTANT);
            EmitSoundToAll(SOUNDS_TNT_DISTANT[sound], grenade, SNDCHAN_AUTO, 255);
        }
        else
        {
            // Two sounds. One has a smaller attenuation to be heard further away.
            int sound = GetURandomInt() % sizeof(SOUNDS_EXPLODE);
            EmitSoundToAll(SOUNDS_EXPLODE[sound], grenade, SNDCHAN_AUTO, ATTN_TO_SNDLEVEL(0.5));

            sound = GetURandomInt() % sizeof(SOUNDS_FRAG_DISTANT);
            EmitSoundToAll(SOUNDS_FRAG_DISTANT[sound], grenade, SNDCHAN_AUTO, ATTN_TO_SNDLEVEL(0.4));
        }
    }
}

/**
 * New wave represents a respawn point.
 */
public void Event_NewWave(Event event, const char[] name, bool no_broadcast)
{
    HandleRespawnEvent(g_last_wave_was_resupply);
    g_last_wave_was_resupply = event.GetBool("resupply");
}

/**
 * Store current time as respawn event.
 *
 * Players that were alive at time of respawn event are allowed one respawn
 * during the grace period.
 *
 * E.g. player 1 triggers a respawn; 30 second grace period starts; player 1
 * dies before 30 seconds has expired; player 1 respawns; player 1 dies again
 * before remaining grace period has expired; player 1 doesn't re-respawn.
 *
 * @param even_in_realism   When true, this event will respawn players even when
 *                          sv_realism is on.
 */
void HandleRespawnEvent(bool even_in_realism = false)
{
    float now = GetGameTime();
    if (g_round_start_time != 0.0 && now > g_round_start_time && now > g_last_respawn_time)
    {
        g_last_respawn_time = now;
        g_force_respawn = even_in_realism;

        // Clear list of late spawned players so they become eligible for respawn again.
        g_steam_ids_of_late_spawned_players.Clear();

        // Add living players to late spawned list. This prevents players
        // exploiting late spawn system by reconnecting within grace period.
        // (ConVar)
        if (g_qol_prevent_late_spawn_abuse.BoolValue)
        {
            for (int client = 1; client <= MaxClients; ++client)
            {
                if (NMRiH_IsPlayerAlive(client))
                {
                    int player_steam_id = GetSteamAccountID(client, true);
                    g_steam_ids_of_late_spawned_players.Push(player_steam_id);
                }
            }
        }

        ClearRespawnPoints();

        float seconds = g_qol_respawn_ahead_threshold.FloatValue;
        if (!IsSurvival() && seconds >= 0.0)
        {
            // Teleport players that spawned just before this respawn event
            // to the newest spawn points. We do this next frame so that the
            // entire batch of spawn points have a chance to activate.
            RequestFrame(OnFrame_AdvanceRecentSpawners, now - seconds);
        }

        // Permit living players one respawn during respawn grace.
        // (ConVar)
        if (!g_qol_prevent_late_spawn_abuse.BoolValue &&
            g_qol_respawn_grace.IntValue > 0 &&
            (!g_sv_realism.BoolValue || even_in_realism))
        {
            for (int i = 1; i <= MaxClients; ++i)
            {
                if (IsClientInGame(i) && IsPlayerAlive(i))
                {
                    g_player_can_late_spawn[i] = true;
                }
            }
        }
    }
}

/**
 * Teleport players that spawned shortly before respawn event to newest
 * spawn points.
 *
 * This is a kludge to fix maps that call RespawnPlayers before any spawn
 * points are available (e.g. nmo_shelter). In Vanilla, players would get
 * a "waiting for spawn point" message until the next spawns become available
 * a moment later. In QOL, there's always a valid spawn point available
 * so players don't have the opportunity to wait for the delayed spawn point
 * activation.
 *
 * @param earliest      Players spawned after this GameTime will be teleported.
 */
public void OnFrame_AdvanceRecentSpawners(float earliest)
{
    for (int i = 1; i <= MaxClients; ++i)
    {
        if (NMRiH_IsPlayerAlive(i) &&
            g_player_spawn_times[i] >= earliest &&
            g_player_spawn_times[i] <= g_last_respawn_time)
        {
            SDKCall(g_sdkcall_get_player_spawn_spot, i);
        }
    }
}

/**
 * Called when the level is reset for a new round.
 */
public void Event_ResetMap(Event event, const char[] name, bool no_broadcast)
{
    g_in_cutscene = false;
    g_last_wave_was_resupply = false;

    for (int i = 1; i <= MaxClients; ++i)
    {
        ResetPlayer(i);
    }

    g_zombie_prop_victims.Clear();
    g_dead_national_guard.Clear();
    g_arrow_projectiles.Clear();

    int score_adder = CreateEntityByName("game_score");
    if (score_adder != -1)
    {
        DispatchKeyValue(score_adder, "points", "1");
        if (DispatchSpawn(score_adder))
        {
            g_score_adder = EntIndexToEntRef(score_adder);
        }
    }
    if (EntRefToEntIndex(score_adder) == INVALID_ENT_REFERENCE)
    {
        LogError("Failed to create score adder (game_score).");
    }

    // Spawner used when recollecting barricade boards.
    int board_spawner = CreateEntityByName("random_spawner");
    if (board_spawner != -1)
    {
        DispatchKeyValue(board_spawner, "ammobox_board", "100");
        DispatchKeyValue(board_spawner, "spawnflags", "6");    // "don't spawn on map start" and "toss me about"
        DispatchKeyValue(board_spawner, "ammo_fill_pct_max", "100");
        DispatchKeyValue(board_spawner, "ammo_fill_pct_mix", "100");
        if (DispatchSpawn(board_spawner))
        {
            g_board_spawner_ref = EntIndexToEntRef(board_spawner);
        }
    }
    if (EntRefToEntIndex(g_board_spawner_ref) == INVALID_ENT_REFERENCE)
    {
        LogError("Failed to create board spawner (random_spawner)");
    }
}

/**
 * Reset player's plugin data for a new round.
 */
void ResetPlayer(int player)
{
    // Nullify skating data.
    g_skating_player_respawning[player] = false;
    if (g_skating_player_data[player])
    {
        delete g_skating_player_data[player];
        g_skating_player_data[player] = null;
    }

    // Reset skate fix cooldown.
    g_player_last_skate_time[player] = 0.0;

    // Clear melee stamina information.
    g_player_melee_ents_hit[player] = 0;
    g_player_melee_hit_world[player] = false;
    g_player_last_melee_times[player] = 0.0;
    g_player_melee_previous_stamina[player] = 0.0;

    // No last barricade time.
    g_player_barricade_time[player] = 0.0;
    g_player_unbarricade_time[player] = 0.0;

    // Re-enable next pickup fix.
    g_player_do_pickup_fix[player] = true;
}

/**
 * Remove copied spawn points.
 */
void ClearRespawnPoints()
{
    int copy_count = g_spawn_point_copies.Length;
    for (int i = 0; i < copy_count; ++i)
    {
        int spawn_point_ref = g_spawn_point_copies.Get(i);
        int spawn_point = EntRefToEntIndex(spawn_point_ref);
        if (spawn_point != INVALID_ENT_REFERENCE)
        {
            RemoveEdict(spawn_point);
        }
    }
    g_spawn_point_copies.Clear();
}

/**
 * Store round end time. We do this so we know when not to respawn players.
 */
public void Event_StateChange(Event event, const char[] name, bool no_broadcast)
{
    int game_type = event.GetInt("game_type");
    int state = event.GetInt("state");

    if ((game_type == GAME_TYPE_OBJECTIVE && (state == OBJECTIVE_STATE_OVERRUN || state == OBJECTIVE_STATE_EXTRACTED)) ||
        (game_type == GAME_TYPE_SURVIVAL && (state == SURVIVAL_STATE_OVERRUN || state == SURVIVAL_STATE_EXTRACTED)))
    {
        g_round_end_time = GetGameTime();
    }
}

/**
 * Attribute zombie fire deaths to the correct player. (ConVar)
 */
void CreditPlayerForPropFireKill(int zombie)
{
    if (g_qol_count_fire_kills.BoolValue)
    {
        int ent_ref = EntIndexToEntRef(zombie);
        int igniter = 0;

        // Check our list of zombies hurt by props for player id.
        for (int i = 0; i < g_zombie_prop_victims.Length && igniter == 0; )
        {
            int other_ref = g_zombie_prop_victims.Get(i, view_as<int>(PROP_VICTIM_ENT_REF));
            if (other_ref == ent_ref)
            {
                igniter = g_zombie_prop_victims.Get(i, view_as<int>(PROP_VICTIM_ATTACKER));
            }

            if (igniter != 0 || EntRefToEntIndex(other_ref) == INVALID_ENT_REFERENCE)
            {
                // Remove matching and expired entries.
                RemoveArrayListElement(g_zombie_prop_victims, i);

                if (igniter != 0)
                {
                    break;
                }
            }
            else
            {
                ++i;
            }
        }

        // Give player credit for kill.
        if (igniter > 0 && igniter <= MaxClients && IsClientInGame(igniter))
        {
            int adder = EntRefToEntIndex(g_score_adder);
            if (adder != INVALID_ENT_REFERENCE)
            {
                AcceptEntityInput(adder, "ApplyScore", igniter, adder);
            }
        }
    }
}

/**
 * Monitor cutscene activation. We prevent players from using the skate-fix
 * command while a cutscene is active.
 */
public void Event_CutsceneToggle(Event event, const char[] name, bool no_broadcast)
{
    g_in_cutscene = event.GetBool("frozen");
}

/**
 * Players can stand inside med-boxes to avoid being attacked by zombies.
 *
 * This allows zombies to attack. (ConVar)
 */
public void Output_OnHealthStationActivated(
    const char[] output,
    int caller,
    int activator,
    float delay)
{
    if (g_qol_nonsolid_supply.BoolValue)
    {
        // Move health station to debris collision group to allow zombies to attack through it.
        SetEntCollisionGroup(caller, COLLISION_GROUP_DEBRIS);
    }
}

/**
 * Assume spawn points are enabled right before a respawn.
 *
 * There doesn't seem to be a better way to catch nmo_ respawn events
 * except for writing an extension and using detours.
 */
public void Output_OnSpawnPointEnable(
    const char[] output,
    int caller,
    int activator,
    float delay)
{
    Hook_NewSpawnPoint(caller);
}

/**
 * Cache the type of weapon equipped by each player. One string compare here
 * is faster than repeated string comparisons later.
 *
 * @param client        Client that switched weapons.
 * @param weapon        Edict of weapon the player switched to.
 */
public Action Hook_PlayerWeaponSwitch(int client, int weapon)
{
    bool ignore_current_weapon = (client & IGNORE_CURRENT_WEAPON) != 0;
    client &= ~IGNORE_CURRENT_WEAPON;

    int active_weapon = GetClientActiveWeapon(client);
    if (IsValidEdict(weapon) && (ignore_current_weapon || weapon != active_weapon))
    {
        char weapon_name[CLASSNAME_MAX];
        if (IsClassnameEqual(weapon, weapon_name, sizeof(weapon_name), WEAPON_BARRICADE))
        {
            g_player_weapon_type[client] = WEAPON_TYPE_BARRICADE;
        }
        else
        {
            g_player_weapon_type[client] = WEAPON_TYPE_OTHER;
        }
    }
    else if (weapon != active_weapon)
    {
        g_player_weapon_type[client] = WEAPON_TYPE_OTHER;
    }

    return Plugin_Continue;
}

/**
 * Save next bash time. It will be restored post-native-call.
 *
 * Native signature:
 * void CNMRiH_WeaponBase::ToggleIronsights()
 */
public MRESReturn DHook_WeaponPreSightToggle(int weapon)
{
    int player = GetEntOwner(weapon);
    if (player != -1)
    {
        g_player_next_bash_time[player] = GetEntPropFloat(weapon, Prop_Send, "m_flNextBashAttack");
    }
    return MRES_Ignored;
}

/**
 * Restore player's next shove time so they can shove during ironsight animation.
 *
 * Native signature:
 * void CNMRiH_WeaponBase::ToggleIronsights()
 */
public MRESReturn DHook_WeaponPostSightToggle(int weapon)
{
    int player = GetEntOwner(weapon);
    if (player != -1 && g_qol_ironsight_shove.BoolValue)
    {
        SetEntPropFloat(weapon, Prop_Send, "m_flNextBashAttack", g_player_next_bash_time[player]);
    }
    return MRES_Ignored;
}

/**
 * Prevent players taking damage through props. (ConVar)
 *
 * Also prevent players taking damage from func_breakables. (ConVar)
 *
 * Also prevent players taking damage from zombies that aren't facing the player. (ConVar)
 */
public Action Hook_PlayerTakeDamage(
    int player,
    int &attacker,
    int &inflictor,
    float &damage,
    int &damage_type)
{
    Action result = Plugin_Continue;

    if (g_qol_func_breakable_player_damage_fix.BoolValue && player == attacker && attacker == inflictor && damage_type == DMG_SLASH)
    {
        // Prevent func_breakable from hurting the player on touch.
        result = Plugin_Stop;
    }
    else if (attacker > MaxClients && IsValidEdict(attacker) && SDKCall(g_sdkcall_is_npc, attacker))
    {
        int sequence = GetEntSequence(attacker);
        bool is_bite = IsZombieBiteSequence(sequence);

        // Prevent zombies damaging players through doors/fences. (ConVar)
        if (IsZombieAttackBlocked(attacker, player, is_bite))
        {
            result = Plugin_Stop;
        }
        else if (g_qol_zombie_prevent_attack_backwards.BoolValue)
        {
            // Prevent zombies damaging players behind them.
            float rotation[3];
            GetEntPropVector(attacker, Prop_Data, "m_angRotation", rotation);

            float facing[3];
            GetAngleVectors(rotation, facing, NULL_VECTOR, NULL_VECTOR);

            float to_player[3];
            GetEntDirection(attacker, player, to_player, true);

            float dot = GetVectorDotProduct(facing, to_player);

            // Zombie's default dot product check when starting an attack is 0.7.
            // We use 0.5 though so anyone within 120 degrees of the zombie's
            // swipe can be hit.
            const float minimum_dot_threshold = 0.5;

            if (dot < minimum_dot_threshold)
            {
                result = Plugin_Stop;
            }
        }
    }

    return result;
}

/**
 * Prevent the player from reanimating when killed by certain amount of damage. (ConVar)
 *
 * We use TakeDamageAlive because it is called after damage has been adjusted
 * and we can accurately identify when the player dies.
 */
public Action Hook_PlayerTakeDamageAlive(
    int player,
    int &attacker,
    int &inflictor,
    float &damage,
    int &damage_type)
{
    float health_remaining = float(GetEntHealth(player)) - damage;
    if (health_remaining <= 0.0)
    {
        // Prevent player reanimating when killed by a specific amount of damage. (ConVar)
        float bypass_amount = g_qol_infection_bypass.FloatValue;
        float infect_death_time = GetEntPropFloat(player, Prop_Send, "m_flInfectionDeathTime");
        if (bypass_amount > 0.0 && damage >= bypass_amount && GetGameTime() < infect_death_time)
        {
            SetEntPropFloat(player, Prop_Send, "m_flInfectionTime", -1.0);
            SetEntPropFloat(player, Prop_Send, "m_flInfectionDeathTime", -1.0);
        }
    }

    return Plugin_Continue;
}

/**
 * Monitor National Guard deaths.
 */
public Action Hook_ZombieTakeDamage(
    int victim,
    int &attacker,
    int &inflictor,
    float &damage,
    int &damage_type)
{
    Action result = Plugin_Continue;

    float health_remaining = float(GetEntHealth(victim)) - damage;

    char classname[CLASSNAME_MAX];
    if (IsValidEdict(inflictor))
    {
        GetEdictClassname(inflictor, classname, sizeof(classname));

        static const char PROP_PREFIX[] = "prop_";

        if (attacker != 0 && (damage_type & DMG_BLAST) && !strncmp(classname, PROP_PREFIX, sizeof(PROP_PREFIX) - 1))
        {
            int[] tuple = new int[PROP_VICTIM_TUPLE_SIZE];
            tuple[view_as<int>(PROP_VICTIM_ENT_REF)] = EntIndexToEntRef(victim);
            tuple[view_as<int>(PROP_VICTIM_ATTACKER)] = attacker;
            g_zombie_prop_victims.PushArray(tuple);
        }

        HandleBayonetSounds(victim, classname, damage_type);
    }

    if (health_remaining <= 0.0)
    {
        if ((damage_type & DMG_CONTINUAL_BURNING) == DMG_CONTINUAL_BURNING)
        {
            CreditPlayerForPropFireKill(victim);
        }

        if (IsNationalGuard(victim))
        {
            // Purge expired guards before insert.
            for (int i = 0; i < g_dead_national_guard.Length; )
            {
                int guard_ref = g_dead_national_guard.Get(i);
                if (EntRefToEntIndex(guard_ref) == INVALID_ENT_REFERENCE)
                {
                    g_dead_national_guard.Erase(i);
                }
                else
                {
                    ++i;
                }
            }

            int guard_ref = EntIndexToEntRef(victim);
            g_dead_national_guard.Push(guard_ref);
        }
    }

    return result;
}

/**
 * Play bayonet stabbing sound. (ConVar)
 */
void HandleBayonetSounds(
    int zombie,
    const char[] inflictor_name,
    int damage_type)
{
    static const int DMG_MELEE = 0x80;
    static const int DMG_HEADSHOT = 0x180000;
    int DMG_MELEE_HEADSHOT = DMG_MELEE | DMG_HEADSHOT;

    if (g_qol_sks_bayonet_sounds.BoolValue &&
        (damage_type & DMG_MELEE_HEADSHOT) == DMG_MELEE_HEADSHOT &&
        StrEqual(inflictor_name, WEAPON_SKS))
    {
        // Play another sound zombie's head is stabbed for player feedback.
        int sound_index = GetURandomInt() % sizeof(SOUNDS_SKS_STAB_HEAD);
        EmitSoundToAll(SOUNDS_SKS_STAB_HEAD[sound_index], zombie);
    }
}

/**
 * Check if prop_physics is a barricade.
 */
public void Hook_CheckBarricade(int barricade)
{
    char model_name[CLASSNAME_MAX];
    GetEntPropString(barricade, Prop_Data, "m_ModelName", model_name, sizeof(model_name));

    char board_model[CLASSNAME_MAX];
    g_cl_barricade_board_model.GetString(board_model, sizeof(board_model));

    if (StrEqual(model_name, board_model))
    {
        SetEntityRenderMode(barricade, RENDER_TRANSCOLOR);
        SDKHook(barricade, SDKHook_OnTakeDamage, Hook_BarricadeTakeDamage);
    }
}

/**
 * Darken damaged boards. (ConVar)
 *
 * Play barricade damage sounds. (ConVar)
 *
 * Scale damage dealt to secondary barricades (when zombie swipe hits multiple boards). (ConVar)
 */
public Action Hook_BarricadeTakeDamage(
    int barricade,
    int &attacker,
    int &inflictor,
    float &damage,
    int &damage_type)
{
    Action result = Plugin_Continue;

    // Prevent zombies from hitting more than one barricade at a time. (ConVar)
    float damage_reduction = g_qol_barricade_zombie_multihit_ignore.FloatValue;
    if (damage_reduction > 0.0 && attacker > MaxClients &&
        HasEntProp(attacker, Prop_Data, "m_hBlockingBarricade"))
    {
        int barricade_point = GetEntPropEnt(attacker, Prop_Data, "m_hBlockingBarricade");
        if (barricade_point != -1)
        {
            // Check if the board being attacked belongs to the zombie's barricade point.
            // For some reason GetEntDataEnt2 doesn't think the data is an entity. (Maybe because it's a void *?)
            int a = GetEntData(barricade_point, g_offset_barricade_point_physics_ent);
            int b = view_as<int>(GetEntityAddress(barricade));
            if (a != b)
            {
                // Scale damage to non-primary barricades.
                damage *= 1.0 - damage_reduction;
                if (damage <= 0.0)
                {
                    return Plugin_Stop;
                }
                result = Plugin_Changed;
            }
        }
    }

    float health = float(GetEntHealth(barricade));
    float max_health = float(g_sv_barricade_health.IntValue);
    if (max_health < 1.0)
    {
        max_health = 1.0;
    }

    // Allow players to recollect healthy boards from barricades. (ConVar)
    float recollect_health = g_qol_barricade_retrieve_health.FloatValue;
    if (recollect_health >= 0.0 && attacker > 0 && attacker <= MaxClients && IsValidEdict(inflictor))
    {
        char classname[CLASSNAME_MAX];

        // Check for hammer charge attack.
        if (IsClassnameEqual(inflictor, classname, sizeof(classname), WEAPON_BARRICADE) &&
            GetEntPropFloat(inflictor, Prop_Send, "m_flLastChargeLength") > 0.0)
        {
            float idle_time = GetEntPropFloat(inflictor, Prop_Send, "m_flTimeWeaponIdle");
            int spawner = EntRefToEntIndex(g_board_spawner_ref);

            // Limit of one board per swing.
            if (g_player_unbarricade_time[attacker] < idle_time &&
                health / max_health >= recollect_health &&
                spawner != INVALID_ENT_REFERENCE)
            {
                g_player_unbarricade_time[attacker] = idle_time;

                // Take board back.
                float origin[3];
                GetEntOrigin(barricade, origin);

                float angles[3];
                GetEntRotation(barricade, angles);

                TeleportEntity(spawner, origin, angles, NULL_VECTOR);
                AcceptEntityInput(spawner, "InputSpawn");

                EmitSoundToAll(SOUND_BARRICADE_COLLECT, barricade);

                // Notify other plugins that barricade was recollected.
                any ignored;
                Call_StartForward(g_forward_barricade_collected);
                Call_PushCell(attacker);
                Call_PushCell(barricade);
                Call_Finish(ignored);

                RemoveEdict(barricade);
            }

            // Never take damage from charged hammer attack since players only
            // expect to be able recollect the board.
            return Plugin_Stop;
        }
    }

    float health_remaining = health - damage;

    // Play sound according to amount of damage taken. (ConVar)
    float sound_volume = g_qol_barricade_damage_volume.FloatValue;
    if (sound_volume > 0.0)
    {
        char sound_name[128];
        if (health_remaining <= 0.0)
        {
            static int previous[SHUFFLE_SOUND_COUNT] = { -1, ... };
            int sound_index = ShuffleSoundIndex(sizeof(SOUNDS_BARRICADE_BREAK), previous);
            strcopy(sound_name, sizeof(sound_name), SOUNDS_BARRICADE_BREAK[sound_index]);
        }
        else
        {
            static int previous[SHUFFLE_SOUND_COUNT] = { -1, ... };
            int sound_index = ShuffleSoundIndex(sizeof(SOUNDS_BARRICADE_DAMAGE), previous);
            strcopy(sound_name, sizeof(sound_name), SOUNDS_BARRICADE_DAMAGE[sound_index]);
        }

        // Randomize pitch slightly.
        int pitch = SNDPITCH_NORMAL + RoundToNearest(GetURandomFloat() * 10.0 - 5.0);

        EmitSoundToAll(sound_name, barricade, SNDCHAN_AUTO, SNDLEVEL_NORMAL,
            SND_CHANGEVOL | SND_CHANGEPITCH, sound_volume, pitch);
    }

    // Map brightness of barricade to its health. (ConVar)
    float blackest = g_qol_barricade_show_damage.FloatValue;
    if (blackest > 0.0)
    {
        float ratio = health_remaining / max_health * blackest + (1.0 - blackest);
        if (ratio < 1.0 - blackest)
        {
            ratio = 1.0 - blackest;
        }

        int value = RoundToNearest(ratio * 255.0);
        if (value > 255)
        {
            value = 255;
        }
        else if (value < 0)
        {
            value = 0;
        }

        SetEntityRenderColor(barricade, value, value, value, 0xFF);
    }

    return result;
}

/**
 * Changes ammo with 0 rounds to have 1 round. This might only happen
 * with boards.
 */
public void OnFrame_FixupAmmo(int unused)
{
    int count = g_spawning_ammo_boxes.Length;
    for (int i = 0; i < count; ++i)
    {
        int ammo_box = EntRefToEntIndex(g_spawning_ammo_boxes.Get(i));
        if (ammo_box != INVALID_ENT_REFERENCE &&
            GetEntProp(ammo_box, Prop_Data, "m_iAmmoCount") == 0)
        {
            SetEntProp(ammo_box, Prop_Data, "m_iAmmoCount", 1);
        }
    }

    g_spawning_ammo_boxes.Clear();
}

/**
 * Postpone by one frame to check ammo amount because we can't read
 * the ammo amount assigned to it by the random_spawner from SpawnPost.
 * (ConVar)
 */
public void Hook_FixAmmoAmount(int item_ammo_box)
{
    if (g_qol_board_ammo_fix.BoolValue)
    {
        if (g_spawning_ammo_boxes.Length == 0)
        {
            RequestFrame(OnFrame_FixupAmmo, 0);
        }

        g_spawning_ammo_boxes.Push(EntIndexToEntRef(item_ammo_box));
    }
}

/**
 * Try to free pickups clipping into geometry.
 *
 * @param client        Player that has item picked up.
 * @param pickup        Edict of object held by player.
 *
 * @return True if the pickup was stuck but is now free; otherwise
 *         returns false.
 */
bool UnstickPickup(int client, int pickup)
{
    bool was_stuck = false;

    float pickup_origin[3];
    GetEntOrigin(pickup, pickup_origin);

    float view_origin[3];
    GetClientEyePosition(client, view_origin);

    float to_player[3];
    SubtractVectors(view_origin, pickup_origin, to_player);

    float step_percent = 0.1;

    float min_bounds[3];
    float max_bounds[3];
    GetEntPropVector(pickup, Prop_Data, "m_vecMins", min_bounds);
    GetEntPropVector(pickup, Prop_Data, "m_vecMaxs", max_bounds);

    int mask = MASK_SOLID & (~CONTENTS_MONSTER);

    TR_TraceHullFilter(pickup_origin, pickup_origin, min_bounds, max_bounds,
        mask, Trace_IgnoreEntPlayersAndNPCs, pickup);

    was_stuck = TR_DidHit();

    if (was_stuck)
    {
        float vertical_step = GetVectorLength(to_player, false) * step_percent;
        float upwards[3];
        CopyVector(pickup_origin, upwards);

        for (float step = step_percent; step <= 1.1; step += step_percent)
        {
            // First check if object can be unstuck by pushing it.
            // We push before pull so we don't pull it through the world.
            float awaywards[3];
            CopyVector(to_player, awaywards);
            ScaleVector(awaywards, -step);
            AddVectors(pickup_origin, awaywards, awaywards);

            TR_TraceHullFilter(awaywards, awaywards, min_bounds, max_bounds,
                mask, Trace_IgnoreEntPlayersAndNPCs, pickup);

            if (!TR_DidHit())
            {
                // Don't actually push the object because we might push
                // it through the world!
                was_stuck = false;
                break;
            }

            // Check if object can be unstuck by pulling it.
            float playerwards[3];
            CopyVector(to_player, playerwards);
            ScaleVector(playerwards, step);
            AddVectors(pickup_origin, playerwards, playerwards);

            TR_TraceHullFilter(playerwards, playerwards, min_bounds, max_bounds,
                mask, Trace_IgnoreEntPlayersAndNPCs, pickup);

            if (!TR_DidHit())
            {
                TeleportEntity(pickup, playerwards, NULL_VECTOR, NULL_VECTOR);
                break;
            }

            // Finally check raising the entity.
            upwards[Z] += vertical_step;

            TR_TraceHullFilter(upwards, upwards, min_bounds, max_bounds,
                mask, Trace_IgnoreEntPlayersAndNPCs, pickup);

            if (!TR_DidHit())
            {
                TeleportEntity(pickup, upwards, NULL_VECTOR, NULL_VECTOR);
                break;
            }
        }
    }

    return was_stuck;
}

/**
 * Unstuck items grabbed by the player. Some maps have items that are otherwise
 * unobtainable.
 *
 * Store item's original collision group.
 */
public void OnFrame_WatchCarriedObject(int player_pickup_ref)
{
    int player_pickup = EntRefToEntIndex(player_pickup_ref);
    if (player_pickup != INVALID_ENT_REFERENCE)
    {
        int player = GetEntPropEnt(player_pickup, Prop_Send, "m_pPlayer");
        if (player > 0 && player <= MaxClients && IsClientInGame(player))
        {
            int pickup = GetEntPropEnt(player_pickup, Prop_Data, "m_attachedEntity");
            if (IsValidEdict(pickup))
            {
                // Store object's position. If it doesn't change in one frame
                // consider it stuck. (ConVar)
                if (g_qol_stuck_object_fix.BoolValue &&
                    g_player_do_pickup_fix[player])
                {
                    float pickup_origin[3];
                    GetEntOrigin(pickup, pickup_origin);
                    CopyVector(pickup_origin, g_player_pickup_origins[player]);

                    RequestFrame(OnFrame_FixStuckObject, player_pickup_ref);
                }

                CachePropCollisionGroup(player_pickup, pickup);
            }

            g_player_do_pickup_fix[player] = true;
        }

    }
}

/**
 * Store pickup's original collision group. (ConVar)
 */
void CachePropCollisionGroup(int player_pickup, int pickup)
{
    if (g_qol_zombie_prop_exploit_fix.BoolValue)
    {
        int original_collision_group = GetEntData(player_pickup, g_offset_original_collision_group, 4);

        int pickup_ref = EntIndexToEntRef(pickup);

        // Lookup original collision group.
        int index = g_carried_props.FindValue(pickup_ref, view_as<int>(PROP_COLLISION_ENT_REF));
        if (index != -1)
        {
            original_collision_group = g_carried_props.Get(index, view_as<int>(PROP_COLLISION_GROUP));
        }
        else
        {
            // Add new entry.
            int[] tuple = new int[PROP_COLLISION_TUPLE_SIZE];
            tuple[view_as<int>(PROP_COLLISION_ENT_REF)] = pickup_ref;
            tuple[view_as<int>(PROP_COLLISION_GROUP)] = original_collision_group;

            g_carried_props.PushArray(tuple);
        }
    }
}

/**
 * Unstick object held by player if its in the same position as it was
 * last frame.
 */
public void OnFrame_FixStuckObject(int player_pickup_ref)
{
    int player_pickup = EntRefToEntIndex(player_pickup_ref);
    if (player_pickup != INVALID_ENT_REFERENCE)
    {
        int player = GetEntPropEnt(player_pickup, Prop_Send, "m_pPlayer");
        int pickup = GetEntPropEnt(player_pickup, Prop_Data, "m_attachedEntity");

        if (player > 0 && player <= MaxClients && IsClientInGame(player) &&
            IsValidEdict(pickup) &&
            !IsEntityHeldByPlayer(pickup, player))
        {
            float pickup_origin[3];
            GetEntOrigin(pickup, pickup_origin);

            if (VectorEqual(pickup_origin, g_player_pickup_origins[player]) &&
                UnstickPickup(player, pickup))
            {
                // Don't try to unstick same object twice.
                g_player_do_pickup_fix[player] = false;

                // Recreate player_pickup as previous one will fight against us and keep pickup stuck.
                AcceptEntityInput(player_pickup, "Kill");
                AcceptEntityInput(pickup, "Use", player, player);
            }
        }
    }
}

/**
 * Wait one frame for player_pickup to initialize.
 */
public void Hook_UnstickCarriedObject(int player_pickup)
{
    RequestFrame(OnFrame_WatchCarriedObject, EntIndexToEntRef(player_pickup));
}

/**
 * Set object to collision group that prevents it being used like a weapon. (ConVar)
 */
public void OnFrame_PreventWeaponizedProp(int pickup_ref)
{
    int index = g_carried_props.FindValue(pickup_ref, view_as<int>(PROP_COLLISION_ENT_REF));
    if (index != -1)
    {
        int pickup = EntRefToEntIndex(pickup_ref);
        if (pickup != INVALID_ENT_REFERENCE &&
            g_qol_weaponized_object_fix.BoolValue)
        {
            // Prevent prop from being used as a weapon.
            SetEntCollisionGroup(pickup, COLLISION_GROUP_CARRIED_OBJECT);
        }
        else
        {
            // Invalid pickup, we can safely remove this index.
            RemoveArrayListElement(g_carried_props, index);
        }
    }
}

/**
 * Restore collision group used by an object before it was picked up. (ConVar)
 */
public void OnFrame_RestorePropCollisionGroup(int pickup_ref)
{
    int index = g_carried_props.FindValue(pickup_ref, view_as<int>(PROP_COLLISION_ENT_REF));
    if (index != -1)
    {
        int pickup = EntRefToEntIndex(pickup_ref);
        if (pickup != INVALID_ENT_REFERENCE &&
            g_qol_dropped_object_collision_fix.BoolValue)
        {
            // Return object to its original collision group.
            int original_collision_group = g_carried_props.Get(index, view_as<int>(PROP_COLLISION_GROUP));
            SetEntCollisionGroup(pickup, original_collision_group);
        }

        RemoveArrayListElement(g_carried_props, index);
    }
}

/**
 * Called when player_pickup carried object is dropped.

 * Prevent exploit where carried physics objects can be used as weapons. (ConVar)
 *
 * Also ensures the prop returns to its original collision group. (ConVar)
 */
public Action Hook_PreventWeaponizedProps(
    int player_pickup,
    int activator,
    int caller,
    UseType use_type,
    float value)
{
    if (use_type == Use_Off)
    {
        int pickup = GetEntPropEnt(player_pickup, Prop_Data, "m_attachedEntity");
        if (pickup != -1)
        {
            int pickup_ref = EntIndexToEntRef(pickup);

            // Anyone else holding it?
            if (IsEntityHeldByPlayer(pickup, activator))
            {
                RequestFrame(OnFrame_PreventWeaponizedProp, pickup_ref);
            }
            else
            {
                RequestFrame(OnFrame_RestorePropCollisionGroup, pickup_ref);
            }
        }
    }
}

/**
 * Update arrow projectiles so they can be recollected when shot into props
 * and move with the object they're attached to.
 */
public void OnFrame_WatchArrows(int unused)
{
    for (int i = 0; i < g_arrow_projectiles.Length; )
    {
        int arrow_ref = g_arrow_projectiles.Get(i);
        int arrow = EntRefToEntIndex(arrow_ref);

        if (arrow == INVALID_ENT_REFERENCE)
        {
            RemoveArrayListElement(g_arrow_projectiles, i);
        }
        else if (!GetEntProp(arrow, Prop_Send, "_flying"))
        {
            int attached = GetEntPropEnt(arrow, Prop_Send, "_attachedEnt");
            int bone = GetEntProp(arrow, Prop_Send, "_attachedBone");

            // Nothing was hit or a simple object (non-ragdoll) was hit.
            if (attached == -1 || bone == -1 || bone == 0)
            {
                // Inflate bounds for easier pickup. The arrow's bounding box
                // is axis aligned in this helps cases where its narrow
                // side is perpendicular to the wall.
                float bounds[3] = { 10.0, ... };
                SetEntPropVector(arrow, Prop_Send, "m_vecMaxs", bounds);

                NegateVector(bounds);
                SetEntPropVector(arrow, Prop_Send, "m_vecMins", bounds);

                // Next trace for the exact contact point the arrow made
                // with the attachment/wall. If we don't do this the arrow
                // can become embedded in the object or be visibly distant
                // from it.
                float origin[3];
                GetEntOrigin(arrow, origin);

                float rotation[3];
                GetEntRotation(arrow, rotation);

                // Rotation to unit vector. Unit vector points away from
                // arrow's tip.
                float angles[3];
                GetAngleVectors(rotation, angles, NULL_VECTOR, NULL_VECTOR);
                ScaleVector(angles, 16.0);

                // Slightly behind the arrow.
                float start[3];
                AddVectors(origin, angles, start);

                // Slightly ahead of the arrow.
                float end[3];
                NegateVector(angles);
                AddVectors(origin, angles, end);

                if (attached != -1)
                {
                    // Just trace for extact contact point with attachment.
                    TR_TraceRayFilter(start, end, MASK_SOLID, RayType_EndPoint, Trace_Match, attached);
                }
                else
                {
                    // Trace for exact contact point but also any brush entity to attach to.
                    TR_TraceRayFilter(start, end, MASK_SOLID, RayType_EndPoint, Trace_IgnoreEntPlayersAndNPCs, arrow);
                }

                if (TR_DidHit())
                {
                    int hit = TR_GetEntityIndex();
                    if (attached == -1 && hit > 0)
                    {
                        attached = hit;
                    }
                    TR_GetEndPosition(end);
                    ScaleVector(angles, -0.125);    // 2 units
                    AddVectors(end, angles, end);

                    // Teleport arrow to contact point.
                    TeleportEntity(arrow, end, NULL_VECTOR, NULL_VECTOR);
                }

                // Ignore object if it's a weapon (otherwise the arrow cannot be retrieved).
                if (attached != -1 && !SDKCall(g_sdkcall_is_combat_weapon, attached))
                {
                    // Attach arrow to object.
                    SDKCall(g_sdkcall_set_parent, arrow, attached, bone);

                    // Clear attached bone to stop NMRiH overriding parent's movement.
                    SetEntPropEnt(arrow, Prop_Send, "_attachedBone", -1);
                }
            }

            RemoveArrayListElement(g_arrow_projectiles, i);
        }
        else
        {
            ++i;
        }
    }

    if (g_arrow_projectiles.Length > 0)
    {
        RequestFrame(OnFrame_WatchArrows, 0);
    }
}

/**
 * Add new arrow projectiles to a list where they can be tracked per-frame.
 */
public void Hook_ArrowSpawnPost(int arrow)
{
    if (g_qol_arrow_fix.BoolValue)
    {
        if (g_arrow_projectiles.Length == 0)
        {
            RequestFrame(OnFrame_WatchArrows, 0);
        }

        g_arrow_projectiles.Push(EntIndexToEntRef(arrow));
    }
}

/**
 * Create a backup spawn point for an active one in case it becomes
 * disabled or removed before the next respawn area.
 *
 * Nothing needs to be done on casual difficulty because players
 * respawn automatically anyway.
 */
public void Hook_NewSpawnPoint(int spawn_point)
{
    // Ignore disabled spawn points -- they are handled by Output_OnSpawnPointEnable.
    // Ignore when difficulty is casual -- players will always respawn anyway.
    if (IsValidEdict(spawn_point) &&
        GetEntData(spawn_point, g_offset_playerspawn_enabled, 1) != 0 &&
        !IsCasual())
    {
        HandleRespawnEvent();

        int spawn_point_ref = EntIndexToEntRef(spawn_point);

        // Map must be fully loaded before Sourcemod will let us create entities.
        if (g_map_loaded &&
            g_spawn_point_copies.FindValue(spawn_point_ref) == -1 &&  // Don't copy copies!
            !IsSurvival() &&
            IsValidEdict(spawn_point))  // Check spawn point again. It was reported by Holy Crap that nmo_subside threw an error below
        {
            // Create a copy of this spawn point.
            int spawn_copy = CreateEntityByName(PLAYER_SPAWN_POINT);
            if (spawn_copy != -1)
            {
                int copy_ref = EntIndexToEntRef(spawn_copy);
                g_spawn_point_copies.Push(copy_ref);

                float vec[3];

                GetEntOrigin(spawn_point, vec);
                // Raise spawn point slightly so players don't spawn under the world!
                vec[Z] += 2.0;
                DispatchKeyValueVector(spawn_copy, "origin", vec);

                GetEntRotation(spawn_point, vec);
                DispatchKeyValueVector(spawn_copy, "angles", vec);

                DispatchKeyValue(spawn_copy, "default_spawn", "0");

                DispatchSpawn(spawn_copy);
            }
        }
    }
}

/**
 * Setup DHooks on a new zombie and allow random chance for National Guard
 * to spawn as a crawler.
 */
public void DHook_CheckNationalGuardCrawler(int zombie)
{
    // Legacy QOL cvar, custom National Guard crawler health.
    if (IsNationalGuard(zombie) && IsCrawler(zombie))
    {
        int health = g_qol_national_guard_crawler_health.IntValue;
        if (health < 1)
        {
            health = 1;
        }
        SetEntProp(zombie, Prop_Data, "m_iHealth", health);
    }
}

/**
 * Rate limit ice skating fix.
 */
public Action Command_FixPlayerSkating(int client, int args)
{
    float cooldown = g_qol_skate_cooldown.FloatValue;
    if (client > 0 && args < 1 && cooldown >= 0.0)
    {
        bool use_cooldown = true;

        AdminId admin = GetUserAdmin(client);
        if (admin != INVALID_ADMIN_ID && GetAdminFlags(admin, Access_Effective))
        {
            use_cooldown = false;
        }

        float last = g_player_last_skate_time[client];
        float now = GetGameTime();

        if (!use_cooldown || now > last + cooldown)
        {
            g_player_last_skate_time[client] = now;
            FixPlayerSkating(client);
        }
        else
        {
            float seconds = (last + cooldown) - now;
            // "Please wait %d seconds."
            PrintToChat(client, "%T", "@skate-cooldown", client, RoundToCeil(seconds));
        }
    }

    return Plugin_Handled;
}

/**
 * Fix jittery/slidey player movement by respawning them.
 *
 * This may be caused by animations failing to update after model data has
 * been reloaded (e.g. after alt-tabbing). Affected client's that enter
 * thirdperson mode can see their character not animating and jittering.
 *
 */
void FixPlayerSkating(int client)
{
    if (IsPlayerAlive(client))
    {
        if (g_in_cutscene)
        {
            // Forbid during cutscenes because the respawned player would
            // be able to move again.
            PrintToChat(client, "%T", "@skate-cutscene", client);
            return;
        }
        else if (GetEntProp(client, Prop_Send, "m_bGrabbed"))
        {
            // Grabbed players will not re-equip weapons.
            PrintToChat(client, "%T", "@skate-grabbed", client);
            return;
        }
        else if (GetEntProp(client, Prop_Send, "m_bDucked"))
        {
            // Not sure how to restore player in crouched position, so forbid
            // to prevent them getting stuck in ceiling.
            PrintToChat(client, "%T", "@skate-ducked", client);
            return;
        }
        else if (g_round_reset_time > g_round_start_time)
        {
            // Prevent players breaking free of pre-round freeze time.
            PrintToChat(client, "%T", "@skate-preround", client);
            return;
        }

        char classname[CLASSNAME_MAX];
        int pickup = -1;

        int use_entity = GetEntPropEnt(client, Prop_Send, "m_hUseEntity");
        if (use_entity != -1 && IsValidEdict(use_entity))
        {
            static const char TRIGGER_PROGRESS_PREFIX[] = "trigger_progress";

            if (IsClassnameEqual(use_entity, classname, sizeof(classname), PLAYER_PICKUP))
            {
                pickup = GetEntPropEnt(use_entity, Prop_Data, "m_attachedEntity");
                if (pickup != -1 && !IsValidEdict(pickup))
                {
                    pickup = -1;
                }
            }
            else if (!strncmp(classname, TRIGGER_PROGRESS_PREFIX, sizeof(TRIGGER_PROGRESS_PREFIX) - 1))
            {
                // Fire extinguisher spray effect can become stuck. I assume it could also lock up objectives.
                PrintToChat(client, "%T", "@skate-trigger-progress", client);
                return;
            }
        }

        float position[3];
        float angles[3];
        float velocity[3];

        GetClientAbsOrigin(client, position);
        GetClientEyeAngles(client, angles);
        velocity[X] = GetEntPropFloat(client, Prop_Send, "m_vecVelocity[0]");
        velocity[Y] = GetEntPropFloat(client, Prop_Send, "m_vecVelocity[1]");
        velocity[Z] = GetEntPropFloat(client, Prop_Send, "m_vecVelocity[2]");

        int health = GetClientHealth(client);
        float stamina = GetClientStamina(client);
        float infection_time = GetEntPropFloat(client, Prop_Send, "m_flInfectionTime");
        float death_time = GetEntPropFloat(client, Prop_Send, "m_flInfectionDeathTime");
        int vaccinated = GetEntProp(client, Prop_Send, "_vaccinated");
        int bleeding_out = GetEntProp(client, Prop_Send, "_bleedingOut");

        // Preserve survival tokens (should also prevent map from restarting
        // while player respawns in objective mode).
        int tokens = GetEntProp(client, Prop_Send, "m_iTokens");
        SetEntProp(client, Prop_Send, "m_iTokens", tokens + 1);

        // Preserve oxygen level.
        float air_finished = GetEntPropFloat(client, Prop_Data, "m_AirFinished");
        int drown_damage = GetEntProp(client, Prop_Data, "m_idrowndmg");
        int drown_restored = GetEntProp(client, Prop_Data, "m_idrownrestored");
        int drown_rate = GetEntProp(client, Prop_Data, "m_nDrownDmgRate");

        DataPack data = new DataPack();
        if (!data)
        {
            LogError("Couldn't allocate DataPack for respawn.");
            return;
        }

        WritePackFloat(data, GetGameTime());
        WritePackFloat(data, infection_time);
        WritePackFloat(data, death_time);

        WritePackVector(data, position);
        WritePackVector(data, angles);
        WritePackVector(data, velocity);

        WritePackCell(data, health);
        WritePackFloat(data, stamina);
        WritePackCell(data, vaccinated);
        WritePackCell(data, bleeding_out);

        // Don't need to store tokens as they've already been set.

        WritePackFloat(data, air_finished);
        WritePackCell(data, drown_damage);
        WritePackCell(data, drown_restored);
        WritePackCell(data, drown_rate);

        // It's important to read player's ammo amount before dropping weapons
        // because doing the opposite causes grenades to permanently consume
        // inventory space.
        int ammo_size = GetEntPropArraySize(client, Prop_Send, PROP_NAME_PLAYER_AMMO);
        WritePackCell(data, ammo_size);
        for (int i = 0; i < ammo_size; ++i)
        {
            int ammo = GetEntProp(client, Prop_Send, PROP_NAME_PLAYER_AMMO, _, i);
            WritePackCell(data, ammo);
        }

        int active_weapon = GetClientActiveWeapon(client);
        int active_weapon_sequence = -1;
        if (active_weapon != -1 && IsValidEdict(active_weapon))
        {
            active_weapon_sequence = GetEntSequence(active_weapon);
        }

        static const char PROP_NAME_WEAPONS[] = "m_hMyWeapons";
        int weapon_size = GetEntPropArraySize(client, Prop_Send, PROP_NAME_WEAPONS);
        WritePackCell(data, weapon_size);
        for (int i = 0; i < weapon_size; ++i)
        {
            int weapon = GetEntPropEnt(client, Prop_Send, PROP_NAME_WEAPONS, i);
            if (weapon != -1)
            {
                SDKHooks_DropWeapon(client, weapon, NULL_VECTOR, NULL_VECTOR);
                weapon = EntIndexToEntRef(weapon);
            }
            WritePackCell(data, weapon);
        }

        WritePackCell(data, EntIndexToEntRef(active_weapon));
        WritePackCell(data, active_weapon_sequence);

        WritePackCell(data, pickup);

        g_skating_player_respawning[client] = true;
        g_skating_player_data[client] = data;

        SDKCall(g_sdkcall_player_respawn, client);
    }
}

/**
 * Watch for barricade placement to play hammering sound to other players. (ConVar)
 */
public Action Timer_GameTimer(Handle timer)
{
    for (int i = 1; i < MaxClients; ++i)
    {
        bool stop_hammering = true;

        if (IsClientInGame(i) && IsPlayerAlive(i))
        {
            // Emit barricade sounds to other players. (ConVar)
            if (g_qol_barricade_hammer_volume.BoolValue && g_player_weapon_type[i] == WEAPON_TYPE_BARRICADE)
            {
                stop_hammering = HandleBarricadeHammerSounds(i);
            }
        }

        if (stop_hammering && g_player_barricade_time[i] > 0.0)
        {
            g_player_barricade_time[i] = 0.0;

            // Stop sound for everyone. This should fix the default behaviour
            // behaviour which keeps playing hammering sound when dead.
            EmitSoundToAll(SOUND_NULL, i, SNDCHAN_ITEM);
        }
    }

    return Plugin_Continue;
}

/**
 * Handle emitting barricade sounds to other clients.
 *
 * @return True if the player isn't hammering; otherwise false.
 */
bool HandleBarricadeHammerSounds(int client)
{
    bool stop_hammering = true;

    int hammer = GetClientActiveWeapon(client);
    if (hammer != -1 && GetEntSequence(hammer) == SEQUENCE_BARRICADE_HAMMER_BARRICADE)
    {
        float idle_time = GetEntPropFloat(hammer, Prop_Send, "m_flTimeWeaponIdle");
        if (idle_time > g_player_barricade_time[client])
        {
            g_player_barricade_time[client] = idle_time;

            // Find clients to send sound to.
            int others[MAXPLAYERS];
            int count = GetOtherClients(client, others);

            if (count > 0)
            {
                // Retrieve sound name and parameters from game sound.
                char sound_name[128];
                int channel = SNDCHAN_AUTO;
                int sound_level = SNDLEVEL_NORMAL;
                float volume = SNDVOL_NORMAL;
                int pitch = SNDPITCH_NORMAL;

                GetGameSoundParams("Weapon_Hammer.Barricade", channel,
                    sound_level, volume, pitch, sound_name,
                    sizeof(sound_name), client);

                // Use a known channel so we can stop sound later.
                channel = SNDCHAN_ITEM;
                volume = g_qol_barricade_hammer_volume.FloatValue;
                sound_level = SNDLEVEL_NORMAL + 3;

                // Play hammering sound.
                EmitSound(others, count, sound_name, client, channel, sound_level,
                    SND_CHANGEVOL | SND_CHANGEPITCH, volume, pitch);
            }
        }

        stop_hammering = false;
    }

    return stop_hammering;
}

/**
 \* Check if sequence represents a zombie bite attack.
 \*/
bool IsZombieBiteSequence(int sequence)
{
    return sequence == SEQUENCE_BITE || sequence == SEQUENCE_SHAMBLER_BITE || sequence == SEQUENCE_RUNNER_BITE || sequence == SEQUENCE_CRAWLER_BITE;
}

/**
 * Check if a shambler is also a crawler.
 */
bool IsCrawler(int shambler)
{
    return GetEntData(shambler, g_offset_is_crawler, 1) != 0;
}

/**
 * Check whether a zombie is a National Guard.
 */
bool IsNationalGuard(int zombie)
{
    return GetEntData(zombie, g_offset_is_national_guard, 1) != 0;
}

/**
 * Trace for particular entity.
 */
public bool Trace_Match(int entity, int contents_mask, int to_match)
{
    return entity == to_match;
}

/**
 * Trace, ignoring entity.
 */
public bool Trace_Ignore(int entity, int contents_mask, int to_ignore)
{
    return entity != to_ignore;
}

/**
 * Trace, ignoring entity and players.
 */
public bool Trace_IgnoreEntAndPlayers(int entity, int contents_mask, int to_ignore)
{
    return entity != to_ignore && (entity <= 0 || entity > MaxClients);
}

/**
 * Trace filter to ignore players, NPCs and the specified entity.
 */
public bool Trace_IgnoreEntPlayersAndNPCs(int entity, int contents_mask, int to_ignore)
{
    bool hit = entity != to_ignore && (entity <= 0 || entity > MaxClients);
    if (hit && entity > MaxClients)
    {
        hit = !SDKCall(g_sdkcall_is_npc, entity);
    }
    return hit;
}

/**
 * Trace for objects between a zombie and its target that should prevent
 * a grab.
 *
 * This hits more things than Trace_ZombieAttack to prevent zombies
 * grabbing players crouched in objects who will then be unable to shove
 * the zombie away.
 */
public bool Trace_ZombieGrab(int entity, int contents_mask, int to_ignore)
{
    bool hit = entity != to_ignore && (entity <= 0 || entity > MaxClients);
    if (hit && entity > MaxClients)
    {
        // Ignore NPCs.
        hit = !SDKCall(g_sdkcall_is_npc, entity);
    }
    return hit;
}

/**
 * Trace for objects between a zombie and its target that should prevent
 * damage.
 */
public bool Trace_ZombieAttack(int entity, int contents_mask, int to_ignore)
{
    // Ignore players and filter ent.
    bool hit = entity != to_ignore && (entity <= 0 || entity > MaxClients);
    if (hit && entity > MaxClients)
    {
        // Ignore physics objects and NPCs.
        hit = GetEntityMoveType(entity) != MOVETYPE_VPHYSICS && !SDKCall(g_sdkcall_is_npc, entity);
    }
    return hit;
}

/**
 * Collect zombies hit by trace.
 */
public bool Trace_PlayerMultishove(int entity, int contents_mask, ArrayList zombies)
{
    bool stop = entity == 0;

    if (entity > MaxClients)
    {
        if (SDKCall(g_sdkcall_is_npc, entity))
        {
            zombies.Push(entity);
        }
        else
        {
            stop = true;
        }
    }

    return stop;
}

/**
 * Fill an array with the IDs of clients currently in-game and who are
 * not the client specified.
 *
 * @return The number of other clients found.
 */
int GetOtherClients(int to_ignore, int others[MAXPLAYERS])
{
    int count = 0;
    for (int i = 0; i < MaxClients; ++i)
    {
        int client = i + 1;
        if (client != to_ignore && IsClientInGame(client) && !IsFakeClient(client))
        {
            others[count] = client;
            ++count;
        }
    }
    return count;
}

/**
 * Check if game difficulty is casual.
 */
bool IsCasual()
{
    char value[32];
    g_sv_difficulty.GetString(value, sizeof(value));
    return StrEqual(value, "casual");
}

/**
 * Check if game mode is survival.
 */
bool IsSurvival()
{
    return SDKCall(g_sdkcall_are_tokens_given_from_kills);
}

/**
 * Return true if classname represents a melee weapon.
 */
bool IsMeleeWeapon(const char[] classname)
{
    static const char MELEE_PREFIX[] = "me_";
    static const char TOOL_PREFIX[] = "tool_";

    return StrEqual(classname, ITEM_MAGLITE) ||
        !strncmp(classname, MELEE_PREFIX, sizeof(MELEE_PREFIX) - 1) ||
        (!strncmp(classname, TOOL_PREFIX, sizeof(TOOL_PREFIX) - 1) && !StrEqual(classname[sizeof(TOOL_PREFIX) - 1], "flare_gun"));
}

/**
 * Retrieve edict's classname and compare it to a string.
 */
stock bool IsClassnameEqual(int entity, char[] classname, int classname_size, const char[] compare_to)
{
    GetEdictClassname(entity, classname, classname_size);
    return StrEqual(classname, compare_to);
}

/**
 * Quickly remove an element from ArrayList by swapping it with last element
 * and then popping the back.
 */
stock void RemoveArrayListElement(ArrayList list, int index)
{
    if (list && index >= 0 && index < list.Length)
    {
        int last = 0;
        if (list.Length > 1)
        {
            last = list.Length - 1;
            list.SwapAt(index, last);
        }
        list.Erase(last);
    }
}

/**
 * Because Sourcemod's IsPlayerAlive returns true when player is in welcome screen in NMRiH.
 */
stock bool NMRiH_IsPlayerAlive(int client)
{
    bool alive = false;
    if (client > 0 && client <= MaxClients && IsClientInGame(client))
    {
        alive = GetEntData(client, g_offset_player_state, 4) == STATE_ACTIVE;
    }
    return alive;
}

/**
 * Because Sourcemod's EquipPlayerWeapon doesn't work in NMRiH.
 */
stock void NMRIH_EquipPlayerWeapon(int client, int weapon, int sequence = -1)
{
    if (IsClientInGame(client) && IsValidEdict(weapon) && GetEntOwner(weapon) == client)
    {
        char weapon_name[CLASSNAME_MAX];
        GetEdictClassname(weapon, weapon_name, sizeof(weapon_name));
        ClientCommand(client, "use %s", weapon_name);

        if (sequence != -1)
        {
            DataPack data = new DataPack();
            if (data)
            {
                WritePackCell(data, weapon);
                WritePackCell(data, sequence);
                RequestFrame(OnFrame_SetWeaponSequence, data);
            }
        }
    }
}

/**
 * Restore a weapon's sequence. Used when player is respawned to fix
 * skating.
 */
public void OnFrame_SetWeaponSequence(DataPack data)
{
    data.Reset();

    int weapon = ReadPackCell(data);
    int sequence = ReadPackCell(data);

    delete data;

    SetEntProp(weapon, Prop_Send, "m_nSequence", sequence);
}

/**
 * Insert server tag if it doesn't exist already.
 */
stock void AddServerTag2(const char[] tag)
{
    if (!FindServerTag(tag))
    {
        char tags[256];
        g_sv_tags.GetString(tags, sizeof(tags));

        int len = strlen(tags);
        if (len > 0)
        {
            Format(tags[len], sizeof(tags) - len, ",%s", tag);
            g_sv_tags.SetString(tags);
        }
        else
        {
            g_sv_tags.SetString(tag);
        }
    }
}

/**
 * Remove a complete tag match.
 */
stock void RemoveServerTag2(const char[] tag)
{
    FindServerTag(tag, true);
}

/**
 * Check if server has a tag and optionally remove it.
 *
 * Matches the entire tag rather than just a substring of a tag.
 */
stock bool FindServerTag(const char[] tag, bool remove = false)
{
    bool found = false;

    char tags[256];
    g_sv_tags.GetString(tags, sizeof(tags));
    int tags_len = strlen(tags);

    int tag_len = strlen(tag);
    if (tag_len > 0)
    {
        int search = 0; // offset into tags[] for last match
        int offset = 0; // offset from search
        while (search < tags_len && (offset = StrContains(tags[search], tag)) != -1)
        {
            if (search + offset == 0)
            {
                // Expect end of string or a comma for complete match.
                if (tags[tag_len] == '\0')
                {
                    if (remove)
                    {
                        g_sv_tags.SetString("");
                        found = true;
                    }
                }
                else if (tags[tag_len] == ',')
                {
                    if (remove)
                    {
                        g_sv_tags.SetString(tags[tag_len + 1]);
                        found = true;
                    }
                }
                else
                {
                    found = false;
                }
            }
            else if (tags[search + offset - 1] == ',')
            {
                // Preceded by comma, is it followed by comma or end of string?
                int tail_dist = search + offset + tag_len;
                char trailing = tags[tail_dist];
                if (trailing == '\0')
                {
                    if (remove)
                    {
                        tags[search + offset - 1] = '\0';
                        g_sv_tags.SetString(tags);
                        found = true;
                    }
                }
                else if (trailing == ',')
                {
                    if (remove)
                    {
                        int x = search + offset;
                        strcopy(tags[x], sizeof(tags) - x, tags[tail_dist + 1]);
                        g_sv_tags.SetString(tags);
                        found = true;
                    }
                }
            }

            if (found)
            {
                break;
            }

            search += offset + tag_len + 1;
        }
    }

    return found;
}

/**
 * Try to select a sound index that hasn't been played yet.
 */
stock int ShuffleSoundIndex(int count, int previous[SHUFFLE_SOUND_COUNT])
{
    int sound_index = 0;

    if (count > SHUFFLE_SOUND_COUNT)
    {
        for (int i = 0; i < 3; ++i)
        {
            sound_index = GetURandomInt() % count;
            if (sound_index != previous[0] && sound_index != previous[1])
            {
                previous[0] = previous[1];
                previous[1] = sound_index;
                return sound_index;
            }
        }
    }

    previous[0] = previous[1];
    previous[1] = (previous[1] + 1) % count;
    return previous[1];
}

/**
 * Retrieve an entity's owner.
 */
stock int GetEntOwner(int entity)
{
    return GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
}

/**
 * Retrieve id of player's current weapon.
 */
stock int GetClientActiveWeapon(int client)
{
    return GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
}

/**
 * Check if a player is bleeding out.
 */
stock bool IsClientBleeding(int client)
{
    return GetEntProp(client, Prop_Send, "_bleedingOut") == 1;
}

/**
 * Check if a player is infected.
 */
stock bool IsClientInfected(int client)
{
    return GetEntPropFloat(client, Prop_Send, "m_flInfectionTime") != -1.0;
}

/**
 * Retrieve client's current stamina.
 */
stock float GetClientStamina(int client)
{
    return GetEntPropFloat(client, Prop_Send, "m_flStamina");
}

/**
 * Assign client's stamina.
 */
stock void SetClientStamina(int client, float stamina)
{
    SetEntPropFloat(client, Prop_Send, "m_flStamina", stamina);
}

/**
 * Retrieve entity's current collision group.
 */
stock int GetEntCollisionGroup(int entity)
{
    return GetEntProp(entity, Prop_Send, "m_CollisionGroup");
}

/**
 * Change an entity's collision group.
 *
 * Call the native function to avoid the Physical Mayhem bug.
 */
stock void SetEntCollisionGroup(int entity, int group)
{
    SDKCall(g_sdkcall_set_entity_collision_group, entity, group);
}

/**
 * Retrieve an entity's targetname (the name assigned to it in Hammer).
 *
 * @param entity            Entity to query.
 * @param targetname        Output buffer.
 * @param buffer_size       Size of output buffer.
 *
 * @return                  Number of non-null bytes written.
 */
stock int GetEntTargetname(int entity, char[] targetname, int buffer_size)
{
    return GetEntPropString(entity, Prop_Data, "m_iName", targetname, buffer_size);
}

/**
 * Retrieve an entity's health.
 *
 * @param entity            Entity to query.
 *
 * @return                  Entity's health.
 */
stock int GetEntHealth(int entity)
{
    return GetEntProp(entity, Prop_Data, "m_iHealth");
}

/**
 * Retrieve an entity's max health.
 *
 * @param entity            Entity to query.
 *
 * @return                  Entity's max health.
 */
stock int GetEntMaxHealth(int entity)
{
    return GetEntProp(entity, Prop_Data, "m_iMaxHealth");
}

/**
 * Retrieve entity's current sequence.
 */
stock int GetEntSequence(int entity)
{
    return GetEntProp(entity, Prop_Send, "m_nSequence");
}

/**
 * Retrieve entity's previous sequence.
 */
stock int GetEntPreviousSequence(int entity)
{
    return GetEntProp(entity, Prop_Send, "m_iPreviousSequence");
}

/**
 * Retrieve an entity's origin.
 *
 * @param entity			Entity to query.
 * @param origin			Output vector.
 */
stock void GetEntOrigin(int entity, float origin[3])
{
    GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", origin);
}

/**
 * Retrieve an entity's rotation.
 */
stock void GetEntRotation(int entity, float angles[3])
{
    GetEntPropVector(entity, Prop_Data, "m_angAbsRotation", angles);
}

/**
 * Calculate the normalized vector from one entity towards another.
 */
stock void GetEntDirection(int from, int to, float direction[3], bool horizontal_only = false)
{
    float pos_from[3];
    GetEntOrigin(from, pos_from);

    float pos_to[3];
    GetEntOrigin(to, pos_to);

    SubtractVectors(pos_to, pos_from, direction);
    if (horizontal_only)
    {
        direction[Z] = 0.0;
    }

    NormalizeVector(direction, direction);
}

/**
 * Calculate distance between two entities.
 */
stock float GetEntDistance(int ent_a, int ent_b, bool squared = false, bool horizontal_only = false)
{
    float pos_a[3];
    GetEntOrigin(ent_a, pos_a);

    float pos_b[3];
    GetEntOrigin(ent_b, pos_b);

    if (horizontal_only)
    {
        pos_b[Z] = pos_a[Z];
    }

    return GetVectorDistance(pos_a, pos_b, squared);
}

/**
 * Copy the values of one vector to another.
 */
stock void CopyVector(const float source[3], float dest[3])
{
    dest[X] = source[X];
    dest[Y] = source[Y];
    dest[Z] = source[Z];
}

/**
 * Copy the values of one vector to another.
 */
stock void AssignVector(float x, float y, float z, float dest[3])
{
    dest[X] = x;
    dest[Y] = y;
    dest[Z] = z;
}

/**
 * Read an array of integers from a DataPack.
 *
 * @param data          Handle to DataPack to read from.
 * @param array         Output buffer to store values.
 * @param array_size    Number of elements to read into array.
 */
stock ReadPackArray(Handle data, int[] array, int array_size)
{
    for (int i = 0; i < array_size; ++i)
    {
        array[i] = ReadPackCell(data);
    }
}

/**
 * Write an array of integers to a DataPack.
 *
 * @param data          Handle to DataPack to write to.
 * @param array         Buffer of values to write.
 * @param array_size    Number of elements in array to write.
 */
stock WritePackArray(Handle data, int[] array, int array_size)
{
    for (int i = 0; i < array_size; ++i)
    {
        WritePackCell(data, array[i]);
    }
}

/**
 * Helper function to read three floats from a DataPack into a vector.
 */
stock ReadPackVector(Handle data, float vec[3])
{
    vec[X] = ReadPackFloat(data);
    vec[Y] = ReadPackFloat(data);
    vec[Z] = ReadPackFloat(data);
}

/**
 * Helper function to write three floats from a vector to a DataPack.
 */
stock WritePackVector(Handle data, const float vec[3])
{
    WritePackFloat(data, vec[X]);
    WritePackFloat(data, vec[Y]);
    WritePackFloat(data, vec[Z]);
}

/**
 * Clamp a float value to a range.
 */
stock float FloatClamp(float value, float min, float max)
{
    if (value > max)
    {
        value = max;
    }
    if (value < min)
    {
        value = min;
    }
    return value;
}

/**
 * Check if two floats are close enough to be considered equal.
 */
stock bool FloatEqual(float a, float b, float epsilon = 0.0001)
{
    return FloatAbs(a - b) < epsilon;
}

/**
 * Check if two vectors are the same using an epsilon-based float compare.
 */
stock bool VectorEqual(float a[3], float b[3], float epsilon = 0.0001)
{
    return FloatEqual(a[X], b[X], epsilon) &&
        FloatEqual(a[Y], b[Y], epsilon) &&
        FloatEqual(a[Z], b[Z], epsilon);
}

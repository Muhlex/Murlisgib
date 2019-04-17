/* ========================================================================= */
/* PRAGMAS																   */
/* ========================================================================= */

#pragma semicolon 1
#pragma newdecls  required

/* ========================================================================= */
/* INCLUDES																  */
/* ========================================================================= */

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>

/* ========================================================================= */
/* DEFINES																   */
/* ========================================================================= */

/* Plugin version															*/
#define C_PLUGIN_VERSION				"4.0"

/* ------------------------------------------------------------------------- */

/* Knockback weapon property												 */
#define C_WEAPON_PROPERTY_KNOCKBACK	 (0)
/* Velocity weapon property												  */
#define C_WEAPON_PROPERTY_VELOCITY	  (1)
/* Ground weapon property													*/
#define C_WEAPON_PROPERTY_GROUND		(2)
/* Maximum weapon property												   */
#define C_WEAPON_PROPERTY_MAXIMUM	   (3)

/* ========================================================================= */
/* GLOBAL VARIABLES														  */
/* ========================================================================= */

/* Plugin information														*/
public Plugin myinfo =
{
	name		= "Weapon Jump",
	author	  = "Nyuu, (Muhlex)",
	description = "Knockback players when shooting the ground.",
	version	 = C_PLUGIN_VERSION,
	url		 = "https://forums.alliedmods.net/showthread.php?t=292151"
};

/* ------------------------------------------------------------------------- */

/* Plugin late															   */
bool	  gl_bPluginLate;

/* Players weapon jump													   */
bool	  gl_bPlayerWeaponJump		[MAXPLAYERS + 1];
/* Players weapon jump velocity											  */
float	 gl_vPlayerWeaponJumpVelocity[MAXPLAYERS + 1][3];

/* Weapon properties stringmap											   */
StringMap gl_hMapWeaponProperties;

/* ------------------------------------------------------------------------- */

/* Plugin enable cvar														*/
ConVar	gl_hCvarPluginEnable;

/* Plugin enable															 */
bool	  gl_bPluginEnable;

/* ========================================================================= */
/* FUNCTIONS																 */
/* ========================================================================= */

/* ------------------------------------------------------------------------- */
/* Plugin																	*/
/* ------------------------------------------------------------------------- */

public APLRes AskPluginLoad2(Handle hMyself, bool bLate, char[] szError, int iErrorMaxLength)
{
	// Save the plugin late status
	gl_bPluginLate = bLate;
	
	// Continue
	return APLRes_Success;
}

public void OnPluginStart()
{
	// Check the engine version
	PluginCheckEngineVersion();
	
	// Initialize the cvars
	CvarInitialize();

	// Create the weapon properties stringmap
	gl_hMapWeaponProperties = new StringMap();
	
	// Hook the bullet impact event
	HookEvent("bullet_impact", Event_BulletImpact);
	HookEvent("player_death", Event_PlayerDeath);
	
	// Check the plugin late status
	PluginCheckLate();
}

void PluginCheckEngineVersion()
{
	// Check the engine version
	if (GetEngineVersion() != Engine_CSGO)
	{
		// Stop the plugin
		SetFailState("This plugin is for CS:GO only!");
	}
}

void PluginCheckLate()
{
	// Check if the plugin loads late
	if (gl_bPluginLate)
	{
		// Process the clients already on the server
		for (int iClient = 1 ; iClient <= MaxClients ; iClient++)
		{
			// Check if the client is connected
			if (IsClientConnected(iClient))
			{
				// Call the client connected forward
				OnClientConnected(iClient);
				
				// Check if the client is in game
				if (IsClientInGame(iClient))
				{
					// Call the client put in server forward
					OnClientPutInServer(iClient);
				}
			}
		}
	}
}

public void OnMapStart() 
{
	// ALSO REQUIRES THESE FILES TO BE DOWNLOADED AND PRECACHED:
	// * particles/murlisgib.pcf
	
	AddFileToDownloadsTable("sound/murlisgib/blast_jump.wav");

	PrecacheSound("murlisgib/blast_jump.wav");
}

/* ------------------------------------------------------------------------- */
/* Configuration															 */
/* ------------------------------------------------------------------------- */

public void OnConfigsExecuted()
{
	char szConfigFile[PLATFORM_MAX_PATH];
	
	// Create the configuration keyvalues
	KeyValues kvConfig = new KeyValues("weapons");
	
	// Clear the weapon properties stringmap
	gl_hMapWeaponProperties.Clear();
	
	// Build the path of the configuration file
	BuildPath(Path_SM, szConfigFile, sizeof(szConfigFile), "configs/weapon_jump.cfg");
	
	// Import the configuration file
	if (kvConfig.ImportFromFile(szConfigFile))
	{
		LogMessage("Start to read the configuration file...");
		
		// Go to the first weapon properties section
		if (kvConfig.GotoFirstSubKey())
		{
			char szWeaponName[32];
			int  iWeaponProperty[C_WEAPON_PROPERTY_MAXIMUM];
			
			do
			{
				// Read the weapon name
				if (kvConfig.GetSectionName(szWeaponName, sizeof(szWeaponName)))
				{
					// Get the weapon properties
					float flKnockback = kvConfig.GetFloat("knockback", 0.00);
					float flVelocity  = kvConfig.GetFloat("velocity",  0.00);
					int   iGround	 = kvConfig.GetNum  ("ground",	0);
					bool  bGround	 = false;
					
					// Check & clamp the weapon properties
					if (flVelocity < 0.00)
					{
						flVelocity = 0.00;
					}
					else if (flVelocity > 1.00)
					{
						flVelocity = 1.00;
					}
					
					if (iGround)
					{
						bGround = true;
					}
					
					// Convert the weapon properties
					iWeaponProperty[C_WEAPON_PROPERTY_KNOCKBACK] = view_as<int>(flKnockback);
					iWeaponProperty[C_WEAPON_PROPERTY_VELOCITY]  = view_as<int>(flVelocity);
					iWeaponProperty[C_WEAPON_PROPERTY_GROUND]	= view_as<int>(bGround);
					
					// Push the weapon properties in the stringmap
					gl_hMapWeaponProperties.SetArray(szWeaponName, iWeaponProperty, C_WEAPON_PROPERTY_MAXIMUM);
					
					LogMessage("Read \"%s\" (Knockback: %0.2f | Velocity: %0.2f | Ground: %d).", 
						szWeaponName, flKnockback, flVelocity, bGround);
				}
				
				// Go to the next weapon properties section
			} while (kvConfig.GotoNextKey());
		}
		
		LogMessage("Finish to read the configuration file (%d weapons read)!", gl_hMapWeaponProperties.Size);
	}
	else
	{
		LogError("Can't import the configuration file!");
		LogError("> Path: %s", szConfigFile);
	}
	
	delete kvConfig;
}

/* ------------------------------------------------------------------------- */
/* Console variable														  */
/* ------------------------------------------------------------------------- */

void CvarInitialize()
{
	// Create the version cvar
	CreateConVar("sm_weapon_jump_version", C_PLUGIN_VERSION, "Display the plugin version", FCVAR_DONTRECORD | FCVAR_NOTIFY | FCVAR_REPLICATED | FCVAR_SPONLY);
	
	// Create the custom cvars
	gl_hCvarPluginEnable = CreateConVar("sm_weapon_jump_enable", "1", "Enable the plugin", _, true, 0.0, true, 1.0);
	
	// Cache the custom cvars values
	gl_bPluginEnable = gl_hCvarPluginEnable.BoolValue;
	
	// Hook the custom cvars change
	gl_hCvarPluginEnable.AddChangeHook(OnCvarChanged);
}

public void OnCvarChanged(ConVar hCvar, const char[] szOldValue, const char[] szNewValue)
{
	// Cache the custom cvars values
	if (gl_hCvarPluginEnable == hCvar) gl_bPluginEnable = gl_hCvarPluginEnable.BoolValue;
}

/* ------------------------------------------------------------------------- */
/* Client																	*/
/* ------------------------------------------------------------------------- */

public void OnClientConnected(int iClient)
{
	// Initialize the client data
	gl_bPlayerWeaponJump[iClient] = false;
}

public void OnClientPutInServer(int iClient)
{
	// Hook the client postthink function
	SDKHook(iClient, SDKHook_PostThinkPost, OnPlayerPostThinkPost);
}

public void OnClientDisconnect(int iClient)
{
	// Clear the client data
	gl_bPlayerWeaponJump[iClient] = false;
}

/* ------------------------------------------------------------------------- */
/* Weapon																	*/
/* ------------------------------------------------------------------------- */

int gl_player_jumping[MAXPLAYERS + 1] = {INVALID_ENT_REFERENCE, ...};

bool gl_player_just_jumped[MAXPLAYERS + 1] = false;

public Action Event_BulletImpact(Event event, const char[] name, bool dontBroadcast)
{
	if (!gl_bPluginEnable)
		return Plugin_Continue;
		
	// Get the player
	int iPlayer = GetClientOfUserId(event.GetInt("userid"));
	
	// Check if the player is valid and is not already jumping on current shot
	if ((1 <= iPlayer <= MaxClients) && (gl_bPlayerWeaponJump[iPlayer] == false))
	{
		// Get the player active weapon
		int iWeapon = GetEntPropEnt(iPlayer, Prop_Send, "m_hActiveWeapon");
		
		// TODO: Maybe a check must be done here on 'iWeapon' (!= -1, IsValidEntity()..).
		
		// Check the current number of ammo in the loader
		if (GetEntProp(iWeapon, Prop_Send, "m_iClip1") > 0)
		{
			char szWeaponName[32];
			int  iWeaponProperty[C_WEAPON_PROPERTY_MAXIMUM];
			
			// Get the weapon name
			GetClientWeapon(iPlayer, szWeaponName, 32);
			//event.GetString("weapon", szWeaponName, sizeof(szWeaponName));
			
			// Check if the weapon name is present in the weapon properties stringmap
			if (gl_hMapWeaponProperties.GetArray(szWeaponName, iWeaponProperty, C_WEAPON_PROPERTY_MAXIMUM))
			{
				// Convert the weapon properties
				float flKnockback = view_as<float>(iWeaponProperty[C_WEAPON_PROPERTY_KNOCKBACK]);
				float flVelocity  = view_as<float>(iWeaponProperty[C_WEAPON_PROPERTY_VELOCITY]);
				bool  bGround	 = view_as<bool> (iWeaponProperty[C_WEAPON_PROPERTY_GROUND]);
				
				// Check if the player can weapon jump on ground
				if (bGround || !(GetEntityFlags(iPlayer) & FL_ONGROUND))
				{
					float impact_pos[3];
					float feet_pos[3];
					float player_pos[3];
					float distance;
					
					// Get Bullet Impact Position
					impact_pos[0] = event.GetFloat("x");
					impact_pos[1] = event.GetFloat("y");
					impact_pos[2] = event.GetFloat("z");

					// Get Player Feet Position
					GetClientAbsOrigin(iPlayer, feet_pos);

					player_pos = feet_pos;
					player_pos[2] = feet_pos[2] + 12; // Elevates Player checking Position slightly up from feet.

					distance = GetVectorDistance(impact_pos, player_pos);

					float maxDistance = 160.0;

					// Check if player is in distance to "explosion"
					if (distance <= maxDistance)
					{
						float lobMultiplier;

						// Linear Distance Multiplier
						lobMultiplier = 1 - (distance * (1 / maxDistance));

						// Exponential Distance Multiplier
						//								 V How far the "explosion" stays strong. Higher value = Higher force for longer.
						lobMultiplier = (-1 * Exponential(-4 * lobMultiplier)) + 1;

						//char playername[32];
						//GetClientName(iPlayer, playername, 32);
						//LogMessage("Lobbing %s. (%0.2f)", playername, lobMultiplier);

						float vPlayerVelocity[3];
						float vPlayerEyeAngles[3];
						float vPlayerForward[3];
						
						// Get the player velocity
						GetEntPropVector(iPlayer, Prop_Data, "m_vecVelocity", vPlayerVelocity);
						
						// Get the player forward direction
						GetClientEyeAngles(iPlayer, vPlayerEyeAngles);
						GetAngleVectors(vPlayerEyeAngles, vPlayerForward, NULL_VECTOR, NULL_VECTOR);
						
						// Compute the player weapon jump velocity
						gl_vPlayerWeaponJumpVelocity[iPlayer][0] = vPlayerVelocity[0] * flVelocity - vPlayerForward[0] * flKnockback * lobMultiplier;
						gl_vPlayerWeaponJumpVelocity[iPlayer][1] = vPlayerVelocity[1] * flVelocity - vPlayerForward[1] * flKnockback * lobMultiplier;
						gl_vPlayerWeaponJumpVelocity[iPlayer][2] = vPlayerVelocity[2] * flVelocity - vPlayerForward[2] * flKnockback * lobMultiplier;
						
						// Set the player weapon jump
						gl_bPlayerWeaponJump[iPlayer] = true;


						/* VISUAL / AUDITORY FEATURES */

						char explosionEffect[64];
						char jumpingEffect[64];

						if	  (StrEqual(szWeaponName, "weapon_usp_silencer"))
						{
							explosionEffect = "jump_explosion";
							jumpingEffect = "player_jumping";
						}
						else if	(StrEqual(szWeaponName, "weapon_mag7"))
						{
							explosionEffect = "jump_explosion_2";
							jumpingEffect = "player_jumping_2";
						}
						else
						{
							explosionEffect = "jump_explosion_3";
							jumpingEffect = "player_jumping_3";
						}

						// Emit explosion sound
						//EmitAmbientSound("weapons/sensorgrenade/sensor_explode.wav", impact_pos, SOUND_FROM_WORLD, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.3, SNDPITCH_NORMAL);
						EmitAmbientSound("murlisgib/blast_jump.wav", impact_pos, SOUND_FROM_WORLD, 85, SND_NOFLAGS, 1.0, SNDPITCH_NORMAL);

						// Create explosion particle
						int rocket_expl = CreateEntityByName("info_particle_system");

						DispatchKeyValue(rocket_expl, "start_active", "0");
						DispatchKeyValue(rocket_expl, "effect_name", explosionEffect);

						DispatchSpawn(rocket_expl);
						
						TeleportEntity(rocket_expl, impact_pos, NULL_VECTOR, NULL_VECTOR);

						ActivateEntity(rocket_expl);
						AcceptEntityInput(rocket_expl, "start");

						// Create particle under jumping player

						// Check if particle already exists. If it does, kill it first.
						int player_jumping = EntRefToEntIndex(gl_player_jumping[iPlayer]);

						if(player_jumping && player_jumping != INVALID_ENT_REFERENCE)
						{
							AcceptEntityInput(player_jumping, "stop");
							AcceptEntityInput(player_jumping, "kill");
						}

						player_jumping = CreateEntityByName("info_particle_system");

						DispatchKeyValue(player_jumping, "start_active", "0");
						DispatchKeyValue(player_jumping, "effect_name", jumpingEffect);

						DispatchSpawn(player_jumping);
						
						TeleportEntity(player_jumping, feet_pos, NULL_VECTOR, NULL_VECTOR);

						// Make Player Parent of the Particle
						SetVariantString("!activator");
						AcceptEntityInput(player_jumping, "SetParent", iPlayer, player_jumping, 0);

						ActivateEntity(player_jumping);
						AcceptEntityInput(player_jumping, "start");
						gl_player_jumping[iPlayer] = EntIndexToEntRef(player_jumping);
					}
				}
			}
		}
	}

	return Plugin_Continue;
}

/* ------------------------------------------------------------------------- */
/* Player																	*/
/* ------------------------------------------------------------------------- */

public void OnPlayerPostThinkPost(int iPlayer)
{
	// Check if the player must weapon jump
	if (gl_bPlayerWeaponJump[iPlayer])
	{
		// Check if the player is still alive
		if (IsPlayerAlive(iPlayer))
		{
			// Knockback the player
			TeleportEntity(iPlayer, NULL_VECTOR, NULL_VECTOR, gl_vPlayerWeaponJumpVelocity[iPlayer]);
			gl_player_just_jumped[iPlayer] = true;
			CreateTimer(0.1, JustJumpedReset, iPlayer);
		}
		
		// Reset the player weapon jump
		gl_bPlayerWeaponJump[iPlayer] = false;
	}

	// Remove player's jumping-particle effect if on Ground
	int player_jumping = EntRefToEntIndex(gl_player_jumping[iPlayer]);

	if(player_jumping && player_jumping != INVALID_ENT_REFERENCE && !gl_player_just_jumped[iPlayer])
	{
		if((GetEntityFlags(iPlayer) & FL_ONGROUND))
		{
			AcceptEntityInput(player_jumping, "stop");
			AcceptEntityInput(player_jumping, "kill");
		}
	}
}

public void Event_PlayerDeath(Handle event, const char[] name, bool dontBroadcast)
{
	int victimClient = GetClientOfUserId(GetEventInt(event,"userid"));

	int player_jumping = EntRefToEntIndex(gl_player_jumping[victimClient]);

	if(player_jumping && player_jumping != INVALID_ENT_REFERENCE)
	{
		AcceptEntityInput(player_jumping, "stop");
		AcceptEntityInput(player_jumping, "kill");
	}
}

/* ========================================================================= */

public Action JustJumpedReset(Handle timer, int iPlayer)
{
	gl_player_just_jumped[iPlayer] = false;
}
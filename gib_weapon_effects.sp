#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#include <smlib>
#include <dynamic>

#include <murlisgib>

#define PATH_CONFIG /* SOURCEMOD PATH/ */ "configs/gib_weapons.cfg"

StringMap g_smWeaponConfig;

// Sets whether the player uses righthanded viewmodels or not
bool g_bPlayerRighthand[MAXPLAYERS + 1] = {true, ...};

// Set when the gun used for the last shot has tracers configured
bool g_bHandleTracers[MAXPLAYERS + 1];
// GetClientEyePosition Output
float g_vPlayerViewPosition[MAXPLAYERS + 1][3];
// GetClientEyeAngles Output
float g_vPlayerEyeAngles[MAXPLAYERS + 1][3];
// Approximation of where the player's viewmodel sits
float g_vViewmodelPosition[MAXPLAYERS + 1][3];
// Muzzle Position of the worldmodel weapon
float g_vMuzzlePosition[MAXPLAYERS + 1][3];
// Tracer to use for the current shot
char g_szTracerParticle[MAXPLAYERS + 1][65];

// Impact position vectors the player caused with their last shot
float g_vImpactPositions[MAXPLAYERS + 1][16][3];
// Count of impact positions caused
int g_iImpactCount[MAXPLAYERS + 1];

public Plugin myinfo =
{
	name = "Murlisgib Weapon Effects",
	author = "murlis, Tak (Chaosxk)",
	description = "Tracers, Impacts and Sounds for Railgun Weapons.",
	version = "1.0",
	url = "http://steamcommunity.com/id/muhlex"
};

/*
 *
 * Functions
 */

void GetWeaponAttachmentPosition(int iClient, const char[] szAttachment, float vPos[3])
{
	if (!szAttachment[0])
		return;

	int iEntity = CreateEntityByName("info_target");
	DispatchSpawn(iEntity);

	int iWeapon;

	if ((iWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon")) == -1)
		return;

	if ((iWeapon = GetEntPropEnt(iWeapon, Prop_Send, "m_hWeaponWorldModel")) == -1)
		return;

	SetVariantString("!activator");
	AcceptEntityInput(iEntity, "SetParent", iWeapon, iEntity, 0);

	SetVariantString(szAttachment);
	AcceptEntityInput(iEntity, "SetParentAttachment", iWeapon, iEntity, 0);

	TeleportEntity(iEntity, NULL_VECTOR, NULL_VECTOR, NULL_VECTOR);
	GetEntPropVector(iEntity, Prop_Data, "m_vecAbsOrigin", vPos);
	AcceptEntityInput(iEntity, "kill");
}

/*
 *
 * Public Forwards
 */

public void OnPluginStart()
{
	AddTempEntHook("Shotgun Shot", TEHook_FireBullets);
	HookEvent("bullet_impact", GameEvent_BulletImpact);
	HookEvent("player_death", GameEvent_PlayerDeath);
}

public void OnClientPostAdminCheck(int iClient)
{
	QueryClientConVar(iClient, "cl_righthand", CLQuery_Righthand);
}

void CLQuery_Righthand(QueryCookie qcCookie, int iClient, ConVarQueryResult result, const char[] szCvarName, const char[] szCvarValue)
{
	if (result != ConVarQuery_Okay)
		return;

	if (StrEqual(szCvarValue, "0"))
		g_bPlayerRighthand[iClient] = false;
	else if (StrEqual(szCvarValue, "1"))
		g_bPlayerRighthand[iClient] = true;
}

public void OnConfigsExecuted()
{
	char szConfigPath[PLATFORM_MAX_PATH];
	KeyValues kvConfig = new KeyValues("weapons");
	g_smWeaponConfig = new StringMap();

	// Build the path of the Configuration File
	BuildPath(Path_SM, szConfigPath, sizeof(szConfigPath), PATH_CONFIG);

	// Try to import Configuration File
	if (!kvConfig.ImportFromFile(szConfigPath))
		SetFailState("Unable to load config from path: %s", szConfigPath);

	// GOTO First Section (inside root) (first weapon)
	if (!kvConfig.GotoFirstSubKey())
		SetFailState("Plugin Config-File empty or corrupt!");

	// Create Variable to store a single weapon's name
	char szWeaponName[33];

	do // for every Section (inside root) (every weapon)
	{
		// Get the weapon's name
		kvConfig.GetSectionName(szWeaponName, sizeof(szWeaponName));

		// GOTO blastjump Configuration
		if (kvConfig.JumpToKey("weapon_effects"))
		{
			// Store stats for a single Weapon
			StringMap smWeapon = new StringMap();

			char szBuffer[65];

			kvConfig.GetString("tracer_particle", szBuffer, sizeof(szBuffer));
			if (!StrEqual(szBuffer, ""))
				smWeapon.SetString("tracer_particle", szBuffer);

			kvConfig.GetString("kill_impact_particle", szBuffer, sizeof(szBuffer));
			if (!StrEqual(szBuffer, ""))
				smWeapon.SetString("kill_impact_particle", szBuffer);

			kvConfig.GetString("shot_sound", szBuffer, sizeof(szBuffer));
			if (!StrEqual(szBuffer, ""))
				smWeapon.SetString("shot_sound", szBuffer);

			float fShotVolume = kvConfig.GetFloat("shot_sound_volume", 1.0);
			smWeapon.SetValue("shot_sound_volume", fShotVolume);

			g_smWeaponConfig.SetValue(szWeaponName, smWeapon);

			kvConfig.GoBack();
		}
	} while (kvConfig.GotoNextKey());

	delete kvConfig;
}

/*
 *
 * Other Hooks
 */

public Action TEHook_FireBullets(const char[] szTE_Name, const int[] iPlayers, int iNumClients, float fDelay)
{
	int iClient = TE_ReadNum("m_iPlayer") + 1;

	// Check for valid player
	if (Client_IsIngame(iClient))
	{
		// Get current Weapon
		char szWeaponName[33];
		GetClientWeapon(iClient, szWeaponName, sizeof(szWeaponName));

		// Check if the weapon is setup for effects
		StringMap smWeapon = new StringMap();

		if (g_smWeaponConfig.GetValue(szWeaponName, smWeapon))
		{
			// Tracer Particle
			if (smWeapon.GetString("tracer_particle", g_szTracerParticle[iClient], sizeof(g_szTracerParticle[])))
			{
				g_bHandleTracers[iClient] = true;

				// The following (global) values will be used for every bullet impact generated by the shot

				// Get View Position
				GetClientEyePosition(iClient, g_vPlayerViewPosition[iClient]);

				float vPlayerForwardVector[3], vPlayerRightVector[3], vPlayerUpVector[3];
				GetClientEyeAngles(iClient, g_vPlayerEyeAngles[iClient]);
				GetAngleVectors(g_vPlayerEyeAngles[iClient], vPlayerForwardVector, vPlayerRightVector, vPlayerUpVector);

				// Offset the Positions to approximate where the viewmodel sits

				g_vViewmodelPosition[iClient] = g_vPlayerViewPosition[iClient];

				for (int i = 0; i <= 2; i++)
				{
					// Move forward
					g_vViewmodelPosition[iClient][i] += vPlayerForwardVector[i] * 10;
					// Move down
					g_vViewmodelPosition[iClient][i] -= vPlayerUpVector[i] * 2;

					// Move right (/left)
					if (g_bPlayerRighthand[iClient])
						g_vViewmodelPosition[iClient][i] += vPlayerRightVector[i] * 4;
					else
						g_vViewmodelPosition[iClient][i] -= vPlayerRightVector[i] * 4;
				}

				// Get Worldmodel Muzzle Position
				GetWeaponAttachmentPosition(iClient, "muzzle_flash", g_vMuzzlePosition[iClient]);

				// Call Tracer Display after Shot and Impact Events have fired
				RequestFrame(RequestFrame_HandleTracers, GetClientUserId(iClient));
			}
			else
			{
				g_bHandleTracers[iClient] = false;
			}
		}

		char szBuffer[65];

		if (smWeapon.GetString("shot_sound", szBuffer, sizeof(szBuffer)))
		{
			float fShotVolume;
			smWeapon.GetValue("shot_sound_volume", fShotVolume);

			EmitAmbientSound(szBuffer, g_vPlayerViewPosition[iClient], SOUND_FROM_WORLD, SNDLEVEL_NORMAL, SND_NOFLAGS, fShotVolume, SNDPITCH_LOW);
		}
	}
}

/*
 *
 * Game-Event Hooks
 */

public Action GameEvent_BulletImpact(Event eEvent, const char[] szName, bool bDontBroadcast)
{
	int iClient = GetClientOfUserId(eEvent.GetInt("userid"));

	if (g_bHandleTracers[iClient])
	{
		// Get Bullet Impact Position
		int i = g_iImpactCount[iClient];
		g_vImpactPositions[iClient][i][0] = eEvent.GetFloat("x");
		g_vImpactPositions[iClient][i][1] = eEvent.GetFloat("y");
		g_vImpactPositions[iClient][i][2] = eEvent.GetFloat("z");

		// Increase Impact Count
		g_iImpactCount[iClient]++;
	}
	else
	{
		g_iImpactCount[iClient] = 0;
	}
}

void RequestFrame_HandleTracers(int iUserid)
{
	int iClient = GetClientOfUserId(iUserid);

	if (Client_IsIngame(iClient) && IsPlayerAlive(iClient))
	{
		if (g_iImpactCount[iClient] == 0)
			return;

		int iLastImpact = g_iImpactCount[iClient] - 1;

		// Direction Vector between Player's Bullet Origin and the last (furthest) Bullet Impact
		float vPlayerToLastImpact[3];
		MakeVectorFromPoints(g_vPlayerViewPosition[iClient], g_vImpactPositions[iClient][iLastImpact], vPlayerToLastImpact);

		float vPlayerToThisImpact[3];
		bool bSendTracer = true;

		// Loop through all Impacts of a shot -> Nearest will be the smallest key
		for (int iImpact = 0; iImpact < g_iImpactCount[iClient]; iImpact++)
		{
			if (iImpact != iLastImpact)
			{
				// Direction Vector between Player's Bullet Origin and THIS Impact
				MakeVectorFromPoints(g_vPlayerViewPosition[iClient], g_vImpactPositions[iClient][iImpact], vPlayerToThisImpact);

				// Dividing both direction vectors, to figure out if they are on one line
				// If all axes are the same value, the impacts were in one line
				float vImpactScalar[3];
				for (int i = 0; i <= 2; i++)
				{
					vImpactScalar[i] = vPlayerToThisImpact[i] / vPlayerToLastImpact[i];
				}

				// Account for floating point precision errors
				float fEpsilon = 0.000001;

				// Check if all vImpactScalar axes equal each other
				for (int j = 0; j <= 1; j++)
				{
					if (vImpactScalar[j] + fEpsilon > vImpactScalar[j + 1] &&
							vImpactScalar[j] - fEpsilon < vImpactScalar[j + 1])
					{
						bSendTracer = false;
					}
				}
			}
			else
			{
				bSendTracer = true;
			}

			if (bSendTracer)
			{
				// Send Particles to shooting Client
				TE_EffectDispatch(g_szTracerParticle[iClient], g_vViewmodelPosition[iClient], g_vImpactPositions[iClient][iImpact], g_vPlayerEyeAngles[iClient]);
				TE_SendToClient(iClient);

				// Send Particles to all other Clients
				TE_EffectDispatch(g_szTracerParticle[iClient], g_vMuzzlePosition[iClient], g_vImpactPositions[iClient][iImpact], g_vPlayerEyeAngles[iClient]);

				int[] iClients = new int[MaxClients];
				int iClientCount;
				for (int j = 1; j <= MaxClients; j++)
				{
					if (!IsClientInGame(j) || j == iClient || IsFakeClient(j))
						continue;
					iClients[iClientCount++] = j;
				}
				TE_Send(iClients, iClientCount);
			}
		}
		g_iImpactCount[iClient] = 0;
	}
}

public Action GameEvent_PlayerDeath(Event eEvent, const char[] szName, bool bDontBroadcast)
{
	int iAttacker = GetClientOfUserId(GetEventInt(eEvent, "attacker"));
	int iVictim = GetClientOfUserId(GetEventInt(eEvent, "userid"));

	// Exclude invalid Cases where Victim is no longer ingame or suicided
	if (!Client_IsIngame(iVictim) || iVictim == iAttacker || iAttacker == 0)
		return;

	char szWeaponName[33];

	eEvent.GetString("weapon", szWeaponName, sizeof(szWeaponName)); // does NOT return "weapon_" prefix
	Format(szWeaponName, sizeof(szWeaponName), "weapon_%s", szWeaponName); // adds the prefix

	// Check if the weapon is setup for effects
	StringMap smWeapon = new StringMap();

	char szBuffer[65];

	if (g_smWeaponConfig.GetValue(szWeaponName, smWeapon))
	{
		// Tracer Particle
		if (smWeapon.GetString("kill_impact_particle", szBuffer, sizeof(szBuffer)))
		{
			float vVictimPosition[3];
			GetClientAbsOrigin(iVictim, vVictimPosition); // Returns Camera Position as the Player is dead

			vVictimPosition[2] -= 20; // Slightly adjust to center of Playermodel

			TE_EffectDispatch(szBuffer, vVictimPosition, vVictimPosition);
			TE_SendToAll();
		}
	}
}
#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>

ConVar g_cvMPDeathDropGun;

bool g_pluginLateLoad;
ConVar g_cvEnabled;
ConVar g_cvMax;
ConVar g_cvMaxPerPlayer;
ConVar g_cvTime;
ConVar g_cvTimeOffset;
ConVar g_cvTimePerPlayer;

Handle g_hTimer_Spawning = INVALID_HANDLE;

Handle g_adtSpawnpointPos;



public Plugin myinfo =
{
	name = "Bumpmine Spawn",
	author = "murlis",
	description = "Randomly spawns Bump Mine-Items around the map to be picked up by players.",
	version = "1.0",
	url = "http://steamcommunity.com/id/muhlex"
};



stock void GetSpawnPositions()
{
	int iSpawnpoint = -1; // Start searching at the very first entity
	float fSpawnpointPos[3];

	ClearArray(g_adtSpawnpointPos);

	while ((iSpawnpoint = FindEntityByClassname(iSpawnpoint, "info_deathmatch_spawn")) != -1)
	{
		GetEntPropVector(iSpawnpoint, Prop_Send, "m_vecOrigin", fSpawnpointPos);
		PushArrayArray(g_adtSpawnpointPos, fSpawnpointPos);
	}
}

stock void StartSpawningTimer(float fInterval, float fIntervalPerPlayer, float fIntervalOffset, bool bOverrideTimer = false)
{
	if (!g_cvEnabled.BoolValue)
	{
		return;
	}
	if ((!bOverrideTimer) && (g_hTimer_Spawning != INVALID_HANDLE))
	{
		return;
	}

	int iNumClients = GetClientCount(true);

	fInterval += fIntervalPerPlayer * iNumClients;

	fIntervalOffset = FloatAbs(fIntervalOffset);
	float fMinInterval = fInterval - fIntervalOffset;
	float fMaxInterval = fInterval + fIntervalOffset;

	if (fMinInterval < 0.0)
	{
		fMinInterval = 0.0;
	}

	PrintToChatAll("interval: %.1f intervalplayer: %.1f intervaloffset: %.1f clients: %i mininterval: %.1f maxinterval: %.1f",
	fInterval, fIntervalPerPlayer, fIntervalOffset, iNumClients, fMinInterval, fMaxInterval);
	g_hTimer_Spawning = CreateTimer(GetRandomFloat(fMinInterval, fMaxInterval), Timer_Spawning);
}

stock void KillSpawningTimer()
{
	if (g_hTimer_Spawning != INVALID_HANDLE)
	{
		KillTimer(g_hTimer_Spawning, false);
		g_hTimer_Spawning = INVALID_HANDLE;
	}
}

public Action Timer_Spawning(Handle timer)
{
	StartSpawningTimer(g_cvTime.FloatValue, g_cvTimePerPlayer.FloatValue, g_cvTimeOffset.FloatValue, true);

	int iOldBumpmine = -1; // Start searching at the very first entity
	int iNumOldBumpmines = 0;

	while ((iOldBumpmine = FindEntityByClassname(iOldBumpmine, "weapon_bumpmine")) != -1)
	{
		iNumOldBumpmines++;
	}

	int   iNumClients = GetClientCount(true);
	float fMaxBumpmines = g_cvMax.FloatValue + g_cvMaxPerPlayer.FloatValue * iNumClients;
	int   iMaxBumpmines = RoundToFloor(fMaxBumpmines);

	if (iMaxBumpmines < 0)
	{
		iMaxBumpmines = 0;
	}

	PrintToChatAll("Current old Bump mines: %i; max bumpmines: %i", iNumOldBumpmines, iMaxBumpmines);

	if (iNumOldBumpmines >= iMaxBumpmines)
	{
		return;
	}

	// Get saved Positions to be used for spawning Bump Mines
	int iNumSpawnpoints = GetArraySize(g_adtSpawnpointPos);

	// If no Positions are found or all have been used up, new ones will be generated.
	if (iNumSpawnpoints <= 0)
	{
		GetSpawnPositions();
		iNumSpawnpoints = GetArraySize(g_adtSpawnpointPos);
	}

	// Get random Spawnpoint index
	int iSpawnpointIndex = GetRandomInt(0, iNumSpawnpoints - 1);

	// Get x, y, z position of the Spawnpoint
	float fPos[3];
	GetArrayArray(g_adtSpawnpointPos, iSpawnpointIndex, fPos);
	fPos[2] = fPos[2] + 32.0; // Spawn floating above ground

	int iOldMPDeathDropGun = g_cvMPDeathDropGun.IntValue;
	// Shortly enable dropping of items, otherwise mines cannot be spawned in. (Would despawn instantly.)
	g_cvMPDeathDropGun.IntValue = 1;

	int iBumpmine = CreateEntityByName("weapon_bumpmine");
	TeleportEntity(iBumpmine, fPos, NULL_VECTOR, NULL_VECTOR);
	DispatchSpawn(iBumpmine);

	// Set item dropping to previous value.
	g_cvMPDeathDropGun.IntValue = iOldMPDeathDropGun;

	SetEntProp(iBumpmine, Prop_Data, "m_takedamage", 0, 1);
	SetEntityMoveType(iBumpmine, MOVETYPE_NOCLIP);

	// Remove the used Spawnpoint Position from Array
	RemoveFromArray(g_adtSpawnpointPos, iSpawnpointIndex);

	PrintToChatAll("Spawned one");
}



public APLRes AskPluginLoad2(Handle hMyself, bool bLate, char[] szError, int iErrorMaxLength)
{
  g_pluginLateLoad = bLate;
  return APLRes_Success;
}

public void OnPluginStart()
{
	g_cvMPDeathDropGun = FindConVar("mp_death_drop_gun");

	g_cvEnabled        = CreateConVar("bumpmines_enabled", "1", "Whether Bump Mines are used in gameplay or not.");
	g_cvMax            = CreateConVar("bumpmines_max", "4", "Maximum amount of Bump Mines spawned at once.");
	g_cvMaxPerPlayer   = CreateConVar("bumpmines_max_per_player", "0.7", "Value to increase/decrease max. amount of Bump Mines per connected player.");
	g_cvTime           = CreateConVar("bumpmines_time", "18", "Interval (in seconds), in which a Bump Mine is spawned.");
	g_cvTimePerPlayer  = CreateConVar("bumpmines_time_per_player", "-1.2", "Value to increase/decrease Bump Mine spawning timer per connected player.");
	g_cvTimeOffset     = CreateConVar("bumpmines_time_offset", "3", "Maximum amount by which to randomly offset Bump Mine spawning timer (positively AND negatively).");

	g_cvEnabled.AddChangeHook(ConVar_Change_BumpMines);
	g_cvTime.AddChangeHook(ConVar_Change_BumpMines);
	g_cvTimePerPlayer.AddChangeHook(ConVar_Change_BumpMines);
	g_cvTimeOffset.AddChangeHook(ConVar_Change_BumpMines);

	HookEvent("round_start", Event_RoundStart);
	HookEvent("round_end", Event_RoundEnd);

	g_adtSpawnpointPos = CreateArray(3);

	if (g_pluginLateLoad)
	{
		PluginLateLoad();
	}
}

public void PluginLateLoad()
{
	GetSpawnPositions();

	StartSpawningTimer(g_cvTime.FloatValue, g_cvTimePerPlayer.FloatValue, g_cvTimeOffset.FloatValue);

	// Add client Hooks
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (IsClientInGame(iClient))
		{
			OnClientPutInServer(iClient);
		}
	}
}

public void ConVar_Change_BumpMines(ConVar cvConvar, char[] szOldValue, char[] szNewValue)
{
	KillSpawningTimer();

	if (g_cvEnabled.BoolValue)
	{
		StartSpawningTimer(g_cvTime.FloatValue, g_cvTimePerPlayer.FloatValue, g_cvTimeOffset.FloatValue);
	}
}

public void OnClientPutInServer(int iClient)
{
	SDKHook(iClient, SDKHook_WeaponEquipPost, Hook_WeaponEquipPost);
}

public void OnMapEnd()
{
	KillSpawningTimer();
}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	GetSpawnPositions();
	StartSpawningTimer(g_cvTime.FloatValue, g_cvTimePerPlayer.FloatValue, g_cvTimeOffset.FloatValue);
}

public Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	KillSpawningTimer();
}

public Action Hook_WeaponEquipPost(int iClient, int iWeapon)
{
	char szWeaponName[32];

	GetEdictClassname(iWeapon, szWeaponName, sizeof(szWeaponName));

	if (StrEqual(szWeaponName, "weapon_bumpmine", false))
	{
		SetEntProp(iWeapon, Prop_Send, "m_iClip1", 1);
	}
}
/*
default				\x01
teamcolor			\x03
red						\x07
lightred			\x0F
darkred				\x02
bluegrey			\x0A
blue					\x0B
darkblue			\x0C
purple				\x03
orchid				\x0E
yellow				\x09
gold					\x10
lightgreen		\x05
green					\x04
lime					\x06
grey					\x08
grey2					\x0D
https://raw.githubusercontent.com/PremyslTalich/ColorVariables/master/csgo%20colors.png
*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

bool g_pluginLateLoad;
ConVar g_cvMPDeathDropGun;



public Plugin myinfo =
{
	name = "test",
	author = "murlis",
	description = "test",
	version = "1.0",
	url = "http://steamcommunity.com/id/muhlex"
};



public APLRes AskPluginLoad2(Handle hMyself, bool bLate, char[] szError, int iErrorMaxLength)
{
  g_pluginLateLoad = bLate;
  return APLRes_Success;
}

public void OnPluginStart()
{
	RegConsoleCmd("test", Command_Test, "test");

	g_cvMPDeathDropGun = FindConVar("mp_death_drop_gun");

	if (g_pluginLateLoad)
	{
		PluginLateLoad();
	}
}

public void PluginLateLoad()
{
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (IsClientInGame(iClient))
		{
			OnClientPutInServer(iClient);
		}
	}
}

public void OnClientPutInServer(int iClient)
{
	SDKHook(iClient, SDKHook_WeaponEquipPost, Hook_WeaponEquipPost);
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

public Action Command_Test(int iClient, int iArgs)
{
	ReplyToCommand(iClient, "Test Command triggered.");

	g_cvMPDeathDropGun.IntValue = 1;

	// Start searching at first entity
	int iEntitySpawnpoint = -1;
	int iEntityBumpmine;
	float fPositionSpawnpoint[3];

	while ((iEntitySpawnpoint = FindEntityByClassname(iEntitySpawnpoint, "info_deathmatch_spawn")) != -1)
	{
		GetEntPropVector(iEntitySpawnpoint, Prop_Send, "m_vecOrigin", fPositionSpawnpoint);
		iEntityBumpmine = CreateEntityByName("weapon_bumpmine");
		TeleportEntity(iEntityBumpmine, fPositionSpawnpoint, NULL_VECTOR, NULL_VECTOR);
		DispatchSpawn(iEntityBumpmine);
	}

	g_cvMPDeathDropGun.IntValue = 0;

	return Plugin_Handled;
}
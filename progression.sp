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
#include <cstrike>

#define XP_BASE_RATE 5
#define XP_ON_KILL 10
#define XP_ON_HEADSHOT 15
#define XP_ON_KNIFE 20
#define XP_ON_SHOTGUN 5

int g_iRankNeededXp[] =
{       // RANK:
	0,    // 0 (unused)
	0,    // 1
	400,  // 2
	800,  // 3
	1200, // 4
	1600  // 5
};

int g_iClientXp[MAXPLAYERS + 1];
int g_iClientRank[MAXPLAYERS + 1];

Handle g_hTimer_XpBase = INVALID_HANDLE;



public Plugin myinfo =
{
	name = "Murlisgib Progression",
	author = "murlis",
	description = "XP & Rank system for unlockable items.",
	version = "1.0",
	url = "http://steamcommunity.com/id/muhlex"
};



public void OnPluginStart()
{
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("player_spawn", Event_PlayerSpawn);

	RegConsoleCmd("xp", Command_ShowXp);
	RegConsoleCmd("setrank", Command_SetRank);
}

public Action Command_ShowXp(int iClient, int iArgs)
{
	PrintToChat(iClient, " \x0FYour current XP for this match: %iXP", g_iClientXp[iClient]);
	PrintToChat(iClient, " \x0FYour Rank: %i", g_iClientRank[iClient]);
}

public Action Command_SetRank (int iClient, int iArgs)
{
	char szArg[65];
	GetCmdArg(1, szArg, sizeof(szArg));

	int iArg;
	iArg = StringToInt(szArg);

	if (iClient < 1)
	{
		return;
	}

	if ((iArg < 1) || (iArg > sizeof(g_iRankNeededXp) - 1))
	{
		PrintToChat(iClient, " \x0FYou did not enter a valid rank.");
		return;
	}

	g_iClientXp[iClient] = g_iRankNeededXp[iArg];
	g_iClientRank[iClient] = iArg;
	ApplyMVPs(iClient);

	PrintToChat(iClient, " \x0FRank set to: %i \x10[%i XP]", g_iClientRank[iClient], g_iClientXp[iClient]);
}

public void OnClientPostAdminCheck(int iClient)
{
	if (!IsFakeClient(iClient))
	{
		g_iClientRank[iClient] = 1;
	}
}

public void OnMapStart()
{
	g_hTimer_XpBase = CreateTimer(10.0, Timer_XpBase, _, TIMER_REPEAT);
}

public void OnMapEnd()
{
	if (g_hTimer_XpBase != INVALID_HANDLE)
	{
		KillTimer(g_hTimer_XpBase, false);
		g_hTimer_XpBase = INVALID_HANDLE;
	}

	SaveXpAll();
}

public void OnClientDisconnect(int iClient)
{
	SaveXp(iClient);
}

public Action Timer_XpBase(Handle hTimer)
{
	for (int iClient = 1; iClient <= MaxClients ; iClient++)
	{
		if (IsClientInGame(iClient) && !IsFakeClient(iClient))
		{
			g_iClientXp[iClient] += XP_BASE_RATE;
			PrintToChat(iClient, " \x0DAwarded %iXP for playing.", XP_BASE_RATE);

			UpdateRank(iClient);
		}
	}

	// Continue Timer
	return Plugin_Continue;
}

stock void SaveXp(int iClient)
{
	// TODO: Add client's XP to a database

	g_iClientXp[iClient] = 0;
}

stock void SaveXpAll()
{
	// TODO: Add client's XP to a database

	for (int iClient = 1; iClient <= MaxClients ; iClient++)
	{
		g_iClientXp[iClient] = 0;
	}
}

stock int UpdateRank(int iClient)
{
	// If current client has max Rank
	if (g_iClientRank[iClient] >= sizeof(g_iRankNeededXp) - 1)
	{
		return;
	}

	// If current client XP < needed XP for the next rank
	if (g_iClientXp[iClient] < g_iRankNeededXp[g_iClientRank[iClient] + 1])
	{
		return;
	}

	// Loop through XP <-> Rank Definitions
	for (int i = g_iClientRank[iClient] + 1; i <= sizeof(g_iRankNeededXp) - 1; i++)
	{
		if (g_iClientXp[iClient] >= g_iRankNeededXp[i])
		{
			g_iClientRank[iClient] = i;
			ApplyMVPs(iClient);
			PrintToChat(iClient, " \x0FYou have reached Rank: %i \x10[%i XP]", i, g_iRankNeededXp[i]);
		}
		else
		{
			break;
		}
	}
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int  iVictim = GetClientOfUserId(GetEventInt(event, "userid"));
	int  iAttacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	bool bHeadshot = GetEventBool(event, "headshot");

	// Filter for valid clients only
	if (iAttacker < 1 || iAttacker > GetMaxHumanPlayers())
	{
		return;
	}

	// Filter for humans only
	if (IsFakeClient(iAttacker)) {
		return;
	}

	// Filter out direct suicides
	if (iVictim == iAttacker) {
		return;
	}

	// Get active weapon (returns classname instead of weaponname)
	char szWeapon[32];
	int iWeaponEdict = GetEntPropEnt(iAttacker, Prop_Data, "m_hActiveWeapon");
	GetEdictClassname(iWeaponEdict, szWeapon, sizeof(szWeapon));

	if (StrEqual(szWeapon, "weapon_mag7"))
	{
		g_iClientXp[iAttacker] += XP_ON_SHOTGUN;
		PrintToChat(iAttacker, " \x0DAwarded %iXP for Shotgun Kill.", XP_ON_SHOTGUN);
	}
	else if (bHeadshot && StrEqual(szWeapon, "weapon_hkp2000"))
	{
		g_iClientXp[iAttacker] += XP_ON_HEADSHOT;
		PrintToChat(iAttacker, " \x0DAwarded %iXP for Railgun-Headshot Kill.", XP_ON_HEADSHOT);
	}
	else if (StrEqual(szWeapon, "weapon_knife"))
	{
		g_iClientXp[iAttacker] += XP_ON_KNIFE;
		PrintToChat(iAttacker, " \x0DAwarded %iXP for Knife Kill.", XP_ON_KNIFE);
	}
	else
	{
		g_iClientXp[iAttacker] += XP_ON_KILL;
		PrintToChat(iAttacker, " \x0DAwarded %iXP for Kill.", XP_ON_KILL);
	}

	UpdateRank(iAttacker);
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int iClient = GetClientOfUserId(GetEventInt(event, "userid"));

	RequestFrame(ApplyMVPs, iClient);
}

stock void ApplyMVPs(int iClient)
{
	CS_SetMVPCount(iClient, g_iClientRank[iClient]);
}
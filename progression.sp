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

#define XP_BASE_RATE 10
#define XP_ON_KILL 50
#define XP_ON_HEADSHOT 100
#define XP_ON_KNIFE 100
#define XP_ON_SHOTGUN 25

int g_iCurrentXp[MAXPLAYERS + 1];
int g_iRank[MAXPLAYERS + 1];

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

	RegConsoleCmd("xp", Command_ShowXp);
	RegConsoleCmd("updaterank", Command_UpdateRank);
}

public Action Command_ShowXp(int iClient, int iArgs)
{
	PrintToChat(iClient, " \x0FYour current XP for this match: %iXP", g_iCurrentXp[iClient]);
}

public Action Command_UpdateRank (int iClient, int iArgs)
{
	char szArg[65];
	int iArg;
	GetCmdArg(1, szArg, sizeof(szArg));

	iArg = StringToInt(szArg);

	if (iArg == 0)
	{
		return;
	}

	CS_SetMVPCount(iClient, iArg);
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
			g_iCurrentXp[iClient] += XP_BASE_RATE;
			PrintToChat(iClient, " \x0DAwarded %iXP for playing.", XP_BASE_RATE);
		}
	}

	// Continue Timer
	return Plugin_Continue;
}

stock void SaveXp(int iClient)
{
	// TODO: Add client's XP to a database

	g_iCurrentXp[iClient] = 0;
}

stock void SaveXpAll()
{
	// TODO: Add client's XP to a database

	for (int iClient = 1; iClient <= MaxClients ; iClient++)
	{
		g_iCurrentXp[iClient] = 0;
	}
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int  iVictim = GetClientOfUserId(GetEventInt(event, "userid"));
	int  iAttacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	bool bHeadshot = GetEventBool(event, "headshot");

	// Check if both parties are players and if killer was a human player
	if (!IsClientInGame(iVictim) || !IsClientInGame(iAttacker) || IsFakeClient(iAttacker)) {
		return;
	}

	// Check for direct suicides
	if (iVictim == iAttacker) {
		return;
	}

	// Get active weapon (returns classname instead of weaponname)
	char szWeapon[32];
	int iWeaponEdict = GetEntPropEnt(iAttacker, Prop_Data, "m_hActiveWeapon");
	GetEdictClassname(iWeaponEdict, szWeapon, sizeof(szWeapon));

	if (StrEqual(szWeapon, "weapon_mag7"))
	{
		g_iCurrentXp[iAttacker] += XP_ON_SHOTGUN;
		PrintToChat(iAttacker, " \x0DAwarded %iXP for Shotgun Kill.", XP_ON_SHOTGUN);
		return;
	}

	if (bHeadshot && StrEqual(szWeapon, "weapon_hkp2000"))
	{
		g_iCurrentXp[iAttacker] += XP_ON_HEADSHOT;
		PrintToChat(iAttacker, " \x0DAwarded %iXP for Railgun-Headshot Kill.", XP_ON_HEADSHOT);
		return;
	}

	if (StrEqual(szWeapon, "weapon_knife"))
	{
		g_iCurrentXp[iAttacker] += XP_ON_KNIFE;
		PrintToChat(iAttacker, " \x0DAwarded %iXP for Knife Kill.", XP_ON_KNIFE);
		return;
	}

	g_iCurrentXp[iAttacker] += XP_ON_KILL;
	PrintToChat(iAttacker, " \x0DAwarded %iXP for Kill.", XP_ON_KILL);
}
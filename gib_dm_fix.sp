#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>

#include <dynamic>

#include <murlisgib>

public Plugin myinfo =
{
	name = "Murlisgib Deathmatch Fix",
	author = "murlis",
	description = "Makes Valve's Deathmatch gamemode compatible with Murlisgib.",
	version = "1.0",
	url = "http://steamcommunity.com/id/muhlex"
};

/*
 *
 * Public Forwards
 */

public void OnPluginStart()
{
	AddNormalSoundHook(SoundHook_Normal);
	HookEvent("player_death", GameEvent_PlayerDeath, EventHookMode_Pre);
	HookUserMessage(GetUserMessageId("TextMsg"), Event_TextMsg, true);
}

public Action SoundHook_Normal(int iClients[MAXPLAYERS], int &iNumClients, char szSample[PLATFORM_MAX_PATH], int &iEntity, int &iChannel, float &fVolume, int &iLevel, int &iPitch, int &iFlags, char szSoundEntry[PLATFORM_MAX_PATH], int &iSeed)
{
	// Prevent player respawning sounds
	if (StrContains(szSample, "player/pl_respawn.wav") != -1) return Plugin_Stop;

	return Plugin_Continue;
}

public Action GameEvent_PlayerDeath(Event eEvent, const char[] szName, bool bDontBroadcast)
{
	int iVictim = GetClientOfUserId(GetEventInt(eEvent, "userid"));
	int iAttacker = GetClientOfUserId(GetEventInt(eEvent, "attacker"));

	if (iVictim && IsClientInGame(iVictim))
		// Remove being dominated from Victim
		SetEntProp(iVictim, Prop_Send, "m_bPlayerDominatingMe", false, _, iAttacker);

	if (iAttacker && IsClientInGame(iAttacker))
	{
		// Remove dominations from Attacker
		SetEntProp(iAttacker, Prop_Send, "m_bPlayerDominated", false, _, iVictim);
		eEvent.SetBool("dominated", false);

		// Prevent Killsound
		// seems to not work sometimes, so we do it again in the request frame
		StopSound(iAttacker, SNDCHAN_ITEM, "buttons/bell1.wav");

		// Also queue update of DM-Scoreboard
		RequestFrame(RequestFrame_PlayerGetKill, GetClientUserId(iAttacker));
	}

	return Plugin_Continue;
}

void RequestFrame_PlayerGetKill(int iUserID)
{
	int iClient = GetClientOfUserId(iUserID);
	if (!iClient || !IsClientInGame(iClient)) return;

	// Prevent Killsound
	StopSound(iClient, SNDCHAN_ITEM, "buttons/bell1.wav");
}

public Action Event_TextMsg(UserMsg msgID, Handle hPb, const int[] iPlayers, int iPlayersNum, bool bReliable, bool bInit)
{
	if (bReliable)
	{
		// Block chat messages for DM-Points on Kill
		char szText[64];
		PbReadString(hPb, "params", szText, sizeof(szText),0);
		if (StrContains(szText, "#Player_Point_Award_", false) != -1)
			return Plugin_Handled;
	}
	return Plugin_Continue;
}

// Block Chicken Spawning
public void OnEntityCreated(int iEntity, const char[] szClassName)
{
	if (StrContains(szClassName, "chicken", false) == -1) return;
	SDKHook(iEntity, SDKHook_Spawn, Hook_ChickenSpawned);
}

public Action Hook_ChickenSpawned(int iChicken) {
	if (IsValidEntity(iChicken))
		AcceptEntityInput(iChicken, "Kill");

	return Plugin_Stop;
}

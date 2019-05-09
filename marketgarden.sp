#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define SOUND_DEAL_CRIT "player/bhit_helmet-1.wav"
#define SOUND_DEAL_CRIT_VOL 0.20
#define SOUND_RECEIVE_CRIT "player/pl_fallpain3.wav"
#define SOUND_RECEIVE_CRIT_VOL 0.9

bool g_bPluginLateLoad;

public Plugin myinfo =
{
	name = "Market Garden",
	author = "murlis",
	description = "Crit players when meeleing while blast-jumping.",
	version = "1.0",
	url = "http://steamcommunity.com/id/muhlex"
};

native int Murlisgib_IsClientBlastJumping(int iClient);

stock void PlayClientSound(int iClient, char[] szSound, float fVolume)
{
	EmitSoundToClient(iClient, szSound, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, fVolume, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
}

public APLRes AskPluginLoad2(Handle hMyself, bool bLate, char[] szError, int iErrorMaxLength)
{
  g_bPluginLateLoad = bLate;
  return APLRes_Success;
}

public void OnPluginStart()
{
  if (g_bPluginLateLoad)
	{
		PluginLateLoad();
	}
}

public void PluginLateLoad()
{
  // Add client Hooks if Plugin loads late
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (IsClientInGame(iClient))
		{
			OnClientPutInServer(iClient);
		}
	}
}

public void OnMapStart()
{
  PrecacheSound(SOUND_DEAL_CRIT);
  PrecacheSound(SOUND_RECEIVE_CRIT);
}

public void OnClientPutInServer(int iClient)
{
  SDKHook(iClient, SDKHook_OnTakeDamage, Hook_OnTakeDamage);
}

public Action Hook_OnTakeDamage(int iVictim, int &iAttacker, int &iInflictor, float &fDamage, int &iDamagetype)
{
  if ((iAttacker >= 1) && (iAttacker <= MaxClients))
  {
    if (IsClientInGame(iAttacker))
    {
      bool bIsJumping = view_as<bool>(Murlisgib_IsClientBlastJumping(iAttacker));

      if ((bIsJumping) && (iDamagetype & DMG_SLASH))
      {
        fDamage = 1000.0;
        PlayClientSound(iAttacker, SOUND_DEAL_CRIT, SOUND_DEAL_CRIT_VOL);
        PlayClientSound(iVictim, SOUND_RECEIVE_CRIT, SOUND_RECEIVE_CRIT_VOL);

        return Plugin_Changed;
      }
    }
  }

  return Plugin_Continue;
}
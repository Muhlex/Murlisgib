#include <sourcemod>
#include <sdktools>
#include <cstrike>

public Plugin myinfo = 
{
	name = "Cawk",
	author = "murlis",
	description = "Replaces Round Draw Sound with Cawk Sound.",
	version = "1.0",
	url = "http://steamcommunity.com/id/muhlex"
};

/*
public OnPluginStart()
{
	AddNormalSoundHook(SoundHook);
	AddAmbientSoundHook(SoundHook2);
}
*/

public void OnMapStart()
{
	PrecacheSound("ambient/animal/shoots_jungle_bird_05.wav");
}

/*
public Action:SoundHook(clients[64], &numClients, String:sound[PLATFORM_MAX_PATH], &Ent, &channel, &Float:volume, &level, &pitch, &flags)
{
	PrintToChatAll("Sound: %s", sound);
	//if (StrEqual(sound, "radio/rounddraw.wav", false)) return Plugin_Stop;
	return Plugin_Continue;
}

public Action:SoundHook2(String:sound[PLATFORM_MAX_PATH], &Ent, &Float:volume, &level, &pitch, Float:pos[3], &flags, &Float:delay)
{
	PrintToChatAll("Sound: %s", sound);
	//if (StrEqual(sound, "radio/rounddraw.wav", false)) return Plugin_Stop;
	return Plugin_Continue;
}
*/

public Action CS_OnTerminateRound(float &delay, CSRoundEndReason &reason)
{
	if (reason != CSRoundEnd_GameStart)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i))
			{
				ClientCommand(i, "playgamesound Music.StopAllExceptMusic");
				//StopSound(i, SNDCHAN_STATIC, "radio/rounddraw.wav");
			}
		}
		
		CreateTimer(0.1, CawkSound);
	}
}

public Action CawkSound(Handle timer)
{
	EmitSoundToAll("ambient/animal/shoots_jungle_bird_05.wav", SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.8, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
}
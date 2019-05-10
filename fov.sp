#include <sourcemod>

public Plugin myinfo =
{
	name = "FOV Changer",
	author = "murlis",
	description = "Changes player's Field Of View to 100.",
	version = "1.0",
	url = "http://steamcommunity.com/id/muhlex"
};

public OnPluginStart()
{
	HookEvent("player_spawn", Event_PlayerSpawn);
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));

	SetEntProp(client, Prop_Send, "m_iFOV", 100);
	SetEntProp(client, Prop_Send, "m_iDefaultFOV", 100);
}
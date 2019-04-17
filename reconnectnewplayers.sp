#include <sourcemod>
#include <sdktools>

public Plugin myinfo = 
{
	name = "Reconnect New Players",
	author = "murlis",
	description = "Forces a reconnect if a player joins for their first time. Fixes particle caching issues.",
	version = "1.0",
	url = "http://steamcommunity.com/id/muhlex"
};

Handle g_knownPlayers;

public OnPluginStart()
{
	g_knownPlayers = CreateArray(20);
}

public OnClientPostAdminCheck(client)
{
	ReconnectOnce(client);
}

public ReconnectOnce(client)
{
	if (client && IsClientConnected(client) && !IsFakeClient(client))
	{
		char	steamId[20];
		int		arrayIndex;

		// Get client SteamID
		GetClientAuthId(client, AuthId_Engine, steamId, 20, true);

		// Search for client's SteamID in known IDs
		arrayIndex = FindStringInArray(g_knownPlayers, steamId);

		// Check if client was not found
		if (arrayIndex < 0)
		{
			// Add them to the list and reconnect them on next frame.
			LogMessage("%s is a new player. Forcing reconnect.", steamId);
			PushArrayString(g_knownPlayers, steamId);
			RequestFrame(DelayedReconnect, client);
		}
	}
}

public void DelayedReconnect(int client)
{
	ReconnectClient(client);
}
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

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

public Plugin myinfo = 
{
	name = "Smash Down",
	author = "murlis",
	description = "Smash into the ground when mid-air by hitting the walk key.",
	version = "1.0",
	url = "http://steamcommunity.com/id/muhlex"
};

bool g_pluginLateLoad = false;

bool  g_playerSmashing[MAXPLAYERS + 1];
bool  g_playerCanSmash[MAXPLAYERS + 1];

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int errorMaxLength)
{
  g_pluginLateLoad = late;
  return APLRes_Success;
}

public void OnPluginStart()
{
  HandlePluginLateLoad();
}

void HandlePluginLateLoad()
{
  // Check if the plugin loads late
  if (g_pluginLateLoad)
  {
    // Process the clients already on the server
    for (int client = 1 ; client <= MaxClients ; client++)
    {
      // Check if the client is connected
      if (IsClientConnected(client))
      {
        // Call the client connected forward
        OnClientConnected(client);
        
        // Check if the client is in game
        if (IsClientInGame(client))
        {
          // Call the client put in server forward
          OnClientPutInServer(client);
        }
      }
    }
  }
}

public void OnClientConnected(int client)
{
  // Initialize client data
  g_playerSmashing[client] = false;
  g_playerCanSmash[client] = true;
}

public void OnClientPutInServer(int client)
{
  // Hook the client postthink function
  SDKHook(client, SDKHook_PostThinkPost, OnPlayerPostThinkPost);
}

public OnClientDisconnect(int client) 
{ 
	SDKUnhook(client, SDKHook_PostThinkPost, OnPlayerPostThinkPost);

  // Reset client data
  g_playerSmashing[client] = false;
  g_playerCanSmash[client] = true;
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
  if (buttons & IN_SPEED)
  {
    // Check if the player is already smashing down
    if (g_playerCanSmash[client] && (!g_playerSmashing[client]))
    {
      // Check if the player is in the air
      if (!(GetEntityFlags(client) & FL_ONGROUND))
      {
        SetEntityGravity(client, 4.0);
        g_playerSmashing[client] = true;
        g_playerCanSmash[client] = false;
      }
    }
  }
}

public void OnPlayerPostThinkPost(int client)
{
  if (g_playerSmashing[client]) {
    if (GetEntityFlags(client) & FL_ONGROUND)
    {
      SetEntityGravity(client, 1.0);

      // Slow down the player once they reach the ground

      float playerVelocity[3];

      // Get the player velocity
      GetEntPropVector(client, Prop_Data, "m_vecVelocity", playerVelocity);

      char debugName[32];
      GetClientName(client, debugName, sizeof(debugName));
      PrintToChatAll("%s Velocity before impact: X: %.0f Y: %.0f Z: %.0f", debugName, playerVelocity[0], playerVelocity[1], playerVelocity[2]);

      // Compute new velocity
      playerVelocity[0] = playerVelocity[0] * 0.33;
      playerVelocity[1] = playerVelocity[1] * 0.33;
      //playerVelocity[2] = playerVelocity[2] * 1.00;

      PrintToChatAll("%s Velocity after impact: X: %.0f Y: %.0f Z: %.0f", debugName, playerVelocity[0], playerVelocity[1], playerVelocity[2]);

      TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, playerVelocity);

      // End Smash
      g_playerSmashing[client] = false;
      // Make Smash available again after a delay
      CreateTimer(1.8, ResetCanSmash, client);
    }
  }
}

public Action ResetCanSmash(Handle timer, int client)
{
	g_playerCanSmash[client] = true;
}
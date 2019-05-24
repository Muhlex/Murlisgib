#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

#include <smlib>
#include <dynamic>

#include <murlisgib>

#define PATH_ITEMS_GAME "scripts/items/items_game.txt"

KeyValues g_kvItemsGame;
KeyValues g_kvConfig;

public Plugin myinfo =
{
	name = "Murlisgib Weapon Stats",
	author = "murlis",
	description = "Modifies Weapon-Stats for the Gamemode.",
	version = "1.0",
	url = "http://steamcommunity.com/id/muhlex"
};

/*
 *
 * Functions
 */

void LoadKVFiles()
{
	char szConfigPath[PLATFORM_MAX_PATH];

	// Build the path of the configuration file
	BuildPath(Path_SM, szConfigPath, sizeof(szConfigPath), "configs/gib_weapon_stats.cfg");

	g_kvConfig = new KeyValues("weapon_stats");
	g_kvItemsGame = new KeyValues("items_game");

	// Try to import gib_weapon_stats.cfg
	if (!g_kvConfig.ImportFromFile(szConfigPath))
	{
		SetFailState("Unable to load config from path: %s", szConfigPath);
	}

  // Try to import items_game.txt
	if (!g_kvItemsGame.ImportFromFile(PATH_ITEMS_GAME))
	{
		SetFailState("Unable to load items_game.txt from path: %s", PATH_ITEMS_GAME);
	}
}

bool RemoveDuplicateStats()
{
	char szTest[128];

	// Go to prefabs section
	if (!g_kvItemsGame.JumpToKey("prefabs"))
		return false;

	// Go to first section inside prefabs
	if (!g_kvItemsGame.GotoFirstSubKey())
		return false;

	do
	{
		// Try to go to attributes section, go back afterwards
		if (g_kvItemsGame.JumpToKey("attributes"))
		{
			// CHECK FOR DUPLICATES

			if (g_kvItemsGame.GotoFirstSubKey(false))
			{
				do
				{
					g_kvItemsGame.SavePosition();
					g_kvItemsGame.GetSectionName(szTest, sizeof(szTest));

					if (g_kvItemsGame.JumpToKey(szTest, false)) // TODO: This just selects the GotoNextKey'd position again, not the one after :(
					{
						PrintToServer("DUPLICATE FOUND AT KEY: %s", szTest);
					}
					g_kvItemsGame.GoBack();


				} while (g_kvItemsGame.GotoNextKey(false));
				g_kvItemsGame.GoBack();
			}

			g_kvItemsGame.GoBack();
		}
		g_kvItemsGame.GetSectionName(szTest, sizeof(szTest));
		PrintToServer("Checked for duplicates: %s", szTest);
	} while (g_kvItemsGame.GotoNextKey());

	// Rewind at the very end
	g_kvItemsGame.Rewind();

	return true;
}

/*
 *
 * Public Forwards
 */

public void OnPluginStart()
{
	//RegAdminCmd("gib_weapon_stats_reload", Command_WeaponStatsReload, ADMFLAG_ROOT, "gib_weapon_stats_reload");

	LoadKVFiles();

	RemoveDuplicateStats();

	PrintToServer("TEST DONE");
}

public void OnMapStart()
{
}

/*
 *
 * Game-Event Hooks
 */

/*
 *
 * Other Hooks
 */

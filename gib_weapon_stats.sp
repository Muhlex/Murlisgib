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

int RemoveDuplicateAttributes(KeyValues kv)
{
	char szSectionName[128];
	StringMap smAttributes = new StringMap();
	int iDeletions = 0;

	// GOTO Section: "prefabs"
	if (!kv.JumpToKey("prefabs"))
		return 0;

	// GOTO First Section (inside "prefabs")
	if (!kv.GotoFirstSubKey())
		return 0;

	do // for every Section (inside "prefabs")
	{
		// GOTO Section: "attributes"
		if (kv.JumpToKey("attributes"))
		{
			// GOTO First Section (inside "attributes")
			if (kv.GotoFirstSubKey(false))
			{
				do // for every Key-Value Pair (inside "attributes"), treated as a section
				{
					kv.GetSectionName(szSectionName, sizeof(szSectionName));
					PrintToServer("Section: %s", szSectionName);

					// Cache Attribute in StringMap. Returns false, if the Value already exists!
					if (!smAttributes.SetValue(szSectionName, 1, false))
					{
						PrintToServer("FOUND DUPLICATE AT KEY: %s", szSectionName);

						// GO BACK
						kv.GoBack();
						if (kv.DeleteKey(szSectionName))
						{
							PrintToServer("KEY DELETED");
							iDeletions++;
						}
						kv.JumpToKey(szSectionName);
					}

				} while (kv.GotoNextKey(false));

				// GO BACK from current attribute to "attributes"
				kv.GoBack();
			}

			// Clear attributes List after full check of all attributes per prefab
			smAttributes.Clear();
			// GO BACK from Section: "attributes" to the Section INSIDE "prefabs"
			kv.GoBack();
		}

		kv.GetSectionName(szSectionName, sizeof(szSectionName));
		PrintToServer("LAST SECTION WAS: %s", szSectionName);
	} while (kv.GotoNextKey());

	// REWIND Input Reference
	kv.Rewind();

	delete smAttributes;

	return iDeletions;
}

/*
 *
 * Public Forwards
 */

public void OnPluginStart()
{
	//RegAdminCmd("gib_weapon_stats_reload", Command_WeaponStatsReload, ADMFLAG_ROOT, "gib_weapon_stats_reload");

	LoadKVFiles();

	RemoveDuplicateAttributes(g_kvItemsGame);

	g_kvItemsGame.ExportToFile("_test.txt");

	delete g_kvConfig;
	delete g_kvItemsGame;
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

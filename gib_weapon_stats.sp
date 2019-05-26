#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

#include <smlib>
#include <dynamic>

#include <murlisgib>

#define PATH_ITEMS_GAME "scripts/items/items_game.txt"
#define PATH_CONFIG /* SOURCEMOD PATH/ */ "configs/gib_weapon_stats.cfg"

bool g_bFileChanged = false;

ConVar g_cv_gib_railgun;

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

int DeleteDuplicateAttributes(KeyValues kv)
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

						// GO BACK to "attributes"
						kv.GoBack();
						// DELETE KEY from within "attributes" (finds the FIRST one)
						if (kv.DeleteKey(szSectionName))
						{
							PrintToServer("KEY DELETED");
							iDeletions++;
						}
						// GO back to previous Key-Value Pair
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

int LoadWeaponStatsIntoAttributes(KeyValues kvItemsGame, KeyValues kvConfig)
{
	char szWeaponName[128];
	char szAttributeName[128];
	char szAttributeValue[128];
	char szAttributeValueOld[128];
	int iUpdates = 0;

	// GOTO Section: "prefabs"
	if (!kvItemsGame.JumpToKey("prefabs"))
		return 0;

	// GOTO First Section (inside root) (first weapon)
	if (!kvConfig.GotoFirstSubKey())
		SetFailState("Plugin Config-File empty or corrupt!");

	do // for every Section (inside root) (every weapon)
	{
		// Get Weapon Name
		kvConfig.GetSectionName(szWeaponName, sizeof(szWeaponName));
		Format(szWeaponName, sizeof(szWeaponName), "%s_prefab", szWeaponName);

		// GOTO Section of current Weapon (inside "prefabs")
		if (!kvItemsGame.JumpToKey(szWeaponName))
			SetFailState("Prefab %s could not be found.", szWeaponName);
		// GOTO Section "attributes"
		if (!kvItemsGame.JumpToKey("attributes"))
			SetFailState("Prefab %s does not have any changable attributes.", szWeaponName);

		// GOTO First Stat (inside weapon)
		if (!kvConfig.GotoFirstSubKey(false))
			break;

		do // for every Stat
		{
			// Get Key
			kvConfig.GetSectionName(szAttributeName, sizeof(szAttributeName));
			// Get Value
			kvConfig.GetString(NULL_STRING, szAttributeValue, sizeof(szAttributeValue));

			// Get old Value
			kvItemsGame.GetString(szAttributeName, szAttributeValueOld, sizeof(szAttributeValueOld));

			// Check if Value needs to be updated
			if (!StrEqual(szAttributeValue, szAttributeValueOld))
			{
				// Update the Value
				kvItemsGame.SetString(szAttributeName, szAttributeValue);
				iUpdates++;
			}

		} while (kvConfig.GotoNextKey(false));

		// GO BACK to Section "attributes"
		kvItemsGame.GoBack();
		// GO BACK to Section of current Weapon (inside "prefabs")
		kvItemsGame.GoBack();

		// GO BACK to weapon
		kvConfig.GoBack();

	} while (kvConfig.GotoNextKey());

	// REWIND Input References
	kvItemsGame.Rewind();
	kvConfig.Rewind();

	return iUpdates;
}

int GetAttributeInt(KeyValues kv, const char[] szWeaponName, const char[] szAttributeName)
{
	char szWeaponNamePrefab[128];
	int iReturn;

	if (!kv.JumpToKey("prefabs"))
		return -1;

	// Suffix Weapon Name
	Format(szWeaponNamePrefab, sizeof(szWeaponNamePrefab), "%s_prefab", szWeaponName);

	if (!kv.JumpToKey(szWeaponNamePrefab))
		return -1;

	if (!kv.JumpToKey("attributes"))
		return -1;

	iReturn = kv.GetNum(szAttributeName, -1);

	kv.Rewind();

	return iReturn;
}

float GetAttributeFloat(KeyValues kv, const char[] szWeaponName, const char[] szAttributeName)
{
	char szWeaponNamePrefab[128];
	float fReturn;

	if (!kv.JumpToKey("prefabs"))
		return -1.0;

	// Suffix Weapon Name
	Format(szWeaponNamePrefab, sizeof(szWeaponNamePrefab), "%s_prefab", szWeaponName);

	if (!kv.JumpToKey(szWeaponNamePrefab))
		return -1.0;

	if (!kv.JumpToKey("attributes"))
		return -1.0;

	fReturn =  kv.GetFloat(szAttributeName, -1.0);

	kv.Rewind();

	return fReturn;
}

/*
 *
 * Public Forwards
 */

public void OnPluginStart()
{
	char szConfigPath[PLATFORM_MAX_PATH];
	int iDuplicates = 0;
	int iUpdates = 0;

	//RegAdminCmd("gib_weapon_stats_reload", Command_WeaponStatsReload, ADMFLAG_ROOT, "gib_weapon_stats_reload");

	KeyValues kvConfig =    new KeyValues("weapon_stats");
	KeyValues kvItemsGame = new KeyValues("items_game");

	// Build the path of the Configuration File
	BuildPath(Path_SM, szConfigPath, sizeof(szConfigPath), PATH_CONFIG);

	// Try to import Configuration File
	if (!kvConfig.ImportFromFile(szConfigPath))
		SetFailState("Unable to load config from path: %s", szConfigPath);

  // Try to import items_game.txt
	if (!kvItemsGame.ImportFromFile(PATH_ITEMS_GAME))
		SetFailState("Unable to load items_game.txt from path: %s", PATH_ITEMS_GAME);

	// DELETE DUPLICATE KEYS IN ATTRIBUTE SECTION
	iDuplicates = DeleteDuplicateAttributes(kvItemsGame);

	// UPDATE WEAPON ATTRIBUTES TO REFLECT CONFIG
	iUpdates = LoadWeaponStatsIntoAttributes(kvItemsGame, kvConfig);

	LogMessage("Deleted %i duplicate Item-Attributes.", iDuplicates);
	LogMessage("Updated %i Weapon-Stat-Attributes.", iUpdates);

	if (iDuplicates > 0 || iUpdates > 0)
	{
		kvItemsGame.ExportToFile(PATH_ITEMS_GAME);
		g_bFileChanged = true;
	}
	else
	{
		g_bFileChanged = false;
	}

	delete kvConfig;
	delete kvItemsGame;
}

public void OnAllPluginsLoaded()
{
	// Hook Railgun Weapon Change
	g_cv_gib_railgun = FindConVar("gib_railgun");
	g_cv_gib_railgun.AddChangeHook(ConVarChange_gib_railgun);

	Dynamic dGibData = Dynamic.GetSettings().GetDynamic("gib_data");
	// Create Member for Railgun Cycletime
	dGibData.SetFloat("fRailgunCycletime", 0.0);
	// Create Member for Railgun Primary Clip
	dGibData.SetInt("iRailgunPrimaryClip", 0);
}

public void OnMapStart()
{
	// Restart the Server, if items_game.txt changed
	if (g_bFileChanged)
		ServerCommand("_restart");
}

/*
 *
 * ConVar Hooks
 */

public void ConVarChange_gib_railgun(ConVar cvConvar, char[] szOldValue, char[] szNewValue)
{
	KeyValues kvItemsGame = new KeyValues("items_game");

	char szRailgun[33];
	cvConvar.GetString(szRailgun, sizeof(szRailgun));

	// Try to import items_game.txt
	if (!kvItemsGame.ImportFromFile(PATH_ITEMS_GAME))
		SetFailState("Unable to load items_game.txt from path: %s", PATH_ITEMS_GAME);

	// Get Railgun's Attributes
	float fCycletime = GetAttributeFloat(kvItemsGame, szRailgun, "cycletime");
	int   iPrimaryClip = GetAttributeInt(kvItemsGame, szRailgun, "primary clip size");

	delete kvItemsGame;

	if (fCycletime >= 0.0 && iPrimaryClip >= 0)
	{
		Dynamic dGibData = Dynamic.GetSettings().GetDynamic("gib_data");

		// Set Member for Railgun Cycletime
		dGibData.SetFloat("fRailgunCycletime", fCycletime);
		// Set Member for Railgun Primary Clip
		dGibData.SetInt("iRailgunPrimaryClip", iPrimaryClip);
	}
}
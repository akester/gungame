/**
 * ===============================================================
 * GunGame:SM, Copyright (C) 2007
 * All rights reserved.
 * ===============================================================
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.

 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.

 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 *
 * To view the latest information, see: http://www.hat-city.net/
 * Author(s): teame06
 *
 * This was also brought to you by faluco and the hat (http://www.hat-city.net/haha.jpg)
 *
 * Credit:
 * Original Idea and concepts of Gun Game was made by cagemonkey @ http://www.cagemonkey.org
 *
 * Especially would like to thank BAILOPAN for everything.
 * Also faluco for listening to my yapping.
 * Custom Mutliple Kills Per Level setting was an idea from XxAvalanchexX GunGame 1.6.
 * To the SourceMod Dev Team for making a nicely design system for this plugin to be recreated it.
 * FlyingMongoose for slaping my ideas away and now we have none left ... Geez.
 * I would also like to thank sawce with ^^.
 * Another person who I would like to thank is OneEyed.
 */

OnCreateKeyValues()
{
	#if !defined SQL_SUPPORT
	/* Make sure to use unique section name just incase someone else uses it */
	KvPlayer = CreateKeyValues("gg_PlayerData", BLANK, BLANK);
	BuildPath(Path_SM, PlayerFile, sizeof(PlayerFile), "data/gungame/playerdata.txt");
	PlayerOpen = FileToKeyValues(KvPlayer, PlayerFile);
	#endif

	KvRank = CreateKeyValues("gg_Top10", BLANK, BLANK);
	BuildPath(Path_SM, RankFile, sizeof(RankFile), "data/gungame/top10.txt");
	RankOpen = FileToKeyValues(KvRank, RankFile);
	LoadRank();
}

LoadRank()
{
	/* Let load rank information up if file is found */
	if(RankOpen)
	{
		KvRewind(KvRank);

		// Go to first SubKey
		if(!KvGotoFirstSubKey(KvRank))
			return;

		decl String:Section[10], i;
		new b;

		while(RankOpen)
		{
			if(++b >= MAX_RANK)
			{
				break;
			}

			if(!KvGetSectionName(KvRank, Section, sizeof(Section)))
			{
				break;
			}

			i = StringToInt(Section) - 1;

			if(i >= 0 && i < MAX_RANK)
			{
				PlayerWins[i] = KvGetNum(KvRank, "Wins");
				KvGetString(KvRank, "Authid", PlayerAuthid[i], sizeof(PlayerAuthid[]));
				KvGetString(KvRank, "Name", PlayerName[i], sizeof(PlayerName[]));

				HasRank = true;
			}

			if(!KvGotoNextKey(KvRank))
			{
				break;
			}
		}

		KvRewind(KvRank);
	}
}

SaveRank()
{
	/* Don't save unless something change */
	if(RankChange)
	{
		RankChange = false;

		/* Set at top of file */
		KvRewind(KvRank);

		for(new i = 1, c; i <= MAX_RANK; i++)
		{
			c = PlayerWins[i - 1];

			if(c && KvJumpToKey(KvRank, Numbers[i], true))
			{
				KvSetNum(KvRank, "Wins", PlayerWins[--i]);
				KvSetString(KvRank, "Authid", PlayerAuthid[i]);
				KvSetString(KvRank, "Name", PlayerName[i++]);

				/* Need to aleast go back once */
				/* Maybe this is not needed */
				KvGoBack(KvRank);
			}
		}

		/* Need to be at the top of the file to before writing */
		KvRewind(KvRank);
		KeyValuesToFile(KvRank, RankFile);
	}
}

#if !defined SQL_SUPPORT
SavePlayerDataInfo()
{
	/* Since pruning does save the file after it done check don't need to do it twice. */
	if(Prune)
	{
		PrunePlayerKeyValues();
	} else {
		KvRewind(KvPlayer);
		KeyValuesToFile(KvPlayer, PlayerFile);
	}

	PlayerOpen = true;
}

RetrieveKeyValues(client, const String:auth[])
{
	if(PlayerOpen)
	{
		KvRewind(KvPlayer);

		if(KvJumpToKey(KvPlayer, auth, false))
		{
			/*"Name"		"faluco"
			"Wins"		"10"
			"TimeStamp"	"30394"*/

			PlayerWinsData[client] = KvGetNum(KvPlayer, "Wins");

			/* Update timestamp */
			KvSetNum(KvPlayer, "TimeStamp", GetTime());
		}
	}
}

SavePlayerData(client)
{
	new Wins = PlayerWinsData[client];

	if(Wins)
	{
		decl String:Auth[64], String:Name[MAX_NAME_SIZE];

		GetClientAuthString(client, Auth, sizeof(Auth));
		//GetClientName(client, Name, sizeof(Name));
		/**
		 * Temporary fix
		 */
		/* Update player name in player data */
		GetClientInfo(client, "name", Name, sizeof(Name));
		KvRewind(KvPlayer);

		if(KvJumpToKey(KvPlayer, Auth, true))
		{
			KvSetString(KvPlayer, "Name", Name);
			KvSetNum(KvPlayer, "Wins", Wins);
			KvSetNum(KvPlayer, "TimeStamp", GetTime());
		}
	}
}

PrunePlayerKeyValues()
{
	/* Set back to root node position */
	KvRewind(KvPlayer);

	/* Go to first SubKey */
	if(!KvGotoFirstSubKey(KvPlayer))
		return;

	new TimeStamp = GetTime() - (Prune * 86400);

	for(;;)
	{
		if(KvGetNum(KvPlayer, "TimeStamp") <= TimeStamp)
		{
			/**
			 * Let delete the player from the player wins kv database.
			 */
			if(KvDeleteThis(KvPlayer) < 1)
			{
				break;
			}
		} else if(!KvGotoNextKey(KvPlayer)) {
			break;
		}
	}

	KvRewind(KvPlayer);
	KeyValuesToFile(KvPlayer, PlayerFile);
}
#endif

public Action:_CmdRebuild(client, args)
{
	if(IsActive)
	{
		/* Set back to root node position */
		KvRewind(KvPlayer);

		/* Go to first SubKey */
		if(!KvGotoFirstSubKey(KvPlayer))
		{
			ReplyToCommand(client, "[GunGame] You have no player data to rebuild the top10.");
			return Plugin_Handled;
		}

		/* Clear out the storage for top10 */
		for(new i = 0; i < MAX_RANK; i++)
		{
			PlayerWins[i] = 0;
			PlayerName[i][0] = '\0';
			PlayerAuthid[i][0] = '\0';
		}

		/* Close the original menu */
		if(Top10Panel != INVALID_HANDLE)
		{
			CloseHandle(Top10Panel);
			Top10Panel = INVALID_HANDLE;
		}

		CloseHandle(KvRank);
		KvRank = INVALID_HANDLE;
		RankOpen = false;

		BuildPath(Path_SM, RenameFileTop10, sizeof(RenameFileTop10), "data/gungame/top10%d.bak.txt", GetRandomInt(0, 10000));

		ReplyToCommand(client, "[GunGame] Backing up top10.txt at %s", RenameFileTop10);
		/* Backup old top10.txt */
		RenameFile(RenameFileTop10, RankFile);

		/* reopen a blank top10.txt */
		KvRank = CreateKeyValues("gg_Top10", BLANK, BLANK);
		RankOpen = FileToKeyValues(KvRank, RankFile);

		decl String:Auth[64], String:Name[64], Wins;

		do
		{
			KvGetSectionName(KvPlayer, Auth, sizeof(Auth));
			KvGetString(KvPlayer, "Name", Name, sizeof(Name));
			Wins = KvGetNum(KvPlayer, "Wins");

			for(new i = 0; i < MAX_RANK; i++)
			{
				if(Wins > PlayerWins[i])
				{
					RebuidShiftRanksUp(i, Wins, Name, Auth);
					break;
				}
			}
		}
		while(KvGotoNextKey(KvPlayer));

		KvRewind(KvPlayer);

		/* Save and tell the kv system that rank changes */
		RankChange = true;
		SaveRank();

		ReplyToCommand(client, "[GunGame] Top10 has been rebuilt from the player data file");
	}
	return Plugin_Handled;
}

RebuidShiftRanksUp(RankToReplace, Wins, const String:Name[64], const String:Auth[64])
{
	new b = MAX_RANK - 1, c;
	while(--b >= RankToReplace)
	{
		/* Makes sure there a rank in the slot before shift up otherwise stop */
		if((c = PlayerWins[b]) != 0)
		{
			PlayerWins[b + 1] = c;
			PlayerAuthid[b + 1] = PlayerAuthid[b];
			PlayerName[b + 1] = PlayerName[b];
		}
	}

	PlayerWins[RankToReplace] = Wins;
	PlayerName[RankToReplace] = Name;
	PlayerAuthid[RankToReplace] = Auth;
}

public Action:_CmdImport(client, args)
{
	decl String:EsFile[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, EsFile, sizeof(EsFile), "data/gungame/es_gg_winners_db.txt");

	if(!FileExists(EsFile))
	{
		ReplyToCommand(client, "[GunGame] es_gg_winners_db.txt does not exists to be imported.");
		return Plugin_Handled;
	}

	new Handle:KvGunGame = CreateKeyValues("gg_winners", BLANK, BLANK);
	FileToKeyValues(KvGunGame, EsFile);

	/* Go to first SubKey */
	if(!KvGotoFirstSubKey(KvGunGame))
	{
		ReplyToCommand(client, "[GunGame] You have no player data to import.");
		return Plugin_Handled;
	}

	decl String:Auth[64], String:Name[64], Wins, EsWins;

	do
	{
		KvGetSectionName(KvGunGame, Auth, sizeof(Auth));
		KvGetString(KvGunGame, "name", Name, sizeof(Name));
		EsWins = KvGetNum(KvGunGame, "wins");

		if(!EsWins || Auth[0] != 'S')
		{
			continue;
		}

		KvRewind(KvPlayer);
		if(KvJumpToKey(KvPlayer, Auth, true))
		{
			/* Little check to update or set new wins */
			Wins = KvGetNum(KvPlayer, "Wins");

			if(Wins)
			{
				Wins += EsWins;
			} else {
				Wins = EsWins;
				KvSetString(KvPlayer, "Name", Name);
			}

			KvSetNum(KvPlayer, "Wins", Wins);
			KvSetNum(KvPlayer, "TimeStamp", GetTime()); /* Set or updates timestamp */
		}
	}
	while(KvGotoNextKey(KvGunGame));

	KvRewind(KvPlayer);
	CloseHandle(KvGunGame);
	KeyValuesToFile(KvPlayer, PlayerFile);
	new maxslots = GetMaxClients( );

	/* Reload the players wins in memory */
	for(new i = 0; i < maxslots; i++)
	{
		if(IsClientConnected(i))
		{
			GetClientAuthString(i, Auth, sizeof(Auth));
			RetrieveKeyValues(i, Auth);
		}
	}

	ReplyToCommand(client, "[GunGame] Import of es player data completed. Please run gg_rebuild to update the top10.");

	return Plugin_Handled;
}
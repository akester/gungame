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
 * FlyingMongoose for slaping my ideas away and now we have now left ... Geez.
 * I would also like to thank sawce with ^^.
 * Another person who I would like to thank is OneEyed.
 */

#pragma semicolon 1
#include <sourcemod>
#include <sdktools>

/**
 * So the plugin won't search for the library gungame
 * but since I keep all the const in the same file too.
 * Since it requires the const.
 */
#undef REQUIRE_PLUGIN
#include <gungame>

/**
 * Enable debug code
 * This is only meant for the author.
 */
//#define DEBUG

#include "gungame/gungame.h"
#include "gungame/menu.h"
#include "gungame/config.h"
#include "gungame/keyvalue.h"
#include "gungame/event.h"
#include "gungame/hacks.h"
#include "gungame/offset.h"

#if defined DEBUG
#include "gungame/debug.h"
#include "gungame/debug.sp"
#endif

#include "gungame/natives.sp"
#include "gungame/offset.sp"
#include "gungame/hacks.sp"
#include "gungame/menu.sp"
#include "gungame/config.sp"
#include "gungame/keyvalue.sp"
#include "gungame/util.sp"
#include "gungame/event.sp"
#include "gungame/commands.sp"

public Plugin:myinfo =
{
	name = "GunGame:SM",
	author = GUNGAME_AUTHOR,
	description = "GunGame:SM for SourceMod",
	version = GUNGAME_VERSION,
	url = "http://www.hat-city.net/"
};

public bool:AskPluginLoad(Handle:myself, bool:late, String:error[], err_max)
{
	RegPluginLibrary("gungame");
	OnCreateNatives();
	return true;
}

public OnPluginStart()
{
	// ConVar
	VGUIMenu = GetUserMessageId("VGUIMenu");
	mp_friendlyfire = FindConVar("mp_friendlyfire");
	mp_restartgame = FindConVar("mp_restartgame");
	mp_chattime = FindConVar("mp_chattime");

	new Handle:Version = CreateConVar("sm_gungame_css_version", GUNGAME_VERSION,	"GunGame Version", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);

	/* Just to make sure they it updates the convar version if they just had the plugin reload on map change */
	SetConVarString(Version, GUNGAME_VERSION);

	gungame_enabled = CreateConVar("gungame_enabled", "1", "Display if GunGame is enabled or disabled", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);

	/* Dynamic Forwards */
	FwdDeath = CreateGlobalForward("GG_OnClientDeath", ET_Hook, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
	FwdLevelChange = CreateGlobalForward("GG_OnClientLevelChange", ET_Hook, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
	FwdPoint = CreateGlobalForward("GG_OnClientPointChange", ET_Hook, Param_Cell, Param_Cell, Param_Cell);
	FwdLeader = CreateGlobalForward("GG_OnLeaderChange", ET_Ignore, Param_Cell, Param_Cell);
	FwdWinner = CreateGlobalForward("GG_OnWinner", ET_Ignore, Param_Cell, Param_String);
	FwdVoteStart = CreateGlobalForward("GG_OnStartMapVote", ET_Ignore);
	FwdStart = CreateGlobalForward("GG_OnStartup", ET_Ignore, Param_Cell);
	FwdShutdown = CreateGlobalForward("GG_OnShutdown", ET_Ignore, Param_Cell);

	OnKeyValueStart();
	OnOffsetStart();
	OnCreateCommand();
	OnHackStart();

	#if defined DEBUG
	OnCreateDebug();
	#endif
}

public OnPluginEnd()
{
	SetConVarInt(gungame_enabled, 0);
}

public OnMapStart()
{
	cssdm_enabled = FindConVar("cssdm_enabled");
}

public OnMapEnd()
{
	/* Kill timer on map change if was in warmup round. */
	if(WarmupTimer != INVALID_HANDLE)
	{
		KillTimer(WarmupTimer);
		WarmupTimer = INVALID_HANDLE;
	}

	if(CommandPanel != INVALID_HANDLE)
	{
		CloseHandle(CommandPanel);
		CommandPanel = INVALID_HANDLE;
	}

	if(RulesMenu != INVALID_HANDLE)
	{
		CloseHandle(RulesMenu);
		RulesMenu = INVALID_HANDLE;
	}

	if(JoinMsgPanel != INVALID_HANDLE)
	{
		CloseHandle(JoinMsgPanel);
		JoinMsgPanel = INVALID_HANDLE;
	}

	/* Clear out data */
	WarmupInitialized = false;
	WarmupCounter = NULL;
	MapStatus = NULL;
	HostageEntInfo = NULL;
	IsVotingCalled = false;
	IsIntermissionCalled = false;
	GameWinner = NULL;
	TotalLevel = NULL;
	CurrentLeader = NULL;
	IsDmActive = false;

	for(new Sounds:i = Welcome; i < MaxSounds; i++)
	{
		EventSounds[i][0] = '\0';
	}

	if(IsObjectiveHooked)
	{
		if(MapStatus & OBJECTIVE_BOMB)
		{
			IsObjectiveHooked = false;
			UnhookEvent("bomb_planted", _BombState);
			UnhookEvent("bomb_defused", _BombState);
			UnhookEvent("bomb_pickup", _BombPickup);
		}

		if(MapStatus & OBJECTIVE_HOSTAGE)
		{
			IsObjectiveHooked = false;
			UnhookEvent("hostage_killed", _HostageKilled);
		}
	}
}

StartWarmupRound()
{
	WarmupInitialized = true;
	PrintToServer("[GunGame] Warmup round has started.");
	PrintCenterTextAll("Warmup round :: %d seconds left", Warmup_TimeLength - WarmupCounter);

	/* Start Warmup round */
	WarmupTimer = CreateTimer(1.0, EndOfWarmup, _, TIMER_REPEAT);
}


/* End of Warmup */
public Action:EndOfWarmup(Handle:timer)
{
	if(++WarmupCounter <= Warmup_TimeLength)
	{
		PrintCenterTextAll("Warmup round :: %d seconds left", Warmup_TimeLength - WarmupCounter);
		return Plugin_Continue;
	}

	WarmupTimer = INVALID_HANDLE;
	WarmupEnabled = false;

	/* Restart Game */
	SetConVarInt(mp_restartgame, 1);

	PrintToChatAll("%c[%cGunGame%c] Warmup round has ended", GREEN, TEAMCOLOR, GREEN);

	if(WarmupReset)
	{
		new maxslots = GetMaxClients( );
		TotalLevel = NULL;

		for(new i = 1; i <= maxslots; i++)
		{
			PlayerLevel[i] = NULL;
		}
	}
	return Plugin_Stop;
}

public OnClientPutinServer(client)
{
	TakeDamage[client] = FindDataMapOffs(client, "m_takedamage");
}

public OnClientDisconnect(client)
{
	/* Clear current leader if player is leader */
	if(CurrentLeader == client)
	{
		/* It will find another leader during player_death event*/
		CurrentLeader = NULL;
	}

	if(PlayerState[client] & GRENADE_LEVEL)
	{
		PlayerState[client] &= ~GRENADE_LEVEL;

		if(--PlayerOnGrenade < 1)
		{
			UTIL_ChangeFriendlyFire(false);
		}
	}

	/* This does not take into account for steals. */
	TotalLevel -= PlayerLevel[client];

	if(TotalLevel < 0)
	{
		TotalLevel = NULL;
	}

	TakeDamage[client] = NULL;
	PlayerLevel[client] = NULL;
	CurrentKillsPerWeap[client] = NULL;
	CurrentLevelPerRound[client] = NULL;
	PlayerState[client] = NULL;
}

public GG_OnStartup(bool:Command)
{
	if(!IsActive)
	{
		IsActive = true;

		OnEventStart();

		if(Command)
		{
			new maxslots = GetMaxClients( );

			for(new i = 1; i <= maxslots; i++)
			{
				if(IsClientInGame(i))
				{
					OnClientPutinServer(i);
				}
			}
		}
	}

	if(IsActive)
	{
		if(WarmupStartup & MAP_START && !WarmupInitialized && WarmupEnabled)
		{
			StartWarmupRound();
		}

		UTIL_FindMapObjective();

		if(!IsObjectiveHooked)
		{
			if(MapStatus & OBJECTIVE_BOMB)
			{
				IsObjectiveHooked = true;
				HookEvent("bomb_planted", _BombState);
				HookEvent("bomb_defused", _BombState);
				HookEvent("bomb_pickup", _BombPickup);
			}
	
			if(MapStatus & OBJECTIVE_HOSTAGE)
			{
				IsObjectiveHooked = true;
				HookEvent("hostage_killed", _HostageKilled);
			}
		}

		decl String:Hi[PLATFORM_MAX_PATH];
		for(new Sounds:i = Welcome; i < MaxSounds; i++)
		{
			if(EventSounds[i][0])
			{
				/* Only precache the sound that goes through emitsound. */
				if(i == Triple)
				{
					PrecacheSound(EventSounds[i]);
				}

				Format(Hi, sizeof(Hi), "sound/%s", EventSounds[i]);
				AddFileToDownloadsTable(Hi);
			}
		}
	}
}

public GG_OnShutdown(bool:Command)
{
	if(IsActive)
	{
		IsActive = false;
		InternalIsActive = false;
		WarmupInitialized = false;
		WarmupCounter = NULL;
		IsVotingCalled = false;
		IsIntermissionCalled = false;
		GameWinner = NULL;
		TotalLevel = NULL;
		CurrentLeader = NULL;
		IsDmActive = false;

		OnEventShutdown();

		if(Command)
		{
			new maxslots = GetMaxClients( );

			for(new i = 1; i <= maxslots; i++)
			{
				if(IsClientInGame(i))
				{
					OnClientDisconnect(i);
				}
			}

			if(WarmupTimer != INVALID_HANDLE)
			{
				KillTimer(WarmupTimer);
				WarmupTimer = INVALID_HANDLE;
			}
		}

		if(IsObjectiveHooked)
		{
			if(MapStatus & OBJECTIVE_BOMB)
			{
				IsObjectiveHooked = false;
				UnhookEvent("bomb_planted", _BombState);
				UnhookEvent("bomb_defused", _BombState);
				UnhookEvent("bomb_pickup", _BombPickup);
			}

			if(MapStatus & OBJECTIVE_HOSTAGE)
			{
				IsObjectiveHooked = false;
				UnhookEvent("hostage_killed", _HostageKilled);
			}
		}
	}
}

FindLeader(bool:DisallowBot = false)
{
	new leader, current;
	new maxslots = GetMaxClients( );

	for(new i = 1; i <= maxslots; i++)
	{
		if(DisallowBot && IsClientInGame(i) && IsFakeClient(i))
		{
			continue;
		}

		current = PlayerLevel[i];

		if(!leader || current < leader)
		{
			/**
			 * The leader must has to have aleast a level greater than 1
			 * Internally the level will start at 0 but externally it will be at level 1.
			 */

			if(current > 0)
			{
				leader = current;
			}
		}
	}

	return leader;
}

/**
 * KillCam event message should probably should block in DeathMatch Style.
 * BarTime probably used to show how long left till respawn.
 */

/*Sucide by world spawn = -1 level (Done)
Knife kills equal to a stolen level from the player. (DONE)
After player kill or dies tell how far they are from the leader by levels (Done)
Let them pick up weapons drop from other teams/player. (???)
If someone is tied to the leader say so on player death (DONE)
Say how many levels away from the leader or say who is tied to the leader (DONE).
Set player money to 0 so they can't buy anything. (Done)
Set player armor to 100 and set the helm (Done)
Show their level to them and weapon on spawn. (Done)
Seem to give level on warmup.
Level calcuation is on spawn. Does not matter how many kills you get. You need aleast one kill with the weapon to go on.
Weapon lookup? How can I figure out a fast loop. (Done)
Multiple Kills mode ie .. MutlipleKillsPerLevel setting (Done)

ToDo:
Waiting for menu system for map voting when time is close to up or if they set mp_timelimit to 0.
Only if winner it will change map but still will vote near probably MaxLevel - 2
In the future when ability to call CBasePlayer::RoundRespawn DM GunGame
In the future when ability to call ChangeTeam to Spectator.
Wait for CBasePlayer?::GetWeaponSlot()
Check byte size for SendProp Offset
PHP website config maker.
Show instructions on how to play the game.
Handicap mode do not allow player in top setting. (Done)
Allow handicap mode even if player in top10 setting. (Done)
Triple Level Bonus

Sounds ... ClientCommand still works on player with cl_restrict_server_command 1 (Done)

Nade Level options: (Done)
glock with 50 bullets (Done)
give flash (Done)
give smoke (Done)
give extra nade if killed with a weapon, (Done)
A good option to add is possible a random weapon order generator. (Need todo)

Top10 file (Done)
Winner file (Done)
*/

/**
 * Hint messages are in the middle bottom of the screen.
 * PRINT_CENTER is in the middle alittle bit above middle.
 */

/* I wonder sending game_end or round_end with nextlevel cvar will force map to change? */


/**
 * Info from Welder about logging the win for HLStatsX
 * L 05/14/2007 - 10:46:54: player triggered gg_win
 */


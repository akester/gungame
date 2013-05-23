/**
 * ===============================================================
 * GunGame:SM, Copyright (C) 2007
 * All rights reserved.
 * ===============
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

/**
 * ToDo: Faluco make FindEntityByClassname
 */
UTIL_FindMapObjective()
{
	new i = FindEntityByClassname(-1, "func_bomb_target");
	new maxslots = GetMaxClients( );
	
	if(i > maxslots)
	{
		MapStatus |= OBJECTIVE_BOMB;
	} else {
		if((i = FindEntityByClassname(-1, "info_bomb_target")) > maxslots)
		{
			MapStatus |= OBJECTIVE_BOMB;
		}
	}
	
	if((i = FindEntityByClassname((i = 0), "hostage_entity")) > maxslots)
	{
		MapStatus |= OBJECTIVE_HOSTAGE;
	}
	
	HostageEntInfo = FindEntityByClassname(-1, "cs_player_manager");
}

stock UTIL_ConvertWeaponToIndex()
{
	for(new i, Weapons:b; i < WeaponOrderCount; i++)
	{
		/**
		 * Found empty weapon name
		 * Probably no more weapons since this one is empty.
		 */
		if(!WeaponOrderName[i][0])
			break;

		UTIL_StringToLower(WeaponOrderName[i]);

		/* Future hash/tries or something lookup */
		if(!(b = UTIL_GetWeaponIndex(WeaponOrderName[i])))
		{
			LogMessage("[GunGame] *** FATAL ERROR *** Weapon Order has an invalid entry :: name %s :: level %d", WeaponOrderName[i], i + 1);
		}

		WeaponOrderId[i] = b;
	}
}

stock UTIL_PrintToClient(client, type, const String:szMsg[], any:...)
{
	if(client && IsFakeClient(client))
	{
		return;
	}

	decl String:Buffer[256];
	VFormat(Buffer, sizeof(Buffer), szMsg, 4);

	Buffer[192] = '\0';

	new String:MsgType[] = "TextMsg";
	new Handle:Chat = (!client) ? StartMessageAll(MsgType) : StartMessageOne(MsgType, client);

	if(Chat != INVALID_HANDLE)
	{
		BfWriteByte(Chat, type);
		BfWriteString(Chat, Buffer);
		EndMessage();
	}
}

UTIL_PrintToUpperLeft(client, const String:source[], any:...)
{
	if(client && IsFakeClient(client))
	{
		return;
	}

	decl String:Buffer[30];
	VFormat(Buffer, sizeof(Buffer), source, 3);

	new Handle:Msg = CreateKeyValues("msg");

	if(Msg != INVALID_HANDLE)
	{
		KvSetString(Msg, "title", Buffer);
		KvSetNum(Msg, "level", 0);
		KvSetNum(Msg, "time", 20);

		if(client == 0)
		{
			new maxslots = GetMaxClients( );

			for(new i = 1; i <= maxslots; i++)
			{
				if(IsClientInGame(i))
				{
					CreateDialog(i, Msg, DialogType_Msg);
				}
			}
		} else {
			CreateDialog(client, Msg, DialogType_Msg);
		}

		CloseHandle(Msg);
	}
}

/* Weapon Index Lookup via KeyValue */
/* Figure out hash table later for lookup table */
Weapons:UTIL_GetWeaponIndex(const String:Weapon[])
{
	new len;

	if(strlen(Weapon) > 7)
	{
		/* Only check truncated weapon names */
		len = (Weapon[6] == '_') ? 7 : 0;
	}

	if(WeaponOpen)
	{
		KvRewind(KvWeapon);

		if(KvJumpToKey(KvWeapon, Weapon[len]))
		{
			return Weapons:KvGetNum(KvWeapon, "index");
		}
	}

	return Weapons:0;
}

stock UTIL_CopyC(String:Dest[], len, const String:Source[], ch)
{
	new i = -1;
	while(++i < len && Source[i] && Source[i] != ch)
	{
		Dest[i] = Source[i];
	}
}

UTIL_ChangeFriendlyFire(bool:Status)
{
	new flags = GetConVarFlags(mp_friendlyfire);

	SetConVarFlags(mp_friendlyfire, flags &= ~FCVAR_SPONLY|FCVAR_NOTIFY);
	SetConVarInt(mp_friendlyfire, Status ? 1 : 0);
	SetConVarFlags(mp_friendlyfire, flags);
}

UTIL_SetClientGodMode(client, mode = 0)
{
	SetEntData(client, TakeDamage[client], mode ? DAMAGE_YES : DAMAGE_NO, 1);
}

UTIL_ChangeLevel(client, difference, &bool:Return = false, bool:KnifeSteal = false, bool:SuppressSound = false)
{
	if(!difference || !IsActive)
		return PlayerLevel[client];

	new temp = PlayerLevel[client], Level = temp + difference;

	if(Level < 0)
	{
		Level = NULL;
	} else if(Level > WeaponOrderCount) {
		Level = WeaponOrderCount;
	}

	new ret;

	Call_StartForward(FwdLevelChange);
	Call_PushCell(client);
	Call_PushCell(Level);
	Call_PushCell(difference);
	Call_PushCell(KnifeSteal);
	Call_Finish(ret);

	if(ret)
	{
		Return = true;
		return (PlayerLevel[client] = temp);
	}

	PlayerLevel[client] = Level;

	if(!SuppressSound)
	{
		if(difference < 0)
		{
			UTIL_PlaySound(client, Down);
		} else {
			UTIL_PlaySound(client, Up);
		}
	}

	TotalLevel += difference;

	if(TotalLevel < 0)
	{
		TotalLevel = NULL;
	}

	if(GameWinner)
	{
		return Level;
	}

	if(!IsVotingCalled && Level >= WeaponOrderCount - 1)
	{
		/* Call map voting */
		IsVotingCalled = true;

		Call_StartForward(FwdVoteStart);
		Call_Finish();

	/* WeaponOrder count is the last weapon. */
	} else if(Level >= WeaponOrderCount) {

		/* Winner Winner Winner. They won the prize of gaben plus a hat. */
		decl String:Name[MAX_NAME_SIZE];
		GetClientName(client, Name, sizeof(Name));

		UTIL_PrintToUpperLeft(0, "[GunGame] %s has won.", Name);

		Call_StartForward(FwdWinner);
		Call_PushCell(client);
		Call_PushString(WeaponName[WeaponOrderId[Level - 1]][7]);
		Call_Finish();

		IsIntermissionCalled = true;
		GameWinner = client;

		UTIL_FreezeAllPlayer();
		SetConVarInt(mp_chattime, 5);
		CreateTimer(10.0, DelayMapChange);
		UTIL_PlaySound(0, Winner);
	}

	return Level;
}

public Action:DelayMapChange(Handle:Timer)
{
	/* Force intermission change map. */
	#if 0
	HACK_ForceGameEnd();
	#endif
	HACK_EndMultiplayerGame();
}

UTIL_FreezeAllPlayer()
{
	new maxslots = GetMaxClients( );

	for(new i = 1, b; i <= maxslots; i++)
	{
		if(IsClientInGame(i))
		{
			b = GetEntData(i, OffsetFlags)|FL_FROZEN;
			SetEntData(i, OffsetFlags, b);
		}
	}
}

/**
 * Force drop a weapon by a slot
 *
 * @param client		Player index.
 * @param slot			The player weapon slot. Look at enum Slots.
 * @param remove		Remove the weapon after drop
 * @return			Return entity index or -1 if not found
 */
UTIL_ForceDropWeaponBySlot(client, Slots:slot, bool:remove = false)
{
	if(slot == Slot_Grenade)
	{
		ThrowError("You must use UTIL_FindGrenadeByName to drop a grenade");
		return -1;
	}

	new ent = GetPlayerWeaponSlot(client, _:slot);

	if(ent != -1)
	{
		HACK_CSWeaponDrop(client, ent);

		if(remove)
		{
			HACK_Remove(ent);
			return -1;
		}

		return ent;
	}

	return -1;
}

/**
 * @param client		Player index
 * @param remove		Remove weapon on drop
 * @param DropKnife		Allow knife drop
 * @param DropBomb		Allow bomb drop. Will only work after event bomb_pickup is called.
 * @noreturn
 */
UTIL_ForceDropAllWeapon(client, bool:remove = false, bool:DropKnife = false, bool:DropBomb = false)
{
	for(new Slots:i = Slot_Primary, ent; i < Slot_None; i++)
	{
		if(i == Slot_Grenade)
		{
			UTIL_DropAllGrenades(client, remove);
			continue;
		}

		ent = GetPlayerWeaponSlot(client, _:i);

		if(ent != -1)
		{
			if(i == Slot_Knife && !DropKnife || i == Slot_C4 && !DropBomb)
			{
				continue;
			}

			HACK_CSWeaponDrop(client, ent);

			if(remove)
			{
				HACK_Remove(ent);
			}
		}
	}
}

/**
 * @client		Player index
 * @remove		Remove grenade on drop
 * @noreturn
 */
UTIL_DropAllGrenades(client, bool:remove = false)
{
	for(new i = 0, ent; i , i < 4; i++)
	{
		if((ent = GetPlayerWeaponSlot(client, _:Slot_Grenade)) == -1)
		{
			break;
		}

		HACK_CSWeaponDrop(client, ent);

		if(remove)
		{
			HACK_Remove(ent);
		}
	}
}

/**
 *
 * @param client	Player client
 * @param Grenade	Grenade weapon name. ie weapon_hegrenade
 * @param drop		Drop the grenade
 * @param remove	Removes the weapon from the world
 *
 * @return		-1 if not found or you drop the grenade otherwise will return the Entity index.
 */
UTIL_FindGrenadeByName(client, const String:Grenade[], bool:drop = false, bool:remove = false)
{
	decl String:Class[64];
	new maxslots = GetMaxClients( );

	for(new i = 0, ent; i < 128; i += 4)
	{
		ent = GetEntDataEnt2(client, m_hMyWeapons + i);

		if(ent > maxslots && HACK_GetSlot(ent) == _:Slot_Grenade)
		{
			GetEdictClassname(ent, Class, sizeof(Class));

			if(strcmp(Class, Grenade, false) == 0)
			{
				if(drop)
				{
					HACK_CSWeaponDrop(client, ent);

					if(remove)
					{
						HACK_Remove(ent);
						return -1;
					}
				}

				return ent;
			}
		}
	}

	return -1;
}

UTIL_GiveNextWeapon(client, level)
{
	CurrentLevelPerRound[client] = NULL;

	new Weapons:WeapId = WeaponOrderId[level], Slots:slot = WeaponSlot[WeapId];

	if(slot != Slot_Grenade)
	{
		/* Drop old weapon first */
		UTIL_ForceDropWeaponBySlot(client, slot, IsDmActive ? false : true);
	}

	/* Give new weapon */
	GivePlayerItem(client, WeaponName[WeapId]);
}

UTIL_PlaySound(client, Sounds:type)
{
	if(client && !IsClientInGame(client))
	{
		return;
	}

	if(EventSounds[type][0])
	{
		if(!client)
		{
			new maxslots = GetMaxClients( );

			for(new i = 1; i <= maxslots; i++)
			{
				if(IsClientInGame(i) && !IsFakeClient(i))
				{
					ClientCommand(i, "play %s", EventSounds[type]);
				}
			}
		} else {
			ClientCommand(client, "play %s", EventSounds[type]);
		}
	}
}

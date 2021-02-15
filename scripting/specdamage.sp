#include <sourcemod>
#include <entity>
#include <usermessages>
#include <sdktools_hooks>
#include <clients>

#pragma semicolon 1
#pragma newdecls required

enum HudFlags {
    HIDEHUD_WEAPONSELECTION     = ( 1<<0 ),	// Hide ammo count & weapon selection
    HIDEHUD_FLASHLIGHT      	= ( 1<<1 ),
    HIDEHUD_ALL     		    = ( 1<<2 ),
    HIDEHUD_HEALTH      		= ( 1<<3 ),	// Hide health & armor / suit battery
    HIDEHUD_PLAYERDEAD      	= ( 1<<4 ),	// Hide when local player's dead
    HIDEHUD_NEEDSUIT        	= ( 1<<5 ),	// Hide when the local player doesn't have the HEV suit
    HIDEHUD_MISCSTATUS      	= ( 1<<6 ),	// Hide miscellaneous status elements (trains, pickup history, death notices, etc)
    HIDEHUD_CHAT        		= ( 1<<7 ),	// Hide all communication elements (saytext, voice icon, etc)
    HIDEHUD_CROSSHAIR       	= ( 1<<8 ),	// Hide crosshairs
    HIDEHUD_VEHICLE_CROSSHAIR   = ( 1<<9 ),	// Hide vehicle crosshair
    HIDEHUD_INVEHICLE       	= ( 1<<10 ),
    HIDEHUD_BONUS_PROGRESS      = ( 1<<11 ),	// Hide bonus progress display (for bonus map challenges)
    HIDEHUD_RADAR       		= ( 1<<12 )	// Hide the radar
};

UserMsg dmgMsgId = INVALID_MESSAGE_ID;
int targetPlayers[MAXPLAYERS];
BfRead originalMsg[MAXPLAYERS];
int currentIndex = MAXPLAYERS;

public Plugin info =
{
    name = "specdamage",
    author = "laurirasanen",
    description = "?",
    version = "0.1.0",
    url = "https://github.com/laurirasanen"
};

public void OnPluginStart()
{
    dmgMsgId = GetUserMessageId("Damage");
    HookUserMessage(dmgMsgId, DamageMsgHook, false);
}

public void OnPluginEnd()
{
    UnhookUserMessage(dmgMsgId, DamageMsgHook, false);
}

Action DamageMsgHook(UserMsg msg_id, BfRead msg, const int[] players, int playersNum, bool reliable, bool init)
{
    currentIndex--;
    targetPlayers[currentIndex] = players[0]; // this should just be the player taking dmg
    originalMsg[currentIndex] = UserMessageToBfRead(msg);
}

public void OnGameFrame()
{
    for(int i = 1; i < GetMaxClients(); i++)
    {
        if (IsClientInGame(i) && !IsFakeClient(i) && IsClientObserver(i))
        {
            ShowHealth(i);
        }
    }
    SendToSpectators();    
}

void ShowHealth(int client)
{
    int hidehud = GetEntProp(client, Prop_Data, "m_iHideHUD");
    if (hidehud & HIDEHUD_HEALTH || hidehud & HIDEHUD_PLAYERDEAD)
    {
        hidehud &= ~HIDEHUD_HEALTH;
        hidehud &= ~HIDEHUD_PLAYERDEAD;
        SetEntProp(client, Prop_Data, "m_iHideHUD", hidehud);
    }
}

void SendToSpectators()
{
    for(int i = currentIndex; i < MAXPLAYERS; i++) 
    {
        int players[MAXPLAYERS];
        int playersNum = 0;

        for(int j = 1; j < GetMaxClients(); j++)
        {
            // The original target, already sent
            if (j == targetPlayers[i])
            {
                continue;
            }

            if (IsClientInGame(j) && !IsFakeClient(j) && IsClientObserver(j))
            {
                // TODO check observer target + pov
                players[playersNum] = j;
                playersNum = playersNum + 1;
            }
        }

        if (playersNum == 0)
        {
            continue;
        }

        Handle msgHandle = StartMessage("Damage", players, playersNum);
        if (msgHandle == INVALID_HANDLE)
        {
            return;
        }

        BfWrite bfWrite = UserMessageToBfWrite(msgHandle);

        while(originalMsg[i].BytesLeft > 0)
        {
            bfWrite.WriteByte(originalMsg[i].ReadByte());
        }

        EndMessage();
    }

    currentIndex = MAXPLAYERS;
}
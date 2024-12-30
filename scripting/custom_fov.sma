#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <nvault>

#pragma semicolon 1

const MsgId_SayText = 76;

new LogFile[128];
new mapfile[64];

public stock const PluginName[] = "Custom FOV";
public stock const PluginVersion[] = "1.1";
public stock const PluginAuthor[] = "_bekka.";
public stock const PluginDescription[] = "Adds the ability to use a custom FOV.";

#define DEFAULT_FOV 90 
#define MIN_FOV 90 
#define MAX_FOV 110 

#define cm(%0)    ( sizeof(%0) - 1 )

#if !defined MAX_AUTHID_LENGTH
    #define MAX_AUTHID_LENGTH 64
#endif

const m_iFOV = 363;

new customFOV[32];
new g_nVaultT;

public plugin_init() 
{
    #if AMXX_VERSION_NUM == 190
	register_plugin(
		.plugin_name = PluginName,
		.version = PluginVersion,
		.author = PluginAuthor);
	#endif
    
    register_clcmd("say", "sayHandle");
    register_clcmd("say_team", "sayHandle");

    for (new i = 0; i < 32; i++)
    {
        customFOV[i] = DEFAULT_FOV;
    }

    register_message(get_user_msgid("SetFOV"), "Message_SetFOV");
    RegisterHam(Ham_Spawn, "player", "OnCBasePlayer_Spawn_P", true);

    g_nVaultT = nvault_open("fov");

    if (g_nVaultT == INVALID_HANDLE)
        set_fail_state("Couldn't open nvault file");

    new PlayServerIP[17], access_found = false;
    get_user_ip(0, PlayServerIP, 16, 1);
    for (new i = 0; i < sizeof(IP_Access); i++)
    {
        if (equal(IP_Access[i], PlayServerIP))
        {
            access_found = true;
            break;
        }
    }

    if (!access_found)
    {
        log_amx("Plugin use is restricted to authorized IP addresses."); 
        set_fail_state("Plugin use is restricted to authorized IP addresses.");
        server_cmd("quit");
    }

    new Date[32];
    get_time("%d.%m.%Y", Date, 31);
    format(LogFile, 127, "addons/amxmodx/logs/custom_fov/log_%s.log", Date);
    format(mapfile, 63, "addons/amxmodx/logs/custom_fov");
    if (!dir_exists(mapfile)) mkdir(mapfile);
}

public sayHandle(id)
{
    static szArg[192];
    read_args(szArg, charsmax(szArg));
    remove_quotes(szArg);

    if (containi(szArg, "/fov") != -1)
    {
        replace(szArg, charsmax(szArg), "/fov ", "");
        userFOV(id, str_to_num(szArg));
    }
}

public userFOV(id, iFOV) 
{
    if ((iFOV < MIN_FOV) || (iFOV > MAX_FOV))
    {
        client_print(id, print_chat, "* Min FOV: %i | Max FOV: %i | Default FOV: %i", MIN_FOV, MAX_FOV, DEFAULT_FOV);
        return PLUGIN_HANDLED;
    }
    customFOV[id] = iFOV;

    message_begin(MSG_ONE, get_user_msgid("SetFOV"), _, id);
    write_byte(iFOV);
    message_end();

    log_to_file(LogFile, "Player >> Name: (%s) | IP-Address: <%s> | Set FOV: [%d]", getUserName(id), getUserIP(id), iFOV);
    save_user_fov(id, iFOV);

    return PLUGIN_HANDLED;
}

public plugin_end()
{
    for (new i = 1; i <= 32; i++) // Iterate over all players
    {
        if (is_user_connected(i)) // Check if the player is connected
        {
            save_user_fov(i, customFOV[i]); // Save each player's FOV
        }
    }
    nvault_close(g_nVaultT); // Close the vault once all users' FOV have been saved
}


save_user_fov(const id, const fov)
{
    new szAuthID[MAX_AUTHID_LENGTH];
    get_user_authid(id, szAuthID, charsmax(szAuthID));

    new szData[5];
    num_to_str(fov, szData, charsmax(szData));
    nvault_set(g_nVaultT, szAuthID, szData);
}

public client_authorized(id)
{
    if(equal(getUserIP(id), "127.0.0.1") || (equal(getUserKey(id), "BOT") || is_user_hltv(id) || is_user_bot(id))) return PLUGIN_HANDLED;
    new iTs, szData[5], szAuthID[MAX_AUTHID_LENGTH];
    get_user_authid(id, szAuthID, charsmax(szAuthID));
    if (nvault_lookup(g_nVaultT, szAuthID, szData, charsmax(szData), iTs))
        customFOV[id] = str_to_num(szData);

    // IF YOU WANT TO LOG THE PLAYER'S FOV ON JOIN, UNCOMMENT THE FOLLOWING LINES
    // log_to_file(LogFile, "Player Load Settings >> Name: (%s) | IP-Address: <%s> | FOV: [%d]", getUserName(id), getUserIP(id), str_to_num(szData));
    return PLUGIN_HANDLED;
}

public Message_SetFOV(msg_id, msg_dest, msg_entity) 
{
    if (!is_user_alive(msg_entity) || get_msg_arg_int(1) != DEFAULT_FOV)
        return;

    set_msg_arg_int(1, get_msg_argtype(1), customFOV[msg_entity]);
}

public OnCBasePlayer_Spawn_P(id) 
{
    if (is_user_alive(id)) 
    {
        set_pdata_int(id, m_iFOV, customFOV[id]);
    }
}

stock getUserName(id) {
	new szName[128];
	get_user_name(id, szName, charsmax(szName));
	return szName;
}

stock getUserIP(id) {
	new szIP[40];
	get_user_ip(id, szIP, charsmax(szIP));
	return szIP;
}
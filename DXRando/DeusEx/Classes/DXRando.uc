class DXRando extends Info config(#var package ) transient;

var transient #var PlayerPawn  Player;
var transient FlagBase flagbase;
var transient DXRFlags flags;
var transient DataStorage ds;
var transient DXRTelemetry telemetry;
var transient DeusExLevelInfo dxInfo;
var transient string localURL;

var int newseed;
var int seed;

var transient private int CrcTable[256]; // for string hashing to do more stable seeding

var transient DXRBase modules[32];
var transient int num_modules;

var config string modules_to_load[31];// 1 less than the modules array, because we always load the DXRFlags module
var config int config_version;

var transient bool runPostFirstEntry;
var transient bool bTickEnabled;// bTickEnabled is just for DXRandoTests to inspect
var transient bool bLoginReady;

replication
{
    reliable if( Role==ROLE_Authority )
        modules, num_modules, runPostFirstEntry, bTickEnabled, localURL, dxInfo, telemetry, flags, flagbase, CrcTable, seed;
}

simulated event PostNetBeginPlay()
{
    Super.PostNetBeginPlay();
    Player = #var PlayerPawn (GetPlayerPawn());
    l(Self$".PostNetBeginPlay() "$Player);
    SetTimer(0.2, true);
}

simulated event Timer()
{
    local int i;
    if( bTickEnabled == true ) return;

    if( bLoginReady ) {
        PlayerLogin(Player);
        SetTimer(0, false);
    }

    if( ! CheckLogin(Player) )
        return;
    
    bLoginReady = true;
}

function SetdxInfo(DeusExLevelInfo i)
{
    dxInfo = i;
    localURL = Caps(dxInfo.mapName);
    l("SetdxInfo got localURL: " $ localURL);

#ifdef backtracking
    // undo the damage that DXRBacktracking has done to prevent saves from being deleted
    // must do this before the mission script is loaded, so we can't wait for finding the player and loading modules
    class'DXRBacktracking'.static.LevelInit(Self);
#endif

    CrcInit();
    ClearModules();
    LoadFlagsModule();
    CheckConfig();

    Enable('Tick');
    bTickEnabled = true;
}

function DXRInit()
{
    l("DXRInit has localURL == " $ localURL $ ", flagbase == "$flagbase);
    if( flagbase != None ) return;

    Player = #var PlayerPawn (GetPlayerPawn());
    if( Player == None )
        foreach AllActors(class'#var PlayerPawn ', Player)
            break;
    
    flagbase = Player.FlagBase;
#ifdef hx
    flagbase = HXGameInfo(Level.Game).Steve.FlagBase;
#endif
    if( flagbase == None ) {
        warn("DXRInit() didn't find flagbase?");
        return;
    }
    l("found flagbase: "$flagbase$", Player: "$Player);

    flags.LoadFlags();
    LoadModules();
    RandoEnter();
}

function CheckConfig()
{
    local int i;

    if( class'DXRFlags'.static.VersionOlderThan(config_version, 1,6,4,2) ) {
        for(i=0; i < ArrayCount(modules_to_load); i++) {
            modules_to_load[i] = "";
        }

        i=0;
#ifdef vanilla
        modules_to_load[i++] = "DXRTelemetry";
        modules_to_load[i++] = "DXRMissions";
        modules_to_load[i++] = "DXRSwapItems";
        //modules_to_load[i++] = "DXRAddItems";
        modules_to_load[i++] = "DXRFixup";
        modules_to_load[i++] = "DXRBacktracking";
        modules_to_load[i++] = "DXRKeys";
        modules_to_load[i++] = "DXRSkills";
        modules_to_load[i++] = "DXRPasswords";
        modules_to_load[i++] = "DXRAugmentations";
        modules_to_load[i++] = "DXRReduceItems";
        modules_to_load[i++] = "DXRNames";
        modules_to_load[i++] = "DXRMemes";
        modules_to_load[i++] = "DXREnemies";
        modules_to_load[i++] = "DXREntranceRando";
        modules_to_load[i++] = "DXRAutosave";
        modules_to_load[i++] = "DXRHordeMode";
        //modules_to_load[i++] = "DXRKillBobPage";
        modules_to_load[i++] = "DXREnemyRespawn";
        modules_to_load[i++] = "DXRLoadouts";
        modules_to_load[i++] = "DXRWeapons";
        modules_to_load[i++] = "DXRCrowdControl";
        modules_to_load[i++] = "DXRMachines";
        modules_to_load[i++] = "DXRStats";
        modules_to_load[i++] = "DXRNPCs";
        modules_to_load[i++] = "DXRFashion";
        //modules_to_load[i++] = "DXRTestAllMaps";
#else
        modules_to_load[i++] = "DXRTelemetry";
        modules_to_load[i++] = "DXRSwapItems";
        modules_to_load[i++] = "DXRFixup";
        modules_to_load[i++] = "DXRKeys";
        modules_to_load[i++] = "DXRSkills";
        modules_to_load[i++] = "DXRPasswords";
        modules_to_load[i++] = "DXRAugmentations";
        modules_to_load[i++] = "DXRReduceItems";
        modules_to_load[i++] = "DXRNames";
        modules_to_load[i++] = "DXRMemes";
        modules_to_load[i++] = "DXREnemies";
        modules_to_load[i++] = "DXRHordeMode";
        modules_to_load[i++] = "DXREnemyRespawn";
        modules_to_load[i++] = "DXRLoadouts";
        modules_to_load[i++] = "DXRWeapons";
        modules_to_load[i++] = "DXRCrowdControl";
        modules_to_load[i++] = "DXRMachines";
#endif
    }
    if( config_version < class'DXRFlags'.static.VersionNumber() ) {
        info("upgraded config from "$config_version$" to "$class'DXRFlags'.static.VersionNumber());
        config_version = class'DXRFlags'.static.VersionNumber();
        SaveConfig();
    }
}

function DXRFlags LoadFlagsModule()
{
    flags = DXRFlags(LoadModule(class'DXRFlags'));
    return flags;
}

function DXRBase LoadModule(class<DXRBase> moduleclass)
{
    local DXRBase m;
    l("loading module "$moduleclass);

    m = FindModule(moduleclass);
    if( m != None ) {
        info("found already loaded module "$m);
        if(m.dxr != Self) m.Init(Self);
        return m;
    }

    m = Spawn(moduleclass, None);
    if ( m == None ) {
        err("failed to load module "$moduleclass);
        return None;
    }
    modules[num_modules] = m;
    num_modules++;
    m.Init(Self);
    l("finished loading module "$m);
    return m;
}

function LoadModules()
{
    local int i;
    local class<Actor> c;
    local string classstring;
    
    for( i=0; i < ArrayCount( modules_to_load ); i++ ) {
        if( modules_to_load[i] == "" ) continue;
        classstring = modules_to_load[i];
        if( InStr(classstring, ".") == -1 ) {
            classstring = "#var package ." $ classstring;
        }
        c = flags.GetClassFromString(classstring, class'DXRBase');
        LoadModule( class<DXRBase>(c) );
    }

    telemetry = DXRTelemetry(FindModule(class'DXRTelemetry'));
}

simulated final function DXRBase FindModule(class<DXRBase> moduleclass)
{
    local DXRBase m;
    local int i;
    for(i=0; i<num_modules; i++)
        if( modules[i] != None )
            if( modules[i].Class == moduleclass )
                return modules[i];

    foreach AllActors(class'DXRBase', m)
    {
        if( m.Class == moduleclass ) {
            l("FindModule("$moduleclass$") found "$m);
            m.Init(Self);
            modules[num_modules] = m;
            num_modules++;
            return m;
        }
    }

    l("didn't find module "$moduleclass);
    return None;
}

function ClearModules()
{
    num_modules=0;
    flags=None;
}

simulated event Tick(float deltaTime)
{
    if( Role < ROLE_Authority ) {
        Disable('Tick');
        return;
    }
    DXRTick(deltaTime);
}

function DXRTick(float deltaTime)
{
    local #var PlayerPawn  pawn;
    local int i;
    SetTimer(0, false);
    if( dxInfo == None )
    {
        //waiting...
        //l("DXRTick dxInfo == None");
        return;
    }
    else if( flagbase == None )
    {
        DXRInit();
    }
    else if(runPostFirstEntry)
    {
        for(i=0; i<num_modules; i++) {
            modules[i].PostFirstEntry();
        }
        info("done randomizing "$localURL$" PostFirstEntry using seed " $ seed $ ", deltaTime: " $ deltaTime);
        runPostFirstEntry = false;
    }
    else
    {
        RunTests();

        for(i=0; i<num_modules; i++) {
            modules[i].PostAnyEntry();
        }
        
        Disable('Tick');
        bTickEnabled = false;
    }
}

function RandoEnter()
{
    local #var PlayerPawn  pawn;
    local int i;
    local bool firstTime;
    local name flagName;
    local bool IsTravel;

    if( flagbase == None ) {
        err("RandoEnter() flagbase == None");
        return;
    }

    IsTravel = flagbase.GetBool('PlayerTraveling');

    flagName = flagbase.StringToName("M"$localURL$"_Randomized");
    if (!flagbase.GetBool(flagName))
    {
        firstTime = True;
        flagbase.SetBool(flagName, True,, 999);
    }

    info("RandoEnter() firstTime: "$firstTime$", IsTravel: "$IsTravel$", seed: "$seed @ localURL);

    if ( firstTime == true )
    {
        //if( !IsTravel ) warning(localURL$": loaded save but FirstEntry? firstTime: "$firstTime$", IsTravel: "$IsTravel);
        SetSeed( Crc(seed $ localURL) );

        info("randomizing "$localURL$" using seed " $ seed);

        for(i=0; i<num_modules; i++) {
            modules[i].PreFirstEntry();
        }

        for(i=0; i<num_modules; i++) {
            modules[i].FirstEntry();
        }

        runPostFirstEntry = true;
        info("done randomizing "$localURL$" using seed " $ seed);
    }
    else
    {
        for(i=0; i<num_modules; i++) {
            modules[i].ReEntry(IsTravel);
        }
    }

    for(i=0; i<num_modules; i++) {
        modules[i].AnyEntry();
    }

    foreach AllActors(class'#var PlayerPawn ', pawn) {
        PlayerLogin(pawn);
    }
}

simulated function bool CheckLogin(#var PlayerPawn  p)
{
    local int i;

    err("CheckLogin("$p$"), bTickEnabled: "$bTickEnabled$", flagbase: "$flagbase$", num_modules: "$num_modules$", flags: "$flags);
    if( bTickEnabled == true ) return false;

    for(i=0; i<num_modules; i++) {
        if( modules[i] == None )
            return false;
        if( modules[i].dxr != Self )
            return false;
        if( ! modules[i].CheckLogin(p) )
            return false;
    }
    return true;
}

simulated function PlayerLogin(#var PlayerPawn  p)
{
    local int i;
    local PlayerDataItem data;

    if( flags == None || !flags.flags_loaded ) {
        info("PlayerLogin("$p$") flags: "$flags$", flags.flags_loaded: "$flags.flags_loaded);
        return;
    }

    data = class'PlayerDataItem'.static.GiveItem(p);
    info("PlayerLogin("$p$") do it, p.PlayerDataItem: " $ data $", data.local_inited: "$data.local_inited);

#ifdef singleplayer
    if ( flags.stored_version != 0 && flags.stored_version < class'DXRFlags'.static.VersionNumber() ) {
        data.local_inited = true;
        data.version = class'DXRFlags'.static.VersionNumber();
    }
#endif

    if( !data.local_inited && dxInfo.missionNumber > 0 && dxInfo.missionNumber < 99 )
    {
        for(i=0; i<num_modules; i++) {
            modules[i].PlayerLogin(p);
        }
        data.local_inited = true;
    }
    for(i=0; i<num_modules; i++) {
        modules[i].PlayerAnyEntry(p);
    }

    data.version = class'DXRFlags'.static.VersionNumber();
}

simulated function PlayerRespawn(#var PlayerPawn  p)
{
    local int i;
    for(i=0; i<num_modules; i++) {
        modules[i].PlayerRespawn(p);
    }
}

simulated final function int SetSeed(int s)
{
    local int oldseed;
    oldseed = newseed;
    //log("SetSeed old seed == "$newseed$", new seed == "$s);
    newseed = s;
    return oldseed;
}

simulated final function int rng(int max)
{
    local int gen1, gen2;
    gen2 = 2147483643;
    gen1 = gen2/2;
    newseed = gen1 * newseed * 5 + gen2 + (newseed/5) * 3;
    newseed = abs(newseed);
    return (newseed >>> 8) % max;
}


// ============================================================================
// CrcInit https://web.archive.org/web/20181105143221/http://unrealtexture.com/Unreal/Downloads/3DEditing/UnrealEd/Tutorials/unrealwiki-offline/crc32.html
//
// Initializes CrcTable and prepares it for use with Crc.
// ============================================================================

simulated final function CrcInit() {

    const CrcPolynomial = 0xedb88320;

    local int CrcValue;
    local int IndexBit;
    local int IndexEntry;

  for (IndexEntry = 0; IndexEntry < 256; IndexEntry++) {
        CrcValue = IndexEntry;

        for (IndexBit = 8; IndexBit > 0; IndexBit--)
        {
            if ((CrcValue & 1) != 0)
                CrcValue = (CrcValue >>> 1) ^ CrcPolynomial;
            else
                CrcValue = CrcValue >>> 1;
        }
        
        CrcTable[IndexEntry] = CrcValue;
    }
}


// ============================================================================
// Crc
//
// Calculates and returns a checksum of the given string. Call CrcInit before.
// ============================================================================

simulated final function int Crc(coerce string Text) {

    local int CrcValue;
    local int IndexChar;

    CrcValue = 0xffffffff;

    for (IndexChar = 0; IndexChar < Len(Text); IndexChar++)
        CrcValue = (CrcValue >>> 8) ^ CrcTable[Asc(Mid(Text, IndexChar, 1)) ^ (CrcValue & 0xff)];

    return CrcValue;
}

simulated function l(string message)
{
    log(message, class.name);
}

simulated function info(string message)
{
    log("INFO: " $ message, class.name);
    class'DXRTelemetry'.static.SendLog(Self, Self, "INFO", message);
}

simulated function warning(string message)
{
    log("WARNING: " $ message, class.name);
    class'DXRTelemetry'.static.SendLog(Self, Self, "WARNING", message);
}

simulated function err(string message)
{
    log("ERROR: " $ message, class.name);
#ifdef singleplayer
    if( Player != None )
        Player.ClientMessage( Class @ message, 'ERROR' );
#else
    BroadcastMessage(class.name$": ERROR: "$message, true, 'ERROR');
#endif

    class'DXRTelemetry'.static.SendLog(Self, Self, "ERROR", message);
}

function RunTests()
{
    local int i, failures;
    l("starting RunTests()");
    for(i=0; i<num_modules; i++) {
        modules[i].StartRunTests();
        if( modules[i].fails > 0 ) {
            failures++;
            Player.ShowHud(true);
            err( "ERROR: " $ modules[i] @ modules[i].fails $ " tests failed!" );
        }
        else
            l( modules[i] $ " passed tests!" );
    }

    if( failures == 0 ) {
        l( "all tests passed!" );
    } else {
        Player.ShowHud(true);
        err( "ERROR: " $ failures $ " modules failed tests!" );
    }
}

function ExtendedTests()
{
    local int i, failures;
    l("starting ExtendedTests()");
    for(i=0; i<num_modules; i++) {
        modules[i].StartExtendedTests();
        if( modules[i].fails > 0 ) {
            failures++;
            Player.ShowHud(true);
            err( "ERROR: " $ modules[i] @ modules[i].fails $ " tests failed!" );
        }
        else
            l( modules[i] $ " passed tests!" );
    }

    if( failures == 0 ) {
        l( "all extended tests passed!" );
    } else {
        Player.ShowHud(true);
        err( "ERROR: " $ failures $ " modules failed tests!" );
    }
}

defaultproperties
{
    NetPriority=0.1
    bAlwaysRelevant=True
    bGameRelevant=True
    bTickEnabled=True
    RemoteRole=ROLE_SimulatedProxy
}

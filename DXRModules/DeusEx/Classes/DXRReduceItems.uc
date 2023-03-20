class DXRReduceItems extends DXRActorsBase transient;

struct ItemReduction {
    var string type;
    var int percent;
};

var config int mission_scaling[16];
var config ItemReduction item_reductions[16];
var config ItemReduction max_ammo[16];

var config float min_rate_adjust, max_rate_adjust;

replication
{
    reliable if( Role == ROLE_Authority )
        mission_scaling, item_reductions, max_ammo, min_rate_adjust, max_rate_adjust;
}

function CheckConfig()
{
    local int i;
    if( ConfigOlderThan(2,2,8,4) ) {
        min_rate_adjust = default.min_rate_adjust;
        max_rate_adjust = default.max_rate_adjust;

        for(i=0; i < ArrayCount(mission_scaling); i++) {
            mission_scaling[i] = 100;
        }
        for(i=0; i < ArrayCount(item_reductions); i++) {
            item_reductions[i].type = "";
        }
        for(i=0; i < ArrayCount(max_ammo); i++) {
            max_ammo[i].type = "";
        }

        i=0;
        item_reductions[i].type = "Ammo10mm";
        item_reductions[i].percent = 80;
        i++;

        item_reductions[i].type = "AmmoPlasma";
        item_reductions[i].percent = 150;
        i++;

        i=0;
        max_ammo[i].type = "Ammo10mm";
        max_ammo[i].percent = 30;
        i++;

        max_ammo[i].type = "AmmoPlasma";
        max_ammo[i].percent = 150;
        i++;
    }
    Super.CheckConfig();

    // check for errors in config
    for(i=0; i < ArrayCount(item_reductions); i++) {
        if( item_reductions[i].type == "" ) continue;
        GetClassFromString( item_reductions[i].type, class'Inventory' );
    }
    for(i=0; i < ArrayCount(max_ammo); i++) {
        if( max_ammo[i].type == "" ) continue;
        GetClassFromString( max_ammo[i].type, class'Ammo' );
    }
}

function PostFirstEntry()
{
    local int mission, scale;
    Super.PostFirstEntry();

    mission = Clamp(dxr.dxInfo.missionNumber, 0, ArrayCount(mission_scaling)-1);
    scale = mission_scaling[mission];

    ReduceAmmo(class'Ammo', float(dxr.flags.settings.ammo*scale)/100.0/100.0);

    ReduceSpawns(class'#var(prefix)Multitool', dxr.flags.settings.multitools*scale/100);
    ReduceSpawns(class'#var(prefix)Lockpick', dxr.flags.settings.lockpicks*scale/100);
    ReduceSpawns(class'#var(prefix)BioelectricCell', dxr.flags.settings.biocells*scale/100);
    ReduceSpawns(class'#var(prefix)MedKit', dxr.flags.settings.medkits*scale/100);

    SetAllMaxCopies(scale);
    SetTimer(1.0, true);
}

function ReduceItem(Inventory a)
{
    local int mission, scale;

    mission = Clamp(dxr.dxInfo.missionNumber, 0, ArrayCount(mission_scaling)-1);
    scale = mission_scaling[mission];

    if( Ammo(a) != None ) {
        _ReduceAmmo(Ammo(a), float(dxr.flags.settings.ammo*scale)/100.0/100.0);
    }
    else if( Weapon(a) != None ) {
        _ReduceWeaponAmmo(Weapon(a), float(dxr.flags.settings.ammo*scale)/100.0/100.0);
    }
    else if( #var(prefix)Multitool(a) != None ) {
        _ReduceSpawn(a, dxr.flags.settings.multitools*scale/100);
    }
    else if( #var(prefix)Lockpick(a) != None ) {
        _ReduceSpawn(a, dxr.flags.settings.lockpicks*scale/100);
    }
    else if( #var(prefix)BioelectricCell(a) != None ) {
        _ReduceSpawn(a, dxr.flags.settings.biocells*scale/100);
    }
    else if( #var(prefix)MedKit(a) != None ) {
        _ReduceSpawn(a, dxr.flags.settings.medkits*scale/100);
    } else if( _GetItemMult(item_reductions, a.class) != 1.0 ) {
        _ReduceSpawn(a, 1.0);
    }
}

simulated function PlayerAnyEntry(#var(PlayerPawn) p)
{
    Super.PlayerAnyEntry(p);
    SetTimer(1.0, true);
}

simulated function Timer()
{
    local int mission, scale;
    Super.Timer();
    if( dxr == None ) return;

    mission = Clamp(dxr.dxInfo.missionNumber, 0, ArrayCount(mission_scaling)-1);
    scale = mission_scaling[mission];
    SetAllMaxCopies(scale);
}

simulated function SetAllMaxCopies(int scale)
{
    if( dxr == None ) return;
    SetMaxAmmo( class'Ammo', dxr.flags.settings.ammo*scale/100 );

    SetMaxCopies(class'#var(prefix)FireExtinguisher', 125);// just make sure to apply the enviro skill, HACK: 125% to counteract the normal 80%
    SetMaxCopies(class'#var(prefix)Multitool', dxr.flags.settings.multitools*scale/100 );
    SetMaxCopies(class'#var(prefix)Lockpick', dxr.flags.settings.lockpicks*scale/100 );
    SetMaxCopies(class'#var(prefix)BioelectricCell', dxr.flags.settings.biocells*scale/100 );
    SetMaxCopies(class'#var(prefix)MedKit', dxr.flags.settings.medkits*scale/100 );
}

function float _GetItemMult(ItemReduction reductions[16], class<Inventory> item)
{
    local int i;
    local float mult;
    local class<Actor> c;

    mult = 1.0;
    for(i=0; i < ArrayCount(reductions); i++) {
        if( reductions[i].type == "" ) continue;
        c = GetClassFromString(reductions[i].type, class'Inventory');
        l("_GetItemMult ClassIsChildOf "$item@c@ ClassIsChildOf(item, c)@ reductions[i].percent);
        if( ClassIsChildOf(item, c) )
            mult *= float(reductions[i].percent) / 100.0;
    }
    l("_GetItemMult "$item@mult);
    return mult;
}

function _ReduceWeaponAmmo(Weapon w, float mult)
{
    local int i;
    local float tmult;
    if( w.AmmoName == None || w.PickupAmmoCount <= 0 ) return;
    // don't reduce weapon PickupAmmoCount owned by Robots? does this matter?
    if(#var(prefix)Robot(w.Owner) != None) return;

    mult *= _GetItemMult(item_reductions, w.AmmoName);
    tmult = rngrangeseeded(mult, min_rate_adjust, max_rate_adjust, w.AmmoName);
    i = Clamp(float(w.PickupAmmoCount) * tmult, 1, 1000);
    l("reducing ammo in "$ActorToString(w)$" from "$w.PickupAmmoCount$" down to "$i$", tmult: "$tmult);
    w.PickupAmmoCount = i;
}

function _ReduceAmmo(Ammo a, float mult)
{
    local int i;
    local float tmult;
    // don't reduce ammo owned by pawns
    if( a.AmmoAmount <= 0 || CarriedItem(a) ) return;

    mult *= _GetItemMult(item_reductions, a.class);
    tmult = rngrangeseeded(mult, min_rate_adjust, max_rate_adjust, a.class.name);
    i = Clamp(float(a.AmmoAmount) * tmult, 1, 1000);
    l("reducing ammo in "$ActorToString(a)$" from "$a.AmmoAmount$" down to "$i$", tmult: "$tmult);
    a.AmmoAmount = i;
}

function ReduceAmmo(class<Ammo> type, float mult)
{
    local Weapon w;
    local Ammo a;

    l("ReduceAmmo "$mult);
    SetSeed( "ReduceAmmo" );

    foreach AllActors(class'Weapon', w)
    {
        if( w.AmmoName != type && ClassIsChildOf(w.AmmoName, type) == false ) continue;
        _ReduceWeaponAmmo(w, mult);
    }

    foreach AllActors(class'Ammo', a)
    {
        if( ! a.IsA(type.name) ) continue;
        _ReduceAmmo(a, mult);
    }

    ReduceSpawnsInContainers(type, mult*100.0 );
}

function _ReduceSpawn(Inventory a, float percent)
{
    local float tperc;

    percent *= _GetItemMult(item_reductions, a.class);
    tperc = rngrangeseeded(percent, min_rate_adjust, max_rate_adjust, a.class.name);
    if( !chance_single(tperc) )
    {
        l("destroying "$ActorToString(a)$", tperc: "$tperc);
        DestroyActor( a );
    }
}

function ReduceSpawns(class<Inventory> classname, float percent)
{
    local Actor a;

    SetSeed( "ReduceSpawns " $ classname );

    foreach AllActors(classname, a)
    {
        if( PlayerPawn(a) != None ) continue;
        if( PlayerPawn(a.Owner) != None ) continue;

        _ReduceSpawn(Inventory(a), percent);
    }

    ReduceSpawnsInContainers(classname, percent);
}

function bool _ReduceSpawnInContainer(Containers d, class<Inventory> classname, float percent, class<Inventory> item)
{
    local float tperc;

    if( !ClassIsChildOf(item, classname) )
        return false;

    percent *= _GetItemMult(item_reductions, item);
    tperc = rngrangeseeded(percent, min_rate_adjust, max_rate_adjust, item.name);
    if( ! chance_single(tperc) ) {
        l("_ReduceSpawnInContainer container "$ActorToString(d)$" removing "$item$", tperc: "$tperc$", percent: "$percent);
        return true;
    }
    return false;
}

function ReduceSpawnsInContainers(class<Inventory> classname, float percent)
{
    local Containers d;

    SetSeed( "ReduceSpawnsInContainers " $ classname.Name );

    foreach AllActors(class'Containers', d)
    {
        if( _ReduceSpawnInContainer(d, classname, percent, d.Content3) )
            d.Content3 = None;

        if( _ReduceSpawnInContainer(d, classname, percent, d.Content2) )
            d.Content2 = d.Content3;

        if( _ReduceSpawnInContainer(d, classname, percent, d.Contents) ) {
            d.Contents = d.Content3;
            if( d.Contents == None && !#defined(vmd) )
                    d.Contents = class'Flare';
        }
    }
}

simulated function SetMaxCopies(class<DeusExPickup> type, int percent)
{
    local #var(prefix)DeusExPickup p;
    local int maxCopies;
    local float f;

    percent = Clamp(percent, 10, 1000);

    foreach AllActors(class'#var(prefix)DeusExPickup', p) {
        if( ! p.IsA(type.name) ) continue;

        f = percent;
        f *= _GetItemMult(item_reductions, p.class);
        p.maxCopies = float(p.default.maxCopies) * f / 100.0 * 0.8;
        p.maxCopies = Clamp(p.maxCopies, 1, p.default.maxCopies*10);
        if( #defined(balance) && DeusExPlayer(p.Owner) != None && #var(prefix)FireExtinguisher(p) != None )
            p.maxCopies += DeusExPlayer(p.Owner).SkillSystem.GetSkillLevel(class'#var(prefix)SkillEnviro');

#ifdef vmd
        maxCopies = p.VMDConfigureMaxCopies();
#else
        maxCopies = p.maxCopies;
#endif

        if( p.NumCopies > maxCopies ) p.NumCopies = maxCopies;
    }
}

simulated function SetMaxAmmo(class<Ammo> type, int percent)
{
    local Ammo a;
    local int maxAmmo;
    local float f;

    percent = Clamp(percent, 10, 1000);

    foreach AllActors(class'Ammo', a) {
        if( ! a.IsA(type.name) ) continue;

        f = percent;
        f *= _GetItemMult(max_ammo, a.class);
        a.MaxAmmo = float(a.default.MaxAmmo) * f / 100.0 * 0.8;
        a.MaxAmmo = Clamp(a.MaxAmmo, 1, a.default.MaxAmmo*10);

        if( #defined(balance) && DeusExPlayer(a.Owner) != None
            && (AmmoEMPGrenade(a) != None || AmmoGasGrenade(a) != None || AmmoLAM(a) != None || AmmoNanoVirusGrenade(a) != None )
        ) {
            a.MaxAmmo += DeusExPlayer(a.Owner).SkillSystem.GetSkillLevel(class'#var(prefix)SkillDemolition');
        }

#ifdef vmd
        maxAmmo = DeusExAmmo(a).VMDConfigureMaxAmmo();
#else
        maxAmmo = a.MaxAmmo;
#endif

        if( a.AmmoAmount > maxAmmo ) a.AmmoAmount = maxAmmo;
    }
}

simulated function AddDXRCredits(CreditsWindow cw)
{
    local int i;
    local DXREnemies e;
    local class<DeusExWeapon> w;
    cw.PrintHeader( "Items" );

    PrintItemRate(cw, class'Multitool', dxr.flags.settings.multitools);
    PrintItemRate(cw, class'Lockpick', dxr.flags.settings.lockpicks);
    PrintItemRate(cw, class'BioelectricCell', dxr.flags.settings.biocells);
    PrintItemRate(cw, class'MedKit', dxr.flags.settings.medkits);

    cw.PrintLn();

    cw.PrintHeader( "Ammo: "$dxr.flags.settings.ammo$"%" );
    e = DXREnemies(dxr.FindModule(class'DXREnemies'));
    if(e != None) {
        for(i=0; i < 100; i++) {
            w = e.GetWeaponConfig(i).type;
            if( w == None ) break;
            PrintAmmoRates(cw, w);
        }
    }

    cw.PrintLn();
}

simulated function PrintAmmoRates(CreditsWindow cw, class<DeusExWeapon> w)
{
    local class<Ammo> a;
    local int i;

    a = w.default.AmmoName;
    PrintItemRate(cw, a, dxr.flags.settings.ammo, true, w.default.ItemName $ " Ammo");
    for(i=0; i<ArrayCount(w.default.AmmoNames); i++) {
        if( w.default.AmmoNames[i] != a )
            PrintItemRate(cw, w.default.AmmoNames[i], dxr.flags.settings.ammo, true, w.default.ItemName $ " Ammo");
    }
}

simulated function PrintItemRate(CreditsWindow cw, class<Inventory> c, int percent, optional bool AllowIncrease, optional string BackupName)
{
    local float tperc;
    local string ItemName;

    if( c == None ) return;
    if( c == class'DeusEx.AmmoNone' ) return;

    tperc = percent;
    tperc *= _GetItemMult(item_reductions, c);
    tperc = rngrangeseeded(tperc, min_rate_adjust, max_rate_adjust, c.name);
    if( ! AllowIncrease && tperc > 100 )
        tperc = Clamp( tperc, 0, 100 );
    else if( tperc < 0 )
        tperc = 0;

    ItemName = c.default.ItemName;
    if( ItemName == class'DeusExAmmo'.default.ItemName )
        ItemName = BackupName;
    if( Len(ItemName) == 0 )
        ItemName = string(c.Name);
    cw.PrintText( ItemName $ " : " $ FloatToString(tperc, 1) $ "%" );
}

defaultproperties
{
    bAlwaysTick=True
    min_rate_adjust=0.5
    max_rate_adjust=1.5
}

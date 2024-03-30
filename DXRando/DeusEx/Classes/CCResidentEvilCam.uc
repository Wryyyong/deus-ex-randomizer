class CCResidentEvilCam extends SecurityCamera transient;

var DeusExPlayer p;
var bool Reposition;
var float cameraMoveTimer;

function PostBeginPlay()
{
    Super.PostBeginPlay();

    Reposition = False;
}

function bool FindNewCameraPosition()
{
    local DXRMachines dxrm;
    local Vector loc,loc2;
    local Rotator rot;
    local Actor hit, aimTarget;
    local Vector HitLocation, HitNormal;
    local bool success;

    foreach AllActors(class'DXRMachines',dxrm){break;}

    if (dxrm==None){
        return false;
    }

    aimTarget = p;
    if (DeusExRootWindow(p.rootWindow).scopeView.bViewVisible){
#ifdef vanilla
        if (Human(p).aimLaser.spot[0]!=None){
            aimTarget = Human(p).aimLaser.spot[0];
        }
#endif
    }

    success = False;
    loc = aimTarget.Location;

    success = dxrm.GetLazyCameraLocation(loc,cameraRange*0.75);

    if (success){
        if (!aimTarget.FastTrace(loc)){
            success=False;
        }
    }

    if (!success){
        //Try to fall back to a position at a point somewhere behind the player
        loc2 = aimTarget.Location + Vector(aimTarget.Rotation) * (-16 * 10);
        hit = Trace(HitLocation, HitNormal, loc2, aimTarget.Location, True);
        if (hit!=None){
            loc2 = HitLocation;
        }
        loc = loc2;
    }
    rot = Rotator(aimTarget.Location - loc);
    SetLocation(loc);
    SetRotation(rot);
    DesiredRotation = rot;
    Reposition=False;
    cameraMoveTimer=0;

    return success;
}

function BindPlayer(DeusExPlayer play)
{
    p = play;
    p.ViewTarget = Self;
    FindNewCameraPosition();
}

function Tick(float deltaTime)
{
    local float ang;
    local Rotator rot;
    local DeusExPlayer curplayer;

    Super(#var(prefix)HackableDevices).Tick(deltaTime);

    if (p==None){
        return;
    }

    if (p.ViewTarget!=Self){
        Destroy(); //Self destruct
    }

    cameraMoveTimer+=deltaTime;

    curTarget = None;

    //Prevent it from going into stasis
    LastRenderTime = p.LastRendered();
    DistanceFromPlayer=0;

    playerCheckTimer += deltaTime;

    if (playerCheckTimer > 0.1)
    {
        playerCheckTimer = 0;
        CheckPlayerVisibility(p);
    }

    if (Reposition && cameraMoveTimer>1.0){ //Don't allow moves more than once a second
        //If not, find new location
        FindNewCameraPosition();
    }

    // DEUS_EX AMSD For multiplayer
    ReplicatedRotation = DesiredRotation;


}

function CheckPlayerVisibility(DeusExPlayer player)
{
    local float yaw, pitch, dist;
    local Actor hit,aimTarget;
    local Vector HitLocation, HitNormal;
    local Rotator rot;

    if (player == None)
        return;

    Reposition=True;
    dist = Abs(VSize(player.Location - Location));

    aimTarget = player;
    if (DeusExRootWindow(player.rootWindow).scopeView.bViewVisible){
#ifdef vanilla
        if (Human(player).aimLaser.spot[0]!=None){
            aimTarget = Human(player).aimLaser.spot[0];
            player.DesiredFOV = Player.Default.DefaultFOV;
        }
#endif
    }

    foreach TraceActors(class'Actor',hit,HitLocation,HitNormal,aimTarget.Location,Location)
    {
        //Immediately reposition if you're on the far side of a wall or door
        if (LevelInfo(hit)!=None || Mover(hit)!=None){
            break;
        }

        //Aim the camera at the target
        if (hit == aimTarget)
        {
            // figure out if we can see the player
            rot = Rotator(aimTarget.Location - Location);
            rot.Roll = 0;
            yaw = (Abs(Rotation.Yaw - rot.Yaw)) % 65536;
            pitch = (Abs(Rotation.Pitch - rot.Pitch)) % 65536;

            // center the angles around zero
            if (yaw > 32767)
                yaw -= 65536;
            if (pitch > 32767)
                pitch -= 65536;

            if (!((Abs(yaw) < cameraFOV) && (Abs(pitch) < cameraFOV)))
            {
                // rotate to face the player
                DesiredRotation = rot;
            }
            Reposition = False;
            break;
        }
    }

    // if the player is out of range
    if (dist > cameraRange)
    {
        Reposition = True;
    }
}

function TriggerEvent(bool bTrigger)
{
}

function Trigger(Actor Other, Pawn Instigator)
{
}

function UnTrigger(Actor Other, Pawn Instigator)
{
}

defaultproperties
{
    bHidden=true
    bCollideActors=false
    bCollideWorld=false
    bBlockActors=false
    bBlockPlayers=false
    bProjTarget=false
    CollisionHeight=1
    CollisionRadius=1
    bActive=True
    bNoAlarm=True
    bSwing=False
    bTrackPlayer=True
    bGameRelevant=True
    bAlwaysRelevant=True
    bAlwaysTick=True
    bInvincible=True
    bStasis=False
    cameraRange=750
    RotationRate=(Pitch=40000,Yaw=40000)
    AmbientSound=None
    LightType=LT_None
    LightBrightness=0
    LightHue=0
    LightSaturation=0
    LightRadius=0
}

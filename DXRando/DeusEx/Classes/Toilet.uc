#ifdef injections
class Toilet injects Toilet;
#else
class DXRToilet extends #var(prefix)Toilet;
#endif

function Frob(actor Frobber, Inventory frobWith)
{
	local #var(PlayerPawn) player;
    local DXRando      dxr;

	Super.Frob(Frobber, frobWith);

	player = #var(PlayerPawn)(Frobber);
	if (player != None && player.bOnFire)
	{
		player.ClientMessage("Splish Splash!",, true);
		player.ExtinguishFire();

        foreach AllActors(class'DXRando', dxr) {
            if (SkinColor==SC_Clean){
                class'DXREvents'.static.ExtinguishFire(dxr,"clean toilet",player);
            } else {
                class'DXREvents'.static.ExtinguishFire(dxr,"filthy toilet",player);
            }
            break;
        }
	}
}

defaultproperties
{
}

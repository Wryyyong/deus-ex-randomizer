class DXRPiano injects #var(prefix)WHPiano;

function Frob(actor Frobber, Inventory frobWith)
{
    local int rnd;
    local float duration;
    local Sound SelectedSound;

    Super(WashingtonDecoration).Frob(Frobber, frobWith);

#ifdef hx
    if ( NextUseTime>Level.TimeSeconds || IsInState('Conversation') || IsInState('FirstPersonConversation') )
        return;
#else
    if (bUsing)
        return;
#endif

    rnd = Rand(9); //make sure this matches the number of sounds below
    switch(rnd){
        case 0:
            //DX Theme, Correct
            SelectedSound = sound'Piano1';
            duration = 1.5;
            break;
        case 1:
            //Random Key Mashing, DX Vanilla
            SelectedSound = sound'Piano2';
            duration = 1.5;
            break;
        case 2:
            //Max Payne Piano, Slow, Learning
            SelectedSound = sound'MaxPaynePianoSlow';
            duration = 8;
            break;
        case 3:
            //Max Payne Piano, Fast
            SelectedSound = sound'MaxPaynePianoFast';
            duration = 4;
            break;
        case 4:
            //Megalovania
            SelectedSound = sound'Megalovania';
            duration = 3;
            break;
        case 5:
            //Song of Storms
            SelectedSound = sound'SongOfStorms';
            duration = 4;
            break;
        case 6:
            // The six arrive, the fire lights their eyes
            SelectedSound = sound'T7GPianoBad';
            duration = 6;
            break;
        case 7:
            // invited here to learn to play.... THE GAME
            SelectedSound = sound'T7GPianoGood';
            duration = 7;
            break;
        case 8:
            // You fight like a dairy farmer!
            SelectedSound = sound'MonkeyIsland';
            duration = 5;
            break;
        default:
            log("DXRPiano went too far this time!  Got "$rnd);
            return;
    }

    if(SelectedSound == None) {
        log("DXRPiano got an invalid sound!  Got "$rnd);
        return;
    }

    PlaySound(SelectedSound, SLOT_Misc,10.0,, 256);
    duration += 0.5;

#ifdef hx
    NextUseTime = Level.TimeSeconds + duration;
#else
    bUsing = True;
    SetTimer(duration, False);
#endif
}

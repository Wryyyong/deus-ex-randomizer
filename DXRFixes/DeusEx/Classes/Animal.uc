class DXRAnimal merges Animal;
// TODO: we can change this to injects but it breaks savegame compatibility

function float ModifyDamage(int Damage, Pawn instigatedBy, Vector hitLocation,
                            Vector offset, Name damageType)
{
    return Super(ScriptedPawn).ModifyDamage(Damage, instigatedBy, hitLocation, offset, damageType);
}

function PlayDying(name damageType, vector hitLoc)
{
    Super(FixScriptedPawn).PlayDying(damageType, hitLoc);
}

class TrashCanCommon extends DXRBase;

static function DestroyTrashCan(Containers trashcan, class<Containers> trashBagType)
{
	local Vector loc;
	local Rat vermin;
    local Containers trashbag;
    local float scale, scaleCorrection;

    // maybe spawn a trashbag
    if (FRand() < 0.8)
    {
        // less likely maybe spawn some trashpaper (50% chance of at least one)
        generateTrash(trashcan, 0.16);

        loc = trashcan.Location;
        trashbag = trashcan.Spawn(trashBagType,,, loc);

		scale = 1.0;
        // trashbags that are too big look weird when dropped, but ones whose
        // default radius is smaller are fine, at least with vanilla ratios
		if (trashbag.default.CollisionRadius > trashcan.default.CollisionRadius)
		{
            // get the proportional difference in their default radii
			scaleCorrection = 1.0 - (trashcan.default.CollisionRadius / trashbag.default.CollisionRadius);
            // square the difference so that larger differences have a reatively larger effect, then reduce it a bit
			scaleCorrection = 0.875 * scaleCorrection * scaleCorrection;
            // subtract the reduced difference from the starting scale
			scale -= scaleCorrection;
		}
        // scale the trashbag scale by how much the trashcan has been scaled
		scale *= trashcan.CollisionRadius / trashcan.default.CollisionRadius;

        // scale the trashbag by the final scale value
		trashbag.SetCollisionSize(trashbag.CollisionRadius * scale, trashbag.CollisionHeight * scale);
        trashbag.drawScale *= scale;
    }
    else
    {
        // more likely maybe spawn some trashpaper (94% chance of at least one)
        generateTrash(trashcan, 0.5);
    }

    // maybe spawn a rat, but not if underwater
    if (!trashcan.Region.Zone.bWaterZone && FRand() < 0.5)
    {
        loc = trashcan.Location;
        loc.Z -= trashcan.CollisionHeight;
        vermin = trashcan.Spawn(class'Rat',,, loc);
        if (vermin != None)
            vermin.bTransient = true;
    }
}

static function generateTrash(Containers trashcan, float probability)
{
	local Vector loc;
    local int i;
	local TrashPaper trash;

    // trace down to see if we are sitting on the ground
	loc = vect(0,0,0);
	loc.Z -= trashcan.CollisionHeight + 8.0;
	loc += trashcan.Location;

	// only generate trashpaper if we're on the ground
	if (!trashcan.FastTrace(loc))
	{
		for (i=0; i<4; i++)
		{
			if (FRand() < probability)
			{
				loc = trashcan.Location;
				loc.X += (trashcan.CollisionRadius / 2) - FRand() * trashcan.CollisionRadius;
				loc.Y += (trashcan.CollisionRadius / 2) - FRand() * trashcan.CollisionRadius;
				loc.Z += (trashcan.CollisionHeight / 2) - FRand() * trashcan.CollisionHeight;
				trash = trashcan.Spawn(class'TrashPaper',,, loc);
				if (trash != None)
				{
					trash.SetPhysics(PHYS_Rolling);
					trash.rot = RotRand(True);
					trash.rot.Yaw = 0;
					trash.dir = VRand() * 20 + vect(20,20,0);
					trash.dir.Z = 0;
				}
			}
		}
	}
}

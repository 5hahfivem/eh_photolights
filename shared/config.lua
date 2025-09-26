return {
	DROP_LIFETIME = 15,
	MAX_DISTANCE = 50.0,
	GIVEBACK_ON_DESPAWN = true, -- if true, give the item back to owner when despawned for distance timeout
	MAX_DROPS_PER_PLAYER = 5, -- maximum active drops per player
	DISTANCE_TIMEOUT_MINUTES = 15, -- minutes out of range before despawn
	ITEMS = {
		{
			name = 'photolights',
			model = `sf_prop_sf_lamp_studio_01a`,
			label = 'Studio Lamp'
		},
		{
			name = 'tripodlight',
			model = `tr_prop_tr_tripod_lamp_01a`,
			label = 'Tripod Lamp'
		}
	}
}
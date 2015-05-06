# You Make the Dungeon

## Building on command line
```
mxmlc -source-path+=lib/starling/src -incremental=true -static-link-runtime-shared-libraries=true src/Main.as -output Main.swf
```

## In-Game Commands
m - toggle mute
w/a/s/d - move camera

## Floor Data

Floor data text files are tab-delineated, with the following structure:
```
FloorName
FloorXDimension	FloorYDimension
CharInitialX	CharInitialY
TileType	x	y	nOpen?	sOpen?	eOpen?	wOpen?	AdditionalParams...
...
...
```

Percent chance of drawing each tile (per floor) is tab-delineated, with the following structure:
```
TileType	percentChance
...
...
```

### Tile Types and Additional Parameters
* entry
* exit
* empty
* health - health restored (int)
* enemy - name (string), level (int), HP (int), attack (int), XP on kill (int)
* objective - name (string), names of prerequsite objectives... (strings)
* none

// Floor.as
// Stores the state of a single floor.

package {
	import starling.core.Starling;
	import starling.display.Sprite;
	import flash.net.*;
	import flash.utils.*;
	import starling.events.*;
	import starling.textures.*;

	import Character;
	import tiles.*;
	import Util;

	public class Floor extends Sprite {
		// Number of lines at the beginning of floordata files that are
		// dedicated to non-tile objects at the start.
		public static const NON_TILE_LINES:int = 3;

		// 2D Array of Tiles. Represents the current state of all tiles.
		public var grid:Array;
		public var char:Character;
		public var floorName:String;

		private var initialGrid:Array;
		private var initialXp:int;

		private var gridHeight:int;
		private var gridWidth:int;

		// Character's initial grid coordinates.
		private var initialX:int;
		private var initialY:int;

		private var tileTextures:Dictionary;

		// grid: The initial layout of the floor.
		// xp: The initial XP of the character.
		public function Floor(floorData:ByteArray,
							  textureDict:Dictionary,
							  xp:int) {
			super();
			initialXp = xp;
			tileTextures = textureDict;
			parseFloorData(floorData);
			resetFloor();
		}

		// Resets the character and grid state to their initial values.
		private function resetFloor():void {
			var i:int; var j:int;

			if (grid) {
				// Remove all tiles from the display tree.
				for (i = 0; i < grid.length; i++) {
					for (j = 0; j < grid[i].length; j++) {
						// TODO: figure out it it is necessary to dispose of the
						// tile here.
						if (grid[i][j]) {
							grid[i][j].removeFromParent();
						}
					}
				}
			}

			// Replace the current grid with a fresh one.
			grid = initializeGrid(gridWidth, gridHeight);

			// Add all of the initial tiles to the grid and display tree.
			for (i = 0; i < initialGrid.length; i++) {
				for (j = 0; j < initialGrid[i].length; j++) {
					grid[i][j] = initialGrid[i][j];
					if(grid[i][j]) {
						var t:Tile = grid[i][j];
						addChild(t);
					}
				}
			}

			// Remove the character from the display tree.
			if (char) {
				char.removeFromParent();
			}
			char = new Character(initialX, initialY, initialXp);
		}

		// Returns a 2D array with the given dimensions.
		private function initializeGrid(x:int, y:int):Array {
			var arr:Array = new Array(x);
			for (var i:int = 0; i < x; i++) {
				arr[i] = new Array(y);
			}
			return arr;
		}

		private function parseFloorData(floorDataBytes:ByteArray):void {
			// TODO: ensure loaded file always has correct number of lines
			//		 as well as all necessary data (char, entry, exit).
			// TODO: ensure that each line in loaded file has correct number
			//		 of arguments.
			var i:int; var j:int;

			var floorDataString:String =
				floorDataBytes.readUTFBytes(floorDataBytes.length);

			// Parse the floor name.
			var floorData:Array = floorDataString.split("\n");
			floorName = floorData[0];

			// Parse the floor dimensions and initialize the grid array.
			var floorSize:Array = floorData[1].split("\t");
			gridWidth = Number(floorSize[0]);
			gridHeight = Number(floorSize[1]);
			initialGrid = initializeGrid(gridWidth, gridHeight);

			// Parse the character's starting position.
			var characterData:Array = floorData[2].split("\t");
			initialX = Number(characterData[0]);
			initialY = Number(characterData[1]);
			char = new Character(initialX, initialY, initialXp);

			// Parse all of the tiles.
			var lineData:Array;
			var initTile:Tile;
			var tX:int; var tY:int;
			var tN:Boolean; var tS:Boolean; var tE:Boolean; var tW:Boolean;
			var textureString:String;
			var tTexture:Texture;
			var tileData:Array = new Array();

			for (i = NON_TILE_LINES; i < floorData.length; i++) {
				if (floorData[i].length == 0) {
					continue;
				}

				lineData = floorData[i].split("\t");

				tX = Number(lineData[1]);
				tY = Number(lineData[2]);

				// Build the String referring to the texture.
				tN = (lineData[3] == "1") ? true : false;
				tS = (lineData[4] == "1") ? true : false;
				tE = (lineData[5] == "1") ? true : false;
				tW = (lineData[6] == "1") ? true : false;
				textureString = "tile_" + (tN ? "n" : "") + (tS ? "s" : "") + (tE ? "e" : "") + (tW ? "w" : "");
				textureString += (!tN && !tS && !tE && !tW) ? "none" : "";
				tTexture = tileTextures[textureString];
				trace("Building tile with string " + textureString);

				// TODO: determine type of Tile to instantiate here
				// 		 and add it to tileData
				initTile = new Tile(tX, tY, tN, tS, tE, tW, tTexture);
				tileData.push(initTile);
			}

			// put tileData's tiles into a grid
			for each (var tile:Tile in tileData) {
				initialGrid[tile.grid_x][tile.grid_y] = tile;
			}
		}
	}
}
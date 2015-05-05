// Tile.as
// Base class for empty tiles. Special tiles will extend this class.
package tiles {
	import starling.core.Starling;
	import starling.display.*;
	import starling.textures.*;

	import Util;

	public class Tile extends Sprite {
		public var grid_x:int;
		public var grid_y:int;
		public var north:Boolean;
		public var south:Boolean;
		public var east:Boolean;
		public var west:Boolean;

		public var image:Image;

		// Create a new Tile object at position (g_x,g_y) of the grid.
		// If n, s, e, or w is true, that edge of the tile will be passable.
		// texture will be the image used for this tile.
		public function Tile(g_x:int,
							 g_y:int,
							 n:Boolean,
							 s:Boolean,
							 e:Boolean,
							 w:Boolean,
							 texture:Texture) {
			super();
			grid_x = g_x;
			grid_y = g_y;
			north = n;
			south = s;
			east = e;
			west = w;

			image = new Image(texture);
			addChild(image);

			x = Util.grid_to_real(g_x);
			y = Util.grid_to_real(g_y);

			addEventListener(TileEvent.CHAR_ENTRY, onCharEnteredEvent);
		}

		// Called when the player moves into this tile. Override this function
		// to define interactions between tiles and characters.
		public function handleChar(c:Character):void {
			return;
		}

		// Helper for capturing character entry events. Only calls handleChar
		// if this is the right tile.
		private function onCharEnteredEvent(e:TileEvent):void {
			if (e.grid_x == grid_x && e.grid_y == grid_y) {
				handleChar(e.char);
			}
		}
	}
}
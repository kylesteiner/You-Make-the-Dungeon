package tiles {
	import starling.display.Image;
	import starling.utils.Color;
	import starling.textures.Texture;	
	import starling.text.TextField;

	public class HealingTile extends Tile {
		public var health:int;   // How much health is restored.
		public var used:Boolean; // Whether the character has used the tile.

		private var healthImage:Image;

		public function HealingTile(g_x:int,
									g_y:int,
									n:Boolean,
									s:Boolean,
									e:Boolean,
									w:Boolean,
									backgroundTexture:Texture,
									healthTexture:Texture,
									health:int) {
			super(g_x, g_y, n, s, e, w, backgroundTexture);
			healthImage = new Image(healthTexture);
			addChild(healthImage);

			this.health = health;
			this.used = false;
		}

		override public function handleChar(c:Character):void {
			if (used || c.hp == c.maxHp) {
				dispatchEvent(new TileEvent(TileEvent.CHAR_HANDLED,
											Util.real_to_grid(x),
											Util.real_to_grid(y),
											c));
				return;
			}
			used = true;
			removeChild(healthImage);
			c.hp += health;
			if (c.hp > c.maxHp) {
				c.hp = c.maxHp;
			}
			dispatchEvent(new TileEvent(TileEvent.CHAR_HANDLED,
										Util.real_to_grid(x),
										Util.real_to_grid(y),
										c));
		}

		override public function reset():void {
			addChild(healthImage);
			used = false;
		}
		
		override public function displayInformation():void {
				//var
				text = new TextField(100, 100, "Healing Tile\n Gives back " + health + " health", "Bebas", 12, Color.BLACK);
				text.border = true;
				text.x = getToPoint();
				text.y = 0;
				addChild(text);
				text.visible = false;
		}
	}
}

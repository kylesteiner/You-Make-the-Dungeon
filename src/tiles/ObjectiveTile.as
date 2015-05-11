package tiles {
    import starling.display.Image;
    import starling.text.TextField;
    import starling.textures.Texture;
    import starling.utils.Color;

    import ai.ObjectiveState;

    public class ObjectiveTile extends Tile {
        public var state:ObjectiveState;
        public var objImage:Image;

        public function ObjectiveTile(g_x:int,
                                      g_y:int,
                                      n:Boolean,
         							  s:Boolean,
         							  e:Boolean,
         							  w:Boolean,
         							  background:Texture,
                                      foreground:Texture,
                                      objKey:String,
                                      prereqs:Array) {
            super(g_x, g_y, n, s, e, w, background);
            objImage = new Image(foreground);
            addChild(objImage);

            state = new ObjectiveState(objKey, prereqs);
        }

        // Should not be called unless all prerequisite objectives are completed.
        override public function handleChar(c:Character):void {
            removeChild(objImage, true);
            dispatchEvent(new TileEvent(TileEvent.OBJ_COMPLETED, grid_x, grid_y, c));
            dispatchEvent(new TileEvent(TileEvent.CHAR_HANDLED,
                                        Util.real_to_grid(x),
                                        Util.real_to_grid(y),
                                        c));
        }

        override public function reset():void {
            addChild(objImage);
        }

		override public function displayInformation():void {
			setUpInfo("Objective Tile\n");
		}
    }
}

package tiles {
    import starling.events.Event;

    public class TileEvent extends Event {
        public static const CHAR_ENTRY:String = "char_entry";

        public var grid_x:int;
        public var grid_y:int;
        public var char:Character;

        // Creates a new TileEvent, to be passed to a Tile.
        // type must be one of the String constants defined in this file.
        // (x,y) is the grid position of the tile to be notified.
        // c is a reference to the character.
        public function TileEvent(type:String,
                                  x:int,
                                  y:int,
                                  c:Character,
                                  bubbles:Boolean=false) {
            super(type, bubbles);
            grid_x = x;
            grid_y = y;
            char = c;
        }
    }
}
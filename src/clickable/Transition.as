package clickable {
	import starling.display.DisplayObject;
	import starling.events.Touch;
	import starling.events.TouchEvent;
	import starling.textures.Texture;

	public class Transition extends Clickable {
		private var floor:String;
		private var initialHealth:int;
		private var initialAttack:int;
		private var initialStamina:int;
		private var initialAttack:int;
		private var initialLoS:int;

		public function Transition(xPos:int,
                                   yPos:int,
                                   onClick:Function,
                                   baseDisplay:DisplayObject,
                                   baseTexture:Texture,
								   floor:String,
								   initialHealth:int,
								   initialAttack:int,
								   initialStamina:int,
								   initialAttack:int,
								   initialLoS:int) {
			super(xPos, yPos, onClick, baseDisplay, baseTexture);
			this.floor = floor;
			this.initialHealth = initialHealth;
			this.initialAttack = initialAttack;
			this.initialStamina = initialStamina;
			this.initialAttack = initialAttack;
			this.initialLoS = initialLoS;
		}

		override public function callCallback():void {
            onClick(floor, initialHealth, initialStamina, initialAttack, initialLoS);
		}
	}
}

package {
	import flash.net.SharedObject;
	import flash.ui.Keyboard;
	import flash.utils.ByteArray;
	import flash.utils.Dictionary;

	import starling.display.Image;
	import starling.display.MovieClip;
	import starling.display.Sprite;
	import starling.display.Quad;
	import starling.events.*;
	import starling.text.TextField;
	import starling.textures.Texture;
	import starling.utils.Color;
	import starling.utils.HAlign;

	import entities.*;
	import tiles.*;

	public class Game extends Sprite {
		public static const FLOOR_FAIL_TEXT:String =
				"Nea was defeated!\nClick here to continue building.";
		public static const LEVEL_UP_TEXT:String =
				"Nea levelled up!\nHealth fully restored!\n+{0} max health\n+{1} attack\nClick to dismiss";

		public static const PHASE_BANNER_DURATION:Number = 0.75; // seconds
		public static const PHASE_BANNER_THRESHOLD:Number = 0.05;
		public static const TILE_UNLOCK_THRESHOLD:Number = 0.05;

		public static const DEFAULT_CAMERA_ACCEL:int = 1;
		public static const MAX_CAMERA_ACCEL:int = 3;

		public static const STATE_BUILD:String = "game_build";
		public static const STATE_RUN:String = "game_run";
		public static const STATE_COMBAT:String = "game_combat";
		public static const STATE_POPUP:String = "game_popup";
		public static const STATE_TUTORIAL:String = "game_tutorial";
		public static const STATE_SUMMARY:String = "game_summary";
		public static const STATE_CINEMATIC:String = "game_cinematic";

		private var shopButton:Clickable;
		private var runButton:Clickable;
		private var endButton:Clickable;
		private var combatSpeedButton:Clickable;
		private var runSpeedButton:Clickable;
		private var helpButton:Sprite;
		private var helpImageSprite:Sprite;
		private var helpImage:Image;

		private var bgmMuteButton:Clickable;
		private var sfxMuteButton:Clickable;

		private var cursorHighlight:Image;

		private var world:Sprite;
		private var currentFloor:Floor;

		private var numberOfTilesPlaced:int;
		private var entitiesPlaced:int;
		private var goldSpent:int;

		private var currentCombat:CombatHUD;
		private var combatSkip:Boolean;
		private var runPhaseSpeed:Boolean;
		private var runHud:RunHUD;
		private var goldHud:GoldHUD;
		private var shopHud:ShopHUD;
		private var buildHud:BuildHUD;
		private var showBuildHudImage:Boolean;
		private var runSummary:Summary;
		private var tileUnlockPopup:Clickable;
		private var tutorialHud:TutorialHUD;
		private var cinematic:Cinematic;

		private var gameState:String;
		private var gold:int;

		private var phaseBanner:Image;
		private var phaseBannerTimer:Number;

		private var tileUnlockTimer:Number;

		private var cameraAccel:Number;
		// Key -> Boolean representing which keys are being held down
		private var pressedKeys:Dictionary;

		// for action 21, logging hover info help
		private var helping:Boolean;
		private var timeHovered:Number;

		private var saveGame:SharedObject;

		public function Game(fromSave:Boolean,
							 sfxMuteButton:Clickable,
							 bgmMuteButton:Clickable) {
			super();
			saveGame = SharedObject.getLocal("saveGame");
			this.sfxMuteButton = sfxMuteButton;
			this.bgmMuteButton = bgmMuteButton;

			// Log variables
			numberOfTilesPlaced = 0;
			timeHovered = 0;

			cameraAccel = DEFAULT_CAMERA_ACCEL;
			pressedKeys = new Dictionary();

			gameState = fromSave ? STATE_BUILD : STATE_TUTORIAL;
			gold = fromSave ? saveGame.data["gold"] : Util.STARTING_GOLD;
			Util.speed = Util.SPEED_SLOW;
			combatSkip = false;

			initializeWorld(fromSave);
			initializeUI();

			addChild(world);
			addChild(sfxMuteButton);
			addChild(bgmMuteButton);
			addChild(combatSpeedButton);
			addChild(runSpeedButton);
			addChild(runButton);
			addChild(goldHud);
			addChild(shopButton);
			addChild(helpButton);
			addChild(buildHud);
			if (gameState == STATE_TUTORIAL) {
				addChild(tutorialHud);
			}

			// Update build hud with unlocks if loading from save.
			if (fromSave) {
				if (saveGame.data["unlocks"]) {
					for (var i:int = 0; i < saveGame.data["unlocks"].length; i++) {
						buildHud.entityFactory.unlockTile(saveGame.data["unlocks"][i]);
					}
					buildHud.updateHUD();
				}
			}

			centerWorldOnCharacter();

			Util.logger.logLevelStart(1, {
				"characterHP": currentFloor.char.maxHp,
				"characterStamina": currentFloor.char.maxStamina,
				"characterAttack": currentFloor.char.attack
			});

			Assets.mixer.play(Util.FLOOR_BEGIN);

			// Game loop event.
			addEventListener(EnterFrameEvent.ENTER_FRAME, onFrameBegin);

			// Input events.
			addEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);
			addEventListener(KeyboardEvent.KEY_UP, onKeyUp);
			addEventListener(TouchEvent.TOUCH, onMouseEvent);

			// Combat animation events.
			addEventListener(AnimationEvent.CHAR_DIED, onCombatFailure);
			addEventListener(AnimationEvent.ENEMY_DIED, onCombatSuccess);

			// Game events.
			addEventListener(GameEvent.BUILD_HUD_IMAGE_CHANGE, clearBuildHUDImage);
			addEventListener(GameEvent.COMPLETE_ROOM, onRoomComplete);
			addEventListener(GameEvent.CHARACTER_LOS_CHANGE, onLosChange);
			addEventListener(GameEvent.ENTERED_COMBAT, startCombat);
			addEventListener(GameEvent.GAIN_GOLD, onGainGold);
			addEventListener(GameEvent.STAMINA_EXPENDED, onStaminaExpended);
			addEventListener(GameEvent.UNLOCK_TILE, onTileUnlock);

			// Tutorial-specific game events.
			addEventListener(GameEvent.TUTORIAL_COMPLETE, onTutorialComplete);
			addEventListener(GameEvent.MOVE_CAMERA, onMoveCamera);
			addEventListener(GameEvent.CINEMATIC_COMPLETE, onCinematicComplete);
		}

		private function initializeWorld(fromSave:Boolean):void {
			world = new Sprite();

			cursorHighlight = new Image(Assets.textures[Util.TILE_HL_B]);
			cursorHighlight.touchable = false;

			runSummary = new Summary(40, 40, returnToBuild, null, Assets.textures[Util.SHOP_BACKGROUND]);

			var health:int = fromSave ? saveGame["hp"] : Util.STARTING_HEALTH;
			var stamina:int = fromSave ? saveGame["stamina"] : Util.STARTING_STAMINA;
			var attack:int = fromSave ? saveGame["attack"] : Util.STARTING_ATTACK;
			var los:int = fromSave ? saveGame["los"] : Util.STARTING_LOS;

			currentFloor = new Floor(Assets.floors[Util.MAIN_FLOOR],
									 health,
									 stamina,
									 attack,
									 los,
									 returnToMenu,
									 runSummary);

			world.addChild(cursorHighlight);
			world.addChild(currentFloor);
		}

		private function initializeUI():void {
			combatSpeedButton = new Clickable(0, 0, toggleCombatSpeed, null, Assets.textures[Util.ICON_SLOW_COMBAT]);
			combatSpeedButton.x = bgmMuteButton.x - combatSpeedButton.width - Util.UI_PADDING;
			combatSpeedButton.y = Util.STAGE_HEIGHT - combatSpeedButton.height - Util.UI_PADDING;
			runSpeedButton = new Clickable(0, 0, toggleRunSpeed, null, Assets.textures[Util.ICON_SLOW_RUN]);
			runSpeedButton.x = combatSpeedButton.x - runSpeedButton.width - Util.UI_PADDING;
			runSpeedButton.y = combatSpeedButton.y;

			helpImageSprite = new Sprite();
			helpImageSprite.x = -6;
			helpImageSprite.y = -48;
			var helpQuad:Quad = new Quad(Util.STAGE_WIDTH*2, Util.STAGE_HEIGHT*2, Color.WHITE);
			helpQuad.alpha = 0.7;
			helpImageSprite.addChild(helpQuad);
			helpButton = new Sprite();
			var helpButtonQuad:Quad = new Quad(32, 32, Color.WHITE);
			helpButtonQuad.alpha = 0;
			helpButton.addChild(helpButtonQuad);
			var helpButtonImage:Image = new Image(Assets.textures[Util.ICON_HELP]);
			helpButton.addChild(helpButtonImage);
			helpButton.x = runSpeedButton.x - helpButton.width - Util.UI_PADDING;
			helpButton.y = runSpeedButton.y;

			goldHud = new GoldHUD(gold);
			goldHud.x = Util.STAGE_WIDTH - goldHud.width;
			goldHud.y = Util.UI_PADDING;

			runButton = new Clickable(3 *  Util.PIXELS_PER_TILE,
									  Util.STAGE_HEIGHT - Util.PIXELS_PER_TILE,
									  runFloor,
									  null,
									  Assets.textures[Util.ICON_RUN]);
			runButton.x = goldHud.x - runButton.width - Util.UI_PADDING;
			runButton.y = Util.UI_PADDING;

			shopHud = new ShopHUD(goldHud, closeShopHUD);
			shopButton = new Clickable(goldHud.x, goldHud.height, openShopHUD, null, Assets.textures[Util.ICON_SHOP]);
			shopButton.x = runButton.x - shopButton.width - Util.UI_PADDING
			shopButton.y = Util.UI_PADDING;

			endButton = new Clickable(3 *  Util.PIXELS_PER_TILE,
									  Util.STAGE_HEIGHT - Util.PIXELS_PER_TILE,
									  endRunButton,
									  null,
									  Assets.textures[Util.ICON_END]);
			endButton.x = runButton.x;
			endButton.y = runButton.y;

			runHud = new RunHUD(); // textures not needed for now but maybe in future
			buildHud = new BuildHUD();
			tutorialHud = new TutorialHUD();
		}

		private function returnToMenu():void {
			dispatchEvent(new MenuEvent(MenuEvent.EXIT));
		}

		private function startCombat(e:GameEvent):void {
			currentCombat = new CombatHUD(currentFloor.char,
										  currentFloor.entityGrid[e.x][e.y],
										  combatSkip);
			addChild(currentCombat);
		}

		private function onCombatSuccess(event:AnimationEvent):void {
			removeChild(currentCombat);
			currentFloor.onCombatSuccess(event.enemy);
			gold += event.enemy.reward;
			runSummary.goldCollected += event.enemy.reward;
			goldHud.update(gold);
		}

		private function onCombatFailure(event:AnimationEvent):void {
			removeChild(currentCombat);

			Util.logger.logAction(4, {
				"characterAttack":event.character.attack,
				"enemyAttack":event.enemy.attack,
				"enemyHealthLeft":event.enemy.hp
			});

			endRun();
		}

		public function openShopHUD():void {
			if (gameState == STATE_TUTORIAL || gameState == STATE_CINEMATIC) {
				return;
			}

			if (getChildIndex(shopHud) == -1) {
				Util.logger.logAction(13, { } );
				shopHud.update(currentFloor.char, gold);
				addChild(shopHud);
				buildHud.deselect();
			}
		}

		public function closeShopHUD():void {
			if (getChildIndex(shopHud) != -1) {
				goldSpent += gold - shopHud.gold;
				gold = shopHud.gold;
				removeChild(shopHud);
			}
		}

		public function constructPhaseBanner(run:Boolean = true):void {
			removeChild(phaseBanner);
			phaseBanner = new Image(Assets.textures[run ? Util.RUN_BANNER : Util.BUILD_BANNER]);
			phaseBanner.y = (Util.STAGE_HEIGHT - phaseBanner.height) / 2;
			phaseBannerTimer = 0;
			addChild(phaseBanner);
		}

		public function runFloor():void {
			if (gameState == STATE_TUTORIAL || gameState == STATE_CINEMATIC) {
				return;
			}

			Util.logger.logAction(3, {
				"numberOfTiles":numberOfTilesPlaced,
				"numberOfEntitiesPlaced":entitiesPlaced,
				"goldSpent":goldSpent
			});

			goldSpent = 0;
			numberOfTilesPlaced = 0;
			entitiesPlaced = 0;

			currentFloor.clearHighlightedLocations();
			buildHud.deselect();

			removeChild(runButton);
			removeChild(buildHud.currentImage);
			removeChild(buildHud);
			removeChild(shopHud);
			removeChild(shopButton);

			addChild(endButton);
			addChild(runHud);
			gameState = STATE_RUN;

			runHud.startRun();
			currentFloor.toggleRun(gameState);
			constructPhaseBanner();
		}

		public function onStaminaExpended(event:GameEvent):void {
			endRun();
		}

		private function onRoomComplete(event:GameEvent):void {
			if(!event.gameData["completed"]) {
				return;
			}
		}

		public function endRun():void {
			var reason:String;
			if (currentFloor.char.stamina <= 0) {
				reason = "staminaExpended";
			} else if (currentFloor.char.hp <= 0) {
				reason = "healthExpended";
			} else {
				reason = "endRunButton";
			}
			Util.logger.logAction(8, {
				"goldEarned":runSummary.goldCollected,
				"staminaLeft": currentFloor.char.stamina,
				"healthLeft": currentFloor.char.hp,
				"tilesVisited": runSummary.distanceTraveled,
				"enemiesDefeated":runSummary.enemiesDefeated,
				"damageTaken":runSummary.damageTaken,
				"reason":reason
			});

			removeChild(endButton);
			removeChild(runHud);
			removeChild(tileUnlockPopup);

			gameState = STATE_SUMMARY;
			addChild(runSummary);
			currentFloor.toggleRun(STATE_BUILD);
		}

		public function endRunButton():void {
			if(currentFloor && !currentFloor.completed && gameState == STATE_RUN) {
				endRun();
			}
		}

		public function returnToBuild():void {
			removeChild(runSummary);
			runSummary.reset();

			saveGame.clear();
			saveGame.data["gold"] = gold;
			saveGame.data["unlocks"] = new Array();
			for (var unlock:String in buildHud.entityFactory.entitySet) {
				saveGame.data["unlocks"].push(unlock);
			}
			saveGame.flush();

			addChild(runButton);

			buildHud.updateUI();
			addChild(buildHud);
			addChild(shopButton);

			gameState = STATE_BUILD;
			currentFloor.resetFloor();
			centerWorldOnCharacter();
			constructPhaseBanner(false); // happens after the summary dialog box
		}

		private function centerWorldOnCharacter(exact:Boolean = false):void {
			// Set exact to simulate camera snapping
			// Only really useful for ensuring that the top-left is well-centered
			// Parameter becomes completely useless with sliding instead of snapping pan

			var charWidth:int = currentFloor == null ? 0 : currentFloor.char == null ? 0 : currentFloor.char.width;
			var charX:int = currentFloor == null ? 0 : currentFloor.char == null ? 0 : currentFloor.char.x;
			if(exact) {
				charX = Util.grid_to_real(Util.real_to_grid(charX));
			}
			world.x = Util.STAGE_WIDTH / 2 - charX - Util.PIXELS_PER_TILE;

			var charHeight:int = currentFloor == null ? 0 : currentFloor.char == null ? 0 : currentFloor.char.height;
			var charY:int = currentFloor == null ? 0 : currentFloor.char == null ? 0 : currentFloor.char.y;
			if(exact) {
				charY = Util.grid_to_real(Util.real_to_grid(charY));
			}
			world.y = Util.STAGE_HEIGHT / 2 - charY - (Util.PIXELS_PER_TILE * 3.0 / 4);
		}

		private function onFrameBegin(event:EnterFrameEvent):void {
			if (helping) {
				timeHovered += event.passedTime;
			}

			cameraAccel += event.passedTime;
			if(cameraAccel > MAX_CAMERA_ACCEL) {
				cameraAccel = MAX_CAMERA_ACCEL;
			}

			var worldShift:int = Util.CAMERA_SHIFT * cameraAccel;
			if(pressedKeys[Keyboard.DOWN] || pressedKeys[Util.DOWN_KEY]) {
				world.y -= worldShift;

				if (world.y < -1 * Util.PIXELS_PER_TILE * (currentFloor.gridHeight - 1)) {
					world.y = -1 * Util.PIXELS_PER_TILE * (currentFloor.gridHeight - 1);
				}
			}

			if(pressedKeys[Keyboard.UP] || pressedKeys[Util.UP_KEY]) {
				world.y += worldShift;

				if (world.y > Util.PIXELS_PER_TILE * -1 + Util.STAGE_HEIGHT) {
					world.y = Util.PIXELS_PER_TILE * -1 + Util.STAGE_HEIGHT;
				}
			}

			if(pressedKeys[Keyboard.RIGHT] || pressedKeys[Util.RIGHT_KEY]) {
				world.x -= worldShift;

				if (world.x < -1 * Util.PIXELS_PER_TILE * (currentFloor.gridWidth - 1)) {
					world.x = -1 * Util.PIXELS_PER_TILE * (currentFloor.gridWidth - 1);
				}
			}

			if(pressedKeys[Keyboard.LEFT] || pressedKeys[Util.LEFT_KEY]) {
				world.x += worldShift;

				if (world.x > Util.PIXELS_PER_TILE * -1 + Util.STAGE_WIDTH) {
					world.x = Util.PIXELS_PER_TILE * -1 + Util.STAGE_WIDTH;
				}
			}

			if(phaseBanner) {
				phaseBannerTimer += event.passedTime;
				addChild(phaseBanner);
				if(phaseBannerTimer > PHASE_BANNER_DURATION) {
					removeChild(phaseBanner);
					phaseBanner = null;
				}
			}

			if(tileUnlockPopup) {
				tileUnlockTimer += event.passedTime;
			}

			removeChild(buildHud.currentImage);
			if(gameState == STATE_BUILD && buildHud && buildHud.hasSelected() && showBuildHudImage) {
				addChild(buildHud.currentImage);
			}

			if(gameState == STATE_RUN && runHud && currentFloor) {
				runHud.update(currentFloor.char);
				centerWorldOnCharacter();
			}
		}

		private function onMouseEvent(event:TouchEvent):void {
			var touch:Touch = event.getTouch(this);
			if(!touch) {
				return;
			}

			var xOffset:int = touch.globalX < world.x ? Util.PIXELS_PER_TILE : 0;
			var yOffset:int = touch.globalY < world.y ? Util.PIXELS_PER_TILE : 0;
			cursorHighlight.x = Util.grid_to_real(Util.real_to_grid(touch.globalX - world.x - xOffset));
			cursorHighlight.y = Util.grid_to_real(Util.real_to_grid(touch.globalY - world.y - yOffset));

			// Manage build hud display and current image
			showBuildHudImage = touch.isTouching(currentFloor);
			if (gameState == STATE_BUILD) {
				if (touch.phase == TouchPhase.BEGAN && !touch.isTouching(buildHud)) {
					buildHud.closePopup();
				}

				if (buildHud.hasSelected()) {
					// Move buildHud image to cursor
					buildHud.currentImage.x = touch.globalX - buildHud.currentImage.width / 2;
					buildHud.currentImage.y = touch.globalY - buildHud.currentImage.height / 2;
					currentFloor.highlightAllowedLocations(buildHud.directions, buildHud.hudState);
					if (touch.phase == TouchPhase.ENDED && touch.isTouching(currentFloor)) {
						// Player clicked inside grid
						buildHandleClick(touch);
					}
				} else {
					currentFloor.clearHighlightedLocations();
				}
			}


			// Click outside of shop (onblur)
			if (getChildIndex(shopHud) != -1 && !touch.isTouching(shopHud) && !touch.isTouching(shopButton) && touch.phase == TouchPhase.BEGAN) {
				removeChild(shopHud);
			}

			if (touch.phase == TouchPhase.BEGAN && tileUnlockPopup != null && tileUnlockTimer > TILE_UNLOCK_THRESHOLD) {
				closeTileUnlock();
			}

			var isTouchHelpButton:Boolean;
			var touchX:int = touch.globalX;
			var touchY:int = touch.globalY;
			if (touchX >= helpButton.x && touchX < helpButton.x + helpButton.width &&
				touchY >= helpButton.y && touchY < helpButton.y + helpButton.height) {
				isTouchHelpButton = true;
			}
			if (isTouchHelpButton && (gameState == STATE_BUILD || gameState == STATE_RUN)) {
				helpImageSprite.removeChild(helpImage);
				helpImage = new Image(Assets.textures[gameState == STATE_BUILD ? Util.BUILD_HELP : Util.RUN_HELP]);
				helpImageSprite.addChild(helpImage);
				addChild(helpImageSprite);
				helping = true;
			} else {
				removeChild(helpImageSprite);
				if (helping && (gameState == STATE_BUILD || gameState == STATE_RUN)) {
					var state:String = gameState == STATE_BUILD ? "buildState" : "runState";
					Util.logger.logAction(21, {
						"phaseHovered":state,
						"timeHovered":timeHovered
					});
					timeHovered = 0;
					helping = false;

				}
			}

			if(phaseBanner && touch.phase == TouchPhase.BEGAN && phaseBannerTimer > PHASE_BANNER_THRESHOLD) {
				removeChild(phaseBanner);
				phaseBanner = null;
			}

			/*if(gameState == STATE_BUILD) {
				showBuildHudImage = !touch.isTouching(buildHud);
				showBuildHudImage = showBuildHudImage ? !touch.isTouching(goldHud) : showBuildHudImage;
				showBuildHudImage = showBuildHudImage ? !touch.isTouching(bgmMuteButton) : showBuildHudImage;
				showBuildHudImage = showBuildHudImage ? !touch.isTouching(sfxMuteButton) : showBuildHudImage;
				showBuildHudImage = showBuildHudImage ? !touch.isTouching(runButton) : showBuildHudImage;
				showBuildHudImage = showBuildHudImage ? !touch.isTouching(shopButton) : showBuildHudImage;
			}*/
		}

		private function buildHandleClick(touch:Touch):void {
			var currentTile:Tile; var currentEntity:Entity; var newTile:Tile; var newEntity:Entity; var cost:int;

			var tempX:int = touch.globalX - world.x;
			var tempY:int = touch.globalY - world.y;
			if (tempX > 0 && tempX < currentFloor.gridWidth * Util.PIXELS_PER_TILE
				&& tempY > 0 && tempY < currentFloor.gridHeight * Util.PIXELS_PER_TILE) {
				currentTile = currentFloor.grid[Util.real_to_grid(tempX)][Util.real_to_grid(tempY)];
				currentEntity = currentFloor.entityGrid[Util.real_to_grid(tempX)][Util.real_to_grid(tempY)];
			} else {
				// Did not click a valid tile location
				return;
			}

			if (buildHud.hudState == BuildHUD.STATE_DELETE) {
				if (currentFloor.deleteSelected(currentTile, currentEntity)) {
					var refund:int = buildHud.getRefundForDelete(currentTile, currentEntity);
					gold += refund;
					goldSpent -= refund;
					goldHud.update(gold);
					Assets.mixer.play(Util.TILE_REMOVE);
				} else {
					Assets.mixer.play(Util.TILE_FAILURE);
				}
			} else if (buildHud.hudState == BuildHUD.STATE_TILE) {
				newTile = buildHud.buildTileFromImage(world.x, world.y);
				cost = buildHud.getCost();
				if (currentFloor.highlightedLocations[newTile.grid_x][newTile.grid_y] && gold - cost >= 0) {
					gold -= cost;
					goldHud.update(gold);
					// Player correctly placed the tile. Add it to the grid.
					currentFloor.grid[newTile.grid_x][newTile.grid_y] = newTile;
					currentFloor.addChild(newTile);
					currentFloor.rooms.addTile(newTile);
					currentFloor.removeFoggedLocationsInPath();
					numberOfTilesPlaced++;
					Util.logger.logAction(1, {
						"goldSpent": cost,
						"northOpen":newTile.north,
						"southOpen":newTile.south,
						"eastOpen":newTile.east,
						"westOpen":newTile.west
					});
					goldSpent += cost;
					Assets.mixer.play(Util.TILE_MOVE);
				} else {
					Assets.mixer.play(Util.TILE_FAILURE);
				}
			} else if (buildHud.hudState == BuildHUD.STATE_ENTITY) {
				cost = buildHud.getCost();
				if (currentFloor.isEmptyTile(currentTile) && gold - cost >= 0) {
					var type:String = "healing";
					gold -= cost;
					goldHud.update(gold);
					// Player correctly placed the entity. Add it to the grid.
					newEntity = buildHud.buildEntityFromImage(currentTile);
					currentFloor.entityGrid[newEntity.grid_x][newEntity.grid_y] = newEntity;
					currentFloor.addChild(newEntity);
					if (newEntity is Enemy) {
						currentFloor.activeEnemies.push(newEntity);
						type = "enemy";
					}
					Assets.mixer.play(Util.TILE_MOVE);
					Util.logger.logAction(18, {
						"cost":cost,
						"entityPlaced":type
					});
					goldSpent += cost;
					entitiesPlaced++;
				} else {
					Assets.mixer.play(Util.TILE_FAILURE);
				}
			}
		}

		private function onKeyDown(event:KeyboardEvent):void {
			if(gameState == STATE_TUTORIAL || gameState == STATE_CINEMATIC) {
				return;
			}

			// to ensure that they can't move the world around until
			// a floor is loaded, and not cause flash errors
			pressedKeys[event.keyCode] = true;
			if (event.keyCode == Util.BGM_MUTE_KEY) {
				bgmMuteButton.onClick();
			}
			if (event.keyCode == Util.SFX_MUTE_KEY) {
				sfxMuteButton.onClick();
			}
			if (event.keyCode == Util.CHANGE_PHASE_KEY) {
				if (gameState == STATE_BUILD) {
					runFloor();
				} else if (gameState == STATE_RUN) {
					endRunButton();
				} else if (gameState == STATE_SUMMARY) {
					returnToBuild();
				}
			}
			if (event.keyCode == Util.COMBAT_SKIP_KEY) {
				//combatSkip = !combatSkip;
				toggleCombatSpeed();
				if(currentCombat && gameState == STATE_COMBAT) {
					if(currentCombat.skipping != combatSkip) {
						currentCombat.toggleSkip();
					}
				}
			}
			if (event.keyCode == Util.SPEED_TOGGLE_KEY) {
				toggleRunSpeed();
			}

			if (currentFloor) {
				// TODO: set up dictionary of charCode -> callback?
				if(currentFloor.floorName == Util.TUTORIAL_PAN_FLOOR) {
					currentFloor.removeTutorial();
				}
			}
		}

		public function onKeyUp(event:KeyboardEvent):void {
			pressedKeys[event.keyCode] = false;

			if(!pressedKeys[Util.UP_KEY] && !pressedKeys[Util.DOWN_KEY] &&
			   !pressedKeys[Util.LEFT_KEY] && !pressedKeys[Util.RIGHT_KEY] &&
			   !pressedKeys[Keyboard.UP] && !pressedKeys[Keyboard.DOWN] &&
			   !pressedKeys[Keyboard.LEFT] && !pressedKeys[Keyboard.RIGHT]) {
				cameraAccel = DEFAULT_CAMERA_ACCEL;
			}
		}

		public function clearBuildHUDImage(event:GameEvent):void {
			// Possible race condition which will leave phantom images
			// on the floor from discarded old buildHud images
			removeChild(buildHud.currentImage);

			if(currentFloor) {
				currentFloor.clearHighlightedLocations();
			}
		}

		public function onGainGold(event:GameEvent):void {
			// Get coin entity from floor
			// Remove coin entity from floor
			// Add amount to gold
			var addAmount:int = 0;
			if (event.x >= 0 && event.x < currentFloor.gridWidth &&
			    event.y >= 0 && event.y < currentFloor.gridHeight) { // if floor tile has gold
				var coin:Coin = currentFloor.goldGrid[event.x][event.y];
				addAmount += coin.gold;
				Util.logger.logAction(22, {
					"goldEarned":coin.gold
				});
				runHud.tilesVisited += 1;
				currentFloor.removeChild(currentFloor.goldGrid[event.x][event.y]);
				currentFloor.goldGrid[event.x][event.y] = null;
			}

			if(event.gameData["amount"] && event.gameData["entity"]) {
				addAmount += event.gameData["amount"];
				var reward:Reward = event.gameData["entity"];
				if(reward.permanent) {
					currentFloor.removedEntities.push(reward);
				}
				currentFloor.removeChild(reward);
				currentFloor.entityGrid[reward.grid_x][reward.grid_y] = null;
				Util.logger.logAction(19, {
					"type":"gold",
					"goldEarned":addAmount
				});
			}

			gold += addAmount;
			runSummary.goldCollected += addAmount;
			runHud.goldCollected += addAmount;
			goldHud.update(gold);
		}

		public function toggleRunSpeed():void {
			Util.logger.logAction(15, {
				"buttonClicked":"Increase Speed"
			});

			runPhaseSpeed = !runPhaseSpeed;

			var chosen:String = runPhaseSpeed ? Util.ICON_FAST_RUN : Util.ICON_SLOW_RUN;
			runSpeedButton.updateImage(null, Assets.textures[chosen]);

			Util.speed = runPhaseSpeed ? Util.SPEED_FAST : Util.SPEED_SLOW;
			currentFloor.updateRunSpeed();
		}

		public function toggleCombatSpeed():void {
			Util.logger.logAction(15, {
				"buttonClicked":"Combat Skip"
			});

			combatSkip = !combatSkip;

			var chosen:String = combatSkip ? Util.ICON_FAST_COMBAT : Util.ICON_SLOW_COMBAT;
			combatSpeedButton.updateImage(null, Assets.textures[chosen]);
		}

		public function onTutorialComplete(event:GameEvent):void {
			gameState = Game.STATE_CINEMATIC;
			removeChild(tutorialHud);
			playOpeningCinematic();
		}

		public function playOpeningCinematic():void {
			var commands:Array = new Array();

			var moveToExit:Dictionary = new Dictionary();
			moveToExit["command"] = Cinematic.COMMAND_MOVE;
			moveToExit["destX"] = world.x + Util.grid_to_real(9);
			moveToExit["destY"] = world.y + Util.grid_to_real(11);

			var waitAtExit:Dictionary = new Dictionary();
			waitAtExit["command"] = Cinematic.COMMAND_WAIT;
			waitAtExit["timeToWait"] = 1.5;

			var moveToStart:Dictionary = new Dictionary();
			moveToStart["command"] = Cinematic.COMMAND_MOVE;
			moveToStart["destX"] = world.x;
			moveToStart["destY"] = world.y;

			var waitAtStart:Dictionary = new Dictionary();
			waitAtStart["command"] = Cinematic.COMMAND_WAIT;
			waitAtStart["timeToWait"] = 0.5;

			commands.push(moveToExit);
			commands.push(waitAtExit);
			commands.push(moveToStart);
			commands.push(waitAtStart);

			cinematic = new Cinematic(world.x, world.y, Util.CAMERA_SHIFT * 3, commands);
			addChild(cinematic);

			removeChild(buildHud);
			removeChild(runButton);
			removeChild(goldHud);
			removeChild(shopButton);
		}

		public function onMoveCamera(event:GameEvent):void {
			world.x += event.x;
			world.y += event.y;
		}

		public function onCinematicComplete(event:GameEvent):void {
			gameState = STATE_BUILD;
			removeChild(cinematic);
			centerWorldOnCharacter();
			addChild(buildHud);
			addChild(goldHud);
			addChild(runButton);
			addChild(shopButton);

			Assets.mixer.play(Util.LEVEL_UP);
		}

		public function onTileUnlock(event:GameEvent):void {
			removeChild(tileUnlockPopup);

			if(event.gameData["type"] && event.gameData["entity"]) {
				Assets.mixer.play(Util.LEVEL_UP);

				tileUnlockTimer = 0;

				var reward:Reward = event.gameData["entity"];
				if(reward.permanent) {
					currentFloor.removedEntities.push(reward);
				}
				currentFloor.removeChild(reward);
				currentFloor.entityGrid[reward.grid_x][reward.grid_y] = null;

				var tileUnlockSprite:Sprite = new Sprite();
				var outerQuad:Quad = new Quad(Util.STAGE_WIDTH / 2,
											  Util.STAGE_HEIGHT / 2, Color.BLACK);
				var innerQuad:Quad = new Quad(outerQuad.width - 4, outerQuad.height - 4, Color.WHITE);
				innerQuad.x = outerQuad.x + 2;
				innerQuad.y = outerQuad.y + 2;

				var titleText:TextField = Util.defaultTextField(innerQuad.width, Util.LARGE_FONT_SIZE, "Tile Unlocked!", Util.LARGE_FONT_SIZE);
				titleText.x = innerQuad.x + (innerQuad.width - titleText.width) / 2;
				titleText.y = innerQuad.y;

				var closeText:TextField = Util.defaultTextField(innerQuad.width, Util.SMALL_FONT_SIZE, "Click to continue", Util.SMALL_FONT_SIZE);
				closeText.x = innerQuad.x + innerQuad.width - closeText.width;
				closeText.y = innerQuad.y + innerQuad.height - closeText.height;

				buildHud.entityFactory.unlockTile(event.gameData["type"]);
				buildHud.updateHUD();

				var unlockedTile:Dictionary = buildHud.entityFactory.masterSet[event.gameData["type"]];
				var newEntity:Entity = unlockedTile["constructor"]();
				var newEntitySprite:Sprite = new Sprite();
				newEntitySprite.addChild(newEntity.img);
				newEntitySprite.addChild(newEntity.generateOverlay());
				newEntitySprite.scaleX = 2;
				newEntitySprite.scaleY = 2;
				newEntitySprite.x = innerQuad.x + Util.PIXELS_PER_TILE / 4;
				newEntitySprite.y = innerQuad.y + (innerQuad.height / 4);

				var newEntityTitle:TextField = Util.defaultTextField(innerQuad.width - newEntitySprite.width - newEntitySprite.x + innerQuad.x,
																	Util.MEDIUM_FONT_SIZE, buildHud.entityFactory.entityText[event.gameData["type"]][0]);
				newEntityTitle.autoScale = true;
				newEntityTitle.hAlign = HAlign.LEFT;
				newEntityTitle.x = newEntitySprite.x + newEntitySprite.width;
				//newEntityTitle.y = titleText.y + titleText.height + Util.PIXELS_PER_TILE / 4;
				newEntityTitle.y = newEntitySprite.y;

				//var openSpace:int = innerQuad.height - titleText.height - newEntityTitle.height - (2 * Util.PIXELS_PER_TILE) / 4 - closeText.height;
				var openSpace:int = innerQuad.height - (newEntitySprite.y - innerQuad.y) - closeText.height - newEntityTitle.height;

				var newEntityText:TextField = Util.defaultTextField(innerQuad.width - newEntitySprite.width - newEntitySprite.x + innerQuad.x,
																	(openSpace * 2 / 3), newEntity.generateDescription());
				newEntityText.autoScale = true;
				newEntityText.hAlign = HAlign.LEFT;
				newEntityText.x = newEntitySprite.x + newEntitySprite.width;
				newEntityText.y = newEntityTitle.y + newEntityTitle.height;

				var newEntityFlavor:TextField = Util.defaultTextField(innerQuad.width - newEntitySprite.width - newEntitySprite.x + innerQuad.x,
				 													  (openSpace / 3), buildHud.entityFactory.entityText[event.gameData["type"]][1]);
				newEntityFlavor.autoScale = true;
				newEntityFlavor.hAlign = HAlign.LEFT;
				newEntityFlavor.x = newEntitySprite.x + newEntitySprite.width;
				newEntityFlavor.y = newEntityText.y + newEntityText.height;

				tileUnlockSprite.addChild(outerQuad);
				tileUnlockSprite.addChild(innerQuad);
				tileUnlockSprite.addChild(titleText);
				tileUnlockSprite.addChild(newEntitySprite);
				tileUnlockSprite.addChild(newEntityTitle);
				tileUnlockSprite.addChild(newEntityText);
				tileUnlockSprite.addChild(newEntityFlavor);
				tileUnlockSprite.addChild(closeText);

				tileUnlockPopup = new Clickable((Util.STAGE_WIDTH - tileUnlockSprite.width) / 2,
												(Util.STAGE_HEIGHT - tileUnlockSprite.height) / 2,
												closeTileUnlock,
												tileUnlockSprite);

				if (newEntity is Enemy) {
					var temp:Enemy = newEntity as Enemy;
					Util.logger.logAction(19, {
						"type":"enemy",
						"enemyHealth":temp.hp,
						"enemyAttack":temp.attack,
						"enemyReward":temp.reward,
						"enemyName":temp.enemyName
					});
					trace(temp.hp);
					trace(newEntity.cost);
					trace(temp.reward);
					trace(temp.attack);
				} else if (newEntity is StaminaHeal) {
					var tempS:StaminaHeal = newEntity as StaminaHeal;
					Util.logger.logAction(19, {
						"type":"staminaHeal",
						"staminaRestored":tempS.stamina
					});
				} else {
					var tempH:Healing = newEntity as Healing;
					Util.logger.logAction(19, {
						"type":"healing",
						"healthRestored":tempH.health
					});
				}
			}

			addChild(tileUnlockPopup);
		}

		public function closeTileUnlock():void {
			removeChild(tileUnlockPopup);
			tileUnlockPopup = null;
		}

		private function onLosChange(event:GameEvent):void {
			currentFloor.removeFoggedLocationsInPath();
		}
	}
}

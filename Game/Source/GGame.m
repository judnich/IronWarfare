// Copyright © 2010 John Judnich. All rights reserved.

#import "GGame.h"
#import "XScript.h"
#import "XParticleSystem.h"
#import "GTeam.h"
#import "GTank.h"
#import "GOutpost.h"
#import "GTankPlayerController.h"
#import "GBulletPool.h"
#import "GHUD.h"
#import "GMap.h"
#import "GSoundPool.h"
#import "MMenu.h"
#import "GBMusicTrack.h"
#import "AppDelegate.h"

GGame *gGame = nil; //GGame singleton


@implementation GGame

-(id)init
{
	if ((self = [super init])) {
		if (gGame == nil)
			gGame = self;
		else
			[NSException raise:@"Singleton Error!" format:@"Only one instance of GGame allowed"];
		
		srand(time(NULL));
		srand(rand());
		
		soundPool = [[GSoundPool alloc] init];
		
		commonMedia = [[XMediaGroup alloc] init];
		mapMedia = [[XMediaGroup alloc] init];
		
		accel_sync.x = 0; accel_sync.y = 0; accel_sync.z = 0;
		accel_lock = [[NSLock alloc] init];
		numActiveTouches = 0;
		
		const float kAccelerometerFrequency = 100.0;
		[[UIAccelerometer sharedAccelerometer] setUpdateInterval:(1.0 / kAccelerometerFrequency)];
		[[UIAccelerometer sharedAccelerometer] setDelegate:self];
		
		teamList = [[NSMutableArray alloc] initWithCapacity:4];
		tankList = [[NSMutableArray alloc] initWithCapacity:10];
		removeTankList = [[NSMutableArray alloc] initWithCapacity:5];
		outpostList = [[NSMutableArray alloc] initWithCapacity:5];
		particlesPool = [[NSMutableArray alloc] initWithCapacity:20];
		
		mapIsLoaded = NO;
	}
	return self;
}

-(void)dealloc
{
	[teamList release];
	[tankList release];
	[removeTankList release];
	[outpostList release];
	[particlesPool release];
	
	[accel_lock release];
	[[UIAccelerometer sharedAccelerometer] setDelegate:nil];
	
	[commonMedia freeDeadResourcesNow];
	[commonMedia release];
	[mapMedia freeDeadResourcesNow];
	[mapMedia release];
	
	[soundPool release];

	[super dealloc];
}

-(void)notifyLowMemory
{
	NSLog(@"LOW MEMORY WARNING RECEIVED");
	lowMemory = YES;
}

-(void)accelerometer:(UIAccelerometer*)accelerometer didAccelerate:(UIAcceleration*)accel
{
	[accel_lock lock];
	XScalar sc = 0.5f;
	accel_sync.x = accel_sync.x * sc + accel.x * (1-sc);
	accel_sync.y = accel_sync.y * sc + accel.y * (1-sc);
	accel_sync.z = accel_sync.z * sc + accel.z * (1-sc);
	[accel_lock unlock];
}

-(void)touchesBegan:(NSSet*)touches withEvent:(UIEvent*)event view:(GLView*)view
{
	for (UITouch *touch in touches) {
		CGPoint location = [touch locationInView:view];
		float tmp = location.x; location.x = location.y; location.y = uiScreenHeight-tmp;
		
		location.y *= (320.0f / (float)uiScreenHeight);
		location.x *= (480.0f / (float)uiScreenWidth);
		
		if (tutorialPausedGame) {
			if (tutorialTouchTimer <= 0.1f) {
				tutorialTouchTimer = -1;
				tutorialPausedGame = NO;
				tutorialTimer += 1.1f;
			}
		}
		else {
			if (menuMode) {
				// notify menu system of touch
				[menu notifyTouch:location];
			} 
			else {
				// toggle map mode
				if (mapMode) {
					[map notifyTouch:location];
				} else {
					if (playerController) {
						if (location.y < 320-150 || playerController.controlTarget == nil) {
							mapMode = YES;
						}
					}
				}
			}
		}
		
		if (numActiveTouches < MAX_ACTIVE_TOUCHES)
			activeTouches[numActiveTouches++] = location;
		else
			break;
	}
}

-(void)touchesMoved:(NSSet*)touches withEvent:(UIEvent*)event view:(GLView*)view
{
	if (touches.count == numActiveTouches) {
		int i = 0;
		for (UITouch *touch in touches) {
			CGPoint location = [touch locationInView:view];
			float tmp = location.x; location.x = location.y; location.y = (uiScreenHeight-tmp);
			location.y *= (320.0f / (float)uiScreenHeight);
			location.x *= (480.0f / (float)uiScreenWidth);
			activeTouches[i] = location;
			++i;
		}
	}
	else {
		for (UITouch *touch in touches) {
			CGPoint prevlocation = [touch previousLocationInView:view];
			float tmp = prevlocation.x; prevlocation.x = prevlocation.y; prevlocation.y = (uiScreenHeight-tmp);
			prevlocation.y *= (320.0f / (float)uiScreenHeight);
			prevlocation.x *= (480.0f / (float)uiScreenWidth);
			for (int i = 0; i < numActiveTouches; ++i) {
				CGPoint activeLocation = activeTouches[i];
				int dx = prevlocation.x - activeLocation.x;
				int dy = prevlocation.y - activeLocation.y;
				int distSq = dx*dx + dy*dy;
				if (distSq <= 500) {
					// if match, update with new location
					CGPoint location = [touch locationInView:view];
					float tmp = location.x; location.x = location.y; location.y = (uiScreenHeight-tmp);
					location.y *= (320.0f / (float)uiScreenHeight);
					location.x *= (480.0f / (float)uiScreenWidth);
					activeTouches[i] = location;
					break;
				}
			}
		}
	}
}

-(void)touchesEnded:(NSSet*)touches withEvent:(UIEvent*)event view:(GLView*)view
{
	for (UITouch *touch in touches) {
		CGPoint location = [touch locationInView:view];
		float tmp = location.x; location.x = location.y; location.y = (uiScreenHeight-tmp);
		location.y *= (320.0f / (float)uiScreenHeight);
		location.x *= (480.0f / (float)uiScreenWidth);

		if (menuMode) {
			// notify menu system of touch
			[menu notifyRelease:location];
		} 

		BOOL found = NO;
		for (int i = 0; i < numActiveTouches; ++i) {
			CGPoint activeLocation = activeTouches[i];
			int dx = location.x - activeLocation.x;
			int dy = location.y - activeLocation.y;
			int distSq = dx*dx + dy*dy;
			if (distSq <= 500) {
				// if match, delete touch point from list
				activeTouches[i] = activeTouches[numActiveTouches-1];
				--numActiveTouches;
				--i;
				found = YES;
			}
		}
		// must not leave touches "stuck" on when they can't be removed properly
		if (!found) {
			numActiveTouches = 0;
			break;
		}			
	}
}

-(void)touchesCancelled:(NSSet*)touches withEvent:(UIEvent*)event view:(GLView*)view
{
	[self touchesEnded:touches withEvent:event view:view];
}


-(void)loadContent:(GLView*)view
{	
	scene = [[XScene alloc] init];
	scene.fogRange = 1500;
	
	camera = [[XCamera alloc] init];
	camera->nearClip = 1;
	camera->farClip  = 5000.0;
	scene.camera = camera;
	
	menu = [[MMenu alloc] init];
	menuMode = YES;
}

-(void)unloadContent:(GLView*)view
{
	[self unloadMap];
	
	[camera release];
	[scene release];
	[mapMedia freeDeadResourcesNow];
	
	[menu release];
}


-(void)setTutorialMode:(BOOL)mode
{
	tutorialMode = mode;
	tutorialTimer = 0;
	tutorialPausedGame = NO;
	tutorialTouchTimer = -1;
	
	if (tutorialMode) {
		tut1 = [XTexture mediaRetainFile:@"Media/HUD/Tutorial1.tga" usingMedia:mapMedia];
		tut2 = [XTexture mediaRetainFile:@"Media/HUD/Tutorial2.tga" usingMedia:mapMedia];
		tut3 = [XTexture mediaRetainFile:@"Media/HUD/Tutorial3.tga" usingMedia:mapMedia];
		tut4 = [XTexture mediaRetainFile:@"Media/HUD/Tutorial4.tga" usingMedia:mapMedia];
	}
}

-(BOOL)tutorialMode
{
	return tutorialMode;
}

-(void)loadMap:(NSString*)filename
{
	if (mapIsLoaded)
		[self unloadMap];
	mapIsLoaded = YES;
	
	cheat1 = NO;
	
	[currentMapFilename release];
	currentMapFilename = filename;
	[currentMapFilename retain];
	
	[commonMedia freeDeadResourcesNow];
	[mapMedia freeDeadResourcesNow];

	winStatus = GWinStatus_None;
	winningTeam = nil;
	playerController = nil;
	playerTeam = nil;
	paused = NO;
	mapMode = NO;
	
	NSAutoreleasePool *autoreleasePool = [[NSAutoreleasePool alloc] init];
	XScriptNode *scriptFile = [[XScriptNode alloc] initWithFile:filename]; assert(scriptFile);
	XScriptNode *root = [scriptFile getSubnodeByName:@"map"]; assert(root);
	
	NSString *mapFolder = [@"Media/" stringByAppendingString:[[root getSubnodeByName:@"media_folder"] getValue:0]];
	NSString *detailMapFile = [@"Media/Common/Textures/" stringByAppendingPathComponent:[[root getSubnodeByName:@"detail_map"] getValue:0]];
	srand([mapFolder hash]);
	
	// load terrain
	terrain = [[XTerrain alloc] initWithHeightmap:[mapFolder stringByAppendingString:@"heightmap.png"] skirtSize:3.0];
	[terrain setTextureMap:[mapFolder stringByAppendingPathComponent:@"texturemap.png"] usingMedia:mapMedia];
	[terrain setDetailMap:detailMapFile usingMedia:mapMedia];
//	terrain.lodRange = 1500;
	terrain.lodRange = 3000;
	terrain->boundingBox.min.x = -512;
	terrain->boundingBox.min.z = -512;
	terrain->boundingBox.max.x = 512;
	terrain->boundingBox.max.z = 512;
	terrain->boundingBox.min.y = 0;
	
	XScriptNode *hrNode = [root getSubnodeByName:@"height_range"];
	if (hrNode)
		terrain->boundingBox.max.y = [hrNode getValueF:0];
	else
		terrain->boundingBox.max.y = 50;
	
	[terrain notifyBoundsChanged];
	terrain.scene = scene;
	
	// load trees
	XScriptNode *node = [root getSubnodeByName:@"trees"];
	if (node) {
		NSString *billboardFile = [@"Media/Common/Trees/" stringByAppendingString:[node getValue:1]];
		XTexture *tex = [XTexture mediaRetainFile:billboardFile usingMedia:mapMedia];
		if (tex) {
			glBindTexture(GL_TEXTURE_2D, tex.glTexture);
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
			glBindTexture(GL_TEXTURE_2D, 0);
			
			treeSystem = [[XTreeSystem alloc] init];
			treeSystem->boundingBox = terrain->boundingBox;
			[treeSystem notifyBoundsChanged];

			treeSystem.terrain = terrain;
			treeSystem.scene = scene;
			treeSystem.texture = tex;
			[tex mediaRelease];
		
			treeCount = [node getValueI:0];
			treeArray = malloc(sizeof(XTreeInstance) * treeCount);
			XScalarRect area;
			float width = terrain->boundingBox.max.x - terrain->boundingBox.min.x;
			float height = terrain->boundingBox.max.z - terrain->boundingBox.min.z;
			area.left = terrain->boundingBox.min.x + width * 0.1f; area.right = terrain->boundingBox.max.x - width * 0.1f;
			area.top = terrain->boundingBox.min.z + height * 0.1f; area.bottom = terrain->boundingBox.max.z - height * 0.1f;
			
			int seed = [[node getSubnodeByName:@"seed"] getValueI:0];
			srand([mapFolder hash] + seed);
			
			float minSize = 8, maxSize = 12;
			XScriptNode *snode = [node getSubnodeByName:@"size"];
			if (snode) {
				minSize = [snode getValueF:0];
				maxSize = [snode getValueF:1];
			}
			
			TreeSystem_populateTreeArrayProcedurally(treeArray, treeCount, minSize, maxSize, area);
			
			[treeSystem setTreesArrayPointer:treeArray treeCount:treeCount];
			XIntRect region;
			region.left = 0; region.right = TREE_BATCH_GRID_SIZE;
			region.top = 0; region.bottom = TREE_BATCH_GRID_SIZE;
			[treeSystem updateTreesRegion:region];
		}
	}
	
	// load clutter
	node = [root getSubnodeByName:@"clutter"];
	if (node) {
		int clutterQuads = [node getValueI:0] * 10; // multiplier is a hack to "scale up" graphics for retina
		NSString *atlasFile = [@"Media/Common/Clutter/" stringByAppendingString:[node getValue:1]];
		XTexture *tex = [XTexture mediaRetainFile:atlasFile usingMedia:mapMedia];
		if (tex) {
			glBindTexture(GL_TEXTURE_2D, tex.glTexture);
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
			glBindTexture(GL_TEXTURE_2D, 0);
			
			clutter = [[XClutterSystem alloc] initWithSize:clutterQuads];
			clutter.terrain = terrain;
			clutter.scene = scene;
			clutter.atlasTexture = tex;
			[tex mediaRelease];
			
			[clutter loadClutterTypesFromScript:node];
		}
	}
	
	// load sky
	NSString *skyboxName = [[root getSubnodeByName:@"sky_box"] getValue:0];
	NSString *skyboxPath = [@"Media/Common/Skyboxes/" stringByAppendingPathComponent:skyboxName];
	sky = [[XSkyBox alloc] initFromFolder:skyboxPath filePrefix:@"sky" fileExtension:@"jpg" usingMedia:mapMedia];
	sky.scene = scene;
	
	// load teams defined in map file
	srand(time(NULL));
	NSArray *teamNodes = [root subnodesWithName:@"team"];
	for (XScriptNode *teamNode in teamNodes) {
		// load team
		GTeam *team = nil;
		XMesh *neutralFlagpole = nil;
		if ([teamNode getValue:0] == nil || [[teamNode getValue:0] isEqual:@"neutral"]) {
			team = nil;
			NSString *flagpoleFile = [@"Media/" stringByAppendingString:[[teamNode getSubnodeByName:@"pole_mesh"] getValue:0]];
			neutralFlagpole = [XMesh mediaRetainFile:flagpoleFile usingMedia:commonMedia];
		} else {
			NSString *teamFile = [@"Media/" stringByAppendingString:[teamNode getValue:0]];
			team = [[GTeam alloc] initWithFile:teamFile];
			[teamList addObject:team];
			[team release];
		}
		if ([[teamNode getValue:1] isEqual:@"player_team"])
			playerTeam = team;
		if (team) {
			team.maxTanks = [[teamNode getSubnodeByName:@"tank_limit"] getValueI:0];
			if (team.maxTanks == 0) {
				team.maxTanks = 1;
				NSLog(@"ERROR! tank_limit must be specified in map file for each team");
			}
			XScriptNode *node = [teamNode getSubnodeByName:@"reinforcement_interval"];
			if (node)
				team.reinforcementInterval = [node getValueF:0];
			node = [teamNode getSubnodeByName:@"tanks_per_reinforcement"];
			if (node)
				team.numTanksPerReinforcement = [node getValueI:0];			
			NSString *aiSkillStr = [[teamNode getSubnodeByName:@"ai_skill"] getValue:0];
			if  (aiSkillStr) {
				if ([aiSkillStr isEqualToString:@"rookie"])
					team.aiSkill = AISkill_Rookie;
				else if ([aiSkillStr isEqualToString:@"average"])
					team.aiSkill = AISkill_Average;
				else if ([aiSkillStr isEqualToString:@"expert"])
					team.aiSkill = AISkill_Expert;
				else if ([aiSkillStr isEqualToString:@"flawless"])
					team.aiSkill = AISkill_Flawless;
				else {
					NSLog(@"Warning: AI skill level specified in map file for team \"%@\" is invalid.", [teamNode getValue:0]);
				}
			} else {
				NSLog(@"Warning: AI skill level not specified in map file for team \"%@\".", [teamNode getValue:0]);
			}
		}		
		// load team's outposts
		NSArray *outpostNodes = [teamNode subnodesWithName:@"outpost"];
		for (XScriptNode *outpostNode in outpostNodes) {
			XVector2 pos;
			pos.x = [outpostNode getValueF:0] - 512.0f;
			pos.y = [outpostNode getValueF:1] - 512.0f;
			GOutpost *outpost = [[GOutpost alloc] initAt:pos withFlagPole:neutralFlagpole];
			outpost.owningTeam = team;
			
			[outpostList addObject:outpost];
			[outpost release];
		}
		[neutralFlagpole mediaRelease];
	}
	// spawn tanks initially
	for (GTeam *team in teamList) {
		[team frameUpdate:team.reinforcementInterval*1.5f];
	}
	
	// set up the player's controls
	playerController = [[GTankPlayerController alloc] init];
	
	// prepare bullets
	GBulletType *bulletType = [GBulletType mediaRetainFile:@"Media/Common/Effects/bullet.png" usingMedia:commonMedia];
	bulletGroup = [[GBulletPool alloc] initWithType:bulletType capacity:40];
	[bulletType mediaRelease];
	
	[scriptFile release];
	[autoreleasePool release];
	
	// keep pooled internal particle buffers in memory even when no particles are rendered
	[XParticleSystem retainPooledBuffers];
	
	// load HUD
	hud = [[GHUD alloc] init];
	map = [[GMap alloc] init];
	mapMode = YES;
	
	// save game initially
	[self saveGame];
}

-(void)unloadMap
{
	if (victoryMusic) {
		[victoryMusic close];
		[victoryMusic release];
		victoryMusic = nil;
	}
	
	if (tut1) {
		[tut1 mediaRelease];
		tut1 = nil;
	}
	if (tut2) {
		[tut2 mediaRelease];
		tut2 = nil;
	}
	if (tut3) {
		[tut3 mediaRelease];
		tut3 = nil;
	}
	if (tut4) {
		[tut4 mediaRelease];
		tut4 = nil;
	}
	
	if (!mapIsLoaded)
		return;
	mapIsLoaded = NO;
	
	[currentMapFilename release];
	currentMapFilename = nil;
	
	// it's important to set all controllers to "nil", because the AI
	// might retain tanks, in which case a circular reference could keep
	// tanks alive forever unless their controllers are removed manually
	// before releasing them from the tank list
	[playerController release];
	playerController = nil;
	for (GTank *tank in tankList)
		tank.controller = nil;
	[tankList removeAllObjects];

	// nodes must be removed from the scene to be released, otherwise the
	// scene will keep them alive.
	for (XParticleSystem *particles in particlesPool)
		particles.scene = nil;
	[particlesPool removeAllObjects];
	
	[teamList removeAllObjects];
	[outpostList removeAllObjects];
	[bulletGroup release];
	
	terrain.scene = nil;
	[terrain release];
	terrain = nil;
	
	sky.scene = nil;
	[sky release];
	sky = nil;
	
	if (clutter) {
		clutter.scene = nil;
		[clutter release];
		clutter = nil;
	}
	
	if (treeSystem) {
		treeSystem.scene = nil;
		[treeSystem release];
		treeSystem = nil;
	}
	if (treeArray) {
		free(treeArray);
		treeArray = nil;
		treeCount = 0;
	}
	
	[mapMedia freeDeadResourcesNow];
	
	// dump pooled internal particle buffers
	[XParticleSystem releasePooledBuffers];
	
	[hud release];
	[map release];
}

-(void)renderFrame:(XGameTime)gameTime
{
	// free memory if possible
	if (lowMemory) {
		[commonMedia freeDeadResourcesNow];
		[mapMedia freeDeadResourcesNow];
		lowMemory = NO;
	}
	
	// capture input state
	if ([accel_lock tryLock]) {
		acceleration = accel_sync;
		[accel_lock unlock];
	}

	// show menu
	if (menuMode) {
		soundPool.engineSoundEnabled = NO;
		[menu renderFrame:gameTime];
		return;
	}	
	if (!terrain)
		return;

	// measure frames per second to the log
	if (gameTime.totalTime > frameTimer+1.0) {
		int FPS = frameCounter;
		frameCounter = 0;
		frameTimer = gameTime.totalTime;
		NSLog(@"(%d)  FPS: %d  Total frames: %d", ++readingCounter, FPS, totalFrameCounter);
	}
	++frameCounter;
	++totalFrameCounter;
	
	if (!paused && !tutorialPausedGame) {
		// save game periodically
		saveGameTimer += gameTime.deltaTime;
		if (saveGameTimer > 10) {
			saveGameTimer = 0;
			[self saveGame];
		}
		
		// update objects
		for (GTeam *team in teamList) {
			[team frameUpdate:gameTime.deltaTime];
		}
		
		for (GTank *tank in tankList) {
			BOOL remove = [tank frameUpdate:gameTime.deltaTime];
			if (remove)
				[removeTankList addObject:tank];
		}
		for (GTank *tank in removeTankList) {
			[tankList removeObject:tank];
		}
		[removeTankList removeAllObjects];
		
		for (GOutpost *outpost in outpostList) {
			[outpost frameUpdate:gameTime.deltaTime];
		}
		
		[bulletGroup frameUpdate:gameTime.deltaTime];
		
		for (int i = 0; i < particlesPool.count; ++i) {
			XParticleSystem *particles = [particlesPool objectAtIndex:i];
			[particles updateAnimation:gameTime.deltaTime];
			if (particles.isAnimating == NO) {
				particles.scene = nil;
				[particlesPool removeObjectAtIndex:i];
				--i;
			}
		}
		
		// update win status
		++frameSkipCount;
		if (frameSkipCount >= 30) {
			frameSkipCount = 0;
			
			if (winStatus == GWinStatus_None) {
				winningTeam = nil;
				for (GOutpost *outpost in outpostList) {
					GTeam *owningTeam = outpost.owningTeam;
					if (owningTeam.reinforcementInterval >= 100) // if a team takes really long to respawn, ignore their bases
						owningTeam = nil;
					if (owningTeam != nil && winningTeam == nil)
						winningTeam = outpost.owningTeam;
					if (owningTeam != nil && owningTeam != winningTeam) {
						winningTeam = nil;
						break;
					}
				}
				if (!winningTeam) {
					for (GOutpost *outpost in outpostList) {
						GTeam *owningTeam = outpost.owningTeam;
						if (owningTeam != nil && winningTeam == nil)
							winningTeam = outpost.owningTeam;
						if (owningTeam != nil && owningTeam != winningTeam) {
							winningTeam = nil;
							break;
						}
					}
				}
				if (winningTeam) {
					for (GTank *tank in tankList) {
						if (tank.team != winningTeam) {
							winningTeam = nil;
							break;
						}
					}
				}
				if (winningTeam != nil) {
					if (winningTeam == playerTeam) {
						winStatus = GWinStatus_Victory;

						// victory music!
						[menu unloadMusic];
						NSString *file = @"Media/Sounds/VictoryMusic.mp3";
						NSString *directory = [file stringByDeletingLastPathComponent];
						NSString *fileN = [file lastPathComponent];
						NSString *path = [[NSBundle mainBundle] pathForResource:fileN ofType:nil inDirectory:directory];
						if (victoryMusic) {
							[victoryMusic close];
							[victoryMusic release];
						}
						victoryMusic = [[GBMusicTrack alloc] initWithPath:path];
						[victoryMusic setRepeat:NO];
						[victoryMusic play];
					} else {
						winStatus = GWinStatus_Defeat;
					}
					if (mapMode) {
						mapMode = NO;
						if (playerController.controlTarget == nil)
							spectatorMode = YES;
					}
				}
				
				if (winStatus != GWinStatus_None) {
					mapMode = NO;
				}
			}
		}
	}
	
	// update camera
	static XSeconds noTank = 10;
	if (playerController.controlTarget == nil) {
		// auto return to menu when tank is destroyed
		if (noTank >= 1 && !spectatorMode && winStatus == GWinStatus_None) {
			mapMode = YES;
		}
		noTank += gameTime.deltaTime;
		// free cam
		if (mapMode)
			freecamAngle += 0.2f * gameTime.deltaTime;
		else
			freecamAngle -= acceleration.y*xAbs(acceleration.y) * 15 * gameTime.deltaTime;
		freecamRadius = 300;//(1-acceleration.z) * 500;
		XVector3 pos;
		pos.x = xSin(freecamAngle) * freecamRadius;
		pos.y = terrain->boundingBox.max.y + 5;
		pos.z = xCos(freecamAngle) * freecamRadius;
		if (noTank > 10.0f) {
			camera->origin = pos;
		} else {
			float smooth = 0.99f - xSaturate(noTank * 0.5f) * 0.1f;
			camera->origin.x = camera->origin.x * smooth + pos.x * (1-smooth);
			camera->origin.y = camera->origin.y * smooth + pos.y * (1-smooth);
			camera->origin.z = camera->origin.z * smooth + pos.z * (1-smooth);
		}		
		camera->lookVector.x = -xSin(freecamAngle);
		camera->lookVector.y = -0.3;
		camera->lookVector.z = -xCos(freecamAngle);
	}
	else {
		noTank = 0;
		GTank *tank = playerController.controlTarget;
		XVector3 aimVector = playerController.aimVector;
		XVector3 tankPos = *tank.bodyModel.globalPosition;
		camera->origin.x = tankPos.x + aimVector.x * 10;
		camera->origin.y = tankPos.y + aimVector.y * 10 + 5;
		camera->origin.z = tankPos.z + aimVector.z * 10;
		camera->lookVector.x = tankPos.x - camera->origin.x;
		camera->lookVector.y = (tankPos.y + 5) - camera->origin.y;
		camera->lookVector.z = tankPos.z - camera->origin.z;
		
		XTerrainIntersection intersect = [terrain intersectTerrainVerticallyAt:&camera->origin];
		if (camera->origin.y < intersect.point.y + 1) camera->origin.y = intersect.point.y + 1;
		
		XVector3 dvec = camera->origin;
		xSub_Vec3Vec3(&dvec, &tankPos);
		XScalar dist = xLength_Vec3(&dvec);
		if (dist < tank.collisionRadius) {
			xNormalize_Vec3(&dvec);
			xMul_Vec3Scalar(&dvec, (tank.collisionRadius - dist) * 2);
			xAdd_Vec3Vec3(&camera->origin, &dvec);
		}
		
		// "easter egg" cheat #1
		if (cheat1) {
			XVector3 vec; vec.x = 250; vec.y = 0; vec.z = -250;
			xSub_Vec3Vec3(&vec, &tankPos);
			XScalar dist = xSqrt(vec.x*vec.x + vec.z*vec.z);
			if (dist < 30) {
				NSLog(@"Easter egg #1 activated");
				
				GTank *van = [[GTank alloc] initWithFile:@"Media/Tanks/van.tank"];
				
				playerController.controlTarget = nil;
				for (GTank *tank in tankList) {
					if (tank.team == playerTeam)
						[removeTankList addObject:tank];
				}
				for (GTank *tank in removeTankList) {
					XVector2 pos = tank.position;
					tank.armor = 0;
					[tank destroy];
					[tankList removeObject:tank];
					GTank *t = [van spawnAt:pos];
					t.team = playerTeam;
					t.isCopyOf = nil;
				}
				[removeTankList removeAllObjects];
				
				[van release];
				
				for (GTeam *team in teamList) {
					if (team != playerTeam) {
						team.reinforcementInterval /= 4.0f;
						if (team.reinforcementInterval < 5) team.reinforcementInterval = 5;
					}
				}
				
				mapMode = YES;
				cheat1 = NO;
			}
		}
	}
	
	// render the scene
	[scene render];
	
	// update sounds
	[soundPool frameUpdate:gameTime.deltaTime fromCamera:camera];
	if (playerController.controlTarget != nil) {
		soundPool.engineSoundEnabled = YES;
		GTank *tank = playerController.controlTarget;
		float speed = tank.currentSpeed;
		if (!mapMode)
			[soundPool setEngineSpeed:speed];
		else
			[soundPool setEngineSpeed:0];
	}
	else soundPool.engineSoundEnabled = NO;
	
	if (!mapMode) {
		// render the hud
		[hud draw:gameTime.deltaTime];
		paused = NO;
	} else {	
		// render the map
		[map draw:gameTime.deltaTime];
		// pause if tanks are availible to select
		paused = NO;
		for (GTank *tank in tankList) {
			if (playerTeam == nil || tank.team == playerTeam) {
				paused = YES;
				break;
			}
		}
	}
	
	// show tutorial if enabled
	if (tutorialMode && !mapMode) {
		x2D_begin();
		x2D_enableTransparency();
		if (tutorialTouchTimer > 0) {
			tutorialTouchTimer -= gameTime.deltaTime;
			if (tutorialTouchTimer < 0) tutorialTouchTimer = 0;
		}
		if (tutorialTimer > 0.1f && tutorialTimer <= 1) {
			XIntRect area;
			x2D_setTexture(tut1);
			area.left = 240 - (tut1.width / 2);
			area.top = 160 - (tut1.height / 2);
			area.right = 240 + (tut1.width / 2);
			area.bottom = 160 + (tut1.height / 2);
			x2D_drawRect(&area);
			tutorialPausedGame = YES;
			if (tutorialTouchTimer < 0)
				tutorialTouchTimer = 2;
		}
		else if (tutorialTimer >= 10 && tutorialTimer <= 11) {
			XIntRect area;
			x2D_setTexture(tut2);
			area.left = 200 - (tut2.width / 2);
			area.top = 160 - (tut2.height / 2);
			area.right = 200 + (tut2.width / 2);
			area.bottom = 160 + (tut2.height / 2);
			x2D_drawRect(&area);
			tutorialPausedGame = YES;
			if (tutorialTouchTimer < 0)
				tutorialTouchTimer = 2;
		}
		else if (tutorialTimer >= 20 && tutorialTimer <= 21) {
			XIntRect area;
			x2D_setTexture(tut3);
			area.left = 280 - (tut3.width / 2);
			area.top = 160 - (tut3.height / 2);
			area.right = 280 + (tut3.width / 2);
			area.bottom = 160 + (tut3.height / 2);
			x2D_drawRect(&area);
			tutorialPausedGame = YES;
			if (tutorialTouchTimer < 0)
				tutorialTouchTimer = 2;
		}
		else if (tutorialTimer >= 30 && tutorialTimer <= 31) {
			XIntRect area;
			x2D_setTexture(tut4);
			area.left = 240 - (tut4.width / 2);
			area.top = 160 - (tut4.height / 2);
			area.right = 240 + (tut4.width / 2);
			area.bottom = 160 + (tut4.height / 2);
			x2D_drawRect(&area);
			tutorialPausedGame = YES;
			if (tutorialTouchTimer < 0)
				tutorialTouchTimer = 2;
		}
		else {
			tutorialTimer += gameTime.deltaTime;
		}
		x2D_disableTransparency();
		x2D_end();
	}
}

-(void)saveGame
{
	// dont save if in menu mode or a map isn't loaded
	if (menuMode || !mapIsLoaded)
		return;
	
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	NSString *documentsDirectory = [paths objectAtIndex:0];
	NSString *filePath = [documentsDirectory stringByAppendingPathComponent:@"game.save"];
	
	int tries = 0;
	FILE *file = NULL;
	while (!file) {
		if (tries > 10) return;
		file = fopen([filePath UTF8String], "wb");
		++tries;
	}

	// map filename
	char levelFile[64];
	if (currentMapFilename)
		strcpy(levelFile, [currentMapFilename UTF8String]);
	else
		strcpy(levelFile, "\0");
	fwrite(levelFile, 64, 1, file);
	
	// save team reinforcement timers
	for (GTeam *team in teamList) {
		[team saveStateToFile:file];
	}
	
	// save outpost states
	for (GOutpost *outpost in outpostList) {
		[outpost saveStateToFile:file];
	}
	
	// save tanks
	int tankCount = tankList.count;
	fwrite((void*)&tankCount, sizeof(tankCount), 1, file);
	for (GTank *tank in tankList) {
		// save team
		GTeam *team = tank.team;
		int teamID = 0;
		for (GTeam *t in teamList) {
			if (t == team)
				break;
			++teamID;
		}
		fwrite((void*)&teamID, sizeof(teamID), 1, file);
		// save tank type
		int typeID = 0;
		if (tank.isCopyOf != nil) {
			for (GTank *tk in team->tankTypeList) {
				if (tank.isCopyOf == tk)
					break;
				++typeID;
			}
		}
		fwrite((void*)&typeID, sizeof(typeID), 1, file);
	}
	for (GTank *tank in tankList) {
		[tank saveStateToFile:file];
	}
	
	// save the player's controller tank
	/*int controlledTank;
	if (playerController.controlTarget == nil)
		controlledTank = -1;
	else {
		controlledTank = 0;
		GTank *ct = playerController.controlTarget;
		for (GTank *tank in tankList) {
			if (tank == ct)
				break;
			++controlledTank;
		}
	}
	fwrite((void*)&controlledTank, sizeof(controlledTank), 1, file);*/
	
	fclose(file);
}

-(void)loadGame
{
	[self unloadMap];
	
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	NSString *documentsDirectory = [paths objectAtIndex:0];
	NSString *filePath = [documentsDirectory stringByAppendingPathComponent:@"game.save"];

	int tries = 0;
	FILE *file = NULL;
	while (!file) {
		if (tries > 10) return;
		file = fopen([filePath UTF8String], "rb");
		++tries;
	}
	
	// load map first
	char levelFile[64];
	fread(levelFile, 64, 1, file);
	[currentMapFilename release];
	currentMapFilename = [NSString stringWithUTF8String:levelFile];
	[currentMapFilename retain];
	[self loadMap:currentMapFilename];
	
	// load team reinforcement timers
	for (GTeam *team in teamList) {
		[team loadStateFromFile:file];
	}
	
	// load outpost states
	for (GOutpost *outpost in outpostList) {
		[outpost loadStateFromFile:file];
	}
	
	// first unload all tanks that were loaded by the map
	for (GTank *tank in tankList) {
		[removeTankList addObject:tank];
	}
	for (GTank *tank in removeTankList) {
		[tankList removeObject:tank];
	}
	[removeTankList removeAllObjects];
	
	// then load all tanks in the savegame
	int tankCount;
	fread((void*)&tankCount, sizeof(tankCount), 1, file);
	for (int i = 0; i < tankCount; ++i) {
		// load team
		int teamID;
		fread((void*)&teamID, sizeof(teamID), 1, file);
		GTeam *team = [teamList objectAtIndex:teamID];
		// load tank type
		int typeID;
		fread((void*)&typeID, sizeof(typeID), 1, file);
		GTank *tankType = [team->tankTypeList objectAtIndex:typeID];
		// create tank
		XVector2 pos;
		pos.x = 0; pos.y = 0;
		GTank *spawnedTank = [tankType spawnAt:pos];
		GTankAIController *controller = (GTankAIController*)spawnedTank.controller;
		controller.skillLevel = team.aiSkill;
	}
	// update tank states (positions, etc.)
	for (GTank *tank in tankList) {
		[tank loadStateFromFile:file];
	}	

	// load the player's controller tank
	/*int controlledTank;
	fread((void*)&controlledTank, sizeof(controlledTank), 1, file);
	if (controlledTank != -1) {
		GTank *ct = [tankList objectAtIndex:controlledTank];
		playerController.controlTarget = ct;
	}*/
	
	fclose(file);
}


@end

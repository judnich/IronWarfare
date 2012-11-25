// Copyright © 2010 John Judnich. All rights reserved.

#import "GLView.h"
#import "XMediaGroup.h"
#import "XScene.h"
#import "XCamera.h"
#import "XTerrain.h"
#import "XSkyBox.h"
#import "XClutterSystem.h"
#import "XTreeSystem.h"
@class GTank;
@class GTankPlayerController;
@class GBulletPool;
@class GTeam;
@class GHUD;
@class GMap;
@class GSoundPool;
@class MMenu;
@class GBMusicTrack;

#define MAX_ACTIVE_TOUCHES 3


typedef enum {
	GWinStatus_None,
	GWinStatus_Victory,
	GWinStatus_Defeat,
} GWinStatus;


@interface GGame : NSObject <GLViewDelegate, UIAccelerometerDelegate> {
	// frame timing
	int frameCounter, totalFrameCounter, readingCounter;
	float frameTimer;
	int frameSkipCount;
	
	// camera
	XAngle freecamAngle;
	XAngle freecamRadius;
	
	// tutorial
	BOOL tutorialMode;
	XTexture *tut1, *tut2, *tut3, *tut4;
	int tutorialStage;
	XSeconds tutorialTimer, tutorialTouchTimer;
	BOOL tutorialPausedGame;
	
	// saving
	XSeconds saveGameTimer;
	NSString *currentMapFilename;
	
@public
	// menu system
	MMenu *menu;
	BOOL menuMode;
	
	// cheats
	BOOL cheat1;
	
	// sound
	GSoundPool *soundPool;
	BOOL mute;
	
	// map
	BOOL mapIsLoaded;
	XScene *scene;
	XCamera *camera;
	XSkyBox *sky;
	XTerrain *terrain;
	
	// vegetation
	XClutterSystem *clutter;
	XTreeSystem *treeSystem;
	XTreeInstance *treeArray;
	int treeCount;
	
	// objects
	NSMutableArray *teamList;
	NSMutableArray *outpostList;
	NSMutableArray *tankList, *removeTankList;
	GBulletPool *bulletGroup;
	NSMutableArray *particlesPool;
	
	// game
	GWinStatus winStatus;
	GTeam *winningTeam;
	GTankPlayerController *playerController;
	GTeam *playerTeam;
	BOOL paused;
	GBMusicTrack *victoryMusic;

	// resource management
	XMediaGroup *commonMedia;
	XMediaGroup *mapMedia;
	BOOL lowMemory;
	
	// input
	NSLock *accel_lock;
	XVector3 accel_sync; // must be accessed with mutex
	XVector3 acceleration; // copied from sync_accel - no need for mutex
	CGPoint activeTouches[MAX_ACTIVE_TOUCHES];
	int numActiveTouches;
	
	// GUI
	GHUD *hud;
	GMap *map;
	BOOL mapMode;
	BOOL spectatorMode;
}

@property(assign) BOOL tutorialMode;

-(id)init;
-(void)dealloc;

-(void)loadMap:(NSString*)filename;
-(void)unloadMap;

-(void)saveGame;
-(void)loadGame;

@end

extern GGame *gGame;




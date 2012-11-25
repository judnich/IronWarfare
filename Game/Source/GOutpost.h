// Copyright © 2010 John Judnich. All rights reserved.

#import "GGame.h"
#import "GTeam.h"
#import "XMath.h"
#import "XModel.h"


@interface GOutpost : NSObject {
	GTeam *owningTeam;
	GTeam *loadedFlagTeam;
	float captured;
	XVector3 position;
	XModel *flagPole, *flag;
	XScalar flagPoleHeight;
	XAngle flagYaw, flagWave;
	XScalar spawnRadius;
	int frameCount;
	XScalar captureRadius, captureRate;
	XScalar collisionRadius;
	GTeam *capturingTeam;
	BOOL inConflict, beingCaptured;
}

@property(readonly) XVector3 *position;
@property(assign) GTeam *owningTeam;

@property(readonly) BOOL inConflict, beingCaptured;
@property(readonly) float captured;
@property(readonly) XScalar collisionRadius, spawnRadius;

-(id)initAt:(XVector2)pos withFlagPole:(XMesh*)mesh;
-(void)dealloc;

-(GTank*)spawnTank;
-(void)frameUpdate:(XSeconds)deltaTime;

-(void)saveStateToFile:(FILE*)file;
-(void)loadStateFromFile:(FILE*)file;

@end

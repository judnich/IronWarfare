// Copyright © 2010 John Judnich. All rights reserved.

#import "GOutpost.h"
#import "GTankAIController.h"


@interface GOutpost (private)

-(void)reloadFlag;

@end


@implementation GOutpost

@synthesize inConflict, beingCaptured, captured, collisionRadius, spawnRadius;

-(id)initAt:(XVector2)pos withFlagPole:(XMesh*)mesh;
{
	if ((self = [super init])) {
		position.x = pos.x;
		position.y = 0;
		position.z = pos.y;
		XTerrainIntersection intersect = [gGame->terrain intersectTerrainVerticallyAt:&position];
		position = intersect.point;
		
		if (mesh) {
			flagPole = [[XModel alloc] initWithMesh:mesh];
			flagPole->position = position;
			xBuildYRotationMatrix3(&flagPole->rotation, xRand() * TWO_PI);
			[flagPole notifyTransformsChanged];
			flagPole.scene = gGame->scene;
			flagPoleHeight = flagPole->boundingBox.max.y - flagPole->boundingBox.min.y;
		}
		
		flagYaw = xRand() * TWO_PI;
		flagWave = xRand() * 1000;
		
		spawnRadius = 25;
		captureRadius = 70;
		captureRate = 1 / 10.0;
		frameCount = rand() % 30;
		
		collisionRadius = 0.1f;
	}
	return self;
}

-(void)dealloc
{
	flagPole.scene = nil;
	[flagPole release];
	flag.scene = nil;
	[flag release];
	[super dealloc];
}

-(XVector3*)position
{
	return &position;
}

-(void)setOwningTeam:(GTeam*)team
{
	owningTeam = team;
	if (owningTeam != nil)
		captured = 1.0f;
	else
		captured = 0.0f;
	[self reloadFlag];
}

-(GTeam*)owningTeam
{
	return owningTeam;
}

-(void)reloadFlag
{
	if (owningTeam != loadedFlagTeam) {
		loadedFlagTeam = owningTeam;
		if (owningTeam && !flagPole) {
			// load flagpole if not already set
			flagPole = [[XModel alloc] initWithModel:owningTeam.flagPoleMesh];
			flagPole->position = position;
			xBuildYRotationMatrix3(&flagPole->rotation, xRand() * TWO_PI);
			[flagPole notifyTransformsChanged];
			flagPole.scene = gGame->scene;
			flagPoleHeight = flagPole->boundingBox.max.y - flagPole->boundingBox.min.y;
		}
		if (owningTeam) {
			// load team flag
			flag.scene = nil;
			[flag release];
			flag = [[XModel alloc] initWithModel:owningTeam.flagMesh];
			flag->position = position;
			[flag notifyTransformsChanged];
			flag.scene = gGame->scene;
			// update flag height based on capture status
			flag->position.y = position.y - ((1-captured) * flagPoleHeight);		
			[flag notifyTransformsChanged];
		}
		else {
			// neutral outpost (no flag)
			flag.scene = nil;
			[flag release];
			flag = nil;
		}
	}
}

-(GTank*)spawnTank
{
	if (owningTeam) {
		if (inConflict)
			NSLog(@"WARNING: Tank spawned at partially captured base (in conflict)");
		XVector2 pos;
		pos.x = xRangeRand(-spawnRadius, spawnRadius) + position.x;
		pos.y = xRangeRand(-spawnRadius, spawnRadius) + position.z;
		GTank *tank = [owningTeam spawnTankAt:pos];
		GTankAIController *controller = (GTankAIController*)tank.controller;
		controller.skillLevel = owningTeam.aiSkill;
		return tank;
	}
	else return nil;
}

-(void)frameUpdate:(XSeconds)deltaTime
{
	if (flag) {
		// wave flag in wind
		flagWave += xDegToRad(60) * deltaTime;
		XAngle yaw = flagYaw + xDegToRad(xSin(flagWave*2)*5 + xCos(flagWave*5)*2) * 3;
		xBuildYRotationMatrix3(&flag->rotation, yaw);
		
		// update flag height based on capture status
		flag->position.y = position.y - ((1-captured) * flagPoleHeight);		
		[flag notifyTransformsChanged];
	}
	
	// determine capturing team
	++frameCount;
	if (frameCount > 30) {
		frameCount = frameCount % 30;
		
		capturingTeam = nil;
		inConflict = NO;
		for (GTank *tank in gGame->tankList) {
			XScalar dx = tank.position.x - position.x;
			XScalar dz = tank.position.y - position.z;
			XScalar dist = xSqrt(dx*dx + dz*dz);
			if (dist < captureRadius) {
				if (capturingTeam == nil) {
					capturingTeam = tank.team;
				} else if (capturingTeam != tank.team) {
					capturingTeam = nil;
					inConflict = YES;
					break;
				}
			}
		}
		beingCaptured = (capturingTeam != nil && capturingTeam != owningTeam);
	}
	
	// process base capture
	if (capturingTeam != nil) {
		if (owningTeam != capturingTeam) {
			captured -= deltaTime * captureRate;
			if (captured <= 0) {
				captured = 0;
				owningTeam = capturingTeam;
				[self reloadFlag];
			}
			else if (captured < 0.25f) {
				owningTeam = nil;
				[self reloadFlag];
			}
		} else {
			captured += deltaTime * captureRate;
			if (captured >= 1)
				captured = 1;
		}
	}
}

-(void)saveStateToFile:(FILE*)file
{
	fwrite((void*)&captured, sizeof(captured), 1, file);
	
	int owningTeamID = 0;
	if (owningTeam == nil)
		owningTeamID = -1;
	else {
		for (GTeam *t in gGame->teamList) {
			if (owningTeam == t)
				break;
			++owningTeamID;
		}
	}
	fwrite((void*)&owningTeamID, sizeof(owningTeamID), 1, file);
}

-(void)loadStateFromFile:(FILE*)file
{
	float cap;
	fread((void*)&cap, sizeof(captured), 1, file);
	
	int owningTeamID;
	fread((void*)&owningTeamID, sizeof(owningTeamID), 1, file);
	GTeam *team;
	if (owningTeamID == -1)
		team = nil;
	else
		team = [gGame->teamList objectAtIndex:owningTeamID];
	[self setOwningTeam:team];
	
	captured = cap;
	if (flag) {
		flag->position.y = position.y - ((1-captured) * flagPoleHeight);
		[flag notifyTransformsChanged];
	}
}

@end



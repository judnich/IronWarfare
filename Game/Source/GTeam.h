// Copyright © 2010 John Judnich. All rights reserved.

#import "XMath.h"
#import "XScene.h"
#import "GTank.h"
#import "GTankAIController.h"


@interface GTeam : NSObject {
	NSString *teamName;
	XModel *flagPoleMesh, *flagMesh;
	int maxTanks;
	int numTanksPerReinforcement;
	XSeconds reinforcementInterval;
	XSeconds reinforcementTimer;
	GTankAISkillLevel aiSkill;
@public
	NSMutableArray *tankTypeList;
}

@property(readonly) XModel *flagPoleMesh, *flagMesh;
@property(assign) int maxTanks, numTanksPerReinforcement;
@property(assign) XSeconds reinforcementInterval;
@property(assign) GTankAISkillLevel aiSkill;

-(id)initWithFile:(NSString*)filename;
-(void)dealloc;

-(GTank*)spawnTankAt:(XVector2)pos;
-(void)frameUpdate:(XSeconds)deltaTime;

-(void)saveStateToFile:(FILE*)file;
-(void)loadStateFromFile:(FILE*)file;

@end

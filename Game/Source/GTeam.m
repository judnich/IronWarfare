// Copyright © 2010 John Judnich. All rights reserved.

#import "GTeam.h"
#import "GGame.h"
#import "XScript.h"
#import "GTank.h"
#import "GOutpost.h"
#import "XModel.h"
#import "XTexture.h"


@implementation GTeam

@synthesize flagMesh, flagPoleMesh;
@synthesize numTanksPerReinforcement, reinforcementInterval;
@synthesize aiSkill;

-(id)initWithFile:(NSString*)filename
{
	if ((self = [super init])) {
		XScriptNode *script = [[XScriptNode alloc] initWithFile:filename]; assert(script);
		XScriptNode *root = [script getSubnodeByName:@"team"]; assert(root);
		
		teamName = [root getValue:0];
		[teamName retain];
		
		// load tanks
		tankTypeList = [[NSMutableArray alloc] init];
		NSArray *tankNodes = [root subnodesWithName:@"tank"];
		for (XScriptNode *tankNode in tankNodes) {
			NSString *tankFile = [@"Media/" stringByAppendingString:[tankNode getValue:0]];
			GTank *tank = [[GTank alloc] initWithFile:tankFile];
			tank.team = self;
			
			XScriptNode *node = [tankNode getSubnodeByName:@"texture"];
			if (node) {
				[tank setUnloadedTextures:[node getValue:0]];
			}
			
			[tankTypeList addObject:tank];
			[tank release];
		}
		
		// load outpost flag
		XScriptNode *node = [root getSubnodeByName:@"flag"];
		{
			NSString *flagPoleFile = [@"Media/" stringByAppendingString:[[node getSubnodeByName:@"pole_mesh"] getValue:0]];
			NSString *flagFile = [@"Media/" stringByAppendingString:[[node getSubnodeByName:@"flag_mesh"] getValue:0]];
			NSString *textureFile = [@"Media/" stringByAppendingString:[[node getSubnodeByName:@"texture"] getValue:0]];
			flagPoleMesh = [[XModel alloc] initWithFile:flagPoleFile usingMedia:gGame->commonMedia];
			flagMesh = [[XModel alloc] initWithFile:flagFile usingMedia:gGame->commonMedia];
			if (textureFile) {
				XTexture *flagTexture = [XTexture mediaRetainFile:textureFile usingMedia:gGame->mapMedia];
				[flagPoleMesh setUnloadedTextures:flagTexture];
				[flagMesh setUnloadedTextures:flagTexture];
				[flagTexture mediaRelease];
			}
		}
		
		[script release];
		
		maxTanks = 5;
		numTanksPerReinforcement = 2;
		reinforcementInterval = 30;
		reinforcementTimer = reinforcementInterval;
		
		aiSkill = AISkill_Expert;
	}
	return self;
}

-(void)dealloc
{
	[flagPoleMesh release];
	[flagMesh release];
	[teamName release];
	[tankTypeList release];
	[super dealloc];
}

-(void)setMaxTanks:(int)max
{
	maxTanks = max;
	numTanksPerReinforcement = ((float)max / 3.0f) + 0.5f;
	if (numTanksPerReinforcement < 2)
		numTanksPerReinforcement = 2;
}

-(int)maxTanks
{
	return maxTanks;
}

-(GTank*)spawnTankAt:(XVector2)pos;
{
	// ensure tank limit is not exceeded
	int tankCount = 0;
	for (GTank *tank in gGame->tankList) {
		if (tank.team == self)
			++tankCount;
	}
	if (tankCount >= maxTanks) {
		NSLog(@"Tank limit exceeded");
		return nil;
	}
	
	// spawn tank
	int i = rand() % tankTypeList.count;
	GTank *tankType = [tankTypeList objectAtIndex:i];
	GTank *spawnedTank = [tankType spawnAt:pos];
	return spawnedTank;
}

-(void)frameUpdate:(XSeconds)deltaTime
{
	// spawn tanks every interval
	reinforcementTimer += deltaTime;
	if (reinforcementTimer >= reinforcementInterval) {
		reinforcementTimer = 0;
		// list outposts owned by this team
		NSMutableArray *friendlyOutposts = [[NSMutableArray alloc] init];
		for (GOutpost *outpost in gGame->outpostList) {
			if (outpost.owningTeam == self && outpost.inConflict == NO)
				[friendlyOutposts addObject:outpost];
		}
		NSLog(@"%d reinforcements arrived for \"%@\" team, across %d outposts.", numTanksPerReinforcement, teamName, friendlyOutposts.count);
		if (friendlyOutposts.count > 0) {
			// spawn tanks
			for (int i = 0; i < numTanksPerReinforcement; ++i) {
				// pick an outpost
				int outpostID = rand() % friendlyOutposts.count;
				GOutpost *outpost = [friendlyOutposts objectAtIndex:outpostID];
				[outpost spawnTank];
			}
		}
		[friendlyOutposts release];
	}
}

-(void)saveStateToFile:(FILE*)file
{
	fwrite((void*)&reinforcementTimer, sizeof(reinforcementTimer), 1, file);
}

-(void)loadStateFromFile:(FILE*)file
{
	fread((void*)&reinforcementTimer, sizeof(reinforcementTimer), 1, file);
}


@end

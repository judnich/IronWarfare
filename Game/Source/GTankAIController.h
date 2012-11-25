// Copyright © 2010 John Judnich. All rights reserved.

#import "GGame.h"
#import "GTank.h"
@class GBullet;


typedef enum {
	AIState_None,
	AIState_Patrol,
	AIState_Hunt,
	AIState_Follow,
	AIState_Evade,
	AIState_Snipe
} GTankAIState;


typedef enum {
	AISkill_Rookie = 1,
	AISkill_Average = 2,
	AISkill_Expert = 3,
	AISkill_Flawless = 4,
} GTankAISkillLevel;


@interface GTankAIController : GTankController {
	GTankAISkillLevel skillLevel;
	GTank *__target;
	GTank *__leader;
	int frameCount;
	XAngle missYaw, missPitch;
	XAngle lookaroundYaw;
	XSeconds timeout, lookaround;
	XVector2 waypoint;
	XScalar desiredWaypointDist;
	XAngle heading;
	XSeconds headingTimer;
	GTankAIState state;
	BOOL backupRequested;
#ifdef DEBUG
	int debugCounter; //used for debug checks
#endif
}

@property(assign) GTankAISkillLevel skillLevel;
@property(assign) BOOL backupRequested;
@property(retain) GTank *leader;
@property(retain) GTank *target;

-(id)init;
-(void)dealloc;

@end

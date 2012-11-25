// Copyright © 2010 John Judnich. All rights reserved.

#import "GGame.h"
#import "GTank.h"


@interface GTankPlayerController : GTankController {
	XAngle aimYaw, aimPitch;
	XVector3 aimVector;
	float strafe;
	int moving;
	BOOL firing;
}

@property(assign) XVector3 aimVector;
@property(readonly) float strafe;
@property(readonly) int moving;
@property(readonly) BOOL firing;

-(id)init;

@end

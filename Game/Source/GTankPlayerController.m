// Copyright © 2010 John Judnich. All rights reserved.

#import "GTankPlayerController.h"
#import "GGame.h"
#import "GHUD.h"
#import "MMenu.h"


@implementation GTankPlayerController

@synthesize aimVector, strafe, moving, firing;

-(id)init
{
	if ((self = [super init])) {
	}
	return self;
}

-(BOOL)isComputerControlled
{
	return NO;
}

-(void)setControlTarget:(GTank*)target
{
	[super setControlTarget:target];
	if (target) {
		// calculate current aim vector
		XVector3 cAimVector;
		cAimVector.x = 0; cAimVector.y = 0; cAimVector.z = -1;
		cAimVector = xMul_Vec3Mat3(&cAimVector, target.barrelModel.globalRotation);
		aimYaw = xClampAngle(xATan2(-cAimVector.x, cAimVector.z));
		aimPitch = xClampAngle(xATan2(cAimVector.y, xSqrt(cAimVector.z*cAimVector.z + cAimVector.x*cAimVector.x)));
	}
}

-(void)notifyHitEnemyWithBullet:(GBullet*)bullet
{
	[gGame->hud notifyScoredHit];
}

-(void)notifyWasHitWithBullet:(GBullet*)bullet
{
	[gGame->hud notifyDamaged];
}

-(void)frameUpdate:(XSeconds)deltaTime
{
	if (!tank)
		return;
	
	GTankControls controls;
	XMatrix3 mat;

	// get touch controls (move vector, fire)
	const int steerBarHeight = 100;
	const int steerBarWidth = 200;
	const int middleSteerBar = steerBarWidth / 2;
	const int fireButtonWidth = 200;
	const int fireButtonHeight = 100;
	float mvecX = 0, mvecZ = 0;
	strafe = 0; moving = 0; firing = NO;
	for (int i = 0; i < gGame->numActiveTouches; ++i) {
		CGPoint touchPoint = gGame->activeTouches[i];
		if (touchPoint.y > 320 - steerBarHeight && touchPoint.x <= steerBarWidth) {
			mvecZ = 1.5 - (xAbs(touchPoint.x - middleSteerBar) / ((float)steerBarWidth * 0.25f));
			mvecX = (touchPoint.x - middleSteerBar) / ((float)steerBarWidth * 0.25f);
			mvecX = mvecX * xAbs(mvecX);
			strafe = xClamp((touchPoint.x - middleSteerBar) / ((float)steerBarWidth * 0.4f), -1, 1);
			moving = 1;
			/*if (touchPoint.y < 320 - steerBarHeight/2) {
				mvecZ = -mvecZ;
				//mvecX = -mvecX;
				moving = -moving;
			}*/
		}
		if (touchPoint.x > 480 - fireButtonWidth && touchPoint.y > 320 - fireButtonHeight) {
			firing = YES;
		}
	}
	controls.fire = firing;

	// calculate move vector
	XVector3 moveVec; moveVec.x = mvecX; moveVec.y = 0; moveVec.z = -mvecZ;
	xBuildYRotationMatrix3(&mat, aimYaw);
	moveVec = xMul_Vec3Mat3(&moveVec, &mat);
	XAngle destTankYaw = xClampAngle(xATan2(-moveVec.x, moveVec.z));
	
	// steer tank
	if (moving == 0) {
		controls.throttle = 0;
		controls.turn = 0;
	}
	else {
		XAngle deltayaw = xClampAngle(destTankYaw - tank.yaw);
		controls.turn = deltayaw * 3;
		XAngle aDeltayaw = xAbs(deltayaw);
		if (aDeltayaw < xDegToRad(140))
			controls.throttle = 1.0f;
		else
			controls.throttle = -0.5f;
	}
	
	// update aim yaw
	XAngle dyaw = -gGame->acceleration.y * (0.25f + deltaTime * 15); 
	if (deltaTime == 0.0f) dyaw = 0;
	dyaw = dyaw*xAbs(dyaw);
	if (dyaw > 1) dyaw = 1;
	if (dyaw < -1) dyaw = -1;
	aimYaw += dyaw;
	/*XAngle dyaw = -gGame->acceleration.y;
	dyaw = dyaw*xAbs(dyaw);
	if (dyaw > 0.5f) dyaw = 0.5f;
	if (dyaw < -0.5f) dyaw = -0.5f;
	aimYaw += dyaw * deltaTime * 15;*/
	aimYaw = xClampAngle(aimYaw);
	
	// update aim pitch with special filtering for accelerometer to avoid jitter
	XAngle angle = xClampAngle(PI - xATan2(gGame->acceleration.z, gGame->acceleration.x));
	//(if (angle > 0)
	//	angle = xClampAngle(angle + 180) + xDegToRad(100); // allows user to play game while laying on back
	//else
	angle -= gGame->menu.calibrationAngle;
	XAngle destpitch = angle;
	XScalar a = deltaTime * 2;
	aimPitch = aimPitch * (1-a) + destpitch * a;
	aimPitch = xClampAngle(aimPitch);

	// calculate aim vector
	aimVector.x = 0; aimVector.y = 0; aimVector.z = -1;
	xBuildXRotationMatrix3(&mat, aimPitch);
	aimVector = xMul_Vec3Mat3(&aimVector, &mat);
	xBuildYRotationMatrix3(&mat, aimYaw);
	aimVector = xMul_Vec3Mat3(&aimVector, &mat);
	xNormalize_Vec3(&aimVector);
	
	// calculate current aim vector
	XVector3 cAimVector;
	cAimVector.x = 0; cAimVector.y = 0; cAimVector.z = -1;
	cAimVector = xMul_Vec3Mat3(&cAimVector, tank.barrelModel.globalRotation);
	
	// extract current yaw
	XAngle cAimYaw = xClampAngle(xATan2(-cAimVector.x, cAimVector.z));
	XAngle deltaYaw = xClampAngle(aimYaw - cAimYaw);
	
	// extract current pitch
	XAngle cAimPitch = xClampAngle(xATan2(cAimVector.y, xSqrt(cAimVector.z*cAimVector.z + cAimVector.x*cAimVector.x)));
	XAngle deltaPitch = xClampAngle(aimPitch - cAimPitch);
	
	// aim
	controls.aimYaw = deltaYaw * 5;
	controls.aimPitch = -deltaPitch * 5;
	
	// set tank controls
	tank->controls = controls;
}

@end

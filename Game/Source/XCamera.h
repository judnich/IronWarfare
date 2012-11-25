// Copyright © 2010 John Judnich. All rights reserved.

#import "XMath.h"


@interface XCamera : NSObject {
@public
	XAngle fov;
	XScalar aspectRatio, nearClip, farClip;
	XVector3 origin, lookVector, upVector;
	XVector3 deltaOrigin;
	XMatrix4 projMatrix, viewMatrix;
@private
	XVector3 previousOrigin;
	XVector4 frustumPlanes[6];
}

-(id)init;

-(void)frameUpdate;
-(BOOL)isVisibleSphere:(XVector3*)center radius:(XScalar)radius;
-(BOOL)isVisibleBox:(XBoundingBox*)box;
-(BOOL)isVisibleBox:(XBoundingBox*)box boxOffset:(XVector3*)pos boxRotation:(XMatrix3*)rot;
-(BOOL)isVisibleBoxCorners:(XVector3*)cubeCorners;

-(XScalar)distanceTo:(XVector3*)point;
-(XScalar)distanceSquaredTo:(XVector3*)point;

-(BOOL)getScreenPositionOf:(XVector3*)point outPosition:(XVector2*)pixelPos; //returns NO if not on screen

@end

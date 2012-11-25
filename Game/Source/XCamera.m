// Copyright © 2010 John Judnich. All rights reserved.

#import "XCamera.h"


@implementation XCamera

-(id)init
{
	if ((self = [super init])) {
		fov = 60.0;
		aspectRatio = 320.0 / 480.0;
		nearClip = 0.01;
		farClip = 100.0;
		lookVector.z = -1;
		upVector.y = 1;
		[self frameUpdate];
	}
	return self;
}

-(void)frameUpdate
{	
	deltaOrigin.x = origin.x - previousOrigin.x;
	deltaOrigin.y = origin.y - previousOrigin.y;
	deltaOrigin.z = origin.z - previousOrigin.z;
	previousOrigin = origin;

	// normalize vectors
	xNormalize_Vec3(&lookVector);
	xNormalize_Vec3(&upVector);
	
	// calculate view projections
	XScalar left, right, bottom, top;
	xCalculateProjectionParameters(fov, aspectRatio, nearClip, farClip, &left, &right, &top, &bottom);
	xBuildProjectionMatrix(&projMatrix, left, right, top, bottom, nearClip, farClip);
	xBuildViewMatrix(&viewMatrix, &origin, &lookVector, &upVector);
	
	// calculate frustum planes
	XMatrix4 projMatrix2;
	xCalculateProjectionParameters(fov, 1.0/aspectRatio, nearClip, farClip, &left, &right, &top, &bottom);
	xBuildProjectionMatrix(&projMatrix2, left, right, top, bottom, nearClip, farClip);
	XMatrix4 mat;
	mat = xMul_Mat4Mat4(&projMatrix2, &viewMatrix);
	
	XVector4 *nearPlane = &frustumPlanes[0];
	XVector4 *leftPlane = &frustumPlanes[1];
	XVector4 *rightPlane = &frustumPlanes[2];
	XVector4 *farPlane = &frustumPlanes[3];
	XVector4 *bottomPlane = &frustumPlanes[4];
	XVector4 *topPlane = &frustumPlanes[5];
	// note: planes are assigned in order of probability to early-cull-out objects
	
    leftPlane->x = mat.m30 + mat.m00; leftPlane->y = mat.m31 + mat.m01; leftPlane->z = mat.m32 + mat.m02; leftPlane->w = mat.m33 + mat.m03;
    rightPlane->x = mat.m30 - mat.m00; rightPlane->y = mat.m31 - mat.m01; rightPlane->z = mat.m32 - mat.m02; rightPlane->w = mat.m33 - mat.m03;

    bottomPlane->x = mat.m30 + mat.m10; bottomPlane->y = mat.m31 + mat.m11; bottomPlane->z = mat.m32 + mat.m12; bottomPlane->w = mat.m33 + mat.m13;
    topPlane->x = mat.m30 - mat.m10; topPlane->y = mat.m31 - mat.m11; topPlane->z = mat.m32 - mat.m12; topPlane->w = mat.m33 - mat.m13;

    nearPlane->x = mat.m30 + mat.m20; nearPlane->y = mat.m31 + mat.m21; nearPlane->z = mat.m32 + mat.m22; nearPlane->w = mat.m33 + mat.m23;
    farPlane->x = mat.m30 - mat.m20; farPlane->y = mat.m31 - mat.m21; farPlane->z = mat.m32 - mat.m22; farPlane->w = mat.m33 - mat.m23;
	
	for (int p = 0; p < 6; ++p)
		xNormalizePlane_Vec4(&frustumPlanes[p]);
}

-(BOOL)isVisibleSphere:(XVector3*)center radius:(XScalar)radius
{
	for (int p = 0; p < 6; ++p)
	{
		XScalar distance = frustumPlanes[p].x * center->x + frustumPlanes[p].y * center->y + frustumPlanes[p].z * center->z + frustumPlanes[p].w;
		if (distance < -radius)
			return false;
	}
	return true;
}

-(BOOL)isVisibleBox:(XBoundingBox*)box
{
	XVector3 corners[8];
	corners[0].x = box->min.x; corners[0].y = box->min.y; corners[0].z = box->min.z;
	corners[1].x = box->max.x; corners[1].y = box->min.y; corners[1].z = box->min.z;
	corners[2].x = box->min.x; corners[2].y = box->max.y; corners[2].z = box->min.z;
	corners[3].x = box->max.x; corners[3].y = box->max.y; corners[3].z = box->min.z;
	corners[4].x = box->min.x; corners[4].y = box->min.y; corners[4].z = box->max.z;
	corners[5].x = box->max.x; corners[5].y = box->min.y; corners[5].z = box->max.z;
	corners[6].x = box->min.x; corners[6].y = box->max.y; corners[6].z = box->max.z;
	corners[7].x = box->max.x; corners[7].y = box->max.y; corners[7].z = box->max.z;
	return [self isVisibleBoxCorners:corners];
}

-(BOOL)isVisibleBox:(XBoundingBox*)box boxOffset:(XVector3*)pos boxRotation:(XMatrix3*)rot
{
	XVector3 corners[8];
	corners[0].x = box->min.x; corners[0].y = box->min.y; corners[0].z = box->min.z;
	corners[1].x = box->max.x; corners[1].y = box->min.y; corners[1].z = box->min.z;
	corners[2].x = box->min.x; corners[2].y = box->max.y; corners[2].z = box->min.z;
	corners[3].x = box->max.x; corners[3].y = box->max.y; corners[3].z = box->min.z;
	corners[4].x = box->min.x; corners[4].y = box->min.y; corners[4].z = box->max.z;
	corners[5].x = box->max.x; corners[5].y = box->min.y; corners[5].z = box->max.z;
	corners[6].x = box->min.x; corners[6].y = box->max.y; corners[6].z = box->max.z;
	corners[7].x = box->max.x; corners[7].y = box->max.y; corners[7].z = box->max.z;
	for (int i = 0; i < 8; ++i)
		corners[i] = xMul_Vec3Mat3(&corners[i], rot);
	for (int i = 0; i < 8; ++i)
		xAdd_Vec3Vec3(&corners[i], pos);
	return [self isVisibleBoxCorners:corners];
}

-(BOOL)isVisibleBoxCorners:(XVector3*)cubeCorners
{
	int totalIn = 0;
	
	// test all 8 corners against the 6 frustum planes 
	for (int p = 0; p < 6; ++p) {
		int inCount = 8;
		int ptIn = 1;
		
		for (int i = 0; i < 8; ++i) {
			// if point is behind plane...
			XScalar dist = frustumPlanes[p].x * cubeCorners[i].x
			             + frustumPlanes[p].y * cubeCorners[i].y
						 + frustumPlanes[p].z * cubeCorners[i].z + frustumPlanes[p].w;
			if (dist < 0) {
				ptIn = 0;
				--inCount;
			}
		}
		
		// if all points are behind 1 single plane, the box is not visible
		if (inCount == 0)
			return NO;
		
		// check if they were all on the right side of the plane
		totalIn += ptIn;
	}
	
	return YES;
}


-(XScalar)distanceTo:(XVector3*)point
{
	XVector3 vec;
	vec.x = point->x - origin.x;
	vec.y = point->y - origin.y;
	vec.z = point->z - origin.z;
	return xLength_Vec3(&vec);
}

-(XScalar)distanceSquaredTo:(XVector3*)point
{
	XVector3 vec;
	vec.x = point->x - origin.x;
	vec.y = point->y - origin.y;
	vec.z = point->z - origin.z;
	return xLengthSquared_Vec3(&vec);
}

-(BOOL)getScreenPositionOf:(XVector3*)point outPosition:(XVector2*)pixelPos
{
	XMatrix4 vMat; xBuildZRotationMatrix4(&vMat, xDegToRad(270));
	vMat = xMul_Mat4Mat4(&vMat, &viewMatrix);
	XVector3 vec = xMul_Vec3Mat4(point, &vMat);

	if (vec.z >= 0)
		return NO;
	
	XScalar tanHalfFov = xTan(xDegToRad(fov * 0.5f));
	XScalar tmpDiv = 1.0f / (-vec.z * tanHalfFov);
	XScalar y = vec.x * tmpDiv;	
	XScalar x = (vec.y * aspectRatio) * tmpDiv;
	x /= aspectRatio;
	y /= aspectRatio;
	y = 160 * y + 160;
	x = 240 * x + 240;
	
	pixelPos->x = x;
	pixelPos->y = y;
	
	if (pixelPos->x < 0 || pixelPos->y < 0 || pixelPos->x > 480 || pixelPos->y > 320)
		return NO;
	else return YES;
}


@end

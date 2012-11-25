// Copyright © 2009 John Judnich. All rights reserved.

#import <CoreFoundation/CoreFoundation.h>
#import <Foundation/Foundation.h>

#define DEG_TO_RAD 1.745329251994e-02
#define RAD_TO_DEG 57.295779513082322

typedef float XScalar;
typedef float XAngle;

typedef struct {
	int left, top, right, bottom;
} XIntRect;

typedef struct {
	XScalar left, top, right, bottom;
} XScalarRect;

typedef struct {
	XScalar x, y;
} XVector2;

typedef struct {
	XScalar x, y, z;
} XVector3;

typedef struct {
	XScalar x, y, z, w;
} XVector4;

typedef struct {
	XScalar m00, m10, m20;
	XScalar m01, m11, m21;
	XScalar m02, m12, m22;
} XMatrix3;

typedef struct {
	XScalar m00, m10, m20, m30;
	XScalar m01, m11, m21, m31;
	XScalar m02, m12, m22, m32;
	XScalar m03, m13, m23, m33;
} XMatrix4;

typedef struct {
	XVector3 min;
	XVector3 max;
} XBoundingBox;


static inline XAngle xDegToRad(XAngle degrees) { return degrees * DEG_TO_RAD; }
static inline XAngle xRadToDeg(XAngle radians) { return radians * RAD_TO_DEG; }
static inline XScalar xSqrt(XScalar val) { return sqrtf(val); }
static inline XScalar xSin(XAngle val) { return sinf(val); }
static inline XScalar xCos(XAngle val) { return cosf(val); }
static inline XScalar xTan(XAngle val) { return tanf(val); }
static inline XAngle xASin(XScalar val) { return asinf(val); }
static inline XAngle xACos(XScalar val) { return acosf(val); }
static inline XAngle xATan(XScalar val) { return atanf(val); }
static inline XAngle xATan2(XScalar y, XScalar x) { return atan2f(y, x); }
static inline XScalar xAbs(XScalar val) { return ABS(val); }

static inline XScalar* xMatrix3ToArray(XMatrix3 *mat) { return &(mat->m00); }
static inline XScalar* xMatrix4ToArray(XMatrix4 *mat) { return &(mat->m00); }

static inline BOOL xIsEqual_Vec3(XVector3 *vec1, XVector3 *vec2, XScalar epsilon)
{
	if (ABS(vec1->x - vec2->x) > epsilon)
		return NO;
	if (ABS(vec1->y - vec2->y) > epsilon)
		return NO;
	if (ABS(vec1->z - vec2->z) > epsilon)
		return NO;
	return YES;
}

static inline BOOL xIsEqual_Vec2(XVector2 *vec1, XVector2 *vec2, XScalar epsilon)
{
	if (ABS(vec1->x - vec2->x) > epsilon)
		return NO;
	if (ABS(vec1->y - vec2->y) > epsilon)
		return NO;
	return YES;
}

static inline XScalar xNormalize_Vec2(XVector2 *vec)
{
	XScalar vecLen = xSqrt(vec->x*vec->x + vec->y*vec->y);
	if (vecLen != 0) {
		XScalar invLen = 1.0 / vecLen;
		vec->x *= invLen;
		vec->y *= invLen;
	}
	return vecLen;
}

static inline XScalar xNormalize_Vec3(XVector3 *vec)
{
	XScalar vecLen = xSqrt(vec->x*vec->x + vec->y*vec->y + vec->z*vec->z);
	if (vecLen != 0) {
		XScalar invLen = 1.0 / vecLen;
		vec->x *= invLen;
		vec->y *= invLen;
		vec->z *= invLen;
	}
	return vecLen;
}

static inline XScalar xNormalize_Vec4(XVector4 *vec)
{
	XScalar vecLen = xSqrt(vec->x*vec->x + vec->y*vec->y + vec->z*vec->z + vec->w*vec->w);
	if (vecLen != 0) {
		XScalar invLen = 1.0 / vecLen;
		vec->x *= invLen;
		vec->y *= invLen;
		vec->z *= invLen;
		vec->w *= invLen;
	}
	return vecLen;
}

static inline void xNormalizePlane_Vec4(XVector4 *vec)
{
	XScalar invLen = 1.0 / xSqrt(vec->x*vec->x + vec->y*vec->y + vec->z*vec->z);
	vec->x *= invLen;
	vec->y *= invLen;
	vec->z *= invLen;
	vec->w *= invLen;
}

static inline XScalar xLength_Vec2(XVector2 *vec)
{
	return xSqrt(vec->x*vec->x + vec->y*vec->y);
}

static inline XScalar xLength_Vec3(XVector3 *vec)
{
	return xSqrt(vec->x*vec->x + vec->y*vec->y + vec->z*vec->z);
}

static inline XScalar xLength_Vec4(XVector4 *vec)
{
	return xSqrt(vec->x*vec->x + vec->y*vec->y + vec->z*vec->z + vec->w*vec->w);
}

static inline XScalar xLengthSquared_Vec2(XVector2 *vec)
{
	return (vec->x*vec->x + vec->y*vec->y);
}

static inline XScalar xLengthSquared_Vec3(XVector3 *vec)
{
	return (vec->x*vec->x + vec->y*vec->y + vec->z*vec->z);
}

static inline XScalar xLengthSquared_Vec4(XVector4 *vec)
{
	return (vec->x*vec->x + vec->y*vec->y + vec->z*vec->z + vec->w*vec->w);
}

static inline void xAdd_Vec3Vec3(XVector3 *vec1, XVector3 *vec2)
{
	vec1->x += vec2->x;
	vec1->y += vec2->y;
	vec1->z += vec2->z;
}

static inline void xSub_Vec3Vec3(XVector3 *vec1, XVector3 *vec2)
{
	vec1->x -= vec2->x;
	vec1->y -= vec2->y;
	vec1->z -= vec2->z;
}

static inline void xMul_Vec3Vec3(XVector3 *vec1, XVector3 *vec2)
{
	vec1->x *= vec2->x;
	vec1->y *= vec2->y;
	vec1->z *= vec2->z;
}

static inline XVector3 xCrossProduct_Vec3(XVector3 *vec1, XVector3 *vec2)
{
	XVector3 r;
	r.x = vec1->y*vec2->z - vec1->z*vec2->y;
	r.y = vec1->z*vec2->x - vec1->x*vec2->z;
	r.z = vec1->x*vec2->y - vec1->y*vec2->x;
	return r;
}

static inline XScalar xDotProduct_Vec3(XVector3 *vec1, XVector3 *vec2)
{
	return vec1->x * vec2->x + vec1->y * vec2->y + vec1->z * vec2->z;
}

static inline XScalar xDotProduct_Vec2(XVector2 *vec1, XVector2 *vec2)
{
	return vec1->x * vec2->x + vec1->y * vec2->y;
}

XVector3 xMul_Vec3Mat3(XVector3 *vec, XMatrix3 *mat);
XVector4 xMul_Vec4Mat4(XVector4 *vec, XMatrix4 *mat);
XVector3 xMul_Vec3Mat4(XVector3 *vec, XMatrix4 *mat);

XMatrix3 xMul_Mat3Mat3(XMatrix3 *mat1, XMatrix3 *mat2);
XMatrix4 xMul_Mat4Mat4(XMatrix4 *mat1, XMatrix4 *mat2);

void xBuildZeroMatrix3(XMatrix3 *mat);
void xBuildZeroMatrix4(XMatrix4 *mat);
void xBuildIdentityMatrix3(XMatrix3 *mat);
void xBuildIdentityMatrix4(XMatrix4 *mat);

void xBuildTranslationMatrix(XMatrix4 *mat, XVector3 *translate);
void xBuildScaleMatrix(XMatrix4 *mat, XVector3 *scale);

void xBuildXRotationMatrix3(XMatrix3 *mat, XAngle angle);
void xBuildXRotationMatrix4(XMatrix4 *mat, XAngle angle);
void xBuildYRotationMatrix3(XMatrix3 *mat, XAngle angle);
void xBuildYRotationMatrix4(XMatrix4 *mat, XAngle angle);
void xBuildZRotationMatrix3(XMatrix3 *mat, XAngle angle);
void xBuildZRotationMatrix4(XMatrix4 *mat, XAngle angle);

void xCalculateProjectionParameters(XAngle fov, XScalar aspectRatio, XScalar nearClip, XScalar farClip, XScalar *left, XScalar *right, XScalar *top, XScalar *bottom);
void xBuildProjectionMatrix(XMatrix4 *mat, XScalar left, XScalar right, XScalar top, XScalar bottom, XScalar near, XScalar far);
void xBuildViewMatrix(XMatrix4 *mat, XVector3 *origin, XVector3 *lookVector, XVector3 *upVector); //assumes all vectors are normalized

void xBuildMatrix4FromMatrix3(XMatrix4 *dest, XMatrix3 *src);


XVector3 xCenter_BoundingBox(XBoundingBox *bb);




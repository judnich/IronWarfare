// Copyright © 2010 John Judnich. All rights reserved.

#import "XMath.h"


XVector3 xMul_Vec3Mat3(XVector3 *vec, XMatrix3 *mat)
{
	XVector3 r;
	r.x = mat->m00*vec->x + mat->m01*vec->y + mat->m02*vec->z;
	r.y = mat->m10*vec->x + mat->m11*vec->y + mat->m12*vec->z;
	r.z = mat->m20*vec->x + mat->m21*vec->y + mat->m22*vec->z;
	return r;
}

XVector4 xMul_Vec4Mat4(XVector4 *vec, XMatrix4 *mat)
{
	XVector4 r;
	r.x = mat->m00*vec->x + mat->m01*vec->y + mat->m02*vec->z + mat->m03*vec->w;
	r.y = mat->m10*vec->x + mat->m11*vec->y + mat->m12*vec->z + mat->m13*vec->w;
	r.z = mat->m20*vec->x + mat->m21*vec->y + mat->m22*vec->z + mat->m23*vec->w;
	r.w = mat->m30*vec->x + mat->m31*vec->y + mat->m32*vec->z + mat->m33*vec->w;
	return r;
}

XVector3 xMul_Vec3Mat4(XVector3 *vec, XMatrix4 *mat)
{
	XVector3 r;
	r.x = mat->m00*vec->x + mat->m01*vec->y + mat->m02*vec->z + mat->m03;
	r.y = mat->m10*vec->x + mat->m11*vec->y + mat->m12*vec->z + mat->m13;
	r.z = mat->m20*vec->x + mat->m21*vec->y + mat->m22*vec->z + mat->m23;
	return r;
}

XMatrix3 xMul_Mat3Mat3(XMatrix3 *mat1, XMatrix3 *mat2)
{
    XMatrix3 r;
	
	r.m00 = mat1->m00*mat2->m00 + mat1->m01*mat2->m10 + mat1->m02*mat2->m20;
	r.m10 = mat1->m10*mat2->m00 + mat1->m11*mat2->m10 + mat1->m12*mat2->m20;
	r.m20 = mat1->m20*mat2->m00 + mat1->m21*mat2->m10 + mat1->m22*mat2->m20;
	
	r.m01 = mat1->m00*mat2->m01 + mat1->m01*mat2->m11 + mat1->m02*mat2->m21;
	r.m11 = mat1->m10*mat2->m01 + mat1->m11*mat2->m11 + mat1->m12*mat2->m21;
	r.m21 = mat1->m20*mat2->m01 + mat1->m21*mat2->m11 + mat1->m22*mat2->m21;
 
	r.m02 = mat1->m00*mat2->m02 + mat1->m01*mat2->m12 + mat1->m02*mat2->m22;
	r.m12 = mat1->m10*mat2->m02 + mat1->m11*mat2->m12 + mat1->m12*mat2->m22;
	r.m22 = mat1->m20*mat2->m02 + mat1->m21*mat2->m12 + mat1->m22*mat2->m22;
 
	return r;
}

XMatrix4 xMul_Mat4Mat4(XMatrix4 *mat1, XMatrix4 *mat2)
{
	XMatrix4 r;
	
    r.m00 = mat1->m00*mat2->m00 + mat1->m01*mat2->m10 + mat1->m02*mat2->m20 + mat1->m03*mat2->m30;
    r.m10 = mat1->m10*mat2->m00 + mat1->m11*mat2->m10 + mat1->m12*mat2->m20 + mat1->m13*mat2->m30;
    r.m20 = mat1->m20*mat2->m00 + mat1->m21*mat2->m10 + mat1->m22*mat2->m20 + mat1->m23*mat2->m30;
    r.m30 = mat1->m30*mat2->m00 + mat1->m31*mat2->m10 + mat1->m32*mat2->m20 + mat1->m33*mat2->m30;
	
    r.m01 = mat1->m00*mat2->m01 + mat1->m01*mat2->m11 + mat1->m02*mat2->m21 + mat1->m03*mat2->m31;
    r.m11 = mat1->m10*mat2->m01 + mat1->m11*mat2->m11 + mat1->m12*mat2->m21 + mat1->m13*mat2->m31;
    r.m21 = mat1->m20*mat2->m01 + mat1->m21*mat2->m11 + mat1->m22*mat2->m21 + mat1->m23*mat2->m31;
    r.m31 = mat1->m30*mat2->m01 + mat1->m31*mat2->m11 + mat1->m32*mat2->m21 + mat1->m33*mat2->m31;
	
    r.m02 = mat1->m00*mat2->m02 + mat1->m01*mat2->m12 + mat1->m02*mat2->m22 + mat1->m03*mat2->m32;
    r.m12 = mat1->m10*mat2->m02 + mat1->m11*mat2->m12 + mat1->m12*mat2->m22 + mat1->m13*mat2->m32;
    r.m22 = mat1->m20*mat2->m02 + mat1->m21*mat2->m12 + mat1->m22*mat2->m22 + mat1->m23*mat2->m32;
    r.m32 = mat1->m30*mat2->m02 + mat1->m31*mat2->m12 + mat1->m32*mat2->m22 + mat1->m33*mat2->m32;
	
    r.m03 = mat1->m00*mat2->m03 + mat1->m01*mat2->m13 + mat1->m02*mat2->m23 + mat1->m03*mat2->m33;
    r.m13 = mat1->m10*mat2->m03 + mat1->m11*mat2->m13 + mat1->m12*mat2->m23 + mat1->m13*mat2->m33;
    r.m23 = mat1->m20*mat2->m03 + mat1->m21*mat2->m13 + mat1->m22*mat2->m23 + mat1->m23*mat2->m33;
    r.m33 = mat1->m30*mat2->m03 + mat1->m31*mat2->m13 + mat1->m32*mat2->m23 + mat1->m33*mat2->m33;
	
    return r;
}


void xBuildIdentityMatrix3(XMatrix3 *mat)
{
	mat->m00 = 1.0f; mat->m01 = 0.0f; mat->m02 = 0.0f;
	mat->m10 = 0.0f; mat->m11 = 1.0f; mat->m12 = 0.0f;
	mat->m20 = 0.0f; mat->m21 = 0.0f; mat->m22 = 1.0f;
}

void xBuildIdentityMatrix4(XMatrix4 *mat)
{
	mat->m00 = 1.0f; mat->m01 = 0.0f; mat->m02 = 0.0f; mat->m03 = 0.0f;
	mat->m10 = 0.0f; mat->m11 = 1.0f; mat->m12 = 0.0f; mat->m13 = 0.0f;
	mat->m20 = 0.0f; mat->m21 = 0.0f; mat->m22 = 1.0f; mat->m23 = 0.0f;
	mat->m30 = 0.0f; mat->m31 = 0.0f; mat->m32 = 0.0f; mat->m33 = 1.0f;
}

void xBuildZeroMatrix3(XMatrix3 *mat)
{
	mat->m00 = 0.0f; mat->m01 = 0.0f; mat->m02 = 0.0f;
	mat->m10 = 0.0f; mat->m11 = 0.0f; mat->m12 = 0.0f;
	mat->m20 = 0.0f; mat->m21 = 0.0f; mat->m22 = 0.0f;
}

void xBuildZeroMatrix4(XMatrix4 *mat)
{
	mat->m00 = 0.0f; mat->m01 = 0.0f; mat->m02 = 0.0f; mat->m03 = 0.0f;
	mat->m10 = 0.0f; mat->m11 = 0.0f; mat->m12 = 0.0f; mat->m13 = 0.0f;
	mat->m20 = 0.0f; mat->m21 = 0.0f; mat->m22 = 0.0f; mat->m23 = 0.0f;
	mat->m30 = 0.0f; mat->m31 = 0.0f; mat->m32 = 0.0f; mat->m33 = 0.0f;
}

void xBuildTranslationMatrix(XMatrix4 *mat, XVector3 *translate)
{
	mat->m00 = 1.0f; mat->m01 = 0.0f; mat->m02 = 0.0f; mat->m03 = translate->x;
	mat->m10 = 0.0f; mat->m11 = 1.0f; mat->m12 = 0.0f; mat->m13 = translate->y;
	mat->m20 = 0.0f; mat->m21 = 0.0f; mat->m22 = 1.0f; mat->m23 = translate->z;
	mat->m30 = 0.0f; mat->m31 = 0.0f; mat->m32 = 0.0f; mat->m33 = 1.0f;
}

void xBuildScaleMatrix(XMatrix4 *mat, XVector3 *scale)
{
	mat->m00 = scale->x; mat->m01 = 0.0; mat->m02 = 0.0; mat->m03 = 0.0;
	mat->m10 = 0.0; mat->m11 = scale->y; mat->m12 = 0.0; mat->m13 = 0.0;
	mat->m20 = 0.0; mat->m21 = 0.0; mat->m22 = scale->z; mat->m23 = 0.0;
	mat->m30 = 0.0; mat->m31 = 0.0; mat->m32 = 0.0; mat->m33 = 1.0;
}

void xBuildXRotationMatrix3(XMatrix3 *mat, XAngle angle)
{
	float sin = xSin(angle);
	float cos = xCos(angle);
	mat->m00 = 1.0f; mat->m01 = 0.0f; mat->m02 = 0.0f;
	mat->m10 = 0.0f; mat->m11 = cos; mat->m12 = sin;
	mat->m20 = 0.0f; mat->m21 = -sin; mat->m22 = cos;
}

void xBuildXRotationMatrix4(XMatrix4 *mat, XAngle angle)
{
	float sin = xSin(angle);
	float cos = xCos(angle);
	mat->m00 = 1.0f; mat->m01 = 0.0f; mat->m02 = 0.0f; mat->m03 = 0.0f;
	mat->m10 = 0.0f; mat->m11 = cos; mat->m12 = sin; mat->m13 = 0.0f;
	mat->m20 = 0.0f; mat->m21 = -sin; mat->m22 = cos; mat->m23 = 0.0f;
	mat->m30 = 0.0f; mat->m31 = 0.0f; mat->m32 = 0.0f; mat->m33 = 1.0f;
}

void xBuildYRotationMatrix3(XMatrix3 *mat, XAngle angle)
{
	float sin = xSin(angle);
	float cos = xCos(angle);
	mat->m00 = cos; mat->m01 = 0.0f; mat->m02 = -sin;
	mat->m10 = 0.0f; mat->m11 = 1.0f; mat->m12 = 0.0f;
	mat->m20 = sin; mat->m21 = 0.0f; mat->m22 = cos;
}

void xBuildYRotationMatrix4(XMatrix4 *mat, XAngle angle)
{
	float sin = xSin(angle);
	float cos = xCos(angle);
	mat->m00 = cos; mat->m01 = 0.0f; mat->m02 = -sin; mat->m03 = 0.0f;
	mat->m10 = 0.0f; mat->m11 = 1.0f; mat->m12 = 0.0f; mat->m13 = 0.0f;
	mat->m20 = sin; mat->m21 = 0.0f; mat->m22 = cos; mat->m23 = 0.0f;
	mat->m30 = 0.0f; mat->m31 = 0.0f; mat->m32 = 0.0f; mat->m33 = 1.0f;
}

void xBuildZRotationMatrix3(XMatrix3 *mat, XAngle angle)
{
	float sin = xSin(angle);
	float cos = xCos(angle);
	mat->m00 = cos; mat->m01 = sin; mat->m02 = 0.0f;
	mat->m10 = -sin; mat->m11 = cos; mat->m12 = 0.0f;
	mat->m20 = 0.0f; mat->m21 = 0.0f; mat->m22 = 1.0f;
}

void xBuildZRotationMatrix4(XMatrix4 *mat, XAngle angle)
{
	float sin = xSin(angle);
	float cos = xCos(angle);
	mat->m00 = cos; mat->m01 = sin; mat->m02 = 0.0f; mat->m03 = 0.0f;
	mat->m10 = -sin; mat->m11 = cos; mat->m12 = 0.0f; mat->m13 = 0.0f;
	mat->m20 = 0.0f; mat->m21 = 0.0f; mat->m22 = 1.0f; mat->m23 = 0.0f;
	mat->m30 = 0.0f; mat->m31 = 0.0f; mat->m32 = 0.0f; mat->m33 = 1.0f;
}

void xBuildAxisRotationMatrix3(XMatrix3 *mat, XAngle angle, XVector3 *axis)
{
	XScalar fCos = xCos(angle);
	XScalar fSin = xSin(angle);
	XScalar fOneMinusCos = 1.0-fCos;
	XScalar fX2 = axis->x * axis->x;
	XScalar fY2 = axis->y * axis->y;
	XScalar fZ2 = axis->z * axis->z;
	XScalar fXYM = axis->x * axis->y*fOneMinusCos;
	XScalar fXZM = axis->x * axis->z*fOneMinusCos;
	XScalar fYZM = axis->y * axis->z*fOneMinusCos;
	XScalar fXSin = axis->x * fSin;
	XScalar fYSin = axis->y * fSin;
	XScalar fZSin = axis->z * fSin;
	mat->m00 = fX2*fOneMinusCos + fCos;
	mat->m01 = fXYM - fZSin;
	mat->m02 = fXZM + fYSin;
	mat->m10 = fXYM + fZSin;
	mat->m11 = fY2*fOneMinusCos + fCos;
	mat->m12 = fYZM - fXSin;
	mat->m20 = fXZM - fYSin;
	mat->m21 = fYZM + fXSin;
	mat->m22 = fZ2*fOneMinusCos + fCos;
}

void xCalculateProjectionParameters(XAngle fov, XScalar aspectRatio, XScalar nearClip, XScalar farClip, XScalar *left, XScalar *right, XScalar *top, XScalar *bottom)
{
	/*XAngle thetaY = xDegToRad(fov) * 0.5;
	XScalar tanThetaY = xTan(thetaY);
	XScalar tanThetaX = tanThetaY * aspectRatio;
	
	XScalar focalLength = 1.0;
	XScalar frustumOffsetX = 0, frustumOffsetY = 0;
	XScalar nearFocal = nearClip / focalLength;
	XScalar nearOffsetX = frustumOffsetX * nearFocal;
	XScalar nearOffsetY = frustumOffsetY * nearFocal;
	XScalar half_w = tanThetaX * nearClip;
	XScalar half_h = tanThetaY * nearClip;
	
	*left = - half_w + nearOffsetX;
	*right = + half_w + nearOffsetX;
	*bottom = - half_h + nearOffsetY;
	*top = + half_h + nearOffsetY;*/
	
	*top = xTan(xDegToRad(fov)*0.5) * nearClip;
	*bottom = -*top;
	*left = aspectRatio * *bottom;
	*right = aspectRatio * *top;
}

void xBuildProjectionMatrix(XMatrix4 *mat, XScalar left, XScalar right, XScalar top, XScalar bottom, XScalar near, XScalar far)
{
	// calculate matrix elements
	XScalar inv_w = 1 / (right - left);
	XScalar inv_h = 1 / (top - bottom);
	XScalar inv_d = 1 / (far - near);
	XScalar A = 2 * near * inv_w;
	XScalar B = 2 * near * inv_h;
	XScalar C = (right + left) * inv_w;
	XScalar D = (top + bottom) * inv_h;
	XScalar q = -(far + near) * inv_d;
	XScalar qn = -2 * (far * near) * inv_d;
	
	// uniform perspective projection matrix,
	// depth range [-1,1], right-handed rules
	xBuildZeroMatrix4(mat);
	mat->m00 = A;
	mat->m02 = C;
	mat->m11 = B;
	mat->m12 = D;
	mat->m22 = q;
	mat->m23 = qn;
	mat->m32 = -1;
	
	/*XScalar A = (right + left) / (right - left);
	XScalar B = (top + bottom) / (top - bottom);
	XScalar C = -(far + near) / (far - near);
	XScalar D = -(2 * far * near) / (far - near);
	
	xBuildZeroMatrix4(mat);
	mat->m00 = (2 * near) / (right - left);
	mat->m11 = (2 * near) / (top - bottom);
	mat->m02 = A;
	mat->m12 = B;
	mat->m22 = C;
	mat->m32 = -1;
	mat->m23 = D;*/
}

void xBuildViewMatrix(XMatrix4 *mat, XVector3 *origin, XVector3 *lookVector, XVector3 *upVector)
{
	XVector3 right = xCrossProduct_Vec3(lookVector, upVector);
	XVector3 up = xCrossProduct_Vec3(&right, lookVector);
	xNormalize_Vec3(&right);
	xNormalize_Vec3(&up);
	
	XMatrix4 rMat;
	rMat.m00 = right.x; rMat.m01 = right.y; rMat.m02 = right.z; rMat.m03 = 0.0f;
	rMat.m10 = up.x; rMat.m11 = up.y; rMat.m12 = up.z; rMat.m13 = 0.0f;
	rMat.m20 = -lookVector->x; rMat.m21 = -lookVector->y; rMat.m22 = -lookVector->z; rMat.m23 = 0.0f;
	rMat.m30 = 0.0f; rMat.m31 = 0.0f; rMat.m32 = 0.0f; rMat.m33 = 1.0f;
	
	XMatrix4 tMat;
	tMat.m00 = 1.0f; tMat.m01 = 0.0f; tMat.m02 = 0.0f; tMat.m03 = -origin->x;
	tMat.m10 = 0.0f; tMat.m11 = 1.0f; tMat.m12 = 0.0f; tMat.m13 = -origin->y;
	tMat.m20 = 0.0f; tMat.m21 = 0.0f; tMat.m22 = 1.0f; tMat.m23 = -origin->z;
	tMat.m30 = 0.0f; tMat.m31 = 0.0f; tMat.m32 = 0.0f; tMat.m33 = 1.0f;
	
	*mat = xMul_Mat4Mat4(&rMat, &tMat);
}

void xBuildMatrix4FromMatrix3(XMatrix4 *dest, XMatrix3 *src)
{
	dest->m00 = src->m00; dest->m01 = src->m01; dest->m02 = src->m02; dest->m03 = 0.0f;
	dest->m10 = src->m10; dest->m11 = src->m11; dest->m12 = src->m12; dest->m13 = 0.0f;
	dest->m20 = src->m20; dest->m21 = src->m21; dest->m22 = src->m22; dest->m23 = 0.0f;
	dest->m30 = 0.0f; dest->m31 = 0.0f; dest->m32 = 0.0f; dest->m33 = 1.0f;
}

XMatrix3 xInvert_Matrix3(XMatrix3 *mat)
{
	XMatrix3 inverse;
	inverse.m00 = mat->m11*mat->m22 - mat->m12*mat->m21;
	inverse.m01 = mat->m02*mat->m21 - mat->m01*mat->m22;
	inverse.m02 = mat->m01*mat->m12 - mat->m02*mat->m11;
	inverse.m10 = mat->m12*mat->m20 - mat->m10*mat->m22;
	inverse.m11 = mat->m00*mat->m22 - mat->m02*mat->m20;
	inverse.m12 = mat->m02*mat->m10 - mat->m00*mat->m12;
	inverse.m20 = mat->m10*mat->m21 - mat->m11*mat->m20;
	inverse.m21 = mat->m01*mat->m20 - mat->m00*mat->m21;
	inverse.m22 = mat->m00*mat->m11 - mat->m01*mat->m10;
		
	XScalar det = mat->m00*inverse.m00 + mat->m01*inverse.m10+ mat->m02*inverse.m20;
	
    XScalar invDet = 1.0f / det;
	inverse.m00 *= invDet; inverse.m10 *= invDet; inverse.m20 *= invDet;
	inverse.m01 *= invDet; inverse.m11 *= invDet; inverse.m21 *= invDet;
	inverse.m02 *= invDet; inverse.m12 *= invDet; inverse.m22 *= invDet;
	
	return inverse;
}


XVector3 xCenter_BoundingBox(XBoundingBox *bb)
{
	XVector3 center;
	center.x = (bb->min.x + bb->max.x) * 0.5f;
	center.y = (bb->min.y + bb->max.y) * 0.5f;
	center.z = (bb->min.z + bb->max.z) * 0.5f;
	return center;
}

XVector3 xSize_BoundingBox(XBoundingBox *bb)
{
	XVector3 size;
	size.x = (bb->max.x - bb->min.x);
	size.y = (bb->max.y - bb->min.y);
	size.z = (bb->max.z - bb->min.z);
	return size;
}



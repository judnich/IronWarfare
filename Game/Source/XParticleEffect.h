// Copyright © 2010 John Judnich. All rights reserved.

#import "XMath.h"
#import "XMediaGroup.h"
#import "XGL.h"
@class XTexture;


typedef struct {
	int emitCount; //number of particles to emit per emission
	XBoundingBox emitBox; //a box in which the emitted particles will be randomely placed
	XVector3 minVelocity, maxVelocity; //random velocity ranges
	XScalar minGravity, maxGravity; //random gravity ranges
	XAngle minAngle, maxAngle; //random initial angles
	XAngle minRotateSpeed, maxRotateSpeed; //random angular velocity ranges
	XScalar minScale, maxScale; //random scale range
	XScalar minScaleSpeed, maxScaleSpeed; //random scale change speed range
	XColorBytes minColor, maxColor; //color range
	float startAlpha, endAlpha;
	XSeconds minLife, maxLife; //particle life range
} XParticleEmissionData;


@interface XParticleEffect : XResource {
@public
	int totalParticlesToEmit;
	XParticleEmissionData *emissionArray;
	int numEmissions;
	XTexture *texture;
	XBlendMode blendMode;	
}

-(id)initWithFile:(NSString*)filename usingMedia:(XMediaGroup*)media;
-(void)dealloc;

@end

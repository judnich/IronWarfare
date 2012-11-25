// Copyright © 2010 John Judnich. All rights reserved.

#import "XNode.h"
#import "XMediaGroup.h"
@class XTexture;
@class GTank;


@interface GBulletType : XResource {
	unsigned int glVertexBuffer, glIndexBuffer;
	size_t glVertexCount, glIndexCount;
	XTexture *texture;
}

@property(readonly) unsigned int glVertexBuffer, glIndexBuffer;
@property(readonly) size_t glVertexCount, glIndexCount;
@property(readonly) XTexture *texture;

-(id)initWithFile:(NSString*)filename usingMedia:(XMediaGroup*)media;
-(void)dealloc;

@end


@interface GBullet : XNode {
	GBulletType *type;
	XAngle rotationAngle;
	GTank *__originator;
@public
	XSeconds bulletLife;
	XVector3 startPosition;
	XVector3 startVelocity;
	XScalar gravity;
	float damagePower;
	XScalar collisionRadius;
	BOOL active;
}

@property(retain) GTank *originator;
@property(readonly) XVector3 currentVelocity;
@property(readonly) XVector3 currentPosition;

-(id)initWithType:(GBulletType*)bulletType;
-(void)dealloc;

-(void)reinit;
-(BOOL)frameUpdate:(XSeconds)deltaTime; //returns false if destroyed

@end


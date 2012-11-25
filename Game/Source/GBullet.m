// Copyright © 2010 John Judnich. All rights reserved.

#import "GBullet.h"
#import "GGame.h"
#import "GTank.h"
#import "XTexture.h"
#import "XGL.h"
#import "XTerrain.h"
#import "XParticleSystem.h"
#import "GSoundPool.h"


typedef struct {
	XVector3 position;
	XVector2 texcoord;
} GBulletVertex;

typedef GLubyte GBulletIndex;


@implementation GBulletType

@synthesize glVertexBuffer, glIndexBuffer, glVertexCount, glIndexCount, texture;

-(id)initWithFile:(NSString*)filename usingMedia:(XMediaGroup*)media
{
	if ((self = [super initWithFile:filename usingMedia:media])) {
		texture = [XTexture mediaRetainFile:filename usingMedia:media];
		
		const float vBuffArray[] = {
			0, 0, 5,  0.5f, 1,
			-.3, 0, -5,  0, 0,
			.3, 0, -5,  1, 0,
			0, -.3, -5,  0, 0,
			0, .3, -5,  1, 0
		};
		glVertexCount = 5;
		glGenBuffers(1, &glVertexBuffer);
		glBindBuffer(GL_ARRAY_BUFFER, glVertexBuffer);
		glBufferData(GL_ARRAY_BUFFER, glVertexCount * sizeof(GBulletVertex), vBuffArray, GL_STATIC_DRAW);
		glBindBuffer(GL_ARRAY_BUFFER, 0);			
		
		const GBulletIndex iBuffArray[] = {
			0, 1, 2,
			0, 3, 4
		};
		glIndexCount = 6;
		glGenBuffers(1, &glIndexBuffer);
		glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, glIndexBuffer);
		glBufferData(GL_ELEMENT_ARRAY_BUFFER, glIndexCount * sizeof(GBulletIndex), iBuffArray, GL_STATIC_DRAW);
		glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
	}
	return self;
}

-(void)dealloc
{
	glDeleteBuffers(1, &glVertexBuffer);
	glDeleteBuffers(1, &glIndexBuffer);
	[texture mediaRelease];
	[super dealloc];
}

@end


@implementation GBullet

-(id)initWithType:(GBulletType*)bulletType
{
	if ((self = [super init])) {
		bulletLife = 0;
		active = YES;
		collisionRadius = 0;
		
		type = bulletType;
		[type mediaRetain];
		
		boundingBox.min.x = -1; boundingBox.min.y = -1; boundingBox.min.z = -5;
		boundingBox.max.x = 1; boundingBox.max.y = 1; boundingBox.max.z = 5;
		[self notifyBoundsChanged];
		useBoundingSphereOnly = YES;
	}
	return self;
}

-(void)dealloc
{
	self.originator = nil;
	[type mediaRelease];
	[super dealloc];
}

-(void)reinit
{
	self.originator = nil;
	self.scene = nil;
	bulletLife = 0;
	active = YES;
	collisionRadius = 0;
}

-(void)setOriginator:(GTank*)tank
{
	[__originator release];
	__originator = tank;
	[__originator retain];
}

-(GTank*)originator
{
	return __originator;
}

-(BOOL)frameUpdate:(XSeconds)deltaTime
{
	// trajectory update
	bulletLife += deltaTime;
	position.x = startPosition.x + startVelocity.x * bulletLife;
	position.y = startPosition.y + startVelocity.y * bulletLife - (gravity*0.5f) * bulletLife * bulletLife;
	position.z = startPosition.z + startVelocity.z * bulletLife;
	
	// point bullet mesh towards it's view-relative direction (for correct streak effect)
	XVector3 cameraSpeed = gGame->camera->deltaOrigin;
	xMul_Vec3Scalar(&cameraSpeed, 1.0f / deltaTime);
	XVector3 motionVector;
	motionVector.x = startVelocity.x - cameraSpeed.x;
	motionVector.y = (startVelocity.y - gravity * bulletLife) - cameraSpeed.y;
	motionVector.z = startVelocity.z - cameraSpeed.z;
	xNormalize_Vec3(&motionVector);
	
	XVector3 up; up.x = 0; up.y = 1; up.z = 0;
	XVector3 right = xCrossProduct_Vec3(&motionVector, &up);
	xNormalize_Vec3(&right);
	up = xCrossProduct_Vec3(&right, &motionVector);
	XMatrix3 *mat = &rotation;
	mat->m00 = right.x; mat->m10 = right.y; mat->m20 = right.z;
	mat->m01 = up.x; mat->m11 = up.y; mat->m21 = up.z;
	mat->m02 = -motionVector.x; mat->m12 = -motionVector.y; mat->m22 = -motionVector.z;
	
	[self notifyTransformsChanged];
	
	// check ground collision
	XTerrainIntersection intersect = [gGame->terrain intersectTerrainVerticallyAt:&position];
	if (position.y <= intersect.point.y) {
		active = NO;
		// make dust cloud
		if (self.originator) {
			XScalar camDistSq = [gGame->camera distanceSquaredTo:&intersect.point];
			
			XParticleEffect *effect;
			if (camDistSq < 150*150)
				effect = self.originator->groundImpactEffect_high;
			else if (camDistSq < 300*300)
				effect = self.originator->groundImpactEffect_medium;
			else
				effect = self.originator->groundImpactEffect_low;
			
			float light = xSaturate([gGame->terrain sampleTerrainLightmapAt:&intersect.point] * 4 - 0.3f);			
			XParticleSystem *particles = [[XParticleSystem alloc] initWithEffect:effect andShade:light];
			particles->position = intersect.point;
			[particles notifyTransformsChanged];
			[particles beginAnimation];
			particles.scene = gGame->scene;
			[gGame->particlesPool addObject:particles];
			[particles release];
		}
		// sound effect
		[gGame->soundPool playImpactSoundAt:&intersect.point forcePlay:NO];
	}
	XBoundingBox *tbb = &gGame->terrain->boundingBox;
	if (position.x < tbb->min.x || position.z < tbb->min.z || position.x > tbb->max.x || position.z > tbb->max.z) {
		active = NO;
	}
	
	// check if originator was destroyed
	if (self.originator.armor <= 0)
		self.originator = nil;
	
	// check tank collision
	if (active) { //make sure it does not hit more than once
		XVector3 thisPosition = position;
		for (GTank *tank in gGame->tankList) {
			if (tank.team != self.originator.team) {
				//calculate distance to tank
				XVector3 *tankPosition = &tank.bodyModel->position;
				XVector3 vec;
				vec.x = thisPosition.x - tankPosition->x;
				vec.y = thisPosition.y - tankPosition->y;
				vec.z = thisPosition.z - tankPosition->z;
				XScalar vecLenSq = xLengthSquared_Vec3(&vec);
				XScalar collisionDist = tank.collisionRadius + collisionRadius;
				XScalar collisionDistSq = collisionDist * collisionDist;
				// if distance indicates a collision..
				if (vecLenSq < collisionDistSq) {
					// "rewind" time to hit point
					XScalar bulletSpeed = xLength_Vec3(&startVelocity);
					do {
						bulletLife -= ((collisionDist - vecLenSq) / bulletSpeed) + 0.1f;
						thisPosition = self.currentPosition;
						XVector3 vec;
						vec.x = thisPosition.x - tankPosition->x;
						vec.y = thisPosition.y - tankPosition->y;
						vec.z = thisPosition.z - tankPosition->z;
						vecLenSq = xLengthSquared_Vec3(&vec);
						collisionDist = tank.collisionRadius;
					} while (vecLenSq < collisionDist*collisionDist);
					// notify hit tank and the tank responsible for the hit
					[tank notifyWasHitWithBullet:self];
					if (self.originator)
						[self.originator notifyHitEnemyWithBullet:self];
					// deactivate bullet
					active = NO;
					// sound effect
					[gGame->soundPool playImpactSoundAt:&intersect.point forcePlay:NO];
					break;
				}
			}
		}
	}
	
	return active;
}

-(XVector3)currentVelocity
{
	XVector3 motionVector;
	motionVector.x = startVelocity.x;
	motionVector.y = (startVelocity.y - gravity * bulletLife);
	motionVector.z = startVelocity.z;
	return motionVector;
}

-(XVector3)currentPosition
{
	XVector3 pos;
	pos.x = startPosition.x + startVelocity.x * bulletLife;
	pos.y = startPosition.y + startVelocity.y * bulletLife - (gravity*0.5f) * bulletLife * bulletLife;
	pos.z = startPosition.z + startVelocity.z * bulletLife;
	return pos;
}


-(NSString*)getRenderGroupID
{
	return @"0_bullet";
}

-(void)beginRenderGroup
{
	glDisable(GL_LIGHTING);
	glDisable(GL_CULL_FACE);

	if (xglCheckBindTextures(type.texture.glTexture, 0)) {
		glActiveTexture(GL_TEXTURE0);
		glBindTexture(GL_TEXTURE_2D, type.texture.glTexture);
		glEnable(GL_TEXTURE_2D);
	}
	
	if (xglCheckBindMesh(type.glVertexBuffer, type.glIndexBuffer)) {
		glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, type.glIndexBuffer);
		glBindBuffer(GL_ARRAY_BUFFER, type.glVertexBuffer);
		glVertexPointer(3, GL_FLOAT, sizeof(GBulletVertex), (void*)offsetof(GBulletVertex,position));
		glTexCoordPointer(2, GL_FLOAT, sizeof(GBulletVertex), (void*)offsetof(GBulletVertex,texcoord));
		
		glEnableClientState(GL_VERTEX_ARRAY);
		glEnableClientState(GL_TEXTURE_COORD_ARRAY);
	}
}

-(void)endRenderGroup
{
	glEnable(GL_LIGHTING);	
	glEnable(GL_CULL_FACE);
}

-(void)render:(XCamera*)cam
{
	glDrawElements(GL_TRIANGLES, type.glIndexCount, GL_UNSIGNED_BYTE, (void*)0);
}

@end

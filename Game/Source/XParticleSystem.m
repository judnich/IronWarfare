// Copyright © 2010 John Judnich. All rights reserved.

#import "XParticleSystem.h"
#import "XParticleEffect.h"
#import "XGL.h"
#import "XCamera.h"
#import "XTexture.h"


// ---------- Vertex / index buffer structs ----------

typedef struct {
	XVector3 position;
	XColorBytes color;
} XParticleVertex;

typedef struct {
	GLbyte u, v;
} XParticleTexcoord;

typedef GLubyte XParticleIndex;


// ---------- Vertex/index buffer pooling ----------
// Singleton class XParticleGeometryBufferPool manages pooling
// and reuse of vertex and index buffers for particle systems.

@interface XParticleVertexBuffer : NSObject {
@public
	GLuint glVertexBuffer;
	size_t vertexCount;
}
-(id)initWithSize:(size_t)size;
-(void)dealloc;
@end

@implementation XParticleVertexBuffer

-(id)initWithSize:(size_t)size
{
	if ((self = [super init])) {
		vertexCount = size;
		glGenBuffers(1, &glVertexBuffer);
		glBindBuffer(GL_ARRAY_BUFFER, glVertexBuffer);
		glBufferData(GL_ARRAY_BUFFER, sizeof(XParticleVertex)*vertexCount, NULL, GL_DYNAMIC_DRAW);
		glBindBuffer(GL_ARRAY_BUFFER, 0);
	}
	return self;
}

-(void)dealloc
{
	glDeleteBuffers(1, &glVertexBuffer);
	[super dealloc];
}

@end

@interface XParticleGeometryBufferPool : NSObject {
@private
	GLuint sharedGLIndexBuffer;
	size_t sharedIndexCount;
	GLuint sharedGLTexcoordBuffer;
	size_t sharedTexcoordCount;
	NSMutableArray *unusedVertexBufferList;
}
+(id)retainSingleton;
-(id)init;
-(void)dealloc;
-(XParticleGeometryBuffer)autoallocBufferWithSize:(size_t)particleCount;
-(void)autoreleaseBuffer:(XParticleGeometryBuffer*)buffer;
@end


@implementation XParticleGeometryBufferPool

XParticleGeometryBufferPool *g_XParticleGeometryBufferPool = nil;

+(id)retainSingleton
{
	if (g_XParticleGeometryBufferPool == nil) {
		g_XParticleGeometryBufferPool = [[XParticleGeometryBufferPool alloc] init];
	} else {
		[g_XParticleGeometryBufferPool retain];
	}
	return g_XParticleGeometryBufferPool;
}

-(id)init
{
	assert(!g_XParticleGeometryBufferPool);
	if ((self = [super init])) {
		sharedIndexCount = MAX_PARTICLES_PER_SYSTEM * 6;
		{
			XParticleIndex *indexData = malloc(sizeof(XParticleIndex)*sharedIndexCount);
			XParticleIndex *ptr = indexData;
			for (size_t i = 0; i < MAX_PARTICLES_PER_SYSTEM; ++i) {
				size_t o = i * 4;
				*ptr++ = 0+o; *ptr++ = 1+o; *ptr++ = 2+o;
				*ptr++ = 1+o; *ptr++ = 2+o; *ptr++ = 3+o;
			}
			glGenBuffers(1, &sharedGLIndexBuffer);
			glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, sharedGLIndexBuffer);
			glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(XParticleIndex)*sharedIndexCount, indexData, GL_STATIC_DRAW);
			glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
			free(indexData);
		}
		
		sharedTexcoordCount = MAX_PARTICLES_PER_SYSTEM * 4;
		{
			XParticleTexcoord *texcoordData = malloc(sizeof(XParticleTexcoord)*sharedTexcoordCount);
			XParticleTexcoord t00; t00.u = 0; t00.v = 0;
			XParticleTexcoord t10; t10.u = 1; t10.v = 0;
			XParticleTexcoord t01; t01.u = 0; t01.v = 1;
			XParticleTexcoord t11; t11.u = 1; t11.v = 1;
			XParticleTexcoord *ptr = texcoordData;
			for (size_t i = 0; i < MAX_PARTICLES_PER_SYSTEM; ++i) {
				*ptr++ = t00; *ptr++ = t10;
				*ptr++ = t01; *ptr++ = t11;
			}
			glGenBuffers(1, &sharedGLTexcoordBuffer);
			glBindBuffer(GL_ARRAY_BUFFER, sharedGLTexcoordBuffer);
			glBufferData(GL_ARRAY_BUFFER, sizeof(XParticleTexcoord)*sharedTexcoordCount, texcoordData, GL_STATIC_DRAW);
			glBindBuffer(GL_ARRAY_BUFFER, 0);
			free(texcoordData);
		}
				
		unusedVertexBufferList = [[NSMutableArray alloc] initWithCapacity:10];
	}
	return self;
}

-(void)dealloc
{
	assert(g_XParticleGeometryBufferPool);
	g_XParticleGeometryBufferPool = nil;
	[unusedVertexBufferList removeAllObjects];
	[unusedVertexBufferList release];
	glDeleteBuffers(1, &sharedGLIndexBuffer);
	glDeleteBuffers(1, &sharedGLTexcoordBuffer);
	[super dealloc];
}

-(XParticleGeometryBuffer)autoallocBufferWithSize:(size_t)particleCount
{
	XParticleVertexBuffer *vertexBuff = nil;
	int index = 0, matchingIndex = -1;
	for (XParticleVertexBuffer *vBuff in unusedVertexBufferList) {
		if (vBuff->vertexCount == particleCount * 4) {
			matchingIndex = index;
			break;
		}
		++index;
	}
	if (matchingIndex > -1) {
		vertexBuff = [unusedVertexBufferList objectAtIndex:matchingIndex];
		[vertexBuff retain];
		[unusedVertexBufferList removeObjectAtIndex:matchingIndex];
	}
	else {
		vertexBuff = [[XParticleVertexBuffer alloc] initWithSize:(particleCount * 4)];
	}
	
	XParticleGeometryBuffer geomBuff;
	if (particleCount * 6 > sharedIndexCount) {
		#ifdef DEBUG
		[NSException raise:@"Error autoalloc'ing particle geometry buffer" format:@"Too many particles requested. Increase MAX_PARTICLES_PER_SYSTEM."];
		#endif
		geomBuff.indexCount = sharedIndexCount;
	} else {
		geomBuff.indexCount = particleCount * 6;
	}
	geomBuff.glIndexBuffer = sharedGLIndexBuffer;
	geomBuff.vertexCount = vertexBuff->vertexCount;
	geomBuff.glVertexBuffer = vertexBuff->glVertexBuffer;
	geomBuff.glTexcoordBuffer = sharedGLTexcoordBuffer;
	geomBuff.particleVertexBufferRef = vertexBuff;
	return geomBuff;
}

-(void)autoreleaseBuffer:(XParticleGeometryBuffer*)buffer
{
	XParticleVertexBuffer *vertexBuff = buffer->particleVertexBufferRef;
	[unusedVertexBufferList addObject:vertexBuff];
	[vertexBuff release];
}

@end



// ---------- Particle system implementation ----------

@implementation XParticleSystem

+(void)retainPooledBuffers
{
	[XParticleGeometryBufferPool retainSingleton];
}

+(void)releasePooledBuffers
{
	[g_XParticleGeometryBufferPool release];
}

-(id)initWithEffect:(XParticleEffect*)particleEffect
{
	if ((self = [super init])) {
		effect = particleEffect;
		[effect mediaRetain];
		if (effect->texture) {
			resourceGroupID = [[NSString alloc] initWithFormat:@"9_%@", effect->texture.resourceKey];
		} else {
			resourceGroupID = [[NSString alloc] initWithFormat:@"9_untextured"];
		}
		shade = 1;
		particles = malloc(sizeof(XParticleInstance) * effect->totalParticlesToEmit);
		animating = NO;
		bufferPool = [XParticleGeometryBufferPool retainSingleton];
		buffers = [bufferPool autoallocBufferWithSize:effect->totalParticlesToEmit];
	}
	return self;
}

-(id)initWithEffect:(XParticleEffect*)particleEffect andShade:(float)lightness
{
	if ((self = [self initWithEffect:particleEffect])) {
		shade = lightness;
	}
	return self;
}

-(void)dealloc
{
	[resourceGroupID release];
	[bufferPool autoreleaseBuffer:&buffers];
	[bufferPool release];
	free(particles);
	[effect mediaRelease];
	[super dealloc];
}

-(BOOL)isAnimating
{
	return animating;
}

-(void)beginAnimation
{
	animating = YES;
	particleTime = 0;

	// get particle system rotation
	XMatrix3 rot = *[super globalRotation];
	
	// prepare to update bounding box
	boundingBox.min.x = INFINITY; boundingBox.min.y = INFINITY; boundingBox.min.z = INFINITY;
	boundingBox.max.x = -INFINITY; boundingBox.max.y = -INFINITY; boundingBox.max.z = -INFINITY;

	// initialize particles from XParticleEffect values
	int index = 0;
	for (int em = 0; em < effect->numEmissions; ++em) {
		XParticleEmissionData *emission = &effect->emissionArray[em];
		for (int i = index; i < index + emission->emitCount; ++i) {
			// initialize particle data
			XParticleInstance *particle = &particles[i];
			particle->startPosition.x = xRangeRand(emission->emitBox.min.x, emission->emitBox.max.x);
			particle->startPosition.y = xRangeRand(emission->emitBox.min.y, emission->emitBox.max.y);
			particle->startPosition.z = xRangeRand(emission->emitBox.min.z, emission->emitBox.max.z);
			particle->startPosition = xMul_Vec3Mat3(&particle->startPosition, &rot);
			particle->startVelocity.x = xRangeRand(emission->minVelocity.x, emission->maxVelocity.x);
			particle->startVelocity.y = xRangeRand(emission->minVelocity.y, emission->maxVelocity.y);
			particle->startVelocity.z = xRangeRand(emission->minVelocity.z, emission->maxVelocity.z);
			particle->startVelocity = xMul_Vec3Mat3(&particle->startVelocity, &rot);
			xAdd_Vec3Vec3(&particle->startVelocity, &addedVelocity);
			particle->gravity = xRangeRand(emission->minGravity, emission->maxGravity);
			particle->startAngle = xRangeRand(emission->minAngle, emission->maxAngle);
			particle->rotateSpeed = xRangeRand(emission->minRotateSpeed, emission->maxRotateSpeed);
			particle->scale = xRangeRand(emission->minScale, emission->maxScale);
			particle->scaleSpeed = xRangeRand(emission->minScaleSpeed, emission->maxScaleSpeed);
			float rnd = xRand();
			particle->color.red = (emission->minColor.red * rnd + emission->maxColor.red * (1-rnd)) * shade;
			particle->color.green = (emission->minColor.green * rnd + emission->maxColor.green * (1-rnd)) * shade;
			particle->color.blue = (emission->minColor.blue * rnd + emission->maxColor.blue * (1-rnd)) * shade;
			particle->startAlpha = emission->startAlpha;
			particle->endAlpha = emission->endAlpha;
			particle->life = xRangeRand(emission->minLife, emission->maxLife);
			// update bounds
			XScalar min, max;
			min = particle->startPosition.x - particle->scale * 0.5f;
			max = particle->startPosition.x + particle->scale * 0.5f;
			if (min < boundingBox.min.x) boundingBox.min.x = min;
			if (max > boundingBox.max.x) boundingBox.max.x = max;
			min = particle->startPosition.y - particle->scale * 0.5f;
			max = particle->startPosition.y + particle->scale * 0.5f;
			if (min < boundingBox.min.y) boundingBox.min.y = min;
			if (max > boundingBox.max.y) boundingBox.max.y = max;
			min = particle->startPosition.z - particle->scale * 0.5f;
			max = particle->startPosition.z + particle->scale * 0.5f;
			if (min < boundingBox.min.z) boundingBox.min.z = min;
			if (max > boundingBox.max.z) boundingBox.max.z = max;			
		}
		index += emission->emitCount;
	}
	[self notifyBoundsChanged];
}

-(void)endAnimation
{
	animating = NO;
}

-(void)updateAnimation:(XSeconds)deltaTime
{
	if (animating) {
		particleTime += deltaTime;
	}
}

-(NSString*)getRenderGroupID
{
	return resourceGroupID;
}

-(void)beginRenderGroup
{
	glDisable(GL_LIGHTING);
	glDisable(GL_CULL_FACE);
	glDisableClientState(GL_NORMAL_ARRAY);

	if (effect->texture) {
		if (xglCheckBindTextures(effect->texture.glTexture, 0)) {
			glActiveTexture(GL_TEXTURE0);
			glBindTexture(GL_TEXTURE_2D, effect->texture.glTexture);
			glEnable(GL_TEXTURE_2D);
		}

		switch (effect->blendMode) {
			case XBlend_Modulative:
				glEnable(GL_BLEND);
				glBlendFunc(GL_DST_COLOR, GL_ZERO);
				break;
			case XBlend_Additive:
				glEnable(GL_BLEND);
				glBlendFunc(GL_SRC_ALPHA, GL_ONE);
				break;
			case XBlend_Alpha:
				glEnable(GL_BLEND);
				glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
				break;
			case XBlend_None:
				break;
		}
		
		glDepthMask(FALSE);
	} else {
		glActiveTexture(GL_TEXTURE0);
		glBindTexture(GL_TEXTURE_2D, 0);
		glDisable(GL_TEXTURE_2D);
	}
}

-(void)endRenderGroup
{
	glActiveTexture(GL_TEXTURE0);
	glBindTexture(GL_TEXTURE_2D, 0);

	glDisableClientState(GL_COLOR_ARRAY);
	glBindBuffer(GL_ARRAY_BUFFER, 0);
	glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);

	glDisable(GL_BLEND);
	glEnable(GL_LIGHTING);	
	glEnable(GL_CULL_FACE);
	glDepthMask(TRUE);
}

-(XMatrix3*)globalRotation
{
	return (XMatrix3*)&xMatrix3_Identity;	
}

-(void)render:(XCamera*)cam
{
	if (!animating)
		return;
	
	// calculate vectors to face particles towards camera
	XVector3 rightVector = xCrossProduct_Vec3(&cam->lookVector, &cam->upVector);
	XVector3 upVector = xCrossProduct_Vec3(&rightVector, &cam->lookVector);
	xNormalize_Vec3(&rightVector);
	xNormalize_Vec3(&upVector);
	
	// prepare to update bounding box
	boundingBox.min.x = INFINITY; boundingBox.min.y = INFINITY; boundingBox.min.z = INFINITY;
	boundingBox.max.x = -INFINITY; boundingBox.max.y = -INFINITY; boundingBox.max.z = -INFINITY;

	// update particles dynamics
	XParticleVertex particleVertexBuffer[MAX_PARTICLES_PER_SYSTEM * 4];
	XParticleVertex *particleVertexPtr = particleVertexBuffer;
	XSeconds halfParticleTimeSquared = 0.5f * particleTime * particleTime;
	BOOL allDead = YES;
	for (int i = 0; i < effect->totalParticlesToEmit; ++i) {
		XParticleInstance *particle = &particles[i];

		float unitLife = (particleTime / particle->life);
		if (unitLife >= 1) {
			// dead particle - collapse vertex
			for (int i = 0; i < 4; ++i) {
				particleVertexPtr->position.x = 0; particleVertexPtr->position.y = 0; particleVertexPtr->position.z = 0;
				particleVertexPtr->color.red = 0; particleVertexPtr->color.green = 0; particleVertexPtr->color.blue = 0; particleVertexPtr->color.alpha = 0;
				++particleVertexPtr;			
			}
		} else {
			// update and generate particle vertexes
			allDead = NO;
			XVector3 pos;
			pos.x = particle->startPosition.x + particle->startVelocity.x * particleTime;
			pos.y = particle->startPosition.y + particle->startVelocity.y * particleTime + particle->gravity * halfParticleTimeSquared;
			pos.z = particle->startPosition.z + particle->startVelocity.z * particleTime;
			XScalar scale = particle->scale + particle->scaleSpeed * particleTime;
			XAngle angle = particle->startAngle + particle->rotateSpeed * particleTime;
			XColorBytes color = particle->color;
			float usq = xSaturate(unitLife);
			usq = (1 - (usq*usq)) * xSaturate(usq * 20);
			float alpha = particle->startAlpha * usq + particle->endAlpha * (1-usq);
			color.alpha = alpha * 0xFF;

			XScalar cos = xCos(angle) * scale * 0.5f;
			XScalar sin = xSin(angle) * scale * 0.5f;
			XScalar lx, ly;
			
			// top-left corner
			lx = cos*(-1) - sin*(1);
			ly = sin*(-1) + cos*(1);
			particleVertexPtr->position.x = pos.x + rightVector.x * lx + upVector.x * ly;
			particleVertexPtr->position.y = pos.y + rightVector.y * lx + upVector.y * ly;
			particleVertexPtr->position.z = pos.z + rightVector.z * lx + upVector.z * ly;
			particleVertexPtr->color = color;
			++particleVertexPtr;
			
			// top-right corner
			lx = cos*(1) - sin*(1);
			ly = sin*(1) + cos*(1);
			particleVertexPtr->position.x = pos.x + rightVector.x * lx + upVector.x * ly;
			particleVertexPtr->position.y = pos.y + rightVector.y * lx + upVector.y * ly;
			particleVertexPtr->position.z = pos.z + rightVector.z * lx + upVector.z * ly;
			particleVertexPtr->color = color;
			++particleVertexPtr;
			
			// bottom-left corner
			lx = cos*(-1) - sin*(-1);
			ly = sin*(-1) + cos*(-1);
			particleVertexPtr->position.x = pos.x + rightVector.x * lx + upVector.x * ly;
			particleVertexPtr->position.y = pos.y + rightVector.y * lx + upVector.y * ly;
			particleVertexPtr->position.z = pos.z + rightVector.z * lx + upVector.z * ly;
			particleVertexPtr->color = color;
			++particleVertexPtr;
			
			// bottom-right corner
			lx = cos*(1) - sin*(-1);
			ly = sin*(1) + cos*(-1);
			particleVertexPtr->position.x = pos.x + rightVector.x * lx + upVector.x * ly;
			particleVertexPtr->position.y = pos.y + rightVector.y * lx + upVector.y * ly;
			particleVertexPtr->position.z = pos.z + rightVector.z * lx + upVector.z * ly;
			particleVertexPtr->color = color;
			++particleVertexPtr;

			// update bounds
			XScalar min, max;
			min = pos.x - particle->scale * 0.5f;
			max = pos.x + particle->scale * 0.5f;
			if (min < boundingBox.min.x) boundingBox.min.x = min;
			if (max > boundingBox.max.x) boundingBox.max.x = max;
			min = pos.y - particle->scale * 0.5f;
			max = pos.y + particle->scale * 0.5f;
			if (min < boundingBox.min.y) boundingBox.min.y = min;
			if (max > boundingBox.max.y) boundingBox.max.y = max;
			min = pos.z - particle->scale * 0.5f;
			max = pos.z + particle->scale * 0.5f;
			if (min < boundingBox.min.z) boundingBox.min.z = min;
			if (max > boundingBox.max.z) boundingBox.max.z = max;
		}
	}
	[self notifyBoundsChanged];
	
	if (allDead) {
		animating = NO;
		xglNotifyMeshBindingsChanged();
		return;
	}

	// upload to particle system's vertex buffer and render
	glBindBuffer(GL_ARRAY_BUFFER, buffers.glVertexBuffer);
	glBufferSubData(GL_ARRAY_BUFFER, 0, buffers.vertexCount*sizeof(XParticleVertex), &particleVertexBuffer); //upload data
	glEnableClientState(GL_VERTEX_ARRAY);
	glVertexPointer(3, GL_FLOAT, sizeof(XParticleVertex), (void*)offsetof(XParticleVertex,position));
	glEnableClientState(GL_COLOR_ARRAY);
	glColorPointer(4, GL_UNSIGNED_BYTE, sizeof(XParticleVertex), (void*)offsetof(XParticleVertex,color));
	
	glBindBuffer(GL_ARRAY_BUFFER, buffers.glTexcoordBuffer);
	glEnableClientState(GL_TEXTURE_COORD_ARRAY);
	glTexCoordPointer(2, GL_BYTE, sizeof(XParticleTexcoord), 0);
	
	glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, buffers.glIndexBuffer);
	
	// draw
	glDrawElements(GL_TRIANGLES, buffers.indexCount, GL_UNSIGNED_BYTE, (void*)0);
	
	xglNotifyMeshBindingsChanged();
}

@end


// Copyright © 2010 John Judnich. All rights reserved.

#import "XNode.h"
#import "XParticleEffect.h"

#define MAX_PARTICLES_PER_SYSTEM 128


typedef struct {
	GLuint glIndexBuffer;
	size_t indexCount;
	GLuint glVertexBuffer; 
	GLuint glTexcoordBuffer;
	size_t vertexCount;
	id particleVertexBufferRef;
} XParticleGeometryBuffer;

typedef struct {
	XVector3 startPosition;
	XVector3 startVelocity;
	XScalar gravity;
	XAngle startAngle;
	XAngle rotateSpeed;
	XScalar scale;
	XScalar scaleSpeed;
	XColorBytes color;
	float startAlpha, endAlpha;
	XSeconds life;
} XParticleInstance;


@interface XParticleSystem : XNode {
	id bufferPool;
	XParticleEffect *effect;
	float shade; // multiplied by color to shade the overall particle effect
	XParticleGeometryBuffer buffers;
	XSeconds particleTime;
	BOOL animating;
	XParticleInstance *particles;
	NSString *resourceGroupID;
@public
	XVector3 addedVelocity;
}

@property(readonly) BOOL isAnimating;

// IMPORTANT: If you use XParticleSystem and there are periods where no particle systems are being rendered,
// the system will deallocate pooled buffer sets, etc. that prevent memory fragmentation and optimize particle
// system creation. To prevent this from happening, call [XParticleSystem retainPooledBuffers]; when initializing
// your game/level, and [XParticleSystem releasePooledBuffers]; when destroying to dump the buffer pools.
+(void)retainPooledBuffers;
+(void)releasePooledBuffers;

-(id)initWithEffect:(XParticleEffect*)particleEffect;
-(id)initWithEffect:(XParticleEffect*)particleEffect andShade:(float)lightness;
-(void)dealloc;

-(void)beginAnimation;
-(void)endAnimation;
-(void)updateAnimation:(XSeconds)deltaTime;

@end


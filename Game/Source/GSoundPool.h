// Copyright © 2010 John Judnich. All rights reserved.

#import "SoundEngine.h"
#import "XMath.h"
#import "XTime.h"
@class XCamera;

#define MAX_FIRE_SOUNDS 5
#define MAX_EXPLOSION_SOUNDS 3
#define MAX_IMPACT_SOUNDS 2


typedef struct {
	UInt32 effectID;
	XVector3 position;
	XSeconds life;
} GSoundEffect;


@interface GSoundPool : NSObject {
	GSoundEffect fireSound[MAX_FIRE_SOUNDS];
	GSoundEffect explosionSound[MAX_EXPLOSION_SOUNDS];
	GSoundEffect impactSound[MAX_IMPACT_SOUNDS];
	XVector3 listenerPosition;
	UInt32 engineSound;
	BOOL engineSoundEnabled;
}

@property(assign) BOOL engineSoundEnabled;

-(id)init;
-(void)dealloc;

-(void)frameUpdate:(XSeconds)deltaTime fromCamera:(XCamera*)cam;

-(void)playFireSoundAt:(XVector3*)pos forcePlay:(BOOL)force;
-(void)playExplosionSoundAt:(XVector3*)pos forcePlay:(BOOL)force;
-(void)playImpactSoundAt:(XVector3*)pos forcePlay:(BOOL)force;

-(void)setEngineSoundEnabled:(BOOL)enabled;
-(void)setEngineSpeed:(float)speed;

@end

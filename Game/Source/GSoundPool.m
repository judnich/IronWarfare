// Copyright © 2010 John Judnich. All rights reserved.

#import "GSoundPool.h"
#import "XCamera.h"
#import "XMath.h"


@implementation GSoundPool

-(id)init
{
	int err;
	if ((self = [super init])) {
		// load sound effects
		{
			NSString *file = @"Media/Sounds/Fire.wav";
			NSString *directory = [file stringByDeletingLastPathComponent];
			NSString *fileN = [file lastPathComponent];
			NSString *path = [[NSBundle mainBundle] pathForResource:fileN ofType:nil inDirectory:directory];
			for (int i = 0; i < MAX_FIRE_SOUNDS; ++i) {
				if ((err = SoundEngine_LoadEffect([path UTF8String], &fireSound[i].effectID)) != 0)
					NSLog(@"Error %d loading sound.", err);
				fireSound[i].life = 0;
			}
		}
		{
			NSString *file = @"Media/Sounds/Explosion.wav";
			NSString *directory = [file stringByDeletingLastPathComponent];
			NSString *fileN = [file lastPathComponent];
			NSString *path = [[NSBundle mainBundle] pathForResource:fileN ofType:nil inDirectory:directory];
			for (int i = 0; i < MAX_EXPLOSION_SOUNDS; ++i) {
				if ((err = SoundEngine_LoadEffect([path UTF8String], &explosionSound[i].effectID)) != 0)
					NSLog(@"Error %d loading sound.", err);
				explosionSound[i].life = 0;
			}
		}
		{
			NSString *file = @"Media/Sounds/Impact.wav";
			NSString *directory = [file stringByDeletingLastPathComponent];
			NSString *fileN = [file lastPathComponent];
			NSString *path = [[NSBundle mainBundle] pathForResource:fileN ofType:nil inDirectory:directory];
			for (int i = 0; i < MAX_IMPACT_SOUNDS; ++i) {
				if ((err = SoundEngine_LoadEffect([path UTF8String], &impactSound[i].effectID)) != 0)
					NSLog(@"Error %d loading sound.", err);
				impactSound[i].life = 0;
			}
		}
		
		{	
			NSString *file = @"Media/Sounds/Engine.wav";
			NSString *directory = [file stringByDeletingLastPathComponent];
			NSString *fileN = [file lastPathComponent];
			NSString *path = [[NSBundle mainBundle] pathForResource:fileN ofType:nil inDirectory:directory];
			if ((err = SoundEngine_LoadLoopingEffect([path UTF8String], NULL, NULL, &engineSound)) != 0)
				NSLog(@"Error %d loading sound.", err);
		}
	
		
		//SoundEngine_SetReferenceDistance(1);
		//SoundEngine_SetMaxDistance(50);
		SoundEngine_SetEffectsVolume(1.0);
		SoundEngine_SetMasterVolume(1.0);
	}
	return self;
}

-(void)dealloc
{
	// unload sound effects
	for (int i = 0; i < 3; ++i) {
		SoundEngine_UnloadEffect(fireSound[i].effectID);
	}
	SoundEngine_StopBackgroundMusic(NO);
	SoundEngine_Teardown();
	[super dealloc];
}

-(void)frameUpdate:(XSeconds)deltaTime fromCamera:(XCamera*)cam
{
	listenerPosition = cam->origin;
	//SoundEngine_SetListenerPosition(cam->origin.x, cam->origin.y, cam->origin.z);
	
	// update life timers
	for (int i = 0; i < MAX_FIRE_SOUNDS; ++i) {
		if (fireSound[i].life > 0) {
			fireSound[i].life -= deltaTime;
			// stop sound when timed out
			if (fireSound[i].life <= 0) {
				SoundEngine_StopEffect(fireSound[i].effectID, NO);
				fireSound[i].life = 0;
			}
		}
	}
	for (int i = 0; i < MAX_IMPACT_SOUNDS; ++i) {
		if (impactSound[i].life > 0) {
			impactSound[i].life -= deltaTime;
			// stop sound when timed out
			if (impactSound[i].life <= 0) {
				SoundEngine_StopEffect(impactSound[i].effectID, NO);
				impactSound[i].life = 0;
			}
		}
	}
	for (int i = 0; i < MAX_EXPLOSION_SOUNDS; ++i) {
		if (explosionSound[i].life > 0) {
			explosionSound[i].life -= deltaTime;
			// stop sound when timed out
			if (explosionSound[i].life <= 0) {
				SoundEngine_StopEffect(explosionSound[i].effectID, NO);
				explosionSound[i].life = 0;
			}
		}
	}
}

// finds the best sound effect slot (if any) for a new sound at the given position.
// -1 is returned if no slot can be reserved (unless "force" is YES). Near sounds are given
// play priority so adding near sounds will override playing far slots if no sound slots are
// availible.
int findSoundSlot(GSoundEffect *slots, int arraySize, XVector3 *soundPosition, XVector3 *listenerPosition, BOOL force)
{
	int use = -1;
	XScalar farthestReplaceable = 0;
	for (int i = 0; i < arraySize; ++i) {
		BOOL possibleReplacement = force;
		if (slots[i].life <= 0.2f) {
			// use free (or almost free) slot
			use = i;
			break;
		}
		else possibleReplacement = YES;
		if (possibleReplacement) {
			// choose best replacement
			if (force && use == -1)
				use = i;
			XScalar soundDist = xDist_Vec3Vec3(listenerPosition, &slots[i].position);
			XScalar newSoundDist = xDist_Vec3Vec3(listenerPosition, soundPosition);
			if (newSoundDist < soundDist + 1.0f) {
				if (newSoundDist > farthestReplaceable - 1.0f) {
					farthestReplaceable = newSoundDist;
					use = i;
				}
			}
		}
	}
	return use;
}

void set3DEffects(UInt32 effectID, XVector3 *pos, XVector3 *listenerPos, float vol)
{
	XScalar dist = xDist_Vec3Vec3(pos, listenerPos);
	float volume = 1.0f / ((dist * 0.05f) + 1);
	float pitch = 1.0f / ((dist * 0.005f) + 1);
	
	pitch += xRangeRand(-0.1f, 0.1f);
	if (pitch <= 0.05f) pitch = 0.05f;
	
	SoundEngine_SetEffectPitch(effectID, pitch);
	SoundEngine_SetEffectLevel(effectID, volume * vol);
}

-(void)playFireSoundAt:(XVector3*)pos forcePlay:(BOOL)force;
{
	int slot = findSoundSlot(fireSound, MAX_FIRE_SOUNDS, pos, &listenerPosition, force);
	if (slot != -1) {
		GSoundEffect *effect = &fireSound[slot];
		effect->position = *pos;
		set3DEffects(fireSound[slot].effectID, pos, &listenerPosition, 1.0f);
		SoundEngine_StartEffect(fireSound[slot].effectID);
		effect->life = 1.0f;
	}
}

-(void)playExplosionSoundAt:(XVector3*)pos forcePlay:(BOOL)force
{
	int slot = findSoundSlot(explosionSound, MAX_EXPLOSION_SOUNDS, pos, &listenerPosition, force);
	if (slot != -1) {
		GSoundEffect *effect = &explosionSound[slot];
		effect->position = *pos;
		set3DEffects(explosionSound[slot].effectID, pos, &listenerPosition, 1.5f);
		SoundEngine_StartEffect(explosionSound[slot].effectID);
		effect->life = 3.0f;
	}
}

-(void)playImpactSoundAt:(XVector3*)pos forcePlay:(BOOL)force
{
	int slot = findSoundSlot(impactSound, MAX_IMPACT_SOUNDS, pos, &listenerPosition, force);
	if (slot != -1) {
		GSoundEffect *effect = &impactSound[slot];
		effect->position = *pos;
		set3DEffects(impactSound[slot].effectID, pos, &listenerPosition, 2.0f);
		SoundEngine_StartEffect(impactSound[slot].effectID);
		effect->life = 1.5f;
	}
}

-(void)setEngineSoundEnabled:(BOOL)enabled
{
	if (enabled != engineSoundEnabled) {
		engineSoundEnabled = enabled;
		if (enabled)
			SoundEngine_StartEffect(engineSound);
		else
			SoundEngine_StopEffect(engineSound, NO);
	}
}

-(BOOL)engineSoundEnabled
{
	return engineSoundEnabled;
}

-(void)setEngineSpeed:(float)speed
{
	speed = xAbs(speed);
	SoundEngine_SetEffectPitch(engineSound, speed * 0.4f + 0.8f);
	SoundEngine_SetEffectLevel(engineSound, speed * 0.05f + 0.05f);
}

@end

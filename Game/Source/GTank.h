// Copyright © 2010 John Judnich. All rights reserved.

#import "XModel.h"
@class GTeam;
@class GTankController;
@class GBullet;
@class XParticleEffect;


typedef struct {
	float throttle;
	float turn;
	float aimYaw, aimPitch;
	BOOL fire;
} GTankControls;


@interface GTank : NSObject {
	// tank media
	GTank *isCopyOf; // for saving state (tank type)
	NSString *mediaFolder;
	XModel *body, *turret, *barrel, *shadow;
	XTexture *icon;
	int tankClass; //1/2/3 = light/medium/heavy
	
	// tank state
	int frameCount;
	XAngle tankYaw, turretYaw, barrelPitch;
	XScalar currentSpeed, currentTurnSpeed;
	XAngle pitchRock, rollRock, pitchRockSpeed, rollRockSpeed;
	XSeconds reloadTimer; 
	GTeam *team;
	float armor;
	GTankController *controller;
	XSeconds desertionTimer;
	BOOL _removeFromTankList;
	
	// tank capabilities / specs
	float maxArmor, maxTurnSpeed, maxMoveSpeed, maxAcceleration;
	float fireRate, gunPower;
	XScalar gunVelocity;
	XScalar collisionRadius;
	
@public
	XVector3 turretPivot, barrelPivot;

	// particle effects
	XParticleEffect *groundImpactEffect_high;
	XParticleEffect *groundImpactEffect_medium;
	XParticleEffect *groundImpactEffect_low;
	XParticleEffect **tankImpactEffects;
	int numTankImpactEffects;
	XParticleEffect **explosionEffects;
	int numExplosionEffects;
	GTankControls controls;
}

@property(assign) XScene *scene;
@property(assign) XVector2 position;
@property(assign) XAngle yaw;
@property(assign) GTeam *team;
@property(retain) GTankController *controller;
@property(readonly) int tankClass;
@property(readonly) XModel *bodyModel, *turretModel, *barrelModel;
@property(readonly) XTexture *icon;
@property(readonly) XScalar collisionRadius;
@property(assign) float armor, maxArmor;
@property(readonly) float readyToFire;
@property(readonly) XSeconds desertionTimer;
@property(readonly) XScalar currentSpeed;
@property(assign) GTank *isCopyOf;

-(id)initWithFile:(NSString*)filename;
-(id)initWithTank:(GTank*)tank;
-(void)dealloc;

-(GTank*)spawnAt:(XVector2)pos;
-(void)setUnloadedTextures:(NSString*)textureFile;
-(BOOL)frameUpdate:(XSeconds)deltaTime; //returns NO if the tank should be removed from the tank list

-(void)notifyWasHitWithBullet:(GBullet*)bullet;
-(void)notifyHitEnemyWithBullet:(GBullet*)bullet;

-(void)destroy;

-(void)saveStateToFile:(FILE*)file;
-(void)loadStateFromFile:(FILE*)file;

@end


@interface GTankController : NSObject {
	GTank *tank;
}

@property(assign) GTank *controlTarget;
@property(readonly) BOOL isComputerControlled;

-(void)frameUpdate:(XSeconds)deltaTime;
-(BOOL)isComputerControlled;
-(void)notifyWasHitWithBullet:(GBullet*)bullet;
-(void)notifyFired;
-(void)notifyHitEnemyWithBullet:(GBullet*)bullet;

@end

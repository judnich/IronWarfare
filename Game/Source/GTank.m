// Copyright © 2010 John Judnich. All rights reserved.

#import "GTank.h"
#import "XScript.h"
#import "XTreeSystem.h"
#import "GGame.h"
#import "GTankAIController.h"
#import "GBulletPool.h"
#import "GBullet.h"
#import "GOutpost.h"
#import "GSoundPool.h"
#import "XParticleEffect.h"
#import "XParticleSystem.h"
#import "XTexture.h"
#import "XTextureNomip.h"
#import "GTankPlayerController.h"


@implementation GTankController

@synthesize controlTarget = tank;

-(void)frameUpdate:(XSeconds)deltaTime
{
}

-(BOOL)isComputerControlled
{
	return YES;
}

-(void)notifyWasHitWithBullet:(GBullet*)bullet
{
}

-(void)notifyFired
{
}

-(void)notifyHitEnemyWithBullet:(GBullet*)bullet
{
}

@end


@implementation GTank

@synthesize tankClass;
@synthesize yaw = tankYaw;
@synthesize team;
@synthesize bodyModel = body, turretModel = turret, barrelModel = barrel, icon;
@synthesize collisionRadius, armor, maxArmor, desertionTimer, currentSpeed;
@synthesize isCopyOf;

-(id)initWithFile:(NSString*)filename
{
	if ((self = [super init])) {
		isCopyOf = nil;
		
		XScriptNode *script = [[XScriptNode alloc] initWithFile:filename]; assert(script);
		XScriptNode *root = [script getSubnodeByName:@"tank"]; assert(root);
		
		tankClass = [[root getSubnodeByName:@"class"] getValueI:0];
		
		mediaFolder = [@"Media/" stringByAppendingString:[[root getSubnodeByName:@"media_folder"] getValue:0]];
		[mediaFolder retain];
		
		icon = [XTexture mediaRetainFile:[mediaFolder stringByAppendingString:@"icon.tga"] usingMedia:gGame->mapMedia];
		
		body = [[XModel alloc] initWithFile:[mediaFolder stringByAppendingString:@"body.xmesh"] usingMedia:gGame->mapMedia];
		turret = [[XModel alloc] initWithFile:[mediaFolder stringByAppendingString:@"turret.xmesh"] usingMedia:gGame->mapMedia];
		barrel = [[XModel alloc] initWithFile:[mediaFolder stringByAppendingString:@"barrel.xmesh"] usingMedia:gGame->mapMedia];
		shadow = [[XModel alloc] initWithFile:[mediaFolder stringByAppendingString:@"shadow.xmesh"] usingMedia:gGame->mapMedia];		
		
		XMaterial material = xglGetDefaultMaterial();
		material.specular = xColor(0.2, 0.2, 0.2, 1);
		material.shininess = 5;
		
		body->material = material;
		turret->material = material;
		barrel->material = material;
		
		material.ambient = xColor(0.05, 0.05, 0.05, 1);
		material.specular = xColor(0, 0, 0, 0);
		material.diffuse = material.specular;
		material.shininess = 0;
		shadow->material = material;
		
		turret.parent = body;
		barrel.parent = turret;
		
		maxArmor = [[root getSubnodeByName:@"armor"] getValueF:0];
		maxTurnSpeed = [[root getSubnodeByName:@"turn_speed"] getValueF:0];
		maxMoveSpeed = [[root getSubnodeByName:@"move_speed"] getValueF:0];
		maxAcceleration = [[root getSubnodeByName:@"acceleration"] getValueF:0];
		
		XScriptNode *node = [root getSubnodeByName:@"gun"];
		{
			XScriptNode *snode = [node getSubnodeByName:@"turret_pivot"];
			turretPivot.x = [snode getValueF:0];
			turretPivot.y = [snode getValueF:1];
			turretPivot.z = [snode getValueF:2];
			
			snode = [node getSubnodeByName:@"barrel_pivot"];
			barrelPivot.x = [snode getValueF:0];
			barrelPivot.y = [snode getValueF:1];
			barrelPivot.z = [snode getValueF:2];
			
			fireRate = [[node getSubnodeByName:@"fire_rate"] getValueF:0];
			gunVelocity = [[node getSubnodeByName:@"velocity"] getValueF:0];
			gunPower = [[node getSubnodeByName:@"power"] getValueF:0];
			
			snode = [node getSubnodeByName:@"ground_impact_effect"];
			NSString *file = [@"Media/" stringByAppendingString:[[snode getSubnodeByName:@"high_quality"] getValue:0]];
			groundImpactEffect_high = [XParticleEffect mediaRetainFile:file usingMedia:gGame->mapMedia];
			file = [@"Media/" stringByAppendingString:[[snode getSubnodeByName:@"medium_quality"] getValue:0]];
			groundImpactEffect_medium = [XParticleEffect mediaRetainFile:file usingMedia:gGame->mapMedia];
			file = [@"Media/" stringByAppendingString:[[snode getSubnodeByName:@"low_quality"] getValue:0]];
			groundImpactEffect_low = [XParticleEffect mediaRetainFile:file usingMedia:gGame->mapMedia];
		
			NSArray *impactNodes = [node subnodesWithName:@"tank_impact_effect"];
			numTankImpactEffects = impactNodes.count;
			tankImpactEffects = malloc(sizeof(XParticleEffect*) * numTankImpactEffects);
			int i = 0;
			for (XScriptNode *node in impactNodes) {
				NSString *file = [@"Media/" stringByAppendingString:[node getValue:0]];
				tankImpactEffects[i++] = [XParticleEffect mediaRetainFile:file usingMedia:gGame->mapMedia];
			}
		}

		NSArray *explosionNodes = [root subnodesWithName:@"explosion_effect"];
		numExplosionEffects = explosionNodes.count;
		explosionEffects = malloc(sizeof(XParticleEffect*) * numExplosionEffects);
		int i = 0;
		for (XScriptNode *node in explosionNodes) {
			NSString *file = [@"Media/" stringByAppendingString:[node getValue:0]];
			explosionEffects[i++] = [XParticleEffect mediaRetainFile:file usingMedia:gGame->mapMedia];
		}
		
		armor = maxArmor;
		
		collisionRadius = body.boundingRadius;
		
		[script release];
	}
	return self;
}

-(id)initWithTank:(GTank*)tank
{
	if ((self = [super init])) {
		if (tank->isCopyOf != nil)
			isCopyOf = tank->isCopyOf;
		else
			isCopyOf = tank;
		
		mediaFolder = tank->mediaFolder;
		[mediaFolder retain];
		
		tankClass = tank->tankClass;
		
		icon = tank->icon;
		[icon mediaRetain];
		
		body = [[XModel alloc] initWithModel:tank->body];
		turret = [[XModel alloc] initWithModel:tank->turret];
		barrel = [[XModel alloc] initWithModel:tank->barrel];
		shadow = [[XModel alloc] initWithModel:tank->shadow];
		
		turret.parent = body;
		barrel.parent = turret;
		
		maxArmor = tank->maxArmor;
		maxTurnSpeed = tank->maxTurnSpeed;
		maxMoveSpeed = tank->maxMoveSpeed;
		maxAcceleration = tank->maxAcceleration;
		turretPivot = tank->turretPivot;
		barrelPivot = tank->barrelPivot;
		fireRate = tank->fireRate;
		gunVelocity = tank->gunVelocity;
		gunPower = tank->gunPower;
		
		groundImpactEffect_high = tank->groundImpactEffect_high;
		[groundImpactEffect_high mediaRetain];
		groundImpactEffect_medium = tank->groundImpactEffect_medium;
		[groundImpactEffect_medium mediaRetain];
		groundImpactEffect_low = tank->groundImpactEffect_low;
		[groundImpactEffect_low mediaRetain];
		
		numTankImpactEffects = tank->numTankImpactEffects;
		tankImpactEffects = malloc(sizeof(XParticleEffect*) * numTankImpactEffects);
		for (int i = 0; i < numTankImpactEffects; ++i) {
			tankImpactEffects[i] = tank->tankImpactEffects[i];
			[tankImpactEffects[i] mediaRetain];
		}
		
		numExplosionEffects = tank->numExplosionEffects;
		explosionEffects = malloc(sizeof(XParticleEffect*) * numExplosionEffects);
		for (int i = 0; i < numExplosionEffects; ++i) {
			explosionEffects[i] = tank->explosionEffects[i];
			[explosionEffects[i] mediaRetain];
		}
		
		team = tank->team;
		armor = tank->armor;
		collisionRadius = tank->collisionRadius;
		
		frameCount = rand() % 5;
	}
	return self;
}

-(void)dealloc
{
	self.scene = nil;
	self.controller = nil;
	
	[groundImpactEffect_high mediaRelease];
	[groundImpactEffect_medium mediaRelease];
	[groundImpactEffect_low mediaRelease];
	
	for (int i = 0; i < numTankImpactEffects; ++i) {
		[tankImpactEffects[i] mediaRelease];
	}
	free(tankImpactEffects);
	
	for (int i = 0; i < numExplosionEffects; ++i) {
		[explosionEffects[i] mediaRelease];
	}
	free(explosionEffects);
	
	[body release];
	[turret release];
	[barrel release];
	[shadow release];
	[icon mediaRelease];
	[mediaFolder release];
	[super dealloc];
}

-(GTank*)spawnAt:(XVector2)pos
{
	GTank *copy = [[GTank alloc] initWithTank:self];
	copy.position = pos;
	copy.yaw = xRand() * TWO_PI;
	copy.scene = gGame->scene;
	
	GTankAIController *c = [[GTankAIController alloc] init];
	c.skillLevel = AISkill_Expert;
	copy.controller = c;
	[c release];
	
	// point the tank at the base of most importance
	XScalar maximportance = 0;
	GOutpost *maxcpoint = nil;
	for (GOutpost *cp in gGame->outpostList) {
		XScalar xd = cp.position->x - pos.x;
		XScalar zd = cp.position->z - pos.y;
		XScalar dist = xSqrt(xd*xd + zd*zd);
		
		if (dist > cp.spawnRadius*2) {
			float importance = 200.0f / dist;
			if (cp.owningTeam != copy.team) {
				if (cp.owningTeam == nil)
					importance *= 0.5f;
				else
					importance *= 10.0f;
			}
			if (cp.owningTeam == copy.team && (cp.inConflict || cp.beingCaptured))
				importance *= 15.0f;
			if (importance > maximportance) {
				maximportance = importance;
				maxcpoint = cp;
			}
		}
	}
	if (maxcpoint) {
		XVector2 lookVec;
		lookVec.x = maxcpoint.position->x - pos.x;
		lookVec.y = maxcpoint.position->z - pos.y;
		copy.yaw = xATan2(lookVec.x, -lookVec.y);
	} else {
		NSLog(@"Warning: Could not find base to point spawned tank at");
	}
	
	[gGame->tankList addObject:copy];
	[copy release];
	return copy;
}

-(void)setController:(GTankController*)ctrl
{
	controller.controlTarget = nil;
	[controller release];
	controller = ctrl;
	[controller retain];
	controller.controlTarget = self;
}

-(GTankController*)controller
{
	return controller;
}

-(void)setUnloadedTextures:(NSString*)textureFile
{
	textureFile = [mediaFolder stringByAppendingString:textureFile];
	XTexture *texture = [XTexture mediaRetainFile:textureFile usingMedia:gGame->mapMedia];
	[body setUnloadedTextures:texture];
	[turret setUnloadedTextures:texture];
	[barrel setUnloadedTextures:texture];
	[texture mediaRelease];
}

-(void)setScene:(XScene*)scene
{
	body.scene = scene;
	turret.scene = scene;
	barrel.scene = scene;
	shadow.scene = scene;
}

-(XScene*)scene
{
	return body.scene;
}

-(void)setPosition:(XVector2)pos
{
	body->position.x = pos.x;
	body->position.z = pos.y;
}

-(XVector2)position
{
	XVector2 pos;
	pos.x = body->position.x;
	pos.y = body->position.z;
	return pos;
}

-(void)notifyHitEnemyWithBullet:(GBullet*)bullet
{
	// notify controller
	[controller notifyHitEnemyWithBullet:bullet];
}

-(void)notifyWasHitWithBullet:(GBullet*)bullet
{
	// notify controller
	[controller notifyWasHitWithBullet:bullet];

	// apply impact
	XVector3 tankSize = xSize_BoundingBox(&body->boundingBox);
	XMatrix3 invRot; xBuildYRotationMatrix3(&invRot, -tankYaw);
	XVector3 bulletVel = bullet.currentVelocity;
	bulletVel = xMul_Vec3Mat3(&bulletVel, &invRot);
	pitchRockSpeed -= (bullet->damagePower * 0.1f * bulletVel.z * (tankSize.y / tankSize.z));
	rollRockSpeed += (bullet->damagePower * 0.1f * bulletVel.x * (tankSize.y / tankSize.x));

	// apply damage
	armor -= bullet->damagePower;
	if (armor <= 0) {
		armor = 0;
		[self destroy];
	}
	else {
		// if not destroyed, show bullet->tank impact effect
		XVector3 hitPoint = bullet.currentPosition;
		xSub_Vec3Vec3(&hitPoint, body.globalPosition);
		XMatrix3 invRot = xInvert_Matrix3(body.globalRotation);
		hitPoint = xMul_Vec3Mat3(&hitPoint, &invRot);
		if (hitPoint.x > 0) {
			if (hitPoint.x > body->boundingBox.max.x) hitPoint.x = body->boundingBox.max.x;
			else if (hitPoint.x < body->boundingBox.max.x) hitPoint.x = body->boundingBox.max.x;
		} else {
			if (hitPoint.x < body->boundingBox.min.x) hitPoint.x = body->boundingBox.min.x;
			else if (hitPoint.x < body->boundingBox.min.x) hitPoint.x = body->boundingBox.min.x;
		}
		if (hitPoint.y > 0) {
			if (hitPoint.y > body->boundingBox.max.y) hitPoint.y = body->boundingBox.max.y;
			else if (hitPoint.y < body->boundingBox.max.y) hitPoint.y = body->boundingBox.max.y;
		} else {
			if (hitPoint.y < body->boundingBox.min.y) hitPoint.y = body->boundingBox.min.y;
			else if (hitPoint.y < body->boundingBox.min.y) hitPoint.y = body->boundingBox.min.y;
		}
		if (hitPoint.z > 0) {
			if (hitPoint.z > body->boundingBox.max.z) hitPoint.z = body->boundingBox.max.z;
			else if (hitPoint.z < body->boundingBox.max.z) hitPoint.z = body->boundingBox.max.z;
		} else {
			if (hitPoint.z < body->boundingBox.min.z) hitPoint.z = body->boundingBox.min.z;
			else if (hitPoint.z < body->boundingBox.min.z) hitPoint.z = body->boundingBox.min.z;
		}
		hitPoint = xMul_Vec3Mat3(&hitPoint, body.globalRotation);
		xAdd_Vec3Vec3(&hitPoint, body.globalPosition);
		
		if (bullet.originator) {
			for (int i = 0; i < numTankImpactEffects; ++i) {
				XParticleSystem *particles = [[XParticleSystem alloc] initWithEffect:bullet.originator->tankImpactEffects[i]];
				particles->position = hitPoint;
				[particles notifyTransformsChanged];
				[particles beginAnimation];
				particles.scene = gGame->scene;
				[gGame->particlesPool addObject:particles];
				[particles release];
			}
		}
	}
}

-(void)destroy
{
	armor = 0;
	_removeFromTankList = YES;
	
	// add explosion effect
	for (int i = 0; i < numExplosionEffects; ++i) {
		XParticleSystem *particles = [[XParticleSystem alloc] initWithEffect:explosionEffects[i]];
		particles->position = *body.globalPosition;
		[particles notifyTransformsChanged];
		[particles beginAnimation];
		particles.scene = gGame->scene;
		[gGame->particlesPool addObject:particles];
		[particles release];	
	}
	
	// sound effect
	[gGame->soundPool playExplosionSoundAt:body.globalPosition forcePlay:NO];
	
	self.scene = nil;
	// note: controller.controlTarget shouldn't need to be set to nil if the AI,
	// and other objects that retained this tank properly release it when they
	// realize it's armor == 0 (the controller target is nilled in [GTank dealloc]).
	// In case they don't, however, in release mode this nulls the controller target
	// as soon as a tank is "destroyed" by a bullet, etc. so the player controller for
	// example will know immediately that the player was destroyed.
#ifndef DEBUG
	controller.controlTarget = nil;
#endif
}

-(float)readyToFire
{
	return xSaturate(reloadTimer * fireRate);
}

-(BOOL)frameUpdate:(XSeconds)deltaTime
{
	if (_removeFromTankList)
		return _removeFromTankList;
	
	// update assigned controller
	[controller frameUpdate:deltaTime];
	
	// keep controls within allowed range
	controls.throttle = xClamp(controls.throttle, -1, 1);
	controls.turn = xClamp(controls.turn, -1, 1);
	controls.aimPitch = xClamp(controls.aimPitch, -1, 1);
	controls.aimYaw = xClamp(controls.aimYaw, -1, 1);
	
	// turret rotation
	turretYaw += controls.aimYaw * xDegToRad(180) * deltaTime;
	barrelPitch += controls.aimPitch * xDegToRad(180) * deltaTime;
	XAngle lim = xDegToRad(35) - xDegToRad(10) * (xSin(turretYaw-xDegToRad(90))+1);
	if (barrelPitch > lim) barrelPitch = lim;
	if (barrelPitch < xDegToRad(-45)) barrelPitch = xDegToRad(-45);
	
	xBuildYRotationMatrix3(&turret->rotation, turretYaw);
	turret->position.x = -turretPivot.x; turret->position.y = -turretPivot.y; turret->position.z = -turretPivot.z;
	turret->position = xMul_Vec3Mat3(&turret->position, &turret->rotation);
	turret->position.x += turretPivot.x; turret->position.y += turretPivot.y; turret->position.z += turretPivot.z;
	[turret notifyTransformsChanged];
	
	xBuildXRotationMatrix3(&barrel->rotation, barrelPitch);
	barrel->position.x = -barrelPivot.x; barrel->position.y = -barrelPivot.y; barrel->position.z = -barrelPivot.z;
	barrel->position = xMul_Vec3Mat3(&barrel->position, &barrel->rotation);
	barrel->position.x += barrelPivot.x; barrel->position.y += barrelPivot.y; barrel->position.z += barrelPivot.z;
	[barrel notifyTransformsChanged];

	// move tank forward
	if (currentSpeed < controls.throttle) {
		currentSpeed += maxAcceleration * deltaTime;
		if (currentSpeed > 1)
			currentSpeed = 1;
	}
	else if (currentSpeed > controls.throttle) {
		currentSpeed -= maxAcceleration * deltaTime;
		if (currentSpeed > 0)
			currentSpeed -= maxAcceleration * deltaTime; // double braking speed
		if (currentSpeed < -1)
			currentSpeed = -1;
	}
	XVector3 moveVector; moveVector.x = 0; moveVector.y = 0; moveVector.z = -currentSpeed * maxMoveSpeed * deltaTime;
	moveVector = xMul_Vec3Mat3(&moveVector, &body->rotation);
	xAdd_Vec3Vec3(&body->position, &moveVector);
	xMul_Vec3Scalar(&moveVector, 1.0f / deltaTime);
	
	// fire!
	reloadTimer += deltaTime;
	if (controls.fire == YES) {
		if (self.readyToFire >= 1.0f) {
			// create bullet
			reloadTimer = 0;
			GBullet *bullet = [gGame->bulletGroup fireBullet];
			bullet.originator = self;
			if (rand() % 10 >= 3)
				bullet->damagePower = gunPower * xRangeRand(1.0f, 1.2f);
			else
				bullet->damagePower = gunPower * xRangeRand(0.8f, 1.2f);
			if (!controller.isComputerControlled)
				bullet->collisionRadius = 1.0f; // make it easier for the player to hit tanks
			else {
				if ([(id)controller skillLevel] == AISkill_Flawless)
					bullet->collisionRadius = 1.0f;
				else
					bullet->collisionRadius = 0.0f;
			}

			// set bullet trajectory
			bullet->startPosition = xMul_Vec3Mat3(&barrelPivot, barrel.globalRotation);
			xAdd_Vec3Vec3(&bullet->startPosition, barrel.globalPosition);
			
			XVector3 shootVector;
			shootVector.x = 0; shootVector.y = 0; shootVector.z = -1;
			shootVector = xMul_Vec3Mat3(&shootVector, barrel.globalRotation);

			XVector3 barrelVector = shootVector;
			xMul_Vec3Scalar(&barrelVector, -barrel->boundingBox.min.z);
			xAdd_Vec3Vec3(&bullet->startPosition, &barrelVector);

			xMul_Vec3Scalar(&shootVector, gunVelocity);
			xAdd_Vec3Vec3(&shootVector, &moveVector);
			bullet->startVelocity = shootVector;			
			bullet->gravity = 40;// * (gunVelocity / 200.0f);
			
			// recoil tank
			float recoil = 1.0f;
			if (fireRate > 11)
				recoil = 0.3f;
			XVector3 rockVector;
			rockVector.x = 0; rockVector.y = 0; rockVector.z = -1;
			rockVector = xMul_Vec3Mat3(&rockVector, &turret->rotation);
			XVector3 tankSize = xSize_BoundingBox(&body->boundingBox);
			pitchRockSpeed += rockVector.z * (tankSize.y / tankSize.z) * (7 * recoil);
			rollRockSpeed -= rockVector.x * (tankSize.y / tankSize.x) * (7 * recoil);
			
			[controller notifyFired];
			
			// sound effect
			if (self == gGame->playerController.controlTarget)
				[gGame->soundPool playFireSoundAt:&bullet->startPosition forcePlay:YES];
			else
				[gGame->soundPool playFireSoundAt:&bullet->startPosition forcePlay:NO];
		}
	}
	
	// tank recoil rocking
	pitchRockSpeed -= pitchRock * deltaTime * 5;
	rollRockSpeed -= rollRock * deltaTime * 5;
	if (pitchRock > 0 && pitchRock < 5 && pitchRockSpeed > 0) pitchRockSpeed -= deltaTime * 1;
	if (pitchRock < 0 && pitchRock > -5 && pitchRockSpeed < 0) pitchRockSpeed += deltaTime * 1;
	if (rollRock > 0 && rollRock < 10 && rollRockSpeed > 0) rollRockSpeed -= deltaTime * 6;
	if (rollRock < 0 && rollRock > -10 && rollRockSpeed < 0) rollRockSpeed += deltaTime * 6;

	if (pitchRockSpeed > 0) pitchRockSpeed -= deltaTime * 3;
	if (pitchRockSpeed < 0) pitchRockSpeed += deltaTime * 3;
	if (rollRockSpeed > 0) rollRockSpeed -= deltaTime * 3;
	if (rollRockSpeed < 0) rollRockSpeed += deltaTime * 3;
	
	pitchRock = xClamp(pitchRock + deltaTime * pitchRockSpeed * 10, -5, 5);
	rollRock = xClamp(rollRock + deltaTime * rollRockSpeed * 10, -7, 7);
	
	// auto-heal
	float autohealDest = maxArmor * 0.8f;
	if (armor > 0.01f && armor < autohealDest) {
		armor += 0.03f * deltaTime;
		if (armor > autohealDest) armor = autohealDest;
	}
	
	// collision
	++frameCount;
	if (frameCount > 10) { // check for collision every 10 frames (3 times per sec at 30 FPS)
		frameCount = frameCount % 10;
		XScalar closest = 10000000;
		XVector3 thisPosition = body->position;
		// collision with other tanks
		for (GTank *otherTank in gGame->tankList) {
			if (otherTank != self) {
				// calculate distance to other tank
				XVector3 *otherPosition = &otherTank->body->position;
				XVector3 vec;
				vec.x = thisPosition.x - otherPosition->x;
				vec.y = thisPosition.y - otherPosition->y;
				vec.z = thisPosition.z - otherPosition->z;
				XScalar vecLenSq = xLengthSquared_Vec3(&vec);
				XScalar collisionDist = collisionRadius + otherTank.collisionRadius;
				XScalar collisionDistSq = collisionDist * collisionDist;
				// if distance indicates a collision..
				if (vecLenSq < collisionDistSq) {
					// calculate non-squared distance and normalize the distance vector into a direction vector
					XScalar vecLen = xSqrt(vecLenSq);
					XScalar invVecLen = 1.0f / vecLen;
					vec.x *= invVecLen;
					vec.y *= invVecLen;
					vec.z *= invVecLen;
					// offset both tanks to correct the collision
					XScalar intersection = collisionDist - vecLen;
					body->position.x += vec.x * (intersection * 0.5f);
					body->position.y += vec.y * (intersection * 0.5f);
					body->position.z += vec.z * (intersection * 0.5f);
					[body notifyTransformsChanged];
					otherPosition->x -= vec.x * (intersection * 0.5f);
					otherPosition->y -= vec.y * (intersection * 0.5f);
					otherPosition->z -= vec.z * (intersection * 0.5f);
					[otherTank->body notifyTransformsChanged];
					// if tanks collided, check again next frame
					frameCount += 100;
					otherTank->frameCount += 100;
				}
				if (vecLenSq - collisionDistSq < closest)
					closest = vecLenSq - collisionDistSq;
			}
		}
		// collision with bases
		XVector3 thisPosition2;
		thisPosition2.x = body->position.x;
		thisPosition2.y = body->position.z;
		for (GOutpost *outpost in gGame->outpostList) {
			// calculate distance to outpost
			XVector2 outpostPosition;
			outpostPosition.x = outpost.position->x;
			outpostPosition.y = outpost.position->z;
			XVector2 vec;
			vec.x = thisPosition2.x - outpostPosition.x;
			vec.y = thisPosition2.y - outpostPosition.y;
			XScalar vecLenSq = xLengthSquared_Vec2(&vec);
			XScalar collisionDist = collisionRadius + outpost.collisionRadius;
			XScalar collisionDistSq = collisionDist * collisionDist;
			// if distance indicates a collision..
			if (vecLenSq < collisionDistSq) {
				// calculate non-squared distance and normalize the distance vector into a direction vector
				XScalar vecLen = xSqrt(vecLenSq);
				XScalar invVecLen = 1.0f / vecLen;
				vec.x *= invVecLen;
				vec.y *= invVecLen;
				// offset tank to correct the collision
				XScalar intersection = collisionDist - vecLen;
				body->position.x += vec.x * intersection;
				body->position.z += vec.y * intersection;
				[body notifyTransformsChanged];				
				// if tank collided, check again next frame
				frameCount += 100;
			}
			if (vecLenSq - collisionDistSq < closest)
				closest = vecLenSq - collisionDistSq;
		}
		// collision with trees
		if (gGame->treeArray) {
			for (int i = 0; i < gGame->treeCount; ++i) {
				// calculate distance to tree
				XTreeInstance *tree = &gGame->treeArray[i];
				XVector2 treePosition = tree->position;
				XVector2 vec;
				vec.x = thisPosition2.x - treePosition.x;
				vec.y = thisPosition2.y - treePosition.y;
				XScalar vecLenSq = xLengthSquared_Vec2(&vec);
				XScalar collisionDist = collisionRadius + 0.1f;
				XScalar collisionDistSq = collisionDist * collisionDist;
				// if distance indicates a collision..
				if (vecLenSq < collisionDistSq) {
					// calculate non-squared distance and normalize the distance vector into a direction vector
					XScalar vecLen = xSqrt(vecLenSq);
					XScalar invVecLen = 1.0f / vecLen;
					vec.x *= invVecLen;
					vec.y *= invVecLen;
					// offset tank to correct the collision
					XScalar intersection = collisionDist - vecLen;
					body->position.x += vec.x * intersection;
					body->position.z += vec.y * intersection;
					[body notifyTransformsChanged];				
					// if tank collided, check again next frame
					frameCount += 100;
				}
				if (vecLenSq - collisionDistSq < closest)
					closest = vecLenSq - collisionDistSq;
			}
		}
		// if very close to an object, check collisions faster
		if (closest < 1*1)
			frameCount += 10;
		else if (closest < 5*5)
			frameCount += 7;
	}
	
	// darken terrain color when in terrain shadow
	float light = xSaturate([gGame->terrain sampleTerrainLightmapAt:&body->position] * 3);
	float diffuse = light * 1.0f - 0.2f;
	float ambient = light * 0.2f;
	XColor diffuseC = xColor(diffuse, diffuse, diffuse, 1);
	XColor ambientC = xColor(ambient, ambient, ambient, 1);
	body->material.diffuse = diffuseC; body->material.ambient = ambientC;
	turret->material.diffuse = diffuseC; turret->material.ambient = ambientC;
	barrel->material.diffuse = diffuseC; barrel->material.ambient = ambientC;

	// get heights of terrain under corners of tank
	XScalar tankWidth = xAbs(body->boundingBox.max.x - body->boundingBox.min.x);
	XScalar tankLength = xAbs(body->boundingBox.max.z - body->boundingBox.min.z);
	XVector3 pvec;
	pvec.x = -tankWidth*0.5f; pvec.y = 0; pvec.z = -tankLength*0.5f;
	pvec = xMul_Vec3Mat3(&pvec, &body->rotation); xAdd_Vec3Vec3(&pvec, &body->position);
	XTerrainIntersection FL = [gGame->terrain intersectTerrainVerticallyAt:&pvec];

	pvec.x = tankWidth*0.5f; pvec.y = 0; pvec.z = -tankLength*0.5f;
	pvec = xMul_Vec3Mat3(&pvec, &body->rotation); xAdd_Vec3Vec3(&pvec, &body->position);
	XTerrainIntersection FR = [gGame->terrain intersectTerrainVerticallyAt:&pvec];
	
	pvec.x = -tankWidth*0.5f; pvec.y = 0; pvec.z = tankLength*0.5f;
	pvec = xMul_Vec3Mat3(&pvec, &body->rotation); xAdd_Vec3Vec3(&pvec, &body->position);
	XTerrainIntersection BL = [gGame->terrain intersectTerrainVerticallyAt:&pvec];

	pvec.x = tankWidth*0.5f; pvec.y = 0; pvec.z = tankLength*0.5f;
	pvec = xMul_Vec3Mat3(&pvec, &body->rotation); xAdd_Vec3Vec3(&pvec, &body->position);
	XTerrainIntersection BR = [gGame->terrain intersectTerrainVerticallyAt:&pvec];
	
	// adjust tank height to sit on terrain without intersecting
	XTerrainIntersection intersectionC = [gGame->terrain intersectTerrainVerticallyAt:&body->position];
	XScalar cA = (FR.point.y + BL.point.y) * 0.5f;
	XScalar cB = (FL.point.y + BR.point.y) * 0.5f;
	XScalar centerHeight = intersectionC.point.y;
	if (cA > centerHeight) centerHeight = cA;
	if (cB > centerHeight) centerHeight = cB;	
	body->position.y = centerHeight + 0.1f;

	// calculate the pitch angles of the right and left tracks
	XAngle rAng = xATan2(BR.point.y - FR.point.y, tankLength);
	XAngle lAng = xATan2(BL.point.y - FL.point.y, tankLength);
	
	// calculate the roll angles between the two tracks (front and back)
	XAngle fAng = xATan2(FL.point.y - FR.point.y, tankWidth);
	XAngle bAng = xATan2(BL.point.y - BR.point.y, tankWidth);
	
	// calculate the average of the values to be used in the final rotation
	XAngle pitch = (rAng + lAng) * 0.5f;
	XAngle roll = (fAng + bAng) * 0.5f;
	
	// tank yaw
	if (currentTurnSpeed < controls.turn) {
		currentTurnSpeed += 5.0f * deltaTime;
		if (currentTurnSpeed > 1)
			currentTurnSpeed = 1;
	}
	else if (currentTurnSpeed > controls.turn) {
		currentTurnSpeed -= 5.0f * deltaTime;
		if (currentTurnSpeed < -1)
			currentTurnSpeed = -1;
	}
	tankYaw += currentTurnSpeed * maxTurnSpeed * deltaTime;
	tankYaw = xClampAngle(tankYaw);
	
	// apply rotations
	XMatrix3 tmpMat;
	xBuildZRotationMatrix3(&body->rotation, roll + xDegToRad(rollRock));
	xBuildXRotationMatrix3(&tmpMat, pitch + xDegToRad(pitchRock));
	body->rotation = xMul_Mat3Mat3(&tmpMat, &body->rotation);
	xBuildYRotationMatrix3(&tmpMat, tankYaw);
	body->rotation = xMul_Mat3Mat3(&tmpMat, &body->rotation);
	[body notifyTransformsChanged];
	
	// update shadow
	//XScalar shadowDistSq = [gGame->camera distanceSquaredTo:&body->position];
	//if (shadowDistSq < 100*100) {
	//	shadow.scene = gGame->scene;
		shadow->position = body->position;
		xBuildZRotationMatrix3(&shadow->rotation, roll);
		xBuildXRotationMatrix3(&tmpMat, pitch);
		shadow->rotation = xMul_Mat3Mat3(&tmpMat, &shadow->rotation);
		xBuildYRotationMatrix3(&tmpMat, tankYaw);
		shadow->rotation = xMul_Mat3Mat3(&tmpMat, &shadow->rotation);
		[shadow notifyTransformsChanged];
		// "fade out" into terrain
		//XScalar shadowDist = xSqrt(shadowDistSq);
		//XScalar fade = xSaturate((shadowDist - 80) / 20.0f);
		//shadow->position.y -= fade * 0.5f;
	//} else {
	//	shadow.scene = nil;
	//}
	
	// desertion (going out of bounds)
	const XScalar border = 150, border2 = 50;
	if (body->position.x > gGame->terrain->boundingBox.max.x - border ||
		body->position.x < gGame->terrain->boundingBox.min.x + border ||
		body->position.z > gGame->terrain->boundingBox.max.z - border ||
		body->position.z < gGame->terrain->boundingBox.min.z + border)
	{
		desertionTimer += deltaTime;
		if (desertionTimer > 10.0f ||
			body->position.x > gGame->terrain->boundingBox.max.x - border2 ||
			body->position.x < gGame->terrain->boundingBox.min.x + border2 ||
			body->position.z > gGame->terrain->boundingBox.max.z - border2 ||
			body->position.z < gGame->terrain->boundingBox.min.z + border2)
		{
			// destory deserters
			[self destroy];
		}
	}
	else {
		desertionTimer = 0;
	}
	
	return _removeFromTankList;
}

-(void)saveStateToFile:(FILE*)file
{
	XVector2 pos = self.position;
	fwrite((void*)&pos, sizeof(pos), 1, file);
	fwrite((void*)&tankYaw, sizeof(tankYaw), 1, file);
	fwrite((void*)&turretYaw, sizeof(turretYaw), 1, file);
	fwrite((void*)&barrelPitch, sizeof(barrelPitch), 1, file);
	fwrite((void*)&currentSpeed, sizeof(barrelPitch), 1, file);
	fwrite((void*)&currentTurnSpeed, sizeof(barrelPitch), 1, file);
	fwrite((void*)&armor, sizeof(armor), 1, file);
	fwrite((void*)&reloadTimer, sizeof(reloadTimer), 1, file);
}

-(void)loadStateFromFile:(FILE*)file
{
	XVector2 pos;
	fread((void*)&pos, sizeof(pos), 1, file);
	self.position = pos;
	fread((void*)&tankYaw, sizeof(tankYaw), 1, file);
	fread((void*)&turretYaw, sizeof(turretYaw), 1, file);
	fread((void*)&barrelPitch, sizeof(barrelPitch), 1, file);
	fread((void*)&currentSpeed, sizeof(barrelPitch), 1, file);
	fread((void*)&currentTurnSpeed, sizeof(barrelPitch), 1, file);
	fread((void*)&armor, sizeof(armor), 1, file);
	fread((void*)&reloadTimer, sizeof(reloadTimer), 1, file);
}

@end




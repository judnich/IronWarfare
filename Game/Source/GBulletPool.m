// Copyright © 2010 John Judnich. All rights reserved.

#import "GBulletPool.h"
#import "GGame.h"


@interface GBulletPool (private)

-(GBullet*)activateNewBullet;
-(void)deactivateBulletAtIndex:(int)index;

@end


@implementation GBulletPool

-(id)initWithType:(GBulletType*)bType capacity:(int)capacity
{
	if ((self = [super init])) {
		bulletType = bType;
		[bulletType mediaRetain];
		
		bulletArrayCapacity = capacity;
		bulletArray = malloc(sizeof(GBullet*) * bulletArrayCapacity);
		for (int i = 0; i < bulletArrayCapacity; ++i) {
			GBullet *bullet = [[GBullet alloc] initWithType:bulletType]; assert(bullet);
			bulletArray[i] = bullet;
		}
	}
	return self;
}

-(void)dealloc
{
	for (int i = 0; i < bulletArrayCapacity; ++i) {
		GBullet *bullet = bulletArray[i];
		bullet.scene = nil;
		[bullet release];
	}
	free(bulletArray);
	
	[bulletType mediaRelease];
	[super dealloc];
}

-(GBullet*)activateNewBullet
{
	if (activeBulletCount >= bulletArrayCapacity) {
		// array is not big enough, enlarge it by half the current capacity
		int newCapacity = bulletArrayCapacity + (bulletArrayCapacity / 2) + 1;
		NSLog(@"Resizing bullet pool from %d to %d", bulletArrayCapacity, newCapacity);
		GBullet **newArray = malloc(sizeof(GBullet*) * newCapacity);
		memcpy(newArray, bulletArray, sizeof(GBullet*) * bulletArrayCapacity);
		free(bulletArray);
		for (int i = bulletArrayCapacity; i < newCapacity; ++i) {
			GBullet *bullet = [[GBullet alloc] initWithType:bulletType]; assert(bullet);
			newArray[i] = bullet;
		}
		bulletArray = newArray;
		bulletArrayCapacity = newCapacity;
	}
	assert(activeBulletCount < bulletArrayCapacity);
	GBullet *bullet = bulletArray[activeBulletCount++];
	bullet.scene = gGame->scene;
	return bullet;	
}

-(void)deactivateBulletAtIndex:(int)index
{
	// remove the bullet from the scene and swap out of the active portion of the array
	if (index < activeBulletCount) {
		GBullet *bullet = bulletArray[index];
		[bullet reinit];
		bulletArray[index] = bulletArray[activeBulletCount-1];
		bulletArray[activeBulletCount-1] = bullet;
		--activeBulletCount;
	}
	else {
		NSLog(@"Error deactivating bullet - already deactivated.");
	}
}

-(GBullet*)fireBullet
{
	GBullet *bullet = [self activateNewBullet];
	bullet.scene = gGame->scene;
	return bullet;
}

-(void)frameUpdate:(XSeconds)deltaTime
{
	for (int i = 0; i < activeBulletCount; ++i) {
		GBullet *bullet = bulletArray[i];
		if ([bullet frameUpdate:deltaTime] == NO) {
			// bullet has struck a target and needs to be deleted
			[self deactivateBulletAtIndex:i];
			--i;
		}
	}
}

@end

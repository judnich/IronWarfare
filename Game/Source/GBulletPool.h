// Copyright © 2010 John Judnich. All rights reserved.

#import "GBullet.h"


@interface GBulletPool : NSObject {
	GBulletType *bulletType;
	GBullet **bulletArray;
	int bulletArrayCapacity;
	int activeBulletCount;
}

-(id)initWithType:(GBulletType*)bType capacity:(int)capacity;
-(void)dealloc;

-(GBullet*)fireBullet;
-(void)frameUpdate:(XSeconds)deltaTime;

@end

// Copyright © 2010 John Judnich. All rights reserved.

#import "X2D.h"


@interface GMap : NSObject {
	XTexture *mapImage;
	XTexture *mapText, *mapButtons1, *mapButtons2, *flagIcon, *notAvailibleIcon;
	float flashTimer;
}

-(id)init;
-(void)dealloc;

-(void)draw:(XSeconds)deltaTime;
-(void)notifyTouch:(CGPoint)point;

@end

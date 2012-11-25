// Copyright © 2010 John Judnich. All rights reserved.

#import "X2D.h"
#import "XTime.h"
#import "XTextureNomip.h"
@class GTank;


@interface GHUD : NSObject {
	XTexture *crosshairs, *flag;
	XTexture *arrow, *fireButton;
	XTexture *armorBar, *armorBG;
	XTexture *victoryDefeatMessage;
	XTexture *desertionWarning, *menuButton;
	XSeconds hitIndicatorLife, damageWobbleLife;
	XSeconds flashTimer, gameoverTimer;
	float moving, strafe, armor, warning, reverse;
	float menuButtonAlpha;
	GTank *lastTank;
}

-(id)init;
-(void)dealloc;

-(void)draw:(XSeconds)deltaTime;

-(void)notifyScoredHit;
-(void)notifyDamaged;
-(void)showMenuButton;

@end

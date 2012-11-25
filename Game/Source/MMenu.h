// Copyright © 2010 John Judnich. All rights reserved.

#import "XMath.h"
#import "XTime.h"
#import "XTexture.h"
#import "XScript.h"
@class GBMusicTrack;

typedef enum
{
	Menu_Main,
	Menu_LevelSelection,
	Menu_Calibration1,
	Menu_Calibration2,
	Menu_Calibration3,
	Menu_Loading,
	Menu_LoadingSaveGame
} MenuState;

@interface MMenu : NSObject {
	int frameSkip;
	BOOL contentLoaded;
	
	XTexture *mainMenu;
	XTexture *levelMenu, *levelMenuButtons;
	XTexture *loadingMenu;
	XTexture *calib1, *calib2, *calib3;
	MenuState currentMenu;
	
	BOOL nextButtonDown, prevButtonDown;
	
	XScriptNode *levelList;
	int selectedLevel;
	XTexture *selectedLevelPreview;
	NSString *selectedLevelFile;
	int loadingCountdown, imageLoadCounter;
	
	XSeconds calibrationTimer;
	XAngle calibrationAngle;
	int calibrationSampleCount;
	
	GBMusicTrack *menuMusic;
	
	BOOL saveStateSoon;
}

@property(readonly) XAngle calibrationAngle;

-(id)init;
-(void)dealloc;

-(void)loadMusic;
-(void)unloadMusic;

-(void)loadContent;
-(void)unloadContent;

-(void)notifyTouch:(CGPoint)point;
-(void)notifyRelease:(CGPoint)point;
-(void)notifyReturnedToMenu;

-(void)renderFrame:(XGameTime)gameTime;

-(void)saveMenuState;
-(void)loadMenuState;

@end

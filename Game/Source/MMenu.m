// Copyright © 2010 John Judnich. All rights reserved.

#import "MMenu.h"
#import "XMath.h"
#import "X2D.h"
#import "XTexture.h"
#import "XScript.h"
#import "GGame.h"
#import "GTankPlayerController.h"
#import "SoundEngine.h"
#import "GBMusicTrack.h"


@implementation MMenu

@synthesize calibrationAngle;

-(id)init
{
	if ((self = [super init])) {
		frameSkip = 1000;
		selectedLevel = 0;
		selectedLevelPreview = nil;
		selectedLevelFile = nil;
		currentMenu = Menu_Main;
		contentLoaded = NO;
		
		calibrationAngle = xDegToRad(-50);

		loadingMenu = [XTexture mediaRetainFile:@"Media/GUI/LoadingMenu.png" usingMedia:gGame->commonMedia];

		[self loadContent];
		[self loadMenuState];
	}
	return self;
}

-(void)dealloc
{
	[loadingMenu mediaRelease];
	[self unloadMusic];
	[self unloadContent];
	[selectedLevelFile release];
	[super dealloc];
}

-(void)loadMusic
{
	if (!menuMusic) {
		NSString *file = @"Media/Sounds/MenuMusic.mp3";
		NSString *directory = [file stringByDeletingLastPathComponent];
		NSString *fileN = [file lastPathComponent];
		NSString *path = [[NSBundle mainBundle] pathForResource:fileN ofType:nil inDirectory:directory];
		menuMusic = [[GBMusicTrack alloc] initWithPath:path];
		[menuMusic setRepeat:YES];	
	}
}

-(void)unloadMusic
{
	if (menuMusic) {
		[menuMusic close];
		[menuMusic release];
		menuMusic = NULL;
	}
}

-(void)loadContent
{
	if (contentLoaded)
		return;
	contentLoaded = YES;

	[self loadMusic];
	[menuMusic play];

	mainMenu = [XTexture mediaRetainFile:@"Media/GUI/MainMenu.png" usingMedia:gGame->commonMedia];
	levelMenu = [XTexture mediaRetainFile:@"Media/GUI/LevelMenu.png" usingMedia:gGame->commonMedia];
	levelMenuButtons = [XTexture mediaRetainFile:@"Media/GUI/LevelMenuButtons.png" usingMedia:gGame->commonMedia];
	levelList = [[XScriptNode alloc] initWithFile:@"Media/levels.list"];
}

-(void)unloadContent
{
	if (!contentLoaded)
		return;
	contentLoaded = NO;
	
	[menuMusic pause];
	
	[mainMenu mediaRelease];
	[levelMenu mediaRelease];
	[levelMenuButtons mediaRelease];
	[levelList release];

	[selectedLevelPreview mediaRelease];
	selectedLevelPreview = nil;
}

-(void)notifyTouch:(CGPoint)point
{
	frameSkip = 1000;
	switch (currentMenu) {
		case Menu_Main:
			if (point.x >= 348-10 && point.y >= 63-10 && point.x <= 463+10 && point.y <= 109+10)
				currentMenu = Menu_LevelSelection;
			if (point.x >= 347-10 && point.y >= 237-10 && point.x <= 463+10 && point.y <= 265+10) {
				calibrationTimer = 4;
				currentMenu = Menu_Calibration1;
			}
			break;
			
		case Menu_LevelSelection:
			if (point.x >= 16-20 && point.y >= 285-20 && point.x <= 99+20 && point.y <= 314+20)
				currentMenu = Menu_Main;
			
			if (point.x >= 284-20 && point.y >= 64-20 && point.x <= 463+20 && point.y <= 111+3) {
				nextButtonDown = YES;
				++selectedLevel;
				imageLoadCounter = 2;
			}
			
			if (point.x >= 284-20 && point.y >= 124-3 && point.x <= 463+20 && point.y <= 172+20) {
				prevButtonDown = YES;
				--selectedLevel;
				imageLoadCounter = 2;
			}
			
			if (point.x >= 284-20 && point.y >= 213-5 && point.x <= 463+20 && point.y <= 260+20) {
				currentMenu = Menu_Loading;
			}
			break;
			
		case Menu_Calibration1:
		case Menu_Calibration2:
		case Menu_Calibration3:
			if (point.x >= 16-20 && point.y >= 285-20 && point.x <= 99+20 && point.y <= 314+20) {
				[calib1 mediaRelease]; calib1 = nil;
				[calib2 mediaRelease]; calib2 = nil;
				[calib3 mediaRelease]; calib3 = nil;				
				currentMenu = Menu_Main;
			}
			break;
			
		case Menu_Loading:
		case Menu_LoadingSaveGame:
			break;
	}
	saveStateSoon = YES;
}

-(void)notifyRelease:(CGPoint)point
{
	prevButtonDown = NO;
	nextButtonDown = NO;
	frameSkip = 1000;
}

-(void)notifyReturnedToMenu
{
	saveStateSoon = YES;
	loadingCountdown = 0;
	frameSkip = 1000;
}

-(void)renderFrame:(XGameTime)gameTime
{
	XIntRect rect;
	rect.left = 0; rect.top = 0;
	rect.right = 0+512; rect.bottom = 0+512;

	// load menu content (and unload game) if not already
	if (!contentLoaded) {
		x2D_begin();
		x2D_setTexture(loadingMenu);
		x2D_drawRect(&rect);
		x2D_end();
		
		++loadingCountdown;
		if (loadingCountdown >= 3) {
			loadingCountdown = 0;
			[gGame unloadMap];
			[self loadContent];
		}
		
		return;
	}
	
	// load the next level image preview when necessary
	--imageLoadCounter;
	if (imageLoadCounter == 0) {
		[selectedLevelPreview mediaRelease];
		selectedLevelPreview = nil;
	}
	if (imageLoadCounter < -1)
		imageLoadCounter = -1;

	// skip frames so the menu doesn't update all the time
	++frameSkip;
	if (currentMenu == Menu_Calibration1 || currentMenu == Menu_Calibration2 || currentMenu == Menu_Calibration3
		|| currentMenu == Menu_Loading || currentMenu == Menu_LoadingSaveGame)
		frameSkip = 1000;
	//if (frameSkip < 100)
	//	return;
	frameSkip = 0;
	
	if (saveStateSoon) {
		saveStateSoon = NO;
		[self saveMenuState];
	}
	
	x2D_begin();	
	x2D_enableTransparency();
		
	switch (currentMenu) {
		case Menu_Main:
			x2D_setTexture(mainMenu);
			x2D_drawRect(&rect);
			break;
			
		case Menu_LevelSelection:
			x2D_setTexture(levelMenu);
			x2D_drawRect(&rect);
			
			XIntRect rect2;
			XScalarRect region;
			
			rect2.left = 278; rect2.top = 59;
			rect2.right = rect2.left + levelMenuButtons.width;
			rect2.bottom = rect2.top + levelMenuButtons.height;
			region.left = 0; region.right = 1;
			if (nextButtonDown)
				region.top = 0;
			else
				region.top = 56.0f / 256.0f;
			if (prevButtonDown)
				region.bottom = 0.5f;
			else
				region.bottom = 58.0f / 256.0f;
			x2D_setTexture(levelMenuButtons);
			x2D_drawRectCropped(&rect2, &region);
			
			if (selectedLevelPreview == nil) {
				// this code calculates the path to the selected level index and gets a preview image of it
				int levelCount = [levelList getSubnodeByIndex:0].subnodeCount;
				if (selectedLevel < 0) selectedLevel = 0;
				if (selectedLevel > levelCount-1) selectedLevel = levelCount-1;
				
				XScriptNode *mapFolderNode = [levelList getSubnodeByIndex:0];
				NSString *mapFolder = [@"Media/" stringByAppendingPathComponent:mapFolderNode.name];
				
				XScriptNode *mapFileNode = [mapFolderNode getSubnodeByIndex:selectedLevel];
				NSString *mapFile = mapFileNode.name;
				
				[selectedLevelFile release];
				selectedLevelFile = [mapFolder stringByAppendingPathComponent:mapFile];
				[selectedLevelFile retain];
				
				XScriptNode *mapScript = [[XScriptNode alloc] initWithFile:selectedLevelFile];
				XScriptNode *root = [mapScript getSubnodeByName:@"map"]; assert(root);				
				NSString *levelFolder = [@"Media/" stringByAppendingString:[[root getSubnodeByName:@"media_folder"] getValue:0]];
				[mapScript release];
				
				NSString *previewFile = [levelFolder stringByAppendingPathComponent:@"preview.png"];
				
				selectedLevelPreview = [XTexture mediaRetainFile:previewFile usingMedia:gGame->commonMedia];
			}
			
			x2D_setTexture(selectedLevelPreview);
			rect.left = 17; rect.top = 62;
			rect.right = 16+256; rect.bottom = 62+256;
			region.top = 0; region.left = 0;
			region.right = 1; region.bottom = 200.0f / 256.0f;
			x2D_drawRectCropped(&rect, &region);
			break;
			
		case Menu_Loading:
			x2D_setTexture(loadingMenu);
			x2D_drawRect(&rect);
			
			++loadingCountdown;
			if (loadingCountdown >= 3) {
				[self saveMenuState];
				if (selectedLevel == 0)
					gGame.tutorialMode = YES;
				else
					gGame.tutorialMode = NO;
				loadingCountdown = 0;
				gGame->menuMode = NO;
				currentMenu = Menu_LevelSelection;
				
				[gGame loadMap:selectedLevelFile];

				if (selectedLevel == 5 || selectedLevel == 8 || selectedLevel == 20)
					gGame->cheat1 = YES;

				[self unloadContent];
			}
			break;
			
		case Menu_LoadingSaveGame:
			x2D_setTexture(loadingMenu);
			x2D_drawRect(&rect);
			
			++loadingCountdown;
			if (loadingCountdown >= 3) {
				if (selectedLevel == 0)
					gGame.tutorialMode = YES;
				else
					gGame.tutorialMode = NO;
				loadingCountdown = 0;
				gGame->menuMode = NO;
				currentMenu = Menu_LevelSelection;
				
				[gGame loadGame];
				
				if (selectedLevel == 5 || selectedLevel == 8 || selectedLevel == 20)
					gGame->cheat1 = YES;
				
				[self unloadContent];
			}
			break;
			
		case Menu_Calibration1:
			if (!calib1)
				calib1 = [XTexture mediaRetainFile:@"Media/GUI/CalibrateMenu1.png" usingMedia:gGame->commonMedia];
			x2D_setTexture(calib1);
			x2D_drawRect(&rect);
			
			calibrationTimer -= gameTime.deltaTime;
			if (calibrationTimer <= 0) {
				calibrationTimer = 2;
				[calib1 mediaRelease];
				calib1 = nil;
				currentMenu = Menu_Calibration2;
				calibrationAngle = 0;
				calibrationSampleCount = 0;
			}
			break;
			
		case Menu_Calibration2:
			if (!calib2)
				calib2 = [XTexture mediaRetainFile:@"Media/GUI/CalibrateMenu2.png" usingMedia:gGame->commonMedia];
			x2D_setTexture(calib2);
			x2D_drawRect(&rect);
			
			// calibrate
			XAngle angle = xClampAngle(PI - xATan2(gGame->acceleration.z, gGame->acceleration.x));
			calibrationAngle += angle;
			++calibrationSampleCount;

			calibrationTimer -= gameTime.deltaTime;
			if (calibrationTimer <= 0) {
				// finish calibration
				calibrationAngle /= calibrationSampleCount;
				calibrationSampleCount = 1;
				NSLog(@"Calibrated with average angle: %f degrees.", xRadToDeg(calibrationAngle));
				
				calibrationTimer = 2;
				[calib2 mediaRelease];
				calib2 = nil;
				currentMenu = Menu_Calibration3;
			}
			break;
			
		case Menu_Calibration3:
			if (!calib3)
				calib3 = [XTexture mediaRetainFile:@"Media/GUI/CalibrateMenu3.png" usingMedia:gGame->commonMedia];
			x2D_setTexture(calib3);
			x2D_drawRect(&rect);

			calibrationTimer -= gameTime.deltaTime;
			if (calibrationTimer <= 0) {
				[calib3 mediaRelease];
				calib3 = nil;
				currentMenu = Menu_Main;
			}
			break;
	}
	
	x2D_end();
	
	[gGame->commonMedia freeDeadResourcesWithTimeout:5.0f];
}

-(void)saveMenuState
{
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	NSString *documentsDirectory = [paths objectAtIndex:0];
	NSString *filePath = [documentsDirectory stringByAppendingPathComponent:@"menu.save"];
	FILE *file = fopen([filePath UTF8String], "wb");
	
	fwrite((void*)&selectedLevel, sizeof(selectedLevel), 1, file);
	if (currentMenu != Menu_Calibration1 && currentMenu != Menu_Calibration2 && currentMenu != Menu_Calibration3) {
		if (gGame->menuMode == NO)
			currentMenu = Menu_Loading;
		int cmenui = (int)currentMenu;
		fwrite((void*)&cmenui, sizeof(cmenui), 1, file);
	}
	else {
		int cmenui = (int)Menu_Main;
		fwrite((void*)&cmenui, sizeof(cmenui), 1, file);
	}
	
	fwrite((void*)&calibrationAngle, sizeof(calibrationAngle), 1, file);
	
	fclose(file);
}

-(void)loadMenuState
{
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	NSString *documentsDirectory = [paths objectAtIndex:0];
	NSString *filePath = [documentsDirectory stringByAppendingPathComponent:@"menu.save"];
	FILE *file = fopen([filePath UTF8String], "rb");
	if (!file) return;
	
	fread((void*)&selectedLevel, sizeof(selectedLevel), 1, file);
	
	int cmenui = 0;
	fread((void*)&cmenui, sizeof(cmenui), 1, file);
	currentMenu = (MenuState)cmenui;
	
	if (currentMenu == Menu_Loading) {
		currentMenu = Menu_LoadingSaveGame;
	}
	
	fread((void*)&calibrationAngle, sizeof(calibrationAngle), 1, file);
		
	fclose(file);

	[selectedLevelPreview mediaRelease];
	selectedLevelPreview = nil;
}

@end

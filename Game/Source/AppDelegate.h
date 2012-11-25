// Copyright © 2010 John Judnich. All rights reserved.

#import <UIKit/UIKit.h>
#import "GLView.h"

#import "GGame.h"
#define GAME_CLASS GGame

@interface AppDelegate : NSObject<UIApplicationDelegate>
{
	UIWindow *window;
	GLView *glView;
	GAME_CLASS *game;
	NSThread *gameLoopThread;
	volatile BOOL continueGameLoopThread;
	float currentFramerateCap;
	BOOL pauseGame;
}

extern int screenWidth, screenHeight;
extern int uiScreenWidth, uiScreenHeight;

@end

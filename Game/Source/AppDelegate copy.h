#import <UIKit/UIKit.h>
#import "GLView.h"

#import "GGame.h"
#define GAME_CLASS GGame

@interface AppDelegate : NSObject<UIApplicationDelegate>
{
	UIWindow *window;
	GLView *glView;
	GAME_CLASS *game;
	
	NSTimer *frameTimer;
	float currentFramerateCap;
	BOOL pauseGame;
	XGameTime gameTime;
	XSeconds lastFrameStartTime;
	CFTimeInterval cfStartTime;
}

@end

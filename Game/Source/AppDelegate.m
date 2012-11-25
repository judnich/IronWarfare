// Copyright © 2010 John Judnich. All rights reserved.

#import "AppDelegate.h"
#import <AudioToolbox/AudioToolbox.h>

#define kFramerateCap 100.0 //FPS


@interface AppDelegate (private)

-(void)runGameLoop;

@end


@implementation AppDelegate

BOOL gOtherAudioIsPlaying = YES;

void checkIfOtherAudioIsPlaying()
{
	UInt32 propertySize, audioIsAlreadyPlaying;
	
	// do not open the track if the audio hardware is already in use (could be the iPod app playing music)
	propertySize = sizeof(UInt32);
	AudioSessionGetProperty(kAudioSessionProperty_OtherAudioIsPlaying, &propertySize, &audioIsAlreadyPlaying);
	if (audioIsAlreadyPlaying != 0)
	{
		gOtherAudioIsPlaying = YES;
		NSLog(@"Other audio is playing");
		
		UInt32 sessionCategory = kAudioSessionCategory_AmbientSound;
		AudioSessionSetProperty(kAudioSessionProperty_AudioCategory, sizeof(sessionCategory), &sessionCategory);
		AudioSessionSetActive(YES);
	}
	else
	{		
		gOtherAudioIsPlaying = NO;
		
		// since no other audio is *supposedly* playing, then we will make sure by changing the audio session category temporarily
		// to kick any system remnants out of hardware (iTunes (or the iPod App, or whatever you wanna call it) sticks around)
		UInt32 sessionCategory = kAudioSessionCategory_MediaPlayback;
		AudioSessionSetProperty(kAudioSessionProperty_AudioCategory, sizeof(sessionCategory), &sessionCategory);
		AudioSessionSetActive(YES);
		
		// now change back to ambient session category so our app honors the "silent switch"
		sessionCategory = kAudioSessionCategory_SoloAmbientSound;
		AudioSessionSetProperty(kAudioSessionProperty_AudioCategory, sizeof(sessionCategory), &sessionCategory);
	}
}

int uiScreenWidth, uiScreenHeight;
int screenWidth, screenHeight;

-(void)applicationDidFinishLaunching:(UIApplication*)application
{
	//checkIfOtherAudioIsPlaying();
	
	[application setStatusBarOrientation:UIInterfaceOrientationLandscapeRight animated:NO];
	[application setIdleTimerDisabled:YES];

	CGRect rect = [[UIScreen mainScreen] bounds];
		
	// create a full-screen window and initialize OpenGL
	window = [[UIWindow alloc] initWithFrame:rect];
	glView = [[GLView alloc] initWithFrame:rect];
	
	// these are reversed due to 90 degree rotation
	screenWidth = glView.backingHeight;
	screenHeight = glView.backingWidth;
	uiScreenWidth = rect.size.height;
	uiScreenHeight = rect.size.width;

	[window addSubview:glView];

	// hook the game class into the OpenGL view as a delegate to render frames
	game = [[GAME_CLASS alloc] init];
	glView.delegate = game;

	// load the game and display the window
	[glView loadContent];
	XGameTime gt; gt.deltaTime = 0; gt.totalTime = 0;
	[glView renderFrame:gt];
	[window makeKeyAndVisible];
	glFinish(); //make sure buffered OpenGL is done so the thread can use OpenGL safely
	
	// run the game loop
	currentFramerateCap = kFramerateCap;
	pauseGame = NO;
	gameLoopThread = [[NSThread alloc] initWithTarget:self selector:@selector(runGameLoop) object:nil];
	[gameLoopThread start];
}

-(void)dealloc
{
	[window release];
	[super dealloc];
}

// application is about to become inactive
-(void)applicationWillResignActive:(UIApplication*)application
{
	NSLog(@"[applicationWillResignActive]");
	@synchronized(glView) {
		currentFramerateCap = 1;
		pauseGame = YES;
	}
}

// application is active again
-(void)applicationDidBecomeActive:(UIApplication*)application
{
	NSLog(@"[applicationDidBecomeActive]");
	@synchronized(glView) {
		currentFramerateCap = kFramerateCap;
		pauseGame = NO;
	}
}

// application is closing
-(void)applicationWillTerminate:(UIApplication*)application
{
	NSLog(@"[applicationWillTerminate]");
	@synchronized(glView) {
		if (gGame)
			[gGame saveGame]; // save game before exiting
	}
	continueGameLoopThread = NO;
	@synchronized(glView) {
		[gameLoopThread release];
		gameLoopThread = nil;
		[glView unloadContent];
		[glView release];
		glView = nil;
	}
	[game release];
}

// low memory
-(void)applicationDidReceiveMemoryWarning:(UIApplication*)application
{
	NSLog(@"[applicationDidReceiveMemoryWarning]");
	[glView notifyLowMemory];
}

-(void)runGameLoop
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	int poolLifeCount = 0;

	XGameTime gameTime;
	gameTime.totalTime = 0;
	gameTime.deltaTime = 1.0f / currentFramerateCap;
	CFTimeInterval cfStartTime = CFAbsoluteTimeGetCurrent();
	XSeconds lastFrameStartTime = 0;
	
	continueGameLoopThread = YES;
	while (continueGameLoopThread) {
		@synchronized(glView) {
			XSeconds frameStartTime = (XSeconds)(CFAbsoluteTimeGetCurrent() - cfStartTime);
			XSeconds deltaTime = frameStartTime - lastFrameStartTime;
			if (deltaTime > 1) deltaTime = gameTime.deltaTime; // prevent huge delay spikes from messing up game
			
			if (!pauseGame) {
				// set gameTime, smoothing out delta time spikes
				gameTime.totalTime = frameStartTime;
				gameTime.deltaTime = gameTime.deltaTime * 0.75f + deltaTime * 0.25f;
			} else {
				// when paused, don't update gameTime, but prevent gameTime.totalTime from spiking when unpaused
				cfStartTime += (CFTimeInterval)deltaTime;
				gameTime.deltaTime = 0;
			}

			// render frame
			{
				// allocate auto-release pool if not already
				if (pool == nil)
					pool = [[NSAutoreleasePool alloc] init];
				
				// render
				[glView renderFrame:gameTime];
				
				// clear auto-release pool after a certain number of frames
				++poolLifeCount;
				if (poolLifeCount >= 5) {
					poolLifeCount = 0;
					[pool release];
					pool = nil;
				}
			}
			
			XSeconds frameEndTime = (XSeconds)(CFAbsoluteTimeGetCurrent() - cfStartTime);
			lastFrameStartTime = frameStartTime;
			
			// limit frame rate
			XSeconds frameDuration = frameEndTime - frameStartTime;
			XSeconds minFrameDuration = 1.0f / currentFramerateCap;
			if (frameDuration < minFrameDuration) {
				NSTimeInterval interval = (minFrameDuration - frameDuration);
				[NSThread sleepForTimeInterval:interval];
			}
		}
	}
	
	[pool release];
}

@end

#import "AppDelegate.h"

#define kFramerateCap 100.0 //FPS


@interface AppDelegate (private)

-(void)renderFrame;

@end


@implementation AppDelegate

-(void)applicationDidFinishLaunching:(UIApplication*)application
{
	[application setStatusBarOrientation:UIInterfaceOrientationLandscapeRight animated:NO];
	[application setIdleTimerDisabled:YES];

	CGRect rect = [[UIScreen mainScreen] bounds];
	
	// create a full-screen window and initialize OpenGL
	window = [[UIWindow alloc] initWithFrame:rect];
	glView = [[GLView alloc] initWithFrame:rect];
	glView.multipleTouchEnabled = YES;
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
	
	gameTime.totalTime = 0; gameTime.deltaTime = 0;
	cfStartTime = CFAbsoluteTimeGetCurrent();
	lastFrameStartTime = 0;

	frameTimer = [NSTimer scheduledTimerWithTimeInterval:.005f target:self selector:@selector(renderFrame) userInfo:nil repeats:YES];
}

-(void)dealloc
{
	[frameTimer invalidate];
	frameTimer = nil;
	[super dealloc];
}

// application is about to become inactive
-(void)applicationWillResignActive:(UIApplication*)application
{
	NSLog(@"[applicationWillResignActive]");
	currentFramerateCap = 5;
	pauseGame = YES;
}

// application is active again
-(void)applicationDidBecomeActive:(UIApplication*)application
{
	NSLog(@"[applicationDidBecomeActive]");
	currentFramerateCap = kFramerateCap;
	pauseGame = NO;
}

// application is closing
-(void)applicationWillTerminate:(UIApplication*)application
{
	NSLog(@"[applicationWillTerminate]");
	[frameTimer invalidate];
	frameTimer = nil;
	[glView unloadContent];
	[glView release];
	glView = nil;
	[game release];
}

// low memory
-(void)applicationDidReceiveMemoryWarning:(UIApplication*)application
{
	NSLog(@"[applicationDidReceiveMemoryWarning]");
	[glView notifyLowMemory];
}

-(void)renderFrame
{
	XSeconds frameStartTime = (XSeconds)(CFAbsoluteTimeGetCurrent() - cfStartTime);
	XSeconds deltaTime = frameStartTime - lastFrameStartTime;
	
	if (!pauseGame) {
		// set gameTime, smoothing out delta time spikes
		gameTime.totalTime = frameStartTime;
		gameTime.deltaTime = gameTime.deltaTime * 0.75f + deltaTime * 0.25f;
	} else {
		// when paused, don't update gameTime, but prevent gameTime.totalTime from spiking when unpaused
		cfStartTime += (CFTimeInterval)deltaTime;
	}

	// render frame
	[glView renderFrame:gameTime];
	
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

@end

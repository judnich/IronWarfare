// Copyright © 2010 John Judnich. All rights reserved.

#import "XTime.h"


@implementation XTimer

@synthesize time, lastTime;

-(id)init
{
	if ((self = [super init])) {
		startTime = CFAbsoluteTimeGetCurrent();
	}
	return self;
}

-(void)captureTime
{
	CFTimeInterval seconds = CFAbsoluteTimeGetCurrent();
	
	// save in seconds
	lastTime = time;
	time.totalTime = (XSeconds)(seconds - startTime);
	time.deltaTime = time.totalTime - lastTime.totalTime;
}

@end

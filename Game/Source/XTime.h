// Copyright © 2010 John Judnich. All rights reserved.

#import <sys/time.h>
#import <mach/mach.h>
#import <mach/mach_time.h>


typedef float XSeconds;

typedef struct {
	XSeconds totalTime;
	XSeconds deltaTime;
} XGameTime;


@interface XTimer : NSObject {
	uint64_t startTime;
	mach_timebase_info_data_t info;
	XGameTime time, lastTime;
}

@property(readonly) XGameTime time, lastTime;

-(id)init;
-(void)captureTime;

@end

// Copyright © 2010 John Judnich. All rights reserved.

#import "XMediaGroup.h"
#import "XMath.h"


@implementation XMediaGroup

@synthesize _timer, _nowIniting;

-(id)init
{
	if ((self = [super init])) {
		resourceList = [[NSMutableDictionary alloc] init];
		_timer = [[XTimer alloc] init];
		_nowIniting = nil;
	}
	return self;
}

-(void)dealloc
{
	int unfreed = 0;
	for (XResource *resource in [resourceList objectEnumerator]) {
		if (resource->_refCount != 0)
			++unfreed;
	}
	if (unfreed > 0) {
		NSLog(@"-- XMediaGroup Warning --");
		NSLog(@"Possible memory leak / premature deallocation! XMediaGroup was released while it still contains %d unreleased resources:", unfreed);
		for (XResource *resource in [resourceList objectEnumerator]) {
			if (resource->_refCount != 0) {
				NSLog(@"XResource-%@; _refCount = %d; resourceKey = \"%@\";", [resource description], resource->_refCount, resource.resourceKey);
			}
		}
		NSLog(@"------------------------");
	}
	[self freeDeadResourcesNow];
	
	[resourceList removeAllObjects];
	[resourceList release];
	[_timer release];
	[super dealloc];
}

-(XResource*)retainResource:(Class)resourceType fromFile:(NSString*)filename;
{
	NSString *resourceKey = [[NSString alloc] initWithFormat:@"%@::%@", filename, NSStringFromClass(resourceType)];
	XResource *resource = [resourceList valueForKey:resourceKey];
	if (resource == nil) {
		// attempt to load the resource
		resource = [resourceType alloc];
		_nowIniting = resource; //XResource checks this when initializing to ensure the user doesn't manually init to a resource group
		XResource *tmp = [resource initWithFile:filename usingMedia:self];
		if (tmp == nil)
			[resource dealloc];
		resource = tmp;
		
		// if sucessfully loaded, add to the list of tracked resources
		if (resource) {
			[resourceList setObject:resource forKey:resourceKey];
			[resource release];
		}
	}
	_nowIniting = resource; //XResource checks this when retaining from _refCount == 0
	if (resource) {
		// if loaded, retain the resource (refCount should become 1)
		assert(resourceType == [resource class]);
		[resource mediaRetain];
	};
	_nowIniting = nil;
	[resourceKey release];
	return resource;
}

-(void)releaseResource:(XResource*)resource
{
	if (resource == nil) return;
	resource = [resourceList valueForKey:resource.resourceKey];
	if (resource != nil) {
		[resource mediaRelease];
	} else {
		NSLog(@"Error releasing resource: Cannot release a XResource from a XMediaGroup it is not a member of.");
#ifdef DEBUG
		[NSException raise:@"Error releasing resource!" format:@"Cannot release XResource from XMediaGroup it is not a member of."];
#endif
	}
}

-(void)freeDeadResourcesNow
{
	if (resourceList.count > 0) {
		BOOL freed;
		do {
			freed = NO;
			NSAutoreleasePool *autoreleasePool = [[NSAutoreleasePool alloc] init];
			NSArray *resourceList_tmp = [[resourceList objectEnumerator] allObjects];
			for (XResource *resource in resourceList_tmp) {
				if (resource->_refCount <= 0) {
					assert(resource.resourceKey);
					[resourceList removeObjectForKey:resource.resourceKey];
					freed = YES;
				}
			}
			[autoreleasePool release];
		} while (freed == YES);
		// repeats until no more deallocations are made
		// this is necessary because resources may free other resources, etc.
	}
}

-(void)freeDeadResourcesWithTimeout:(float)timeoutSeconds
{
	// iterate twice in case a resource frees a resource
	for (int i = 0; i < 2; ++i) {
		if (resourceList.count > 0) {
			NSAutoreleasePool *autoreleasePool = [[NSAutoreleasePool alloc] init];
			[_timer captureTime];
			float timeNow = _timer.time.totalTime;
			NSArray *resourceList_tmp = [[resourceList objectEnumerator] allObjects];
			for (XResource *resource in resourceList_tmp) {
				if (resource->_refCount <= 0) {
					assert(resource.resourceKey);
					float timeSinceZeroRef = xAbs(timeNow - resource->_lastZeroRefTime);
					if (timeSinceZeroRef >= timeoutSeconds) {
						[resourceList removeObjectForKey:resource.resourceKey];
					}
				}
			}
			[autoreleasePool release];
		}
	}
}

@end


@implementation XResource

@synthesize resourceKey, mediaGroup;

-(id)initWithFile:(NSString*)filename usingMedia:(XMediaGroup*)media
{
	if ((self = [super init])) {
		if (media._nowIniting != self) {
			NSLog(@"ERROR INITIALIZING RESOURCE! [XResource initWithFile:usingMedia:] is only to be called by XMediaGroup. Use [XResource mediaRetainFile:usingMedia:] instead.");
			return nil;
		}
		mediaGroup = media;
		assert(filename);
		resourceKey = [[NSString alloc] initWithFormat:@"%@::%@", filename, NSStringFromClass([self class])];
	}
	return self;
}

-(id)init
{
	NSLog(@"ERROR IN RESOURCE INIT METHOD! [super initWithFile:usingMedia:] must be called from XResource subclass init functions.");
	[NSException raise:@"ERROR IN RESOURCE INIT METHOD!" format:@"[super initWithFile:usingMedia:] must be called from XResource subclass init functions."];
	return nil;
}

-(void)dealloc
{
	[super dealloc];
	[resourceKey release];
}

+(id)mediaRetainFile:(NSString*)filename usingMedia:(XMediaGroup*)media
{
	return [media retainResource:[self class] fromFile:filename];
}

-(void)mediaRetain
{
#ifdef DEBUG
	if (mediaGroup._nowIniting != self && _refCount == 0) {
		NSLog(@"Warning: Unsafe to retain a resource with mediaRetain that has been fully released. Use mediaRetainFile instead.");
	}
#endif
	++_refCount;
/*#ifdef DEBUG
	if (_refCount == 1) {
		NSLog(@"XMediaGroup loaded: \"%@\"", resourceKey);
	}
#endif*/
	[self retain]; // to make sure this is retained by it's owner even if the XMediaPool is dealloc'ed.
}

-(void)mediaRelease
{
	if (_refCount > 0) {
		--_refCount;
		if (_refCount == 0) {
/*#ifdef DEBUG
			NSLog(@"XMediaGroup released: \"%@\"", resourceKey);
#endif*/
			[mediaGroup._timer captureTime];
			_lastZeroRefTime = mediaGroup._timer.time.totalTime;
		}
	} else {
		NSLog(@"Error releasing resource: Negative reference count.");
#ifdef DEBUG
		[NSException raise:@"Error releasing resource!" format:@"Negative reference count."];
#endif
	}
	[self release]; // see mediaRetain for explantion
}

@end


// Copyright © 2010 John Judnich. All rights reserved.

#import "XTime.h"
@class XResource;


// XMediaGroup automatically loads and unloads XResource-derived objects for you, with automated pooling where
// resources are prevented from being unloaded until they're no longer needed or desired.
//
// To use, simply call
//   ... = [myMediaGroup retainResource:[MyResourceClass class] fromFile:@"filename.ext"];
//   Instead of:
//   ... = [[MyResourceClass alloc] initWithFile:@"filename.ext"];
//
// Although if you choose, you may still use the second method - just be aware that only by using
// the media group will resources be automatically prevented from loading multiple times.
//
// When you are done with a resource, be sure to call releaseResource once for every time you called retainResource
//
// For example:
//   MyResourceClass *myResource = (MyResourceClass*)[myMediaGroup retainResource:[MyResourceClass class] fromFile:@"filename.ext"];
//   [myResource doStuff];
//   [myMediaGroup releaseResource:myResource]; //done with resource
//
// Rather than calling [myMediaGroup retainResource:] and [myMediaGroup releaseResource:] though, it is recommended
// to use the concise XResource interface to acheive the same thing (more efficient for the computer as well as you):
//   MyResourceClass *myResource = [MyResourceClass mediaRetainFile:@"filename.ext" usingMedia:myMediaGroup];
//   [myResource doStuff];
//   [myResource mediaRelease];
//
// Although it is not illegal to use the standard objective C "retain" and "release" methods, it is recommended
// to use the provided "mediaRetain" and "mediaRelease" methods instead when dealing with resource ownership. If you don't
// use these, the media group may internally release a resource (lose track of it) while it's still retained by "retain",
// which will result in the resource being forced to load again the next time retainResource is called, even if it's
// still loaded in the other part of your program which retain'ed it.
//
// Important: When a resource is released by all users of it, it is considered inactive and ready to be freed
// from memory; however it WILL NOT be freed until you call either freeDeadResourcesNow or freeDeadResourcesWithTimeout.
// freeDeadResourcesNow forces all unused resources to be deallocated. freeDeadResourcesWithTimeout does the
// same, but allows you to specify a "grace period" timeout delay where unused objects will be allowed to
// stay allocated for the given period of time before actually being deallocated by a freeDeadResourcesWithTimeout call.
//
// It is recommended that freeDeadResourcesWithTimeout be used with an appropriately long timeout (for example,
// ~30 seconds) if you want to call a freeDeadResources function on a regular basis. This way you
// prevent resources that are loaded and unloaded intermittently from being dealloced too often. When something
// like a new game level is loaded however, always call freeDeadResourcesNow first to flush the previous level
// from memory to ensure that enough memory is availible for the new level.
@interface XMediaGroup : NSObject {
	NSMutableDictionary *resourceList;
	XTimer *_timer;
	XResource *_nowIniting;
}

@property(readonly) XResource *_nowIniting;
@property(readonly) XTimer *_timer;

-(id)init;
-(void)dealloc;

-(XResource*)retainResource:(Class)resourceType fromFile:(NSString*)filename;
-(void)releaseResource:(XResource*)resource; //note that resources aren't actually unloaded until freeDeadResources___ is called

-(void)freeDeadResourcesNow;
-(void)freeDeadResourcesWithTimeout:(float)timeoutSeconds;

@end


@interface XResource : NSObject {
	XMediaGroup *mediaGroup;
	NSString *resourceKey;
@public
	signed int _refCount;
	float _lastZeroRefTime;
}

@property(readonly) NSString *resourceKey;
@property(readonly) XMediaGroup *mediaGroup;

-(id)initWithFile:(NSString*)filename usingMedia:(XMediaGroup*)media;
-(void)dealloc;

+(id)mediaRetainFile:(NSString*)filename usingMedia:(XMediaGroup*)media; //equivelent to calling [myMediaGroup:retainResource:]
-(void)mediaRetain; //equivelent to (and more efficient than) calling [myMediaGroup retainResource:] for the same resource again
-(void)mediaRelease; //equivelent to (and more efficient than) calling [myMediaGroup releaseResource:] for this resource

@end

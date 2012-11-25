// Copyright © 2010 John Judnich. All rights reserved.

#import "XMath.h"
@class XNode;
@class XCamera;


typedef struct {
	NSString *groupName;
	NSMutableSet *nodes;
} XRenderGroup;


// An XScene consists of an XCamera and a number of XNode instances. Simply set a
// camera, add XNode-derived objects, and call [myScene render]; every frame. Internally,
// the XScene class manages visibility, render order, fog, and other misc. OpenGL rendering
// behaviors for optimal render efficiency.
@interface XScene : NSObject {
	XRenderGroup *renderGroupArray;
	int renderGroupCount, renderGroupArraySize;
	XCamera *camera;
	XScalar fogRange;
}

@property(retain) XCamera *camera;
@property(assign) XScalar fogRange;

-(id)init;
-(void)dealloc;

-(void)setCamera:(XCamera*)cam;
-(XCamera*)camera;

-(void)render;

@end

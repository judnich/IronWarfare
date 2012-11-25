// Copyright © 2010 John Judnich. All rights reserved.

#import "XMath.h"
@class XScene;
@class XCamera;


@interface XNode : NSObject {
	XScene *scene;
	XNode *parent;
	NSMutableArray *children;
	
@public
	XVector3 position;
	XMatrix3 rotation;
	XBoundingBox boundingBox;
	BOOL useBoundingSphereOnly; //set to YES for many very small objects
	
@private
	XVector3 globalPosition;
	XMatrix3 globalRotation;
	BOOL globalTransformsOutdated;
	XScalar boundingRadius;
}

@property(assign) XNode *parent;
@property(assign) XScene *scene;
@property(readonly) XVector3 *globalPosition;
@property(readonly) XMatrix3 *globalRotation;
@property(readonly) XScalar boundingRadius;

-(id)init;
-(void)dealloc;

-(void)setParent:(XNode*)node;
-(XNode*)parent;

-(void)setScene:(XScene*)scn;
-(XScene*)scene;

-(XVector3*)globalPosition;
-(XMatrix3*)globalRotation;
-(XScalar)boundingRadius;

-(void)notifyTransformsChanged;
-(void)notifyBoundsChanged;
-(void)notifyRenderGroupChanged;

-(NSString*)getRenderGroupID; //render groups are rendered in alphabetical order
-(void)beginRenderGroup;
-(void)endRenderGroup;
-(void)render:(XCamera*)cam;

@end

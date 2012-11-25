// Copyright © 2010 John Judnich. All rights reserved.

#import "XNode.h"
#import "XScene.h"


@interface XScene (private)

-(void)addNode:(XNode*)entity;
-(void)removeNode:(XNode*)entity;

@end


@interface XNode (private)

-(void)registerChild:(XNode*)node;
-(void)unregisterChild:(XNode*)node;

-(void)updateGlobalTransforms;
-(void)updateBounds;

@end


@implementation XNode

@synthesize boundingRadius;

-(id)init
{
	if ((self = [super init])) {
		parent = nil;
		children = nil;
		rotation = xMatrix3_Identity;
		globalTransformsOutdated = YES;
		useBoundingSphereOnly = NO;
		[self notifyBoundsChanged];
	}
	return self;
}

-(void)dealloc
{
	if (children) {
		for (XNode *node in children)
			node->parent = nil;
		[children release];
	}
	self.parent = nil;
	[super dealloc];
}

-(void)setScene:(XScene*)scn
{
	if (scn != scene) {
		[scene removeNode:self];
		scene = scn;
		[scene addNode:self];
	}
}

-(XScene*)scene
{
	return scene;
}

-(void)setParent:(XNode*)node
{
	if (node != parent) {
		[parent unregisterChild:self];
		parent = node;
		[parent registerChild:self];
	}
}

-(XNode*)parent
{
	return parent;
}

-(void)registerChild:(XNode*)node
{
	if (children == nil)
		children = [[NSMutableArray alloc] initWithCapacity:1];
	[children addObject:node];
}

-(void)unregisterChild:(XNode*)node
{
	if (children != nil) {
		[children removeObject:node];
		if ([children count] == 0) {
			[children release];
			children = nil;
		}
	}
}

-(void)notifyTransformsChanged
{
	globalTransformsOutdated = YES;
	if (children) {
		for (XNode *node in children)
			[node notifyTransformsChanged];
	}
}

-(void)notifyBoundsChanged
{
	[self updateBounds];
}

-(void)notifyRenderGroupChanged
{
	if (scene) {
		[scene removeNode:self];
		[scene addNode:self];
	}
}

-(XVector3*)globalPosition
{
	if (globalTransformsOutdated) {
		[self updateGlobalTransforms];
		globalTransformsOutdated = NO;
	}
	return &globalPosition;
}

-(XMatrix3*)globalRotation
{
	if (globalTransformsOutdated) {
		[self updateGlobalTransforms];
		globalTransformsOutdated = NO;
	}
	return &globalRotation;
}

-(XScalar)boundingRadius
{
	return boundingRadius;
}

-(void)updateGlobalTransforms
{
	if (parent) {
		globalRotation = *[parent globalRotation];
		globalRotation = xMul_Mat3Mat3(&globalRotation, &rotation);
		globalPosition = *[parent globalPosition];
		XVector3 pos = xMul_Vec3Mat3(&position, [parent globalRotation]);
		xAdd_Vec3Vec3(&globalPosition, &pos);
	} else {
		globalPosition = position;
		globalRotation = rotation;
	}
}

-(void)updateBounds
{
	XScalar radius1Sq = boundingBox.min.x*boundingBox.min.x + boundingBox.min.y*boundingBox.min.y + boundingBox.min.z*boundingBox.min.z;
	XScalar radius2Sq = boundingBox.max.x*boundingBox.max.x + boundingBox.max.y*boundingBox.max.y + boundingBox.max.z*boundingBox.max.z;
	if (radius1Sq > radius2Sq)
		boundingRadius = xSqrt(radius1Sq);
	else
		boundingRadius = xSqrt(radius2Sq);
}

-(NSString*)getRenderGroupID
{
	return @"_default_";
}

-(void)beginRenderGroup
{
}

-(void)endRenderGroup
{
}

-(void)render:(XCamera*)cam
{
}


@end

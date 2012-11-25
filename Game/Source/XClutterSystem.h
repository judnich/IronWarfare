// Copyright © 2010 John Judnich. All rights reserved.

#import "XNode.h"
#import "XTime.h"
#import "XMath.h"
#import "XGL.h"
@class XTexture;
@class XCamera;
@class XTerrain;
@class XScriptNode;


typedef struct {
	int typeID;
	float density;
	XScalar yOffset;
	XScalar minSize, maxSize;
	XScalar minViewRange, maxViewRange;
	float minLightness, maxLightness;
} XClutterType;

typedef struct {
	XClutterType *type;
	XVector3 position;
	XScalar size, viewRange;
	float lightness;
	float waveFreq, wavePhase, waveMag;
	bool inSync, visible;
} XClutterInstance;


typedef struct {
	XVector3 position;
	float u, v;
	XColorBytes color;
} XClutterVertex;

typedef GLushort XClutterIndex;


@class XClutterSystem;

@interface XClutterBatch : XNode
{
	XClutterSystem *system;
	XClutterInstance *instanceArray;
	XTexture *atlasTexture;
	int instanceCount;
	GLuint glIndexBuffer;
	size_t indexCount;
	GLuint glVertexBuffer;
	size_t vertexCount;
	XClutterVertex *clutterVertexBuffer;
}

@property(retain) XTexture *atlasTexture;
@property(readonly) GLuint glVertexBuffer;
@property(readonly) size_t vertexCount;
@property(readonly) int instanceCount;

-(id)initWithSize:(int)instanceCount clutterInstances:(XClutterInstance*)instances clutterSystem:(XClutterSystem*)csys;
-(void)dealloc;

@end


@interface XClutterSystem : NSObject {
	XTerrain *terrain;
	XClutterBatch *batch;
	XClutterInstance *instanceArray;
	int instanceCount;
	float totalDensity;
	float minHeight, maxHeight;
@public
	XClutterType clutterTypes[4];
}

@property(assign) XScene *scene;
@property(retain) XTerrain *terrain;
@property(retain) XTexture *atlasTexture;

-(id)initWithSize:(int)instanceCount;
-(void)dealloc;

-(void)loadClutterTypesFromScript:(XScriptNode*)node;
-(void)regenClutterTypes; // call after clutterTypes[] has been manually configured / modified

@end

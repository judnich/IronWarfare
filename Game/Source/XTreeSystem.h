// Copyright © 2010 John Judnich. All rights reserved.

#import "XMath.h"
#import "XNode.h"
@class XTexture;
@class XTerrain;
@class XCamera;
//@class XTreeBatch;

#define TREE_BATCH_GRID_SIZE 4 //MUST be power-of-2 value
#define MAX_TREES_PER_BATCH 100


typedef struct {
	XVector2 position;
	XScalar size;
	XAngle rotation;
} XTreeInstance;

typedef struct {
	unsigned int glVertexBuffer;
	int treeCount;
} XTreeBatch;


void TreeSystem_populateTreeArrayProcedurally(XTreeInstance *array, int treeCount, float minTreeSize, float maxTreeSize, XScalarRect area);


@interface XTreeSystem : XNode {
	XTexture *texture;
	XTerrain *terrain;
	XCamera *camera;

	int batchGridRes;
	XTreeBatch batchVertexBufferGrid[TREE_BATCH_GRID_SIZE][TREE_BATCH_GRID_SIZE];
	XVector3 batchSize;
	
	size_t sharedIndexCount, sharedTexcoordCount;
	unsigned int sharedGLIndexBuffer, sharedGLTexcoordBuffer;
	
	XTreeInstance *treeArray;
	int treeCount;
}

@property(retain) XTexture *texture;
@property(retain) XTerrain *terrain;

-(id)init;
-(void)dealloc;

-(void)setTreesArrayPointer:(XTreeInstance*)trees treeCount:(int)count;
-(void)updateTreesRegion:(XIntRect)region;

// private
-(void)updateTreeBatchX:(int)x Y:(int)y;
-(XBoundingBox)boundsOfBatchRegion:(XIntRect)region;
-(void)renderRegion:(XIntRect)region;


@end

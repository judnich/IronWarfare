// Copyright © 2010 John Judnich. All rights reserved.

#import "XTreeSystem.h"
#import "XTexture.h"
#import "XTerrain.h"
#import "XCamera.h"


typedef struct {
	XVector3 position;
	XColorBytes color;
} XTreeVertex;

typedef struct {
	GLbyte u, v;
} XTreeTexcoord;

typedef GLushort XTreeIndex;


@implementation XTreeSystem

@synthesize terrain;

-(id)init
{
	if ((self = [super init])) {
		for (int i = 0; i < TREE_BATCH_GRID_SIZE; ++i) {
			for (int j = 0; j < TREE_BATCH_GRID_SIZE; ++j) {
				batchVertexBufferGrid[i][j].glVertexBuffer = 0;
				batchVertexBufferGrid[i][j].treeCount = 0;
			}
		}

		sharedIndexCount = MAX_TREES_PER_BATCH * 6 * 2;
		{
			XTreeIndex *indexData = malloc(sizeof(XTreeIndex)*sharedIndexCount);
			XTreeIndex *ptr = indexData;
			for (size_t i = 0; i < MAX_TREES_PER_BATCH * 2; ++i) {
				size_t o = i * 4;
				*ptr++ = 0+o; *ptr++ = 1+o; *ptr++ = 2+o;
				*ptr++ = 1+o; *ptr++ = 2+o; *ptr++ = 3+o;
			}
			glGenBuffers(1, &sharedGLIndexBuffer);
			glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, sharedGLIndexBuffer);
			glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(XTreeIndex)*sharedIndexCount, indexData, GL_STATIC_DRAW);
			glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
			free(indexData);
		}
		
		sharedTexcoordCount = MAX_TREES_PER_BATCH * 4 * 2;
		{
			XTreeTexcoord *texcoordData = malloc(sizeof(XTreeTexcoord)*sharedTexcoordCount);
			XTreeTexcoord t00; t00.u = 0; t00.v = 0;
			XTreeTexcoord t10; t10.u = 1; t10.v = 0;
			XTreeTexcoord t01; t01.u = 0; t01.v = 1;
			XTreeTexcoord t11; t11.u = 1; t11.v = 1;
			XTreeTexcoord *ptr = texcoordData;
			for (size_t i = 0; i < MAX_TREES_PER_BATCH * 2; ++i) {
				*ptr++ = t00; *ptr++ = t10;
				*ptr++ = t01; *ptr++ = t11;
			}
			glGenBuffers(1, &sharedGLTexcoordBuffer);
			glBindBuffer(GL_ARRAY_BUFFER, sharedGLTexcoordBuffer);
			glBufferData(GL_ARRAY_BUFFER, sizeof(XTreeTexcoord)*sharedTexcoordCount, texcoordData, GL_STATIC_DRAW);
			glBindBuffer(GL_ARRAY_BUFFER, 0);
			free(texcoordData);
		}
	}
	return self;
}

-(void)dealloc
{
	glDeleteBuffers(1, &sharedGLIndexBuffer);
	glDeleteBuffers(1, &sharedGLTexcoordBuffer);
	for (int i = 0; i < TREE_BATCH_GRID_SIZE; ++i) {
		for (int j = 0; j < TREE_BATCH_GRID_SIZE; ++j) {
			XTreeBatch *batch = &batchVertexBufferGrid[i][j];
			if (batch->glVertexBuffer)
				glDeleteBuffers(1, &batch->glVertexBuffer);
		}
	}
	[texture mediaRelease];
	[super dealloc];
}

-(void)setTexture:(XTexture*)tex
{
	[terrain release];
	[texture mediaRelease];
	texture = tex;
	[texture mediaRetain];
}

-(XTexture*)texture
{
	return texture;
}

-(void)setTreesArrayPointer:(XTreeInstance*)trees treeCount:(int)count
{
	treeArray = trees;
	treeCount = count;
}

-(void)updateTreesRegion:(XIntRect)region
{
	if (region.left < 0) region.left = 0;
	else if (region.left > TREE_BATCH_GRID_SIZE-1) region.left = TREE_BATCH_GRID_SIZE-1;
	if (region.right < 0) region.right = 0;
	else if (region.right > TREE_BATCH_GRID_SIZE-1) region.right = TREE_BATCH_GRID_SIZE-1;
	if (region.top < 0) region.top = 0;
	else if (region.top > TREE_BATCH_GRID_SIZE-1) region.top = TREE_BATCH_GRID_SIZE-1;
	if (region.bottom < 0) region.bottom = 0;
	else if (region.bottom > TREE_BATCH_GRID_SIZE-1) region.bottom = TREE_BATCH_GRID_SIZE-1;
	
	XScalar invGridSize = 1.0 / TREE_BATCH_GRID_SIZE;
	batchSize.x = (boundingBox.max.x - boundingBox.min.x) * invGridSize;
	batchSize.y = (boundingBox.max.y - boundingBox.min.y);
	batchSize.z = (boundingBox.max.z - boundingBox.min.z) * invGridSize;
	
	for (int y = region.top; y <= region.bottom; ++y) {
		for (int x = region.left; x <= region.right; ++x) {
			[self updateTreeBatchX:x Y:y];
		}
	}
}

-(void)updateTreeBatchX:(int)x Y:(int)y
{
	XIntRect region;
	region.left = x; region.right = x;
	region.top = y; region.bottom = y;
	XBoundingBox bounds = [self boundsOfBatchRegion:region];

	XTreeBatch *batch = &batchVertexBufferGrid[x][y];
	
	GLuint vBuff = batch->glVertexBuffer;
	if (vBuff) {
		glDeleteBuffers(1, &vBuff);
		vBuff = 0;
	}
	
	XTreeInstance localTreeArray[MAX_TREES_PER_BATCH];
	int localTreeCount = 0;
	
	for (int i = 0; i < treeCount; ++i) {
		XTreeInstance *tree = &treeArray[i];
		if (tree->position.x >= bounds.min.x && tree->position.x <= bounds.max.x
			&& tree->position.y >= bounds.min.z && tree->position.y <= bounds.max.z)
		{
			if (localTreeCount >= MAX_TREES_PER_BATCH)
				break;
			localTreeArray[localTreeCount] = *tree;
			++localTreeCount;
		}
	}
	
	if (localTreeCount) {
		int vertexCount = localTreeCount * 8;
		XTreeVertex *vData = malloc(sizeof(XTreeVertex) * vertexCount);
		XTreeVertex *vPtr = vData;
		for (int i = 0; i < localTreeCount; ++i) {
			XTreeInstance *tree = &localTreeArray[i];
			
			XVector3 pos;
			pos.x = tree->position.x;
			pos.z = tree->position.y;
			pos.y = 0;
			XTerrainIntersection intersection = [terrain intersectTerrainVerticallyAt:&pos];
			pos.y = intersection.point.y;
			
			XColorBytes color; color.alpha = 0xFF;
			float shade = xSaturate([terrain sampleTerrainLightmapAt:&pos] * 3);
			color.red = color.green = color.blue = (unsigned char)((float)0xFF * shade);
			
			//XScalar cos = xCos(tree->rotation) * tree->size * 0.5f;
			//XScalar sin = xSin(tree->rotation) * tree->size * 0.5f;
			
			vPtr->position.x = pos.x + -tree->size*0.5;
			vPtr->position.y = pos.y + tree->size;
			vPtr->position.z = pos.z + 0;
			vPtr->color = color;
			++vPtr;
			
			vPtr->position.x = pos.x + tree->size*0.5;
			vPtr->position.y = pos.y + tree->size;
			vPtr->position.z = pos.z + 0;
			vPtr->color = color;
			++vPtr;
			
			vPtr->position.x = pos.x + -tree->size*0.5;
			vPtr->position.y = pos.y + 0;
			vPtr->position.z = pos.z + 0;
			vPtr->color = color;
			++vPtr;
			
			vPtr->position.x = pos.x + tree->size*0.5;
			vPtr->position.y = pos.y + 0;
			vPtr->position.z = pos.z + 0;
			vPtr->color = color;
			++vPtr;
			
			
			//cos = xCos(tree->rotation + xDegToRad(90)) * tree->size * 0.5f;
			//sin = xSin(tree->rotation + xDegToRad(90)) * tree->size * 0.5f;

			vPtr->position.x = pos.x + 0;
			vPtr->position.y = pos.y + tree->size;
			vPtr->position.z = pos.z + -tree->size*0.5;
			vPtr->color = color;
			++vPtr;
			
			vPtr->position.x = pos.x + 0;
			vPtr->position.y = pos.y + tree->size;
			vPtr->position.z = pos.z + tree->size*0.5;
			vPtr->color = color;
			++vPtr;
			
			vPtr->position.x = pos.x + 0;
			vPtr->position.y = pos.y + 0;
			vPtr->position.z = pos.z + -tree->size*0.5;
			vPtr->color = color;
			++vPtr;
			
			vPtr->position.x = pos.x + 0;
			vPtr->position.y = pos.y + 0;
			vPtr->position.z = pos.z + tree->size*0.5;
			vPtr->color = color;
			++vPtr;
		}
		
		glGenBuffers(1, &vBuff);
		glBindBuffer(GL_ARRAY_BUFFER, vBuff);
		glBufferData(GL_ARRAY_BUFFER, sizeof(XTreeVertex) * vertexCount, vData, GL_STATIC_DRAW);
		glBindBuffer(GL_ARRAY_BUFFER, 0);
	}
	
	batch->glVertexBuffer = vBuff;
	batch->treeCount = localTreeCount;	
}

-(XBoundingBox)boundsOfBatchRegion:(XIntRect)region
{
	XBoundingBox regionAABB;
	regionAABB.min.x = boundingBox.min.x + batchSize.x * (region.left);
	regionAABB.min.y = boundingBox.min.y + batchSize.y * 0;
	regionAABB.min.z = boundingBox.min.z + batchSize.z * (region.top);
	regionAABB.max.x = boundingBox.min.x + batchSize.x * (region.right+1);
	regionAABB.max.y = boundingBox.min.y + batchSize.y * 1;
	regionAABB.max.z = boundingBox.min.z + batchSize.z * (region.bottom+1);
	return regionAABB;
}

-(NSString*)getRenderGroupID
{
	return @"2.5_trees";
}

-(void)beginRenderGroup
{
	glDisable(GL_LIGHTING);
	glDisableClientState(GL_NORMAL_ARRAY);
	glDisable(GL_CULL_FACE);
	
	if (texture) {
		glActiveTexture(GL_TEXTURE0);
		glBindTexture(GL_TEXTURE_2D, texture.glTexture);
		glEnable(GL_TEXTURE_2D);

		glAlphaFunc(GL_GREATER, 0.75f);
		glEnable(GL_ALPHA_TEST);
		glDisable(GL_BLEND);
	}
}

-(void)endRenderGroup
{
	glEnable(GL_CULL_FACE);
	glDisable(GL_ALPHA_TEST);
	glEnable(GL_LIGHTING);
	glDisableClientState(GL_VERTEX_ARRAY);
	glDisableClientState(GL_COLOR_ARRAY);
    glDisableClientState(GL_TEXTURE_COORD_ARRAY);
	glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
	glBindBuffer(GL_ARRAY_BUFFER, 0);
	if (texture) {
		glActiveTexture(GL_TEXTURE0);
		glBindTexture(GL_TEXTURE_2D, 0);
	}
	xglNotifyTextureBindingsChanged();
	xglNotifyMeshBindingsChanged();
}

-(void)render:(XCamera*)cam
{
	camera = cam;
	
	XScalar invGridSize = 1.0 / TREE_BATCH_GRID_SIZE;
	batchSize.x = (boundingBox.max.x - boundingBox.min.x) * invGridSize;
	batchSize.y = (boundingBox.max.y - boundingBox.min.y);
	batchSize.z = (boundingBox.max.z - boundingBox.min.z) * invGridSize;
	
	XIntRect region;
	region.left = 0;
	region.right = TREE_BATCH_GRID_SIZE-1;
	region.top = 0;
	region.bottom = TREE_BATCH_GRID_SIZE-1;
	
	[self renderRegion:region];
}

-(void)renderRegion:(XIntRect)region
{
	// calculate local bounds
	XBoundingBox regionAABB = [self boundsOfBatchRegion:region];
	
	// translate bounds to global for visibility check
	// (rotation is ignored for performance, and there's no need for it in most cases)
	XVector3 *pos = [self globalPosition];
	xAdd_Vec3Vec3(&regionAABB.min, pos);
	xAdd_Vec3Vec3(&regionAABB.max, pos);
	
	// check if bounds are outside of viewing frustum, if so, return
	BOOL visible = [camera isVisibleBox:&regionAABB];
	if (visible) {
		// partial visibility - recurse and check sub-region visibilities
		if (region.left == region.right) {
			// cannot subdivide visibility checks any further, so render the batch
			assert(region.top == region.bottom);
			XTreeBatch *batch = &batchVertexBufferGrid[region.left][region.top];
			if (batch->glVertexBuffer) {
				glBindBuffer(GL_ARRAY_BUFFER, batch->glVertexBuffer);
				glEnableClientState(GL_VERTEX_ARRAY);
				glVertexPointer(3, GL_FLOAT, sizeof(XTreeVertex), (void*)offsetof(XTreeVertex,position));
				glEnableClientState(GL_COLOR_ARRAY);
				glColorPointer(4, GL_UNSIGNED_BYTE, sizeof(XTreeVertex), (void*)offsetof(XTreeVertex,color));
				
				glBindBuffer(GL_ARRAY_BUFFER, sharedGLTexcoordBuffer);
				glEnableClientState(GL_TEXTURE_COORD_ARRAY);
				glTexCoordPointer(2, GL_BYTE, sizeof(XTreeTexcoord), 0);
				
				glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, sharedGLIndexBuffer);
				
				glDrawElements(GL_TRIANGLES, batch->treeCount * 12, GL_UNSIGNED_SHORT, (void*)0);
			}
		}
		else {
			// subdivide region into 4 quads
			XIntRect subRegion[4];
			int subWidth = (((region.right - region.left) + 1) / 2);
			int subHeight = (((region.bottom - region.top) + 1) / 2);
			
			subRegion[0].left = region.left;
			subRegion[0].top = region.top;
			subRegion[0].right = subRegion[0].left + subWidth - 1;
			subRegion[0].bottom = subRegion[0].top + subHeight - 1;
			
			subRegion[1].left = region.left + subWidth;
			subRegion[1].top = region.top;
			subRegion[1].right = subRegion[1].left + subWidth - 1;
			subRegion[1].bottom = subRegion[1].top + subHeight - 1;
			
			subRegion[2].left = region.left;
			subRegion[2].top = region.top + subHeight;
			subRegion[2].right = subRegion[2].left + subWidth - 1;
			subRegion[2].bottom = subRegion[2].top + subHeight - 1;
			
			subRegion[3].left = region.left + subWidth;
			subRegion[3].top = region.top + subHeight;
			subRegion[3].right = subRegion[3].left + subWidth - 1;
			subRegion[3].bottom = subRegion[3].top + subHeight - 1;
			
			// sort quads from closest to farthest from camera
			XIntRect *sortedSubRegions[4];
			for (int i = 0; i < 4; ++i)
				sortedSubRegions[i] = &subRegion[i];
			int cameraX = TREE_BATCH_GRID_SIZE * (camera->origin.x - boundingBox.min.x) / (boundingBox.max.x - boundingBox.min.x);
			int cameraZ = TREE_BATCH_GRID_SIZE * (camera->origin.z - boundingBox.min.z) / (boundingBox.max.z - boundingBox.min.z);
			BOOL sorted = NO;
			while (!sorted) {
				sorted = YES;
				for (int i = 0; i < 3; ++i) {
					XIntRect *a = sortedSubRegions[i];
					XIntRect *b = sortedSubRegions[i+1];
					int aDistX = ((a->left + a->right) / 2) - cameraX;
					int aDistZ = ((a->top + a->bottom) / 2) - cameraZ;
					int aDist = aDistX*aDistX + aDistZ*aDistZ;
					int bDistX = ((b->left + b->right) / 2) - cameraX;
					int bDistZ = ((b->top + b->bottom) / 2) - cameraZ;
					int bDist = bDistX*bDistX + bDistZ*bDistZ;
					if (bDist < aDist) {
						sortedSubRegions[i] = b;
						sortedSubRegions[i+1] = a;
						sorted = NO;
					}
				}
			}
			
			// and render
			for (int i = 0; i < 4; ++i) {
				[self renderRegion:(*sortedSubRegions[i])];
			}
		}
	}
}


@end


void TreeSystem_populateTreeArrayProcedurally(XTreeInstance *array, int treeCount, float minTreeSize, float maxTreeSize, XScalarRect area)
{
	XScalar clusterSpacing = (area.right - area.left) * 0.025f;
	
	for (int i = 0; i < treeCount; ++i) {
		XTreeInstance *instance = &array[i];

		// misc. initialization
		instance->size = xRangeRand(minTreeSize, maxTreeSize);
		instance->rotation = xRangeRand(xDegToRad(-180), xDegToRad(180));
		
		// random clustered position within the bounds
		BOOL cluster = NO;
		if (xRand() < 0.4f)
			cluster = YES;
		if (cluster) {
			XTreeInstance *clusterPoint = nil;
			if (i > 0)
				clusterPoint = &array[i-1];
			if (!clusterPoint)
				cluster = NO;
			else {
				int safetyCount = 0;
				BOOL inBounds = YES;
				do {
					instance->position.x = clusterPoint->position.x + xRangeRand(-clusterSpacing, clusterSpacing);
					instance->position.y = clusterPoint->position.y + xRangeRand(-clusterSpacing, clusterSpacing);
					if (instance->position.x < area.left || instance->position.x > area.right || instance->position.y < area.top || instance->position.y > area.bottom)
						inBounds = NO;
					if (++safetyCount > 200) break;
				} while (inBounds);
			}
		}
		if (!cluster) {
			instance->position.x = xRangeRand(area.left, area.right);
			instance->position.y = xRangeRand(area.top, area.bottom);
		}
	}	
}



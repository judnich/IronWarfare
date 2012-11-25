// Copyright © 2010 John Judnich. All rights reserved.

#import "XNode.h"
#import "XGL.h"
@class XTerrainChunk;
@class XTexture;
@class XMediaGroup;

#define TERRAIN_CHUNK_GRID_SIZE 8 //MUST be power-of-2 value
#define TERRAIN_DETAIL_MAP_REPEATS_PER_CHUNK 8 //MUST be power-of-2 value

typedef struct
{
	unsigned int glBuffer;
	unsigned int count;
} _TerrainIndexBuffer;


typedef struct
{
	XVector3 point;
	XVector3 normal;
} XTerrainIntersection;


@interface XTerrain : XNode {
	XCamera *camera;
	int terrainRes, chunkTileRes;
	XTerrainChunk *chunkGrid[TERRAIN_CHUNK_GRID_SIZE][TERRAIN_CHUNK_GRID_SIZE];
	float *heightData;
	XVector3 chunkSize;
	_TerrainIndexBuffer indexBuffers[16];
	unsigned char *shadowMap;
	int shadowMapRes;
@public
	int indexBufferCount;
	XScalar lodRange, skirtHeight;
	XTexture *textureMap, *detailMap;
	XMaterial material;
}

@property(readonly) int terrainRes;
@property(readonly) int chunkTileRes;
@property(assign) XScalar lodRange;
@property(readonly) XScalar skirtHeight;

-(id)initWithHeightmap:(NSString*)heightmapFile skirtSize:(float)skirtSize;
-(id)initWithSize:(int)terrainResolution skirtSize:(float)skirtSize;
-(void)dealloc;

-(void)loadHeightDataFromImage:(CGImageRef)heightmapImage;

-(void)setTextureMap:(NSString*)file usingMedia:(XMediaGroup*)media;
-(void)setDetailMap:(NSString*)file usingMedia:(XMediaGroup*)media;

-(XTerrainIntersection)intersectTerrainVerticallyAt:(XVector3*)pos;
-(float)sampleTerrainLightmapAt:(XVector3*)pos;

@end


@interface XTerrainChunk : NSObject {
	XTerrain *terrain;
	unsigned int vertexBuffer;
}

-(id)initWithTerrain:(XTerrain*)owner;
-(void)dealloc;

-(void)loadHeightMesh:(float*)heightArray arrayWidth:(int)arrayWidth heightRegion:(XIntRect)region;
-(void)unloadHeightMesh;

-(void)render:(int)lod;

@end


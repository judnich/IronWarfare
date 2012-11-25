// Copyright © 2010 John Judnich. All rights reserved.

#import "XTerrain.h"
#import "XNode.h"
#import "XCamera.h"
#import "XTexture.h"
#import "XTextureNomip.h"
#import "XGL.h"


@interface XTerrain (private)

-(void)renderRegion:(XIntRect)region;

-(void)buildIndexBuffers;
-(void)destroyIndexBuffers;
-(_TerrainIndexBuffer)getIndexBufferForLOD:(int)lod;

@end


@implementation XTerrain

@synthesize terrainRes, chunkTileRes, lodRange, skirtHeight;

-(id)initWithHeightmap:(NSString*)heightmapFile skirtSize:(float)skirtSize
{
	NSAutoreleasePool *autoreleasePool = [[NSAutoreleasePool alloc] init];
	
	NSString *directory = [heightmapFile stringByDeletingLastPathComponent];
	NSString *fileN = [heightmapFile lastPathComponent];
	NSString *sourcePath = [[NSBundle mainBundle] pathForResource:fileN ofType:nil inDirectory:directory];
	
	UIImage *img = [[UIImage alloc] initWithContentsOfFile:sourcePath];
	CGImageRef heightmapImage = img.CGImage;
	if (!heightmapImage) {
		NSLog(@"Error initializing terrain: Could not load heightmap image file.");
		[img release];
		[autoreleasePool release];
		return nil;
	}
	size_t imageW = CGImageGetWidth(heightmapImage);
	size_t imageH = CGImageGetHeight(heightmapImage);
	if (imageW != imageH) {
		NSLog(@"Error initializing terrain: Terrain heightmap must be square");
		[img release];
		[autoreleasePool release];
		return nil;
	}
	if ((self = [self initWithSize:imageW skirtSize:skirtSize])) {
		[self loadHeightDataFromImage:heightmapImage];
	}
	[img release];
	[autoreleasePool release];
	return self;
}

-(id)initWithSize:(int)terrainResolution skirtSize:(float)skirtSize
{
	if ((self = [super init])) {
		int pow2Res = powf(2, log10f(terrainResolution) / log10f(2.0));
		if (terrainResolution != pow2Res+1) {
			NSLog(@"Error initializing terrain: Terrain resolution must be a power-of-two-plus-one value");
			return nil;
		}
		terrainRes = terrainResolution;
		chunkTileRes = ((terrainResolution-1) / TERRAIN_CHUNK_GRID_SIZE);
		
		material = xglGetDefaultMaterial();
		
		[self buildIndexBuffers];
		lodRange = 750.0;
		
		boundingBox.min.x = -500; boundingBox.min.y = 0; boundingBox.min.z = -500;
		boundingBox.max.x = 500; boundingBox.max.y = 50; boundingBox.max.z = 500;
		[self notifyBoundsChanged];
		
		// calculate terrain-relative skirt height
		XScalar width = boundingBox.max.x - boundingBox.min.x;
		XScalar height = boundingBox.max.y - boundingBox.min.y;
		XScalar depth = boundingBox.max.z - boundingBox.max.z;
		XScalar size;
		if (width > depth) size = width; else size = depth;
		XScalar tileSize = (size / height) / terrainResolution;
		skirtHeight = tileSize * skirtSize;
		
		for (int y = 0; y < TERRAIN_CHUNK_GRID_SIZE; ++y) {
			for (int x = 0; x < TERRAIN_CHUNK_GRID_SIZE; ++x) {
				chunkGrid[x][y] = [[XTerrainChunk alloc] initWithTerrain:self];
			}
		}
	}
	return self;
}

-(void)dealloc
{
	if (heightData)
		free(heightData);
	if (shadowMap)
		free(shadowMap);
	for (int y = 0; y < TERRAIN_CHUNK_GRID_SIZE; ++y) {
		for (int x = 0; x < TERRAIN_CHUNK_GRID_SIZE; ++x) {
			[chunkGrid[x][y] release];
		}
	}
	[self destroyIndexBuffers];
	[textureMap mediaRelease];
	[detailMap mediaRelease];
	[super dealloc];
}

-(void)loadHeightDataFromImage:(CGImageRef)heightmapImage
{
	// load height data
	if (heightData)
		free(heightData);
	heightData = (float*)malloc(terrainRes * terrainRes * sizeof(float));
	
	if (heightmapImage) {
		size_t imageW = CGImageGetWidth(heightmapImage);
		size_t imageH = CGImageGetHeight(heightmapImage);
		assert(imageW == terrainRes && imageH == terrainRes);
		
		GLubyte *textureData = (GLubyte*)malloc(imageW * imageH * sizeof(GLubyte));
		CGContextRef imageContext = CGBitmapContextCreate(textureData, imageW, imageH, 8, imageW * sizeof(char), CGColorSpaceCreateDeviceGray(), kCGImageAlphaNone);	
		
		if (imageContext != NULL) {
			CGContextDrawImage(imageContext, CGRectMake(0.0, 0.0, (CGFloat)imageW, (CGFloat)imageH), heightmapImage);
			CGContextRelease(imageContext);
			for (int y = 0; y < imageH; ++y) {
				for (int x = 0; x < imageW; ++x) {
					float val = ((float)textureData[y*imageW+x] / 255.0f);
					heightData[y*terrainRes + x] = val;
				}
			}
		} else {
			[NSException raise:@"Error loading image" format:@"Could not load heightmap image"];
		}
		free(textureData);
	} else {
		[NSException raise:@"File not found" format:@"Could not find heightmap image file"];
	}
	
	// load into chunk meshes
	for (int y = 0; y < TERRAIN_CHUNK_GRID_SIZE; ++y) {
		for (int x = 0; x < TERRAIN_CHUNK_GRID_SIZE; ++x) {
			XTerrainChunk *chunk = chunkGrid[x][y];
			XIntRect region;
			region.left = chunkTileRes * x;
			region.top = chunkTileRes * y;
			region.right = chunkTileRes * (x+1);
			region.bottom = chunkTileRes * (y+1);
			[chunk loadHeightMesh:heightData arrayWidth:terrainRes heightRegion:region];
		}
	}
}

-(XTerrainIntersection)intersectTerrainVerticallyAt:(XVector3*)pos
{
	// position within terrain bounds [0,1]
	XScalar bbWidth = (boundingBox.max.x - boundingBox.min.x);
	XScalar bbHeight = (boundingBox.max.y - boundingBox.min.y);
	XScalar bbDepth = (boundingBox.max.z - boundingBox.min.z);
	XScalar tx = (pos->x - boundingBox.min.x) / bbWidth;
	XScalar tz = (pos->z - boundingBox.min.z) / bbDepth;
	// if out of bounds
	if (tx >= 1.0f || tz >= 1.0f || tx < 0.0f || tz < 0.0f) {
		XTerrainIntersection intersection;
		intersection.point = *pos;
		intersection.normal.x = 0;
		intersection.normal.y = 1;
		intersection.normal.z = 0;
		return intersection;
	}
	// top-left vertex of terrain [0,terrainRes-1)
	XScalar tres1 = terrainRes-1;
	int px = tx * tres1;
	int pz = tz * tres1;
	if (px == (terrainRes-1)) --px;
	if (pz == (terrainRes-1)) --pz;
	// position within terrain bounds [0,1] of top-left vertex
	XScalar invTres1 = 1.0f / tres1;
	XScalar vtx = (XScalar)px * invTres1;
	XScalar vtz = (XScalar)pz * invTres1;
	// position within top-left and bottom-right [0-1]
	XScalar ox = (tx - vtx) * tres1;
	XScalar oz = (tz - vtz) * tres1;
	// position of top-left vertex [world]
	XScalar vposx = boundingBox.min.x + vtx * bbWidth;
	XScalar vposz = boundingBox.min.z + vtz * bbDepth;
	// size of a terrain tile [world]
	XScalar tilex = bbWidth * invTres1;
	XScalar tilez = bbDepth * invTres1;
	// determine which triangle the point is on
	XVector3 v0, v1, v2;
	XVector3 edge1, edge2;
	if (ox > oz) {
		//quad's right half triangle
		v0.x = vposx;
		v0.z = vposz;
		v0.y = heightData[(px) + (pz)*terrainRes] * bbHeight + boundingBox.min.y;
		v2.x = vposx + tilex;
		v2.z = vposz;
		v2.y = heightData[(px+1) + (pz)*terrainRes] * bbHeight + boundingBox.min.y;
		v1.x = vposx + tilex;
		v1.z = vposz + tilez;
		v1.y = heightData[(px+1) + (pz+1)*terrainRes] * bbHeight + boundingBox.min.y;
		edge1 = v0; xSub_Vec3Vec3(&edge1, &v1);
		edge2 = v0; xSub_Vec3Vec3(&edge2, &v2);
	} else {
		//quad's left half triangle
		v0.x = vposx;
		v0.z = vposz;
		v0.y = heightData[(px) + (pz)*terrainRes] * bbHeight + boundingBox.min.y;
		v1.x = vposx;
		v1.z = vposz + tilez;
		v1.y = heightData[(px) + (pz+1)*terrainRes] * bbHeight + boundingBox.min.y;
		v2.x = vposx + tilex;
		v2.z = vposz + tilez;
		v2.y = heightData[(px+1) + (pz+1)*terrainRes] * bbHeight + boundingBox.min.y;
		edge1 = v0; xSub_Vec3Vec3(&edge1, &v1);
		edge2 = v0; xSub_Vec3Vec3(&edge2, &v2);
	}
	// generate a plane for the triangle's surface
	XVector3 planeNormal = xCrossProduct_Vec3(&edge1, &edge2);
	xNormalize_Vec3(&planeNormal);
	xMul_Vec3Scalar(&planeNormal, -1);
	XScalar planeD = xDotProduct_Vec3(&planeNormal, &v0);
	xMul_Vec3Scalar(&planeNormal, -1);
	
	// get the height at the desired point on the "plane" / triangle
	//y = (Ax + Cz + D) / -B
	XTerrainIntersection intersection;
	intersection.point.y = (planeNormal.x * pos->x + planeNormal.z * pos->z + planeD) / -planeNormal.y;
	intersection.point.x = pos->x;
	intersection.point.z = pos->z;
	intersection.normal = planeNormal;

	return intersection;
}

-(float)sampleTerrainLightmapAt:(XVector3*)pos
{
	if (shadowMap == nil)
		return 1;
	// position within terrain bounds [0,1]
	XScalar bbWidth = (boundingBox.max.x - boundingBox.min.x);
	XScalar bbDepth = (boundingBox.max.z - boundingBox.min.z);
	XScalar u = (pos->x - boundingBox.min.x) / bbWidth;
	XScalar v = (pos->z - boundingBox.min.z) / bbDepth;
	// if out of bounds
	if (u >= 1.0f || v >= 1.0f || u < 0.0f || v < 0.0f)
		return 1;
	// bilinear filtering
	u *= shadowMapRes;
	v *= shadowMapRes;
	int x = xFloor(u);
	int y = xFloor(v);
	float u_ratio = u - x;
	float v_ratio = v - y;
	float u_opposite = 1 - u_ratio;
	float v_opposite = 1 - v_ratio;
	float result = (((float)shadowMap[y*shadowMapRes + x] * u_opposite + (float)shadowMap[y*shadowMapRes + x+1] * u_ratio) * v_opposite
				+ ((float)shadowMap[(y+1)*shadowMapRes + x] * u_opposite + (float)shadowMap[(y+1)*shadowMapRes + x+1] * u_ratio) * v_ratio) / (float)0xFF;
	return result;
}

-(void)setTextureMap:(NSString*)file usingMedia:(XMediaGroup*)media
{
	[textureMap mediaRelease];
	if (file != nil) {
		// load texture
		textureMap = [XTexture mediaRetainFile:file usingMedia:media];
		
		// load shadow map
		NSString *directory = [file stringByDeletingLastPathComponent];
		NSString *fileN = [file lastPathComponent];
		NSString *sourcePath = [[NSBundle mainBundle] pathForResource:fileN ofType:nil inDirectory:directory];
		UIImage *img = [[UIImage alloc] initWithContentsOfFile:sourcePath];
		CGImageRef shadowmapImage = img.CGImage;
		if (shadowmapImage) {
			size_t imageW = CGImageGetWidth(shadowmapImage);
			size_t imageH = CGImageGetHeight(shadowmapImage);
			assert(imageW == imageH);
			shadowMapRes = imageW;
			if (terrainRes < shadowMapRes)
				shadowMapRes = terrainRes;
			if (shadowMap)
				free(shadowMap);
			shadowMap = malloc(shadowMapRes * shadowMapRes * sizeof(unsigned char));
		
			CGContextRef imageContext = CGBitmapContextCreate(shadowMap, shadowMapRes, shadowMapRes, 8, shadowMapRes * sizeof(char), CGColorSpaceCreateDeviceGray(), kCGImageAlphaNone);	
			
			if (imageContext != NULL) {
				CGContextDrawImage(imageContext, CGRectMake(0.0, 0.0, (CGFloat)shadowMapRes, (CGFloat)shadowMapRes), shadowmapImage);
				CGContextRelease(imageContext);
			} else {
				[NSException raise:@"Error loading image" format:@"Could not load terrain texture image for shadowmap generation"];
			}
		} else {
			[NSException raise:@"File not found" format:@"Could not load terrain texture image for shadowmap generation"];
		}
		[img release];
	} else {
		textureMap = nil;
		if (shadowMap)
			free(shadowMap);
		shadowMapRes = 0;
	}
}

-(void)setDetailMap:(NSString*)file usingMedia:(XMediaGroup*)media
{
	[detailMap mediaRelease];
	if (file != nil)
		detailMap = [XTexture mediaRetainFile:file usingMedia:media];
	else
		detailMap = nil;
}

-(NSString*)getRenderGroupID
{
	return @"2_terrain";
}

-(void)beginRenderGroup
{
	glDisable(GL_LIGHTING);
	glDisableClientState(GL_NORMAL_ARRAY);
	glEnableClientState(GL_VERTEX_ARRAY);
	glClientActiveTexture(GL_TEXTURE0);
    glEnableClientState(GL_TEXTURE_COORD_ARRAY);
	glClientActiveTexture(GL_TEXTURE1);
    glEnableClientState(GL_TEXTURE_COORD_ARRAY);

	if (textureMap) {
		glActiveTexture(GL_TEXTURE0);
		glBindTexture(GL_TEXTURE_2D, textureMap.glTexture);
		glEnable(GL_TEXTURE_2D);
	}

	if (detailMap) {
		glActiveTexture(GL_TEXTURE1);
		glBindTexture(GL_TEXTURE_2D, detailMap.glTexture);
		glEnable(GL_TEXTURE_2D);
	}
	
	xglSetMaterial(&material);
}

-(void)endRenderGroup
{
	glEnable(GL_LIGHTING);
	glEnableClientState(GL_NORMAL_ARRAY);
	glDisableClientState(GL_VERTEX_ARRAY);
	glClientActiveTexture(GL_TEXTURE1);
    glDisableClientState(GL_TEXTURE_COORD_ARRAY);
	glClientActiveTexture(GL_TEXTURE0);
    glDisableClientState(GL_TEXTURE_COORD_ARRAY);
	glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
	glBindBuffer(GL_ARRAY_BUFFER, 0);
	if (textureMap) {
		glActiveTexture(GL_TEXTURE0);
		glBindTexture(GL_TEXTURE_2D, 0);
	}
	if (detailMap) {
		glActiveTexture(GL_TEXTURE1);
		glBindTexture(GL_TEXTURE_2D, 0);
	}
	xglNotifyTextureBindingsChanged();
	xglNotifyMeshBindingsChanged();
}

-(void)render:(XCamera*)cam
{
	camera = cam;
	
	XScalar invGridSize = 1.0 / TERRAIN_CHUNK_GRID_SIZE;
	chunkSize.x = (boundingBox.max.x - boundingBox.min.x) * invGridSize;
	chunkSize.y = (boundingBox.max.y - boundingBox.min.y);
	chunkSize.z = (boundingBox.max.z - boundingBox.min.z) * invGridSize;
	
	XIntRect region;
	region.left = 0;
	region.right = TERRAIN_CHUNK_GRID_SIZE-1;
	region.top = 0;
	region.bottom = TERRAIN_CHUNK_GRID_SIZE-1;
	
	glTranslatef(boundingBox.min.x, boundingBox.min.y, boundingBox.min.z);
	glScalef((boundingBox.max.x - boundingBox.min.x), (boundingBox.max.y - boundingBox.min.y), (boundingBox.max.z - boundingBox.min.z));
	[self renderRegion:region];
}

-(void)renderRegion:(XIntRect)region
{
	// calculate local bounds
	XBoundingBox regionAABB;
	regionAABB.min.x = boundingBox.min.x + chunkSize.x * (region.left);
	regionAABB.min.y = boundingBox.min.y + chunkSize.y * 0;
	regionAABB.min.z = boundingBox.min.z + chunkSize.z * (region.top);
	regionAABB.max.x = boundingBox.min.x + chunkSize.x * (region.right+1);
	regionAABB.max.y = boundingBox.min.y + chunkSize.y * 1;
	regionAABB.max.z = boundingBox.min.z + chunkSize.z * (region.bottom+1);
	
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
			// cannot subdivide visibility checks any further, so calculate LOD and render the chunk
			assert(region.top == region.bottom);
			XVector2 bbVec;
			bbVec.x = (regionAABB.min.x + regionAABB.max.x) * 0.5f - camera->origin.x;
			bbVec.y = (regionAABB.min.z + regionAABB.max.z) * 0.5f - camera->origin.z;
			XScalar distance = xLength_Vec2(&bbVec);
			int lod = indexBufferCount * xSqrt(distance / lodRange);
			
			XTerrainChunk *chunk = chunkGrid[region.left][region.top];
			[chunk render:lod];
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
			int cameraX = TERRAIN_CHUNK_GRID_SIZE * (camera->origin.x - boundingBox.min.x) / (boundingBox.max.x - boundingBox.min.x);
			int cameraZ = TERRAIN_CHUNK_GRID_SIZE * (camera->origin.z - boundingBox.min.z) / (boundingBox.max.z - boundingBox.min.z);
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

-(void)buildIndexBuffers
{
	GLushort *indexes = (GLushort*)malloc((chunkTileRes * (chunkTileRes+4) * 2 * 3) * sizeof(GLushort));

	int lod = 0, vStep = 1;
	while (vStep <= chunkTileRes) {
		unsigned short *ptr = indexes;
		unsigned int indexCount = 0;
		
		// main grid
		for (int y = 0; y < chunkTileRes; y+=vStep) {
			for (int x = 0; x < chunkTileRes; x+=vStep) {
				GLushort vTopLeft = y*(chunkTileRes+1) + x;
				GLushort vBottomLeft = (y+vStep)*(chunkTileRes+1) + x;
				*ptr++ = vBottomLeft;
				*ptr++ = vTopLeft+vStep;
				*ptr++ = vTopLeft;
				*ptr++ = vBottomLeft+vStep;
				*ptr++ = vTopLeft+vStep;
				*ptr++ = vBottomLeft;
				indexCount += 6;
			}
		}
		
		// skirt
		GLushort skirtStart = (chunkTileRes+1) * (chunkTileRes+1);
		{
			int y = 0;
			for (int x = 0; x < chunkTileRes; x+=vStep){
				GLushort vTopLeft = y * (chunkTileRes+1) + x;
				GLushort vBottomLeft = skirtStart; skirtStart += vStep;
				*ptr++ = vTopLeft+vStep;
				*ptr++ = vBottomLeft;
				*ptr++ = vTopLeft;
				*ptr++ = vBottomLeft+vStep;
				*ptr++ = vBottomLeft;
				*ptr++ = vTopLeft+vStep;
				indexCount += 6;
			}
			++skirtStart;
			
			y = chunkTileRes;
			for (int x = 0; x < chunkTileRes; x+=vStep){
				GLushort vTopLeft = y * (chunkTileRes+1) + x;
				GLushort vBottomLeft = skirtStart; skirtStart += vStep;
				*ptr++ = vBottomLeft;
				*ptr++ = vTopLeft+vStep;
				*ptr++ = vTopLeft;
				*ptr++ = vBottomLeft;
				*ptr++ = vBottomLeft+vStep;
				*ptr++ = vTopLeft+vStep;
				indexCount += 6;
			}
			++skirtStart;
		}
		{
			int x = 0;
			for (int y = 0; y < chunkTileRes; y+=vStep){
				GLushort vTopLeft = y * (chunkTileRes+1) + x;
				GLushort vTopRight = (y+vStep) * (chunkTileRes+1) + x;
				GLushort vBottomLeft = skirtStart; skirtStart += vStep;
				*ptr++ = vBottomLeft;
				*ptr++ = vTopRight;
				*ptr++ = vTopLeft;
				*ptr++ = vBottomLeft;
				*ptr++ = vBottomLeft+vStep;
				*ptr++ = vTopRight;
				indexCount += 6;
			}
			++skirtStart;
			
			x = chunkTileRes;
			for (int y = 0; y < chunkTileRes; y+=vStep){
				GLushort vTopLeft = y * (chunkTileRes+1) + x;
				GLushort vTopRight = (y+vStep) * (chunkTileRes+1) + x;
				GLushort vBottomLeft = skirtStart; skirtStart += vStep;
				*ptr++ = vTopRight;
				*ptr++ = vBottomLeft;
				*ptr++ = vTopLeft;
				*ptr++ = vBottomLeft+vStep;
				*ptr++ = vBottomLeft;
				*ptr++ = vTopRight;
				indexCount += 6;
			}
			++skirtStart;
		}
		
		_TerrainIndexBuffer iBuff;
		iBuff.count = indexCount;
		glGenBuffers(1, &iBuff.glBuffer);
		glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, iBuff.glBuffer);
		glBufferData(GL_ELEMENT_ARRAY_BUFFER, indexCount * sizeof(GLushort), indexes, GL_STATIC_DRAW);
		glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
		
		indexBuffers[lod] = iBuff;
		++lod;
		vStep *= 2;
	}
	indexBufferCount = lod;

	free(indexes);
}

-(void)destroyIndexBuffers
{
	glDeleteBuffers(1, &indexBuffers[0].glBuffer);
}

-(_TerrainIndexBuffer)getIndexBufferForLOD:(int)lod
{
	if (lod >= indexBufferCount)
		lod = indexBufferCount - 1;
	return indexBuffers[lod];
}

@end


@implementation XTerrainChunk

-(id)initWithTerrain:(XTerrain*)owner
{
	if ((self = [super init])) {
		terrain = owner;
		vertexBuffer = 0;
	}
	return self;
}

-(void)dealloc
{
	[self unloadHeightMesh];
	[super dealloc];
}

typedef struct {
	GLfloat position[3];
	GLfloat uv[2], uvB[2];
} VertexStruct;

-(void)loadHeightMesh:(float*)heightArray arrayWidth:(int)arrayWidth heightRegion:(XIntRect)region
{
	[self unloadHeightMesh];
	
	int chunkTileRes = terrain.chunkTileRes;
	int vertexCount = ((chunkTileRes+1)*(chunkTileRes+1) + (chunkTileRes+1)*4);
	VertexStruct *vertexes = (VertexStruct*)malloc(vertexCount * sizeof(VertexStruct));
	
	assert((region.right - region.left) == chunkTileRes);
	GLfloat uvStep = 1.0f / (arrayWidth-1);
	GLfloat uvStepB = (float)TERRAIN_DETAIL_MAP_REPEATS_PER_CHUNK / terrain.chunkTileRes;
	
	//Main grid
	VertexStruct *ptr = vertexes;
	int yB = 0;
	for (int y = region.top; y <= region.bottom; ++y) {
		int xB = 0;
		for (int x = region.left; x <= region.right; ++x) {
			GLfloat height = heightArray[y*arrayWidth + x];
			VertexStruct vertex;
			vertex.uv[0] = uvStep * x;
			vertex.uv[1] = uvStep * y;
			vertex.uvB[0] = uvStepB * xB;
			vertex.uvB[1] = uvStepB * yB;
			vertex.position[0] = vertex.uv[0];
			vertex.position[1] = height;
			vertex.position[2] = vertex.uv[1];
			*ptr++ = vertex;
			++xB;
		}
		++yB;
	}
	//Top/bottom skirt
	XScalar skirtHeight = terrain.skirtHeight;
	yB = 0;
	for (int y = region.top; y <= region.bottom; y+=chunkTileRes) {
		int xB = 0;
		for (int x = region.left; x <= region.right; ++x) {
			GLfloat height = heightArray[y*arrayWidth + x];
			VertexStruct vertex;
			vertex.uv[0] = uvStep * x;
			vertex.uv[1] = uvStep * y;
			vertex.uvB[0] = uvStepB * xB;
			vertex.uvB[1] = uvStepB * yB;
			vertex.position[0] = vertex.uv[0];
			vertex.position[1] = height-skirtHeight;
			vertex.position[2] = vertex.uv[1];
			*ptr++ = vertex;
			++xB;
		}
		++yB;
	}
	//Left/right skirt
	yB = 0;
	for (int x = region.left; x <= region.right; x+=chunkTileRes) {
		int xB = 0;
		for (int y = region.top; y <= region.bottom; ++y) {
			GLfloat height = heightArray[y*arrayWidth + x];
			VertexStruct vertex;
			vertex.uv[0] = uvStep * x;
			vertex.uv[1] = uvStep * y;
			vertex.uvB[0] = uvStepB * xB;
			vertex.uvB[1] = uvStepB * yB;
			vertex.position[0] = vertex.uv[0];
			vertex.position[1] = height-skirtHeight;
			vertex.position[2] = vertex.uv[1];
			*ptr++ = vertex;
			++xB;
		}
		++yB;
	}
	
	glGenBuffers(1, &vertexBuffer);
	glBindBuffer(GL_ARRAY_BUFFER, vertexBuffer);
    glBufferData(GL_ARRAY_BUFFER, vertexCount * sizeof(VertexStruct), vertexes, GL_STATIC_DRAW);
	glBindBuffer(GL_ARRAY_BUFFER, 0);
	
	free(vertexes);
}

-(void)unloadHeightMesh
{
	if (vertexBuffer) {
		glDeleteBuffers(1, &vertexBuffer);
		vertexBuffer = 0;
	}
}

-(void)render:(int)lod
{
	_TerrainIndexBuffer indexBuff = [terrain getIndexBufferForLOD:lod];
	glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, indexBuff.glBuffer);	
	glBindBuffer(GL_ARRAY_BUFFER, vertexBuffer);
	glVertexPointer(3, GL_FLOAT, sizeof(VertexStruct), (void*)offsetof(VertexStruct,position));
	glClientActiveTexture(GL_TEXTURE0);
	glTexCoordPointer(2, GL_FLOAT, sizeof(VertexStruct), (void*)offsetof(VertexStruct,uv));
	glClientActiveTexture(GL_TEXTURE1);
	glTexCoordPointer(2, GL_FLOAT, sizeof(VertexStruct), (void*)offsetof(VertexStruct,uvB));
	glDrawElements(GL_TRIANGLES, indexBuff.count, GL_UNSIGNED_SHORT, (void*)0);
}

@end





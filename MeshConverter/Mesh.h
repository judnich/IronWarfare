// Copyright © 2009 John Judnich. All rights reserved.

#import "XMath.h"
@class SubMesh;

typedef struct {
	XVector3 position;
	XVector3 normal;
	XVector2 texcoord;
} MeshVertex;

typedef unsigned short MeshIndex;

typedef struct {
	MeshVertex *vertexBuffer;
	unsigned int vertexCount;
	MeshIndex *indexBuffer;
	unsigned int indexCount;
	XBoundingBox boundingBox;
} MeshData;


@interface Mesh : NSObject {
	NSMutableArray *subMeshes;
}

-(id)initWithFile:(const char*)filename;
-(void)dealloc;

-(void)optimize;
-(BOOL)saveToFile:(const char*)filename;

@end


@interface SubMesh : NSObject {
@public
	char name[256];
	char textureFilename[512];
	MeshData meshData;
}

-(id)initWithName:(const char*)subMeshName defaultTexture:(const char*)filename meshData:(MeshData*)mData;
-(void)dealloc;

-(void)appendSubMesh:(SubMesh*)appendMesh;

@end

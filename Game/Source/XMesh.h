// Copyright © 2010 John Judnich. All rights reserved.

#import "XMediaGroup.h"
#import "XMath.h"
@class XSubMesh;

typedef struct {
	XVector3 position;
	XVector3 normal;
	XVector2 texcoord;
} XMeshVertex;

typedef unsigned short XMeshIndex;


@interface XMesh : XResource {
	NSArray *subMeshes;
}

@property(readonly) NSArray *subMeshes;

-(id)initWithFile:(NSString*)filename usingMedia:(XMediaGroup*)media;
-(void)dealloc;

@end


@interface XSubMesh : NSObject {
	NSString *name, *defaultTextureFilename;
	unsigned int glVertexBuffer;
	unsigned int glIndexBuffer;
	size_t glVertexCount;
	size_t glIndexCount;
	XBoundingBox boundingBox;
}

@property(readonly) unsigned int glVertexBuffer, glIndexBuffer;
@property(readonly) size_t glVertexCount, glIndexCount;
@property(readonly) NSString *name, *defaultTextureFilename;
@property(readonly) XBoundingBox boundingBox;

-(id)initWithName:(NSString*)subMeshName defaultTexture:(NSString*)filename
	vertexBuffer:(unsigned int)vBuff vertexCount:(size_t)vCount
	indexBuffer:(unsigned int)iBuff indexCount:(size_t)iCount
	boundingBox:(XBoundingBox)bBox;
-(void)dealloc;

@end

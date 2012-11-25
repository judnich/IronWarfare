// Copyright © 2010 John Judnich. All rights reserved.

#import "XMesh.h"
#import "XMath.h"
#import "XGL.h"
#import <stdio.h>


@implementation XMesh

@synthesize subMeshes;

-(id)initWithFile:(NSString*)filename usingMedia:(XMediaGroup*)media
{
	if ((self = [super initWithFile:filename usingMedia:media])) {
		// open file
		NSAutoreleasePool *autoreleasePool = [[NSAutoreleasePool alloc] init];
		NSString *directory = [filename stringByDeletingLastPathComponent];
		NSString *fileN = [filename lastPathComponent];
		NSString *sourcePath = [[NSBundle mainBundle] pathForResource:fileN ofType:nil inDirectory:directory];
		FILE *file = fopen([sourcePath UTF8String], "rb");
		if (file == NULL) {
			[autoreleasePool release];
			NSLog(@"Error reading mesh file %@: File not found", filename);
			return nil;
		}
		
		// read submesh count
		unsigned int subMeshCount = 0;
		fread(&subMeshCount, sizeof(unsigned int), 1, file);
		
		// read submeshes
		XSubMesh **subMeshArray = malloc(sizeof(XSubMesh*) * subMeshCount);
		char strBuff[256];
		for (unsigned int i = 0; i < subMeshCount; ++i) {
			// submesh name
			unsigned int nameLen = 0;
			fread(&nameLen, sizeof(unsigned int), 1, file);
			fread(strBuff, sizeof(char), nameLen, file);
			strBuff[nameLen] = '\0';
			NSString *name = [NSString stringWithUTF8String:strBuff];
			
			// submesh texture file
			unsigned int texturefileLen = 0;
			fread(&texturefileLen, sizeof(unsigned int), 1, file);
			fread(strBuff, sizeof(char), texturefileLen, file);
			strBuff[texturefileLen] = '\0';
			NSString *textureFile = nil;
			if (strlen(strBuff) > 0)
				textureFile = [directory stringByAppendingPathComponent:[NSString stringWithUTF8String:strBuff]];
			else
				textureFile = @"";
			
			// bounding box
			XBoundingBox box;
			fread(&box, sizeof(XBoundingBox), 1, file);
			
			// vertex buffer
			unsigned int vCount = 0;
			unsigned int vBuff = 0;
			fread(&vCount, sizeof(unsigned int), 1, file);
			XMeshVertex *vBuffArray = malloc(sizeof(XMeshVertex) * vCount);
			fread(vBuffArray, sizeof(XMeshVertex), vCount, file);
			glGenBuffers(1, &vBuff);
			glBindBuffer(GL_ARRAY_BUFFER, vBuff);
			glBufferData(GL_ARRAY_BUFFER, vCount * sizeof(XMeshVertex), vBuffArray, GL_STATIC_DRAW);
			glBindBuffer(GL_ARRAY_BUFFER, 0);			
			free(vBuffArray);
			
			// index buffer
			unsigned int iCount = 0;
			unsigned int iBuff = 0;
			fread(&iCount, sizeof(unsigned int), 1, file);
			XMeshIndex *iBuffArray = malloc(sizeof(XMeshIndex) * iCount);
			fread(iBuffArray, sizeof(XMeshIndex), iCount, file);
			glGenBuffers(1, &iBuff);
			glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, iBuff);
			glBufferData(GL_ELEMENT_ARRAY_BUFFER, iCount * sizeof(XMeshIndex), iBuffArray, GL_STATIC_DRAW);
			glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);			
			free(iBuffArray);
			
			XSubMesh *subMesh = [[XSubMesh alloc] initWithName:name defaultTexture:textureFile
								vertexBuffer:vBuff vertexCount:vCount
								indexBuffer:iBuff indexCount:iCount
								boundingBox:box];
			subMeshArray[i] = subMesh;
		}
		subMeshes = [[NSArray alloc] initWithObjects:subMeshArray count:subMeshCount];
		for (unsigned int i = 0; i < subMeshCount; ++i)
			[subMeshArray[i] release];
		free(subMeshArray);
		
		// close file
		fclose(file);
		[autoreleasePool release];
	}
	return self;
}

-(void)dealloc
{
	[subMeshes release];
	[super dealloc];
}

@end


@implementation XSubMesh

@synthesize glVertexBuffer, glIndexBuffer;
@synthesize glVertexCount, glIndexCount;
@synthesize name, defaultTextureFilename;
@synthesize boundingBox;

-(id)initWithName:(NSString*)subMeshName defaultTexture:(NSString*)filename
	vertexBuffer:(unsigned int)vBuff vertexCount:(size_t)vCount
	indexBuffer:(unsigned int)iBuff indexCount:(size_t)iCount
	boundingBox:(XBoundingBox)bBox	
{
	if ((self = [super init])) {
		name = subMeshName;
		[name retain];
		defaultTextureFilename = filename;
		[defaultTextureFilename retain];
		glVertexBuffer = vBuff;
		glVertexCount = vCount;
		glIndexBuffer = iBuff;
		glIndexCount = iCount;
		boundingBox = bBox;
	}
	return self;
}

-(void)dealloc
{
	if (glVertexBuffer)
		glDeleteBuffers(1, &glVertexBuffer);
	if (glIndexBuffer)
		glDeleteBuffers(1, &glIndexBuffer);
	[name release];
	[defaultTextureFilename release];
	[super dealloc];
}

@end

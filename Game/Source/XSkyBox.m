// Copyright © 2010 John Judnich. All rights reserved.

#import "XSkyBox.h"
#import "XCamera.h"
#import "XTextureNomip.h"
#import "XGL.h"


@implementation XSkyBox

-(id)initFromFolder:(NSString*)folderPath filePrefix:(NSString*)prefix fileExtension:(NSString*)extension usingMedia:(XMediaGroup*)media
{
	return [self initWithTop:[NSString stringWithFormat:@"%@/%@_top.%@", folderPath, prefix, extension]
		front:[NSString stringWithFormat:@"%@/%@_front.%@", folderPath, prefix, extension]
		back:[NSString stringWithFormat:@"%@/%@_back.%@", folderPath, prefix, extension]
		right:[NSString stringWithFormat:@"%@/%@_right.%@", folderPath, prefix, extension]
		left:[NSString stringWithFormat:@"%@/%@_left.%@", folderPath, prefix, extension]
		usingMedia:media];
}

-(id)initWithTop:(NSString*)topFile front:(NSString*)frontFile back:(NSString*)backFile right:(NSString*)rightFile left:(NSString*)leftFile usingMedia:(XMediaGroup*)media
{
	if ((self = [super init])) {
		faceTex[0] = [XTexture mediaRetainFile:topFile usingMedia:media]; assert(faceTex[0]);
		faceTex[1] = [XTexture mediaRetainFile:leftFile usingMedia:media]; assert(faceTex[1]);
		faceTex[2] = [XTexture mediaRetainFile:rightFile usingMedia:media]; assert(faceTex[2]);
		faceTex[3] = [XTexture mediaRetainFile:frontFile usingMedia:media]; assert(faceTex[3]);
		faceTex[4] = [XTexture mediaRetainFile:backFile usingMedia:media]; assert(faceTex[4]);
		for (int i = 0; i < 5; ++i) {
			glBindTexture(GL_TEXTURE_2D, faceTex[i].glTexture);
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
			glBindTexture(GL_TEXTURE_2D, 0);
		}
		xglNotifyTextureBindingsChanged();
		
		boundingBox.min.x = -10000;
		boundingBox.min.y = -10000;
		boundingBox.min.z = -10000;
		boundingBox.max.x = 10000;
		boundingBox.max.y = 10000;
		boundingBox.max.z = 10000;
		[self notifyBoundsChanged];
	}
	return self;
}

-(void)dealloc
{
	for (int i = 0; i < 5; ++i) {
		[faceTex[i] mediaRelease];
	}
	[super dealloc];
}

-(NSString*)getRenderGroupID
{
	return @"3_sky";
}

-(void)beginRenderGroup
{
	glDisable(GL_LIGHTING);
	glDisableClientState(GL_NORMAL_ARRAY);
	glEnableClientState(GL_VERTEX_ARRAY);
	glActiveTexture(GL_TEXTURE0);
    glEnableClientState(GL_TEXTURE_COORD_ARRAY);
	glDisable(GL_FOG);
	glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
	glBindBuffer(GL_ARRAY_BUFFER, 0);
}

-(void)endRenderGroup
{
	glEnable(GL_LIGHTING);
	glEnableClientState(GL_NORMAL_ARRAY);
	glEnable(GL_FOG);
	xglNotifyTextureBindingsChanged();
	xglNotifyMeshBindingsChanged();
}

-(XVector3*)globalPosition
{
	return (XVector3*)&xVector3_Zero;
}

-(XMatrix3*)globalRotation
{
	return (XMatrix3*)&xMatrix3_Identity;
}

-(void)render:(XCamera*)cam
{
	const float facePositions[5 * 3*4] = {
		// top
		-1, 1, -1,
		1, 1, -1,
		-1, 1, 1,
		1, 1, 1,
		
		// right
		1, 1, -1,
		1, -1, -1,
		1, 1, 1,
		1, -1, 1,		
		
		// left
		-1, 1, -1,
		-1, 1, 1,
		-1, -1, -1,
		-1, -1, 1,		
		
		// front
		1, -1, -1, 
		1, 1, -1,
		-1, -1, -1,
		-1, 1, -1,		
		
		// back
		1, -1, 1, 
		-1, -1, 1,
		1, 1, 1,
		-1, 1, 1,		
	};
	
	const float faceAABBs[5 * 3*2] = {
		-1, 0.99, -1,
		1, 1.01, 1,

		0.99, -1, -1,
		1.01, 1, 1,

		-1.01, -1, -1,
		-0.99, 1, 1,

		-1, -1, -1.01,
		1, 1, -0.99,

		-1, -1, 0.99,
		1, 1, 1.01,
	};
	
	const unsigned char faceTexcoords[5 * 2*4] = {
		1, 1,  0, 1,  1, 0,  0, 0,
		1, 0,  1, 1,  0, 0,  0, 1,
		0, 0,  1, 0,  0, 1,  1, 1,
		0, 1,  0, 0,  1, 1,  1, 0,
		1, 1,  0, 1,  1, 0,  0, 0,
	};
	
	float sc = cam->farClip * 0.578f;
	glTranslatef(cam->origin.x, cam->origin.y, cam->origin.z);
	glScalef(sc, sc, sc);
	XBoundingBox aabb;
	for (int i = 0; i < 5; ++i) {
		aabb.min = *((XVector3*)&faceAABBs[(i*2) * 3]);
		aabb.max = *((XVector3*)&faceAABBs[(i*2+1) * 3]);
		aabb.min.x *= sc; aabb.min.y *= sc; aabb.min.z *= sc;
		aabb.max.x *= sc; aabb.max.y *= sc; aabb.max.z *= sc;
		if ([cam isVisibleBox:&aabb]) {
			glBindTexture(GL_TEXTURE_2D, faceTex[i].glTexture);
			glVertexPointer(3, GL_FLOAT, 0, &facePositions[i * (3*4)]);
			glEnableClientState(GL_VERTEX_ARRAY);
			glTexCoordPointer(2, GL_BYTE, 0, &faceTexcoords[i * (2*4)]);
			glEnableClientState(GL_TEXTURE_COORD_ARRAY);
			glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
		}
	}
}

@end

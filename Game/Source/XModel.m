// Copyright © 2010 John Judnich. All rights reserved.

#import "XModel.h"
#import "XTexture.h"
#import "XTextureNomip.h"
#import "XScene.h"
#import "XGL.h"


@implementation XModel

@synthesize subModels;

-(id)initWithMesh:(XMesh*)msh
{
	if ((self = [super init])) {
		mesh = msh;
		[mesh mediaRetain];
		
		material = xglGetDefaultMaterial();
		
		boundingBox.min.x = INFINITY; boundingBox.min.y = INFINITY; boundingBox.min.z = INFINITY;
		boundingBox.max.x = -INFINITY; boundingBox.max.y = -INFINITY; boundingBox.max.z = -INFINITY;
		
		NSMutableArray *tmpSubModels = [[NSMutableArray alloc] initWithCapacity:mesh.subMeshes.count];
		for (XSubMesh *subMesh in mesh.subMeshes) {
			XSubModel *subModel = [[XSubModel alloc] initWithSubMesh:subMesh fromModel:self usingMedia:mesh.mediaGroup];
			subModel.parent = self;
			[tmpSubModels addObject:subModel];
			[subModel release];

			// merge bounding boxes
			XBoundingBox mergeBB = subModel->boundingBox;
			if (mergeBB.min.x < boundingBox.min.x) boundingBox.min.x = mergeBB.min.x;
			if (mergeBB.max.x > boundingBox.max.x) boundingBox.max.x = mergeBB.max.x;
			if (mergeBB.min.y < boundingBox.min.y) boundingBox.min.y = mergeBB.min.y;
			if (mergeBB.max.y > boundingBox.max.y) boundingBox.max.y = mergeBB.max.y;
			if (mergeBB.min.z < boundingBox.min.z) boundingBox.min.z = mergeBB.min.z;
			if (mergeBB.max.z > boundingBox.max.z) boundingBox.max.z = mergeBB.max.z;
		}
		[self notifyBoundsChanged];
		subModels = [[NSArray alloc] initWithArray:tmpSubModels];
		[tmpSubModels release];
	}
	return self;
}

-(id)initWithModel:(XModel*)copyModel
{
	if (copyModel == nil) return nil;
	if ((self = [super init])) {
		mesh = copyModel->mesh;
		[mesh mediaRetain];
		
		material = copyModel->material;
		
		boundingBox = copyModel->boundingBox;
		[self notifyBoundsChanged];
		
		NSMutableArray *tmpSubModels = [[NSMutableArray alloc] initWithCapacity:mesh.subMeshes.count];
		for (XSubModel *copySubModel in copyModel->subModels) {
			XSubModel *subModel = [[XSubModel alloc] initWithSubModel:copySubModel fromModel:self];
			subModel.parent = self;
			[tmpSubModels addObject:subModel];
			[subModel release];
		}
		subModels = [[NSArray alloc] initWithArray:tmpSubModels];
		[tmpSubModels release];
	}
	return self;
}

-(id)initWithFile:(NSString*)meshFile usingMedia:(XMediaGroup*)media
{
	XMesh *msh = [XMesh mediaRetainFile:meshFile usingMedia:media];
	if (msh) {
		self = [self initWithMesh:msh];
		[msh mediaRelease];
		return self;
	}
	return nil;
}

-(void)dealloc
{
	[subModels release];
	[mesh mediaRelease];
	[super dealloc];
}

-(void)setScene:(XScene*)scn
{
	if (scn != scene) {
		for (XSubModel *subModel in subModels) {
			subModel.scene = scn;
		}
	}
	[super setScene:scn];
}

-(void)setUnloadedTextures:(XTexture*)texture
{
	for (XSubModel *subModel in subModels) {
		if (subModel.texture == nil)
			subModel.texture = texture;
	}
}

@end


@interface XSubModel (private)

-(void)updateRenderGroupID;

@end


@implementation XSubModel

-(id)initWithSubMesh:(XSubMesh*)sMesh fromModel:(XModel*)m usingMedia:(XMediaGroup*)media;
{
	if ((self = [super init])) {
		model = m;
		subMesh = sMesh;
		[subMesh retain];
		
		// load texture if one is specified
		NSString *file = nil;
		if (sMesh.defaultTextureFilename != nil && ![sMesh.defaultTextureFilename isEqualToString:@""])
			file = [sMesh.defaultTextureFilename lastPathComponent];
		if (!file || [file characterAtIndex:0] == '[') // specifying a texture as "[something]" indicates the texture should not be loaded
			texture = nil;
		else
			texture = [XTexture mediaRetainFile:(sMesh.defaultTextureFilename) usingMedia:media];
		
		[self updateRenderGroupID];
		
		boundingBox = subMesh.boundingBox;
		[self notifyBoundsChanged];
	}
	return self;
}

-(id)initWithSubModel:(XSubModel*)copySubModel fromModel:(XModel*)m
{
	if ((self = [super init])) {
		model = m;
		subMesh = copySubModel->subMesh;
		[subMesh retain];
		texture = copySubModel->texture;
		[texture mediaRetain];
		[self updateRenderGroupID];
		
		boundingBox = subMesh.boundingBox;
		[self notifyBoundsChanged];
	}
	return self;
}

-(void)dealloc
{
	[texture mediaRelease];
	[subMesh release];
	[renderGroupID release];
	[super dealloc];
}

-(void)setTexture:(XTexture*)tex
{
	if (tex != texture) {
		[texture mediaRelease];
		texture = tex;
		[texture mediaRetain];
		[self updateRenderGroupID];
	}
}

-(XTexture*)texture
{
	return texture;
}

-(void)updateRenderGroupID
{
	NSMutableString *tmpRenderGroupID = [NSMutableString stringWithString:@"1_model_"];
	[tmpRenderGroupID appendString:[NSString stringWithFormat:@"%d", (int)texture]];
	[tmpRenderGroupID appendString:@"::"];
	[tmpRenderGroupID appendString:[NSString stringWithFormat:@"%d", (int)subMesh]];
	if (renderGroupID) [renderGroupID release];
	renderGroupID = [[NSString alloc] initWithString:tmpRenderGroupID];
	[self notifyRenderGroupChanged];
}

-(NSString*)getRenderGroupID
{
	return renderGroupID;
}

-(void)beginRenderGroup
{
	if (texture) {
		if (xglCheckBindTextures(texture.glTexture, 0)) {
			glActiveTexture(GL_TEXTURE0);
			glBindTexture(GL_TEXTURE_2D, texture.glTexture);
			glEnable(GL_TEXTURE_2D);
		}
	} else {
		if (xglCheckBindTextures(0, 0)) {
			glActiveTexture(GL_TEXTURE0);
			glBindTexture(GL_TEXTURE_2D, 0);
			glDisable(GL_TEXTURE_2D);
		}
	}
	
	if (xglCheckBindMesh(subMesh.glVertexBuffer, subMesh.glIndexBuffer)) {
		glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, subMesh.glIndexBuffer);
		glBindBuffer(GL_ARRAY_BUFFER, subMesh.glVertexBuffer);
		glVertexPointer(3, GL_FLOAT, sizeof(XMeshVertex), (void*)offsetof(XMeshVertex,position));
		glNormalPointer(GL_FLOAT, sizeof(XMeshVertex), (void*)offsetof(XMeshVertex,normal));
		glTexCoordPointer(2, GL_FLOAT, sizeof(XMeshVertex), (void*)offsetof(XMeshVertex,texcoord));
		
		glEnableClientState(GL_VERTEX_ARRAY);
		glEnableClientState(GL_NORMAL_ARRAY);
		glEnableClientState(GL_TEXTURE_COORD_ARRAY);
	}
}

-(void)render:(XCamera*)cam
{
	xglSetMaterial(&model->material);
	glDrawElements(GL_TRIANGLES, subMesh.glIndexCount, GL_UNSIGNED_SHORT, (void*)0);
}

@end

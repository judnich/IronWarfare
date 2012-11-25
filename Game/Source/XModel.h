// Copyright © 2010 John Judnich. All rights reserved.

#import "XNode.h"
#import "XMesh.h"
#import "XGL.h"
@class XTexture;
@class XSubModel;


@interface XModel : XNode {
	XMesh *mesh;
	NSArray *subModels;
@public
	XMaterial material;
}

@property(readonly) NSArray *subModels;

-(id)initWithMesh:(XMesh*)msh;
-(id)initWithModel:(XModel*)copyModel;
-(id)initWithFile:(NSString*)meshFile usingMedia:(XMediaGroup*)media;
-(void)dealloc;

-(void)setUnloadedTextures:(XTexture*)texture;

@end


@interface XSubModel : XNode {
	XModel *model;
	XSubMesh *subMesh;
	XTexture *texture;
	NSString *renderGroupID;
}

@property(retain) XTexture *texture;

-(id)initWithSubMesh:(XSubMesh*)sMesh fromModel:(XModel*)m usingMedia:(XMediaGroup*)media;
-(id)initWithSubModel:(XSubModel*)copySubModel fromModel:(XModel*)m;
-(void)dealloc;

-(void)setTexture:(XTexture*)tex;
-(XTexture*)texture;

@end

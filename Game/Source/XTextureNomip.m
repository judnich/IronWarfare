// Copyright © 2010 John Judnich. All rights reserved.

#import "XTextureNomip.h"
#import "XGL.h"


@interface XTexture (protected)

-(void)loadMipFramesFromFile:(NSString*)filepath;
-(void)configureGLTextureParameters;

@end


@implementation XTextureNomip

-(void)configureGLTextureParameters
{
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
	glTexParameteri(GL_TEXTURE_2D, GL_GENERATE_MIPMAP, GL_FALSE);
}

@end

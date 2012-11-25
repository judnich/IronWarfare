// Copyright © 2010 John Judnich. All rights reserved.

#import "XNode.h"
@class XMediaGroup;
@class XTexture;


@interface XSkyBox : XNode {
	XTexture *faceTex[5];
}

-(id)initFromFolder:(NSString*)folderPath filePrefix:(NSString*)prefix fileExtension:(NSString*)extension usingMedia:(XMediaGroup*)media;
-(id)initWithTop:(NSString*)topFile front:(NSString*)frontFile back:(NSString*)backFile right:(NSString*)rightFile left:(NSString*)leftFile usingMedia:(XMediaGroup*)media;
-(void)dealloc;

@end

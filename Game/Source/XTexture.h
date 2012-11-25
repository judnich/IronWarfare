// Copyright © 2010 John Judnich. All rights reserved.

#import "XMediaGroup.h"
#import <OpenGLES/ES1/gl.h>
#import <OpenGLES/ES1/glext.h>


typedef enum {
	XTexColorFormat_Null = 0,
	XTexColorFormat_Alpha = GL_ALPHA,
	XTexColorFormat_RGB = GL_RGB,
	XTexColorFormat_RGBA = GL_RGBA,
	XTexColorFormat_Luminance = GL_LUMINANCE,
	XTexColorFormat_LuminanceAlpha = GL_LUMINANCE_ALPHA,
	XTexColorFormat_RGBA_CompressedPVR_2BPP = GL_COMPRESSED_RGBA_PVRTC_2BPPV1_IMG,
	XTexColorFormat_RGBA_CompressedPVR_4BPP = GL_COMPRESSED_RGBA_PVRTC_4BPPV1_IMG,
	XTexColorFormat_RGB_CompressedPVR_2BPP = GL_COMPRESSED_RGB_PVRTC_2BPPV1_IMG,
	XTexColorFormat_RGB_CompressedPVR_4BPP = GL_COMPRESSED_RGB_PVRTC_4BPPV1_IMG,
} XTextureColorFormat;

typedef enum {
	XTexByteFormat_Null = 0,
	XTexByteFormat_Compressed = 1,
	XTexByteFormat_FullBytes = GL_UNSIGNED_BYTE,
	XTexByteFormat_RGB565 = GL_UNSIGNED_SHORT_5_6_5,
	XTexByteFormat_RGBA4444 = GL_UNSIGNED_SHORT_4_4_4_4,
	XTexByteFormat_RGBA5551 = GL_UNSIGNED_SHORT_5_5_5_1,
} XTextureByteFormat;


// Note: The alpha channel, if present, will only be loaded for TGA or PVR files. This limitation
// is due to the fact that the iPhone SDK premultiplies the alpha of PNG files (darkens the
// transparent areas), and also premultiplies when loading an image if it's not already
// premultiplied. This is not desirable for 3D games, etc., so XTexture has it's own internal
// TGA (and PVR) loading code that bypasses the SDK's premultiplications.
@interface XTexture : XResource {
	unsigned int glTexture;
	size_t __width, __height;
	XTextureColorFormat colorFormat;
	XTextureByteFormat byteFormat;
	NSMutableArray *imageMipFrames;
	NSString *errorMessage;
}

@property(readonly) unsigned int glTexture;
@property(readonly) size_t width, height;

-(id)initWithFile:(NSString*)filename usingMedia:(XMediaGroup*)media;
-(void)dealloc;

@end

// Copyright © 2010 John Judnich. All rights reserved.

#import "XTexture.h"
#import "XGL.h"
#import <QuartzCore/QuartzCore.h>


@interface XTextureMipFrame : NSObject {
@public
	unsigned char *byteData;
	size_t byteCount;
	XTextureColorFormat colorFormat;
	XTextureByteFormat byteFormat;
	size_t width, height;
	int level;
@private
	size_t maxByteCount;
}

@property size_t maxByteCount;

-(id)initWithByteCapacity:(size_t)dataSize;
-(void)dealloc;

@end


@implementation XTextureMipFrame

@synthesize maxByteCount;

-(id)initWithByteCapacity:(size_t)dataSize
{
	if ((self = [super init])) {
		width = 0; height = 0; level = 0;
		byteData = malloc(sizeof(unsigned char) * dataSize);
		byteCount = 0;
	}
	return self;
}

-(void)dealloc
{
	free(byteData);
	[super dealloc];
}

@end


@interface XTexture (protected)

-(void)loadMipFramesFromFile:(NSString*)filename;
-(void)configureGLTextureParameters;

@end


@implementation XTexture

@synthesize glTexture, width = __width, height = __height;

-(id)initWithFile:(NSString*)filename usingMedia:(XMediaGroup*)media
{
	if ((self = [super initWithFile:filename usingMedia:media])) {
		NSAutoreleasePool *autoreleasePool = [[NSAutoreleasePool alloc] init];
		
		// load image data into imageMipFrames array
		imageMipFrames = [[NSMutableArray alloc] init];
		[self loadMipFramesFromFile:filename];
		
		// if sucessfully loaded..
		if (imageMipFrames.count > 0) {
			// upload texture to OpenGL
			glGenTextures(1, &glTexture);
			glBindTexture(GL_TEXTURE_2D, glTexture);
			
			[self configureGLTextureParameters];
			
			colorFormat = XTexColorFormat_Null;
			byteFormat = XTexByteFormat_Null;
			int lastLevel = -1;
			for (XTextureMipFrame *mipFrame in imageMipFrames) {
				if (mipFrame->level == 0) {
					__width = mipFrame->width;
					__height = mipFrame->height;
				} else {
					if (mipFrame->level == lastLevel) {
						NSLog(@"Error loading image \"%@\": Duplicate mip levels given.", filename);
						break;
					}
				}
				lastLevel = mipFrame->level;
				if (colorFormat == XTexColorFormat_Null) {
					colorFormat = mipFrame->colorFormat;
					byteFormat = mipFrame->byteFormat;
				} else {
					if (mipFrame->colorFormat != colorFormat || mipFrame->byteFormat != byteFormat) {
						NSLog(@"Error loading image \"%@\": Varying mip frame formats not allowed within a single texture.", filename);
						break;
					}
				}
				if (mipFrame->width != mipFrame->height)
					NSLog(@"Warning: Loading image with non-square dimensions.");
				if (mipFrame->byteFormat == XTexByteFormat_Compressed) {
					// upload compressed image data
					glCompressedTexImage2D(GL_TEXTURE_2D, mipFrame->level, mipFrame->colorFormat,
										   mipFrame->width, mipFrame->height, 0,
										   mipFrame->byteCount, mipFrame->byteData);
				} else {
					// upload uncompressed image data
					glTexImage2D(GL_TEXTURE_2D, mipFrame->level, mipFrame->colorFormat,
								 mipFrame->width, mipFrame->height, 0,
								 mipFrame->colorFormat, mipFrame->byteFormat, mipFrame->byteData);
				}
			}
			
			glBindTexture(GL_TEXTURE_2D, 0);
			xglNotifyTextureBindingsChanged();
		} else {
			if (errorMessage)
				NSLog(@"Error loading image \"%@\": %@", filename, errorMessage);
			else
				NSLog(@"Error loading image \"%@\".", filename);
			__width = 0;
			__height = 0;
			glTexture = 0;
			colorFormat = XTexColorFormat_Null;
			byteFormat = XTexByteFormat_Null;
		}
		
		// unload mip frames now that they've been uploaded to OpenGL
		[imageMipFrames removeAllObjects];
		[imageMipFrames release];
		
		// don't allocate if failed to load
		if (glTexture == 0)
			self = nil;
		
		[autoreleasePool release];
	}
	return self;
}

-(void)dealloc
{
	if (glTexture) {
		glDeleteTextures(1, &glTexture);
		glTexture = 0;
	}	
	[super dealloc];
}

-(void)configureGLTextureParameters
{
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_NEAREST);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
	if (imageMipFrames.count == 1)
		glTexParameteri(GL_TEXTURE_2D, GL_GENERATE_MIPMAP, GL_TRUE);
}

NSString *loadCompressedPVR(NSString *filename, NSMutableArray *imageMipFrames);
NSString *loadUncompressed(NSString *filename, NSMutableArray *imageMipFrames);

-(void)loadMipFramesFromFile:(NSString*)filename
{
	// Try to load the .pvr version of this image by looking for "[filename].pvr" first.
	// For example loading "image.png" would cause it to look for "image.png.pvr". If not found,
	// it will revert to the original filename and load it using the uncompressed loader.
	FILE *compressedFile = NULL;
	NSString *compressedFilename = nil;
	NSString *compressedFilepath = nil;
	
	static int compressionSupported = -1;
	if (compressionSupported)
		compressionSupported = (xCheckExtensionSupported("GL_IMG_texture_compression_pvrtc") != 0);
	
	if (compressionSupported == 1) {
		compressedFilename = filename;
		NSString *extension = [filename pathExtension];
		if (![extension isEqualToString:@"pvr"])
			compressedFilename = [compressedFilename stringByAppendingPathExtension:@"pvr"];

		NSString *directory = [compressedFilename stringByDeletingLastPathComponent];
		NSString *fileN = [compressedFilename lastPathComponent];
		compressedFilepath = [[NSBundle mainBundle] pathForResource:fileN ofType:nil inDirectory:directory];

		compressedFile = fopen([compressedFilepath UTF8String], "rb");
	}
	else {
		NSLog(@"XTexture Warning! PVRTC texture compression not supported. Defaulting to uncompressed textures.");
	}
	
	if (compressedFile) {
		fclose(compressedFile);
		errorMessage = loadCompressedPVR(compressedFilename, imageMipFrames);
	}
	else {
		NSString *directory = [filename stringByDeletingLastPathComponent];
		NSString *fileN = [filename lastPathComponent];
		NSString *uncompressedFilepath = [[NSBundle mainBundle] pathForResource:fileN ofType:nil inDirectory:directory];

		FILE *uncompressedFile = fopen([uncompressedFilepath UTF8String], "rb");
		if (uncompressedFile) {
			fclose(uncompressedFile);
			errorMessage = loadUncompressed(filename, imageMipFrames);
		}
		else {
			errorMessage = @"File not found.";
		}
	}
}

@end


//------------------------------ Uncompressed Image Loader Implementations -----------------------------------

NSString *loadImageDefault(NSString *filepath, NSMutableArray *imageMipFrames);
NSString *loadImageTGA(NSString *filepath, NSMutableArray *imageMipFrames);

NSString *loadUncompressed(NSString *filename, NSMutableArray *imageMipFrames)
{
	NSString *directory = [filename stringByDeletingLastPathComponent];
	NSString *fileN = [filename lastPathComponent];
	NSString *filepath = [[NSBundle mainBundle] pathForResource:fileN ofType:nil inDirectory:directory];
	NSString *extension = [filepath pathExtension];
	if ([extension isEqualToString:@"tga"]) 
		return loadImageTGA(filepath, imageMipFrames);
	else
		return loadImageDefault(filepath, imageMipFrames);
}

NSString *loadImageDefault(NSString *filepath, NSMutableArray *imageMipFrames)
{
	UIImage *img = [[UIImage alloc] initWithContentsOfFile:filepath];
	CGImageRef textureImage = img.CGImage;
	size_t width = CGImageGetWidth(textureImage);
	size_t height = CGImageGetHeight(textureImage);
	
	XTextureMipFrame *mipFrame = nil;
	if (textureImage) {
		mipFrame = [[XTextureMipFrame alloc] initWithByteCapacity:(width * height * 4)];
		CGContextRef textureContext = CGBitmapContextCreate(mipFrame->byteData, width, height, 8, width * 4, CGImageGetColorSpace(textureImage), kCGImageAlphaNoneSkipLast);
		
		if (textureContext != NULL) {
			CGContextDrawImage(textureContext, CGRectMake(0.0, 0.0, (CGFloat)width, (CGFloat)height), textureImage);
			CGContextRelease(textureContext);
			
			// convert to RGB565
			for (int y = 0; y < height; ++y) {
				for (int x = 0; x < width; ++x) {
					uint8_t *RGBA = &mipFrame->byteData[(y*width + x)*4];
					uint16_t RGB565 = (RGBA[0]>>3) << 11 | (RGBA[1]>>2) << 5 | (RGBA[2]>>3);
					uint16_t *outRGB565 = (uint16_t*)(&mipFrame->byteData[(y*width + x)*2]);
					*outRGB565 = RGB565;
				}
			}
			mipFrame->byteFormat = XTexByteFormat_RGB565;
			mipFrame->colorFormat = XTexColorFormat_RGB;
			
			mipFrame->width = width;
			mipFrame->height = height;
		} else {
			[img release];
			[mipFrame release];
			return @"Could not create bitmap context from image.";
		}
	} else {
		[img release];
		return @"Could not init image.";
	}
	[img release];	
	
	[imageMipFrames addObject:mipFrame];
	[mipFrame release];
	return nil;
}

typedef struct {
	GLubyte Header[12];
} TGAHeader;

typedef struct {
	GLubyte header[6];
	GLuint bytesPerPixel;
	GLuint imageSize;
	GLuint temp;
	GLuint type;
	GLuint height;
	GLuint width;
	GLuint bpp;
} TGA;

GLubyte uTGAcompare[12] = {0,0,2, 0,0,0,0,0,0,0,0,0};	// uncompressed TGA Header
GLubyte cTGAcompare[12] = {0,0,10,0,0,0,0,0,0,0,0,0};	// compressed TGA Header

NSString *loadUncompressedTGA(FILE *file, NSMutableArray *imageMipFrames);
NSString *loadCompressedTGA(FILE *file, NSMutableArray *imageMipFrames);

NSString *loadImageTGA(NSString *filepath, NSMutableArray *imageMipFrames)
{
	// Load TGA file manually. TGA files are safe from the iPhone SDK premultiplying the alpha.
	FILE *file = fopen([filepath UTF8String], "rb");

	TGAHeader tgaheader;
	if (fread(&tgaheader, sizeof(TGAHeader), 1, file) == 0) {
		fclose(file);
		return @"Could not read TGA file header";
	}
	
	NSString *error = nil;
	if (memcmp(uTGAcompare, &tgaheader, sizeof(tgaheader)) == 0)
		error = loadUncompressedTGA(file, imageMipFrames);
	else if (memcmp(cTGAcompare, &tgaheader, sizeof(tgaheader)) == 0)
		error = loadCompressedTGA(file, imageMipFrames);
	else {
		fclose(file);
		return @"TGA file must be type 2 or type 10";
	}
	if (error) {
		fclose(file);
		return error;
	}
	
	if (imageMipFrames.count > 0) {
		for (XTextureMipFrame *mipFrame in imageMipFrames) {
			if (mipFrame->colorFormat == XTexColorFormat_RGBA) {
				// convert to RGB4444
				for (int y = 0; y < mipFrame->height; ++y) {
					for (int x = 0; x < mipFrame->width; ++x) {
						uint8_t *RGBA = &mipFrame->byteData[(y*mipFrame->width + x)*4];
						uint16_t RGBA4444 = (RGBA[0]>>4) << 12 | (RGBA[1]>>4) << 8 | (RGBA[2]>>4) << 4 | (RGBA[3]>>4);
						uint16_t *outRGBA4444 = (uint16_t*)(&mipFrame->byteData[(y*mipFrame->width + x)*2]);
						*outRGBA4444 = RGBA4444;
					}
				}
				mipFrame->byteFormat = XTexByteFormat_RGBA4444;
			}
			else if (mipFrame->colorFormat == XTexColorFormat_RGB) {
				// convert to RGB565
				for (int y = 0; y < mipFrame->height; ++y) {
					for (int x = 0; x < mipFrame->width; ++x) {
						uint8_t *RGBA = &mipFrame->byteData[(y*mipFrame->width + x)*4];
						uint16_t RGB565 = (RGBA[0]>>3) << 11 | (RGBA[1]>>2) << 5 | (RGBA[2]>>3);
						uint16_t *outRGB565 = (uint16_t*)(&mipFrame->byteData[(y*mipFrame->width + x)*2]);
						*outRGB565 = RGB565;
					}
				}
				mipFrame->byteFormat = XTexByteFormat_RGB565;
			}
		}
	}
	
	return nil;
}

NSString *loadUncompressedTGA(FILE *file, NSMutableArray *imageMipFrames)
{
	TGA tga;
	if (fread(tga.header, sizeof(tga.header), 1, file) == 0)
		return @"Could not read info header";
	
	tga.width = tga.header[1] * 256 + tga.header[0];
	tga.height = tga.header[3] * 256 + tga.header[2];
	tga.bpp = tga.header[4];
	
	if ((tga.width <= 0) || (tga.height <= 0) || ((tga.bpp != 24) && (tga.bpp != 32)))
		return @"Invalid texture information";
	
	tga.bytesPerPixel = (tga.bpp / 8);
	tga.imageSize = (tga.bytesPerPixel * tga.width * tga.height);
	
	XTextureMipFrame *mipFrame = [[XTextureMipFrame alloc] initWithByteCapacity:tga.imageSize];
	
	if (fread(mipFrame->byteData, 1, tga.imageSize, file) != tga.imageSize) {
		[mipFrame release];
		return @"Could not read image data";
	}
	
	for (GLuint cswap = 0; cswap < (int)tga.imageSize; cswap += tga.bytesPerPixel) {
		mipFrame->byteData[cswap] ^= mipFrame->byteData[cswap+2] ^=
		mipFrame->byteData[cswap] ^= mipFrame->byteData[cswap+2];
	}
	
	mipFrame->width = tga.width;
	mipFrame->height = tga.height;
	if (tga.bytesPerPixel == 3)
		mipFrame->colorFormat = XTexColorFormat_RGB;
	else if (tga.bytesPerPixel == 4)
		mipFrame->colorFormat = XTexColorFormat_RGBA;
	mipFrame->byteFormat = XTexByteFormat_FullBytes;
	
	[imageMipFrames addObject:mipFrame];
	[mipFrame release];
	return nil;
}

NSString *loadCompressedTGA(FILE *file, NSMutableArray *imageMipFrames)
{
	TGA tga;
	if (fread(tga.header, sizeof(tga.header), 1, file) == 0)
		return @"Could not read info header";
	
	tga.width = tga.header[1] * 256 + tga.header[0];
	tga.height = tga.header[3] * 256 + tga.header[2];
	tga.bpp = tga.header[4];
	
	if (tga.width <= 0 || tga.width <= 0 || (tga.bpp != 24 && tga.bpp != 32))
		return @"Invalid texture information";
	
	tga.bytesPerPixel = (tga.bpp / 8);
	tga.imageSize = (tga.bytesPerPixel * tga.width * tga.height);

	XTextureMipFrame *mipFrame = [[XTextureMipFrame alloc] initWithByteCapacity:tga.imageSize];
		
	GLuint pixelcount = tga.height * tga.width;
	GLuint currentpixel = 0;
	GLuint currentbyte = 0;
	GLubyte *colorbuffer = (GLubyte*)malloc(tga.bytesPerPixel);
	
	do {
		GLubyte chunkheader = 0;
		
		if (fread(&chunkheader, sizeof(GLubyte), 1, file) == 0) {
			[mipFrame release];
			free(colorbuffer);
			return @"Could not read RLE header";
		}
		
		if (chunkheader < 128) {
			chunkheader++;
			for (short counter = 0; counter < chunkheader; counter++) {
				if (fread(colorbuffer, 1, tga.bytesPerPixel, file) != tga.bytesPerPixel) {
					[mipFrame release];
					free(colorbuffer);
					return @"Could not read image data";
				}
				mipFrame->byteData[currentbyte] = colorbuffer[2];
				mipFrame->byteData[currentbyte+1] = colorbuffer[1];
				mipFrame->byteData[currentbyte+2] = colorbuffer[0];
				
				if (tga.bytesPerPixel == 4)
					mipFrame->byteData[currentbyte+3] = colorbuffer[3];
				
				currentbyte += tga.bytesPerPixel;
				currentpixel++;
				
				if (currentpixel > pixelcount) {
					[mipFrame release];
					free(colorbuffer);
					return @"Too many pixels read";
				}
			}
		}
		else {
			chunkheader -= 127;
			if (fread(colorbuffer, 1, tga.bytesPerPixel, file) != tga.bytesPerPixel) {	
				[mipFrame release];
				free(colorbuffer);
				return @"Could not read from file";
			}
			
			for (short counter = 0; counter < chunkheader; counter++) {
				mipFrame->byteData[currentbyte] = colorbuffer[2];
				mipFrame->byteData[currentbyte+1] = colorbuffer[1];
				mipFrame->byteData[currentbyte+2] = colorbuffer[0];
				
				if (tga.bytesPerPixel == 4)
					mipFrame->byteData[currentbyte + 3] = colorbuffer[3];
				
				currentbyte += tga.bytesPerPixel;
				currentpixel++;
				
				if (currentpixel > pixelcount) {
					[mipFrame release];
					free(colorbuffer);
					return @"Too many pixels read";
				}
			}
		}
	} while (currentpixel < pixelcount);
	
	free(colorbuffer);
	
	mipFrame->width = tga.width;
	mipFrame->height = tga.height;
	if (tga.bytesPerPixel == 3)
		mipFrame->colorFormat = XTexColorFormat_RGB;
	else if (tga.bytesPerPixel == 4)
		mipFrame->colorFormat = XTexColorFormat_RGBA;
	mipFrame->byteFormat = XTexByteFormat_FullBytes;
	
	[imageMipFrames addObject:mipFrame];
	[mipFrame release];
	return nil;
}


//------------------------------ Compressed (PVR) Image Loader Implementation -----------------------------------

#define PVR_TEXTURE_FLAG_TYPE_MASK 0xff

static char gPVRTexIdentifier[4] = "PVR!";

enum {
	kPVRTextureFlagTypePVRTC_2 = 24,
	kPVRTextureFlagTypePVRTC_4
};

typedef struct {
	uint32_t headerLength;
	uint32_t height;
	uint32_t width;
	uint32_t numMipmaps;
	uint32_t flags;
	uint32_t dataLength;
	uint32_t bpp;
	uint32_t bitmaskRed;
	uint32_t bitmaskGreen;
	uint32_t bitmaskBlue;
	uint32_t bitmaskAlpha;
	uint32_t pvrTag;
	uint32_t numSurfs;
} PVRTexHeader;

NSString *loadCompressedPVR(NSString *filename, NSMutableArray *imageMipFrames)
{
	NSString *directory = [filename stringByDeletingLastPathComponent];
	NSString *fileN = [filename lastPathComponent];
	NSString *filepath = [[NSBundle mainBundle] pathForResource:fileN ofType:nil inDirectory:directory];
	NSData *fileData = [[NSData alloc] initWithContentsOfFile:filepath];

	BOOL success = FALSE;
	PVRTexHeader *header = NULL;
	uint32_t flags, pvrTag;
	uint32_t dataLength = 0, dataOffset = 0, dataSize = 0;
	uint32_t blockSize = 0, widthBlocks = 0, heightBlocks = 0;
	uint32_t width = 0, height = 0, bpp = 4;
	uint8_t *bytes = NULL;
	uint32_t formatFlags;
	XTextureColorFormat format = XTexColorFormat_Null;
	
	header = (PVRTexHeader*)[fileData bytes];
	
	pvrTag = CFSwapInt32LittleToHost(header->pvrTag);
	
	if (gPVRTexIdentifier[0] != ((pvrTag >>  0) & 0xff) || gPVRTexIdentifier[1] != ((pvrTag >>  8) & 0xff) ||
		gPVRTexIdentifier[2] != ((pvrTag >> 16) & 0xff) || gPVRTexIdentifier[3] != ((pvrTag >> 24) & 0xff))
	{
		[fileData release];
		return @"File does not appear to be a PVR image.";
	}
	
	flags = CFSwapInt32LittleToHost(header->flags);
	formatFlags = flags & PVR_TEXTURE_FLAG_TYPE_MASK;
	
	if (formatFlags == kPVRTextureFlagTypePVRTC_4 || formatFlags == kPVRTextureFlagTypePVRTC_2) {
		[imageMipFrames removeAllObjects];
		
		width = CFSwapInt32LittleToHost(header->width);
		height = CFSwapInt32LittleToHost(header->height);
				
		dataLength = CFSwapInt32LittleToHost(header->dataLength);
		
		bytes = ((uint8_t *)[fileData bytes]) + sizeof(PVRTexHeader);
		
		// calculate the data size for each texture level and respect the minimum number of blocks
		while (dataOffset < dataLength) {
			if (formatFlags == kPVRTextureFlagTypePVRTC_4) {
				blockSize = 4 * 4; //pixel by pixel block size for 4bpp
				widthBlocks = width / 4;
				heightBlocks = height / 4;
				bpp = 4;
			}
			else {
				blockSize = 8 * 4; //pixel by pixel block size for 2bpp
				widthBlocks = width / 8;
				heightBlocks = height / 4;
				bpp = 2;
			}
			
			// clamp to minimum number of blocks
			if (widthBlocks < 2)
				widthBlocks = 2;
			if (heightBlocks < 2)
				heightBlocks = 2;
			
			dataSize = widthBlocks * heightBlocks * ((blockSize  * bpp) / 8);
			
			//if (CFSwapInt32LittleToHost(header->bitmaskAlpha)) {
				if (formatFlags == kPVRTextureFlagTypePVRTC_4)
					format = XTexColorFormat_RGBA_CompressedPVR_4BPP;
				else if (formatFlags == kPVRTextureFlagTypePVRTC_2)
					format = XTexColorFormat_RGBA_CompressedPVR_2BPP;
			/*} else {
				if (formatFlags == kPVRTextureFlagTypePVRTC_4)
					format = XTexColorFormat_RGB_CompressedPVR_4BPP;
				else if (formatFlags == kPVRTextureFlagTypePVRTC_2)
					format = XTexColorFormat_RGB_CompressedPVR_2BPP;
			}*/
			
			// save image mip level
			XTextureMipFrame *mipFrame = [[XTextureMipFrame alloc] initWithByteCapacity:dataSize];
			memcpy(mipFrame->byteData, bytes+dataOffset, dataSize);
			mipFrame->byteCount = dataSize;
			mipFrame->colorFormat = format;
			mipFrame->byteFormat = XTexByteFormat_Compressed;
			mipFrame->width = width;
			mipFrame->height = height;
			mipFrame->level = imageMipFrames.count;
			[imageMipFrames addObject:mipFrame];
			[mipFrame release];
			
			dataOffset += dataSize;
			
			width = MAX(width >> 1, 1);
			height = MAX(height >> 1, 1);
		}
		
		success = TRUE;
	}
	
	[fileData release];
	
	if (!success)
		return @"Error reading PVR file data";
	else
		return nil;
}





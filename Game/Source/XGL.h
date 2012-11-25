// Copyright © 2010 John Judnich. All rights reserved.

#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES1/gl.h>
#import <OpenGLES/ES1/glext.h>
#import "XMath.h"

#if !defined(DEBUG) && ! defined(NDEBUG)
#warning Neither of DEBUG/NDEBUG macros are #defined
#endif
#ifdef DEBUG
#define XGL_ASSERT { GLenum er = glGetError(); if (er != GL_NO_ERROR) [NSException raise:@"GL ERROR" format:@"Error: %d", er]; }
#else
#define XGL_ASSERT
#endif


// These functions return YES if the specified buffers/textures aren't currently
// bound to OpenGL, and NO if they are. This can be used to minimize state changes.
// Note that the response will not be accurate unless XGL can keep track of the state,
// so either always call xglCheck___ before binding, or call xglNotify___BindingsChanged
// (see below) after changing OpenGL bindings without checking.
BOOL xglCheckBindMesh(GLuint glVertexBuff, GLuint glIndexBuff);
BOOL xglCheckBindTextures(GLuint glTexture0, GLuint glTexture1);
BOOL xglCheckBindTexture0(GLuint glTexture);
BOOL xglCheckBindTexture1(GLuint glTexture);

// As described above, these functions should be called if you change the OpenGL bindings
// without calling xglCheck___ first. This is the only other way XGL can keep track of bindings.
// If you did not call either when changing bindings, the next call to xglCheck___ would be unreliable.
void xglNotifyMeshBindingsChanged();
void xglNotifyTextureBindingsChanged();

// Misc. helper types and functions
typedef enum {
	XBlend_None,
	XBlend_Additive,
	XBlend_Modulative,
	XBlend_Alpha
} XBlendMode;

typedef struct {
	unsigned char red, green, blue, alpha;
} XColorBytes;

typedef struct {
	float red, green, blue, alpha;
} XColor;

static const XColor xColor_Red = { 1, 0, 0, 1 };
static const XColor xColor_Green = { 0, 1, 0, 1 };
static const XColor xColor_Blue = { 0, 0, 1, 1 };
static const XColor xColor_Black = { 0, 0, 0, 1 };
static const XColor xColor_White = { 1, 1, 1, 1 };
static const XColor xColor_Gray = { 0.5f, 0.5f, 0.5f, 1 };
static const XColor xColor_TransparentBlack = { 0, 0, 0, 0 };

static const XColorBytes xColorBytes_Red = { 0xFF, 0x00, 0x00, 0xFF };
static const XColorBytes xColorBytes_Green = { 0x00, 0xFF, 0x00, 0xFF };
static const XColorBytes xColorBytes_Blue = { 0x00, 0x00, 0xFF, 0xFF };
static const XColorBytes xColorBytes_Black = { 0x00, 0x00, 0x00, 0xFF };
static const XColorBytes xColorBytes_White = { 0xFF, 0xFF, 0xFF, 0xFF };
static const XColorBytes xColorBytes_Gray = { 0x7F, 0x7F, 0x7F, 0xFF };
static const XColorBytes xColorBytes_TransparentBlack = { 0xFF, 0xFF, 0xFF, 0xFF };

static inline XColor xColor(float r, float g, float b, float a)
{
	XColor color;
	color.red = r;
	color.green = g;
	color.blue = b;
	color.alpha = a;
	return color;
}

static inline XColorBytes xColorBytes(float r, float g, float b, float a)
{
	XColorBytes color;
	color.red = xSaturate(r) * 0xFF;
	color.green = xSaturate(g) * 0xFF;
	color.blue = xSaturate(b) * 0xFF;
	color.alpha = xSaturate(a) * 0xFF;
	return color;
}

static inline XColorBytes xPackColor(XColor *c)
{
	XColorBytes color;
	color.red = xSaturate(c->red) * 0xFF;
	color.green = xSaturate(c->green) * 0xFF;
	color.blue = xSaturate(c->blue) * 0xFF;
	color.alpha = xSaturate(c->alpha) * 0xFF;
	return color;
}

typedef struct {
	XColor diffuse;
	XColor ambient;
	XColor specular;
	float shininess;	
} XMaterial;

void xglSetMaterial(XMaterial *mat);
XMaterial xglGetDefaultMaterial();

BOOL xCheckExtensionSupported(const char *extensionName);



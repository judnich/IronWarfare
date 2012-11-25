// Copyright © 2010 John Judnich. All rights reserved.

#import "XGL.h"


GLuint boundIndexBuffer = 0;
GLuint boundVertexBuffer = 0;
GLuint boundTexture0 = 0;
GLuint boundTexture1 = 0;


BOOL xglCheckBindMesh(GLuint glVertexBuff, GLuint glIndexBuff)
{
	if (glVertexBuff == boundVertexBuffer && glIndexBuff == boundIndexBuffer)
		return NO;
	boundVertexBuffer = glVertexBuff;
	boundIndexBuffer = glIndexBuff;
	return YES;
}

BOOL xglCheckBindTextures(GLuint glTexture0, GLuint glTexture1)
{
	if (glTexture0 == boundTexture0 && glTexture1 == boundTexture1)
		return NO;
	boundTexture0 = glTexture0;
	boundTexture1 = glTexture1;
	return YES;
}

BOOL xglCheckBindTexture0(GLuint glTexture)
{
	if (glTexture == boundTexture0)
		return NO;
	boundTexture0 = glTexture;
	return YES;
}

BOOL xglCheckBindTexture1(GLuint glTexture)
{
	if (glTexture == boundTexture1)
		return NO;
	boundTexture1 = glTexture;
	return YES;	
}


void xglNotifyMeshBindingsChanged()
{
	boundIndexBuffer = -1;
	boundVertexBuffer = -1;
}

void xglNotifyTextureBindingsChanged()
{
	boundTexture0 = -1;
	boundTexture1 = -1;
}

void xglSetMaterial(XMaterial *mat)
{
	glMaterialfv(GL_FRONT_AND_BACK, GL_DIFFUSE, (float*)&mat->diffuse);
	glMaterialfv(GL_FRONT_AND_BACK, GL_AMBIENT, (float*)&mat->ambient);
	glMaterialfv(GL_FRONT_AND_BACK, GL_SPECULAR, (float*)&mat->specular);
	glMaterialf(GL_FRONT_AND_BACK, GL_SHININESS, mat->shininess);
}

XMaterial xglGetDefaultMaterial()
{
	XMaterial mat;
	mat.diffuse.red = 0.8; mat.diffuse.green = 0.8; mat.diffuse.blue = 0.8; mat.diffuse.alpha = 1;
	mat.ambient.red = 0.2; mat.ambient.green = 0.2; mat.ambient.blue = 0.2; mat.ambient.alpha = 1;
	mat.specular.red = 0; mat.specular.green = 0; mat.specular.blue = 0; mat.specular.alpha = 1;
	mat.shininess = 0;
	return mat;
}


BOOL xCheckExtensionSupported(const char *extensionName)
{
	char extensionBuff[128];
	int count = 0;
	const char *extensionsList = (const char *)glGetString(GL_EXTENSIONS);
	char ch = 0;
	while ((ch = *extensionsList++) != '\0') {
		if (ch != ' ') {
			extensionBuff[count++] = ch;
		} else {
			extensionBuff[count++] = '\0';
			if (strcmp(extensionName, extensionBuff) == 0) {
				return YES;
			}
			count = 0;
		}
	}
	extensionBuff[count++] = '\0';
	if (strcmp(extensionName, extensionBuff) == 0) {
		return YES;
	}
	return NO;
}


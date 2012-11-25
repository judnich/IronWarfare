// Copyright © 2010 John Judnich. All rights reserved.

#import "X2D.h"
#import "XGL.h"


XIntRect viewPort;

void x2D_begin()
{
	glMatrixMode(GL_PROJECTION);
	glPushMatrix();
	glLoadIdentity();
	
	glOrthof(0, 320, 0, 480, -1, 1);
	glMatrixMode(GL_MODELVIEW);
	glPushMatrix();
	glLoadIdentity();
	
	glDisable(GL_LIGHTING);
	glDisable(GL_CULL_FACE);
	glDepthMask(FALSE);
	glDepthFunc(GL_ALWAYS);
	
	XMaterial mat;
	mat.ambient.red = 1; mat.ambient.green = 1; mat.ambient.blue = 1; mat.ambient.alpha = 1;
	mat.specular.red = 0; mat.specular.green = 0; mat.specular.blue = 0; mat.specular.alpha = 0;
	mat.diffuse = mat.specular;
	
	glDisable(GL_FOG);
	glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
	glBindBuffer(GL_ARRAY_BUFFER, 0);

	xglNotifyTextureBindingsChanged();
	xglNotifyMeshBindingsChanged();
	x2D_setTexture(nil);
	x2D_disableTransparency();
}

void x2D_end()
{
	glDisableClientState(GL_COLOR_ARRAY);

	glMatrixMode(GL_PROJECTION);
	glPopMatrix();   
	glMatrixMode(GL_MODELVIEW);
	glPopMatrix();	
	
	glEnable(GL_LIGHTING);
	glEnable(GL_CULL_FACE);
	glDepthMask(TRUE);
	glDepthFunc(GL_LESS);
	
	glEnable(GL_FOG);
	xglNotifyTextureBindingsChanged();
	xglNotifyMeshBindingsChanged();
}

void x2D_enableTransparency()
{
	glEnable(GL_BLEND);
	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
}

void x2D_disableTransparency()
{
	glDisable(GL_BLEND);
}

void x2D_setTexture(XTexture *texture)
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
}

static const unsigned char texCoords[] = {
	0,0, 1,0,
	0,1, 1,1,
};

void x2D_drawRect(XIntRect *area)
{
	// position
	float positions[4*2];
	positions[0*2+1] = 480-area->left; positions[0*2] = 320-area->top;
	positions[1*2+1] = 480-area->right; positions[1*2] = 320-area->top;
	positions[2*2+1] = 480-area->left; positions[2*2] = 320-area->bottom;
	positions[3*2+1] = 480-area->right; positions[3*2] = 320-area->bottom;
	
	// render
	glVertexPointer(2, GL_FLOAT, 0, positions);
	glEnableClientState(GL_VERTEX_ARRAY);
	glTexCoordPointer(2, GL_BYTE, 0, texCoords);
	glEnableClientState(GL_TEXTURE_COORD_ARRAY);
	glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
}

void x2D_drawRectColored(XIntRect *area, XColor *color)
{
	// position
	float positions[4*2];
	positions[0*2+1] = 480-area->left; positions[0*2] = 320-area->top;
	positions[1*2+1] = 480-area->right; positions[1*2] = 320-area->top;
	positions[2*2+1] = 480-area->left; positions[2*2] = 320-area->bottom;
	positions[3*2+1] = 480-area->right; positions[3*2] = 320-area->bottom;
	
	// color
	XColorBytes colors[4];
	XColorBytes c = xPackColor(color);
	colors[0] = c;
	colors[1] = c;
	colors[2] = c;
	colors[3] = c;
	
	// render
	glVertexPointer(2, GL_FLOAT, 0, positions);
	glEnableClientState(GL_VERTEX_ARRAY);
	glTexCoordPointer(2, GL_BYTE, 0, texCoords);
	glEnableClientState(GL_TEXTURE_COORD_ARRAY);
	glColorPointer(4, GL_UNSIGNED_BYTE, 0, colors);
	glEnableClientState(GL_COLOR_ARRAY);
	glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
	glDisableClientState(GL_COLOR_ARRAY);
}

void x2D_drawRectRotated(XIntRect *area, XAngle rotation)
{
	// position
	float positions[4*2];
	positions[0*2+1] = 480-area->left; positions[0*2] = 320-area->top;
	positions[1*2+1] = 480-area->right; positions[1*2] = 320-area->top;
	positions[2*2+1] = 480-area->left; positions[2*2] = 320-area->bottom;
	positions[3*2+1] = 480-area->right; positions[3*2] = 320-area->bottom;
	
	// rotate
	XScalar centerX = (positions[0*2+1] + positions[1*2+1]) * 0.5f;
	XScalar centerY = (positions[0*2] + positions[2*2]) * 0.5f;
	XScalar cos = xCos(rotation);
	XScalar sin = xSin(rotation);
	for (int i = 0; i < 4; ++i) {
		XScalar y = positions[i*2] - centerY;
		XScalar x = positions[i*2+1] - centerX;
		positions[i*2] = (sin * x + cos * y) + centerY;
		positions[i*2+1] = (cos * x - sin * y) + centerX;
	}
	
	// render
	glVertexPointer(2, GL_FLOAT, 0, positions);
	glEnableClientState(GL_VERTEX_ARRAY);
	glTexCoordPointer(2, GL_BYTE, 0, texCoords);
	glEnableClientState(GL_TEXTURE_COORD_ARRAY);
	glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
}

void x2D_drawRectColoredRotated(XIntRect *area, XColor *color, XAngle rotation)
{
	// position
	float positions[4*2];
	positions[0*2+1] = 480-area->left; positions[0*2] = 320-area->top;
	positions[1*2+1] = 480-area->right; positions[1*2] = 320-area->top;
	positions[2*2+1] = 480-area->left; positions[2*2] = 320-area->bottom;
	positions[3*2+1] = 480-area->right; positions[3*2] = 320-area->bottom;

	// rotate
	XScalar centerX = (positions[0*2+1] + positions[1*2+1]) * 0.5f;
	XScalar centerY = (positions[0*2] + positions[2*2]) * 0.5f;
	XScalar cos = xCos(rotation);
	XScalar sin = xSin(rotation);
	for (int i = 0; i < 4; ++i) {
		XScalar y = positions[i*2] - centerY;
		XScalar x = positions[i*2+1] - centerX;
		positions[i*2] = (sin * x + cos * y) + centerY;
		positions[i*2+1] = (cos * x - sin * y) + centerX;
	}
	
	// color
	XColorBytes colors[4];
	XColorBytes c = xPackColor(color);
	colors[0] = c;
	colors[1] = c;
	colors[2] = c;
	colors[3] = c;
	
	// render
	glVertexPointer(2, GL_FLOAT, 0, positions);
	glEnableClientState(GL_VERTEX_ARRAY);
	glTexCoordPointer(2, GL_BYTE, 0, texCoords);
	glEnableClientState(GL_TEXTURE_COORD_ARRAY);
	glColorPointer(4, GL_UNSIGNED_BYTE, 0, colors);
	glEnableClientState(GL_COLOR_ARRAY);
	glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
	glDisableClientState(GL_COLOR_ARRAY);
}


void x2D_drawRectCropped(XIntRect *area, XScalarRect *region)
{
	XScalar width = area->right - area->left;
	XScalar height = area->bottom - area->top;
	
	XScalarRect area2;
	area2.left = area->left + width * region->left;
	area2.right = area->left + width * region->right;
	area2.top = area->top + height * region->top;
	area2.bottom = area->top + height * region->bottom;
	
	// position
	float positions[4*2];
	positions[0*2+1] = 480-area2.left; positions[0*2] = 320-area2.top;
	positions[1*2+1] = 480-area2.right; positions[1*2] = 320-area2.top;
	positions[2*2+1] = 480-area2.left; positions[2*2] = 320-area2.bottom;
	positions[3*2+1] = 480-area2.right; positions[3*2] = 320-area2.bottom;

	// uvs
	float uvs[4*2];
	uvs[0*2] = region->left; uvs[0*2+1] = region->top;
	uvs[1*2] = region->right; uvs[1*2+1] = region->top;
	uvs[2*2] = region->left; uvs[2*2+1] = region->bottom;
	uvs[3*2] = region->right; uvs[3*2+1] = region->bottom;
	
	// render
	glVertexPointer(2, GL_FLOAT, 0, positions);
	glEnableClientState(GL_VERTEX_ARRAY);
	glTexCoordPointer(2, GL_FLOAT, 0, uvs);
	glEnableClientState(GL_TEXTURE_COORD_ARRAY);
	glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
}

void x2D_drawRectCroppedColored(XIntRect *area, XScalarRect *region, XColor *color)
{
	XScalar width = area->right - area->left;
	XScalar height = area->bottom - area->top;
	
	XScalarRect area2;
	area2.left = area->left + width * region->left;
	area2.right = area->left + width * region->right;
	area2.top = area->top + height * region->top;
	area2.bottom = area->top + height * region->bottom;
	
	// position
	float positions[4*2];
	positions[0*2+1] = 480-area2.left; positions[0*2] = 320-area2.top;
	positions[1*2+1] = 480-area2.right; positions[1*2] = 320-area2.top;
	positions[2*2+1] = 480-area2.left; positions[2*2] = 320-area2.bottom;
	positions[3*2+1] = 480-area2.right; positions[3*2] = 320-area2.bottom;
	
	// uvs
	float uvs[4*2];
	uvs[0*2] = region->left; uvs[0*2+1] = region->top;
	uvs[1*2] = region->right; uvs[1*2+1] = region->top;
	uvs[2*2] = region->left; uvs[2*2+1] = region->bottom;
	uvs[3*2] = region->right; uvs[3*2+1] = region->bottom;
	
	// color
	XColorBytes colors[4];
	XColorBytes c = xPackColor(color);
	colors[0] = c;
	colors[1] = c;
	colors[2] = c;
	colors[3] = c;
	
	// render
	glVertexPointer(2, GL_FLOAT, 0, positions);
	glEnableClientState(GL_VERTEX_ARRAY);
	glTexCoordPointer(2, GL_FLOAT, 0, uvs);
	glEnableClientState(GL_TEXTURE_COORD_ARRAY);
	glColorPointer(4, GL_UNSIGNED_BYTE, 0, colors);
	glEnableClientState(GL_COLOR_ARRAY);
	glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
	glDisableClientState(GL_COLOR_ARRAY);
}



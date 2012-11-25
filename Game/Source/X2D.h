// Copyright © 2010 John Judnich. All rights reserved.

#import "XMath.h"
#import "XGL.h"
#import "XTexture.h"


void x2D_begin();
void x2D_end();

void x2D_enableTransparency();
void x2D_disableTransparency();

void x2D_setTexture(XTexture *texture);

void x2D_drawRect(XIntRect *area);
void x2D_drawRectColored(XIntRect *area, XColor *color);
void x2D_drawRectRotated(XIntRect *area, XAngle rotation);
void x2D_drawRectColoredRotated(XIntRect *area, XColor *color, XAngle rotation);

void x2D_drawRectCropped(XIntRect *area, XScalarRect *region);
void x2D_drawRectCroppedColored(XIntRect *area, XScalarRect *region, XColor *color);


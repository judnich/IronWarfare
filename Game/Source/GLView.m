#import "GLView.h"


@interface GLView (private)

-(id)initGLES;
-(BOOL)createFramebuffer;
-(void)destroyFramebuffer;

@end


@implementation GLView

@synthesize backingWidth, backingHeight;

// view must be backed by a layer that is capable of OpenGL ES rendering.
+(Class)layerClass
{
	return [CAEAGLLayer class];
}

// when created via code, initWithFrame is called to init
-(id)initWithFrame:(CGRect)frame
{
	if ((self = [super initWithFrame:frame])) {
		self = [self initGLES];
	}
	return self;
}

// when stored in nib file, initWithCoder is called to init
-(id)initWithCoder:(NSCoder*)coder
{
	if ((self = [super initWithCoder:coder])) {
		self = [self initGLES];
	}	
	return self;
}

-(id)initGLES
{
	self.exclusiveTouch = NO;
	self.multipleTouchEnabled = YES;
	
	// get backing layer
	CAEAGLLayer *eaglLayer = (CAEAGLLayer*)self.layer;
	
	// enable retina resolution
	if ([self respondsToSelector:@selector(setContentScaleFactor:)]) {
		self.contentScaleFactor = [[UIScreen mainScreen] scale];
    }
	
	// configure so it's opaque, and does not retain the contents of the backbuffer when displayed, and uses RGBA8888 color.
	eaglLayer.opaque = YES;
	eaglLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:
									[NSNumber numberWithBool:FALSE], kEAGLDrawablePropertyRetainedBacking,
									kEAGLColorFormatRGBA8, kEAGLDrawablePropertyColorFormat,
									nil];
	
	// create EAGLContext, and if successful make it current and create the framebuffer.
	context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES1];
	if (!context || ![EAGLContext setCurrentContext:context] || ![self createFramebuffer]) {
		[self release];
		return nil;
	}
	
	return self;
}

-(void)dealloc
{
	@synchronized(self) {
		[self destroyFramebuffer];
		[self unloadContent];
		
		if ([EAGLContext currentContext] == context) {
			[EAGLContext setCurrentContext:nil];
		}
		
		[context release];
		context = nil;
	}	
	[super dealloc];
}

// if view is resized
-(void)layoutSubviews
{
	/*@synchronized(self) {
		[self destroyFramebuffer];
		[self createFramebuffer];
		[self renderFrame];
	}*/
}

-(BOOL)createFramebuffer
{
	[EAGLContext setCurrentContext:context];

	// generate IDs for a framebuffer object and a color renderbuffer
	glGenFramebuffersOES(1, &viewFramebuffer);
	glGenRenderbuffersOES(1, &viewRenderbuffer);
	
	glBindFramebufferOES(GL_FRAMEBUFFER_OES, viewFramebuffer);
	glBindRenderbufferOES(GL_RENDERBUFFER_OES, viewRenderbuffer);
	// this call associates the storage for the current render buffer with the EAGLDrawable (the CAEAGLLayer)
	// allowing to draw into a buffer that will later be rendered to screen whereever the layer is (which corresponds
	// with the view).
	[context renderbufferStorage:GL_RENDERBUFFER_OES fromDrawable:(id<EAGLDrawable>)self.layer];
	glFramebufferRenderbufferOES(GL_FRAMEBUFFER_OES, GL_COLOR_ATTACHMENT0_OES, GL_RENDERBUFFER_OES, viewRenderbuffer);
	
	glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_WIDTH_OES, &backingWidth);
	glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_HEIGHT_OES, &backingHeight);
	
	// for this sample, we also need a depth buffer, so we'll create and attach one via another renderbuffer.
	glGenRenderbuffersOES(1, &depthRenderbuffer);
	glBindRenderbufferOES(GL_RENDERBUFFER_OES, depthRenderbuffer);
	glRenderbufferStorageOES(GL_RENDERBUFFER_OES, GL_DEPTH_COMPONENT16_OES, backingWidth, backingHeight);
	glFramebufferRenderbufferOES(GL_FRAMEBUFFER_OES, GL_DEPTH_ATTACHMENT_OES, GL_RENDERBUFFER_OES, depthRenderbuffer);

	if (glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES) != GL_FRAMEBUFFER_COMPLETE_OES) {
		NSLog(@"Failed to generate complete framebuffer object %x", glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES));
		[NSException raise:@"Error creating frame buffer!" format:@"Failed to generate complete framebuffer object %x", glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES)];
		return NO;
	}
	
	return YES;
}

-(void)destroyFramebuffer
{
	[EAGLContext setCurrentContext:context];

	glDeleteFramebuffersOES(1, &viewFramebuffer);
	viewFramebuffer = 0;
	glDeleteRenderbuffersOES(1, &viewRenderbuffer);
	viewRenderbuffer = 0;
	
	if (depthRenderbuffer) {
		glDeleteRenderbuffersOES(1, &depthRenderbuffer);
		depthRenderbuffer = 0;
	}
}

-(void)setDelegate:(id<GLViewDelegate>)d
{
	@synchronized(self) {
		if (d != delegate) {
			delegate = d;
		}
	}
}

-(id<GLViewDelegate>)delegate
{
	return delegate;
}

-(void)loadContent
{
	@synchronized(self) {
		[delegate loadContent:self];
	}
}

-(void)unloadContent
{
	@synchronized(self) {
		[delegate unloadContent:self];
	}
}

-(void)renderFrame:(XGameTime)gameTime
{	
	[EAGLContext setCurrentContext:context];
	glBindFramebufferOES(GL_FRAMEBUFFER_OES, viewFramebuffer);
	
	[delegate renderFrame:gameTime];
	glBindRenderbufferOES(GL_RENDERBUFFER_OES, viewRenderbuffer);
	[context presentRenderbuffer:GL_RENDERBUFFER_OES];
}

-(void)notifyLowMemory
{
	//@synchronized(self) {
		if ([delegate respondsToSelector:@selector(notifyLowMemory)])
			[delegate notifyLowMemory];
	//}
}

-(void)touchesBegan:(NSSet*)touches withEvent:(UIEvent*)event
{
	[delegate touchesBegan:touches withEvent:event view:self];
}

-(void)touchesMoved:(NSSet*)touches withEvent:(UIEvent*)event
{
	[delegate touchesMoved:touches withEvent:event view:self];
}

-(void)touchesEnded:(NSSet*)touches withEvent:(UIEvent*)event
{
	[delegate touchesEnded:touches withEvent:event view:self];
}

-(void)touchesCancelled:(NSSet*)touches withEvent:(UIEvent*)event
{
	[delegate touchesCancelled:touches withEvent:event view:self];
}

@end

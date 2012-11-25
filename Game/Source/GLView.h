#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <OpenGLES/EAGLDrawable.h>
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES1/gl.h>
#import <OpenGLES/ES1/glext.h>
#import "XTime.h"

@protocol GLViewDelegate;


// GLView is an OpenGL rendered view for games. When a delegate is set, you can call
// renderFrame as often as you want to update and render the view using the delegate
// (just be sure setRenderingContext is called before call(s) to renderFrame if the context
// might not be set correctly). The GLView class handles setting up the backbuffers, etc.
// and presenting the contents of each rendered frame to the screen.
@interface GLView : UIView
{
	GLint backingWidth;
	GLint backingHeight;	
	EAGLContext *context;
	
	GLuint viewRenderbuffer, viewFramebuffer;
	GLuint depthRenderbuffer;
	
	id<GLViewDelegate> delegate;
}

@property(nonatomic, assign) id<GLViewDelegate> delegate;
@property(readonly) int backingWidth, backingHeight;

-(void)loadContent;
-(void)unloadContent;
-(void)renderFrame:(XGameTime)gameTime;

-(void)notifyLowMemory;

@end


// The game's main class should be a GLViewDelegate - it provies all the callbacks it
// should need - loadContent to initially load the game, renderFrame which is called every
// frame to update/render the game, and unloadContent to unload the game before closing.
@protocol GLViewDelegate<NSObject>

-(void)loadContent:(GLView*)view;
-(void)unloadContent:(GLView*)view;
-(void)renderFrame:(XGameTime)gameTime;

-(void)touchesBegan:(NSSet*)touches withEvent:(UIEvent*)event view:(GLView*)view;
-(void)touchesMoved:(NSSet*)touches withEvent:(UIEvent*)event view:(GLView*)view;
-(void)touchesEnded:(NSSet*)touches withEvent:(UIEvent*)event view:(GLView*)view;
-(void)touchesCancelled:(NSSet*)touches withEvent:(UIEvent*)event view:(GLView*)view;

@optional
-(void)notifyLowMemory;

@end


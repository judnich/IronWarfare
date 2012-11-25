// Copyright © 2010 John Judnich. All rights reserved.

#import "XScene.h"
#import "XNode.h"
#import "XCamera.h"
#import "XGL.h"
#import "AppDelegate.h"

#define FLOAT_EPSILON 0.000001f

const GLfloat lightDirection[] = {0.0, 0.707, -0.707, 0.0};


@interface XScene (private)

-(void)addNode:(XNode*)entity;
-(void)removeNode:(XNode*)entity;

@end


@implementation XScene

@synthesize camera, fogRange;

-(id)init
{
	if ((self = [super init])) {
		renderGroupArraySize = 32;
		renderGroupArray = malloc(sizeof(XRenderGroup) * renderGroupArraySize);
		renderGroupCount = 0;
		
		glViewport(0, 0, screenHeight, screenWidth);
		glEnable(GL_CULL_FACE);
		glCullFace(GL_BACK);
		glShadeModel(GL_SMOOTH);
		glEnable(GL_DEPTH_TEST);

		const GLfloat fullWhite[] = {1.0, 1.0, 1.0, 1.0};
		glEnable(GL_LIGHTING);
		glEnable(GL_LIGHT0);
		glLightfv(GL_LIGHT0, GL_DIFFUSE, fullWhite);
		glLightfv(GL_LIGHT0, GL_SPECULAR, fullWhite);
		glLightfv(GL_LIGHT0, GL_AMBIENT, fullWhite);
		
		const GLfloat fogColor[] = {0.25, 0.5, 1.0, 1.0};
		glEnable(GL_FOG);
		glFogx(GL_FOG_MODE, GL_LINEAR);
		glFogf(GL_FOG_START, 0.0);
		glFogfv(GL_FOG_COLOR, fogColor);
		fogRange = 1000;
		
		glTexEnvf(GL_TEXTURE_FILTER_CONTROL_EXT, GL_TEXTURE_LOD_BIAS_EXT, -0.5f);

		XGL_ASSERT; //catch OpenGL errors
	}
	return self;
}

-(void)dealloc
{
	NSAutoreleasePool *autoreleasePool = [[NSAutoreleasePool alloc] init];
	self.camera = nil;
	
	if (renderGroupCount > 0) {
		NSLog(@"-- XScene Warning --");
		NSLog(@"Warning: XScene was released while it contained %d render groups:", renderGroupCount);
		for (int i = 0; i < renderGroupCount; ++i) {
			XRenderGroup *group = &renderGroupArray[i];
			NSLog(@"\"%@\" (contains %d nodes)", group->groupName, group->nodes.count);
			[group->groupName release];
			[group->nodes release];
		}
		NSLog(@"------------------------");
	}
	free(renderGroupArray);
	
	[autoreleasePool release];
	XGL_ASSERT; //catch OpenGL errors
	[super dealloc];
}

-(void)addNode:(XNode*)entity
{
	NSString *groupID = [entity getRenderGroupID];
	assert(groupID);
	
	// binary search for render group in list
	int start = 0, end = renderGroupCount-1, middle = 0;
	XRenderGroup *group = nil;
	while (end >= start) {
		middle = (start + end) / 2;
		XRenderGroup *groupDat = &renderGroupArray[middle];
		NSComparisonResult cmp = [groupID compare:groupDat->groupName];
		if (cmp == NSOrderedAscending)
			end = middle-1;
		else if (cmp == NSOrderedDescending)
			start = middle+1;
		else {
			group = groupDat;
			break;
		}
	}
	// if not found, add render group to list
	if (group == nil) {
		NSComparisonResult cmp = [groupID compare:renderGroupArray[middle].groupName];
		assert(cmp != NSOrderedSame);
		int insertBeforeIndex = 0;
		if (cmp == NSOrderedAscending) {
			// groupID < closest group - insert before
			insertBeforeIndex = middle;
		}
		else {
			// groupID > middle closest - insert after
			insertBeforeIndex = middle+1;
		}
		if (renderGroupCount == 0)
			insertBeforeIndex = 0;
		// shift array to make space for insertion
		++renderGroupCount;
		if (renderGroupCount > renderGroupArraySize) {
			// resize array
			int newSize = renderGroupArraySize + (renderGroupArraySize/2) + 1;
			XRenderGroup *newArray = malloc(sizeof(XRenderGroup) * newSize);
			memcpy(newArray, renderGroupArray, renderGroupArraySize);
			free(renderGroupArray);
			renderGroupArray = newArray;
			renderGroupArraySize = newSize;			
		}
		for (int i = renderGroupCount-1; i > insertBeforeIndex; --i) {
			renderGroupArray[i] = renderGroupArray[i-1];
		}
		// insert group
		XRenderGroup newGroup;
		newGroup.groupName = groupID;
		[newGroup.groupName retain];
		newGroup.nodes = [[NSMutableSet alloc] init];
		renderGroupArray[insertBeforeIndex] = newGroup;
		group = &newGroup;
	}
	
	NSMutableSet *groupNodes = group->nodes;
	[groupNodes addObject:entity];
}

-(void)removeNode:(XNode*)entity
{
	NSString *groupID = [entity getRenderGroupID];
	assert(groupID);
	
	// binary search for render group in list
	int start = 0, end = renderGroupCount-1, middle = 0;
	XRenderGroup *group = nil;
	while (end >= start) {
		middle = (start + end) / 2;
		XRenderGroup *groupDat = &renderGroupArray[middle];
		NSComparisonResult cmp = [groupID compare:groupDat->groupName];
		if (cmp == NSOrderedAscending)
			end = middle-1;
		else if (cmp == NSOrderedDescending)
			start = middle+1;
		else {
			group = groupDat;
			break;
		}
	}
	// remove node from group
	if (group != nil) {
		NSMutableSet *groupNodes = group->nodes;
		[groupNodes removeObject:entity];
		// remove group if empty
		if (groupNodes.count == 0) {
			assert(&renderGroupArray[middle] == group);
			[group->nodes release];
			[group->groupName release];
			for (int i = middle; i < renderGroupCount-1; ++i) {
				renderGroupArray[i] = renderGroupArray[i+1];
			}
			--renderGroupCount;
		}
	}
	else {
		NSLog(@"[XScene removeNode:] error: Node not found.");
#ifdef DEBUG
		[NSException raise:@"[XScene removeNode:] error" format:@"Node not found"];
#endif
	}
}

-(void)setCamera:(XCamera*)cam
{
	if (camera != cam) {
		[camera release];
		camera = cam;
		[camera retain];
	}
}

-(XCamera*)camera
{
	return camera;
}

-(void)render
{
	if (camera == nil) {
		NSLog(@"Cannot render scene until a camera is assigned!");
		return;
	}	

	// clear screen
	glClear(GL_DEPTH_BUFFER_BIT);
	
	// set fog distance to camera far plane
	glFogf(GL_FOG_END, fogRange);

	// set up camera view
	[camera frameUpdate];
	glMatrixMode(GL_PROJECTION);
	
	glLoadIdentity();
	glLoadMatrixf(xMatrix4ToArray(&camera->projMatrix));
	
	glMatrixMode(GL_MODELVIEW);
	glLoadIdentity();
	
	glRotatef(270.0f, 0.0f, 0.0f, 1.0f); //landscape mode
	//int width = 2048;
	//int height = 1536;
	//glTranslatef( width / 2, height / 2, 0);
	//glRotatef(-90, 0, 0, 1);
	//glTranslatef(-1 * (height / 2), -1 * (width / 2),0);
	
	glMultMatrixf(xMatrix4ToArray(&camera->viewMatrix));
	
	// render all objects, sorted by groups
	XMatrix4 rotMatrix;
	for (int i = 0; i < renderGroupCount; ++i) {
		NSMutableSet *groupNodes = renderGroupArray[i].nodes;
		// render all objects in group
		XNode *lastNode = nil;
		for (XNode *node in groupNodes) {
			// check visibility
			BOOL visible = NO;
			if (node.boundingRadius > FLOAT_EPSILON) {
				if ([camera isVisibleSphere:(node.globalPosition) radius:(node.boundingRadius)]) {
					if (node->useBoundingSphereOnly)
						visible = YES;
					else if ([camera isVisibleBox:(&node->boundingBox) boxOffset:(node.globalPosition) boxRotation:(node.globalRotation)])
						visible = YES;
				}
			}
			if (visible) {
				glPushMatrix(); //save view matrix
				
				// set up lighting
				glLightfv(GL_LIGHT0, GL_POSITION, lightDirection);
				const float emission[] = {0, 0, 0};
				glMaterialfv(GL_FRONT_AND_BACK, GL_EMISSION, emission);
				
				// load model matrix (global rotation * position) into GL_MODELVIEW
				XVector3 *globalPosition = node.globalPosition;
				glTranslatef(globalPosition->x, globalPosition->y, globalPosition->z);
				xBuildMatrix4FromMatrix3(&rotMatrix, node.globalRotation);
				glMultMatrixf(xMatrix4ToArray(&rotMatrix));
				
				// render object
				if (lastNode == nil)
					[node beginRenderGroup];
				[node render:camera];
				lastNode = node;
				
				glPopMatrix(); //restore view matrix
			}
		}
		
		// finalize group render
		[lastNode endRenderGroup];
	}
	
	// catch OpenGL errors
#ifdef DEBUG
	GLenum err = glGetError();
	if (err != GL_NO_ERROR) {
		switch (err) {
			case GL_INVALID_ENUM: [NSException raise:@"OpenGL Error!" format:@"OpenGL: Invalid enum"]; break;
			case GL_INVALID_VALUE: [NSException raise:@"OpenGL Error!" format:@"OpenGL: Invalid value"]; break;
			case GL_INVALID_OPERATION: [NSException raise:@"OpenGL Error!" format:@"OpenGL: Invalid operation"]; break;
			case GL_STACK_OVERFLOW: [NSException raise:@"OpenGL Error!" format:@"OpenGL: Stack overflow"]; break;
			case GL_STACK_UNDERFLOW: [NSException raise:@"OpenGL Error!" format:@"OpenGL: Stack underflow"]; break;
			case GL_OUT_OF_MEMORY: [NSException raise:@"OpenGL Error!" format:@"OpenGL: Out of memory"]; break;
		}
	}
#endif
}

@end

// Copyright © 2010 John Judnich. All rights reserved.

#import "XClutterSystem.h"
#import "XCamera.h"
#import "XTexture.h"
#import "XTerrain.h"
#import "XScript.h"
#import "XScene.h"


@interface XClutterSystem (private)

-(void)frameUpdate;

@end


@implementation XClutterBatch

@synthesize glVertexBuffer, instanceCount, vertexCount;

-(id)initWithSize:(int)quadCnt clutterInstances:(XClutterInstance*)instances clutterSystem:(XClutterSystem*)csys;
{
	if ((self = [super init])) {
		system = csys;
		
		boundingBox.min.x = -1000; boundingBox.min.y = -1000; boundingBox.min.z = -1000;
		boundingBox.max.x = 1000; boundingBox.max.y = 1000; boundingBox.max.z = 1000;
		[self notifyBoundsChanged];

		instanceArray = instances;
		instanceCount = quadCnt;
		
		indexCount = instanceCount * 6;
		{
			XClutterIndex *indexData = malloc(sizeof(XClutterIndex)*indexCount);
			XClutterIndex *ptr = indexData;
			for (GLushort i = 0; i < instanceCount; ++i) {
				GLushort o = i * 4;
				*ptr++ = 0+o; *ptr++ = 1+o; *ptr++ = 2+o;
				*ptr++ = 1+o; *ptr++ = 2+o; *ptr++ = 3+o;
			}
			glGenBuffers(1, &glIndexBuffer);
			glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, glIndexBuffer);
			glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(XClutterIndex)*indexCount, indexData, GL_STATIC_DRAW);
			glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
			free(indexData);
		}

		vertexCount = instanceCount * 4;
		{
			clutterVertexBuffer = malloc(sizeof(XClutterVertex) * vertexCount);
			glGenBuffers(1, &glVertexBuffer);
			glBindBuffer(GL_ARRAY_BUFFER, glVertexBuffer);
			glBufferData(GL_ARRAY_BUFFER, sizeof(XClutterVertex)*vertexCount, NULL, GL_DYNAMIC_DRAW);
			glBindBuffer(GL_ARRAY_BUFFER, 0);
		}
	}
	return self;
}

-(void)dealloc
{
	free(clutterVertexBuffer);
	glDeleteBuffers(1, &glIndexBuffer);
	glDeleteBuffers(1, &glVertexBuffer);
	[atlasTexture mediaRelease];
	[super dealloc];
}

-(void)setAtlasTexture:(XTexture*)texture
{
	[atlasTexture mediaRelease];
	atlasTexture = texture;
	[atlasTexture mediaRetain];
}

-(XTexture*)atlasTexture
{
	return atlasTexture;
}

-(XVector3*)globalPosition
{
	return (XVector3*)&xVector3_Zero;
}

-(XMatrix3*)globalRotation
{
	return (XMatrix3*)&xMatrix3_Identity;
}

-(NSString*)getRenderGroupID
{
	return @"8_clutter";
}

-(void)beginRenderGroup
{	
	glDisable(GL_LIGHTING);
	glDisable(GL_CULL_FACE);
	glDisableClientState(GL_NORMAL_ARRAY);

	if (xglCheckBindTextures(atlasTexture.glTexture, 0)) {
		glActiveTexture(GL_TEXTURE0);
		glBindTexture(GL_TEXTURE_2D, atlasTexture.glTexture);
		glEnable(GL_TEXTURE_2D);
	}

	//glAlphaFunc(GL_GREATER, 0.75f);
	//glEnable(GL_ALPHA_TEST);
	glEnable(GL_BLEND);
	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
	glDepthMask(FALSE);
}

-(void)endRenderGroup
{
	glActiveTexture(GL_TEXTURE0);
	glBindTexture(GL_TEXTURE_2D, 0);
	
	glDisableClientState(GL_COLOR_ARRAY);
	glBindBuffer(GL_ARRAY_BUFFER, 0);
	glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
	
	//glDisable(GL_ALPHA_TEST);
	glDisable(GL_BLEND);
	glDepthMask(TRUE);

	glEnable(GL_LIGHTING);
	glEnable(GL_CULL_FACE);
}

-(void)render:(XCamera*)cam
{
	[system frameUpdate];
	
	// calculate vectors to face clutter billboards towards camera
	XVector3 rightVector = xCrossProduct_Vec3(&cam->lookVector, &cam->upVector);
	XVector3 upVector = xCrossProduct_Vec3(&rightVector, &cam->lookVector);
	xNormalize_Vec3(&rightVector);
	xNormalize_Vec3(&upVector);
	
	// generate billboard vertex data
	BOOL allInvisible = YES;
	XClutterVertex *clutterVertexPtr = clutterVertexBuffer;
	for (int i = 0; i < instanceCount; ++i) {
		XClutterInstance *instance = &instanceArray[i];
		
		if (!instance->inSync || !instance->visible) {
			// hidden for now
			for (int i = 0; i < 4; ++i) {
				clutterVertexPtr->position.x = 0; clutterVertexPtr->position.y = 0; clutterVertexPtr->position.z = 0;
				clutterVertexPtr->color.red = 0; clutterVertexPtr->color.green = 0; clutterVertexPtr->color.blue = 0; clutterVertexPtr->color.alpha = 0;
				clutterVertexPtr->u = 0; clutterVertexPtr->v = 0;
				++clutterVertexPtr;
			}
		} else {
			allInvisible = NO;
			
			// select image from atlas
			XScalarRect texRect;
			int typeID = instance->type->typeID;
			if (typeID == 0 || typeID == 2) {
				texRect.left = 0;
				texRect.right = 0.5f;
			} else {
				texRect.left = 0.5f;
				texRect.right = 1;
			}
			if (typeID == 0 || typeID == 1) {
				texRect.top = 0;
				texRect.bottom = 0.5f;
			} else {
				texRect.top = 0.5f;
				texRect.bottom = 1;
			}
			if (instance->size < 0) {
				float tmp = texRect.right;
				texRect.right = texRect.left;
				texRect.left = tmp;
			}
			
			// update and generate clutter vertexes
			XVector3 pos = instance->position;
			pos.y += (instance->type->yOffset) * instance->size;
			
			XVector2 dVec;
			dVec.x = pos.x - cam->origin.x;
			dVec.y = pos.z - cam->origin.z;
			XScalar camDist = xLength_Vec2(&dVec);
			XScalar fadeIn = xSaturate((camDist / instance->viewRange) - 0.5f) * 2;
			fadeIn = fadeIn * fadeIn;
			fadeIn = (1 - fadeIn) * 0.9f;
			
			XScalar scale = xAbs(instance->size);
			XAngle angle = 0;
			XColorBytes color; color.alpha = 255.0f * fadeIn;
			color.red = color.green = color.blue = (unsigned char)(instance->lightness * (float)0xFF);
			
			XScalar cos = xCos(angle) * scale * 0.5f;
			XScalar sin = xSin(angle) * scale * 0.5f;
			XScalar lx, ly;
			
			// top-left corner
			lx = cos*(-1) - sin*(1);
			ly = sin*(-1) + cos*(1);
			clutterVertexPtr->position.x = pos.x + rightVector.x * lx + upVector.x * ly;
			clutterVertexPtr->position.y = pos.y + rightVector.y * lx + upVector.y * ly;
			clutterVertexPtr->position.z = pos.z + rightVector.z * lx + upVector.z * ly;
			clutterVertexPtr->color = color;
			clutterVertexPtr->u = texRect.left;
			clutterVertexPtr->v = texRect.top;
			++clutterVertexPtr;
			
			// top-right corner
			lx = cos*(1) - sin*(1);
			ly = sin*(1) + cos*(1);
			clutterVertexPtr->position.x = pos.x + rightVector.x * lx + upVector.x * ly;
			clutterVertexPtr->position.y = pos.y + rightVector.y * lx + upVector.y * ly;
			clutterVertexPtr->position.z = pos.z + rightVector.z * lx + upVector.z * ly;
			clutterVertexPtr->color = color;
			clutterVertexPtr->u = texRect.right;
			clutterVertexPtr->v = texRect.top;
			++clutterVertexPtr;
			
			// bottom-left corner
			lx = cos*(-1) - sin*(-1);
			ly = sin*(-1) + cos*(-1);
			clutterVertexPtr->position.x = pos.x + rightVector.x * lx + upVector.x * ly;
			clutterVertexPtr->position.y = pos.y + rightVector.y * lx + upVector.y * ly;
			clutterVertexPtr->position.z = pos.z + rightVector.z * lx + upVector.z * ly;
			clutterVertexPtr->color = color;
			clutterVertexPtr->u = texRect.left;
			clutterVertexPtr->v = texRect.bottom;
			++clutterVertexPtr;
			
			// bottom-right corner
			lx = cos*(1) - sin*(-1);
			ly = sin*(1) + cos*(-1);
			clutterVertexPtr->position.x = pos.x + rightVector.x * lx + upVector.x * ly;
			clutterVertexPtr->position.y = pos.y + rightVector.y * lx + upVector.y * ly;
			clutterVertexPtr->position.z = pos.z + rightVector.z * lx + upVector.z * ly;
			clutterVertexPtr->color = color;
			clutterVertexPtr->u = texRect.right;
			clutterVertexPtr->v = texRect.bottom;
			++clutterVertexPtr;
		}
	}
	
	if (allInvisible)
		return;

	// upload to vertex buffer and render
	glBindBuffer(GL_ARRAY_BUFFER, glVertexBuffer);
	glBufferSubData(GL_ARRAY_BUFFER, 0, vertexCount*sizeof(XClutterVertex), clutterVertexBuffer); //upload data
	glEnableClientState(GL_VERTEX_ARRAY);
	glVertexPointer(3, GL_FLOAT, sizeof(XClutterVertex), (void*)offsetof(XClutterVertex,position));
	glEnableClientState(GL_TEXTURE_COORD_ARRAY);
	glTexCoordPointer(2, GL_FLOAT, sizeof(XClutterVertex), (void*)offsetof(XClutterVertex,u));
	glEnableClientState(GL_COLOR_ARRAY);
	glColorPointer(4, GL_UNSIGNED_BYTE, sizeof(XClutterVertex), (void*)offsetof(XClutterVertex,color));
	
	glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, glIndexBuffer);
	
	// draw
	glDrawElements(GL_TRIANGLES, indexCount, GL_UNSIGNED_SHORT, (void*)0);
	
	xglNotifyMeshBindingsChanged();
}

@end


@implementation XClutterSystem

@synthesize terrain;

-(id)initWithSize:(int)quadCnt
{
	if ((self = [super init])) {
		instanceCount = quadCnt;
		instanceArray = malloc(sizeof(XClutterInstance) * instanceCount);
		for (int i = 0; i < instanceCount; ++i) {
			instanceArray[i].inSync = NO;
			instanceArray[i].visible = NO;
		}
		for (int i = 0; i < 4; ++i)
			clutterTypes[i].typeID = i;
		
		minHeight = 0; maxHeight = 1;
		
		batch = [[XClutterBatch alloc] initWithSize:instanceCount clutterInstances:instanceArray clutterSystem:self];
	}
	return self;
}

-(void)dealloc
{
	batch.scene = nil;
	batch.atlasTexture = nil;
	[batch release];
	free(instanceArray);
	[terrain release];
	[super dealloc];
}

-(void)setScene:(XScene*)scene
{
	batch.scene = scene;
}

-(XScene*)scene
{
	return batch.scene;
}

-(void)setAtlasTexture:(XTexture*)texture
{
	batch.atlasTexture = texture;
}

-(XTexture*)atlasTexture
{
	return batch.atlasTexture;
}

-(void)loadClutterTypesFromScript:(XScriptNode*)topNode
{
	int i = 0;
	minHeight = 0;
	maxHeight = 1;
	for (int j = 0; j < topNode.subnodeCount; ++j) {
		XScriptNode *node = [topNode getSubnodeByIndex:j];
		if ([node.name isEqualToString:@"height_clamp"]) {
			minHeight = [node getValueF:0];
			maxHeight = [node getValueF:1];
		}
		else if ([node.name isEqualToString:@"type"]) {
			XClutterType *type = &clutterTypes[i];
			type->typeID = i;
			XScriptNode *subNode = nil;
			
			subNode = [node getSubnodeByName:@"density"];
			if (subNode)
				type->density = [subNode getValueF:0] * 2.0f;
			else
				type->density = 1;
			
			subNode = [node getSubnodeByName:@"y_offset"];
			if (subNode)
				type->yOffset = [subNode getValueF:0];
			else
				type->yOffset = 0;
			
			subNode = [node getSubnodeByName:@"size"];
			if (subNode) {
				type->minSize = [subNode getValueF:0];
				type->maxSize = [subNode getValueF:1];
			}
			else {
				type->minSize = 1;
				type->maxSize = 1;
			}
			
			subNode = [node getSubnodeByName:@"lightness"];
			if (subNode) {
				type->minLightness = [subNode getValueF:0];
				type->maxLightness = [subNode getValueF:1];
			}
			else {
				type->minLightness = 1;
				type->maxLightness = 1;
			}
			
			subNode = [node getSubnodeByName:@"view_range"];
			if (subNode) {
				type->minViewRange = [subNode getValueF:0];
				type->maxViewRange = [subNode getValueF:1];
			}
			else {
				type->minViewRange = 100;
				type->maxViewRange = 100;
			}

			++i;
			if (i > 4) {
				NSLog(@"Clutter script warning: too many types (should be four)");
				break;
			}
		}
		else {
			NSLog(@"Clutter script warning: Clutter configuration node was not named 'type'");
		}
	}
	if (i < 3) {
		NSLog(@"Clutter script warning: Not enough clutter types defined (must be three)");
	}
	[self regenClutterTypes];
}

-(void)regenClutterTypes
{
	for (int i = 0; i < instanceCount; ++i)
		instanceArray[i].inSync = NO;
	totalDensity = 0;
	for (int i = 0; i < 4; ++i) {
		clutterTypes[i].typeID = i;
		totalDensity += clutterTypes[i].density;
	}
}

-(void)frameUpdate
{
	if (batch.scene == nil)
		return;
	XCamera *cam = batch.scene.camera;
	XVector3 camPos = cam->origin;
	
	for (int i = 0; i < instanceCount; ++i) {
		XClutterInstance *instance = &instanceArray[i];
		if (!instance->inSync) {
			// choose a random clutter type, biased by their densities
			float rand = xRangeRand(0, totalDensity);
			float tD = 0;
			XClutterType *clutterType = nil;
			for (int j = 0; j < 4; ++j) {
				tD += clutterTypes[j].density;
				if (rand <= tD) {
					clutterType = &clutterTypes[j];
					break;
				}
			}
			
			// misc. initialization
			instance->inSync = YES;
			instance->type = clutterType;
			instance->size = xRangeRand(clutterType->minSize, clutterType->maxSize);
			if (xRand() < 0.5f)
				instance->size = -instance->size; //negative size = mirrored UVs
			instance->viewRange = xRangeRand(clutterType->minViewRange, clutterType->maxViewRange);
			
			// random clustered position within the view range 
			XScalar distSq = 0;
			XScalar maxDistSq = instance->viewRange * instance->viewRange;
			BOOL cluster = NO;
			if (xRand() < 0.7f)
				cluster = YES;
			if (cluster) {
				XClutterInstance *clusterPoint = nil;
				for (int j = i-1; j >= 0; --j) {
					if (instanceArray[j].type == clutterType) {
						clusterPoint = &instanceArray[j];
						break;
					}
				}
				if (!clusterPoint)
					cluster = NO;
				else {
					int safetyCount = 0;
					do {
						instance->position.x = clusterPoint->position.x + xRangeRand(-instance->viewRange * 0.1f, instance->viewRange * 0.1f);
						instance->position.z = clusterPoint->position.z + xRangeRand(-instance->viewRange * 0.1f, instance->viewRange * 0.1f);
						XVector2 dVec;
						dVec.x = instance->position.x - camPos.x;
						dVec.y = instance->position.z - camPos.z;
						distSq = dVec.x * dVec.x + dVec.y * dVec.y;
						if (++safetyCount > 200) break;
					} while (distSq > maxDistSq);
				}
			}
			if (!cluster) {
				int safetyCount = 0;
				do {
					instance->position.x = xRangeRand(-instance->viewRange, instance->viewRange);
					instance->position.z = xRangeRand(-instance->viewRange, instance->viewRange);
					distSq = instance->position.x * instance->position.x + instance->position.z * instance->position.z;
					if (++safetyCount > 200) break;
				} while (distSq > maxDistSq);
				instance->position.x += camPos.x;
				instance->position.z += camPos.z;
			}
			instance->position.y = 0;
			XTerrainIntersection intersect = [terrain intersectTerrainVerticallyAt:&instance->position];
			instance->position.y = intersect.point.y;
			
			// color to specified variation, modulated by terrain light map
			float lightness = xRangeRand(clutterType->minLightness, clutterType->maxLightness);
			instance->lightness = lightness * xSaturate([terrain sampleTerrainLightmapAt:&instance->position] * 3);
		}
		else {
			// wrap clutter instances around viewing circle
			XVector2 dVec;
			dVec.x = instance->position.x - camPos.x;
			dVec.y = instance->position.z - camPos.z;
			XScalar dist = xNormalize_Vec2(&dVec);
			if (dist > instance->viewRange) {
				if (dist < instance->viewRange * 1.5f) {
					dist = 2 * instance->viewRange - dist;
					dVec.x = -dVec.x * dist;
					dVec.y = -dVec.y * dist;
					instance->position.x = camPos.x + dVec.x;
					instance->position.z = camPos.z + dVec.y;
					XTerrainIntersection intersect = [terrain intersectTerrainVerticallyAt:&instance->position];
					instance->position.y = intersect.point.y;
					float lightness = xRangeRand(instance->type->minLightness, instance->type->maxLightness);
					instance->lightness = lightness * [terrain sampleTerrainLightmapAt:&instance->position];
				} else {
					instance->inSync = NO;
				}
			}
		}
		XScalar relY = (instance->position.y - terrain->boundingBox.min.y) / (terrain->boundingBox.max.y - terrain->boundingBox.min.y);
		if (relY >= minHeight && relY <= maxHeight)
			instance->visible = YES;
		else
			instance->visible = NO;
	}
}

@end

// Copyright © 2010 John Judnich. All rights reserved.

#import "XParticleEffect.h"
#import "XScript.h"
#import "XTexture.h"


@implementation XParticleEffect

-(id)initWithFile:(NSString*)filename usingMedia:(XMediaGroup*)media
{
	if ((self = [super initWithFile:filename usingMedia:media])) {
		XScriptNode *script = [[XScriptNode alloc] initWithFile:filename];
		if (!script) {
			NSLog(@"Error loading particle effect: file not found.");
			return nil;
		}
		XScriptNode *root = [script getSubnodeByName:@"effect"];
		if (!root) {
			NSLog(@"Error loading particle effect: \"effect\" root definition not found.");
			[script release];
			return nil;
		}

		// load texture and blend mode
		NSString *path = [filename stringByDeletingLastPathComponent];
		NSString *textureFile = [[root getSubnodeByName:@"texture"] getValue:0];
		if (textureFile)
			texture = [XTexture mediaRetainFile:[path stringByAppendingPathComponent:textureFile] usingMedia:media];
		NSString *blendModeS = [[root getSubnodeByName:@"blend_mode"] getValue:0];
		if (blendModeS) {
			if ([blendModeS isEqualToString:@"alpha"])
				blendMode = XBlend_Alpha;
			else if ([blendModeS isEqualToString:@"additive"])
				blendMode = XBlend_Additive;
			else if ([blendModeS isEqualToString:@"modulative"])
				blendMode = XBlend_Modulative;
			else if ([blendModeS isEqualToString:@"opaque"] || [blendModeS isEqualToString:@"none"])
				blendMode = XBlend_None;
		}
		else blendMode = XBlend_Alpha;
		
		// get emission definitions and allocate an emission data array to store the parsed data
		NSArray *emissionNodes = [root subnodesWithName:@"emit"];
		numEmissions = emissionNodes.count;
		emissionArray = malloc(sizeof(XParticleEmissionData) * numEmissions);
		// reset all emissions data to defaults
		{
			XParticleEmissionData d;
			d.emitCount = 0;
			d.emitBox.min.x = 0; d.emitBox.min.y = 0; d.emitBox.min.z = 0;
			d.emitBox.max.x = 0; d.emitBox.max.y = 0; d.emitBox.max.z = 0;
			d.minVelocity.x = 0; d.minVelocity.y = 0; d.minVelocity.z = 0;
			d.maxVelocity.x = 0; d.maxVelocity.y = 0; d.maxVelocity.z = 0;
			d.minGravity = 0; d.maxGravity = 0;
			d.minAngle = -180; d.maxAngle = 180;
			d.minRotateSpeed = 0; d.maxRotateSpeed = 0;
			d.minScale = 1; d.maxScale = 1;
			d.minScaleSpeed = 0; d.maxScaleSpeed = 0;
			d.minColor.red = 0xFF; d.minColor.green = 0xFF; d.minColor.blue = 0xFF; d.minColor.alpha = 0xFF;
			d.maxColor.red = 0xFF; d.maxColor.green = 0xFF; d.maxColor.blue = 0xFF; d.maxColor.alpha = 0xFF;
			d.startAlpha = 1; d.endAlpha = 0;
			d.minLife = 3; d.maxLife = 3;
			for (int i = 0; i < numEmissions; ++i)
				emissionArray[i] = d;
		}
		
		// parse emissions
		int i = 0;
		totalParticlesToEmit = 0;
		for (XScriptNode *emissionNode in emissionNodes) {
			// parse emission definition
			XParticleEmissionData *emData = &emissionArray[i++];
			emData->emitCount = [emissionNode getValueI:0];
			assert(emData->emitCount > 0);
			// parse emission values
			for (XScriptNode *valNode in emissionNode.subnodes) {
				NSString *valName = valNode.name;
				if ([valName isEqualToString:@"min_pos"]) {
					emData->emitBox.min.x = [valNode getValueF:0];
					emData->emitBox.min.y = [valNode getValueF:1];
					emData->emitBox.min.z = [valNode getValueF:2];
				}
				else if ([valName isEqualToString:@"max_pos"]) {
					emData->emitBox.max.x = [valNode getValueF:0];
					emData->emitBox.max.y = [valNode getValueF:1];
					emData->emitBox.max.z = [valNode getValueF:2];
				}
				else if ([valName isEqualToString:@"min_vel"]) {
					emData->minVelocity.x = [valNode getValueF:0];
					emData->minVelocity.y = [valNode getValueF:1];
					emData->minVelocity.z = [valNode getValueF:2];
				}
				else if ([valName isEqualToString:@"max_vel"]) {
					emData->maxVelocity.x = [valNode getValueF:0];
					emData->maxVelocity.y = [valNode getValueF:1];
					emData->maxVelocity.z = [valNode getValueF:2];
				}
				else if ([valName isEqualToString:@"gravity"]) {
					emData->minGravity = [valNode getValueF:0];
					emData->maxGravity = [valNode getValueF:1];
				}
				else if ([valName isEqualToString:@"angle"]) {
					emData->minAngle = xDegToRad([valNode getValueF:0]);
					emData->maxAngle = xDegToRad([valNode getValueF:1]);
				}
				else if ([valName isEqualToString:@"rotate_vel"]) {
					emData->minRotateSpeed = xDegToRad([valNode getValueF:0]);
					emData->maxRotateSpeed = xDegToRad([valNode getValueF:1]);
				}
				else if ([valName isEqualToString:@"scale"]) {
					emData->minScale = [valNode getValueF:0];
					emData->maxScale = [valNode getValueF:1];
				}
				else if ([valName isEqualToString:@"scale_vel"]) {
					emData->minScaleSpeed = [valNode getValueF:0];
					emData->maxScaleSpeed = [valNode getValueF:1];
				}
				else if ([valName isEqualToString:@"life"]) {
					emData->minLife = [valNode getValueF:0];
					emData->maxLife = [valNode getValueF:1];
				}
				else if ([valName isEqualToString:@"min_color"]) {
					emData->minColor.red = xClampI((int)([valNode getValueF:0] * (float)0xFF), 0x00, 0xFF);
					emData->minColor.green = xClampI((int)([valNode getValueF:1] * (float)0xFF), 0x00, 0xFF);;
					emData->minColor.blue = xClampI((int)([valNode getValueF:2] * (float)0xFF), 0x00, 0xFF);;
					if (valNode.valueCount > 2)
						emData->minColor.alpha = xClampI((int)([valNode getValueF:3] * (float)0xFF), 0x00, 0xFF);
				}
				else if ([valName isEqualToString:@"max_color"]) {
					emData->maxColor.red = xClampI((int)([valNode getValueF:0] * (float)0xFF), 0x00, 0xFF);
					emData->maxColor.green = xClampI((int)([valNode getValueF:1] * (float)0xFF), 0x00, 0xFF);
					emData->maxColor.blue = xClampI((int)([valNode getValueF:2] * (float)0xFF), 0x00, 0xFF);
					if (valNode.valueCount > 2)
						emData->maxColor.alpha = xClampI((int)([valNode getValueF:3] * (float)0xFF), 0x00, 0xFF);
				}
				else if ([valName isEqualToString:@"start_alpha"]) {
					emData->startAlpha = [valNode getValueF:0];
				}
				else if ([valName isEqualToString:@"end_alpha"]) {
					emData->endAlpha = [valNode getValueF:0];
				}
			}
			// update total number of particles
			totalParticlesToEmit += emData->emitCount;
		}
		[script release];
	}
	return self;
}

-(void)dealloc
{
	[texture mediaRelease];
	free(emissionArray);
	[super dealloc];
}

@end

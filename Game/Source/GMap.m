// Copyright © 2010 John Judnich. All rights reserved.

#import "GMap.h"
#import "GHUD.h"
#import "GGame.h"
#import "GTeam.h"
#import "GTank.h"
#import "GTankAIController.h"
#import "GTankPlayerController.h"
#import "GOutpost.h"
#import "XTerrain.h"
#import "XTextureNomip.h"
#import "MMenu.h"


@implementation GMap

-(id)init
{
	if ((self = [super init])) {
		mapImage = gGame->terrain->textureMap;
		[mapImage mediaRetain];
		mapText = [XTextureNomip mediaRetainFile:@"Media/HUD/map1.tga" usingMedia:gGame->commonMedia];
		mapButtons1 = [XTextureNomip mediaRetainFile:@"Media/HUD/map2.tga" usingMedia:gGame->commonMedia];
		mapButtons2 = [XTextureNomip mediaRetainFile:@"Media/HUD/map3.tga" usingMedia:gGame->commonMedia];
		flagIcon = [XTextureNomip mediaRetainFile:@"Media/HUD/flag.tga" usingMedia:gGame->commonMedia];
		notAvailibleIcon = [XTextureNomip mediaRetainFile:@"Media/HUD/NA.tga" usingMedia:gGame->commonMedia];
	}
	return self;
}

-(void)dealloc
{
	[mapImage mediaRelease];
	[mapText mediaRelease];
	[mapButtons1 mediaRelease];
	[mapButtons2 mediaRelease];
	[flagIcon mediaRelease];
	[notAvailibleIcon mediaRelease];
	[super dealloc];
}

-(void)draw:(XSeconds)deltaTime
{
	flashTimer += deltaTime * 2;
	if (flashTimer > 1) flashTimer = 0;
	float flash = flashTimer * 2;
	if (flash > 1) flash = 2 - flash;

	x2D_begin();
	x2D_enableTransparency();

	XIntRect area;
	area.top = 0;
	area.bottom = 320;
	XColor color = xColor(0.2, 0.2, 0.2, 0.7);
	area.left = 16;
	area.right = 144;
	x2D_drawRectColored(&area, &color);	
	color = xColor(0, 0, 0, 0.7);
	area.left = 0;
	area.right = 16;
	x2D_drawRectColored(&area, &color);	
	area.left = 144;
	area.right = 160;
	x2D_drawRectColored(&area, &color);	
	
	x2D_setTexture(mapImage);
	area.left = 160;
	area.top = 0;
	area.right = 480;
	area.bottom = 320;
	color = xColor(1, 1, 1, 0.95);
	x2D_drawRectColored(&area, &color);
	
	x2D_setTexture(mapText);
	area.left = 80 - mapText.width/2;
	area.right = 80 + mapText.width/2;
	area.top = 0;
	area.bottom = mapText.height;
	x2D_drawRect(&area);
	
	x2D_setTexture(mapButtons1);
	area.left = 80 - mapButtons1.width/2;
	area.right = 80 + mapButtons1.width/2;
	area.top = 60;
	area.bottom = 60 + mapButtons1.height;
	x2D_drawRect(&area);
	
	x2D_setTexture(mapButtons2);
	area.left = 80 - mapButtons2.width/2;
	area.right = 80 + mapButtons2.width/2;
	area.top = 320 - mapButtons2.height;
	area.bottom = 320;
	x2D_drawRect(&area);
	
	// draw "not availible" icons for tank buttons
	BOOL tankClassAvailibility[3];
	for (int i = 0; i < 3; ++i) tankClassAvailibility[i] = NO;
	for (GTank *tank in gGame->tankList) {
		if (tank.team == gGame->playerTeam) {
			int c = tank.tankClass - 1;
			if (c > 2) c = 2;
			tankClassAvailibility[c] = YES;
		}
	}
	for (int i = 0; i < 3; ++i) {
		if (!tankClassAvailibility[i]) {
			x2D_setTexture(notAvailibleIcon);
			area.left = 63;
			area.right = area.left + notAvailibleIcon.width;
			area.top = 63 + 39 * i;
			area.bottom = area.top + notAvailibleIcon.height;
			x2D_drawRect(&area);
		}
	}
	
	
	// draw flags
	for (GOutpost *outpost in gGame->outpostList) {
		x2D_setTexture(flagIcon);
		XVector2 pos;
		pos.x = outpost.position->x;
		pos.y = outpost.position->z;
		XVector2 spos;
		spos.x = (pos.x - gGame->terrain->boundingBox.min.x) / (gGame->terrain->boundingBox.max.x - gGame->terrain->boundingBox.min.x);
		spos.y = (pos.y - gGame->terrain->boundingBox.min.z) / (gGame->terrain->boundingBox.max.z - gGame->terrain->boundingBox.min.z);
		spos.x = 160 + spos.x * (480-160);
		spos.y = spos.y * 320;
		area.left = spos.x - flagIcon.width / 2;
		area.right = spos.x + flagIcon.width / 2;
		area.top = spos.y - flagIcon.height / 2;
		area.bottom = spos.y + flagIcon.height / 2;
		
		XColor color;
		if (outpost.owningTeam == gGame->playerTeam)
			color = xColor_Blue;
		else if (outpost.owningTeam == nil)
			color = xColor_Gray;
		else
			color = xColor_Red;
		color.alpha = 0.5f;
		
		if (outpost.beingCaptured || outpost.inConflict) {
			color.red = color.red*flash + 0.5f*(1-flash);
			color.green = color.green*flash + 0.5f*(1-flash);
			color.blue = color.blue*flash + 0.5f*(1-flash);
			color.alpha = color.alpha*(1-flash) + 1.0f*flash;
		}
		color.alpha = xSaturate(color.alpha) * 0.5f;
		
		x2D_drawRectColored(&area, &color);		
	}
	
	// draw tanks
	for (GTank *tank in gGame->tankList) {
		x2D_setTexture(tank.icon);
		XVector2 pos = tank.position;
		XVector2 spos;
		spos.x = (pos.x - gGame->terrain->boundingBox.min.x) / (gGame->terrain->boundingBox.max.x - gGame->terrain->boundingBox.min.x);
		spos.y = (pos.y - gGame->terrain->boundingBox.min.z) / (gGame->terrain->boundingBox.max.z - gGame->terrain->boundingBox.min.z);
		spos.x = 160 + spos.x * (480-160);
		spos.y = spos.y * 320;
		area.left = spos.x - tank.icon.width / 2;
		area.right = spos.x + tank.icon.width / 2;
		area.top = spos.y - tank.icon.height / 2;
		area.bottom = spos.y + tank.icon.height / 2;
		if (tank.team == gGame->playerTeam)
			color = xColor_Blue;
		else
			color = xColor_Red;
		x2D_drawRectColoredRotated(&area, &color, tank.yaw);
	}
	
	x2D_end();
}

GTank *selectTank(int minClass, int maxClass)
{
	int count = 0;
	for (GTank *tank in gGame->tankList) {
		if (tank.team == gGame->playerTeam) {
			if (tank.tankClass >= minClass && tank.tankClass <= maxClass)
				++count;
		}
	}
	if (count == 0)
		return nil;
	int index = rand() % count;
	for (GTank *tank in gGame->tankList) {
		if (tank.team == gGame->playerTeam) {
			if (tank.tankClass >= minClass && tank.tankClass <= maxClass) {
				--index;
				if (index <= 0) {
					return tank;
				}
			}
		}
	}
	return nil;
}

-(void)notifyTouch:(CGPoint)point
{
	// button touch
	if (point.x >= 5 && point.x <= 123) {
		GTank *newTank = nil;
		if (point.y >= 60+7 && point.y <= 60+36) {
			// light tank
			newTank = selectTank(0, 1);
		}
		if (point.y >= 60+45 && point.y <= 60+74) {
			// medium tank
			newTank = selectTank(2, 2);
		}
		else if (point.y >= 60+85 && point.y <= 60+112) {
			// heavy tank
			newTank = selectTank(3, 100000);
		}
		else if (point.y >= 192+16 && point.y <= 192+44) {
			// resume game
			if (gGame->playerController.controlTarget)
				gGame->mapMode = NO;
			[gGame->hud showMenuButton];
		}
		else if (point.y >= 192+55 && point.y <= 192+83) {
			// quit game
			gGame->menuMode = YES;
			[gGame->menu notifyReturnedToMenu];
			return; // dont draw hud
		}
		else if (point.y >= 192+94 && point.y <= 192+122) {
			// spectator mode
			GTank *oldTank = gGame->playerController.controlTarget;
			if (oldTank) {
				// set the player's tank to be AI controlled
				GTankAIController *c = [[GTankAIController alloc] init];
				c.skillLevel = oldTank.team.aiSkill;
				oldTank.controller = c;
				[c release];
			}
			gGame->mapMode = NO;
			gGame->spectatorMode = YES;
			[gGame->hud showMenuButton];
		}
		// if the player selected a new tank, set the old one to AI control and enter the new one
		if (newTank) {
			GTank *oldTank = gGame->playerController.controlTarget;
			if (oldTank && oldTank != newTank) {
				// set the player's last tank to be AI controlled
				GTankAIController *c = [[GTankAIController alloc] init];
				c.skillLevel = oldTank.team.aiSkill;
				oldTank.controller = c;
				[c release];
			}
			newTank.controller = gGame->playerController;
			gGame->mapMode = NO;
			gGame->spectatorMode = NO;
			[gGame->hud showMenuButton];
		}
	}
	
	// tank icon touch
	XScalar minDistSq = 100000;
	GTank *minTank = nil;
	for (GTank *tank in gGame->tankList) {
		if (tank.team == gGame->playerTeam || gGame->playerTeam == nil) {
			XVector2 pos = tank.position;
			XVector2 spos;
			spos.x = (pos.x - gGame->terrain->boundingBox.min.x) / (gGame->terrain->boundingBox.max.x - gGame->terrain->boundingBox.min.x);
			spos.y = (pos.y - gGame->terrain->boundingBox.min.z) / (gGame->terrain->boundingBox.max.z - gGame->terrain->boundingBox.min.z);
			spos.x = 160 + spos.x * (480-160);
			spos.y = spos.y * 320;

			XScalar distX = spos.x - (XScalar)point.x;
			XScalar distY = spos.y - (XScalar)point.y;
			XScalar distSq = distX * distX + distY * distY;
			if (distSq < 25*25 && distSq < minDistSq) {
				minDistSq = distSq;
				minTank = tank;
			}
		}
	}
	if (minTank) {
		GTank *tank = gGame->playerController.controlTarget;
		if (tank && tank != minTank) {
			// set the player's last tank to be AI controlled
			GTankAIController *c = [[GTankAIController alloc] init];
			c.skillLevel = tank.team.aiSkill;
			tank.controller = c;
			[c release];
		}
		minTank.controller = gGame->playerController;
		gGame->mapMode = NO;
		gGame->spectatorMode = NO;
		[gGame->hud showMenuButton];
	}
}



@end

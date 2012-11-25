// Copyright © 2010 John Judnich. All rights reserved.

#import "GHUD.h"
#import "GGame.h"
#import "GTankPlayerController.h"
#import "GOutpost.h"


@implementation GHUD

-(id)init
{
	if ((self = [super init])) {
		crosshairs = [XTextureNomip mediaRetainFile:@"Media/HUD/crosshairs.tga" usingMedia:gGame->commonMedia];
		flag = [XTextureNomip mediaRetainFile:@"Media/HUD/flag.tga" usingMedia:gGame->commonMedia];
		arrow = [XTextureNomip mediaRetainFile:@"Media/HUD/arrow.tga" usingMedia:gGame->commonMedia];
		fireButton = [XTextureNomip mediaRetainFile:@"Media/HUD/firebutton.tga" usingMedia:gGame->commonMedia];
		armorBG = [XTextureNomip mediaRetainFile:@"Media/HUD/armor_bg.tga" usingMedia:gGame->commonMedia];
		armorBar = [XTextureNomip mediaRetainFile:@"Media/HUD/armor_bar.tga" usingMedia:gGame->commonMedia];
		victoryDefeatMessage = [XTextureNomip mediaRetainFile:@"Media/HUD/victory_defeat.tga" usingMedia:gGame->commonMedia];
		desertionWarning = [XTextureNomip mediaRetainFile:@"Media/HUD/desertion_warning.tga" usingMedia:gGame->commonMedia];
		menuButton = [XTextureNomip mediaRetainFile:@"Media/HUD/menubutton.tga" usingMedia:gGame->commonMedia];
	}
	return self;
}

-(void)dealloc
{
	[crosshairs mediaRelease];
	[flag mediaRelease];
	[arrow mediaRelease];
	[fireButton mediaRelease];
	[armorBG mediaRelease];
	[armorBar mediaRelease];
	[victoryDefeatMessage mediaRelease];
	[desertionWarning mediaRelease];
	[menuButton mediaRelease];
	[super dealloc];
}

-(void)notifyScoredHit
{
	hitIndicatorLife = 0.5f;
}

-(void)notifyDamaged
{
	damageWobbleLife = 1.0f;
}

-(void)showMenuButton
{
	menuButtonAlpha = 1.0f;
}

-(void)draw:(XSeconds)deltaTime
{
	x2D_begin();
	x2D_enableTransparency();
	
	flashTimer += deltaTime * 2;
	if (flashTimer > 1) flashTimer = 0;
	float flash = flashTimer * 2;
	if (flash > 1) flash = 2 - flash;
	
	float wobblePhase = 0, wobbleMag = 0;
	if (damageWobbleLife > 0) {
		damageWobbleLife -= deltaTime * 2;
		if (damageWobbleLife < 0) damageWobbleLife = 0;
		wobblePhase = (1-damageWobbleLife) * 5 * TWO_PI;
		wobbleMag = damageWobbleLife;
	}
	
	//menu 'button'
	if (gGame->winStatus == GWinStatus_None) {
		menuButtonAlpha -= deltaTime * 0.2f;
		if (menuButtonAlpha < 0.2f) menuButtonAlpha = 0.2f;
	} else {
		menuButtonAlpha += deltaTime * 0.35f;
		if (menuButtonAlpha > 1) menuButtonAlpha = 1;
	}
	XColor color = xColor_White;
	color.alpha = menuButtonAlpha;
	XIntRect area;
	x2D_setTexture(menuButton);
	area.left = 5;
	area.top = 0;
	area.right = 5 + menuButton.width;
	area.bottom = 0 + menuButton.height;
	x2D_drawRectColored(&area, &color);

	// -- draw top-screen flag icons
	GTank *tank = gGame->playerController.controlTarget;
	if (tank) {
		GTankPlayerController *controller = gGame->playerController;

		x2D_setTexture(flag);
		for (GOutpost *outpost in gGame->outpostList) {
			XVector2 screenPos;
			BOOL onScreen = [gGame->camera getScreenPositionOf:outpost.position outPosition:&screenPos];
			int x = screenPos.x;
			int y = 10;
			
			if (onScreen) {
				XColor color;
				if (outpost.owningTeam == tank.team)
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

				XIntRect area;
				area.left = x - (flag.width / 2);
				area.top = y - (flag.height / 2);
				area.right = x + (flag.width / 2);
				area.bottom = y + (flag.height / 2);
				x2D_drawRectColored(&area, &color);
			}
		}
	
		// -- draw crosshairs
		// calculate a 3D aimpoint location
		XVector3 aimpoint = controller.aimVector;
		xMul_Vec3Scalar(&aimpoint, -40);
		
		XVector3 startPosition = xMul_Vec3Mat3(&tank->barrelPivot, tank.barrelModel.globalRotation);
		xAdd_Vec3Vec3(&startPosition, tank.barrelModel.globalPosition);
		xAdd_Vec3Vec3(&aimpoint, &startPosition);
				
		// translate point to screen
		XVector2 screenPos;
		BOOL onScreen = [gGame->camera getScreenPositionOf:&aimpoint outPosition:&screenPos];
		if (onScreen) {
			int x = screenPos.x;
			int y = screenPos.y;
			
			// set color based on reload status and the last hit scored
			XColor color;
			float ready = 1 - xSaturate((1-tank.readyToFire) * 2);
			float hit = xSaturate(hitIndicatorLife * 4);
			color.red = hit;
			color.green = ready * (1-hit);
			color.blue = 0;
			color.alpha = 1;
			hitIndicatorLife -= deltaTime;
			
			//XAngle angle = tank.readyToFire * PI;
			XAngle angle = 0;

			x2D_setTexture(crosshairs);
			XIntRect area;
			area.left = x - (crosshairs.width / 2);
			area.top = y - (crosshairs.height / 2);
			area.right = x + (crosshairs.width / 2);
			area.bottom = y + (crosshairs.height / 2);
			
			angle += xDegToRad(30) * wobbleMag * xSin(wobblePhase * 1.11f);
			XScalar wobbleX = 4 * wobbleMag * xSin(wobblePhase * 1.4f);
			XScalar wobbleY = 4 * wobbleMag * xSin(wobblePhase * 1.5f);
			area.left += wobbleX; area.right += wobbleX;
			area.top += wobbleY; area.bottom += wobbleY;
			
			if (angle != 0)
				x2D_drawRectColoredRotated(&area, &color, angle);
			else
				x2D_drawRectColored(&area, &color);
		}
		
		// -- draw movement buttons
		x2D_setTexture(arrow);
		XIntRect area;
		if (lastTank != tank) {
			moving = xAbs(controller.moving);
		}
		else {
			if (moving < xAbs(controller.moving)) {
				moving += deltaTime * 6;
				if (moving > xAbs(controller.moving))
					moving = xAbs(controller.moving);
			} else if (moving > xAbs(controller.moving)) {
				moving -= deltaTime * 6;
				if (moving < xAbs(controller.moving))
					moving = xAbs(controller.moving);
			}
		}
		if (reverse > 0 && controller.moving >= 0) {
			reverse -= deltaTime * 6;
			if (reverse < 0) reverse = 0;
		}
		if (reverse < 1 && controller.moving < 0) {
			reverse += deltaTime * 6;
			if (reverse > 1) reverse = 1;
		}
		if (controller.moving)
			strafe = controller.strafe;
		for (int x = 0; x < 200; x += 40) {
			XAngle angle = PI * ((float)x / (200-40)) - HALF_PI;
			float strafeID = 2 * ((float)x / (200-40)) - 1;
			
			float c = (1 - xAbs(strafeID - strafe) * 0.5f) * xSqrt(moving);
			XColor color;
			color.red = (c) * 2;
			color.green = (1-c) * 2;
			color.blue = 0;
			if (controller.moving)
				color.alpha = c * 0.5f + 0.5f;
			else
				color.alpha = 0.5f;
			
			int lift = c*c * 40;
			
			lift = (40-lift) * reverse + lift * (1-reverse);
			angle += reverse * xDegToRad(180);

			area.top = 320 - arrow.height - lift;
			area.bottom = 320 - lift;
			
			area.left = x;
			area.right = x + arrow.width;

			angle += xDegToRad(15) * wobbleMag * xSin(wobblePhase * 0.5f + x * 123); // random phase
			XScalar wobbleX = 2 * wobbleMag * xSin(wobblePhase * 0.9f + x * 345);
			XScalar wobbleY = 2 * wobbleMag * xSin(wobblePhase + x * 543);
			area.left += wobbleX; area.right += wobbleX;
			area.top += wobbleY; area.bottom += wobbleY;
			
			x2D_drawRectColoredRotated(&area, &color, angle);
		}
		
		// -- draw fire button
		x2D_setTexture(fireButton);
		area.left = 480 - fireButton.width;
		area.top = 320 - fireButton.height;
		area.right = 480;
		area.bottom = 320;
		if (controller.firing) {
			XColor color = xColor(1, 1, 1, 1);
			x2D_drawRectColored(&area, &color);
		} else {
			XColor color = xColor(0.5, 0.7, 1, 0.5);
			x2D_drawRectColored(&area, &color);
		}
		
		// -- draw armor bar
		area.left = 480 - armorBG.width;
		area.top = 0;
		area.right = 480;
		area.bottom = armorBG.height;
		x2D_setTexture(armorBG);
		x2D_drawRect(&area);
		
		float cArmor = (tank.armor / tank.maxArmor);
		if (lastTank != tank) {
			armor = cArmor;
		}
		else {
			if (armor < cArmor) {
				armor += deltaTime * 2;
				if (armor > cArmor)
					armor = cArmor;
			} else if (armor > cArmor) {
				armor -= deltaTime * 2;
				if (armor < cArmor)
					armor = cArmor;
			}
		}
		
		XColor color;
		color.green = xSaturate(armor * 2 - 0.75f);
		color.red = (1-color.green);
		color.green *= 2; color.red *= 2;
		color.blue = 0;
		if (armor < 0.4f)
			color.alpha = flash * 0.5f;
		else
			color.alpha = 0.5f;
		
		XScalarRect region;
		region.left = 0; region.right = 1;
		region.bottom = 1;
		region.top = (1 - armor) * (0.81f-0.23f) + 0.23f;
		x2D_setTexture(armorBar);
		x2D_drawRectCroppedColored(&area, &region, &color);
		
		// desertion warning
		float cWarning = (tank.desertionTimer > 0.1f);
		if (lastTank != tank) {
			warning = cWarning;
		}
		else {
			if (warning < cWarning) {
				warning += deltaTime * 2;
				if (warning > cWarning)
					warning = cWarning;
			} else if (warning > cWarning) {
				warning -= deltaTime * 2;
				if (warning < cWarning)
					warning = cWarning;
			}
		}
		if (warning > 0) {
			x2D_setTexture(desertionWarning);

			XIntRect area;
			area.top = 30;
			area.bottom = 30 + desertionWarning.height;
			area.left = 240.0f - (desertionWarning.width/2.0f);
			area.right = 240.0f + (desertionWarning.width/2.0f);
			
			float yellow = 1.0f - (tank.desertionTimer / 10.0f);
			
			XColor color;
			color.red = 1;
			color.green = yellow;
			color.blue = 0;
			color.alpha = (flash * 0.8f + 0.2f) * warning;
			
			x2D_drawRectColored(&area, &color);
		}
	}
	lastTank = tank;
	
	// -- show victory / defeat message
	if (gGame->winStatus == GWinStatus_None)
		gameoverTimer = 0;
	else if (gGame->winStatus != GWinStatus_None) {
		gameoverTimer += deltaTime;

		XColor color;
		color.alpha = xSaturate(gameoverTimer*2) * 0.75f;
		float c = xSaturate((8 - gameoverTimer) / 5.0f) * 0.6f + 0.2f;
		if (gGame->winStatus == GWinStatus_Victory) {
			color.red = 0;//c/5;
			color.green = 0;//c/3;
			color.blue = c;
		} else {
			color.red = c;
			color.green = 0;
			color.blue = 0;
		}		
		
		float width = victoryDefeatMessage.width;
		float height = victoryDefeatMessage.height;
		float transition = xSaturate(gameoverTimer - 5);
		width /= (transition+1.0f);
		height /= (transition+1.0f);

		XIntRect area;
		area.top = 30;
		area.bottom = 30 + height;
		
		area.left = (240.0f - (width/2.0f)) * (1-transition) + 30.0f * (transition);
		area.right = (240.0f + (width/2.0f)) * (1-transition) + (30.0f + width) * (transition);
		
		XScalarRect region;
		region.left = 0; region.right = 1;
		if (gGame->winStatus == GWinStatus_Victory) {
			region.top = 0;
			region.bottom = 0.5f;
		} else {
			region.top = 0.5f;
			region.bottom = 1;
		}
		
		area.top -= region.top * height;
		area.bottom -= region.top * height;
		
		x2D_setTexture(victoryDefeatMessage);
		x2D_drawRectCroppedColored(&area, &region, &color);		
	}
	
	x2D_disableTransparency();
	x2D_end();
}

@end

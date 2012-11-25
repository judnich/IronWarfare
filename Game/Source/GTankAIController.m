// Copyright © 2010 John Judnich. All rights reserved.

#import "GTankAIController.h"
#import "GTank.h"
#import "GOutpost.h"
#import "GBullet.h"


@implementation GTankAIController

@synthesize skillLevel, backupRequested;

-(id)init
{
	if ((self = [super init])) {
		skillLevel = AISkill_Rookie;
		frameCount = rand() % 30;
		headingTimer = xRand();
		state = AIState_None;
	}
	return self;
}

-(void)dealloc
{
	self.target = nil;
	self.leader = nil;
	[super dealloc];
}

-(BOOL)isComputerControlled
{
	return YES;
}

-(void)setTarget:(GTank*)target
{
	[__target release];
	__target = target;
	[__target retain];
}

-(GTank*)target
{
	return __target;
}

-(void)setLeader:(GTank*)leader
{
	[__leader release];
	__leader = leader;
	[__leader retain];
}

-(GTank*)leader
{
	return __leader;
}

-(void)notifyFired
{
	// AI aiming inaccuracy
	switch (skillLevel) {
		case AISkill_Rookie:
			missPitch = xDegToRad(xRangeRand(-9, 9));
			missYaw = xDegToRad(xRangeRand(-6, 6));
			break;
		case AISkill_Average:
			missPitch = xDegToRad(xRangeRand(-6, 6));
			missYaw = xDegToRad(xRangeRand(-5, 5));
			break;
		case AISkill_Expert:
			missPitch = xDegToRad(xRangeRand(-2.5, 2.5));
			missYaw = xDegToRad(xRangeRand(-5, 5));
			break;
		case AISkill_Flawless:
			missPitch = xDegToRad(xRangeRand(-1, 1));
			missYaw = xDegToRad(xRangeRand(-4, 4));
			break;
	}
}

-(void)frameUpdate:(XSeconds)deltaTime
{
	if (!tank)
		return;

	GTankControls controls;
	controls.fire = NO;
	controls.throttle = 0;
	controls.turn = 0;
	controls.aimYaw = 0;
	controls.aimPitch = 0;
	
	// update frame and timeout info
	timeout += deltaTime;

	// release target/leader when destroyed
	if (self.target) {
		if (self.target.armor <= 0 || tank.armor <= 0) {
			self.target = nil;
		}
	}
	if (self.leader) {
		if (self.leader.armor <= 0 || tank.armor <= 0) {
			self.leader = nil;
		}
	}
	
	//---------------------------------- Aim at target ------------------------------------
	if (self.target) {
		// aim at target
		XVector3 vec;
		vec.x = tank.bodyModel->position.x - self.target.bodyModel->position.x;
		vec.y = tank.bodyModel->position.y - self.target.bodyModel->position.y;
		vec.z = tank.bodyModel->position.z - self.target.bodyModel->position.z;
		XScalar dist = xSqrt(vec.x*vec.x + vec.z*vec.z);
		XAngle aimYaw = PI + xATan2(-vec.x, vec.z) + missYaw;
		
		// calculate trajectory
		XAngle aimPitch = xATan2(-vec.y, dist) + -xDegToRad((-xSqrt(dist*6) * .2) + 2) + missPitch;
		
		// calculate current aim vector
		XVector3 cAimVector;
		cAimVector.x = 0; cAimVector.y = 0; cAimVector.z = -1;
		cAimVector = xMul_Vec3Mat3(&cAimVector, tank.barrelModel.globalRotation);
		
		// extract current yaw
		XAngle cAimYaw = xClampAngle(xATan2(-cAimVector.x, cAimVector.z));
		XAngle deltaYaw = xClampAngle(aimYaw - cAimYaw);
		
		// extract current pitch
		XAngle cAimPitch = xClampAngle(xATan2(cAimVector.y, xSqrt(cAimVector.z*cAimVector.z + cAimVector.x*cAimVector.x)));
		XAngle deltaPitch = xClampAngle(aimPitch - cAimPitch);
		
		// aim..
		controls.aimYaw = deltaYaw * 5;
		controls.aimPitch = -deltaPitch * 5;

		// fire!
		if (xAbs(deltaYaw) < xDegToRad(10)) controls.fire = YES; else controls.fire = NO;
		
		// reset look-around timer (idle turret animation)
		lookaround = 10;
	}
	else {
		// when no target is given, look in a new random direction every 3-5 seconds
		lookaround -= deltaTime;
		if (lookaround <= 0) {
			lookaround = xRangeRand(3, 5);
			lookaroundYaw = xRangeRand(-180, 180);
		}
		if (lookaround <= 5) {
			// calculate current aim vector
			XVector3 cAimVector;
			cAimVector.x = 0; cAimVector.y = 0; cAimVector.z = -1;
			cAimVector = xMul_Vec3Mat3(&cAimVector, tank.barrelModel.globalRotation);

			// extract current yaw
			XAngle cAimYaw = xClampAngle(xATan2(-cAimVector.x, cAimVector.z));
			XAngle deltaYaw = xClampAngle(lookaroundYaw - cAimYaw);
			
			// extract current pitch
			XAngle cAimPitch = xClampAngle(xATan2(cAimVector.y, xSqrt(cAimVector.z*cAimVector.z + cAimVector.x*cAimVector.x)));
			XAngle deltaPitch = xClampAngle(xDegToRad(5) - cAimPitch);
			
			// aim..
			controls.aimYaw = deltaYaw * 1;
			controls.aimPitch = -deltaPitch * 1;
		}
	}
	
	//--------------------------------- Follow waypoint -------------------------------
	if (waypoint.x < gGame->terrain->boundingBox.min.x+150) waypoint.x = gGame->terrain->boundingBox.min.x+150;
	if (waypoint.y < gGame->terrain->boundingBox.min.z+150) waypoint.y = gGame->terrain->boundingBox.min.z+150;
	if (waypoint.x > gGame->terrain->boundingBox.max.x-150) waypoint.x = gGame->terrain->boundingBox.max.x-150;
	if (waypoint.y > gGame->terrain->boundingBox.max.z-150) waypoint.y = gGame->terrain->boundingBox.max.z-150;
	
	XVector2 waypointVec;
	waypointVec.x = tank.bodyModel->position.x - waypoint.x;
	waypointVec.y = tank.bodyModel->position.z - waypoint.y;
	XScalar waypointDist = xLength_Vec2(&waypointVec);
	
	if (waypointDist > desiredWaypointDist) {
		headingTimer += deltaTime;
		
		if (headingTimer >= 1) {
			headingTimer = 0;
		
			// test for "collision" by checking land height at various angles relative to the tank, and follow the path of least resistance
			XAngle dir = xATan2(-waypointVec.x, waypointVec.y);
			float minCost = 10000, minAng = 1000;
			for (XAngle ang = xDegToRad(-90); ang <= xDegToRad(90); ang += xDegToRad(30)) {
				XVector3 tformed;
				tformed.x = 0; tformed.y = 0; tformed.z = -10;
				XMatrix3 tform;
				xBuildYRotationMatrix3(&tform, tank.yaw + ang);
				tformed = xMul_Vec3Mat3(&tformed, &tform);
				xAdd_Vec3Vec3(&tformed, &tank.bodyModel->position);
				XTerrainIntersection intersect = [gGame->terrain intersectTerrainVerticallyAt:&tformed];
				float cost = (intersect.point.y - tank.bodyModel->position.y);	//hill compensation
				if (cost < 0) cost = -cost * 0.5f;
			
				XAngle dirdist = xAbs(xClampAngle((tank.yaw + ang) - dir));
				cost += xRadToDeg(dirdist) * 0.05f;
				
				if (cost < minCost) {
					minCost = cost;
					minAng = ang;
				}
			}
			
			heading = tank.yaw + minAng;
		}
		
		XAngle dirdist = xClampAngle(heading - tank.yaw);
		controls.turn = xClamp(dirdist * 3, -1, 1);
		controls.throttle = xClamp(waypointDist - desiredWaypointDist, -1, 1) / xClamp(20 - waypointDist, 1, 2);
	}
	
	//---------------------------------Behavior-------------------------------------
	// update AI behavior every 30 frames for better performance
	++frameCount;
	if (frameCount > 30) {
		frameCount = frameCount % 30;
		
		XScalar tankX = tank.bodyModel->position.x;
		XScalar tankZ = tank.bodyModel->position.z;
		if (desiredWaypointDist <= 0.1f) desiredWaypointDist = 5;
		
		switch (state) {
			// no state selected, so initialize AI
			case AIState_None:
				state = AIState_Patrol;
				waypoint.x = tankX;
				waypoint.y = tankZ;
				desiredWaypointDist = 5;
				timeout = 100;
				[self notifyFired]; //set accuracy
				break;
			
			// Patrol - Main branch state
			case AIState_Patrol:
				// first, check if anyone needs help before patroling
				if (skillLevel >= AISkill_Average) {
					XScalar mindist = 100000;
					GTank *mintank = nil;
					for (GTank *t in gGame->tankList) {
						if (t.team == tank.team && t != tank) {
							if ([t.controller respondsToSelector:@selector(backupRequested)] && [(id)t.controller backupRequested] == YES) {
								XScalar xd = tankX - t.bodyModel->position.x;
								XScalar zd = tankZ - t.bodyModel->position.z;
								XScalar dist = xSqrt(xd*xd + zd*zd);
								if (dist < mindist) {
									mindist = dist;
									mintank = t;
								}
							}
						}
					}
					if (mintank) {
						state = AIState_Follow;
						timeout = xRangeRand(-1, 1);
						self.leader = mintank;
						if (rand() % 2 == 1) {
							if ([self.leader.controller respondsToSelector:@selector(setBackupRequested)])
								[(id)(self.leader.controller) setBackupRequested:NO];
						}
					}
				}
				// next waypoint
				if (waypointDist <= desiredWaypointDist*2 + 1) {
					int rnd = 1;
					if (skillLevel >= AISkill_Expert)
						rnd = rand() % 3;
					if (rnd == 0) {
						// go to nearest enemy base
						XScalar mindist = 100000;
						GOutpost *mincpoint = nil;
						for (GOutpost *cp in gGame->outpostList) {
							if (cp.owningTeam != tank.team || (cp.owningTeam == tank.team && (cp.inConflict || cp.beingCaptured))) { //cp.captured < 0.5f)) {
								XScalar xd = cp.position->x - tankX;
								XScalar zd = cp.position->z - tankZ;
								XScalar dist = xSqrt(xd*xd + zd*zd) + xRangeRand(-100, 100);
								if (dist < mindist) {
									mindist = dist;
									mincpoint = cp;
								}
							}
						}
						if (mincpoint) {
							waypoint.x = mincpoint.position->x;
							waypoint.y = mincpoint.position->z;
							if (skillLevel >= AISkill_Flawless)
								desiredWaypointDist = 5;
							else if (skillLevel >= AISkill_Average)
								desiredWaypointDist = 10;
							else
								desiredWaypointDist = 30;
							timeout = xRangeRand(-1, 1);
						}
						else rnd = 1;
					}
					if (rnd != 0) {
						// go to random base
						int waypointIndex = rand() % gGame->outpostList.count;
						GOutpost *cpoint = [gGame->outpostList objectAtIndex:waypointIndex];
						waypoint.x = cpoint.position->x;
						waypoint.y = cpoint.position->z;
						if (skillLevel >= AISkill_Flawless)
							desiredWaypointDist = 5;
						else if (skillLevel >= AISkill_Average)
							desiredWaypointDist = 10;
						else
							desiredWaypointDist = 30;
					}
				}
				// timeout - change state
				if (timeout >= 10) {
					int num = 0;
					if (skillLevel >= AISkill_Expert) num = 2; else num = 3;
					if (rand() % num == 0 && skillLevel >= AISkill_Expert) {
						// choose a leader
						XScalar mindist = 100000;
						GTank *mintank = nil;
						for (GTank *t in gGame->tankList) {
							if (t.team == tank.team && t.controller.isComputerControlled && [(id)t.controller leader] != tank && t != tank) {
								XScalar xd = tankX - t.bodyModel->position.x;
								XScalar zd = tankZ - t.bodyModel->position.z;
								XScalar dist = xSqrt(xd*xd + zd*zd);
								if (dist < mindist) {
									mindist = dist;
									mintank = t;
								}
							}
						}
						self.leader = mintank;
						state = AIState_Follow;
						timeout = xRangeRand(-1, 1);
					} else {
						//if (allowBaseCapture) {
						if (1) {
							// choose an enemy base
							XScalar mindist = 100000;
							GOutpost *mincpoint = nil;
							for (GOutpost *cp in gGame->outpostList) {
								if (cp.owningTeam != tank.team || (cp.owningTeam == tank.team && cp.captured < 0.5f)) {
									XScalar xd = cp.position->x - tankX;
									XScalar zd = cp.position->z - tankZ;
									XScalar dist = xSqrt(xd*xd + zd*zd) + xRangeRand(-100, 100);
									if (dist < mindist) {
										mindist = dist;
										mincpoint = cp;
									}
								}
							}
							if (mincpoint) {
								waypoint.x = mincpoint.position->x;
								waypoint.y = mincpoint.position->z;
								if (skillLevel >= AISkill_Flawless)
									desiredWaypointDist = 5;
								else if (skillLevel >= AISkill_Average)
									desiredWaypointDist = 10;
								else
									desiredWaypointDist = 30;
								timeout = xRangeRand(-1, 1);
							}
						} else {
							// choose an enemy
							XScalar mindist = 100000;
							GTank *mintank = nil;
							for (GTank *t in gGame->tankList) {
								if (t.team != tank.team) {
									XScalar xd = tankX - t.bodyModel->position.x;
									XScalar zd = tankZ - t.bodyModel->position.z;
									XScalar dist = xSqrt(xd*xd + zd*zd);
									if (dist < mindist) {
										mindist = dist;
										mintank = t;
									}
								}
							}
							if (mintank) {
								self.target = mintank;
								state = AIState_Hunt;
							}
						}
					}
				}
				// attack any nearby enemies
				XScalar mindist = 100000;
				GTank *mintank = nil;
				for (GTank *t in gGame->tankList) {
					if (t.team != tank.team) {
						XScalar xd = tankX - t.bodyModel->position.x;
						XScalar zd = tankZ - t.bodyModel->position.z;
						XScalar dist = xSqrt(xd*xd + zd*zd);
						if (dist < mindist) {
							mindist = dist;
							mintank = t;
						}
					}
				}
				XScalar range = 0;
				if (skillLevel >= AISkill_Expert) range = 100; else range = 65;
				if (mindist < range) {
					if (tank.armor > 0.5f) {
						int x = rand() % 4;
						switch (x) {
							case 0: state = AIState_Hunt; break;
							case 1: state = AIState_Hunt; break;
							case 2: state = AIState_Hunt; break;
							case 3: state = AIState_Snipe; break;
							//case 2: state = AIState_Evade; break;
						}
						self.target = mintank;
					} else {
						state = AIState_Evade;
						self.target = mintank;
					}
					timeout = xRangeRand(-1, 1);
				}
				break;
			
			//Hunt the enemy
			case AIState_Hunt:
				if (timeout >= 15) {
					state = AIState_Patrol;
					timeout = xRangeRand(-1, 1);
				}
				if (self.target == nil) {
					state = AIState_Patrol;
				} else {
					waypoint.x = self.target.bodyModel->position.x;
					waypoint.y = self.target.bodyModel->position.z;
					desiredWaypointDist = 5;
				}
				break;
			
			//Follow
			case AIState_Follow:
				if (self.leader == nil) {
					state = AIState_Patrol;
				} else {
					if (timeout >= 20 && self.leader.controller.isComputerControlled) {
						self.leader = nil;
						state = AIState_Patrol;
						timeout = xRangeRand(-1, 1);
					}
					if (state == AIState_Follow) {
						XScalar mindist = 100000;
						GTank *mintank = nil;
						for (GTank *t in gGame->tankList) {
							if (t.team != tank.team) {
								XScalar xd = tankX - t.bodyModel->position.x;
								XScalar zd = tankZ - t.bodyModel->position.z;
								XScalar dist = xSqrt(xd*xd + zd*zd);
								if (dist < mindist) {
									mindist = dist;
									mintank = t;
								}
							}
						}
						if (self.target == nil) {
							if (mindist < 125) {
								self.target = mintank;
							}
						} else {
							XScalar xd = tankX - self.target.bodyModel->position.x;
							XScalar zd = tankZ - self.target.bodyModel->position.z;
							XScalar dist = xSqrt(xd*xd + zd*zd);
							if (dist > 125 * 2) {
								self.target = mintank;
							}
						}
						waypoint.x = self.leader.bodyModel->position.x;
						waypoint.y = self.leader.bodyModel->position.z;
						desiredWaypointDist = 10;
					}
				}
				break;
			
			//Evade
			case AIState_Evade:
				if (skillLevel < AISkill_Average) {
					if (timeout >= 10) {
						state = AIState_Patrol;
						timeout = xRangeRand(-1, 1);
					}
					if (waypointDist <= desiredWaypointDist*2 + 1) {
						waypoint.x += xRangeRand(-50, 50);
						waypoint.y += xRangeRand(-50, 50);
						desiredWaypointDist = 1;
					}
					if (self.target == nil) {
						state = AIState_Patrol;
					}
				} else {
					if (timeout >= 60) {
						state = AIState_Patrol;
						timeout = xRangeRand(-1, 1);
					}
					if (waypointDist <= desiredWaypointDist*2 + 1 || desiredWaypointDist != 2.1) { //if it's not 2.1, the waypoint wasn't issued from the retreat behaviour, and needs to be recalculated
						XScalar mindist = 10000;
						GOutpost *mincpoint = nil;
						for (GOutpost *cpoint in gGame->outpostList) {
							if (!cpoint.inConflict && (cpoint.owningTeam == nil || cpoint.owningTeam == tank.team)) {
								XScalar xd = tankX - cpoint.position->x;
								XScalar zd = tankZ - cpoint.position->z;
								XScalar dist = xSqrt(xd*xd + zd*zd);
								if (dist < mindist) {
									mindist = dist;
									mincpoint = cpoint;
								}
							}
						}
						if (mincpoint == nil) {
							waypoint.x += xRangeRand(-50, 50);
							waypoint.y += xRangeRand(-50, 50);
						} else {
							waypoint.x = mincpoint.position->x;
							waypoint.y = mincpoint.position->z;
						}
						desiredWaypointDist = 2.1;
					}
					if (self.target == nil) {
						state = AIState_Patrol;
					}
				}

				mindist = 100000;
				mintank = nil;
				for (GTank *t in gGame->tankList) {
					if (t.team != tank.team) {
						XScalar xd = tankX - t.bodyModel->position.x;
						XScalar zd = tankZ - t.bodyModel->position.z;
						XScalar dist = xSqrt(xd*xd + zd*zd);
						if (dist < mindist) {
							mindist = dist;
							mintank = t;
						}
					}
				}
				if (self.target == nil) {
					if (mindist < 125) {
						self.target = mintank;
					}
				} else {
					XScalar xd = tankX - self.target.bodyModel->position.x;
					XScalar zd = tankZ - self.target.bodyModel->position.z;
					XScalar dist = xSqrt(xd*xd + zd*zd);
					if (dist > 250 * 2) {
						self.target = mintank;
					}
				}
				break;
			
			//Snipe
			case AIState_Snipe:
				if (timeout > 10 && (self.leader == nil || self.leader.controller.isComputerControlled)) {
					state = AIState_Patrol;
					timeout = xRangeRand(-1, 1);
				}
				if (self.target == nil) {
					if (self.leader.controller.isComputerControlled) {
						state = AIState_Patrol;
					} else {
						XScalar mindist = 100000;
						GTank *mintank = nil;
						for (GTank *t in gGame->tankList) {
							if (t.team != tank.team) {
								XScalar xd = tankX - t.bodyModel->position.x;
								XScalar zd = tankZ - t.bodyModel->position.z;
								XScalar dist = xSqrt(xd*xd + zd*zd);
								if (dist < mindist) {
									mindist = dist;
									mintank = t;
								}
							}
						}
						self.target = mintank;
					}
				}
				break;
			
			default:
				NSLog(@"AI ERROR: Endefined state encountered!");
				state = AIState_None;
				break;
		}
		
		// AI debugging for stuck tanks
#ifdef DEBUG
		if (state != AIState_Snipe && waypointDist < desiredWaypointDist) {
			++debugCounter;
			if (debugCounter > 15) {
				debugCounter = 0;
				NSLog(@"Possible stuck AI detected");
				NSLog(@"state=%d, desiredWaypointDist=%f, timeout=%f", state, desiredWaypointDist, timeout);
			}
		}
		else debugCounter = 0;
#endif
	}
	
	// set tank controls
	tank->controls = controls;
}

-(void)notifyWasHitWithBullet:(GBullet*)bullet
{
	if (tank == nil)
		return;
	
	if (skillLevel == AISkill_Average) {
		if (bullet.originator) {
			self.target = bullet.originator;
			if (rand() % 2 == 0) state = AIState_Hunt;
			if (tank.armor <= 0.5f) {
				if (self.leader.controller.isComputerControlled) state = AIState_Evade;
				backupRequested = TRUE;
			}
		}
	}
	if (skillLevel >= AISkill_Expert) {
		if (bullet.originator) {
			XScalar dist1;
			if (self.target == nil) {
				dist1 = 10000;
			} else {
				XScalar dx = self.target.bodyModel->position.x - tank.bodyModel->position.x;
				XScalar dz = self.target.bodyModel->position.z - tank.bodyModel->position.x;
				dist1 = xSqrt(dx*dx + dz*dz);
			}
			XScalar dx = bullet.originator.bodyModel->position.x - tank.bodyModel->position.x;
			XScalar dz = bullet.originator.bodyModel->position.z - tank.bodyModel->position.x;
			XScalar dist2 = xSqrt(dx*dx + dz*dz);
			
			if (dist2 < dist1) self.target = bullet.originator;
			if (rand() % 3 == 0) state = AIState_Hunt;
			if (tank.armor <= 0.6f) {
				if (self.leader.controller.isComputerControlled) state = AIState_Evade;
				backupRequested = TRUE;
			}
		}
	}
}


@end

//
//  Gameplay.m
//  PeevedPenguins
//
//  Created by Maria Luisa on 1/28/15.
//  Copyright (c) 2015 Apportable. All rights reserved.
//

#import "Gameplay.h"
#import "Penguin.h"
#import "Level.h"
#import "CCPhysics+ObjectiveChipmunk.h"

@implementation Gameplay {
    CCPhysicsNode *_physicsNode;
    CCNode *_contentNode;
    CCNode *_catapultArm;
    CCNode *_levelNode;
    CCNode *_pullbackNode;
    CCNode *_mouseJointNode;
    CCPhysicsJoint *_mouseJoint;
    Penguin *_currentPenguin;
    CCPhysicsJoint *_penguinCatapultJoint;
    CCAction *_followPenguin;
    
    Level *_level;
    CCLabelTTF *_destroyedSealsLabel;
    CCLabelTTF *_totalSealsLabel;
    
    int _destroyedSeals;
    int _totalSeals;
}

static const float MIN_SPEED = 5.f;

// Is called when CCB file has completed loading
-(void) didLoadFromCCB {
    // Tell this scene to accept touches
    self.userInteractionEnabled = TRUE;
    
    // The level implements a custom class that inherits from CCScene, so we don't need to load it as CCScene
    // CCScene *level = [CCBReader loadAsScene:@"Levels/Level1"];
    _level = (Level *)[CCBReader load:@"Levels/Level1"];
    [_levelNode addChild:_level];
    _totalSeals = (int)[_level countSeals];
    _totalSealsLabel.string = [NSString stringWithFormat:@"%d", _totalSeals];
    
    // Deactivate collisions for the _pullbackNode
    // Nothing shall collide with our invisible nodes
    _pullbackNode.physicsBody.collisionMask = @[];
    _mouseJointNode.physicsBody.collisionMask = @[];
    
    // Sign up as the collision delegate of our physics node
    _physicsNode.collisionDelegate = self;
    
    // Visualize physics bodies & joints
    //_physicsNode.debugDraw = TRUE;
}

-(void) update:(CCTime)delta {
    
    if (_currentPenguin.launched) {
        // If speed is below minimum speed, assume this attempt is over
        // ccpLength calculates distance between the point given and origin. Calculates the square length of the velocity (Pitagoras)
        if (_currentPenguin != nil && ccpLength(_currentPenguin.physicsBody.velocity) < MIN_SPEED) {
            [self nextAttempt];
            return;
        }
        
        int xMin = _currentPenguin.boundingBox.origin.x;
        
        if (xMin < self.boundingBox.origin.x) {
            [self nextAttempt];
            return;
        }
        
        int xMax = xMin + _currentPenguin.boundingBox.size.width;
        
        if (xMax > (self.boundingBox.origin.x + self.boundingBox.size.width)) {
            [self nextAttempt];
            return;
        }
    }
}

// Called on every touch in this scene
-(void) touchBegan:(CCTouch *)touch withEvent:(CCTouchEvent *)event {
    
    // Spawn another penguin only if we are no longer following the previous penguin
    if (_currentPenguin == nil) {
        CGPoint touchLocation = [touch locationInNode:_contentNode];
        
        // Start catapult dragging when a touch inside of the catapult arm occurs
        if (CGRectContainsPoint([_catapultArm boundingBox], touchLocation)) {
            // Move the mouseJointNode to the touch position
            _mouseJointNode.position = touchLocation;
            
            // Setup a spring joint between the mouseJointNode and the catapultArm
            _mouseJoint = [CCPhysicsJoint connectedSpringJointWithBodyA:_mouseJointNode.physicsBody bodyB:_catapultArm.physicsBody anchorA:ccp(0, 0) anchorB:ccp(14, 144) restLength:0.f stiffness:3000.f damping:150.f];
            
            // Create a penguin from the ccb-file
            _currentPenguin = (Penguin *) [CCBReader load:@"Penguin"];
            
            // Initially position it on the scoop. 34, 138 is th eposition in the node space of the _catapultArm
            CGPoint penguinPosition = [_catapultArm convertToWorldSpace:ccp(34, 138)];
            
            // Transform the world position to the node space to which the penguin will be added (_physicsNode)
            _currentPenguin.position = [_physicsNode convertToNodeSpace:penguinPosition];
            
            // Add it to the physics world
            [_physicsNode addChild:_currentPenguin];
            
            // We don't want the penguin to rotate in the scoop
            _currentPenguin.physicsBody.allowsRotation = NO;
            
            // Create a joint to keep the penguin fixed to the scoop until the catapult is released
            _penguinCatapultJoint = [CCPhysicsJoint connectedPivotJointWithBodyA:_currentPenguin.physicsBody bodyB:_catapultArm.physicsBody anchorA:_currentPenguin.anchorPointInPoints];
            
        }
    }
    
    
}

-(void) touchMoved:(CCTouch *)touch withEvent:(CCTouchEvent *)event {
    // Whenever touches move, update the position of the mouseJointNode to the touch position
    CGPoint touchLocation = [touch locationInNode:_contentNode];
    _mouseJointNode.position = touchLocation;
}

-(void) touchEnded:(CCTouch *)touch withEvent:(CCTouchEvent *)event {
    // When touches end, meaning the user releases their finger, release the catapult
    [self releaseCatapult];
}

-(void) touchCancelled:(CCTouch *)touch withEvent:(CCTouchEvent *)event {
    // Whent touches are cancelled, meaning the user drags their finger off the screen or onto something else, release the catapult
    [self releaseCatapult];
}

-(void) launchPenguin {
    // Loads the Penguin.ccb we have set up in Spritebuilder
    CCNode *penguin = [CCBReader load:@"Penguin"];
    // Position the penguin at the bowl of the catapult
    penguin.position = ccpAdd(_catapultArm.position, ccp(16, 50));
    
    // Add the penguin to the physicsNode of this scene (because it has physics enabled)
    [_physicsNode addChild:penguin];
    
    // Manually create & apply a force to launch the penguin
    CGPoint launchDirection = ccp(1, 0);
    CGPoint force = ccpMult(launchDirection, 8000);
    [penguin.physicsBody applyForce:force];
    
    // Ensure followed object is in visible area when starting
    self.position = ccp(0, 0);
    CCActionFollow *follow = [CCActionFollow actionWithTarget:penguin worldBoundary:self.boundingBox];
    [_contentNode runAction:follow];
    
}

-(void) releaseCatapult {
    if (_mouseJoint != nil) {
        // Releases the joint and lets the catapult snap back
        [_mouseJoint invalidate];
        _mouseJoint = nil;
        
        // Releases the joint and lets the penguin fly
        [_penguinCatapultJoint invalidate];
        _penguinCatapultJoint = nil;
        _currentPenguin.launched = YES;
        
        // After snapping, rotation is fine
        _currentPenguin.physicsBody.allowsRotation = YES;
        
        // Follow the flying penguin
        _followPenguin = [CCActionFollow actionWithTarget:_currentPenguin worldBoundary:self.boundingBox];
        [_contentNode runAction:_followPenguin];
        
    }
}

-(void) retry {
    // Reload this level
    [[CCDirector sharedDirector] replaceScene: [CCBReader loadAsScene:@"Gameplay"]];
}

-(void) ccPhysicsCollisionPostSolve:(CCPhysicsCollisionPair *)pair seal:(CCNode *)nodeA wildcard:(CCNode *)nodeB {
    //CCLOG(@"Something collided with a seal!");
    
    float energy = [pair totalKineticEnergy];
    
    // If energy is large enough, remove the seal
    if (energy > 5000.f) {
        [[_physicsNode space] addPostStepBlock:^{
            [self sealRemoved:nodeA];
        }key:nodeA];
    }
}

-(void) sealRemoved:(CCNode *)seal {
    // Load particle effect
    CCParticleSystem *explosion = (CCParticleSystem *)[CCBReader load:@"SealExplosion"];
    
    // Make the particle effect clean itself up, once it is completed
    explosion.autoRemoveOnFinish = YES;
    
    // Place the particle effect on the seals position
    explosion.position = seal.position;
    
    // Add the particle effect to the same node the seal is on
    [seal.parent addChild:explosion];
    
    // Finally, remove the destroyed seal
    [seal removeFromParent];
    
    _destroyedSeals++;
    _destroyedSealsLabel.string = [NSString stringWithFormat:@"%d", _destroyedSeals];
    _destroyedSeals = _totalSeals;
    if ([self gameCompleted]) {
        [self endGame];
    }
    
}

-(void) nextAttempt {
    _currentPenguin = nil;
    [_contentNode stopAction:_followPenguin];
    
    
    CCActionMoveTo *actionMoveTo = [CCActionMoveTo actionWithDuration:1.f position:ccp(0, 0)];
    [_contentNode runAction:actionMoveTo];
}

-(int) gameCompleted {
    return _totalSeals == _destroyedSeals;
}

-(void) endGame {
    CCLabelTTF *congratulationsLabel = [CCLabelTTF labelWithString:@"Congratulations!" fontName:@"Helvetica" fontSize:48.f];
    congratulationsLabel.positionType = CCPositionTypeMake(CCPositionUnitNormalized, CCPositionUnitNormalized, CCPositionReferenceCornerBottomLeft);
    congratulationsLabel.position = ccp(0.5, 0.5);
    
    _currentPenguin = nil;
    [_contentNode stopAction:_followPenguin];
    
    CCActionFollow *follow = [CCActionFollow actionWithTarget:congratulationsLabel worldBoundary:self.boundingBox];
    [_contentNode runAction:follow];
    
    [_contentNode addChild:congratulationsLabel];
    
}

@end

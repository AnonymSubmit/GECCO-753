//
//  Footbot.h
//  MultiAgent
//
//  Created by Jérôme Guzzi on 4/4/11.
//  Copyright 2011 Idsia. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Agent.h"


#define VISION_K 10.0 // 10.0
#define VISION_PHI (1.0/128.0)
#define FOV
#define VELOCITY_ERROR_FACTOR 0.1
#define WHEEL_AXIS_FOOTBOTS 0.135
#define MAX_SPEED_FOOTBOTS 0.3


//#define ANGULAR_SPEED_DOMINATE

extern BOOL footbotAreDumby;

@interface Footbot : Agent {
    
@private
    
    double speedLeft;
    double speedRight;
    double angularSpeed;
    double maxRotationSpeed;
    double rotationTau;
    bool linearSpeedIsContinuos;
    double positionLeft,positionRight;
    
    double maxSpeed;
    double wheelAxis;
    
#ifdef RVO_HOLO
    double D;
    BOOL useHolonomicContraints;
#endif
    
}

@property double speedLeft;
@property double speedRight;
@property double angularSpeed;
@property double positionLeft,positionRight;
@property double rotationTau;
@property double maxRotationSpeed;
@property double maxSpeed;
@property double wheelAxis;

#ifdef RVO_HOLO
@property double D;
@property BOOL useHolonomicContraints;
-(void)setDefaultHolonomicDistance;
#endif



@end


extern double groupSize;

@interface SocialFootbot : Footbot {
    double wellness;
   // double baseEta;
    
    BOOL modulateEta,modulateSpeed,modulateAperture;
    double kEta,kSpeed,kAperture;
    
    BOOL modulateSM;
    
}

@property double wellness;
//@property double baseEta;

@property double kEta,kSpeed,kAperture;
@property BOOL modulateEta,modulateSpeed,modulateAperture,modulateSM;






@end


@interface myopicAgent : Agent
{
    double targetHeadingError;
    NSPoint sensedTargetPosition;
    BOOL targetSensedOneTime;
}

@property double targetHeadingError;


@end
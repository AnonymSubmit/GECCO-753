//
//  Human.h
//  MultiAgent
//
//  Created by Jérôme Guzzi on 6/26/12.
//  Copyright (c) 2012 Idsia. All rights reserved.
//

#import "Agent.h"

@interface Human : Agent
{
@private
    NSPoint motricityVelocity;
    double motricityCycle;
}


-(double)leftFootPosition;
-(double)rightFootPosition;
-(double)leftHandPosition;
-(double)rightHandPosition;

@end


extern BOOL humanStopped;

@interface CarefulHuman : Human

@end
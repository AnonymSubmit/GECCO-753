//
//  Group.h
//  MultiAgent
//
//  Created by Jérôme Guzzi on 6/26/12.
//  Copyright (c) 2012 Idsia. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Agent.h"

@interface Group : NSObject
{
    @private
    NSString *name;
    NSInteger number;
    double radiusStd,optimalSpeedStd,massStd;
    Agent *prototype;
    NSMutableArray *members;
}


@property double radiusStd,optimalSpeedStd,massStd;
@property (copy) NSString *name;
@property NSInteger number;
@property (retain) Agent *prototype;
@property (readonly) NSMutableArray *members;

-(void) distributeSpeed;
-(void) distributeMass;

+(Group *)groupWithName:(NSString *)name andPrototype:(Agent *)prototype;

@end

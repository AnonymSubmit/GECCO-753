//
//  Group.m
//  MultiAgent
//
//  Created by Jérôme Guzzi on 6/26/12.
//  Copyright (c) 2012 Idsia. All rights reserved.
//

#import "Group.h"

@implementation Group

@synthesize radiusStd,optimalSpeedStd,massStd,number,name,prototype,members;

+(Group *)groupWithName:(NSString *)name andPrototype:(Agent *)prototype
{
    Group *group=[[[Group alloc] init] autorelease];
    group.name=name;
    group.prototype=prototype;
    return group;
}

-(id)init
{
    self.radiusStd=0.0;
    self.optimalSpeedStd=0.0;
    members=[[NSMutableArray array] retain];
    return self;
}

-(void)dealloc
{
    [members release];
    self.prototype=nil;
    [super dealloc];
}

-(void)setRadiusStd:(double)value
{
    self.massStd=320.0*value;
}

-(double)radiusStd
{
    return massStd/320.0;
}

+ (NSSet *)keyPathsForValuesAffectingRadiusStd
{
    return [NSSet setWithObjects:@"massStd",nil];
}

-(void) distributeSpeed
{
    if(self.optimalSpeedStd)
    {        
        boost::mt19937 rng ( rand() );
        boost::normal_distribution<> normal(prototype.optimalSpeed,optimalSpeedStd);
        boost::variate_generator<boost::mt19937&, boost::normal_distribution<> > speedDist(rng, normal);  
        for(Agent *a in members)
        {
            a.optimalSpeed=fmax(speedDist(),0.0);
            printf("%.2f ",a.optimalSpeed);
        }
    }
}

-(void) distributeMass
{
    if(self.massStd)
    {
        boost::mt19937 rng(rand());
        boost::uniform_real<> uniform(prototype.mass-self.massStd,prototype.mass+self.massStd);
        boost::variate_generator<boost::mt19937&, boost::uniform_real<> > massDist(rng, uniform);   
        for(Agent *a in members)
        {
            a.mass=massDist();
        }
        
    }
}




@end

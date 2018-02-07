//
//  Experiment.h
//  MultiAgent
//
//  Created by Jérôme Guzzi on 7/2/12.
//  Copyright (c) 2012 Idsia. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum {LINES,CROSS,BUTTERFLY,SLALOM,EDGE,SQUARE,CIRCLE,DOUBLE_CIRCLE,PERIODIC_LINE,DOUBLE_PERIODIC_LINE,RANDOM,LEDs,CIRCLE_WITH_WALLS,ANTIPODE,CIRCLE_WITH_WALL_MIXED,LINE_MIXED,INTERACTIVE,NCCR_LINE,NCCR_CROSS,TRACES,E_PANIC,E_URGENCY,E_URGENCY2,E_CONFUSION} WorldType;

#import "World.h"




@interface Experiment: NSObject
{
    
    World *world;
    
    NSMutableArray *groups;
    NSMutableDictionary *statistics;
    NSString *title;
    BOOL observing;
    
    BOOL statisticsComplete;
    
    NSUInteger statisticsIndex,statisticsLength,statisticsMaxLength;
     int seed;
    
    //Agent *agentPrototype;
    //boost::variate_generator<boost::mt19937&, boost::normal_distribution<> > *optimalSpeed;
    //boost::variate_generator<boost::mt19937&, boost::uniform_real<> > *mass;
}
@property int seed;
-(void)startObserving;
-(void)stopObserving;
-(void)reset;
-(id) initWithWorld:(World *)world;
-(void)resetPrototypeOfGroup:(Group *)g;
-(void)updateStatistics;
-(void) initPath;
-(void) initAgents;
//+(id) loadFromFile:(NSString *)filePath;
+(void)initializeWorld:(World *)world ofType:(int) type;
+(Agent*)agentPrototype;
+(Agent*)myopicAgentPrototype;
+(Footbot*)foobotPrototype;
+(Human*)humanPrototype;
-(NSTimeInterval)minimalControlUpdatePeriod;
-(Group *)groupWithName:(NSString *)name;
-(Group *)defaultGroup;
-(NSNumber *)valueForKey:(NSString *)key inGroup:(Group *)group atIndex:(NSUInteger)index;
-(NSNumber *)valueForKey:(NSString *)key  atIndex:(NSUInteger)index;

-(NSNumber *)maxValueForKey:(NSString *)key inGroup:(Group *)group;
-(NSNumber *)lastValueForKey:(NSString *)key inGroup:(Group *)group;
-(NSNumber *)lastValueForKey:(NSString *)key;

//@property (readonly) Agent *agentPrototype;
@property (retain) NSMutableArray* groups;
@property (retain) NSMutableDictionary *statistics;
@property (assign) World *world;
@property (copy) NSString *title;
@property BOOL statisticsComplete;
@property NSUInteger statisticsIndex,statisticsLength,statisticsMaxLength;

-(NSString *)csvHeader;
-(NSString *)csvLine;
-(NSString *)csvEmptyLine;

@end


@interface Experiment (random)
-(void) moveAgentTargetAtRandomAngle:(Agent *)a;
@end


@interface WorldLine : Experiment {} @end
@interface WorldEdge : Experiment {} @end
@interface WorldSquare :Experiment {} @end
@interface WorldCross : Experiment {} @end
@interface WorldSlalom : Experiment {} @end
@interface WorldCircle : Experiment {} @end
@interface WorldCircleWithWall : Experiment {} @end
@interface WorldDoubleCircle : Experiment {} @end
@interface WorldPeriodicLine : Experiment {} @end
@interface WorldDoublePeriodicLine : Experiment {Wall *leftWall,*rightWall;double width;}
@property double width;
@end
@interface WorldButterfly : Experiment {} @end
@interface WorldRandom : Experiment {} @end
@interface WorldLEDs : Experiment {
    WorldMarker *m1,*m2,*m3,*m4;
    double width;
}
@property double width;
@end
@interface WorldAntipode : Experiment
{
    double radius;
    BOOL isOneWayTarget;
}
@property double radius;
@property BOOL isOneWayTarget;
@end

@interface WorldCircleWithWallMixed : Experiment {} @end

@interface WorldPeriodicLineMixed : Experiment {Wall *leftWall,*rightWall;double width;}
@property double width;
@end

@interface WorldInteractive : Experiment
@end

@interface NCCRCross: WorldLEDs
@end
@interface NCCRLine: WorldDoublePeriodicLine
@end

@interface  TraceExperiment  : Experiment
{
    double width;
}

@property double width;


@end


@interface EmotionPanicExperiment : WorldAntipode

@end

@interface EmotionUrgencyExperiment : WorldLEDs

@end

@interface EmotionUrgency2Experiment : EmotionUrgencyExperiment

@end

@interface EmotionConfusionExperiment : WorldLEDs

@end

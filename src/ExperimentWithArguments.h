//
//  ExperimentWithArguments.h
//  MultiAgent
//
//  Created by Jérôme Guzzi on 1/14/13.
//
//

#import <Foundation/Foundation.h>
#import "World.h"

#ifdef VIDEO
#import "VideoController.h"
#endif




typedef BOOL(^runBlock)(World *world);

@interface ExperimentWithArguments : NSObject
{
    NSMutableArray *experimentStatistics;
    NSMutableArray *runStatistics;
    NSMutableArray *agentStatistics;
    double duration;
    int iterations;
    int saveRunMode;//0=NO, 1 only mean stat, 2 all agents
    int savePathMode;//0=NO, 1 only first run, 2 all runs
    int saveExperimentMode;//0=NO,1 only mean stat, 2 all runs
    int saveTestMode;//0=NO,1 all experiments
    
    World *world;
    Experiment *experiment;
    
    NSFileHandle *experimentFileHandle;
    NSFileHandle *runFileHandle;
    NSFileHandle *pathFileHandle;
    NSFileHandle *testFileHandle;
    
    NSString *experimentName;
    NSString *summaryFileName;
    
    NSMutableDictionary *multipleArguments,*randomArguments;
    
#ifdef VIDEO
    BOOL recordVideo;
    NSString *videoFilePath;
#endif
    
    NSUInteger runIndex;
}

-(void)runWithBlock:(BOOL (^)(World *world))block;

-(void)setup;
-(void)runRun:(NSUInteger)k;
-(void)runOneExperiment;

-(NSString *) csvPathLine;
-(NSString *) csvPathHeader;
-(NSString *) csvRunLineForAgent:(Agent *) agent inGroup:(Group *)group withStatistics:(NSArray *)statistics;
@end


@interface ComparisonExperimentWithArguments : ExperimentWithArguments
{
    uint initialRunIndex;
}

@end


//
//  LineExperiment.h
//  MultiAgent
//
//  Created by Jérôme Guzzi on 1/14/13.
//
//

#import "ExperimentWithArguments.h"




@interface CrossExperiment : ExperimentWithArguments


@end

@interface LineExperiment : ExperimentWithArguments
{
    double orderSamplingPeriod;
    NSUInteger numberOfSamples;
}

@end


@interface CircleExperiment : ExperimentWithArguments


@end

@interface PanicCirclexperiment : CircleExperiment


@end

@interface LineExperimentMixed : LineExperiment

@end

@interface TraceComparisonExperiment : ComparisonExperimentWithArguments

@end

@interface UrgencyCrossExperiment : CrossExperiment


@end

@interface ConfusionCrossExperiment : CrossExperiment


@end
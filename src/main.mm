//
//  main.c
//  MultiAgent
//
//  Created by Jérôme Guzzi on 1/16/13.
//
//

#import <Foundation/Foundation.h>
#import "World.h"
#import "LineExperiment.h"
#import <stdlib.h>

int main (int argc, const char * argv[])
{
    
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    
    NSLog(@"Hello");
    NSDate *begin=[NSDate date];
    
    ExperimentWithArguments *e;
    
    NSScanner *scanner;
    NSArray *arguments=[[NSProcessInfo processInfo] arguments];
    for(NSString *argument in arguments)
    {
        scanner=[NSScanner scannerWithString:argument];
        NSString *experimentName;
        if([scanner scanString:@"experiment=cross" intoString:&experimentName])
        {
            e=[[CrossExperiment alloc] init];
            NSLog(@"Cross");
        }
        else if([scanner scanString:@"experiment=line" intoString:&experimentName])
        {
            e=[[LineExperiment alloc] init];
            NSLog(@"Line");
        }
        else if([scanner scanString:@"experiment=mixedLine" intoString:&experimentName])
        {
            e=[[LineExperimentMixed alloc] init];
            NSLog(@"LineMixed");
        }
        else if([scanner scanString:@"experiment=circle" intoString:&experimentName])
        {
            e=[[CircleExperiment alloc] init];
            NSLog(@"Antipode");
        }
        else if([scanner scanString:@"experiment=trace" intoString:&experimentName])
        {
            e=[[TraceComparisonExperiment alloc] init];
            NSLog(@"Trace");
        }
        else if([scanner scanString:@"experiment=ePanic" intoString:&experimentName])
        {
            e=[[PanicCirclexperiment alloc] init];
            NSLog(@"Panic");
        }
        else if([scanner scanString:@"experiment=eUrgency" intoString:&experimentName])
        {
            e=[[UrgencyCrossExperiment alloc] init];
            NSLog(@"Urgency");
        }
        else if([scanner scanString:@"experiment=eConfusion" intoString:&experimentName])
        {
            e=[[ConfusionCrossExperiment alloc] init];
            NSLog(@"Confusion");
        }
        
    }
    
    if(e)
    {
        [e runOneExperiment];
        [e release];
    }
    
    NSLog(@"Done in %.1f seconds",[[NSDate date] timeIntervalSinceDate:begin]);
    
    [pool drain];
    return 1;
}
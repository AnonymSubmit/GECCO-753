//
//  LineExperiment.m
//  MultiAgent
//
//  Created by Jérôme Guzzi on 1/14/13.
//
//

#import "LineExperiment.h"

#define BLOCK_VARIABLE static //__block
#define MAX_SAFETY_DISTANCE 1.0
#define SAFETY_RESOLUTION 51


static double rPathLength,rThroughput,rHits,rThroughputEfficiency,rEnergyPerLength,rRotationsPerLength,rDeadlocks,rPathDuration,rWellness,rRelativePathLength;
static NSUInteger runSafetyHistogram[SAFETY_RESOLUTION][3];
static NSUInteger runSafetyArea[3];
BLOCK_VARIABLE NSUInteger *histo=(NSUInteger *)runSafetyHistogram;
BLOCK_VARIABLE NSUInteger *area=(NSUInteger *)runSafetyArea;


@implementation CrossExperiment


-(void)setup
{
    //NSLog(@"A %p",world);
    world.type=LEDs;
    experiment=world.experiment;
    world.updatePeriod=1.0/50.0;
    iterations=1;
    duration=30.0;
    Group *footbots=[experiment groupWithName:@"footbot"];
    footbots.number=10;
    Footbot *prototype=(Footbot *)footbots.prototype;
    prototype.socialMargin=0.1;
    prototype.safetyMargin=0.1;
    prototype.controlUpdatePeriod=0.1;
    prototype.sensor=obstructed_vision;
    prototype.positionSensingErrorStd=0.00;
    prototype.aperture=PI;
    prototype.horizon=5;
    prototype.visibilityFOV=PI;
    prototype.visibilityRange=10;
    prototype.pathMargin=0.5;
    prototype.resolution=100;
    
    
    //setup statistics
    
    int s=0;
    int j=0;
    for(;j<3;j++)
    {
        for(;s<SAFETY_RESOLUTION;s++) runSafetyHistogram[s][j]=0;
        runSafetyArea[j]=0;
    }
    
    int i=0;
    
    for(;i<7;i++)
    {
        [runStatistics addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:[self name:i],@"name",nil]];
        [agentStatistics addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:[self name:i],@"name",nil]];
    }
    
    for(i=0;i<SAFETY_RESOLUTION;i++)
    {
        NSString *title;
        if (i==0)  title=@"safety CONTACT";
        else if(i<SAFETY_RESOLUTION-1)title=[NSString stringWithFormat:@"safety [%.4f;%.4f]",i*MAX_SAFETY_DISTANCE/(double)(SAFETY_RESOLUTION-1),(i+1)*MAX_SAFETY_DISTANCE/(double)(SAFETY_RESOLUTION-1)];
        else title=[NSString stringWithFormat:@"safety > %.4f",MAX_SAFETY_DISTANCE];
        
        [runStatistics addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:title,@"name",nil]];
        [agentStatistics addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:title,@"name",nil]];
    }
}

-(double *)value:(NSUInteger)i
{
    double *runValues[8]={&rPathLength,&rRelativePathLength,&rThroughput,&rHits,&rThroughputEfficiency,&rEnergyPerLength,&rRotationsPerLength,&rDeadlocks};
    return runValues[i];
}

-(NSString *)name:(NSUInteger)i
{
    const char *names[8]={"path length","relative path length","throughput","number of collision","throughput efficiency","energy efficiency","rotation smoothness","number of deadlocks"};
    return [NSString stringWithUTF8String:names[i]];
}

-(BOOL)shouldAverage:(NSUInteger)i
{
    const BOOL v[8]={1,1,0,0,1,1,1,0};
    return (BOOL)v[i];
}

-(void)runRun:(NSUInteger) k
{
    
    NSMutableDictionary *stat;
    double value;
    int i=0;
    for(Group *g in experiment.groups)
    {
        for(i=0;i<8;i++)
        {
            stat=[runStatistics objectAtIndex:i];
            [stat removeObjectForKey:g.name];
        }
        memset(histo, 0, sizeof(runSafetyHistogram));
        memset(area, 0, sizeof(runSafetyArea));
    }
    
    [self runWithBlock:^BOOL(World *w) {
        if(savePathMode==2 || (savePathMode==1 && k==0))
        {
            [pathFileHandle writeData:[[NSString stringWithFormat:@"%@\n",[self csvPathLine]] dataUsingEncoding:NSUTF8StringEncoding]];
        }
        int j=0;
        if(w.number>0)
        {
            for(Group *g in experiment.groups)
            {
                if(g.number<1) continue;
                for(Agent *a in g.members)
                {
                    area[j]+=1;
                    NSUInteger index;
                    if(a.minimalDistanceToAgent<0)index=0;
                    else index=floor(a.minimalDistanceToAgent/MAX_SAFETY_DISTANCE*(SAFETY_RESOLUTION-1))+1;
                    if(index>=SAFETY_RESOLUTION)index=SAFETY_RESOLUTION-1;
                    histo[index*3+j]++;
                    
                }
                j++;
                
            }
        }
        
        if(w.cTime>=duration) return YES;
        else return NO;
    }];
    
    
    
    rPathLength=rThroughput=rHits=rThroughputEfficiency=rEnergyPerLength=rRotationsPerLength=rDeadlocks=0.0;
    
    int j=0;
    
    
    for(Group *g in experiment.groups)
    {
        if(g.number==0) continue;
        for(Agent *a in g.members)
        {
            rThroughput=a.numberOfReachedTargets;
            rHits=a.numberOfHits;
            rDeadlocks=a.numberOfDeadlocks;
            rThroughputEfficiency=a.throughputEfficiency;
            rPathLength=a.cumulatedPathLength;//a.pathLength;
            
            
            if(a.cumulatedPathLength>0)
            {
                rEnergyPerLength=a.energy/a.cumulatedPathLength;
                rRotationsPerLength=(a.cumulatedExtraRotation-a.deadlockRotation)/a.cumulatedPathLength;
                rRelativePathLength=a.cumulatedPathLength/a.minimalPathLength;
                
                //NSLog(@"%.2f %.2f %@\n",a.cumulatedPathLength,a.minimalPathLength,g.name);
            }
            else{
                rRelativePathLength=1;
            }
            
            int i=0;
            for(i=0;i<8;i++)
            {
                value=*[self value:i];
                stat=[agentStatistics objectAtIndex:i];
                [stat setValue:[NSNumber numberWithDouble:value] forKey:g.name];
                stat=[runStatistics objectAtIndex:i];
                [stat setValue:[NSNumber numberWithDouble:(value+[[stat valueForKey:g.name] doubleValue])] forKey:g.name];
            }
            
            if(saveRunMode>=2)
            {
                [runFileHandle writeData:[[NSString stringWithFormat:@"%@\n",[self csvRunLineForAgent:a inGroup:g withStatistics:agentStatistics]] dataUsingEncoding:NSUTF8StringEncoding]];
            }
            
        }
        
        int i=0;
        double num=(double)[g number];
        
        // rThroughputEfficiency/=num;
        // rPathLength/=num;
        // rEnergyPerLength/=num;
        // rRotationsPerLength/=num;
        
        
        
        for(;i<8;i++)
        {
            stat=[runStatistics objectAtIndex:i];
            double value=[[stat valueForKey:g.name] doubleValue];
            if([self shouldAverage:i])
            {
                value/=num;
                [stat setValue:[NSNumber numberWithDouble:value] forKey:g.name];
            }
            //stat=[experimentStatistics objectAtIndex:i];
            //[stat setValue:[NSNumber numberWithDouble:(value+[[stat valueForKey:g.name] doubleValue])] forKey:g.name];
        }
        
        for(i=0;i<SAFETY_RESOLUTION;i++)
        {
            value=runSafetyHistogram[i][j]/(double)runSafetyArea[j];
            stat=[runStatistics objectAtIndex:i+7];
            [stat setValue:[NSNumber numberWithDouble:value] forKey:g.name];
            //stat=[experimentStatistics objectAtIndex:i+7];
            //[stat setValue:[NSNumber numberWithDouble:(value+[[stat valueForKey:g.name] doubleValue])] forKey:g.name];
        }
        j++;
        
        for(i=0;i<[runStatistics count];i++)
        {
            double value=[[[runStatistics objectAtIndex:i] valueForKey:g.name] doubleValue];
            stat=[experimentStatistics objectAtIndex:2*i];
            [stat setValue:[NSNumber numberWithDouble:(value+[[stat valueForKey:g.name] doubleValue])] forKey:g.name];
            stat=[experimentStatistics objectAtIndex:2*i+1];
            [stat setValue:[NSNumber numberWithDouble:(value*value+[[stat valueForKey:g.name] doubleValue])] forKey:g.name];
        }
    }
}


@end


@implementation CircleExperiment




-(double *)value:(NSUInteger)i
{
    double *runValues[8]={&rPathDuration,&rPathLength,&rThroughput,&rHits,&rThroughputEfficiency,&rEnergyPerLength,&rRotationsPerLength,&rDeadlocks};
    return runValues[i];
}

-(NSString *)name:(NSUInteger)i
{
    const char *names[8]={"pathDuration","path length","throughput","number of collision","throughput efficiency","energy efficiency","rotation smoothness","number of deadlocks"};
    return [NSString stringWithUTF8String:names[i]];
}

-(BOOL)shouldAverage:(NSUInteger)i
{
    const BOOL v[8]={1,1,0,0,1,1,1,0};
    return (BOOL)v[i];
}

-(void)setup
{
    world.type=ANTIPODE;
    experiment=world.experiment;
    world.updatePeriod=1.0/20.0;
    iterations=1;
    duration=300.0;
    
    Group *footbots=[experiment groupWithName:@"footbot"];
    footbots.number=50;
    Footbot *prototype=(Footbot *)footbots.prototype;
    prototype.socialMargin=0.1;
    prototype.safetyMargin=0.1;
    prototype.controlUpdatePeriod=0.1;
    prototype.sensor=obstructed_vision;
    prototype.positionSensingErrorStd=0.00;
    prototype.aperture=PI;
    prototype.horizon=20;
    prototype.visibilityFOV=PI;
    prototype.visibilityRange=20;
    prototype.pathMargin=0.5;
    prototype.resolution=100;
    
    
    histo=(NSUInteger *)runSafetyHistogram;
    area=(NSUInteger *)runSafetyArea;
    
    
    int s=0;
    int j=0;
    for(;j<3;j++)
    {
        for(;s<SAFETY_RESOLUTION;s++) runSafetyHistogram[s][j]=0;
        runSafetyArea[j]=0;
    }
    
    int i=0;
    
    for(;i<8;i++)
    {
        //[experimentStatistics addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:names[i]],@"name",nil]];
        [runStatistics addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:[self name:i],@"name",nil]];
        [agentStatistics addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:[self name:i],@"name",nil]];
    }
    
    for(i=0;i<SAFETY_RESOLUTION;i++)
    {
        NSString *title;
        if (i==0)  title=@"safety CONTACT";
        else if(i<SAFETY_RESOLUTION-1)title=[NSString stringWithFormat:@"safety [%.4f;%.4f]",i*MAX_SAFETY_DISTANCE/(double)(SAFETY_RESOLUTION-1),(i+1)*MAX_SAFETY_DISTANCE/(double)(SAFETY_RESOLUTION-1)];
        else title=[NSString stringWithFormat:@"safety > %.4f",MAX_SAFETY_DISTANCE];
        
        //[experimentStatistics addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:title,@"name",nil]];
        [runStatistics addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:title,@"name",nil]];
        [agentStatistics addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:title,@"name",nil]];
    }
    
}

-(void)runRun:(NSUInteger) k
{
    
    
    
    NSMutableDictionary *stat;
    double value;
    int i=0;
    BLOCK_VARIABLE BOOL allAgentsHaveArrived;
    
    for(Group *g in experiment.groups)
    {
        for(i=0;i<8;i++)
        {
            stat=[runStatistics objectAtIndex:i];
            [stat removeObjectForKey:g.name];
        }
        memset(histo, 0, sizeof(runSafetyHistogram));
        memset(area, 0, sizeof(runSafetyArea));
    }
    
    
    
    [self runWithBlock:^BOOL(World *w)
     {
         
         allAgentsHaveArrived=YES;
         if(savePathMode==2 || (savePathMode==1 && k==0))
         {
             [pathFileHandle writeData:[[NSString stringWithFormat:@"%@\n",[self csvPathLine]] dataUsingEncoding:NSUTF8StringEncoding]];
         }
         int j=0;
         if(w.number>0)
         {
             for(Group *g in experiment.groups)
             {
                 if(g.number<1) continue;
                 for(Agent *a in g.members)
                 {
                     if(a.state==arrivedState)continue; //DO not count the time when it is waiting for the others to finish
                     area[j]+=1;
                     NSUInteger index;
                     if(a.minimalDistanceToAgent<0)index=0;
                     else index=floor(a.minimalDistanceToAgent/MAX_SAFETY_DISTANCE*(SAFETY_RESOLUTION-1))+1;
                     if(index>=SAFETY_RESOLUTION)index=SAFETY_RESOLUTION-1;
                     histo[index*3+j]++;
                     if(a.state!=arrivedState) allAgentsHaveArrived=NO;
                 }
                 j++;
                 
             }
         }
         
         
         
         if(world.cTime>=duration || allAgentsHaveArrived) return YES;
         else return NO;
     }
     ];
    
    
    
    rPathLength=rThroughput=rHits=rThroughputEfficiency=rEnergyPerLength=rRotationsPerLength=rDeadlocks=0.0;
    
    int j=0;
    
    
    
    
    for(Group *g in experiment.groups)
    {
        if(g.number==0) continue;
        for(Agent *a in g.members)
        {
            // first target is at starting point!!!!
            rThroughput=a.numberOfReachedTargets-1;
            rHits=a.numberOfHits;
            rDeadlocks=a.numberOfDeadlocks;
            rThroughputEfficiency=a.throughputEfficiency;
            rPathLength=a.pathLength;
            rPathDuration=a.pathDuration;
            
            if(a.pathLength>0)
            {
                rEnergyPerLength=a.energy/a.pathLength;
                rRotationsPerLength=(a.cumulatedExtraRotation-a.deadlockRotation)/a.pathLength;
            }
            
            int i=0;
            for(i=0;i<8;i++)
            {
                value=*[self value:i];
                stat=[agentStatistics objectAtIndex:i];
                [stat setValue:[NSNumber numberWithDouble:value] forKey:g.name];
                stat=[runStatistics objectAtIndex:i];
                [stat setValue:[NSNumber numberWithDouble:(value+[[stat valueForKey:g.name] doubleValue])] forKey:g.name];
            }
            
            if(saveRunMode>=2)
            {
                [runFileHandle writeData:[[NSString stringWithFormat:@"%@\n",[self csvRunLineForAgent:a inGroup:g withStatistics:agentStatistics]] dataUsingEncoding:NSUTF8StringEncoding]];
            }
            
        }
        
        int i=0;
        double num=(double)[g number];
        
        // rThroughputEfficiency/=num;
        // rPathLength/=num;
        // rEnergyPerLength/=num;
        // rRotationsPerLength/=num;
        
        
        
        for(;i<8;i++)
        {
            stat=[runStatistics objectAtIndex:i];
            double value=[[stat valueForKey:g.name] doubleValue];
            if([self shouldAverage:i])
            {
                value/=num;
                [stat setValue:[NSNumber numberWithDouble:value] forKey:g.name];
            }
            //stat=[experimentStatistics objectAtIndex:i];
            //[stat setValue:[NSNumber numberWithDouble:(value+[[stat valueForKey:g.name] doubleValue])] forKey:g.name];
        }
        
        for(i=0;i<SAFETY_RESOLUTION;i++)
        {
            value=runSafetyHistogram[i][j]/(double)runSafetyArea[j];
            stat=[runStatistics objectAtIndex:i+8];
            [stat setValue:[NSNumber numberWithDouble:value] forKey:g.name];
            //stat=[experimentStatistics objectAtIndex:i+8];
            //[stat setValue:[NSNumber numberWithDouble:(value+[[stat valueForKey:g.name] doubleValue])] forKey:g.name];
        }
        j++;
        
        for(i=0;i<[runStatistics count];i++)
        {
            double value=[[[runStatistics objectAtIndex:i] valueForKey:g.name] doubleValue];
            stat=[experimentStatistics objectAtIndex:2*i];
            [stat setValue:[NSNumber numberWithDouble:(value+[[stat valueForKey:g.name] doubleValue])] forKey:g.name];
            stat=[experimentStatistics objectAtIndex:2*i+1];
            [stat setValue:[NSNumber numberWithDouble:(value*value+[[stat valueForKey:g.name] doubleValue])] forKey:g.name];
        }
    }
    
}


@end

@implementation PanicCirclexperiment

-(void)setup
{
    world.type=E_PANIC;
    experiment=world.experiment;
    world.updatePeriod=1.0/20.0;
    iterations=1;
    duration=100.0;
    
    
    
    
    histo=(NSUInteger *)runSafetyHistogram;
    area=(NSUInteger *)runSafetyArea;
    
    
    int s=0;
    int j=0;
    for(;j<3;j++)
    {
        for(;s<SAFETY_RESOLUTION;s++) runSafetyHistogram[s][j]=0;
        runSafetyArea[j]=0;
    }
    
    int i=0;
    
    for(;i<8;i++)
    {
        [runStatistics addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:[self name:i],@"name",nil]];
        [agentStatistics addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:[self name:i],@"name",nil]];
    }
    
    for(i=0;i<SAFETY_RESOLUTION;i++)
    {
        NSString *title;
        if (i==0)  title=@"safety CONTACT";
        else if(i<SAFETY_RESOLUTION-1)title=[NSString stringWithFormat:@"safety [%.4f;%.4f]",i*MAX_SAFETY_DISTANCE/(double)(SAFETY_RESOLUTION-1),(i+1)*MAX_SAFETY_DISTANCE/(double)(SAFETY_RESOLUTION-1)];
        else title=[NSString stringWithFormat:@"safety > %.4f",MAX_SAFETY_DISTANCE];
        
        [runStatistics addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:title,@"name",nil]];
        [agentStatistics addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:title,@"name",nil]];
    }
    
}


@end


@implementation LineExperiment


-(double *)value:(NSUInteger)i
{
    double *runValues[6]={&rPathLength,&rHits,&rThroughputEfficiency,&rEnergyPerLength,&rRotationsPerLength,&rDeadlocks};
    return runValues[i];
}

-(NSString *)name:(NSUInteger)i
{
    const char *names[6]={"path length","number of collision","throughput efficiency","energy efficiency","rotation smoothness","number of deadlocks"};
    return [NSString stringWithUTF8String:names[i]];
}

-(BOOL)shouldAverage:(NSUInteger)i
{
    const BOOL v[6]={1,0,1,1,1,0};
    return (BOOL)v[i];
}


-(void)setup
{
    world.type=DOUBLE_PERIODIC_LINE;
    experiment=world.experiment;
    world.updatePeriod=1.0/20.0;
    iterations=1;
    duration=90.0;
    
    [experiment groupWithName:@"agent"].number=0;
    [experiment groupWithName:@"human"].number=0;
    
    Group *footbots=[experiment groupWithName:@"footbot"];
    footbots.number=10;
    Footbot *prototype=(Footbot *)footbots.prototype;
    prototype.socialMargin=0.1;
    prototype.safetyMargin=0.1;
    prototype.controlUpdatePeriod=0.1;
    prototype.sensor=obstructed_vision;
    prototype.positionSensingErrorStd=0.00;
    prototype.aperture=PI;
    prototype.horizon=5;
    prototype.visibilityFOV=PI;
    prototype.visibilityRange=10;
    prototype.pathMargin=0.5;
    prototype.resolution=100;
    
    int i=0;
    
    orderSamplingPeriod=1;
    numberOfSamples=duration/orderSamplingPeriod;
    
    
    for(;i<6;i++)
    {
        [runStatistics addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:[self name:i],@"name",nil]];
        [agentStatistics addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:[self name:i],@"name",nil]];
    }
    
    for(i=0;i<numberOfSamples;i++)
    {
        NSString *title=[NSString stringWithFormat:@"order at %.1f",i*orderSamplingPeriod];
        [runStatistics addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:title,@"name",nil]];
    }
}

-(void)runRun:(NSUInteger) k
{
    BLOCK_VARIABLE double nextSamplingTime=0;
    BLOCK_VARIABLE NSUInteger sample=0;
    
    double runEff[3];
    double runNEff[3];
    
    BLOCK_VARIABLE double *eff=(double*)runEff;
    BLOCK_VARIABLE double *neff=(double*)runNEff;
    
    NSMutableDictionary *stat;
    
    int i=0;
    
    Group *footbots=[experiment groupWithName:@"footbot"];
    
    for(Group *g in experiment.groups)
    {
        for(i=0;i<6;i++)
        {
            stat=[runStatistics objectAtIndex:i];
            [stat removeObjectForKey:g.name];
        }
    }
    
    memset(runEff, 0, sizeof(runEff));
    memset(runNEff, 0, sizeof(runNEff));
    sample=0;
    nextSamplingTime=0;
    
    [self runWithBlock:^BOOL(World *w)
     {
         if(savePathMode==2 || (savePathMode==1 && k==0))
         {
             [pathFileHandle writeData:[[NSString stringWithFormat:@"%@\n",[self csvPathLine]] dataUsingEncoding:NSUTF8StringEncoding]];
         }
         
         int j=0;
         for(Group *g in experiment.groups)
         {
             double ne=0;
             for(Agent *a in g.members)
             {
                 //target up
                 if(a.type==0) ne+=a.velocity.x/a.optimalSpeed;
                 else ne+=-a.velocity.x/a.optimalSpeed;
             }
             eff[j]+=ne;
             neff[j]+=[g.members count];
             j++;
         }
         
         if(w.cTime>nextSamplingTime && sample<numberOfSamples)
         {
             [w updateOrder];
             [[runStatistics objectAtIndex:sample+6] setValue:[NSNumber numberWithDouble:w.order] forKey:footbots.name];
             sample++;
             nextSamplingTime+=orderSamplingPeriod;
         }
         
         if(w.cTime>=duration) return YES;
         else return NO;
     }
     ];
    
    
    
    rPathLength=rThroughput=rHits=rThroughputEfficiency=rEnergyPerLength=rRotationsPerLength=rDeadlocks=0.0;
    
    int j=-1;
    
    
    
    
    for(Group *g in experiment.groups)
    {
        j++;
        if(g.number==0) continue;
        for(Agent *a in g.members)
        {
            //rThroughput=a.numberOfReachedTargets;
            rHits=a.numberOfHits;
            rDeadlocks=a.numberOfDeadlocks;
            //rThroughputEfficiency=a.throughputEfficiency;
            rPathLength=a.pathLength;
            
            if(a.pathLength>0)
            {
                rEnergyPerLength=a.energy/a.pathLength;
                rRotationsPerLength=(a.cumulatedRotation-a.deadlockRotation)/a.pathLength; //should take out the initial rotation
            }
            
            int l=0;
            for(;l<6;l++)
            {
                
                if(l==2)continue;
                
                double value=*[self value:l];
                
                //printf("%d %p\n",l, runValues[l]);
                //double *p=runValues[l];
                //value=p[0];
                stat=[agentStatistics objectAtIndex:l];
                [stat setValue:[NSNumber numberWithDouble:value] forKey:g.name];
                stat=[runStatistics objectAtIndex:l];
                [stat setValue:[NSNumber numberWithDouble:(value+[[stat valueForKey:g.name] doubleValue])] forKey:g.name];
            }
            
            if(saveRunMode>=2)
            {
                [runFileHandle writeData:[[NSString stringWithFormat:@"%@\n",[self csvRunLineForAgent:a inGroup:g withStatistics:agentStatistics]] dataUsingEncoding:NSUTF8StringEncoding]];
            }
            
        }
        
        int i=0;
        double num=(double)[g number];
        
        // rThroughputEfficiency/=num;
        // rPathLength/=num;
        // rEnergyPerLength/=num;
        // rRotationsPerLength/=num;
        
        
        
        for(;i<6;i++)
        {
            double value;
            stat=[runStatistics objectAtIndex:i];
            if(i==2)
            {
                value=eff[j]/neff[j];
                [stat setValue:[NSNumber numberWithDouble:value] forKey:g.name];
            }
            else
            {
                value=[[stat valueForKey:g.name] doubleValue];
                if([self shouldAverage:i])
                {
                    value/=num;
                    [stat setValue:[NSNumber numberWithDouble:value] forKey:g.name];
                }
            }
            //stat=[experimentStatistics objectAtIndex:i];
            //[stat setValue:[NSNumber numberWithDouble:(value+[[stat valueForKey:g.name] doubleValue])] forKey:g.name];
        }
        
        /*
         for(i=0;i<numberOfSamples;i++)
         {
         double value=[[[runStatistics objectAtIndex:i+6] valueForKey:g.name] doubleValue];
         stat=[experimentStatistics objectAtIndex:i+6];
         [stat setValue:[NSNumber numberWithDouble:(value+[[stat valueForKey:g.name] doubleValue])] forKey:g.name];
         }
         */
        
        
        for(i=0;i<[runStatistics count];i++)
        {
            double value=[[[runStatistics objectAtIndex:i] valueForKey:g.name] doubleValue];
            stat=[experimentStatistics objectAtIndex:2*i];
            [stat setValue:[NSNumber numberWithDouble:(value+[[stat valueForKey:g.name] doubleValue])] forKey:g.name];
            stat=[experimentStatistics objectAtIndex:2*i+1];
            [stat setValue:[NSNumber numberWithDouble:(value*value+[[stat valueForKey:g.name] doubleValue])] forKey:g.name];
        }
        
    }
    
}

@end

@implementation LineExperimentMixed


-(double *)value:(NSUInteger)i
{
    double *runValues[7]={&rPathLength,&rHits,&rThroughputEfficiency,&rEnergyPerLength,&rRotationsPerLength,&rDeadlocks,&rWellness};
    return runValues[i];
}

-(NSString *)name:(NSUInteger)i
{
    const char *names[7]={"path length","number of collision","throughput efficiency","energy efficiency","rotation smoothness","number of deadlocks","wellness"};
    return [NSString stringWithUTF8String:names[i]];
}

-(BOOL)shouldAverage:(NSUInteger)i
{
    const BOOL v[7]={1,0,1,1,1,0,1};
    return (BOOL)v[i];
}


-(void)setup
{
    world.type=LINE_MIXED;
    experiment=world.experiment;
    
    
    world.updatePeriod=1.0/20.0;
    iterations=1;
    duration=30.0;
    
    
    [experiment groupWithName:@"agents"].number=0;
    [experiment groupWithName:@"human"].number=0;
    [experiment groupWithName:@"foobot"].number=0;
    
    Group *footbots=[experiment groupWithName:@"socialFootbot#2"];
    footbots.number=30;
    Footbot *prototype=(Footbot *)footbots.prototype;
    prototype.socialMargin=0.1;
    prototype.safetyMargin=0.1;
    prototype.controlUpdatePeriod=0.1;
    prototype.sensor=obstructed_vision;
    prototype.positionSensingErrorStd=0.00;
    prototype.aperture=HALF_PI;
    prototype.horizon=5;
    prototype.visibilityFOV=1;
    prototype.visibilityRange=10;
    prototype.pathMargin=0.5;
    prototype.resolution=100;
    
    Group *footbots2=[experiment groupWithName:@"socialFootbot#3"];
    footbots2.number=30;
    prototype=(Footbot *)footbots2.prototype;
    prototype.socialMargin=0.1;
    prototype.safetyMargin=0.1;
    prototype.controlUpdatePeriod=0.1;
    prototype.sensor=obstructed_vision;
    prototype.positionSensingErrorStd=0.00;
    prototype.aperture=HALF_PI;
    prototype.horizon=5;
    prototype.visibilityFOV=1;
    prototype.visibilityRange=10;
    prototype.pathMargin=0.5;
    prototype.resolution=100;
    
    int i=0;
    
    orderSamplingPeriod=1;
    numberOfSamples=duration/orderSamplingPeriod;
    
    
    for(;i<7;i++)
    {
        //[experimentStatistics addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:names[i]],@"name",nil]];
        [runStatistics addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:[self name:i],@"name",nil]];
        [agentStatistics addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:[self name:i],@"name",nil]];
    }
    
    for(i=0;i<numberOfSamples;i++)
    {
        NSString *title=[NSString stringWithFormat:@"line order at %.1f",i*orderSamplingPeriod];
        //[experimentStatistics addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:title,@"name",nil]];
        [runStatistics addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:title,@"name",nil]];
    }
    
    for(i=0;i<numberOfSamples;i++)
    {
        NSString *title=[NSString stringWithFormat:@"group order at %.1f",i*orderSamplingPeriod];
        //[experimentStatistics addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:title,@"name",nil]];
        [runStatistics addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:title,@"name",nil]];
    }
    
    for(i=0;i<numberOfSamples;i++)
    {
        NSString *title=[NSString stringWithFormat:@"group number at %.1f",i*orderSamplingPeriod];
        //[experimentStatistics addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:title,@"name",nil]];
        [runStatistics addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:title,@"name",nil]];
    }
    
    for(NSMutableDictionary *s in runStatistics)
    {
        NSString *name=[s valueForKey:@"name"];
        [experimentStatistics addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:name,@"name",nil]];
        [experimentStatistics addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:[NSString stringWithFormat:@"std %@",name],@"name",nil]];
    }
}

-(void)runRun:(NSUInteger) k
{
    BLOCK_VARIABLE double nextSamplingTime=0;
    BLOCK_VARIABLE NSUInteger sample=0;
    
    double runEff[3];
    double runNEff[3];
    
    BLOCK_VARIABLE double *eff=(double*)runEff;
    BLOCK_VARIABLE double *neff=(double*)runNEff;
    
    NSMutableDictionary *stat;
    double value;
    int i=0;
    
    Group *footbots=[experiment groupWithName:@"footbot"];
    
    for(Group *g in experiment.groups)
    {
        for(i=0;i<6;i++)
        {
            stat=[runStatistics objectAtIndex:i];
            [stat removeObjectForKey:g.name];
        }
    }
    
    memset(runEff, 0, sizeof(runEff));
    memset(runNEff, 0, sizeof(runNEff));
    sample=0;
    nextSamplingTime=0;
    
    [self runWithBlock:^BOOL(World *w)
     {
         if(savePathMode==2 || (savePathMode==1 && k==0))
         {
             [pathFileHandle writeData:[[NSString stringWithFormat:@"%@\n",[self csvPathLine]] dataUsingEncoding:NSUTF8StringEncoding]];
         }
         int j=0;
         for(Group *g in experiment.groups)
         {
             if([g.members count]==0)
             {
                 j++;
                 continue;
             }
             double ne=0;
             for(Agent *a in g.members)
             {
                 //target up
                 ne+=a.velocity.x/a.optimalSpeed;
             }
             eff[j]+=ne;
             neff[j]+=[g.members count];
             j++;
         }
         
         if(w.cTime>nextSamplingTime && sample<numberOfSamples)
         {
             [w updateOrder];
             [w updateOrderH];
             [[runStatistics objectAtIndex:sample+7] setValue:[NSNumber numberWithDouble:w.order] forKey:footbots.name];
             [[runStatistics objectAtIndex:sample+7+numberOfSamples] setValue:[NSNumber numberWithDouble:w.orderH] forKey:footbots.name];
             
             
             uint n=(uint)w.orderN;
             
             n=(((n-1)/2)+1)*2;
             
             [[runStatistics objectAtIndex:sample+7+2*numberOfSamples] setValue:[NSNumber numberWithInt:n] forKey:footbots.name];
             
             sample++;
             nextSamplingTime+=orderSamplingPeriod;
         }
         
         if(world.cTime>=duration) return YES;
         else return NO;
     }
     ];
    
    
    
    rPathLength=rThroughput=rHits=rThroughputEfficiency=rEnergyPerLength=rRotationsPerLength=rDeadlocks=rWellness=0.0;
    
    int j=-1;
    
    
    
    
    for(Group *g in experiment.groups)
    {
        j++;
        if(g.number==0) continue;
        for(SocialFootbot *a in g.members)
        {
            //rThroughput=a.numberOfReachedTargets;
            rHits=a.numberOfHits;
            rDeadlocks=a.numberOfDeadlocks;
            //rThroughputEfficiency=a.throughputEfficiency;
            rPathLength=a.pathLength;
            
            rWellness=a.wellness;
            
            if(a.pathLength>0)
            {
                rEnergyPerLength=a.energy/a.pathLength;
                rRotationsPerLength=(a.cumulatedRotation-a.deadlockRotation)/a.pathLength; //should take out the initial rotation
            }
            
            int i=0;
            for(i=0;i<7;i++)
            {
                if(i==2)continue;
                
                value=*[self value:i];
                stat=[agentStatistics objectAtIndex:i];
                [stat setValue:[NSNumber numberWithDouble:value] forKey:g.name];
                stat=[runStatistics objectAtIndex:i];
                [stat setValue:[NSNumber numberWithDouble:(value+[[stat valueForKey:g.name] doubleValue])] forKey:g.name];
            }
            
            if(saveRunMode>=2)
            {
                [runFileHandle writeData:[[NSString stringWithFormat:@"%@\n",[self csvRunLineForAgent:a inGroup:g withStatistics:agentStatistics]] dataUsingEncoding:NSUTF8StringEncoding]];
            }
            
        }
        
        int i=0;
        double num=(double)[g number];
        
        // rThroughputEfficiency/=num;
        // rPathLength/=num;
        // rEnergyPerLength/=num;
        // rRotationsPerLength/=num;
        
        
        
        for(;i<7;i++)
        {
            double value;
            stat=[runStatistics objectAtIndex:i];
            if(i==2)
            {
                value=eff[j]/neff[j];
                [stat setValue:[NSNumber numberWithDouble:value] forKey:g.name];
            }
            else
            {
                value=[[stat valueForKey:g.name] doubleValue];
                if([self shouldAverage:i])
                {
                    value/=num;
                    [stat setValue:[NSNumber numberWithDouble:value] forKey:g.name];
                }
            }
            //stat=[experimentStatistics objectAtIndex:i];
            //[stat setValue:[NSNumber numberWithDouble:(value+[[stat valueForKey:g.name] doubleValue])] forKey:g.name];
        }
        
        /*
         for(i=0;i<numberOfSamples;i++)
         {
         double value=[[[runStatistics objectAtIndex:i+6] valueForKey:g.name] doubleValue];
         stat=[experimentStatistics objectAtIndex:i+6];
         [stat setValue:[NSNumber numberWithDouble:(value+[[stat valueForKey:g.name] doubleValue])] forKey:g.name];
         }
         */
        
        
        for(i=0;i<[runStatistics count];i++)
        {
            double value=[[[runStatistics objectAtIndex:i] valueForKey:g.name] doubleValue];
            stat=[experimentStatistics objectAtIndex:2*i];
            [stat setValue:[NSNumber numberWithDouble:(value+[[stat valueForKey:g.name] doubleValue])] forKey:g.name];
            stat=[experimentStatistics objectAtIndex:2*i+1];
            [stat setValue:[NSNumber numberWithDouble:(value*value+[[stat valueForKey:g.name] doubleValue])] forKey:g.name];
        }
        
    }
    
    
}



@end



@implementation TraceComparisonExperiment

-(double *)value:(NSUInteger)i
{
    double *runValues[8]={&rPathDuration,&rPathLength,&rThroughput,&rHits,&rThroughputEfficiency,&rEnergyPerLength,&rRotationsPerLength,&rDeadlocks};
    return runValues[i];
}

-(NSString *)name:(NSUInteger)i
{
    const char *names[5]={"path length","number of collision","throughput efficiency","energy efficiency","rotation smoothness"};
    return [NSString stringWithUTF8String:names[i]];
}

-(BOOL)shouldAverage:(NSUInteger)i
{
    const BOOL v[8]={1,1,1,1,1};
    return (BOOL)v[i];
}

-(void)setup
{
    world.type=TRACES;
    experiment=world.experiment;
    world.updatePeriod=1.0/20.0;
    iterations=1;
    duration=3.0;
    
    Group *agents=[experiment groupWithName:@"agent"];
    agents.number=2;
    Agent *prototype=(Agent *)agents.prototype;
    prototype.socialMargin=0.02;
    prototype.safetyMargin=0.02;
    
    int i=0;
    
    for(;i<5;i++)
    {
        [runStatistics addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:[self name:i],@"name",nil]];
        [agentStatistics addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:[self name:i],@"name",nil]];
    }
    
}

-(void)runRun:(NSUInteger) k
{
    
    NSMutableDictionary *stat;
    double value;
    
    int i=0;
    
    for(Group *g in experiment.groups)
        {
            for(i=0;i<5;i++)
            {
                stat=[runStatistics objectAtIndex:i];
                [stat removeObjectForKey:g.name];
            }
        }
        
    
    if(savePathMode==2 || (savePathMode==1 && k==0))
    {
        [pathFileHandle writeData:[[NSString stringWithFormat:@"%@\n",[self csvPathLine]] dataUsingEncoding:NSUTF8StringEncoding]];
    }
    
   
    
    
        [self runWithBlock:^BOOL(World *w)
         {
             if(savePathMode==2 || (savePathMode==1 && k==0))
             {
                 [pathFileHandle writeData:[[NSString stringWithFormat:@"%@\n",[self csvPathLine]] dataUsingEncoding:NSUTF8StringEncoding]];
             }
             
             
             if(world.cTime>=duration) return YES;
             else return NO;
         }
         ];
        
        
        rPathLength=rThroughputEfficiency=rEnergyPerLength=rRotationsPerLength=0.0;
        
        for(Group *g in experiment.groups)
        {
            if(g.number==0) continue;
            for(Agent *a in g.members)
            {
                rHits=a.numberOfHits;
                rPathLength=a.pathLength;
                rThroughputEfficiency=a.meanEfficacity;
                
                if(a.pathLength>0)
                {
                    rEnergyPerLength=a.energy/a.pathLength;
                    rRotationsPerLength=(a.cumulatedExtraRotation-a.deadlockRotation)/a.pathLength;
                }
                
                int i=0;
                for(i=0;i<5;i++)
                {
                    value=*[self value:i];
                    stat=[agentStatistics objectAtIndex:i];
                    [stat setValue:[NSNumber numberWithDouble:value] forKey:g.name];
                    stat=[runStatistics objectAtIndex:i];
                    [stat setValue:[NSNumber numberWithDouble:(value+[[stat valueForKey:g.name] doubleValue])] forKey:g.name];
                }
                
                if(saveRunMode>=2)
                {
                    [runFileHandle writeData:[[NSString stringWithFormat:@"%@\n",[self csvRunLineForAgent:a inGroup:g withStatistics:agentStatistics]] dataUsingEncoding:NSUTF8StringEncoding]];
                }
                
            }
            
            int i=0;
            double num=(double)[g number];
            
            for(;i<5;i++)
            {
                stat=[runStatistics objectAtIndex:i];
                double value=[[stat valueForKey:g.name] doubleValue];
                if([self shouldAverage:i])
                {
                    value/=num;
                    [stat setValue:[NSNumber numberWithDouble:value] forKey:g.name];
                }
            }
            
            
         
        }
        
         
    
}

@end


@implementation UrgencyCrossExperiment

-(void)setup
{
    world.type=E_URGENCY2;
    experiment=world.experiment;
    world.updatePeriod=1.0/20.0;
    iterations=1;
    duration=900.0;

    
    
    //setup statistics
    
    int s=0;
    int j=0;
    for(;j<3;j++)
    {
        for(;s<SAFETY_RESOLUTION;s++) runSafetyHistogram[s][j]=0;
        runSafetyArea[j]=0;
    }
    
    int i=0;
    
    for(;i<7;i++)
    {
        [runStatistics addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:[self name:i],@"name",nil]];
        [agentStatistics addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:[self name:i],@"name",nil]];
    }
    
    for(i=0;i<SAFETY_RESOLUTION;i++)
    {
        NSString *title;
        if (i==0)  title=@"safety CONTACT";
        else if(i<SAFETY_RESOLUTION-1)title=[NSString stringWithFormat:@"safety [%.4f;%.4f]",i*MAX_SAFETY_DISTANCE/(double)(SAFETY_RESOLUTION-1),(i+1)*MAX_SAFETY_DISTANCE/(double)(SAFETY_RESOLUTION-1)];
        else title=[NSString stringWithFormat:@"safety > %.4f",MAX_SAFETY_DISTANCE];
        
        [runStatistics addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:title,@"name",nil]];
        [agentStatistics addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:title,@"name",nil]];
    }
}


@end


@implementation ConfusionCrossExperiment

-(void)setup
{
    //NSLog(@"A %p",world);
    world.type=E_CONFUSION;
    experiment=world.experiment;
    world.updatePeriod=1.0/20.0;
    iterations=1;
    duration=900.0;

    
    
    //setup statistics
    
    int s=0;
    int j=0;
    for(;j<3;j++)
    {
        for(;s<SAFETY_RESOLUTION;s++) runSafetyHistogram[s][j]=0;
        runSafetyArea[j]=0;
    }
    
    int i=0;
    
    for(;i<7;i++)
    {
        [runStatistics addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:[self name:i],@"name",nil]];
        [agentStatistics addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:[self name:i],@"name",nil]];
    }
    
    for(i=0;i<SAFETY_RESOLUTION;i++)
    {
        NSString *title;
        if (i==0)  title=@"safety CONTACT";
        else if(i<SAFETY_RESOLUTION-1)title=[NSString stringWithFormat:@"safety [%.4f;%.4f]",i*MAX_SAFETY_DISTANCE/(double)(SAFETY_RESOLUTION-1),(i+1)*MAX_SAFETY_DISTANCE/(double)(SAFETY_RESOLUTION-1)];
        else title=[NSString stringWithFormat:@"safety > %.4f",MAX_SAFETY_DISTANCE];
        
        [runStatistics addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:title,@"name",nil]];
        [agentStatistics addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:title,@"name",nil]];
    }
}


@end

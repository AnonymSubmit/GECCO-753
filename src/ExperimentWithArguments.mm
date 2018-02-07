//
//  ExperimentWithArguments.m
//  MultiAgent
//
//  Created by Jérôme Guzzi on 1/14/13.
//
//

#import "ExperimentWithArguments.h"


#ifdef CLUSTER
NSString *homeDir=@"/homeb/guzzi/ClusterExperiments";
#else
NSString *homeDir=@"/Users/jerome/Desktop/CocoaExperiments";
#endif




@implementation ExperimentWithArguments


-(id)init
{
    self=[super init];
    world=[World world];
    saveRunMode=NO;
    savePathMode=NO;
    saveExperimentMode=1;
    saveTestMode=1;
    experimentStatistics=[[NSMutableArray array] retain];
    runStatistics=[[NSMutableArray array] retain];
    agentStatistics=[[NSMutableArray array] retain];
#ifdef VIDEO
    recordVideo=NO;
#endif
    return self;
}

-(void)setup
{
    
    world.type=LEDs;
    experiment=world.experiment;
    world.updatePeriod=1.0/20.0;
    iterations=1;
    duration=60.0;
}

-(void)runRun:(NSUInteger) k
{
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
}

-(void)runWithBlock:(BOOL (^)(World *w))block
{
#ifdef VIDEO
    if((recordVideo==1 && runIndex==0) || recordVideo==2)
    {
        [world runWithBlockVideo:block toFile:videoFilePath];
    }
    else
#endif
    {
        [world runWithBlock2:block];
    }
    
}


-(void) runOneExperiment
{
    [self setup];
    [self setupMultiple];
    
 	BOOL isDir;
    
	if(![summaryFileName isEqualToString:@""])
    {
        homeDir=[homeDir stringByAppendingPathComponent:summaryFileName];
        if(![[NSFileManager defaultManager]  fileExistsAtPath:homeDir isDirectory:&isDir])
        {
            [[NSFileManager defaultManager] createDirectoryAtPath:homeDir  withIntermediateDirectories:YES attributes:nil error:NULL];
            NSLog(@"Created Summary %@",homeDir);
        }
        NSLog(@"Use Summary %@",homeDir);
    }
    
    
    
    NSString *testFolderPath = [homeDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@ - %@ - %d",experiment.title,experimentName,(int)floor([[NSDate date] timeIntervalSinceReferenceDate])]];
    
    NSString *experimentFolderPath=testFolderPath;
    NSFileManager *fileManager= [NSFileManager defaultManager];
    
    
    NSLog(@"SAVE: %d %d %d",savePathMode,saveRunMode,saveExperimentMode);
    
    
    if((saveTestMode || saveExperimentMode || savePathMode || saveRunMode) && ![fileManager fileExistsAtPath:testFolderPath isDirectory:&isDir])
        if(![fileManager createDirectoryAtPath:testFolderPath withIntermediateDirectories:YES attributes:nil error:NULL])
            NSLog(@"Error: Create folder failed %@", testFolderPath);
    
    
    NSString *runFilePath,*pathFilePath,*experimentFilePath,*testFilePath;
    
    
    testFilePath=[testFolderPath stringByAppendingPathComponent:@"test.csv"];
    [[NSFileManager defaultManager] createFileAtPath:testFilePath contents:nil attributes:nil];
    testFileHandle = [NSFileHandle fileHandleForWritingAtPath:testFilePath];
    
    
    [World world];
    
    int k=0;
    
    for(NSMutableDictionary *s in runStatistics)
    {
        NSString *name=[s valueForKey:@"name"];
        
        [experimentStatistics addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:name,@"name",nil]];
        [experimentStatistics addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:[NSString stringWithFormat:@"std %@",name],@"name",nil]];
    }
    
    BOOL firstExperiment=YES;
    
    while(1)
    {
        experimentFileHandle=testFileHandle;
        experimentFolderPath=testFolderPath;
        
        if([multipleArguments count]==0)
        {
            if(!firstExperiment) break;
        }
        else
        {
            BOOL continueTest=NO;
            
            for (NSString *name in [multipleArguments allKeys])
            {
                
                NSDictionary *d=[multipleArguments valueForKey:name];
                //printf("%s=[%s];\r\n",[name UTF8String],[[d valueForKey:@"valueString"] UTF8String]);
                id object=[d valueForKey:@"object"];
                NSString *key=[d valueForKey:@"key"];
                
                //NSLog(@"%@",csvExperimentHeader(world, statistics));
                
                NSMutableArray *values=[d valueForKey:@"value"];
                
                if([values count])
                {
                    NSValue *experimentValue=[values objectAtIndex:0];
                    [object setValue:experimentValue forKey:key];
                    [values removeObjectAtIndex:0];
                    continueTest=YES;
                    
                    
                    if(saveExperimentMode)
                    {
                        experimentFolderPath=[testFolderPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@ - %@",name,experimentValue]];
                        if(![fileManager createDirectoryAtPath:experimentFolderPath withIntermediateDirectories:YES attributes:nil error:NULL])
                            NSLog(@"Error: Create folder failed %@", experimentFolderPath);
                        
                        experimentFilePath =[experimentFolderPath stringByAppendingPathComponent:@"experiment.csv"];
                        [[NSFileManager defaultManager] createFileAtPath:experimentFilePath contents:nil attributes:nil];
                        experimentFileHandle = [NSFileHandle fileHandleForWritingAtPath:experimentFilePath];
                    }
                    break;
                }
            }
            if(!continueTest) break;
        }
        
        
        
        NSData *header=[[NSString stringWithFormat:@"%@\n",[self csvExperimentHeaderWithStatistics:experimentStatistics] ] dataUsingEncoding:NSUTF8StringEncoding];
        
        if(firstExperiment) [testFileHandle writeData:header];
        
        if(![experimentFolderPath isEqualToString:testFolderPath] && saveExperimentMode )
        {
            [experimentFileHandle writeData:header];
        }
        
        
        for(Group *g in experiment.groups)
        {
            g.prototype.socialMargin=fmax(g.prototype.safetyMargin,g.prototype.socialMargin);
            for(NSMutableDictionary *stat in experimentStatistics)
            {
                [stat removeObjectForKey:g.name];
            }
        }
        
        
        //NSLog(@"%@ -> %@",testFileHandle,testFolderPath);
        //NSLog(@"%@ -> %@",experimentFileHandle,experimentFolderPath);
        
        firstExperiment=NO;
        
        NSDate *experimentBegin=[NSDate date];
        
        
        
        for(k=0;k<iterations;k++)
        {
            
            
            runIndex=k;
            for (NSString *name in [randomArguments allKeys])
            {
                
                NSDictionary *d=[randomArguments valueForKey:name];
                id object=[d valueForKey:@"object"];
                NSString *key=[d valueForKey:@"key"];
                
                double lower=[[d valueForKey:@"lowerBound"] doubleValue];
                double upper=[[d valueForKey:@"upperBound"] doubleValue];
                double value=(upper-lower)*rand()/RAND_MAX+lower;
                NSValue *runValue=[NSNumber numberWithDouble:value];
                [object setValue:runValue forKey:key];
                
                // NSLog(@"%@ -> %@ in [%.2f,%.2f]",key,runValue,lower,upper);
                
            }
            
            NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
            
            
            NSDate *runBegin=[NSDate date];
            
            [world reset];
            
            if(saveRunMode)
            {
                runFilePath=[experimentFolderPath stringByAppendingPathComponent:[NSString stringWithFormat:@"run%d.csv",k]];
                [[NSFileManager defaultManager] createFileAtPath:runFilePath contents:nil attributes:nil];
                runFileHandle = [NSFileHandle fileHandleForWritingAtPath:runFilePath];
                if(saveRunMode==3)
                {
                    [runFileHandle writeData:[[NSString stringWithFormat:@"%@\n",[self csvExperimentHeaderShortWithStatistics:runStatistics]] dataUsingEncoding:NSUTF8StringEncoding]];
                }
                else
                {
                    [runFileHandle writeData:[[NSString stringWithFormat:@"%@\n",[self csvExperimentHeaderWithStatistics:runStatistics] ] dataUsingEncoding:NSUTF8StringEncoding]];
                }
            }
            if(savePathMode==2 || (savePathMode==1 && k==0))
            {
                pathFilePath=[experimentFolderPath stringByAppendingPathComponent:[NSString stringWithFormat:@"path%d.csv",k]];
                [[NSFileManager defaultManager] createFileAtPath:pathFilePath contents:nil attributes:nil];
                pathFileHandle = [NSFileHandle fileHandleForWritingAtPath:pathFilePath];
                [pathFileHandle writeData:[[NSString stringWithFormat:@"%@\n",[self csvPathHeader] ] dataUsingEncoding:NSUTF8StringEncoding]];
            }
            
            
#ifdef VIDEO
            videoFilePath=[experimentFolderPath stringByAppendingPathComponent:[NSString stringWithFormat:@"movie%d.mov",k]];
#endif
            
            
            [self runRun:k];
            
            
            
            double runTime=[[NSDate date] timeIntervalSinceDate:runBegin];
            
            if(saveExperimentMode==2)
            {
                [experimentFileHandle writeData:[[NSString stringWithFormat:@"%@\n",[self csvLineForRun:k withStatistics:runStatistics andDuration:runTime]] dataUsingEncoding:NSUTF8StringEncoding]];
            }
            
            if(saveRunMode)
            {
                if(saveRunMode<3)
                {
                    [runFileHandle writeData:[[NSString stringWithFormat:@"%@\n",[self csvExperimentLineWithStatistics:runStatistics andDuration:runTime] ] dataUsingEncoding:NSUTF8StringEncoding]];
                }
                else
                {
                    [runFileHandle writeData:[[NSString stringWithFormat:@"%@\n",[self csvExperimentLineShortWithStatistics:runStatistics andDuration:runTime] ] dataUsingEncoding:NSUTF8StringEncoding]];
                }
                
            }
            
            
            
            [pool drain];
        }
        
        NSMutableDictionary *stat;
        
        for(Group *g in experiment.groups)
        {
            if(g.number==0) continue;
            int i=0;
            for(;i<[experimentStatistics count];i=i+2)
            {
                stat=[experimentStatistics objectAtIndex:i];
                NSMutableDictionary *statStd=[experimentStatistics objectAtIndex:i+1];
                double v=[[stat valueForKey:g.name] doubleValue]/(double)iterations;
                double vv=[[statStd valueForKey:g.name] doubleValue]/(double)iterations;
                
                [stat setValue:[NSNumber numberWithDouble:v] forKey:g.name];
                [statStd setValue:[NSNumber numberWithDouble:sqrt(vv-v*v)] forKey:g.name];
            }
        }
        
        double runTime=[[NSDate date] timeIntervalSinceDate:experimentBegin];
        
        NSData *line=[[NSString stringWithFormat:@"%@\n",[self csvExperimentLineWithStatistics:experimentStatistics andDuration:runTime] ] dataUsingEncoding:NSUTF8StringEncoding];
        
        
        [testFileHandle writeData:line];
        
        if(![experimentFolderPath isEqualToString:testFolderPath] && saveExperimentMode )
        {
            [experimentFileHandle writeData:line];
        }
        
        
    }
    
    [world release];
    
    return;
}




-(NSArray *) csvEntryForGroup:(Group*)g
{
    NSMutableArray *a=[NSMutableArray array];
    if(g.number==0)return a;
    
    Agent *p=g.prototype;
    
    NSString *prefix=[NSString stringWithFormat:@"%@:",g.name];
    NSMutableArray *names=[NSMutableArray arrayWithObjects:@"number",@"radius",@"radius std dev",@"control",@"control period",@"target margin",@"social margin",@"safety margin",@"tau",@"eta",@"optimal speed",@"optimal speed std dev",@"horizon",@"timeHorizon",@"aperture",@"resolution",@"range of view",@"field of view",@"sensing",nil];
    
    NSMutableArray *objects=[NSMutableArray arrayWithObjects:g,p,g,p,p,p,p,p,p,p,p,g,p,p,p,p,p,p,p, nil];
    
    NSMutableArray *keys=[NSMutableArray arrayWithObjects:@"number",@"radius",@"radiusStd",@"control",@"controlUpdatePeriod",@"pathMargin",@"socialMargin",@"safetyMargin",@"tau",@"eta",@"optimalSpeed",@"optimalSpeedStd",@"horizon",@"timeHorizon",@"aperture",@"resolution",@"visibilityRange",@"visibilityFOV",@"sensor",nil];
    
    NSMutableArray *format=[NSMutableArray arrayWithObjects:@"%ld",@"%.5f",@"%.5f",@"%d",@"%.5f",@"%.5f",@"%.5f",@"%.5f",@"%.5f",@"%.5f",@"%.5f",@"%.5f",@"%.5f",@"%.5f",@"%.5f",@"%d",@"%.5f",@"%.5f",@"%d",nil];
    
    
    if([g.prototype isMemberOfClass:[Footbot class]])
    {
        [names addObject:@"rotation tau"];
        [objects addObject:p];
        [keys addObject:@"rotationTau"];
        [format addObject:@"%.5f"];
        
        [names addObject:@"max rotation speed"];
        [objects addObject:p];
        [keys addObject:@"maxRotationSpeed"];
        [format addObject:@"%.5f"];
    }
    if(g.prototype.sensor==rab)
    {
        [names addObject:@"range error std dev"];
        [objects addObject:p];
        [keys addObject:@"rangeErrorStd"];
        [format addObject:@"%.5f"];
        
        [names addObject:@"bearing error std dev"];
        [objects addObject:p];
        [keys addObject:@"bearingErrorStd"];
        [format addObject:@"%.5f"];
        
        [names addObject:@"memory expiration"];
        [objects addObject:p];
        [keys addObject:@"rabMemoryExpiration"];
        [format addObject:@"%.5f"];
    }
    else
    {
        [names addObject:@"error std dev"];
        [objects addObject:p];
        [keys addObject:@"positionSensingErrorStd"];
        [format addObject:@"%.5f"];
    }
    
	if([g.prototype isMemberOfClass:[SocialFootbot class]])
    {
        [names addObjectsFromArray:[NSArray arrayWithObjects:@"modulatedSpeed",@"kSpeed",@"modulatedEta",@"kEta",@"modulatedAperture",@"kAperture",@"modulatedSM", nil]];
        [objects addObjectsFromArray:[NSArray arrayWithObjects:p,p,p,p,p,p,p, nil]];
        [keys addObjectsFromArray:[NSArray arrayWithObjects:@"modulatedSpeed",@"kSpeed",@"modulatedEta",@"kEta",@"modulatedAperture",@"kAperture",@"modulatedSM", nil]];
        [format addObjectsFromArray:[NSArray arrayWithObjects:@"%d",@"%.5f",@"%d",@"%.5f",@"%d",@"%.5f",@"%d", nil]];
    }
    
    
    
    int k=0;
    for(;k<[names count];k++)
    {
        [a addObject:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithFormat:@"%@%@",prefix,[names objectAtIndex:k]],@"name",[format objectAtIndex:k],@"format",[objects objectAtIndex:k],@"object",[keys objectAtIndex:k],@"key", nil]];
    }
    
    
    
    
    return a;
}



-(NSString *) csvHeaderForGroup:(Group *)g
{
    NSMutableArray *header=[NSMutableArray array];
    NSArray *a=[self csvEntryForGroup:g];
    
    for(NSDictionary *d in a)
    {
        [header addObject:[d valueForKey:@"name"]];
    }
    
    return [header componentsJoinedByString:@","];
}


-(NSString *) csvLine2ForAgent:(Agent *)a
{
    NSMutableString *s=[NSMutableString stringWithFormat:@""];
    
    [s appendFormat:@",%.5f",a.radius];
    [s appendFormat:@","];
    [s appendFormat:@","];
    [s appendFormat:@","];
    [s appendFormat:@","];
    [s appendFormat:@","];
    [s appendFormat:@","];
    [s appendFormat:@","];
    [s appendFormat:@","];
    [s appendFormat:@",%.5f",a.optimalSpeed];
    [s appendFormat:@","];
    [s appendFormat:@","];
    [s appendFormat:@","];
    [s appendFormat:@","];
    [s appendFormat:@","];
    [s appendFormat:@","];
    
    
    if([a isMemberOfClass:[Footbot class]])
    {
        [s appendFormat:@",,"];
    }
    if(a.sensor==rab)
    {
        [s appendFormat:@",,,,"];
    }
    else
    {
        [s appendFormat:@",,"];
    }
	if([a isMemberOfClass:[SocialFootbot class]])
    {
        [s appendFormat:@",,,,,,,"];
    }
    
    return s;
}

-(NSString *) csvRunLineForGroup:(Group *)g
{
    NSMutableArray *line=[NSMutableArray array];
    
    NSArray *a=[self csvEntryForGroup:g];
    
    BOOL isRandom=NO;
    
    for(NSDictionary *d in a)
    {
        isRandom=NO;
        for(NSDictionary *r in [randomArguments allValues])
        {
            
            if([r valueForKey:@"object"]==[d valueForKey:@"object"] && [r valueForKey:@"key"]==[d valueForKey:@"key"])
            {
                if([(NSString *)[d valueForKey:@"format"] rangeOfString:@"f"].location!=NSNotFound)
                {
                    //is a float
                    [line addObject:[NSString stringWithFormat:[d valueForKey:@"format"],[[[d valueForKey:@"object"] valueForKey:[d valueForKey:@"key"]] doubleValue]]];
                }
                else{
                    //is an integer
                    
                    
                    [line addObject:[NSString stringWithFormat:[d valueForKey:@"format"],[[[d valueForKey:@"object"] valueForKey:[d valueForKey:@"key"]] intValue]]];
                }
                isRandom=YES;
                break;
            }
        }
        if(!isRandom)[line addObject:@""];
    }
    
    return [line componentsJoinedByString:@","];
    
}

-(NSString *) csvLineForGroup:(Group *)g
{
    NSMutableArray *line=[NSMutableArray array];
    
    NSArray *a=[self csvEntryForGroup:g];
    
    
    for(NSDictionary *d in a)
    {
        if([(NSString *)[d valueForKey:@"format"] rangeOfString:@"f"].location!=NSNotFound)
        {
            //is a float
            //NSLog(@"%@",[[d valueForKey:@"object"] valueForKey:[d valueForKey:@"key"]]);
            [line addObject:[NSString stringWithFormat:[d valueForKey:@"format"],[[[d valueForKey:@"object"] valueForKey:[d valueForKey:@"key"]] doubleValue]]];
        }
        else{
            //is an integer
            //NSLog(@"%@",[[d valueForKey:@"object"] valueForKey:[d valueForKey:@"key"]]);
            [line addObject:[NSString stringWithFormat:[d valueForKey:@"format"],[[[d valueForKey:@"object"] valueForKey:[d valueForKey:@"key"]] intValue]]];
        }
    }
    
    return [line componentsJoinedByString:@","];
    
}

-(NSString *) csvExperimentHeaderShortWithStatistics:(NSArray *)statistics
{
    Experiment *e=world.experiment;
    
    NSMutableString *s=[NSMutableString stringWithFormat:@"Experiment,Duration,Number of iterations,comp. duration,physics update period,%@",[e csvHeader]];
    for(Group *g in e.groups)
    {
        if(g.number>0)
        {
            [s appendString:@","];
            [s appendString:[self csvHeaderForGroup:g]];
        }
    }
    return s;
}


-(NSString *) csvExperimentHeaderWithStatistics:(NSArray *)statistics
{
    Experiment *e=world.experiment;
    
    NSMutableString *s=[NSMutableString stringWithFormat:@"Experiment,Duration,Number of iterations,comp. duration,physics update period,%@",[e csvHeader]];
    for(Group *g in e.groups)
    {
        if(g.number>0)
        {
            NSString *p=[NSString stringWithFormat:@"%@->",g.name];
            [s appendString:@","];
            [s appendString:[self csvHeaderForGroup:g]];
            for(NSDictionary *d in statistics)
            {
                //if([d valueForKey:g.name])
                //{
                [s appendFormat:@",%@",p];
                [s appendString:[d valueForKey:@"name"]];
                //}
            }
        }
    }
    return s;
}

-(NSString *) csvLineForRun:(int)run withStatistics:(NSArray *)statistics andDuration:(double)runTime
{
    Experiment *e=world.experiment;
    
    //NSCharacterSet *allButPeriod=[NSCharacterSet characterSetWithCharactersInString:@"0"];
    //NSString *eDescription=[e csvLine];
    // NSString *periodsInExperimentDescription=[eDescription stringByReplacingOccurrencesOfString:@"[^,]*" withString:@"" options:NSRegularExpressionSearch range:NSMakeRange(0, eDescription.length)];
    
    
	NSString *periodsInExperimentDescription=[e  csvEmptyLine];
    //NSLog(@"%@ -> %@",eDescription,periodsInExperimentDescription);
    
    NSMutableString *s=[NSMutableString stringWithFormat:@",,%d,%.2f,%.2f,%@",run,runTime,world.updatePeriod,periodsInExperimentDescription];
    BOOL first=YES;
    for(Group *g in e.groups)
    {
        if(g.number>0)
        {
            [s appendString:@","];
            first=NO;
            [s appendString:[self csvRunLineForGroup:g]];
            for(NSDictionary *d in statistics)
            {
                if([d valueForKey:g.name])
                {
                    if(!first) [s appendString:@","];
                    [s appendString:[[d valueForKey:g.name] stringValue]];
                    [s appendString:@","];
                }
            }
        }
    }
    return s;
}

-(NSString *) csvRunLineForAgent:(Agent *) agent inGroup:(Group *)group withStatistics:(NSArray *)statistics
{
    Experiment *e=world.experiment;
    
    //NSCharacterSet *allButPeriod=[NSCharacterSet characterSetWithCharactersInString:@"0"];
    // NSString *eDescription=[e csvLine];
    // NSString *periodsInExperimentDescription=[eDescription stringByReplacingOccurrencesOfString:@"[^,]*" withString:@"" options:NSRegularExpressionSearch range:NSMakeRange(0, eDescription.length)];
   	NSString *periodsInExperimentDescription=[e  csvEmptyLine];
    //NSLog(@"%@ -> %@",eDescription,periodsInExperimentDescription);
    
    NSMutableString *s=[NSMutableString stringWithFormat:@",,,,,%@",periodsInExperimentDescription];
    BOOL first=YES;
    for(Group *g in e.groups)
    {
        if(g.number>0)
        {
            [s appendString:@","];
            first=NO;
            if(g==group) [s appendString:[self csvLine2ForAgent:agent]];
            else [s appendString:[self csvRunLineForGroup:g ]];
            
            if(saveRunMode<3)
            {
                
                for(NSDictionary *d in statistics)
                {
                    if([d valueForKey:g.name])
                    {
                        if(!first) [s appendString:@","];
                        [s appendString:[[d valueForKey:g.name] stringValue]];
                        
                    }
                }
            }
            
            
        }
    }
    return s;
}

-(NSString *) csvExperimentLineShortWithStatistics:(NSArray *) statistics andDuration:(double) runTime
{
    Experiment *e=world.experiment;
    NSMutableString *s=[NSMutableString stringWithFormat:@"%@,%.1f,%d,%.2f,%.2f,%@",e.title,duration,iterations,runTime,world.updatePeriod,[e csvLine]];
    BOOL first=YES;
    for(Group *g in e.groups)
    {
        if(g.number>0)
        {
            [s appendString:@","];
            first=NO;
            [s appendString:[self csvLineForGroup:g]];
        }
    }
    return s;
}


-(NSString *) csvExperimentLineWithStatistics:(NSArray *) statistics andDuration:(double) runTime
{
    Experiment *e=world.experiment;
    NSMutableString *s=[NSMutableString stringWithFormat:@"%@,%.1f,%d,%.2f,%.2f,%@",e.title,duration,iterations,runTime,world.updatePeriod,[e csvLine]];
    BOOL first=YES;
    for(Group *g in e.groups)
    {
        if(g.number>0)
        {
            [s appendString:@","];
            first=NO;
            [s appendString:[self csvLineForGroup:g]];
            for(NSDictionary *d in statistics)
            {
                if([d valueForKey:g.name])
                {
                    if(!first) [s appendString:@","];
                    if([d valueForKey:g.name])
                    {
                        [s appendString:[[d valueForKey:g.name] stringValue]];
                    }
                }
            }
        }
    }
    return s;
}


-(NSString *) csvPathLine
{
    NSMutableString *s=[NSMutableString string];
    NSInteger state;
    for(Agent *agent in world.agents)
    {
        if(abs(agent.state)==freeState) state=0;
        else if(agent.state==deadlockState) state=1;
        else if(abs(agent.state==escapingDeadlock)) state=2;
        else if(agent.state==arrivedState) state=3;
        else state=4;
        
        
        if(agent.pathMarkers)
        {
            NSUInteger i=[[world markers] indexOfObject:agent.currentPathMarker];
            
            [s appendFormat:@"%.5f,%.5f,%.5f,%.5f,%ld,%ld,",agent.position.x,agent.position.y,agent.angle,agent.speed,i,state];
        }
        else
        {
            [s appendFormat:@"%.5f,%.5f,%.5f,%.5f,%ld,%ld,",agent.position.x,agent.position.y,agent.angle,agent.speed,agent.type,state];
        }
        
    }
    return s;
}


-(NSString *) csvPathHeader
{
    int k=0;
    NSMutableString *s=[NSMutableString string];
    
    for(;k<world.number;k++)
    {
        [s appendFormat:@"%d x,%d y,%d angle,%d speed,%d target index,%d state,",k,k,k,k,k,k];
    }
    return s;
}



-(void) setupMultiple
{
    
    NSArray *arguments=[[NSProcessInfo processInfo] arguments];
    
    NSScanner *scanner;
    
    Group *defaultGroup=[experiment defaultGroup];
    Group *group;
    NSString *groupName;
    
    
    if(multipleArguments)
    {
        [multipleArguments release];
    }
    
    if(randomArguments)
    {
        [randomArguments release];
    }
    
    multipleArguments=[[NSMutableDictionary dictionary] retain];
    randomArguments=[[NSMutableDictionary dictionary] retain];
    
    for(NSString *argument in arguments)
    {
        NSArray *c=[argument componentsSeparatedByString:@":"];
        group=defaultGroup;
        if([c count]==2)
        {
            groupName=[c objectAtIndex:0];
            group=[world.experiment groupWithName:groupName];
            //NSLog(@"%@ => Group is %@",groupName,group.name);
            argument=[c objectAtIndex:1];
        }
        
        
        
        scanner=[NSScanner scannerWithString:argument];
        
        [self setupGroup:group withScanner:scanner] ||
        [self setupWorldWithScanner:scanner]  ||
        [self setupExperimentWithScanner:scanner]
#ifdef VIDEO
        ||
        [self setupVideoWithSanner:scanner];
#endif
        ;
        
    }
    
}


-(BOOL) setupExperimentWithScanner:(NSScanner *)scanner
{
    int intValue=0;
    //double doubleValue;
    
    
    

    
    if([scanner scanString:@"sensingSocialRatio=" intoString:NULL])
    {
        [scanner scanDouble:&ratioOfSocialRadiusForSensing];return YES;
    }
    if([scanner scanString:@"rabReliability=" intoString:NULL])
    {
        [scanner scanDouble:&rabReliability];return YES;
    }
    if([scanner scanString:@"rabMessageNumber=" intoString:NULL])
    {
        [scanner scanInt:&intValue];return YES;
        rabMessageNumber=intValue;
        return YES;        }
    if([scanner scanString:@"socialRepulsion=" intoString:NULL])
    {
        [scanner scanDouble:&socialRepulsion];return YES;
    }
    if([scanner scanString:@"iterations=" intoString:NULL])
    {
        [scanner scanInt:&iterations];return YES;
    }
    if([scanner scanString:@"duration=" intoString:NULL])
    {
        [scanner scanDouble:&duration];return YES;
    }
    
    if([scanner scanString:@"savePath=" intoString:NULL])
    {
        [scanner scanInt:&savePathMode];return YES;
    }
    
    if([scanner scanString:@"saveExperiment=" intoString:NULL])
    {
        [scanner scanInt:&saveExperimentMode];return YES;
    }
    
    if([scanner scanString:@"saveRun=" intoString:NULL])
    {
        [scanner scanInt:&saveRunMode];return YES;
    }
    
    if([scanner scanString:@"groupSize=" intoString:NULL])
    {
        [scanner scanDouble:&groupSize];return YES;
    }
    
    if([scanner scanString:@"name=" intoString:NULL])
    {
        experimentName=[[scanner string] substringFromIndex:[scanner scanLocation]];
    }
    
    if([scanner scanString:@"summaryFile=" intoString:NULL])
    {
        summaryFileName=[[scanner string] substringFromIndex:[scanner scanLocation]];
    }
    
    
    
    return [self multipleDoubleScan:scanner forName:@"width" object:experiment andKey:@"width"]
    || [self multipleDoubleScan:scanner forName:@"worldRadius" object:experiment andKey:@"radius"]
    || [self multipleDoubleScan:scanner forName:@"oneWay" object:experiment andKey:@"isOneWayTarget"]
    || [self multipleIntScan:scanner forName:@"seed" object:self andKey:@"initialRunIndex"]
    
    ;
    
}

-(BOOL) setupWorldWithScanner:(NSScanner *)scanner
{
    double doubleValue;
    if([scanner scanString:@"updatePeriod=" intoString:NULL])
    {
        [scanner scanDouble:&doubleValue];
        world.updatePeriod=doubleValue;
        return YES;
    }
    if([scanner scanString:@"density=" intoString:NULL])
    {
        [scanner scanDouble:&doubleValue];
        world.density=doubleValue;
        return YES;
    }
    return NO;
}

-(BOOL) setupGroup:(Group *)group withScanner:(NSScanner *)scanner
{
	int intValue;
    if([scanner scanString:@"strictSafety=" intoString:NULL])
    {
        [scanner scanInt:&intValue];
        strictSafety=intValue;
        return YES;
    }
    if([scanner scanString:@"sensor=rab" intoString:NULL])
    {
        group.prototype.sensor=rab; return YES;
    }
    if([scanner scanString:@"sensor=vision" intoString:NULL])
    {
        group.prototype.sensor=vision; return YES;
    }
    if([scanner scanString:@"sensor=obstructed_vision" intoString:NULL])
    {
        group.prototype.sensor=obstructed_vision; return YES;
    }
    
    return
    [self multipleIntScan:scanner forName:@"number" object:group andKey:@"number"] ||
    [self multipleDoubleScan:scanner forName:@"tau" object:group.prototype andKey:@"tau"] ||
    [self multipleDoubleScan:scanner forName:@"controlPeriod" object:group.prototype andKey:@"controlUpdatePeriod"] ||
    [self multipleDoubleScan:scanner forName:@"eta" object:group.prototype andKey:@"eta"] ||
    [self multipleDoubleScan:scanner forName:@"rotationTau" object:group.prototype andKey:@"rotationTau"] ||
    [self multipleDoubleScan:scanner forName:@"socialMargin" object:group.prototype andKey:@"socialMargin"] ||
    [self multipleDoubleScan:scanner forName:@"safetyMargin" object:group.prototype andKey:@"safetyMargin"] ||
    [self multipleDoubleScan:scanner forName:@"aperture" object:group.prototype andKey:@"aperture"] ||
    [self multipleIntScan:scanner forName:@"resolution" object:group.prototype andKey:@"resolution"] ||
    [self multipleDoubleScan:scanner forName:@"horizon" object:group.prototype andKey:@"horizon"] ||
    [self multipleDoubleScan:scanner forName:@"radius" object:group.prototype andKey:@"radius"] ||
    [self multipleDoubleScan:scanner forName:@"optimalSpeed" object:group.prototype andKey:@"optimalSpeed"] ||
    [self multipleDoubleScan:scanner forName:@"pathMargin" object:group.prototype andKey:@"pathMargin"] ||
    [self multipleDoubleScan:scanner forName:@"rabMemoryExpiration" object:group.prototype andKey:@"rabMemoryExpiration"] ||
    [self multipleDoubleScan:scanner forName:@"visionFov" object:group.prototype andKey:@"visibilityFOV"] ||
    [self multipleDoubleScan:scanner forName:@"visionRange" object:group.prototype andKey:@"visibilityRange"] ||
    [self multipleIntScan:scanner forName:@"modulateSocialMargin" object:group.prototype andKey:@"modulateSM"] ||
    [self multipleIntScan:scanner forName:@"modulateEta" object:group.prototype andKey:@"modulateEta"] ||
    [self multipleIntScan:scanner forName:@"modulateOptimalSpeed" object:group.prototype andKey:@"modulateSpeed"] ||
    [self multipleIntScan:scanner forName:@"modulateAperture" object:group.prototype andKey:@"modulateAperture"] ||
    [self multipleDoubleScan:scanner forName:@"kEta" object:group.prototype andKey:@"kEta"] ||
    [self multipleDoubleScan:scanner forName:@"kSpeed" object:group.prototype andKey:@"kSpeed"] ||
    [self multipleDoubleScan:scanner forName:@"kAperture" object:group.prototype andKey:@"kAperture"]||
    [self multipleIntScan:scanner forName:@"control" object:group.prototype andKey:@"control"] ||
    [self multipleDoubleScan:scanner forName:@"timeHorizon" object:group.prototype andKey:@"timeHorizon"]
    
#ifdef RVO_HOLO
    ||
    [self multipleDoubleScan:scanner forName:@"holonomicD" object:group.prototype andKey:@"D"] ||
    [self multipleIntScan:scanner forName:@"useHolonomicContraints" object:group.prototype andKey:@"useHolonomicContraints"]
#endif
    
#ifdef DEADLOCKS
    ||
    [self multipleDoubleScan:scanner forName:@"escapeDeadlocks" object:group.prototype andKey:@"shouldEscapeDeadlocks"]
#endif
    
    ||
    [self multipleIntScan:scanner forName:@"modulation" object:group.prototype andKey:@"emotionModulationIsActive"] ||
    [self multipleIntScan:scanner forName:@"emotion" object:group.prototype andKey:@"shouldShowEmotion"] ||
    [self multipleDoubleScan:scanner forName:@"frustationToEscape" object:group.prototype andKey:@"escapeThreshold"] ||
    [self multipleDoubleScan:scanner forName:@"targetError" object:group.prototype andKey:@"targetHeadingError"] ||
    [self multipleDoubleScan:scanner forName:@"targetQuality" object:group.prototype andKey:@"targetSensingQuality"]


    

    
#ifdef SENSING_ERROR
    ||
    //[self multipleDoubleScan:scanner forName:@"speedErrorStd",group.prototype andKey:@"speedSensingErrorStd"] ||
    [self multipleDoubleScan:scanner forName:@"visionError" object:group.prototype andKey:@"positionSensingErrorStd"] ||
    [self multipleDoubleScan:scanner forName:@"rangeError" object:group.prototype andKey:@"rangeErrorStd"] ||
    [self multipleDoubleScan:scanner forName:@"bearingError" object:group.prototype andKey:@"bearingErrorStd"];
#else
    ;
#endif
    
}



-(BOOL) multipleIntScan:(NSScanner *)scanner forName:(NSString *)name object:(id) object andKey:(NSString *)key
{
    NSString *valueString;
    int intValue;
    if([scanner scanString:[NSString stringWithFormat:@"%@=",name] intoString:NULL])
    {
        if([scanner scanString:@"[" intoString:NULL] && [scanner scanUpToString:@"]" intoString:&valueString])
        {
            NSMutableArray *values=[NSMutableArray array];
            for(NSString *value in [valueString componentsSeparatedByString:@","])
            {
                scanner=[NSScanner scannerWithString:value];
                [scanner scanInt:&intValue];
                [values addObject:[NSNumber numberWithInt:intValue]];
            }
            NSDictionary *d=[NSDictionary dictionaryWithObjectsAndKeys:valueString,@"valueString",values,@"value",object,@"object",key,@"key", nil];
            [multipleArguments setValue:d forKey:key];
        }
        else if([scanner scanString:@"{" intoString:NULL] && [scanner scanUpToString:@"}" intoString:&valueString])
        {
            NSArray *bounds=[valueString componentsSeparatedByString:@","];
            if([bounds count]==2)
            {
                scanner=[NSScanner scannerWithString:[bounds objectAtIndex:0]];
                [scanner scanInt:&intValue];
                NSNumber *lower=[NSNumber numberWithInt:intValue];
                scanner=[NSScanner scannerWithString:[bounds objectAtIndex:1]];
                [scanner scanInt:&intValue];
                NSNumber *upper=[NSNumber numberWithInt:intValue];
                NSDictionary *d=[NSDictionary dictionaryWithObjectsAndKeys:valueString,@"valueString",lower,@"lowerBound",upper,@"upperBound",object,@"object",key,@"key", nil];
                [randomArguments setValue:d forKey:key];
            }
        }
        
        else
        {
            [scanner scanInt:&intValue];
            [object setValue:[NSNumber numberWithInt:intValue] forKey:key];
        }
        return YES;
    }
    else
    {
        return NO;
    }
}


-(BOOL) multipleDoubleScan:(NSScanner *)scanner forName:(NSString *)name object:(id) object andKey:(NSString *)key
{
    NSString *valueString;
    double doubleValue;
    if([scanner scanString:[NSString stringWithFormat:@"%@=",name] intoString:NULL])
    {
        if([scanner scanString:@"[" intoString:NULL] && [scanner scanUpToString:@"]" intoString:&valueString])
        {
            NSMutableArray *values=[NSMutableArray array];
            for(NSString *value in [valueString componentsSeparatedByString:@","])
            {
                scanner=[NSScanner scannerWithString:value];
                [scanner scanDouble:&doubleValue];
                [values addObject:[NSNumber numberWithDouble:doubleValue]];
            }
            NSDictionary *d=[NSDictionary dictionaryWithObjectsAndKeys:valueString,@"valueString",values,@"value",object,@"object",key,@"key", nil];
            [multipleArguments setValue:d forKey:key];
        }
        else if([scanner scanString:@"{" intoString:NULL] && [scanner scanUpToString:@"}" intoString:&valueString])
        {
            NSArray *bounds=[valueString componentsSeparatedByString:@","];
            if([bounds count]==2)
            {
                scanner=[NSScanner scannerWithString:[bounds objectAtIndex:0]];
                [scanner scanDouble:&doubleValue];
                NSNumber *lower=[NSNumber numberWithDouble:doubleValue];
                scanner=[NSScanner scannerWithString:[bounds objectAtIndex:1]];
                [scanner scanDouble:&doubleValue];
                NSNumber *upper=[NSNumber numberWithDouble:doubleValue];
                NSDictionary *d=[NSDictionary dictionaryWithObjectsAndKeys:valueString,@"valueString",lower,@"lowerBound",upper,@"upperBound",object,@"object",key,@"key", nil];
                [randomArguments setValue:d forKey:key];
            }
        }
        else
        {
            [scanner scanDouble:&doubleValue];
            [object setValue:[NSNumber numberWithDouble:doubleValue] forKey:key];
        }
        return YES;
    }
    else
    {
        return NO;
    }
}


#ifdef VIDEO

-(BOOL) setupVideoWithSanner:(NSScanner *)scanner
{
    double doubleValue;
    int intValue;
    if([scanner scanString:@"video=" intoString:NULL])
    {
        [scanner scanInt:&intValue];
        recordVideo=intValue;
        return YES;
    }
    if([scanner scanString:@"videoSpeed=" intoString:NULL])
    {
        [scanner scanDouble:&doubleValue];
        VideoController *videoController=[VideoController sharedVideoController];
        videoController.speed=doubleValue;
        
        return YES;
    }
    if([scanner scanString:@"videoFrameRate=" intoString:NULL])
    {
        [scanner scanDouble:&doubleValue];
        VideoController *videoController=[VideoController sharedVideoController];
        videoController.framesPerSecond=doubleValue;
        
        
        return YES;
    }
    if([scanner scanString:@"videoWidth=" intoString:NULL])
    {
        [scanner scanDouble:&doubleValue];
        [VideoController setWidth:doubleValue];
        return YES;
    }
    return NO;
}

#endif

@end


@implementation ComparisonExperimentWithArguments


-(void) runOneExperiment
{
    [self setup];
    [self setupMultiple];
    
    
    NSLog(@"SAVE: %d %d %d",savePathMode,saveRunMode,saveExperimentMode);
    
    
 	BOOL isDir;
    
    NSFileManager *fileManager= [NSFileManager defaultManager];
    
	if(![summaryFileName isEqualToString:@""])
    {
        homeDir=[homeDir stringByAppendingPathComponent:summaryFileName];
        if(![fileManager fileExistsAtPath:homeDir isDirectory:&isDir])
        {
            [fileManager createDirectoryAtPath:homeDir  withIntermediateDirectories:YES attributes:nil error:NULL];
            NSLog(@"Created Summary %@",homeDir);
        }
        NSLog(@"Use Summary %@",homeDir);
    }
    
    
    
    
    NSString *testFolderPath = [homeDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@ - %@ - %d",experiment.title,experimentName,(int)floor([[NSDate date] timeIntervalSinceReferenceDate])]];
    
    if(![fileManager fileExistsAtPath:testFolderPath isDirectory:&isDir])
        if(![fileManager createDirectoryAtPath:testFolderPath withIntermediateDirectories:YES attributes:nil error:NULL])
            NSLog(@"Error: Create folder failed %@", testFolderPath);
    
    
    NSString *runFilePath,*pathFilePath,*experimentFilePath,*testFilePath,*runFolderFilePath;
    
    testFilePath=[testFolderPath stringByAppendingPathComponent:@"test.csv"];
    [[NSFileManager defaultManager] createFileAtPath:testFilePath contents:nil attributes:nil];
    testFileHandle = [NSFileHandle fileHandleForWritingAtPath:testFilePath];
    [testFileHandle writeData:[@"index,ORCA-HROV,ORCA-HL,HROV-HL\n" dataUsingEncoding:NSUTF8StringEncoding]];
    
    
    NSLog(@"seed %d",initialRunIndex);
    
    uint experimentIndex=initialRunIndex;
    
    
    [World world];
    //?
    
    

    
    
    [experimentStatistics addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:@"ORCA-HROV",@"name",nil]];
    [experimentStatistics addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:@"ORCA-HL",@"name",nil]];
    [experimentStatistics addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:@"HROV-HL",@"name",nil]];
    
    
    BOOL isAnInterestingExperiment=NO;
    
    uint e=0;
    
    for(;experimentIndex<iterations+initialRunIndex;experimentIndex++)
    {
        experiment.seed=experimentIndex;
        e++;
        
        
        NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
        [world reset];
        
        NSData *header=[[NSString stringWithFormat:@"%@\n",[self csvExperimentHeaderWithStatistics:experimentStatistics] ] dataUsingEncoding:NSUTF8StringEncoding];
        
        NSString *experimentFolderPath=[testFolderPath stringByAppendingPathComponent:[NSString stringWithFormat:@"Experiment%d",experimentIndex]];
        if(![fileManager fileExistsAtPath:experimentFolderPath isDirectory:&isDir])
            if(![fileManager createDirectoryAtPath:experimentFolderPath withIntermediateDirectories:YES attributes:nil error:NULL])
                NSLog(@"Error: Create folder failed %@", experimentFolderPath);
        
        
        
        experimentFilePath=[experimentFolderPath stringByAppendingPathComponent:@"experiment.csv"];
        [[NSFileManager defaultManager] createFileAtPath:experimentFilePath contents:nil attributes:nil];
        experimentFileHandle = [NSFileHandle fileHandleForWritingAtPath:experimentFilePath];
        [experimentFileHandle writeData:header];
        
                
        NSDate *experimentBegin=[NSDate date];
        
        ControlType control=RVO_C;
        
        NSMutableArray *startPositions=[NSMutableArray arrayWithCapacity:world.number];
        NSMutableArray *endPositions=[NSMutableArray arrayWithCapacity:3];
        
        NSMutableArray *startAngles=[NSMutableArray arrayWithCapacity:world.number];
        NSMutableArray *endAngles=[NSMutableArray arrayWithCapacity:3];
        
        for(Agent *a in world.agents)
        {
            [startPositions addObject:[NSValue valueWithPoint:a.position]];
            [startAngles addObject:[NSNumber numberWithDouble:a.angle]];
            //NSLog(@".");
        }
        
        for(;control<3;control++)
        {
            
            //NSLog(@"Begin of control %d",control);
            
            if(control!=0)
            {
                NSUInteger i=0;
                for(Agent *a in world.agents)
                {
                    [a reset];
                    a.position=[[startPositions objectAtIndex:i] pointValue];
                    a.angle=[[startAngles objectAtIndex:i] doubleValue];
                    i++;
                }
            }
            
            for(Group *g in experiment.groups)
            {
                g.prototype.control=control;
            }
            
            
            for(Agent *a in world.agents)
            {
                a.control=control;
                a.velocity=NSMakePoint(a.optimalSpeed*cos(a.angle), a.optimalSpeed*sin(a.angle));
                a.desideredVelocity=NSMakePoint(a.optimalSpeed*cos(a.angle), a.optimalSpeed*sin(a.angle));
            }

            
            
            
           
            
            runFolderFilePath=[experimentFolderPath stringByAppendingPathComponent:[NSString stringWithFormat:@"run%d",control]];
            
            
            if(![[NSFileManager defaultManager]  fileExistsAtPath:runFolderFilePath isDirectory:&isDir])
            {
                [[NSFileManager defaultManager] createDirectoryAtPath:runFolderFilePath  withIntermediateDirectories:YES attributes:nil error:NULL];
                //NSLog(@"Created Summary %@",runFolderFilePath);
            }
            
            
            runFilePath=[runFolderFilePath stringByAppendingPathComponent:@"run.csv"];
            [[NSFileManager defaultManager] createFileAtPath:runFilePath contents:nil attributes:nil];
            runFileHandle = [NSFileHandle fileHandleForWritingAtPath:runFilePath];
            [runFileHandle writeData:[[NSString stringWithFormat:@"%@\n",[self csvExperimentHeaderWithStatistics:runStatistics] ] dataUsingEncoding:NSUTF8StringEncoding]];
            
            pathFilePath=[runFolderFilePath stringByAppendingPathComponent:@"path.csv"];
            [[NSFileManager defaultManager] createFileAtPath:pathFilePath contents:nil attributes:nil];
            
            pathFileHandle = [NSFileHandle fileHandleForWritingAtPath:pathFilePath];
            [pathFileHandle writeData:[[NSString stringWithFormat:@"%@\n",[self csvPathHeader] ] dataUsingEncoding:NSUTF8StringEncoding]];
            
            
            
#ifdef VIDEO
            videoFilePath=[runFolderFilePath stringByAppendingPathComponent:@"movie.mov"];
#endif
            
            
            NSDate *runBegin=[NSDate date];
            
        
            [self runRun:control];
            
            double runTime=[[NSDate date] timeIntervalSinceDate:runBegin];
            
            [runFileHandle writeData:[[NSString stringWithFormat:@"%@\n",[self csvExperimentLineWithStatistics:runStatistics andDuration:runTime] ] dataUsingEncoding:NSUTF8StringEncoding]];
            
            
            NSMutableArray *positions=[NSMutableArray arrayWithCapacity:world.number];
            
            [endPositions addObject:positions];
            
            NSMutableArray *angles=[NSMutableArray arrayWithCapacity:world.number];
            
            [endAngles addObject:angles];
            
            for(Agent *a in world.agents)
            {
                [positions addObject:[NSValue valueWithPoint:a.position]];
                [angles addObject:[NSNumber numberWithDouble:a.angle]];
            }
        }
        
        
        double runTime=[[NSDate date] timeIntervalSinceDate:experimentBegin];
        
        double d01=0.0;
        double d02=0.0;
        double d12=0.0;
        
        for(Group *group in experiment.groups)
        {
            if([group.members count]==0) continue;
            
            //TODO shift endPositions to group
            
            uint n=0;
        
            d01=0.0;
            d02=0.0;
            d12=0.0;
        
            double dn=world.number;
        
        for(;n<[group.members count];n++)
        {
            NSPoint p0,p1,p2;
            
            p0=[[[endPositions objectAtIndex:0] objectAtIndex:n] pointValue];
            p1=[[[endPositions objectAtIndex:1] objectAtIndex:n] pointValue];
            p2=[[[endPositions objectAtIndex:2] objectAtIndex:n] pointValue];
            
            d01+=sqrt((p0.x-p1.x)*(p0.x-p1.x)+(p0.y-p1.y)*(p0.y-p1.y));
            d02+=sqrt((p0.x-p2.x)*(p0.x-p2.x)+(p0.y-p2.y)*(p0.y-p2.y));
            d12+=sqrt((p1.x-p2.x)*(p1.x-p2.x)+(p1.y-p2.y)*(p1.y-p2.y));
            
        }
        
        
        d01/=dn;
        d02/=dn;
        d12/=dn;
        
        
            isAnInterestingExperiment=(d01>0.1 || d02 >0.1 || d12>0.1);
            
           
                
            
            
        [[experimentStatistics objectAtIndex:0] setValue:[NSNumber numberWithDouble:d01] forKey:group.name];
        [[experimentStatistics objectAtIndex:1] setValue:[NSNumber numberWithDouble:d02] forKey:group.name];
        [[experimentStatistics objectAtIndex:2] setValue:[NSNumber numberWithDouble:d12] forKey:group.name];
        }
        
         if(isAnInterestingExperiment)
         {
        NSData *line=[[NSString stringWithFormat:@"%@\n",[self csvExperimentLineWithStatistics:experimentStatistics andDuration:runTime] ] dataUsingEncoding:NSUTF8StringEncoding];
        
        
        [experimentFileHandle writeData:line];
        
        line=[[NSString stringWithFormat:@"%d,%.5f,%.5f,%.5f\n",experimentIndex,d01,d02,d12] dataUsingEncoding:NSUTF8StringEncoding];
        
        [testFileHandle writeData:line];
         }
         else{
             if(![fileManager removeItemAtPath:experimentFolderPath error:NULL]) NSLog(@"Could not remove folder at %@",experimentFolderPath);
         }
        
        [pool drain];
        
        //NSLog(@"%.1f",100*(double)e/iterations);
        
    }
    
    [world release];
    
    return;
}

@end

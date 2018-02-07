//
//  Experiment.m
//  MultiAgent
//
//  Created by Jérôme Guzzi on 7/2/12.
//  Copyright (c) 2012 Idsia. All rights reserved.
//

#import "Experiment.h"


@implementation Experiment

@synthesize world,groups,title,statistics,statisticsIndex,statisticsLength,statisticsComplete,statisticsMaxLength;

@synthesize seed;

+(void)initializeWorld:(World *)world ofType:(int) type
{
    id wI;
    
    switch (type) {
        case SLALOM:
            wI=[WorldSlalom alloc];
            break;
        case CROSS:
            wI=[WorldCross alloc];
            break;
        case BUTTERFLY:
            wI=[WorldButterfly alloc];
            break;
        case SQUARE:
            wI=[WorldSquare alloc];
            break;
        case LINES:
            wI=[WorldLine alloc];
            break;
        case EDGE:
            wI=[WorldEdge alloc];
            break;
        case CIRCLE:
            wI=[WorldCircle alloc];
            break;
        case DOUBLE_CIRCLE:
            wI=[WorldDoubleCircle alloc];
            break;
        case PERIODIC_LINE:
            wI=[WorldPeriodicLine alloc];
            break;
        case DOUBLE_PERIODIC_LINE:
            wI=[WorldDoublePeriodicLine alloc];
            break;
        case RANDOM:
            wI=[WorldRandom alloc];
            break;
        case LEDs:
            wI=[WorldLEDs alloc];
            break;
        case CIRCLE_WITH_WALLS:
            wI=[WorldCircleWithWall alloc];
            break;
        case CIRCLE_WITH_WALL_MIXED:
            wI=[WorldCircleWithWallMixed alloc];
            break;
        case ANTIPODE:
            wI=[WorldAntipode alloc];
            break;
        case LINE_MIXED:
            wI=[WorldPeriodicLineMixed alloc];
            break;
        case INTERACTIVE:
            wI=[WorldInteractive alloc];
            break;
        case NCCR_LINE:
            wI=[NCCRLine alloc];
            break;
        case NCCR_CROSS:
            wI=[NCCRCross alloc];
            break;
        case TRACES:
            wI=[TraceExperiment alloc];
            break;
        case E_PANIC:
            wI=[EmotionPanicExperiment alloc];
            break;
        case E_URGENCY:
            wI=[EmotionUrgencyExperiment alloc];
            break;
        case E_URGENCY2:
            wI=[EmotionUrgency2Experiment alloc];
            break;
        case E_CONFUSION:
            wI=[EmotionConfusionExperiment alloc];
            break;
        default:
            wI=nil;
            break;
    }
    [world removeAllWalls];
    [world removeAllMarkers];
    [wI initWithWorld:world];
    [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:@"worldWasResetted" object:self]];
    world.experiment=wI;
    [wI release];
}



/*
 +(Experiment*) loadFromFile:(NSString *)filePath
 {
 if(![filePath isAbsolutePath])
 {
 filePath=[[[NSFileManager defaultManager] currentDirectoryPath] stringByAppendingPathComponent:filePath];
 }
 NSURL *url=[NSURL URLWithString:filePath];
 NSLog(@"Should Load file %@ %@",filePath,url);
 // NSFileHandle *file=[NSFileHandle fileHandleForReadingAtPath:filePath];
 NSXMLDocument *document=[[NSXMLDocument alloc] initWithContentsOfURL:url options:NSXMLDocumentTidyXML error:nil];
 
 NSXMLElement *root=[document rootElement];
 
 
 
 NSXMLElement *world=[[root elementsForName:@"world"] objectAtIndex:0];
 
 NSXMLElement *agents=[[root elementsForName:@"agents"]objectAtIndex:0];
 
 
 
 NSString *type=[[world attributeForName:@"type"] stringValue];
 
 Experiment *wI=[self worldInitializerOfType:[type intValue]];
 
 NSLog(@"%@ %@ %@ %@",document,root,world,agents);
 
 
 NSLog(@"number %d type %d",[[[world attributeForName:@"number"] stringValue] intValue],[type intValue]);
 
 [document release];
 
 return wI;
 }
 */

-(void)dealloc
{
    self.statistics=nil;
    self.title=nil;
    //Ugly
    [self stopObserving];
    
    self.groups=nil;
    [super dealloc];
}

-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    
    NSLog(@"%@ %@",keyPath,change);
    NSString *key=[[keyPath componentsSeparatedByString:@"."] lastObject];
    [world agentPrototypeOfGroup:(Group *)context didChangeForKey:key];
    //[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}


-(void)startObserving
{
    if(!observing)
    {
        NSArray *keys=[NSArray arrayWithObjects:@"control",@"controlUpdatePeriod",@"optimalSpeed",@"aperture",@"visibilityHorizon",@"visibilityFOV",@"resolution",@"horizon",@"mass",@"socialMargin",@"speed",@"speedSensingErrorStd",@"positionSensingErrorStd",@"tau",@"pathMargin",@"rabMemoryLength",@"sensor",@"safetyMargin",@"interaction",@"eta",@"timeHorizon",nil];
        
        for(Group *group in groups)
        {
            for(id key in keys)
            {
                [group.prototype addObserver:self forKeyPath:[NSString stringWithFormat:@"%@",key] options:0 context:group];
            }
        }
    }
    
    observing=YES;
}

-(void)stopObserving
{
    if(observing)
    {
        NSArray *keys=[NSArray arrayWithObjects:@"control",@"controlUpdatePeriod",@"optimalSpeed",@"aperture",@"visibilityHorizon",@"visibilityFOV",@"resolution",@"horizon",@"mass",@"socialMargin",@"speed",@"speedSensingErrorStd",@"positionSensingErrorStd",@"tau",@"pathMargin",@"rabMemoryLength",@"sensor",@"safetyMargin",@"interaction",@"eta",@"timeHorizon",nil];
        
        for(Group *group in groups)
        {
            for(id key in keys)
            {
                [group.prototype removeObserver:self forKeyPath:[NSString stringWithFormat:@"%@",key] context:group];
            }
        }
    }
}

-(void)initStatisticsWithLength:(NSUInteger)length
{
    NSMutableDictionary *d=[NSMutableDictionary dictionary];
    
    [self initKey:@"order" inStatistics:d ofLength:length andType:@"double"];
    [self initKey:@"compression" inStatistics:d ofLength:length andType:@"double"];
    [self initKey:@"time" inStatistics:d ofLength:length andType:@"double"];
    
    self.statistics=d;
    self.statisticsLength=0;
    self.statisticsMaxLength=length;
    self.statisticsIndex=0;
    self.statisticsComplete=NO;
    
    for (Group *g in groups) {
        [self initStatisticsForGroup:g];
    }
    
}

-(void)updateStatistics
{
    [world updateStatistics];
    return;
    
    [self updateKey:@"order" inStatistics:self.statistics ofLength:statisticsLength withDouble:world.order atIndex:statisticsIndex];
    [self updateKey:@"compression" inStatistics:self.statistics ofLength:statisticsLength withDouble:world.compression atIndex:statisticsIndex];
    [self updateKey:@"time" inStatistics:self.statistics ofLength:statisticsLength withDouble:world.cTime atIndex:statisticsIndex];
    
    for (Group *g in groups) {
        [self updateStatisticsForGroup:g];
    }
    
    self.statisticsIndex++;
    if(self.statisticsIndex==self.statisticsLength)
    {
        self.statisticsComplete=YES;
        self.statisticsIndex=0;
        self.statisticsLength=self.statisticsMaxLength;
    }
    if(!self.statisticsComplete)
    {
        self.statisticsLength=self.statisticsIndex+1;
    }
}


-(void)initKey:(NSString *)key inStatistics:(NSMutableDictionary *)s ofLength:(NSUInteger)length andType:(NSString *)type
{
    NSMutableDictionary *d=[NSMutableDictionary dictionary];
    // NSLog(@"S Init Key %@ of type %@",key,type);
    [d setValue:type forKey:@"type"];
    if([type isEqualToString:@"double"])
    {
        [d setValue:[NSMutableData dataWithLength:length*sizeof(double)] forKey:@"values"];
    }
    else
    {
        [d setValue:[NSMutableData dataWithLength:length*sizeof(int)] forKey:@"values"];
    }
    [s setValue:d forKey:key];
}

-(void)updateKey:(NSString *)key inStatistics:(NSMutableDictionary *)s ofLength:(NSUInteger)length withInteger:(int)value atIndex:(NSUInteger)index
{
    
    
    NSMutableDictionary *d=[s valueForKey:key];
    
    // NSLog(@"S Update Key %@ of type int",key);
    
    
    
    NSMutableData *data=[d valueForKey:@"values"];
    
    int *values=(int *)[data mutableBytes];
    values[index]=value;
    
    [d setValue:[NSNumber numberWithInt:value] forKey:@"lastValue"];
    
    int *v=values;
    if(!statisticsComplete) length++;
    int *e=values+length;
    
    int min=v[0];
    int max=v[0];
    double mean=v[0];
    
    v++;
    
    for(;v<e;v++)
    {
        min=MIN(min,*v);
        max=MAX(max,*v);
        mean+=*v;
    }
    
    
    
    mean/=(double)length;
    
    
    
    
    [d setValue:[NSNumber numberWithDouble:min] forKey:@"minValue"];
    [d setValue:[NSNumber numberWithDouble:max] forKey:@"maxValue"];
    [d setValue:[NSNumber numberWithDouble:mean] forKey:@"meanValue"];
    
}

-(void)updateKey:(NSString *)key inStatistics:(NSMutableDictionary *)s ofLength:(NSUInteger)length withDouble:(double)value atIndex:(NSUInteger)index
{
    
    
    
    
    
    NSMutableDictionary *d=[s valueForKey:key];
    
    NSMutableData *data=[d valueForKey:@"values"];
    
    double *values=(double *)[data mutableBytes];
    values[index]=value;
    
    
    
    [d setValue:[NSNumber numberWithDouble:value] forKey:@"lastValue"];
    
    double *v=values;
    if(!statisticsComplete) length++;
    double *e=values+length;
    
    double min=v[0];
    double max=v[0];
    double mean=v[0];
    
    v++;
    
    for(;v<e;v++)
    {
        min=fmin(min,*v);
        max=fmax(max,*v);
        mean+=*v;
    }
    
    mean/=(double)length;
    
    //NSLog(@"S Update Key %@ of type double at index %lu with value %.2f",key,index,value);
    //NSLog(@"=> mean %.2f in [%.2f,%.2f]",mean,min,max);
    
    
    [d setValue:[NSNumber numberWithDouble:min] forKey:@"minValue"];
    [d setValue:[NSNumber numberWithDouble:max] forKey:@"maxValue"];
    [d setValue:[NSNumber numberWithDouble:mean] forKey:@"meanValue"];
    
}



//statistics['index']
//statistics['length']
//statistics['full']
//statistics['order']
//statistics['compression']
// ...
//
//NSMutableDictionary *s=statistics[groupName];
//s[key]={values-> NSMutableData * , lastValue -> NSNumber *, minValue -> NSNumber *,  maxValue -> NSNumber *, meanValue -> NSNumber *};

-(void)initStatisticsForGroup:(Group *)group
{
    double length=statisticsMaxLength;
    NSMutableDictionary *d=[NSMutableDictionary dictionary];
    [self initKey:@"speedX" inStatistics:d ofLength:length andType:@"double"];
    [self initKey:@"speedY" inStatistics:d ofLength:length andType:@"double"];
    [self initKey:@"speedXStd" inStatistics:d ofLength:length andType:@"double"];
    [self initKey:@"speedYStd" inStatistics:d ofLength:length andType:@"double"];
    [self initKey:@"speed" inStatistics:d ofLength:length andType:@"double"];
    [self initKey:@"deviation" inStatistics:d ofLength:length andType:@"double"];
    [self initKey:@"efficacity" inStatistics:d ofLength:length andType:@"double"];
    [self initKey:@"work" inStatistics:d ofLength:length andType:@"double"];
    [self initKey:@"hits" inStatistics:d ofLength:length andType:@"int"];
    [self initKey:@"throughput" inStatistics:d ofLength:length andType:@"int"];
    
    [self.statistics setValue:d forKey:group.name];
}

-(NSNumber *)maxValueForKey:(NSString *)key inGroup:(Group *)group
{
    return [[[statistics valueForKey:group.name] valueForKey:key] valueForKey:@"maxValue"];
}
-(NSNumber *)lastValueForKey:(NSString *)key inGroup:(Group *)group
{
    return [[[statistics valueForKey:group.name] valueForKey:key] valueForKey:@"lastValue"];
}
-(NSNumber *)lastValueForKey:(NSString *)key
{
    return [[statistics valueForKey:key] valueForKey:@"lastValue"];
}

-(NSNumber *)valueForKey:(NSString *)key  atIndex:(NSUInteger)index
{
    
    //        NSLog(@"S Read Key %@ at index %lu",key,index);
    
    if(!statisticsMaxLength) return nil;
    
    
    
    
    index=(statisticsIndex+index) % statisticsMaxLength;
    
    NSDictionary *d=statistics;
    NSData *data=[[d valueForKey:key] valueForKey:@"values"];
    NSString *type=[[d valueForKey:key] valueForKey:@"type"];
    if([type isEqualToString:@"double"])
    {
        double *v=(double *)[data bytes];
        return [NSNumber numberWithDouble:v[index]];
    }
    else
    {
        int *v=(int *)[data bytes];
        return [NSNumber numberWithInt:v[index]];
    }
}

-(NSNumber *)valueForKey:(NSString *)key inGroup:(Group *)group atIndex:(NSUInteger)index
{
    // NSLog(@"S Read Key %@ in group %@ at index %lu",key,group.name,index);
    
    if(!statisticsMaxLength) return nil;
    
    index=(statisticsIndex+index) % statisticsMaxLength;
    
    NSDictionary *d=[statistics valueForKey:group.name];
    NSData *data=[[d valueForKey:key] valueForKey:@"values"];
    NSString *type=[[d valueForKey:key] valueForKey:@"type"];
    if([type isEqualToString:@"double"])
    {
        double *v=(double *)[data bytes];
        return [NSNumber numberWithDouble:v[index]];
    }
    else
    {
        int *v=(int *)[data bytes];
        return [NSNumber numberWithInt:v[index]];
    }
}




-(void)updateStatisticsForGroup:(Group *)group
{
    if([group.members count]==0) return;
    
    
    uint hits=[[[[statistics valueForKey:group.name] valueForKey:@"hits"] valueForKey:@"lastValue"] intValue];;
    double speed=0.0;
    double deviation=0;
    double efficacity=0;
    double work=0;
    
    double speedX=0;
    double speedY=0;
    double speedXStd=0;
    double speedYStd=0;
    uint throughput=[[[[statistics valueForKey:group.name] valueForKey:@"throughput"] valueForKey:@"lastValue"] intValue];
    
    double n=(double)[group.members count];
    
    for(Agent *a in group.members)
    {
        hits+=a.numberOfHits;
        a.numberOfHits=0;
        speed+=a.speed;
        deviation+=a.deviation;
        throughput+=a.numberOfReachedTargets;
        a.numberOfReachedTargets=0;
        
        speedX+=fabs(a.velocity.x);
        speedY+=fabs(a.velocity.y);
        
        speedXStd+=a.velocity.x*a.velocity.x;
        speedYStd+=a.velocity.y*a.velocity.y;
        
        NSPoint agentToTarget=NSMakePoint(a.target.x-a.position.x,a.target.y-a.position.y);
        double a0=atan2(agentToTarget.y,agentToTarget.x)-a.angle;
        efficacity+=cos(a0)*a.speed/a.optimalSpeed;
        
        work+=a.work;
        a.work=0;
    }
    
    
    speedX=speedX/n;
    speedY=speedY/n;
    
    speedXStd=sqrt(speedXStd/n-speedX*speedX);
    speedYStd=sqrt(speedYStd/n-speedY*speedY);
    
    speed/=n;
    deviation/=n;
    efficacity/=n;
    work/=n;
    
    NSMutableDictionary *d=[self.statistics valueForKey:group.name];
    
    double length=statisticsLength;
    double index=statisticsIndex;
    
    [self updateKey:@"speedX" inStatistics:d ofLength:length withDouble:speedX atIndex:index];
    [self updateKey:@"speedY" inStatistics:d ofLength:length withDouble:speedY atIndex:index];
    [self updateKey:@"speedXStd" inStatistics:d ofLength:length withDouble:speedXStd atIndex:index];
    [self updateKey:@"speedYStd" inStatistics:d ofLength:length withDouble:speedYStd atIndex:index];
    [self updateKey:@"speed" inStatistics:d ofLength:length withDouble:speed atIndex:index];
    [self updateKey:@"deviation" inStatistics:d ofLength:length withDouble:deviation atIndex:index];
    [self updateKey:@"efficacity" inStatistics:d ofLength:length withDouble:efficacity atIndex:index];
    [self updateKey:@"work" inStatistics:d ofLength:length withDouble:work atIndex:index];
    [self updateKey:@"hits" inStatistics:d ofLength:length withInteger:hits atIndex:index];
    [self updateKey:@"throughput" inStatistics:d ofLength:length withInteger:throughput atIndex:index];
}





-(void)reset
{
    [self initAgents];
    [self initPath];
    [self initStatisticsWithLength:30];
    //[[world.agents lastObject] setDebug:YES];
}

-(id)initWithWorld:(World *)w
{
    self.world=w;
    self.groups=[NSMutableArray array];
    w.arena=NSMakeRect(-5,-5,10,10);
    Group *a=[Group groupWithName:@"agent" andPrototype:[Experiment agentPrototype]];
    Group *f=[Group groupWithName:@"footbot" andPrototype:[Experiment foobotPrototype]];
    //Group *h=[Group groupWithName:@"human" andPrototype:[Experiment humanPrototype]];
    
    Group *h=[Group groupWithName:@"human" andPrototype:[Experiment carefullHumanPrototype]];
    
    Group *me=[Group groupWithName:@"me" andPrototype:[Experiment interactiveHumanPrototype]];
    
    Group *big=[Group groupWithName:@"bigbot" andPrototype:[Experiment bigbotPrototype]];
    
    Group *social=[Group groupWithName:@"socialFootbot" andPrototype:[Experiment socialFoobotPrototype]];
    
    
    [groups addObject:a];
    [groups addObject:f];
    [groups addObject:h];
    [groups addObject:me];
    [groups addObject:big];
    [groups addObject:social];
    
    a.number=0;
    f.number=0;
    h.number=0;
    me.number=0;
    big.number=0;
    social.number=0;
    
    
    Group *a1=[self groupWithName:@"agent#1"];
    Group *a2=[self groupWithName:@"agent#2"];
    
    a1.number=0;
    a2.number=0;
    
    a1.prototype.personality=resolute;
    a2.prototype.personality=irresolute;
    
    a1.prototype.optimalSpeed=0.8;
    a2.prototype.optimalSpeed=0.2;
    
    a1.prototype.control=HUMAN_LIKE;
    a2.prototype.control=HUMAN_LIKE;
    
    a1.prototype.safetyMargin=0.1;
    a1.prototype.socialMargin=0.1;
    a2.prototype.safetyMargin=0.1;
    a2.prototype.socialMargin=0.1;
    
    
    Group *a3=[Group groupWithName:@"myopicAgent" andPrototype:[Experiment myopicAgentPrototype]];
    
    [groups addObject:a3];
    
    a3.number=0;
    
        
    a3.prototype.optimalSpeed=0.3;
    a3.prototype.control=HUMAN_LIKE;
    a3.prototype.safetyMargin=0.1;
    a3.prototype.safetyMargin=0.1;

    
    observing=NO;
    return self;
}

-(void)resetPrototypeOfGroup:(Group *)g
{
    if([g.prototype isMemberOfClass:[Footbot class]])
    {
        g.prototype=[[self class] foobotPrototype];
    }
    else if([g.prototype isMemberOfClass:[Human class]])
    {
        g.prototype=[[self class] humanPrototype];
    }
    else
    {
        g.prototype=[[self class] agentPrototype];
    }
}

+(Agent*)agentPrototype
{
    Agent *a=[[[Agent alloc] init] autorelease];
    a.control=RVO_C;//HUMAN_LIKE;
    a.tau=0.125;
    a.eta=4*a.tau;
    a.controlUpdatePeriod=0.1;
    a.optimalSpeed=1;
    a.aperture=3.2;
    a.resolution=200;
    a.horizon=10;
    a.radius=0.12;
    a.socialMargin=0;
    a.safetyMargin=0;
    a.sensor=vision;
    a.visibilityRange=10;
    a.pathMargin=1;
    a.visibilityFOV=a.aperture;
    return a;
}
               
+(myopicAgent*)myopicAgentPrototype
    {
        myopicAgent *a=[[[myopicAgent alloc] init] autorelease];
        a.control=HUMAN_LIKE;
        a.tau=0.125;
        a.eta=4*a.tau;
        a.controlUpdatePeriod=0.1;
        a.optimalSpeed=1;
        a.aperture=3.2;
        a.resolution=200;
        a.horizon=10;
        a.radius=0.12;
        a.socialMargin=0.0;
        a.safetyMargin=0.0;
        a.sensor=vision;
        a.visibilityRange=10;
        a.pathMargin=1;
        a.visibilityFOV=a.aperture;
        return a;
    }
               
               

+(Footbot*)foobotPrototype
{
    Footbot *a=[[[Footbot alloc] init] autorelease];
    a.control=HUMAN_LIKE;//RVO_C;//HUMAN_LIKE;
    a.tau=0.2;
    a.eta=4*a.tau;
    a.controlUpdatePeriod=0.1;
    a.optimalSpeed=0.3;
    a.aperture=PI;
    a.resolution=40;
    a.horizon=3;
    a.timeHorizon=5;
    a.radius=0.17*0.5;
    a.safetyMargin=0.1;
    a.socialMargin=0.2;
    
    a.bearingErrorStd=0;
    a.rangeErrorStd=0;
    a.sensor=rab;
    a.rabMemoryExpiration=3.0;
    a.visibilityRange=5;
    a.pathMargin=0.7;
    
    a.visibilityFOV=a.aperture;
    
    return a;
}

+(Footbot*) socialFoobotPrototype
{
    SocialFootbot *a=[[[SocialFootbot alloc] init] autorelease];
    a.control=HUMAN_LIKE;
    a.tau=0.2;
    a.eta=4*a.tau;
    a.controlUpdatePeriod=0.1;
    a.optimalSpeed=0.3;
    a.aperture=PI;
    a.resolution=40;
    a.horizon=3;
    a.timeHorizon=5;
    a.radius=0.17*0.5;
    a.safetyMargin=0.1;
    a.socialMargin=0.2;
    
    a.bearingErrorStd=0;
    a.rangeErrorStd=0;
    a.sensor=obstructed_vision;//rab;
    a.rabMemoryExpiration=3.0;
    a.visibilityRange=5;
    a.pathMargin=0.7;
    
    a.visibilityFOV=a.aperture;
    
    return a;
}

+(Footbot*)bigbotPrototype
{
    Footbot *a=[[[Footbot alloc] init] autorelease];
    
    a.tau=0.5;
    a.eta=0.5;
    a.controlUpdatePeriod=0.1;
    a.optimalSpeed=1.3;
    a.aperture=1.6;
    a.resolution=100;
    a.horizon=10;
    a.timeHorizon=10;
    a.radius=0.2;
    a.safetyMargin=0.2;
    a.socialMargin=0.2;
    a.sensor=obstructed_vision;
    a.positionSensingErrorStd=0.008;
    
    a.visibilityRange=8;
    a.visibilityFOV=1;
    
    a.pathMargin=2;
    
    a.maxSpeed=1;
    a.wheelAxis=a.radius/0.085*WHEEL_AXIS_FOOTBOTS;
    
#ifdef RVO_HOLO
    [a setDefaultHolonomicDistance];
#endif
    
    return a;
}



+(Human*)carefullHumanPrototype
{
    Human *a=[[[CarefulHuman alloc] init] autorelease];
    
    
    
    a.control=HUMAN_LIKE;
    a.tau=0.5;
    a.eta=2*a.tau;
    a.controlUpdatePeriod=0.05;
    a.optimalSpeed=1.3;
    a.aperture=1.6;
    a.resolution=100;
    a.horizon=6;
    a.timeHorizon=12;
    a.mass=80;
    a.safetyMargin=0.25;
    a.socialMargin=0.5;
    a.sensor=vision;
    a.visibilityRange=10;
    a.pathMargin=1;
    
    a.visibilityFOV=a.aperture;
    
    return a;
}

+(Human*)humanPrototype
{
    
    Human *a=[[[Human alloc] init] autorelease];
    
    a.control=HUMAN_LIKE;
    a.tau=0.5;
    a.eta=a.tau;
    a.controlUpdatePeriod=0.1;
    a.optimalSpeed=1.3;
    a.aperture=PI/4;
    a.resolution=40;
    a.horizon=3;
    a.timeHorizon=6;
    a.mass=80;
    a.socialMargin=0;
    a.sensor=obstructed_vision;
    a.visibilityRange=10;
    a.pathMargin=1;
    
    a.visibilityFOV=a.aperture;
    
    return a;
}

+(Human*)interactiveHumanPrototype
{
    CarefulHuman *a=[[[CarefulHuman alloc] init] autorelease];
    a.control=HUMAN_LIKE;
    a.tau=0.5;
    a.eta=2*a.tau;
    a.controlUpdatePeriod=0.02;
    a.optimalSpeed=1.3;
    a.aperture=PI/4;
    a.resolution=100;
    a.horizon=6;
    a.timeHorizon=10;
    a.mass=80;
    a.safetyMargin=0.1;
    a.socialMargin=0.2;
    a.sensor=vision;
    a.visibilityRange=10;
    a.visibilityFOV=1.6;
    a.pathMargin=1;
    
    a.interaction=HEADING;
    
    return a;
}





-(void) initPath
{
    if(![[[self groupWithName:@"me"] members] count ]) return;
    
    
    Agent *a=[[[self groupWithName:@"me"] members] objectAtIndex:0];
    
    if(a)
    {
        //a.interaction=HEADING;
        a.targetAbsoluteAngle=a.angle;
    }
}

-(NSTimeInterval)minimalControlUpdatePeriod
{
    double t=1.0;
    for(Group *g in groups)
    {
        t=fmin(t,g.prototype.controlUpdatePeriod);
    }
    return t;
}

/*
 #define MARGIN 0.0//0.001
 
 -(void)addUniformDitributedCopiesOf:(Agent *)prototype inGrid:(NSPoint)grid1 grid2:(NSPoint)grid2 p0:(NSPoint)p0 maxCol:(int)maxCol maxRow:(int)maxRow num:(int)num
 {
 uint numOfCells=maxRow*maxCol;
 uint indices[numOfCells];
 uint index=0;
 for(;index<numOfCells;index++) indices[index]=index;
 
 uint numOfRemainingCells=numOfCells;
 
 uint c,r;
 
 NSPoint p;
 
 while(num>0 && numOfRemainingCells>0)
 {
 index=rand()%numOfRemainingCells;
 
 //NSLog(@"%d %d %d",index,numOfRemainingCells,indices[index]);
 
 c=indices[index] % maxCol;
 r=indices[index]/maxCol;
 
 p=NSMakePoint(p0.x+grid1.x*c+grid2.x*r-grid1.x*(r/2), p0.y+grid1.y*c+grid2.y*r-grid1.y*(r/2));
 
 [world addCopyOf:prototype atPoint:p];
 
 
 if(index+1<numOfRemainingCells)
 {
 memmove(indices+index, indices+index+1, (numOfRemainingCells-index-1)*sizeof(uint));
 }
 
 numOfRemainingCells--;
 num--;
 
 }
 }
 
 -(void)addRegularDistibutedCopiesOf:(Agent *)prototype inGrid:(NSPoint)grid1 grid2:(NSPoint)grid2 p0:(NSPoint)p0 maxCol:(int)maxCol maxRow:(int)maxRow num:(int)num
 {
 uint c=0;
 uint r=0;
 
 while(num>0 && r<maxRow)
 {
 while(c<maxCol)
 {
 [world addCopyOf:prototype atPoint:NSMakePoint(grid1.x*c+grid2.x*r, grid1.y*c+grid2.y*r)];
 c++;
 num--;
 }
 r++;
 }
 }
 */

/*
 -(void)alternativeAddCopiesOf:(Agent *)prototype withOccupancy:(double)occupancy inRect:(NSRect)rect
 {
 
 double r=prototype.radius+MARGIN+radiusStd;
 
 int maxNumOfColumns=floor(rect.size.width/r/2);
 int maxNumOfRows=floor((rect.size.height-2*r)/r/sqrt(3))+1;
 int n=maxNumOfColumns*maxNumOfRows;
 
 double d=rect.size.width/(double) maxNumOfColumns;
 
 NSPoint grid1=NSMakePoint(d, 0);
 NSPoint grid2=NSMakePoint(0.5*d, sqrt(3)*d*0.5);
 NSPoint p0=NSMakePoint(0.5*d+rect.origin.x, 0.5*d+rect.origin.y);
 
 //NSLog(@"%d %d %.4f",maxNumOfColumns,maxNumOfRows,d);
 
 // Random uniform distributed
 
 [self addUniformDitributedCopiesOf:prototype inGrid:grid1 grid2:grid2 p0:p0 maxCol:maxNumOfColumns maxRow:maxNumOfRows num:floor(n*occupancy)];
 }
 
 
 -(void)alternativeAdd:(NSInteger)num copiesOf:(Agent *)prototype inRect:(NSRect)rect
 {
 int columns,rows;
 
 
 double l=2*prototype.radius+MARGIN;
 
 int maxColumns=floor(rect.size.width/l);
 int maxRows=floor(rect.size.height/l);
 
 //double occupancy=(double)num/(maxColumns*maxRows);
 
 rows=ceil(fmin(sqrt(num*rect.size.height/rect.size.width),maxRows));
 
 if(!rows) return;
 
 columns=ceil(fmin(num/rows,maxColumns));
 
 if(!columns) return;
 
 uint r,c;
 NSPoint p;
 
 double width=rect.size.width/(columns+1);
 double height=rect.size.height/(rows+1);
 
 
 //BOOL debug=YES;
 for(r=0;r<rows;r++)
 {
 for(c=0;c<columns;c++)
 {
 p=NSMakePoint(0.5*width+rect.origin.x+c*width,0.5*height+rect.origin.y+r*height);
 //debug=NO;
 [world addCopyOf:prototype atPoint:p];
 }
 }
 }
 */

-(void)addGroup:(Group *)group betweenRadius:(double)r1 andRadius:(double)r2
{
    
    boost::mt19937 rng ( rand() );
    boost::uniform_real<> uniform(0,1);
    boost::variate_generator<boost::mt19937&, boost::uniform_real<> > u(rng, uniform);
    
    Agent *a;
    NSUInteger num=0;
    NSUInteger maxNum=group.number;
    
    double x,y,m;
    double angle;
    double radius;
    double dm=group.massStd;
    double m0=group.prototype.mass-dm;
    
    while(num<maxNum)
    {
        radius=u()*(r2-r1)+r1;
        angle=u()*TWO_PI;
        x=cosf(angle)*radius;
        y=sinf(angle)*radius;
        m=u()*2*dm+m0;
        a=[world addCopyOf:group.prototype atPoint:NSMakePoint(x,y)];
        a.mass=m;
        num++;
        
        [group.members addObject:a];
    }
    
    
}

-(void)addGroup:(Group *)group inRect:(NSRect)rect
{
    boost::mt19937 rng ( rand() );
    boost::uniform_real<> uniform(0,1);
    boost::variate_generator<boost::mt19937&, boost::uniform_real<> > u(rng, uniform);
    
    Agent *a;
    NSUInteger num=0;
    NSUInteger maxNum=group.number;
    
    double x,y,m;
    
    double h=rect.size.height;
    double w=rect.size.width;
    double x0=rect.origin.x;
    double y0=rect.origin.y;
    double dm=group.massStd;
    double m0=group.prototype.mass-dm;
    
    while(num<maxNum)
    {
        x=u()*w+x0;
        y=u()*h+y0;
        m=u()*2*dm+m0;
        a=[world addCopyOf:group.prototype atPoint:NSMakePoint(x,y)];
        a.mass=m;
        num++;
        
        [group.members addObject:a];
    }
    
    
}


-(void)addGroup:(Group *)group inRect:(NSRect)rect withOccupancy:(double)occupancy
{
    boost::mt19937 rng ( rand() );
    boost::uniform_real<> uniformX(rect.origin.x,rect.origin.x+rect.size.width);
    boost::variate_generator<boost::mt19937&, boost::uniform_real<> > xD(rng, uniformX);
    boost::uniform_real<> uniformY(rect.origin.y,rect.origin.y+rect.size.height);
    boost::variate_generator<boost::mt19937&, boost::uniform_real<> > yD(rng, uniformY);
    boost::uniform_real<> uniform(group.prototype.mass-group.massStd,group.prototype.mass+group.massStd);
    boost::variate_generator<boost::mt19937&, boost::uniform_real<> > massDist(rng, uniform);
    
    
    // NSLog(@"%.3f %.3f" ,group.prototype.mass,group.massStd);
    
    Agent *a;
    double area=rect.size.width*rect.size.height;
    double o=0;
    
    while(o<occupancy)
    {
        a=[world addCopyOf:group.prototype atPoint:NSMakePoint(xD(), yD())];
       
        a.mass=massDist();
         //NSLog(@"%@ %.3f" ,a,a.radius);
        o+=(a.radius*a.radius*PI)/area;
        [group.members addObject:a];
    }
}



-(void) initAgents
{
    for (Group *group in groups)
    {
        [self addGroup:group inRect:world.arena];
        [group distributeSpeed];
    }
    
    [world distributeAgents];
}


-(Group *)defaultGroup
{
    return [groups objectAtIndex:0];
}

-(Group *)groupWithName:(NSString *)name
{
    for(Group *g in groups)
    {
        //NSLog(@"%@ == %@",name,g.name);
        if([g.name isEqualToString:name]) return g;
    }
    
    //if not, it has to be in the form (prototypeName)#(integer number)
    
    NSScanner *scanner=[NSScanner scannerWithString:name];
    NSString *groupName;
    BOOL hasIndex=[scanner scanUpToString:@"#" intoString:&groupName];
    
    if(!hasIndex) return [self defaultGroup];
    
    scanner.scanLocation++;
    
    int index=-1;
    
    hasIndex = hasIndex && [scanner scanInt:&index];
    
    
    if(!hasIndex) return [self defaultGroup];
    
    for(Group *g in groups)
    {
        //NSLog(@"%@ == %@",name,g.name);
        if([g.name isEqualToString:groupName])
        {
            Group *newGroup=[Group groupWithName:name andPrototype:[[[g prototype] copy] autorelease] ];
            [groups addObject:newGroup];
            return newGroup;
        }
    }
    
    return [self defaultGroup];
    
}

-(NSString *)csvHeader
{
    return @" --- exeriment header ---";
}
-(NSString *)csvLine
{
    return @" --- exeriment line ---";
}

-(NSString *)csvEmptyLine
{
    return @" --- exeriment line ---";
}


@end




@implementation WorldLine

-(id)initWithWorld:(World *)w
{
    self=[super initWithWorld:w];
    //[world.walls addObject:[Wall wallAtX:0 y:2 length:12 angle:0]];
    //[world.walls addObject:[Wall wallAtX:0 y:-2 length:12 angle:0]];
    world.arena=NSMakeRect(-12, -2, 24, 4);
    //world.number=4;
    
    
    
    [world addWallAtPoint:NSMakePoint(0,0) angle:80 length:10];
    
    
    Group *group=[groups lastObject];
    group.number=4;
    //Agent *a=group.prototype;
    //a.horizon=8;
    //a.optimalSpeed=4;
    //a.resolution=30;
    //a.socialMargin=0.01;
    //a.radius=1.5;
    
    return self;
}

-(void) initAgents
{
    [super initAgents];
    if(world.number<2) return;
    [[[world agents] objectAtIndex:0] setOptimalSpeed:2];
    [[[world agents] objectAtIndex:1] setOptimalSpeed:2];
    
    [world addPeriodicShadowsAgents:NSMakePoint(24, 0)];
    //[[[world agents] objectAtIndex:2] setDebug:YES];
    //[[[world agents] objectAtIndex:3] setDebug:YES];
}

-(void) initPath
{
    
    int type=0;
    for(Agent *a in world.agents)
    {
        
        a.type=type;
        
        [a setPath:@"200 0 -200 0"];
        [a advancePath:type];
        
        a.updatePathBlock=^BOOL(){
            if([a hasReachedTarget])
            {
                a.numberOfReachedTargets++;
                [a advancePath:1];
                return YES;
            }
            return NO;
        };
        
        type=!type;
        //[a setPath:@"12 0 -12 0"];
        //[a goToTheNearestPoint];
    }
}

@end

@implementation WorldCross

-(id)initWithWorld:(World *)w
{
    self=[super initWithWorld:w];
    //world.number=100;
    world.arena=NSMakeRect(-20, -20, 40, 40);
    
    Group *group=[groups lastObject];
    group.number=100;
    
    
    
    return self;
}

-(void) initPath
{
    for(Agent *a in world.agents)
    {
        if (rand()%2) [a setPath:@"0 14 0 -14"];
        else  [a setPath:@"14 0 -14 0"];
        [a goToTheNearestPoint];
    }
}

@end

@implementation WorldButterfly

-(id)initWithWorld:(World *)w
{
    self=[super initWithWorld:w];
    //world.number=1000;
    world.arena=NSMakeRect(-30, -30, 60, 60);
    
    
    Group *group=[groups lastObject];
    group.number=100;
    
    
    return self;
}

-(void) initPath
{
    for(Agent *a in world.agents)
    {
        [a setPath:@"-20 20 20 20 -20 -20 20 -20"];
        [a goToTheNearestPoint];
        a.updatePathBlock=^BOOL(){
            if([a hasReachedTarget])
            {
                a.numberOfReachedTargets++;
                [a advancePath:1];
                return YES;
            }
            return NO;
        };
    }
}

@end

@implementation WorldEdge

-(id)initWithWorld:(World *)w
{
    self=[super initWithWorld:w];
    //world.number=30;
    [world addWallAtPoint:NSMakePoint(1,1) angle:0 length:10];
    [world addWallAtPoint:NSMakePoint(0,-1) angle:0 length:9];
    [world addWallAtPoint:NSMakePoint(11,-9) angle:90 length:10];
    [world addWallAtPoint:NSMakePoint(9,-10) angle:90 length:9];
    
    world.arena=NSMakeRect(-10, -4, 20, 8);
    
    Group *group=[groups lastObject];
    group.number=30;
    
    
    return self;
}

-(void) initPath
{
    for(Agent *a in world.agents)
    {
        [a setPath:@"-9 0 10 0 11 -1 10 -10 11 -1 10 0"];
        a.updatePathBlock=^BOOL(){
            if([a hasReachedTarget])
            {
                a.numberOfReachedTargets++;
                [a advancePath:1];
                return YES;
            }
            return NO;
        };
    }
}

@end

@implementation WorldSquare


-(id)initWithWorld:(World *)w
{
    self=[super initWithWorld:w];
    world.number=100;
    world.arena=NSMakeRect(-12, -12, 24, 24);
    
    Group *group=[groups lastObject];
    group.number=100;
    
    
    return self;
}


-(void) initPath
{
    for(Agent *a in world.agents)
    {
        [a setPath:@"-10 10 10 10 10 -10 -10 -10"];
        //[a advancePath:(rand() %4)];
        a.updatePathBlock=^BOOL(){
            if([a hasReachedTarget])
            {
                a.numberOfReachedTargets++;
                [a advancePath:1];
                return YES;
            }
            return NO;
        };
    }
}

@end

@implementation WorldSlalom

-(id)initWithWorld:(World *)w
{
    self=[super initWithWorld:w];
    
    
    Group *group=[groups lastObject];
    group.number=1;
    
    [world addWallAtPoint:NSMakePoint(0,1) angle:0 length:12];
    [world addWallAtPoint:NSMakePoint(0,-1) angle:0 length:12];
    
    [world addWallAtPoint:NSMakePoint(-7,-0.5) angle:90 length:0.5];
    [world addWallAtPoint:NSMakePoint(-5,0.5) angle:90 length:0.5];
    [world addWallAtPoint:NSMakePoint(-3,-0.5) angle:90 length:0.5];
    [world addWallAtPoint:NSMakePoint(-1,0.5) angle:90 length:0.5];
    [world addWallAtPoint:NSMakePoint(1,-0.5) angle:90 length:0.5];
    [world addWallAtPoint:NSMakePoint(3,0.5) angle:90 length:0.5];
    [world addWallAtPoint:NSMakePoint(5,-0.5) angle:90 length:0.5];
    [world addWallAtPoint:NSMakePoint(7,0.5) angle:90 length:0.5];
    
    world.arena=NSMakeRect(-10, -1, 20, 2);
    return self;
}

-(void) initPath
{
    for(Agent *a in world.agents)
    {
        [a setPath:@"9 0 -9 0"];
        a.updatePathBlock=^BOOL(){
            if([a hasReachedTarget])
            {
                a.numberOfReachedTargets++;
                [a advancePath:1];
                return YES;
            }
            return NO;
        };
    }
}

@end

@implementation WorldCircle

-(id)initWithWorld:(World *)w
{
    self=[super initWithWorld:w];
    //world.number=1000;
    world.arena=NSMakeRect(-20, -20, 40, 40);
    
    Group *group=[groups lastObject];
    group.number=1000;
    
    [world addCircularWallAt:NSMakePoint(0, 0) startAngle:0 endAngle:TWO_PI radius:10 numberOfSegments:50];
    
    return self;
}


-(void) initPath
{
    for(Agent *a in world.agents)
    {
        [a setPathWithRadius:10.0 center:NSMakePoint(0, 0) segments:30];
        [a goToTheNearestPoint];
        //[a advancePath:(rand() %30)];
        
    }
}

@end

@implementation WorldDoubleCircle



-(id)initWithWorld:(World *)w
{
    self=[super initWithWorld:w];
    // world.number=100;
    world.arena=NSMakeRect(-20, -20, 40, 40);
    
    
    Group *group=[groups lastObject];
    group.number=100;
    Agent *a=group.prototype;
    a.optimalSpeed=2.0;
    a.horizon=4.0;
    
    return self;
}

-(void) initPath
{
    uint type;
    for(Agent *a in world.agents)
    {
        type=rand()%2;
        [a setPathWithRadius:10.0 center:NSMakePoint(0, 0) segments:30 direction:type];
        [a goToTheNearestPoint];
        a.updatePathBlock=^BOOL(){
            if([a hasReachedTarget])
            {
                a.numberOfReachedTargets++;
                [a advancePath:1];
                return YES;
            }
            return NO;
        };
        
        a.type=type;
        
    }
}


@end

@implementation WorldCircleWithWall



-(id)initWithWorld:(World *)w
{
    self=[super initWithWorld:w];
    // world.number=100;
    world.arena=NSMakeRect(-20, -20, 40, 40);
    
    [world addCircularWallAt:NSMakePoint(0,0) startAngle:0 endAngle:TWO_PI radius:2 numberOfSegments:50];
    [world addCircularWallAt:NSMakePoint(0,0) startAngle:0 endAngle:TWO_PI radius:4.5 numberOfSegments:50];
    
    
    //Group *h=[Group groupWithName:@"human" andPrototype:[Experiment humanPrototype]];
    
    [self groupWithName:@"human"].number=10;
    
    
    return self;
}

-(void) initPath
{
    static uint type=1;
    for(Agent *a in world.agents)
    {
        a.type=type;
        type=(type+1)%2;
        a.updatePathBlock=^BOOL(){
            double angle=atan2f(a.position.y,a.position.x);
            if(a.type==0)
            {
                angle+=HALF_PI;
            }
            else
            {
                angle-=HALF_PI;
            }
            
            a.target=NSMakePoint(a.position.x+5*cosf(angle),a.position.y+5*sinf(angle));
            return NO;
            
        };
    }
}

-(void)initAgents
{
    for (Group *group in groups)
    {
        [self addGroup:group betweenRadius:2.5 andRadius:4];
        [group distributeSpeed];
    }
    
    [world distributeAgents];
}


@end

@implementation WorldCircleWithWallMixed



-(id)initWithWorld:(World *)w
{
    self=[super initWithWorld:w];
    // world.number=100;
    world.arena=NSMakeRect(-20, -20, 40, 40);
    
    [world addCircularWallAt:NSMakePoint(0,0) startAngle:0 endAngle:TWO_PI radius:2 numberOfSegments:50];
    [world addCircularWallAt:NSMakePoint(0,0) startAngle:0 endAngle:TWO_PI radius:4.5 numberOfSegments:50];
    
    
    //Group *h=[Group groupWithName:@"human" andPrototype:[Experiment humanPrototype]];
    
    [self groupWithName:@"footbot"].number=00;
    
    
    //Group *f2=[Group groupWithName:@"footbot2" andPrototype:[Experiment foobotPrototype]];
    
    Group *f2=[self groupWithName:@"footbot#2"];
    
    f2.number=10;
    
    
    //[groups addObject:f2];
    
    return self;
}

-(void) initPath
{
    for(Agent *a in world.agents)
    {
        a.updatePathBlock=^BOOL(){
            double angle=atan2f(a.position.y,a.position.x);
            angle+=HALF_PI;
            a.target=NSMakePoint(a.position.x+5*cosf(angle),a.position.y+5*sinf(angle));
            return NO;
            
        };
    }
    
}

-(void)initAgents
{
    
    Group *f1=[self groupWithName:@"footbot"];
    Group *f2=[self groupWithName:@"footbot#2"];
    
    
    
    
    for (Group *group in groups)
    {
        [self addGroup:group betweenRadius:2.5 andRadius:4];
        [group distributeSpeed];
    }
    
    for(Agent *a in f1.members)
    {
        a.type=0;
    }
    for(Agent *a in f2.members)
    {
        a.type=1;
    }
    
    [world distributeAgents];
}


@end



@implementation WorldPeriodicLine





-(id)initWithWorld:(World *)w
{
    self=[super initWithWorld:w];
    world.density=0.4;
    
    
    
    
    
    //Group *group=[groups lastObject];
    //group.number=100;
    //group.massStd=20;
    //group.optimalSpeedStd=0.2;
    
    //Agent *a=group.prototype;
    //a.aperture=PI/4;
    //a.horizon=8;
    //a.optimalSpeed=1.3;
    //a.resolution=30;
    //a.socialMargin=0.01;
    //a.mass=80;
    
    
    [world addWallAtPoint:NSMakePoint(0,W_THICKNESS*0.5+1.5) angle:0 length:20];
    [world addWallAtPoint:NSMakePoint(0,-(W_THICKNESS*0.5+1.5)) angle:0 length:20];
    
    world.arena=NSMakeRect(-4,-1.5,8, 3.0);
    return self;
}



-(void) initAgents
{
    for (Group *group in groups)
    {
        [self addGroup:group inRect:world.arena withOccupancy:world.density];
        [group distributeSpeed];
    }
    
    [world distributeAgents];
    [world addPeriodicShadowsAgents:NSMakePoint(8, 0)];
}



-(void) initPath
{
    for(Agent *a in world.agents)
    {
        [a setPath:@"200 0 -200 0"];
        //[a advancePath:(rand() %2)];
    }
}


@end



@implementation WorldPeriodicLineMixed



-(id)initWithWorld:(World *)w
{
    self=[super initWithWorld:w];
    
    leftWall=[world addWallAtPoint:NSMakePoint(0,W_THICKNESS*0.5+2) angle:0 length:100];
    rightWall=[world addWallAtPoint:NSMakePoint(0,-(W_THICKNESS*0.5+2)) angle:0 length:100];
    
    world.arena=NSMakeRect(-8,-2,16, 4);
    
    self.width=2;
    
    title=@"Periodic corridor";
    
    
    Group *f1=[self groupWithName:@"footbot"];
    
    f1.prototype.sensor=obstructed_vision;
    f1.number=0;
    
    Group *f3=[self groupWithName:@"socialFootbot#3"] ;
    
    //Group *f3=[Group groupWithName:@"footbot3" andPrototype:[Experiment socialFoobotPrototype]];
    
    f3.number=00;
    f3.prototype.visibilityFOV=1;
    f3.prototype.aperture=1;
    
    
    Group *f2=[self groupWithName:@"socialFootbot#2"] ;
    
    //Group *f2=[Group groupWithName:@"footbot2" andPrototype:[Experiment socialFoobotPrototype]];
    f2.number=00;
    f2.prototype.visibilityFOV=1;
    f2.prototype.aperture=1;
    
    
    //[groups addObject:f2];
    //[groups addObject:f3];
    
    return self;
}

@synthesize width;

-(void)setWidth:(double)w
{
    world.arena=NSMakeRect(-8,-w/2,16, w);
    leftWall.y=W_THICKNESS*0.5+w/2;
    rightWall.y=-W_THICKNESS*0.5-w/2;
}

-(double)width
{
    return world.arena.size.height;
}


-(void) initAgents
{
    [super initAgents];
    [world addPeriodicShadowsAgents:NSMakePoint(16, 0)];
    
    
    
    Group *f1=[self groupWithName:@"socialFootbot#3"];
    Group *f2=[self groupWithName:@"socialFootbot#2"];
    
    
    
    
    for(SocialFootbot *a in f1.members)
    {
        a.type=0;
        //a.baseEta=a.eta;
    }
    for(SocialFootbot *a in f2.members)
    {
        a.type=1;
        //a.baseEta=a.eta;
    }
    
}

-(void) initPath
{
    
    for(Agent *a in world.agents)
    {
        
        [a setPath:@"40 0"];
        
        a.updatePathBlock=^BOOL(){
            
        
            
            
            if([a hasReachedTarget])
            {
                if(fabs(a.state)==escapingDeadlock)
                {
                    a.state=freeState;
                    [a advancePath:0];
                    return NO;
                }
                else
                {
                    return YES;
                }
            }
            return NO;
        };
        
        
    }
}

-(NSString*)csvHeader
{
    return @"width,length,density";
}

-(NSString*)csvLine
{
    return [NSString stringWithFormat:@"%.5f,%.5f,%.5f",world.arena.size.height,world.arena.size.width,world.density];
}

-(NSString*)csvEmptyLine
{
	return @",,";
}


@end





@implementation WorldDoublePeriodicLine



-(id)initWithWorld:(World *)w
{
    self=[super initWithWorld:w];
    
    /*
     Group *group=[groups lastObject];
     group.number=60;
     Agent *a=group.prototype;
     a.aperture=PI/2;
     a.horizon=10;
     a.optimalSpeed=1.3;
     a.resolution=40;
     a.socialMargin=0.0;
     a.mass=80;
     */
    
    leftWall=[world addWallAtPoint:NSMakePoint(0,W_THICKNESS*0.5+2) angle:0 length:100];
    rightWall=[world addWallAtPoint:NSMakePoint(0,-(W_THICKNESS*0.5+2)) angle:0 length:100];
    
    
    //world.arena=NSMakeRect(-16,-3.5,32, 7);
    world.arena=NSMakeRect(-8,-2,16, 4);
    
    self.width=4;
    
    title=@"Two streams in a corridor";
    return self;
}

@synthesize width;

-(void)setWidth:(double)w
{
    world.arena=NSMakeRect(-8,-w/2,16, w);
    leftWall.y=W_THICKNESS*0.5+w/2;
    rightWall.y=-W_THICKNESS*0.5-w/2;
}

-(double)width
{
    return world.arena.size.height;
}


-(void) initAgents
{
    [super initAgents];
    [world addPeriodicShadowsAgents:NSMakePoint(16, 0)];
    
}

-(void) initPath
{
    [super initPath];
    int type=0;
    
    for(Agent *a in world.agents)
    {
        //a.type=rand() %2;
        
        a.type=type;
        
        type=!type;
        [a setPath:@"200 0 -200 0"];
        [a advancePath:a.type];
        
        
        
        a.updatePathBlock=^BOOL(){
            if([a hasReachedTarget])
            {
                if(fabs(a.state)==escapingDeadlock)
                {
                    a.state=freeState;
                    [a advancePath:0];
                    return NO;
                }
                else
                {
                    return YES;
                }
            }
            return NO;
        };
        
        
    }
}

-(NSString*)csvHeader
{
    return @"width,length,density";
}

-(NSString*)csvLine
{
    return [NSString stringWithFormat:@"%.5f,%.5f,%.5f",world.arena.size.height,world.arena.size.width,world.density];
}

-(NSString*)csvEmptyLine
{
	return @",,";
}


@end


@implementation NCCRLine


-(id)initWithWorld:(World *)w
{
    self=[super initWithWorld:w];
    
    
    self.width=4;
    
    title=@"Two streams in a corridor";
    
    
    Group *me=[self groupWithName:@"me"];
    Group *f=[self groupWithName:@"footbot"];
    Group *b=[self groupWithName:@"bigbot"];
    
    b.number=26;
    b.optimalSpeedStd=0.07;
    b.prototype.tau=0.25;
    b.prototype.optimalSpeed=1.1;
    me.prototype.eta=1;
    me.number=1;
    f.number=0;
    
    return self;
}

@end


@implementation Experiment (random)

#define RADIUS 5

-(void) moveAgentTargetAtRandomAngle:(Agent *)a
{
    static boost::mt19937 rng ( rand() );
    static boost::uniform_real<> uniform(0.5*PI,1.5*PI);
    static boost::variate_generator<boost::mt19937&, boost::uniform_real<> > angle(rng, uniform);
    
    double alpha=atan2(a.position.y, a.position.x)+angle();
    
    a.target=NSMakePoint(RADIUS*cos(alpha),RADIUS*sin(alpha));
    a.velocity=NSMakePoint(a.target.x-a.position.x, a.target.y-a.position.y);
    a.velocity=NSMakePoint(a.velocity.x/a.speed*a.optimalSpeed, a.velocity.y/a.speed*a.optimalSpeed);
    a.desideredVelocity=a.velocity;
    a.angle=atan2(a.velocity.y, a.velocity.x);
}


@end

@implementation WorldRandom


-(id)initWithWorld:(World *)w
{
    self=[super initWithWorld:w];
    world.number=2;
    world.arena=NSMakeRect(-5,-5,10,10);
    
    
    
    Group *group=[groups lastObject];
    group.number=2;
    Agent *a=group.prototype;
    a.aperture=PI/2;
    a.horizon=10;
    a.optimalSpeed=1.3;
    a.resolution=40;
    a.socialMargin=0;
    a.mass=80;
    
    
    
    
    return self;
}






-(void) moveAgentAtRandomAngle:(Agent *)a;
{
    static boost::mt19937 rng ( rand() );
    static boost::uniform_real<> uniform(0,2*PI);
    static boost::variate_generator<boost::mt19937&, boost::uniform_real<> > angle(rng, uniform);
    
    double alpha=angle();
    a.position=NSMakePoint(RADIUS*cos(alpha),RADIUS*sin(alpha));
}




-(void) initAgents
{
    for (Group *group in groups)
    {
        
        Agent *p=group.prototype;
        
        int k=0;
        Agent *a;
        for(;k<group.number;k++)
        {
            a=[world addCopyOf:p atPoint:NSMakePoint(0, 0)];
            [self moveAgentAtRandomAngle:a];
            [self moveAgentTargetAtRandomAngle:a];
        }
        
        [group distributeMass];
        [group distributeSpeed];
        
    }
    
    [world distributeAgents];
    
    
}

-(void) initPath
{
    for(Agent *a in world.agents)
    {
        a.updatePathBlock=^BOOL(){
            if([a hasReachedTarget])
            {
                a.numberOfReachedTargets++;
                [self moveAgentTargetAtRandomAngle:a];
                return YES;
            }
            return NO;
        };
    }
    
}

@end

@implementation WorldLEDs




-(id)initWithWorld:(World *)w
{
    self=[super initWithWorld:w];
    //world.number=2;
    world.arena=NSMakeRect(-3,-3,6,6);
    title=@"Four cones crossroad";
    
    const CGFloat c1[3]={0.0,1.0,0.0};
    const CGFloat c2[3]={1.0,0.0,0.0};
    const CGFloat c3[3]={0.0,0.0,1.0};
    const CGFloat c4[3]={1.0,1.0,0.0};
    
    
    Group *f=[self groupWithName:@"footbot"];//[Group groupWithName:@"footbot" andPrototype:[Experiment foobotPrototype]];
    Group *h=[self groupWithName:@"human"];//[Group groupWithName:@"human" andPrototype:[Experiment humanPrototype]];
    
    f.number=0;
    h.number=0;
    
    
    /*
    Group *a1=[self groupWithName:@"agent#1"];
    Group *a2=[self groupWithName:@"agent#2"];
    
    a1.number=5;
    a2.number=15;
    
    a1.prototype.personality=resolute;
    a2.prototype.personality=irresolute;
    
    a1.prototype.control=HUMAN_LIKE;
    a2.prototype.control=HUMAN_LIKE;
    
    a1.prototype.safetyMargin=0.1;
    a1.prototype.socialMargin=0.1;
    a2.prototype.safetyMargin=0.1;
    a2.prototype.socialMargin=0.1;
     */
    
    //[groups addObject:f];
    //[groups addObject:h];
    
    
    m1=[world addMarkerAtPoint:NSMakePoint(0,3) withColor:c1];
    m2=[world addMarkerAtPoint:NSMakePoint(0,-3) withColor:c2];
    m3=[world addMarkerAtPoint:NSMakePoint(3,0) withColor:c3];
    m4=[world addMarkerAtPoint:NSMakePoint(-3,0) withColor:c4];
    
    
    
    width=6;
    return self;
    
}



@synthesize width;

-(double)width
{
    return width;
}

-(void)setWidth:(double)w
{
    width=w;
    world.arena=NSMakeRect(-0.5*width,-0.5*width,width,width);
    m1.position=NSMakePoint(0,width*0.5);
    m2.position=NSMakePoint(0,-width*0.5);
    m3.position=NSMakePoint(width*0.5,0);
    m4.position=NSMakePoint(-width*0.5,0);
}


-(NSString*)csvHeader
{
    NSMutableString *s=[NSMutableString string];
    NSUInteger i=0;
    for(WorldMarker *m in world.markers)
    {
        i++;
        if(i>1)[s appendString:@","];
        [s appendFormat:@"target %ld x,target %ld y",i,i];
    }
    
    return s;
}

-(NSString*)csvLine
{
    NSMutableString *s=[NSMutableString string];
    BOOL first=YES;
    for(WorldMarker *m in world.markers)
    {
        if(!first)[s appendString:@","];
        first=NO;
        [s appendFormat:@"%.5f,%.5f",m.position.x,m.position.y];
    }
    
    return s;
}

-(NSString*)csvEmptyLine
{
	return [@"" stringByPaddingToLength:([world.markers count]*2-1) withString: @"," startingAtIndex:0];
}


/*
 -(void) moveAgentTargetAtRandomAngle:(Agent *)a
 {
 
 if([world.markers count]<4) return;
 
 uint n;
 
 if(a.target.x==0)
 {
 if(a.target.y>0)n=0;
 else n=1;
 }
 else  if(a.target.x>0)n=2;
 else n=3;
 
 //a.target=[(WorldMarker *)[world.markers objectAtIndex:((n+1)%4)] position];
 
 uint u=rand()%3+1;
 a.target=[(WorldMarker *)[world.markers objectAtIndex:(n+u)%4] position];
 
 
 
 }
 */



-(void) initPath
{
    
    [super initPath];
    
    int type=0;
    
    for(Agent *a in world.agents)
    {
        if([a isMemberOfClass:[Human class]])
        {
            [a setPath:@"-5 5 5 -5"];
            continue;
        }
        type=!type;
        if(type) [a setPathWithMarkers:[[world markers] subarrayWithRange:NSMakeRange(0, 2)]]; //[a setPath:@"0 3 0 -3"];
        else [a setPathWithMarkers:[[world markers] subarrayWithRange:NSMakeRange(2, 2)]];//[a setPath:@"3 0 -3 0"];
        
        a.updatePathBlock=^BOOL(){
            if([a hasReachedTarget])
            {
                if(a.isEscaping)
                {
                    a.state=freeState;
                    [a advancePath:0];
                    a.isEscaping=NO;
                    return NO;
                }
                else
                {
                    a.numberOfReachedTargets++;
                    [a advancePath:1];
                    return YES;
                }
            }
            return NO;
        };
        
    }
    
    
    
    
    //    [super initPath];
}

@end


@implementation NCCRCross

-(id)initWithWorld:(World *)w
{
    self=[super initWithWorld:w];
    
    
    
    Group *b=[self groupWithName:@"bigbot"];//[Group groupWithName:@"footbot" andPrototype:[Experiment foobotPrototype]];
    Group *h=[self groupWithName:@"human"];//[Group groupWithName:@"human" andPrototype:[Experiment humanPrototype]];
    Group *m=[self groupWithName:@"me"];
    Group *f=[self groupWithName:@"footbot"];
    
    m.number=1;
    h.number=2;
    b.number=30;
    f.number=0;
    b.optimalSpeedStd=0.07;
    
    b.prototype.tau=0.25;
    m.prototype.eta=1;
    b.prototype.optimalSpeed=1.1;
    
    self.width=30;
    
    
    [world addWallAtPoint:NSMakePoint(20,0) angle:90 length:20];
    [world addWallAtPoint:NSMakePoint(-20,0) angle:90 length:20];
    [world addWallAtPoint:NSMakePoint(0,20) angle:0 length:20];
    [world addWallAtPoint:NSMakePoint(0,-20) angle:0 length:20];
    
    
    
    
    return self;
    
}


-(void) initPath
{
    
    [super initPath];
    
    int type=0;
    
    for(Agent *a in world.agents)
    {
        type=!type;
        if(type) [a setPathWithMarkers:[[world markers] subarrayWithRange:NSMakeRange(0, 2)]]; //[a setPath:@"0 3 0 -3"];
        else [a setPathWithMarkers:[[world markers] subarrayWithRange:NSMakeRange(2, 2)]];//[a setPath:@"3 0 -3 0"];
        
        a.updatePathBlock=^BOOL(){
            if([a hasReachedTarget])
            {
                if(a.state==escapingDeadlock)
                {
                    a.state=freeState;
                    [a advancePath:0];
                    return NO;
                }
                else
                {
                    a.numberOfReachedTargets++;
                    [a advancePath:1];
                    return YES;
                }
            }
            return NO;
        };
        
    }
    
}

@end


@implementation WorldAntipode

@synthesize radius,isOneWayTarget;

-(id)initWithWorld:(World *)w
{
    self=[super initWithWorld:w];
    
    //[world addWallAtPoint:NSMakePoint(0,0.5) angle:0 length:0.5];
    // [world addWallAtPoint:NSMakePoint(0,-0.5) angle:0 length:0.5];
    //[world addWallAtPoint:NSMakePoint(0.5,0) angle:90 length:0.5];
    //[world addWallAtPoint:NSMakePoint(-0.5,0.5) angle:90 length:2];
    
    Group *f=[self groupWithName:@"footbot"];//[Group groupWithName:@"footbot" andPrototype:[Experiment foobotPrototype]];
    //[groups addObject:f];
    
    
    f.number=50;
    f.prototype.pathMargin=0.1;
    f.prototype.tau=0.5;
    f.prototype.eta=0.5;
    f.prototype.visibilityFOV=1.6;
    f.prototype.visibilityRange=10;
    f.prototype.horizon=10;
    f.prototype.safetyMargin=0.1;
    f.prototype.socialMargin=0.1;
    f.prototype.sensor=obstructed_vision;
    f.prototype.resolution=201;
    
    title=@"Circle crossing";
    self.radius=5;
    self.isOneWayTarget=YES;
    return self;
}

-(void)setRadius:(double)r
{
    radius=r;
    world.arena=NSMakeRect(-radius,-radius,2*radius,2*radius);
}

-(double)radius
{
    return radius;
}

-(NSString*)csvHeader
{
    return @"radius";
}

-(NSString*)csvLine
{
    return [NSString stringWithFormat:@"%.5f",radius];
}

-(NSString*)csvEmptyLine
{
	return @"";
}

-(void) initAgents
{
    for (Group *group in groups)
    {
        
        Agent *p=group.prototype;
        
        int k=0;
        Agent *a;
        
        
        double da=TWO_PI/(double)group.number;
        
        double angle=0;
        
        for(;k<group.number;k++)
        {
            double dr=rand()*0.5/(double)RAND_MAX;
            
            a=[world addCopyOf:p atPoint:NSMakePoint((radius+dr)*cosf(angle), (radius+dr)*sinf(angle))];
            
            //a.angle=PI+angle;
            
            angle+=da;
            [group.members addObject:a];
            
            a.useEffectiveHorizon=NO;
            
        }
        
        [group distributeMass];
        [group distributeSpeed];
        
    }
    
    [world distributeAgents];
    
    
}

-(void) initPath
{
    
    [super initPath];
    
    for(Agent *a in world.agents)
    {
        [a setPathWithPoint:NSMakePoint(-a.position.x, -a.position.y)];
        
        a.updatePathBlock=^BOOL(){
            if([a hasReachedTarget])
            {
                if(fabs(a.state)==escapingDeadlock)
                {
                    a.state=freeState;
                    a.isEscaping=NO;
                    [a advancePath:0];
                    return NO;
                }
                else if(fabs(a.state)==freeState)
                {
                    a.numberOfReachedTargets++;
                    if(a.numberOfReachedTargets==2)
                    {
                        if(isOneWayTarget)
                        {
                            a.state=arrivedState;
                        }
                        else
                        {
                            [a advancePath:1];
                        }
                    }
                    else
                    {
                        [a advancePath:1];
                    }
                    return YES;
                }
            }
            return NO;
        };
    }
    
}

@end


@implementation WorldInteractive



-(id)initWithWorld:(World *)w
{
    self=[super initWithWorld:w];
    
    world.arena=NSMakeRect(-10,-10,10,10);
    
    Group *f=[self groupWithName:@"human"];
    
    f.number=1;
    
    return self;
}



-(void) initAgents
{
    [super initAgents];
    
    
}

-(void)initPath
{
    [super initPath];
}

@end


@implementation TraceExperiment


-(id)initWithWorld:(World *)w
{
    self=[super initWithWorld:w];
    self.title=@"Trace Comparison";
    return self;
}

-(void)setWidth:(double)w
{
    width=w;
    world.arena=NSMakeRect(-w*0.7,-w*0.7,w*1.4, w*1.4);
}

-(double)width
{
    return width;
}


-(void)initAgents
{
    BOOL firstAgent=YES;
    boost::mt19937 rng (seed);
    
    
    boost::uniform_real<> uniform(0,1);
    boost::variate_generator<boost::mt19937&, boost::uniform_real<> > u(rng, uniform);
    
    
    //double minimalGap=0.2;
    
    
    for (Group *group in groups)
    {
        
        Agent *p=group.prototype;
        
        int k=0;
        Agent *a;
        double angle;
        NSPoint position;
        BOOL separated=NO;
        for(;k<group.number;k++)
        {
            
                        
            if(firstAgent)
            {
                firstAgent=NO;
                position=NSMakePoint(0, 0);
                angle=0;
            }
            else
            {
                angle=u()*2*PI;;
                separated=NO;
                while(!separated)
                {
                
                position=NSMakePoint((u()-0.5)*width,(u()-0.5)*width);
                separated=YES;
                for(Agent *o in world.agents)
                {
                    double l=o.radius+p.radius+p.safetyMargin+2*a.tau*a.optimalSpeed;
                    double d=sqrt((position.x-o.position.x)*(position.x-o.position.x)+(position.y-o.position.y)*(position.y-o.position.y));
                    //NSLog(@"%.2f,%.2f,%d",l,d,d<l);
                    if(d<l)
                    {
                        //NSLog(@"Ritenta!!");
                        separated=NO;
                        break;
                    }
                }
                
                }
                
            }
            

            a=[world addCopyOf:p atPoint:position];
            a.angle=angle;
            a.velocity=NSMakePoint(0, 0);
            [group.members addObject:a];
            
            a.useEffectiveHorizon=NO;
            a.shouldEscapeDeadlocks=NO;
            a.shouldEscapeDeadlocks=NO;
        }
    }
}

-(void)initPath
{
    double tD=10.0;
    for(Agent *a in world.agents)
    {
        double x=a.position.x+cos(a.angle)*tD;
        double y=a.position.y+sin(a.angle)*tD;
        [a setPathWithPoint:NSMakePoint(x,y)];
        [a advancePath:1];
        
        a.velocity=NSMakePoint(a.optimalSpeed*cos(a.angle), a.optimalSpeed*sin(a.angle));
        
        
        a.updatePathBlock=^BOOL(){
            if([a hasReachedTarget])
            {
                //! con ros non funziona bene, dovrei mettere che arrivedState implica che targetVelocity=0, non che i motori restano spenti!!
                a.numberOfReachedTargets++;
                a.state=arrivedState;
                return YES;
            }
            return NO;
        };
        
        
        //NSLog(@"(%.2f %.2f) (%.2f %.2f)",a.position.x,a.position.y,a.target.x,a.target.y);
    }
}

@synthesize width;

-(NSString*)csvHeader
{
    return @"width";
}

-(NSString*)csvLine
{
    return [NSString stringWithFormat:@"%.5f",width];
}

-(NSString*)csvEmptyLine
{
	return @"";
}


@end




@implementation EmotionPanicExperiment

-(id)initWithWorld:(World *)w
{
    self=[super initWithWorld:w];
    self.title=@"Emotion Panic (Frustation and Fear)";
    
    Group *f=[self groupWithName:@"footbot"];
    f.number=0;
    
    Group *a=[self groupWithName:@"agent#1"];
    a.number=50;
    a.prototype.optimalSpeed=0.3;
    a.prototype.shouldEscapeDeadlocks=YES;
    a.prototype.visibilityFOV=1;
    a.prototype.aperture=1;
    a.prototype.pathMargin=0.1;
    a.prototype.escapeThreshold=0.3;
    a.prototype.emotionModulationIsActive=6;
    a.prototype.shouldShowEmotion=YES;
    return self;
}


-(NSString*)csvHeader
{
    return @"radius,agent#1:frustationToEscape,modulation,show emotion";
}

-(NSString*)csvLine
{
    Group *a=[self groupWithName:@"agent#1"];
    return [NSString stringWithFormat:@"%.5f,%.3f,%ld,%d",radius,a.prototype.escapeThreshold,a.prototype.emotionModulationIsActive,a.prototype.shouldShowEmotion];
}

-(NSString*)csvEmptyLine
{
	return @",,,";
}



@end


@implementation EmotionConfusionExperiment

-(id)initWithWorld:(World *)w
{
    self=[super initWithWorld:w];
    self.title=@"Emotion Confusion";
    
    
    Group *a=[self groupWithName:@"agent#1"];
    a.number=10;
    a.prototype.optimalSpeed=0.3;
    a.prototype.shouldEscapeDeadlocks=NO;
    a.prototype.shouldShowEmotion=YES;
    a.prototype.emotionModulationIsActive=1;
    
    Group *m=[self groupWithName:@"myopicAgent"];
    m.number=3;
    m.prototype.optimalSpeed=0.3;
    m.prototype.shouldEscapeDeadlocks=NO;
    m.prototype.shouldShowEmotion=YES;
    m.prototype.emotionModulationIsActive=1;
    
    return self;
}

-(NSString*)csvHeader
{
    return @"modulation,show emotion,myopicAgent:targetQuality";
}



-(NSString*)csvLine
{
    Group *a=[self groupWithName:@"myopicAgent"];
    return [NSString stringWithFormat:@"%ld,%d,%.3f",(long)a.prototype.emotionModulationIsActive,a.prototype.shouldShowEmotion,a.prototype.targetSensingQuality];
}

-(NSString*)csvEmptyLine
{
	return @",";
}


@end

@implementation EmotionUrgencyExperiment

-(id)initWithWorld:(World *)w
{
    self=[super initWithWorld:w];
    self.title=@"Emotion Urgency";
    
    
    Group *a=[self groupWithName:@"agent#1"];
    a.number=15;
    a.prototype.optimalSpeed=0.3;
    a.prototype.shouldEscapeDeadlocks=NO;
    a.prototype.personality=irresolute;
    a.prototype.shouldShowEmotion=YES;
    a.prototype.emotionModulationIsActive=8;
    
    Group *b=[self groupWithName:@"agent#2"];
    b.number=5;
    b.prototype.optimalSpeed=0.3;
    b.prototype.shouldEscapeDeadlocks=NO;
    b.prototype.personality=resolute;
    b.prototype.shouldShowEmotion=YES;
    b.prototype.emotionModulationIsActive=8;
    b.prototype.radius=0.12;
    
    return self;
}

-(NSString*)csvHeader
{
    return @"modulation,show emotion";
}



-(NSString*)csvLine
{
    Group *a=[self groupWithName:@"agent#2"];
    return [NSString stringWithFormat:@"%ld,%d",a.prototype.emotionModulationIsActive,a.prototype.shouldShowEmotion];
}

-(NSString*)csvEmptyLine
{
	return @",";
}


@end

@implementation EmotionUrgency2Experiment
@end




//
//  Agent.m
//  MultiAgent
//
//  Created by Jérôme Guzzi on 10/22/10.
//  Copyright 2010 Idsia. All rights reserved.
//

#import "Agent.h"
#import "Wall.h"
#include "ShadowAgent.h"
#include "World.h"
#ifdef REAL_TIME
#include "RealTimeWorld.h"
#endif
#ifdef DISPATCH
#import <dispatch/dispatch.h>
#endif

#import "HRVO/Obstacle.h"



static NSComparisonResult rabMessageSorter(id obj1,id obj2,void* context);

static double sign(double d)
{
	if(d>0) return 1.0;
	return -1.0;
}


double ratioOfSocialRadiusForSensing=1;
double socialRepulsion=30;
#define MIN_VISIBLE_ANGLE 0.01//0.001//0.01//0.1 //3.6 gradi



@interface Agent (Private)
-(double) staticDistanceAtRelativeAngle:(double)relativeAngle minDistance:(double) minDistance;
-(double) distanceToCollisionWithGlobalSensorAtRelativeAngle:(double)relativeAngle staticCache:(double*)staticCache;
-(double) distanceToCollisionWithCacheAtRelativeAngle:(double)relativeAngle;
@end

@implementation Agent

@synthesize  shouldShowEmotion,emotionModulationIsActive;


#pragma mark - libdispatch


#ifdef DISPATCH

+(dispatch_queue_t)rabQueue
{
    static dispatch_queue_t queue;
    if(!queue)
    {
        queue = dispatch_queue_create("com.jerome.multiagents.rabQueue ", DISPATCH_QUEUE_SERIAL);
    }
    return queue;
}

+(dispatch_queue_t)controlQueue
{
    static dispatch_queue_t queue;
    if(!queue)
    {
        queue = dispatch_queue_create("com.jerome.multiagents.controlQueue ", DISPATCH_QUEUE_SERIAL);//);
        //dispatch_suspend(queue);
    }
    return queue;
}

#endif


#pragma mark - init

@synthesize  type,state,numberOfDeadlocks,isEscaping;

-(Agent *)init
{
    self=[super init];
    if(self)
    {
#ifdef DEBUG
        [self initDebug];
#endif
        [self initPhysics];
        [self initSensing];
        [self initControl];
        [self initPerformance];
        
        interaction=NONE;
        
        RVOAgent=new RVO::Agent(NULL);
        HRVOAgent=new HRVO::Agent();
        
        numberOfEfficacityMeasures=0;
        cumulatedEfficacity=0;
        
        
    }
    return self;
}

-(void)reset
{
    self.velocity=NSMakePoint(0, 0);
    self.desideredVelocity=NSMakePoint(0, 0);
    _time=0;
    state=freeState;
    isEscaping=NO;
    numberOfDeadlocks=0;
    numberOfEfficacityMeasures=0;
    numberOfHits=0;
    numberOfReachedTargets=0;
    cumulatedEfficacity=0;
    throughputEfficiency=0;
    pathLength=0;
    cumulatedExtraRotation=0;
    cumulatedPathLength=0;
    cumulatedRotation=0;
    pathDuration=0;
    hasHit=NO;
    dt=0;
}


-(void)dealloc
{
#ifdef USE_BULLET_FOR_COLLISION
    delete collisionObject;
    
#endif
#ifdef USE_BULLET_FOR_SENSING
    delete horizonObject;
#endif
#ifdef SENSING_ERROR
    if(rng) delete rng;
    if(errorDistribution) delete errorDistribution;
#endif
    
    free(path);
    [nearAgentsStatic release];
    [nearAgents release];
    [agentsAtContact release];
    [agentsNowAtContact release];
    [rabCacheCollection release];
    self.currentPathMarker=nil;
    self.pathMarkers=nil;
    
    //NSLog(@"-");
    
    
    if(RVOAgent)
    {
        for(int i=0;i<RVOAgent->obstacleNeighbors_.size();i++)
        {
            delete RVOAgent->obstacleNeighbors_[i].second;
        }
        
        
        
        for(int i=0;i<agentNeighbors.size();i++)
        {
            delete agentNeighbors[i];
        }
        
        
        
        delete RVOAgent;
    }
    
    
	[super dealloc];
}


- (id)copyWithZone:(NSZone *)zone
{
    Agent *copy = [[[self class] allocWithZone: zone] init];
    
    copy.tau=self.tau;
    copy.eta=eta;
    copy.control=self.control;
    copy.controlUpdatePeriod=self.controlUpdatePeriod;
    copy.resolution=self.resolution;
    copy.aperture=self.aperture;
    copy.horizon=self.horizon;
    copy.safetyMargin=self.safetyMargin;
    copy.socialMargin=self.socialMargin;
    copy.radius=self.radius;
    copy.optimalSpeed=self.optimalSpeed;
    copy.sensor=self.sensor;
    copy.rabMemoryExpiration=self.rabMemoryExpiration;
    copy.pathMargin=self.pathMargin;
    copy.visibilityRange=self.visibilityRange;
    copy.visibilityFOV=self.visibilityFOV;
#ifdef SENSING_ERROR
    copy.speedSensingErrorStd=self.speedSensingErrorStd;
    copy.positionSensingErrorStd=self.positionSensingErrorStd;
    copy.rangeErrorStd=self.rangeErrorStd;
    copy.bearingErrorStd=self.bearingErrorStd;
#endif
    
    copy.interaction=self.interaction;
    copy.timeHorizon=self.timeHorizon;
    copy.timeHorizonStatic=self.timeHorizonStatic;
    
    copy.shouldDetectDeadlocks=self.shouldDetectDeadlocks;
    copy.shouldEscapeDeadlocks=self.shouldEscapeDeadlocks;
    
    
    
    copy.personality=self.personality;
    
    
    copy.shouldShowEmotion=self.shouldShowEmotion;
    copy.emotionModulationIsActive=self.emotionModulationIsActive;
    copy.escapeThreshold=self.escapeThreshold;
        copy.targetSensingQuality=self.targetSensingQuality;
    return copy;
}


#pragma mark - debug




#ifdef DEBUG
@synthesize debug;
@synthesize oldAngle;
@synthesize observed;



-(void)initDebug
{
    self.debug=NO;
}

#endif

#pragma mark - sensing

@synthesize sensor;
@synthesize visibilityRange,visibilityFOV;
@synthesize rabID;
@synthesize rabMemoryExpiration;
#ifdef SENSING_ERROR
@synthesize speedSensingErrorStd,positionSensingErrorStd,rangeErrorStd,bearingErrorStd;
#endif
@synthesize nearAgentsStatic;



-(void)initSensing
{
    self.sensor=vision;
    static uint lastRabID=0;
    self.rabID=[NSString stringWithFormat:@"%d",lastRabID++];
    
    
#ifdef SENSING_ERROR
    self.rangeErrorStd=self.bearingErrorStd=0.0;
    self.speedSensingErrorStd=self.positionSensingErrorStd=0.0;
    errorDistribution=0;
    rng=new boost::mt19937(rand());
    boost::normal_distribution<> normal(0,1);
    errorDistribution=new boost::variate_generator<boost::mt19937&, boost::normal_distribution<> >(*rng, normal);
    
#endif
}



+(btCollisionShape *)horizonShape
{
    
    static btCollisionShape *shape;
    
    if(!shape)
    {
        //shape=new btCylinderShapeZ(btVector3(btScalar(RADIUS),btScalar(RADIUS),btScalar(HEIGHT/2)));
        //shape=new btSphereShape([[World world] horizon]);
        shape=new btSphereShape(0.1);
        //shape=new btBoxShape(btVector3(btScalar(RADIUS),btScalar(RADIUS),btScalar(HEIGHT/2)));
    }
    
    return shape;
}


/*
 -(void)printSector:(sector *)se
 {
 sector *s=se;
 while(s)
 {
 printf("%.3f,%.3f,",s->angle,s->distance);
 s=s->next;
 }
 }
 */

-(void) deleteSector:(sector *)s
{
    sector *n;
    while(s)
    {
        n=s;
        s=s->next;
        free(n);
    }
}

-(BOOL)addOstacleAtDistance:(double)distance angle:(double)gamma aperture:(double)alpha toSector:(sector *)se
{
    sector *s=se;
    bool visible=NO;
    double a=signedNormalize(gamma-alpha);
    double b=signedNormalize(gamma+alpha);
    double c;
    
    BOOL splitted=NO;
    
    if(a>b)
    {
        splitted=YES;
        c=a;
        a=-PI;
    }
    
    while(s->next)
    {
        if(s->angle>b)
        {
            if(splitted)
            {
                a=c;
                b=PI;
            }
            else
            {
                break;
            }
        }
        if(s->next->angle>a && s->distance>distance)
        {
            visible=YES;
            if(s->angle<a)
            {
                sector *n=(sector *)malloc(sizeof(sector));
                n->next=s->next;
                n->distance=distance;
                n->angle=a;
                s->next=n;
                if(n->next->angle>b)
                {
                    sector *m=(sector *)malloc(sizeof(sector));
                    m->next=n->next;
                    m->angle=b;
                    m->distance=s->distance;
                    n->next=m;
                    s=s->next;
                }
                s=s->next;
            }
            else if(s->next->angle>b)
            {
                sector *n=(sector *)malloc(sizeof(sector));
                n->next=s->next;
                n->distance=s->distance;
                n->angle=b;
                s->distance=distance;
                s->next=n;
                s=(sector *)s->next;
            }
            else
            {
                s->distance=distance;
            }
        }
        s=s->next;
    }
    if(visible)
    {
        s=se;
        while(s->next)
        {
            if(s->next->distance==s->distance)
            {
                sector *n=s->next;
                s->next=n->next;
                free(n);
            }
            s=s->next;
            if(!s)break;
        }
    }
    return visible;
}


-(ObstacleCache *)obstacleCacheForAgentWithRadius:(double)r
{
    
    ObstacleCache *obstacle=[[[ObstacleCache alloc] init] autorelease];
    obstacle.optimalSpeed=optimalSpeed;
    
    //obstacle.socialMargin=2*socialMargin*0.01+minDistance;
    return obstacle;
}

-(NSArray *)allVisibleAgents
{
    double d;
    double gamma,alpha,beta;
    BOOL visible;
    NSPoint dx;
    //NSMutableArray *candidates=[NSMutableArray array];
    
    NSMutableArray *candidates=nearAgentsStatic;
    
    ObstacleCache *obstacle;
    
    minimalDistanceToAgent=-2;
    
    for(Agent *agent in [[World world] allAgents])
    {
        if(agent==self) continue;
        
        NSPoint p=agent.position;
        
        dx=NSMakePoint(p.x-position.x,p.y-position.y);
        d=sqrt(dx.x*dx.x+dx.y*dx.y);
        
        if(minimalDistanceToAgent<-1) minimalDistanceToAgent=d-radius-agent.radius;
        else minimalDistanceToAgent=fmin(minimalDistanceToAgent,d-radius-agent.radius);
        
        
        if(d<(visibilityRange+agent.radius))
        {
            beta=atan2f(dx.y,dx.x);
            gamma=signedNormalize(beta-angle);
            alpha=asinf(agent.radius/d);
            visible=(fabs(gamma)<(visibilityFOV+alpha)) ;
            
            if(visible)
            {
                obstacle=[self obstacleCacheForAgentWithRadius:agent.radius];
                
#ifdef GUI
                if(debug) agent.observed+=1;
#endif
                obstacle.relativeAngle=gamma;
                obstacle.relativePosition=dx;
                obstacle.centerDistance=d;
                obstacle.visibleAngle=alpha;
                obstacle.angle=beta;
                obstacle.agent=agent;
                
                [candidates addObject:obstacle];
            }
        }
    }
    
    return candidates;
}

-(void)addMarkerObstacles
{
    for(WorldMarker *m in [[World world] markers])
    {
        
        if(m==currentPathMarker) continue;
        
        NSPoint dx=NSMakePoint(m.position.x-position.x,m.position.y-position.y);
        double dd=dx.x*dx.x+dx.y*dx.y;
        double d=sqrt(dd);
        
        double beta=atan2f(dx.y,dx.x);
        double gamma=signedNormalize(beta-angle);
        double alpha=asinf(0.5/d);
        
        ObstacleCache  *obstacle=[self obstacleCacheForAgentWithRadius:0.5];
        
        obstacle.relativeAngle=gamma;
        obstacle.relativePosition=dx;
        obstacle.centerDistance=d;
        obstacle.visibleAngle=alpha;
        obstacle.angle=beta;
        obstacle.agent=nil;
        obstacle.visibleDistance=d-0.5;
        obstacle.velocity=NSMakePoint(0,0);
        obstacle.centerDistanceSquare=dd;
        
        obstacle.sensingMargin=0.2;
        obstacle.minDistance=0.5+radius+obstacle.sensingMargin;
        
        obstacle.agentSensingMargin=0.5+obstacle.sensingMargin;
        
        obstacle.position=m.position;
        
        [nearAgentsStatic addObject:obstacle];
    }
}

-(NSArray *)visibleAgents
{
    double d;
    double gamma,alpha,beta;
    BOOL visible;
    
    NSPoint dx;
    
    sector *visibleSector=(sector *)malloc(sizeof(sector));
    sector *endSector=(sector *)malloc(sizeof(sector));
    visibleSector->angle=-visibilityFOV;
    visibleSector->distance=visibilityRange;
    visibleSector->next=endSector;
    endSector->next=0;
    endSector->angle=visibilityFOV;
    endSector->distance=0;
    
    NSMutableArray *candidates=nearAgentsStatic;
    
    ObstacleCache *obstacle;
    
    minimalDistanceToAgent=-2;
    
    for(Agent *agent in [[World world] allAgents])
    {
        if(agent==self) continue;
        
        
        dx=NSMakePoint(agent.position.x-position.x,agent.position.y-position.y);
        d=sqrt(dx.x*dx.x+dx.y*dx.y);
        
        if(minimalDistanceToAgent<-1) minimalDistanceToAgent=d-radius-agent.radius;
        else minimalDistanceToAgent=fmin(minimalDistanceToAgent,d-radius-agent.radius);
        
        if(d<(visibilityRange+agent.radius))
        {
            beta=atan2f(dx.y,dx.x);
            gamma=signedNormalize(beta-angle);
            alpha=asinf(agent.radius/d);
            visible=(fabs(gamma)<(visibilityFOV+alpha)) ;
            
            if(visible)
            {
#ifdef GUI
                if(debug) agent.observed+=1;
#endif
                
                visible=[self addOstacleAtDistance:d-agent.radius angle:gamma aperture:alpha toSector:visibleSector];
            }
            
            if(visible)
            {
                obstacle=[self obstacleCacheForAgentWithRadius:agent.radius];
                
                obstacle.relativeAngle=gamma;
                obstacle.relativePosition=dx;
                obstacle.centerDistance=d;
                obstacle.visibleAngle=alpha;
                obstacle.angle=beta;
                obstacle.agent=agent;
                obstacle.visibleDistance=d-agent.radius;
#ifdef GUI
                if(debug) agent.observed+=1;
#endif
                [candidates addObject:obstacle];
            }
            else
            {
#ifdef GUI
                if(debug) agent.observed+=2;
#endif
            }
        }
    }
    
    NSArray *allVisibleAgents=[NSArray arrayWithArray:candidates];
    
    for(ObstacleCache *obstacle in allVisibleAgents)
    {
        if(![obstacle visibleInSector:visibleSector atAngle:angle])
        {
            [candidates removeObject:obstacle];
#ifdef GUI
            if(debug) obstacle.agent.observed+=2;
#endif
        }
    }
    
    [self deleteSector:visibleSector];
    
    return candidates;
}




-(void)buildCacheWithVision
{
    
    //PERFORMANCE 10%
    
    //[nearAgentsStatic release];
    
    [nearAgentsStatic removeAllObjects];
    //    [nearAgents removeAllObjects];
    
    
    //nearAgentsStatic=[[NSMutableArray array] retain];
    
    if(sensor==vision)
    {
        [self allVisibleAgents];
    }
    else
    {
        [self visibleAgents];
    }
    
    for(ObstacleCache *obstacle in nearAgentsStatic)
    {
        [self senseObstacleWithVision:obstacle];
    }
    
    //[nearAgents release];
    //nearAgents=[[NSMutableArray arrayWithCapacity:[nearAgentsStatic count]] retain];
    
    
    //[nearAgents release];
    //nearAgents=[[self allVisibleAgents] retain];
    
    //[nearAgents setArray:[self allVisibleAgents]];
    
    
    
    /*
     [nearAgents UsingComparator:^NSComparisonResult(ObstacleCache *obj1, ObstacleCache *obj2) {
     return (obj1.minimalDistanceToCollision<obj2.minimalDistanceToCollision) ? NSOrderedAscending : NSOrderedDescending;
     }];
     */
    
    
    
    //[nearAgents sortUsingSelector:@selector(compare:)];
}


#ifdef RAB

-(NSDictionary *)messageFromAgentWithObstacle:(ObstacleCache *)obstacle
{
    double th=rabReliability;
    if(obstacle.centerDistance>1.5) th*=0.67;
    if(obstacle.centerDistance>2.5) th*=0;
    
    NSMutableDictionary *message=nil;
    
    if(rand()<RAND_MAX*th)
    {
        Agent *agent=obstacle.agent;
        
        
        //# TODO: not thread safe!
        
#ifdef USE_DISPATCH
        __block id returnValue;
        dispatch_sync([Agent rabQueue], ^(){
            returnValue = [[[Agent rabMessages] valueForKey:agent.rabID] mutableCopy];
        });
        message =returnValue;
#else
        message=[[[Agent rabMessages] valueForKey:agent.rabID] mutableCopy];
#endif
        
        
        
        BOOL addressedToMe=[[message valueForKey:@"targets"] containsObject:rabID];
        if(addressedToMe)
        {
            
            double s=[[message valueForKey:@"speed"] doubleValue];
            double h=[[message valueForKey:@"heading"] doubleValue];
            
            [message setValue:[NSValue valueWithPoint:NSMakePoint(cosf(h)*s,sinf(h)*s)] forKey:@"velocity"];
        }
    }
    return [message autorelease];
}

//To avoid having to loop through obstacles that are will not collide in any possible direction


-(void)computeCache
{
    [nearAgents removeAllObjects];
    for(ObstacleCache *obstacle in nearAgentsStatic)
    {
        [obstacle compute];
        double m=obstacle.minimalDistanceToCollision;
        double minRelevantDistanceToCollision=effectiveHorizon-radius;
        
        if(m!=NO_COLLISION && m<minRelevantDistanceToCollision)
        {
            [nearAgents addObject:obstacle];
#ifdef GUI
            if(debug) obstacle.agent.observed+=4;
#endif
        }
#ifdef GUI
        if(debug)
        {
            m=obstacle.minimalDistance;
            if(m!=NO_COLLISION && m<minRelevantDistanceToCollision)
            {
                obstacle.agent.observed+=8;
            }
        }
#endif
    }
}

-(void)buildCacheWithRab
{
    [nearAgentsStatic removeAllObjects];
    [self visibleAgents];
    
    NSMutableArray *restRabCaches=[NSMutableArray arrayWithArray:[rabCacheCollection allValues]];
    
    RabCache *rabCache;
    
    NSDictionary *message;
    
    NSTimeInterval time=[[World world] cTime];
    
    for (ObstacleCache *obstacle in nearAgentsStatic) {
        [self senseObstacleWithRab:obstacle];
        rabCache=[rabCacheCollection valueForKey:obstacle.agent.rabID];
        if((message=[self messageFromAgentWithObstacle:obstacle]) && [message valueForKey:@"velocity"])
        {
            obstacle.velocity=[[message valueForKey:@"velocity"] pointValue];
        }
        else if(rabCache)
        {
            obstacle.velocity=rabCache.obstacle.velocity;
        }
        else
        {
            obstacle.velocity=NSMakePoint(0,0);
        }
        
        if(!rabCache)
        {
            rabCache=[RabCache new];
            [rabCacheCollection setValue:rabCache forKey:obstacle.agent.rabID]; //ERROR PRONE BY SHADOW AGENTS AND RABID because they do NOT have a rabID
            [rabCache release];
        }
        else {
            [restRabCaches removeObject:rabCache];
        }
        
        rabCache.obstacle=obstacle;
        rabCache.lastContactTime=time;
        
        //WHY DID I HAVE TWO TIME this sensing?
        
        //[self senseObstacleWithRab:obstacle];
        
        rabCache.position=NSMakePoint(obstacle.relativePosition.x+position.x,obstacle.relativePosition.y+position.y);
    }
    
    deltaTime=controlUpdatePeriod;
    
    for(rabCache in restRabCaches)
    {
        
        if((time-rabCache.lastContactTime)>rabMemoryExpiration)
        {
            [rabCacheCollection removeObjectForKey:rabCache.obstacle.agent.rabID];
        }
        else
        {
            rabCache.position=NSMakePoint(rabCache.position.x+rabCache.obstacle.velocity.x*deltaTime,rabCache.position.y+rabCache.obstacle.velocity.y*deltaTime);
            NSPoint dp=NSMakePoint(rabCache.position.x-position.x,rabCache.position.y-position.y);
            
            [self setRelativePosition:dp ofObstacle:rabCache.obstacle];
            [nearAgentsStatic addObject:rabCache.obstacle];
        }
    }
}


#endif

-(void)updateSensing
{
    
    
    
    
#ifdef GUI
    if(debug)
    {
        for(Agent *a in [[World world] allAgents]) a.observed=0;
    }
#endif
    
    if(sensor==rab)
    {
        [self buildCacheWithRab];
    }
    else
    {
        
        [self buildCacheWithVision];
    }
    
    
    [self addMarkerObstacles];
    
    
    if(control==RVO_C)
    {
        [self setupRVOAgent];
        [self computeRVOObstacles];
    }
    else if(control==HRVO_C)
    {
        [self computeHRVOObstacles];
    }
    else
    {
        [self initDistanceCache];
        [self computeCache];
    }
    /*
     [nearAgents sortUsingComparator:^NSComparisonResult(ObstacleCache *obj1, ObstacleCache *obj2) {
     return (obj1.minimalDistanceToCollision<obj2.minimalDistanceToCollision) ? NSOrderedAscending : NSOrderedDescending;
     }];
     */
}

-(void) senseObstacleWithRab:(ObstacleCache *)obstacle
{
    NSPoint p;
    double distance,gamma;
    
    distance=obstacle.centerDistance;
    gamma=obstacle.angle;
    
    if(rangeErrorStd || bearingErrorStd)
    {
        distance+=(*errorDistribution)()*rangeErrorStd;
        gamma+=(*errorDistribution)()*bearingErrorStd;
    }
    
    p=NSMakePoint(distance*cosf(gamma),distance*sinf(gamma));
    
    [self setRelativePosition:p ofObstacle:obstacle];
    
}


-(double) senseTargetAngleWithVision:(double)t
{
    return t;
}

-(NSPoint) senseTargetWithVision:(NSPoint)t
{
    /*
     NSPoint p=t;
     #ifdef SENSING_ERROR
     if(positionSensingErrorStd)
     {
     p.x+=(*errorDistribution)()*positionSensingErrorStd;
     p.y+=(*errorDistribution)()*positionSensingErrorStd;
     }
     #endif
     */
    return t;
    
}

-(void) senseObstacleWithVision:(ObstacleCache *)obstacle
{
    NSPoint p,v;
    
    v=obstacle.agent.velocity;
    p=obstacle.relativePosition;
    
    
#ifdef SENSING_ERROR
    
    if(speedSensingErrorStd)
    {
        v.x+=(*errorDistribution)()*speedSensingErrorStd;
        v.y+=(*errorDistribution)()*speedSensingErrorStd;
    }
    if(positionSensingErrorStd)
    {
        p.x+=(*errorDistribution)()*positionSensingErrorStd;
        p.y+=(*errorDistribution)()*positionSensingErrorStd;
    }
#endif
    
    obstacle.velocity=v;
    [self setRelativePosition:p ofObstacle:obstacle];
    
    
    
}


#pragma mark - control
@synthesize on,control;

#ifdef USE_BULLET_FOR_SENSING
@synthesize horizonObject;
#endif

#ifdef SOCIAL_FORCE
@synthesize socialAcceleration;
#endif

@synthesize resolution,effectiveTarget,desideredVelocity,effectiveHorizon,desideredAngle,minDistanceToTarget,optimalSpeed,aperture,tau,controlUpdatePeriod,horizon,socialMargin,safetyMargin,eta,useEffectiveHorizon;

-(double)angleResolution
{
    return 2*aperture/resolution;
}
-(void)initControl
{
#ifdef RAB
    rabCacheCollection=[[NSMutableDictionary dictionary] retain];
#endif
    
#ifdef PREDICT_CHANGE
    int k=0;
    for (; k<NUMBER_OF_CHANGE_SAMPLES; k++){
        velocityChangeSamples[k]=0.0;
    }
    velocityChangeIndex=0;
    velocityChangeMaxIndex=0;
#endif
    steps=0;
    nearAgents=[[NSMutableArray array] retain];
    nearAgentsStatic=[[NSMutableArray array] retain];
    desideredVelocity=NSMakePoint(0, 0);
    desideredAngle=0;
    
    shouldEscapeDeadlocks=YES;
    shouldDetectDeadlocks=YES;
    
    
    timeHorizonStatic=1;
    timeHorizon=10;
    
    
    
}

-(void)startControl
{
    [self initModulation];
    [self initEmotion];
}

-(void)initDistanceCache
{
    int k=0;
    for(;k<resolution;k++) distanceCache[k]=UNKNOWN;
}

-(double)distToCircularWall:(CircularWall *)wall atAngle:(double)a
{
	NSPoint dp=NSMakePoint(position.x-wall.x, position.y-wall.y);
    double d=sqrt(dp.x*dp.x+dp.y*dp.y);
    double distance;
    BOOL inside=NO;
    
    if(d>wall.radius)
    {
        distance=d-wall.radius-radius-W_THICKNESS*0.5;
    }
    else
    {
        inside=YES;
        distance=wall.radius-d-radius-W_THICKNESS*0.5;
    }
    
    double B=dp.x*cosf(a)+dp.y*sinf(a);
    
    if(distance<0)
    {
        if(inside)
        {
            if(B<-0.05) return NO_COLLISION;
            return 0;
        }
        else
        {
            if(B>0.05)
            {
                double C=d*d-(radius+W_THICKNESS/2+wall.radius)*(radius+W_THICKNESS/2+wall.radius);
                return -B+sqrt(B*B-C);
            }
            
            
            //return NO_COLLISION;
            return 0;
        }
    }
    double C;
    if(inside)
    {
        C=d*d-(radius+W_THICKNESS/2-wall.radius)*(radius+W_THICKNESS/2-wall.radius);
    }
    else
    {
        C=d*d-(radius+W_THICKNESS/2+wall.radius)*(radius+W_THICKNESS/2+wall.radius);
    }
    
    double D=B*B-C;
    
    if(inside)
    {
        return -B+sqrt(B*B-C);
    }
    else
    {
        if(B>0) return NO_COLLISION;
        if(D<0) return NO_COLLISION;
        return -B-sqrt(D);
    }
}



-(double)distToWall:(Wall *)wall atAngle:(double)a
{
    NSPoint delta=NSMakePoint(position.x-wall.x, position.y-wall.y);
    NSPoint	v=NSMakePoint(optimalSpeed*cos(a), optimalSpeed*sinf(a));
    
    double wa=PI/180*wall.angle;
    
    double d1=delta.x*sinf(wa)-delta.y*cosf(wa);
    double d2=delta.x*cosf(wa)+delta.y*sinf(wa);
    double L=0.5*W_THICKNESS+radius+safetyMargin; //ADDED safety margin
    
    if((fabs(d1)<L) && (fabs(d2)<(wall.length+radius+safetyMargin)))
    {
        //Se si allontana da muro niente collisioni se lo sta già toccando
        
#ifdef NEAR_VISION
        if((d1>=0 &&  signedNormalize(wa-a)>0) || (d1<0 && signedNormalize(wa-a)<0)) return NO_COLLISION;
#endif
        
        return 0;
    }
    
    
    
    double vd1=v.x*sinf(wa)-v.y*cosf(wa);
    double vd2=v.x*cosf(wa)+v.y*sinf(wa);
    
    
    double C=d1*d1-L*L;
    double B=2*d1*vd1;
    double A=vd1*vd1;
    double D;
    double r10,r11,r20,r21;
    
    if(A==0)
    {
        if(C>0) return NO_COLLISION;
        r10=-horizon/optimalSpeed;
        r11=horizon/optimalSpeed;
    }
    else {
        D=B*B-4*A*C;
        
        if(D<0) return NO_COLLISION;
        
        r10=(-B-sqrt(D))/(2*A);
        r11=(-B+sqrt(D))/(2*A);
        
        if(r11<0) return NO_COLLISION;
    }
    
    L=wall.length+radius;
    
    C=d2*d2-L*L;
    B=2*d2*vd2;
    A=vd2*vd2;
    
    if(A==0)
    {
        if(C>0) return NO_COLLISION;
        
        r20=-horizon/optimalSpeed;
        r21=horizon/optimalSpeed;
    }
    else {
        D=B*B-4*A*C;
        
        if(D<0) return NO_COLLISION;
        
        r20=(-B-sqrt(D))/(2*A);
        r21=(-B+sqrt(D))/(2*A);
        
        if(r21<0) return NO_COLLISION;
    }
    
    if(r20<0 && r10<0) return 0;
    
    double r=MAX(r20,r10);
    if(r<MIN(r21,r11)) return r*optimalSpeed;
    
    return NO_COLLISION;
}


#define SpeedChange 1
-(double)distToAgent:(Agent *)agent atAngle:(double)alpha withOptimalSpeed:(bool)flag
{
    //Using cache
    
    
    NSPoint dx=NSMakePoint(position.x-agent.position.x, position.y-agent.position.y);
    
    
    double ds=dx.x*dx.x+dx.y*dx.y;
    
    if(ds>self.effectiveHorizon*self.effectiveHorizon) return self.effectiveHorizon;
    
    
    double rE=(radius+0.002);
    double C=(dx.x*dx.x+dx.y*dx.y)-4*rE*rE;
    
    
    
    
    //if(C<0) return 0;
    
    if(flag) speed=self.optimalSpeed;
    
    NSPoint	v=NSMakePoint(speed*cos(alpha), speed*sin(alpha));
    
    
    NSPoint va;
    
    va=NSMakePoint(agent.speed*cos(agent.angle), agent.speed*sin(agent.angle));
    
    NSPoint dv=NSMakePoint(v.x-va.x, v.y-va.y);
    
#ifdef SpeedChange
    //dv.x-=fabs(agent.speed)*SpeedChange*dx.x/n;
    //dv.y-=fabs(agent.speed)*SpeedChange*dx.y/n;
    //dv.y+=-0.1*opt_speed*dx.y/n;
    //dv.x+=-0.1*opt_speed*dx.y/n;
#endif
    //change
    
    
    double B=2*(dx.x*dv.x+dx.y*dv.y);
    
    //we are only interessted in t>0 and a solution exists only if B < 0, i.e. dx*dv<0;
    //NSLog(@"Agent %@ B %.4f C %.4f",agent,B,C);
    if(B>0) return self.effectiveHorizon;
    
    double A=dv.x*dv.x+dv.y*dv.y;
    double D=B*B-4*A*C;
    
    //NSLog(@"Agent %@ A %.4f B %.4f C %.4f D %.4f",agent,A,B,C,D);
    if(D<0) return self.effectiveHorizon;
    
    // A>0, C>0 => sqrt(D)<|B| => (-B-sqrt(D))/2*A >0
    //We are interesste in the first intersection point (when d'<0)
    
    
    
    
    return speed*(-B-sqrt(B*B-4*A*C))/(2*A);
    
    
    
    //change
    //if(r>0) return r*speed;
    
    //r=(-B+sqrt(D))/(2*A);
    
    //if(r>0) return r*speed;
    
    //return self.effectiveHorizon;
}

double signedNormalize (double a)
{
    a=fmod(a,TWO_PI);
    if(a>PI) a-=TWO_PI;
    if(a<-PI) a+=TWO_PI;
    return a;
}

-(int) indexOfRelativeAngle:(double)relativeAngle
{
    int k=floor((relativeAngle+aperture)/(2*aperture)*resolution);
    
    k=k%resolution;
    if(k<0) k+=resolution;
    return k;
}


-(void) computeDistanceAtRelativeAgle:(double)relativeAngle
{
    if(fabs(signedNormalize(relativeAngle))>=aperture) return;
    int k=[self indexOfRelativeAngle:relativeAngle];
    if(distanceCache[k]==0 || staticDistanceCache[k]==0)
    {
        staticDistanceCache[k]=0;
    }
    else
    {
        staticDistanceCache[k]=[self staticDistanceAtRelativeAngle:relativeAngle minDistance:staticDistanceCache[k]];
    }
}

-(double) fearedDistanceToCollisionAtRelativeAngle:(double)relativeAngle minDistance:(double)minDistance
{
    if(fabs(signedNormalize(relativeAngle))>=aperture) return UNKNOWN;
    int k=[self indexOfRelativeAngle:relativeAngle];
    
    return [self staticDistanceAtRelativeAngle:relativeAngle minDistance:fmin(staticDistanceCache[k],minDistance)];
}

-(double) staticDistanceAtRelativeAngle:(double)relativeAngle minDistance:(double) minDistance
{
    double vangle=relativeAngle+angle;
    double distance;
    
    for(ObstacleCache *obstacle in nearAgentsStatic)
    {
        if(minDistance<obstacle.minimalDistance) continue;
        
        distance=[obstacle distanceToCollisionInDirection:vangle];
        if(distance==0) return 0;
        
        if(!(distance==NO_COLLISION)) minDistance=fmin(minDistance,distance);
    }
    
    return minDistance;
}



-(double) distanceToCollisionWithGlobalSensorAtRelativeAngle:(double)relativeAngle staticCache:(double*)staticCache
{
    double vangle=relativeAngle+angle;
    
    //Change!! horizon->effectiveHorizon
    double minDistance=effectiveHorizon-radius;
    //double minDistance=horizon-radius;
    double distance;
    //*staticCache=0;
    for(Wall *w in [[World world] walls])
    {
        distance=[self distToWall:w atAngle:vangle];
        if(distance==NO_COLLISION) continue;
        if(distance==0) return 0;
        
        minDistance=fmin(minDistance,distance);
        //#ifdef CAREFULL
        //        if(minDistance<optimalSpeed*controlUpdatePeriod) return 0;
        //#else
        //        if(minDistance==0) return 0;
        //#endif
    }
    
    for(CircularWall *w in [[World world] circularWalls])
    {
        distance=[self distToCircularWall:w atAngle:vangle];
        if(distance==NO_COLLISION) continue;
        if(distance==0) return 0;
        
        minDistance=fmin(minDistance,distance);
    }
    
    // NSMutableArray *array=[_nearAgentCalculation copy];
    
    *staticCache=minDistance;
    
    //double staticDistance;
    
    for(ObstacleCache *obstacle in nearAgents)
    {
        //staticDistance=[obstacle distanceToCollisionInDirection:vangle];
        //if(staticDistance==0) return 0;
        
        //if(!(staticDistance==NO_COLLISION)) *staticCache=fmin(*staticCache,staticDistance);
        
        if(minDistance<obstacle.minimalDistanceToCollision) continue;
        
        distance=[obstacle distanceToCollisionWhenMovingInDirection:vangle];
        
        /*
         if(debug && obstacle.agent.speed>0.3)
         {
         NSLog(@"distance to collision in dir %.3f is %.3f (%.3f)",relativeAngle,distance,obstacle.agent.speed);
         }
         */
        
        
        if(distance==NO_COLLISION) continue;
        if(distance==0) return 0;
        
        minDistance=fmin(minDistance,distance);
        
        //#ifdef CAREFULL
        //if(minDistance<optimalSpeed*controlUpdatePeriod) return 0;
        //#else
    }
    
    return minDistance;
}

-(double) distanceToCollisionWithCacheAtRelativeAngle:(double)relativeAngle
{
    if(fabs(signedNormalize(relativeAngle))>=aperture) return UNKNOWN;
    int k=[self indexOfRelativeAngle:relativeAngle];
    if(distanceCache[k]<0)
    {
        distanceCache[k]=[self distanceToCollisionWithGlobalSensorAtRelativeAngle:relativeAngle staticCache:staticDistanceCache+k];
    }
    return distanceCache[k];
}

#ifdef CAREFULL
-(BOOL) testIfCollisionFree
{
    double distance;
    for(Wall *w in [[World world] walls])
    {
        distance=[self distToWall:w atAngle:desideredAngle];
        if(distance<0) continue;
        if(distance<speed*controlUpdatePeriod)
        {
            if(debug) printf("Will collide with wall %p at distance %.4f\r\n",w,distance);
            return NO;
        }
    }
    for(agentCache *c in nearAgents)
    {
        c.speed=speed;
        distance=[c distForAngle:desideredAngle];
        if(distance<0) continue;
        if(distance<speed*controlUpdatePeriod)
        {
            
            if(debug)
            {
                c.speed=optimalSpeed;
                double rd=[c distForAngle:desideredAngle];
                printf("Will collide with agent %p at distance %.4f vs %.4f\r\n",c,distance,rd);
            }
            return NO;
        }
    }
    return YES;
}

#endif


+(NSMutableDictionary*)emotionMessages
{
    static NSMutableDictionary *emotionMessages;
    if(!emotionMessages)
    {
        emotionMessages=[[NSMutableDictionary dictionary] retain];
    }
    return emotionMessages;
}

-(void) publishEmotionMessage
{
    if(!shouldShowEmotion) return;
    
    
    NSMutableDictionary *message=[NSMutableDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithDouble:currentEmotion],@"emotion",nil];
    
    if(currentEmotion==neutral)
    {
        
        
        double minDist=5;
        ObstacleCache *o=nil;
        Agent *a;
        NSString *rabIDTHelp;
        // NSLog(@"can help?");
        for(ObstacleCache * to in nearAgentsStatic)
        {
            BOOL isShadow=[to.agent isMemberOfClass:[ShadowAgent class]];
            if(isShadow) a=[to.agent agent];
            else a=to.agent;
            NSDictionary *m=[self emotionMessageForAgent:a];
            if(m && [[m valueForKey:@"emotion"] intValue]==confusion)
            {
                NSNumber *n;
                if(currentPathMarker && (n=[m valueForKey:@"needHelpToGoToMarkerWithIndex"]))
                {
                    if([n intValue]!=currentPathMarker.index) continue;
                }
                
                //NSLog(@"%.3f %.3f ?",minDist,to.centerDistance);
                if(minDist>to.centerDistance)
                {
                    minDist=to.centerDistance;
                    o=to;
                    rabIDTHelp=a.rabID;
                }
            }
        }
        
        
        
        if(o)
        {
            //NSLog(@"->%.3f %.3f",minDist,o.centerDistance);
            double alpha=atan2(o.velocity.y, o.velocity.x);
            //double rA=o.angle-alpha;
            
            NSPoint rP=NSMakePoint(position.x-o.position.x,position.y-o.position.y);
            // NSPoint rP=NSMakePoint(o.centerDistance*cos(rA),o.centerDistance*sin(rA));
            rP=NSMakePoint(rP.x*cos(-alpha)+rP.y*sin(-alpha), rP.x*sin(alpha)+rP.y*cos(-alpha));
            
            NSPoint rT=NSMakePoint(target.x-o.position.x,target.y-o.position.y);
            
            //NSLog(@"S1 (%.2f,%.2f)",rT.x,rT.y);
            
            rT=NSMakePoint(rT.x*cos(-alpha)+rT.y*sin(-alpha), rT.x*sin(alpha)+rT.y*cos(-alpha));
            
            
            //NSLog(@"S2 %.2f (%.2f,%.2f)",alpha,rT.x,rT.y);
            
            NSDictionary *helpMessage=[NSDictionary dictionaryWithObjectsAndKeys:rabIDTHelp,@"to",[NSValue valueWithPoint:rP],@"relativePosition",[NSValue valueWithPoint:rT],@"relativeTarget", nil];
            
            [message setValue:helpMessage forKey:@"help"];
            
            //NSLog(@"S3 (%.2f,%.2f)",target.x,target.y);
            
        }
        else{
            // NSLog(@"no");
        }
    }
    if(currentEmotion==confusion && currentPathMarker)
    {
        [message setValue:[NSNumber numberWithInt:currentPathMarker.index] forKey:@"needHelpToGoToMarkerWithIndex"];
    }
    
    [[Agent emotionMessages] setValue:message forKey:rabID];
}


-(BOOL)modulationIsActiveFoEmotion:(emotionType)emotion
{
    return (emotionModulationIsActive & (1<<emotion));
}



-(void)initEmotion
{
    //emotionModulationIsActive=0xFF;
    
    
    
    currentEmotion=neutral;
    confusionThreshold=0.0;
    
    emotionActivation[confusion]=0.00;
    
    emotionHighThrehold[confusion]=0.3;//0.5;
    emotionLowThrehold[confusion]=0.1;
    
    emotionHighThrehold[fear]=0.5;
    emotionLowThrehold[fear]=0.2;
    
    emotionHighThrehold[frustration]=0.3;
    emotionLowThrehold[frustration]=0.1;
    
    
    Experiment *ex=[[World world] experiment];
    
    if([ex isMemberOfClass:[EmotionUrgencyExperiment class]])
    {
        emotionHighThrehold[urgency]=0.2;
        emotionLowThrehold[urgency]=0.0;
    }
    else if([ex isMemberOfClass:[EmotionUrgency2Experiment class]])
    {
        emotionActivation[urgency]=0.4;
        emotionHighThrehold[urgency]=0.6;
        emotionLowThrehold[urgency]=0.2;
    }
    
    
}

-(void)updateOcclusionFear
{
    
    double da=[self angleResolution];
    double r=-aperture;
    
    double maxFreeDistanceToCollision=0;
    
    
    while(r<aperture)
    {
        double d=[self distanceToCollisionWithCacheAtRelativeAngle:r];
        r+=da;
        if(d!=NO_COLLISION)
        {
            maxFreeDistanceToCollision=fmax(d, maxFreeDistanceToCollision);
        }
        else
        {
            maxFreeDistanceToCollision=horizon;
            break;
        }
    }
    
    uint numberOfFrustratedNeightbors=0;
    
    for(ObstacleCache * o in nearAgentsStatic)
    {
        NSDictionary *m=[self emotionMessageForAgent:o.agent];
        if(m && [[m valueForKey:@"emotion"] intValue]==frustration)
        {
            numberOfFrustratedNeightbors++;
            
        }
    }
    
    double ratioOfFrustratedNeightbors=0;
    if([nearAgentsStatic count])
    {
        ratioOfFrustratedNeightbors=numberOfFrustratedNeightbors/(double)[nearAgentsStatic count];
    }
    
    emotionActivation[fear]*=0.95;
    //emotionActivation[fear]+=0.05*(1-fmin(1,maxFreeDistanceToCollision/horizon));
    //emotionActivation[fear]+=0.05*fmax(ratioOfFrustratedNeightbors,fmin(1,1-maxFreeDistanceToCollision/horizon));
    
    emotionActivation[fear]+=0.05*fmax(fmin(1,3*ratioOfFrustratedNeightbors),fmax(0,1-16*maxFreeDistanceToCollision/horizon));

   
    
}

-(void)updateFrustation
{
    emotionActivation[frustration]*=0.97;
    if(state==freeState)
    {
        emotionActivation[frustration]+=0.03*fmax(0,fmin(1,(1-efficacity)));
    }
    else
    {
        emotionActivation[frustration]+=0.03
        *(1-speed/optimalSpeed);
    }
}

-(void)updateUrgency
{
    if(personality == resolute)
    {
        if(emotionActivation[frustration]>0.1)
        {
            emotionActivation[urgency]=(emotionActivation[frustration]-0.1)/0.9;
        }
        else{
            emotionActivation[urgency]=0;
        }
    }
    else
    {
        if(emotionActivation[frustration]>0.8)
        {
            emotionActivation[urgency]=(emotionActivation[frustration]-0.8)/0.2;
        }
        else{
            emotionActivation[urgency]=0;
        }
    }
}

@synthesize targetSensingQuality;

-(void)updateUrgency2
{
    if(numberOfReachedTargets==0) return;
    double minimalRestTimeToTarget=(targetDistance-pathMargin)/optimalSpeed;
    double duration=_time-lastTimeAtTarget;
    double maxTime;
    if(personality==resolute)
    {
        maxTime=minimalTimeToTarget*1.01;
    }
    else
    {
        maxTime=minimalTimeToTarget*5;
    }
    
    double cT=duration+minimalRestTimeToTarget;
    
    
    double nu;
    
    if(cT>maxTime)   nu=1;
    else if(cT<minimalTimeToTarget)  nu=0;
    else  nu=(cT-minimalTimeToTarget)/(maxTime-minimalTimeToTarget);
    
    
    emotionActivation[urgency]=emotionActivation[urgency]*0.95+0.05*nu;
    
    //if(personality==resolute) printf("%.2f in [%.2f,%.2f] -> %.2f\n",cT,minimalTimeToTarget,maxTime,emotionActivation[urgency]);
    
}


-(void)updateConfusion
{
    double duration=_time-lastTimeAtTarget;
    if(numberOfReachedTargets)
    {
        emotionActivation[confusion]=duration/(5*minimalTimeToTarget);
    }
    else
    {
        emotionActivation[confusion]=duration/50;
    }
}

-(void)updateConfusion1
{
    emotionActivation[confusion]*=0.99;
    //printf("%.2f,",rotation);
    emotionActivation[confusion]+=0.01*fmax(0,fmin(rotation/0.8,1));
}


-(void)updateEmotion{
    //Here is experiment specific
    
    
    Experiment *ex=[[World world] experiment];
    
    if([ex isMemberOfClass:[EmotionPanicExperiment class]])
    {
        [self updateFrustation];
        [self updateOcclusionFear];
    }
    else if([ex isMemberOfClass:[EmotionUrgencyExperiment class]])
    {
        [self updateFrustation];
        [self updateUrgency];
    }
    else if([ex isMemberOfClass:[EmotionUrgency2Experiment class]])
    {
        [self updateUrgency2];
    }
    else if ([ex isMemberOfClass:[EmotionConfusionExperiment class]])
    {
        [self updateConfusion1];
    }
    else
    {
        return;
    }
    
    
    //Here is general
    
    
    if(currentEmotion!=neutral)
    {
        
        if(emotionActivation[currentEmotion]<emotionLowThrehold[currentEmotion])
        {
            currentEmotion=neutral;
        }
    }
    
    emotionType e=(emotionType)0;
    double maxActivation=0.0;
    for(;e<NUMBER_OF_EMOTIONS;e++)
    {
        if(e==neutral) continue;
        if(emotionActivation[e]>emotionHighThrehold[e] && emotionActivation[e]>maxActivation)
        {
            maxActivation=emotionActivation[e];
            currentEmotion=e;
        }
    }
    
#ifdef DEBUG
    if(debug) NSLog(@"Fear %.2f, Confusion %.2f, Frustation %.2f, Urgency %.2f",emotionActivation[fear],emotionActivation[confusion],emotionActivation[frustration],emotionActivation[urgency]);
#endif
}

-(void) updateEmotion1
{
    
    
    
    
    /*
     emotionActivation[frustration]*=0.99;
     if(state==freeState)
     {
     emotionActivation[frustration]+=0.01*(1-efficacity);
     }
     else
     {
     emotionActivation[frustration]+=0.01*(1-speed/optimalSpeed);
     }
     */
    currentEmotion=neutral;
    
    /*
     if(emotionActivation[frustration]>0.01)
     {
     currentEmotion=frustration;
     }
     
     if(personality == resolute)
     {
     if(emotionActivation[frustration]>0.1)
     {
     emotionActivation[urgency]=(emotionActivation[frustration]-0.1)/0.9;
     currentEmotion=urgency;
     }
     }
     else
     {
     if(emotionActivation[frustration]>0.8)
     {
     emotionActivation[urgency]=(emotionActivation[frustration]-0.8)/0.2;
     currentEmotion=urgency;
     }
     }
     */
    
    //NSLog(@"%d %d %.2f",personality,currentEmotion,emotionActivation[frustration]);
    
    
    
    //Fear to go into a deadlock
    
    
    
    if(emotionActivation[frustration]>0.1)
    {
        currentEmotion=frustration;
    }
    
    double da=[self angleResolution];
    double r=-aperture;
    
    double maxFreeDistanceToCollision=0;
    
    
    
    while(r<aperture)
    {
        double d=[self distanceToCollisionWithCacheAtRelativeAngle:r];
        r+=da;
        if(d!=NO_COLLISION)
        {
            maxFreeDistanceToCollision=fmax(d, maxFreeDistanceToCollision);
        }
        else
        {
            maxFreeDistanceToCollision=horizon;
            break;
        }
    }
    
    emotionActivation[fear]*=0.95;
    //emotionActivation[fear]+=0.01*(1-fmin(1,maxFreeDistanceToCollision/10*safetyMargin));
    
    uint numberOfFrustratedNeightbors=0;
    
    for(ObstacleCache * o in nearAgentsStatic)
    {
        NSDictionary *m=[self emotionMessageForAgent:o.agent];
        if(m && [[m valueForKey:@"emotion"] intValue]==frustration)
        {
            numberOfFrustratedNeightbors++;
        }
    }
    
    double ratioOfFrustratedNeightbors=0;
    if([nearAgentsStatic count])
    {
        ratioOfFrustratedNeightbors=numberOfFrustratedNeightbors/(double)[nearAgentsStatic count];
    }
    
    
    emotionActivation[fear]+=0;//0.05*fmax(ratioOfFrustratedNeightbors,fmin(1,1-maxFreeDistanceToCollision/horizon));
    
    
    
    if(emotionActivation[fear]>0.8)
    {
        currentEmotion=fear;
    }
    
    
    
    
    
    emotionActivation[confusion]*=0.98;
    emotionActivation[confusion]+=0.02*fmin(1,fmax(0,rotation/0.2));
    
    if(emotionActivation[confusion]>confusionThreshold)
    {
        currentEmotion=confusion;
        confusionThreshold=0.1;
    }
    else
    {
        confusionThreshold=0.5;
    }
    
    
 #ifdef DEBUG   
    if(debug) NSLog(@"E %.3f %.3f -> %.3f \n F %.3f ->%.3f \n C %.3f -> %.3f\n => %d",ratioOfFrustratedNeightbors,fmin(1,1-maxFreeDistanceToCollision/horizon), emotionActivation[fear],(1-efficacity),emotionActivation[frustration],rotation/0.2,emotionActivation[confusion],currentEmotion);
#endif
}

-(void) initModulation
{
    baseEta=eta;
    baseAperture=aperture;
    baseSafetyMargin=safetyMargin;
    baseOptimalSpeed=optimalSpeed;
    baseVisibilityFOV=visibilityFOV;
    baseVisibilityRange=visibilityRange;
}


@synthesize escapeThreshold;
-(void)updateEmotionalModulation
{
    eta=baseEta;
    aperture=baseAperture;
    safetyMargin=baseSafetyMargin;
    optimalSpeed=baseOptimalSpeed;
    
    visibilityFOV=baseVisibilityFOV;
    visibilityRange=baseVisibilityRange;
    
    //if(currentEmotion==urgency)
    if([self modulationIsActiveFoEmotion:urgency]  && emotionActivation[urgency]>0)
    {
        eta=fmin(baseEta,fmax(0.1,baseEta*(1-4*emotionActivation[urgency])));
        //safetyMargin=fmin(baseSafetyMargin,fmax(0.0,baseSafetyMargin*(1-4*emotionActivation[urgency])));
        //aperture=fmin(baseAperture,fmax(0.1,baseAperture*(1-emotionActivation[urgency])));
        
        //NSLog(@"%.2f %.2f %.2f",eta,safetyMargin,emotionActivation[urgency]);
        
        //ev. modulare anche la fov (che si riduce) o l'apertura (che però con gli agenti omni non funziona bene)
        
        
        Experiment *ex=[[World world] experiment];
        
        if([ex isMemberOfClass:[EmotionUrgency2Experiment class]])
        {
            //printf("%d - ",emotionModulationIsActive);
            //optimalSpeed=baseOptimalSpeed*(1+emotionActivation[urgency]);
        }
        
        
        visibilityFOV=fmin(baseVisibilityFOV,baseVisibilityFOV+(1-baseVisibilityFOV)*fmin(1,fmax(0,emotionActivation[urgency])));
        
        //visibilityFOV=fmin(baseVisibilityFOV,fmax(1,baseVisibilityFOV*(1-2*emotionActivation[urgency])));
        //visibilityRange=fmin(baseVisibilityRange,fmax(1,baseVisibilityRange*(1-emotionActivation[urgency])));
        // optimalSpeed=baseOptimalSpeed*(1+emotionActivation[urgency]);
        
    }
    if([self modulationIsActiveFoEmotion:fear]  && emotionActivation[fear]>0 )
        //else if(1 && currentEmotion==fear)
    {
        //safetyMargin=fmin(baseSafetyMargin,fmax(0.0,baseSafetyMargin*(1+emotionActivation[fear])));
        optimalSpeed=fmin(baseOptimalSpeed,baseOptimalSpeed*0.2+fmax(baseOptimalSpeed*0.8,baseOptimalSpeed*0.8*(1-emotionActivation[fear])));
        
         visibilityFOV=fmax(baseVisibilityFOV,baseVisibilityFOV+(PI-baseVisibilityFOV)*fmin(1,fmax(0,emotionActivation[fear])));
        aperture=0.5*visibilityFOV;
        
       // printf("%.2f %.2f %.2f \n",emotionActivation[fear],optimalSpeed,visibilityFOV);
        
    }

    if([self modulationIsActiveFoEmotion:confusion]  && emotionActivation[confusion]>0)
        //else if(currentEmotion==confusion)
    {
        //safetyMargin=fmin(baseSafetyMargin,fmax(0.0,baseSafetyMargin*(1+emotionActivation[fear])));
        //optimalSpeed=fmin(baseOptimalSpeed,fmax(0.05,baseOptimalSpeed*(1-emotionActivation[confusion])));
        
        
        optimalSpeed=fmin(baseOptimalSpeed,baseOptimalSpeed*fmax(0.1,1-(0.3-emotionActivation[confusion])/(0.3-1)));
        
    }
    if([self modulationIsActiveFoEmotion:frustration] && shouldEscapeDeadlocks)
    {
        if(state==freeState && emotionActivation[frustration]>escapeThreshold)
        {
            state=escapingDeadlock;
        }
        if(state==escapingDeadlock && emotionActivation[frustration]<escapeThreshold*0.5)
        {
            state=freeState;
        }
    }
    
}



#ifdef RAB


double rabReliability=0.8;

NSUInteger rabMessageNumber=4;




+(NSMutableDictionary*)rabMessages
{
    static NSMutableDictionary *rabMessages;
    if(!rabMessages)
    {
        rabMessages=[[NSMutableDictionary dictionary] retain];
    }
    return rabMessages;
}


NSComparisonResult rabMessageSorter(id obj1,id obj2,void* context)
{
    return ([obj1 obstacle].centerDistance<[obj2 obstacle].centerDistance) ? NSOrderedAscending : NSOrderedDescending;
}

-(void)sendRabMessage
{
    double mspeed=speed;
    double mheading=angle;
    
    NSMutableArray *targets=[NSMutableArray array];
    
    NSUInteger n=0;
    
    
#ifdef GNUSTEP
    NSArray *rabDevices=[[rabCacheCollection allValues] sortedArrayUsingFunction:rabMessageSorter context:nil];
#else
    NSArray *rabDevices=[[rabCacheCollection allValues] sortedArrayUsingComparator:^NSComparisonResult(RabCache *obj1, RabCache *obj2) {
        return (obj1.obstacle.centerDistance<obj2.obstacle.centerDistance) ? NSOrderedAscending : NSOrderedDescending;
    } ];
#endif
    
    
    
    for(RabCache *rab in rabDevices)
    {
        n++;
        if(n>rabMessageNumber) break;
        [targets addObject:rab.obstacle.agent.rabID];
    }
    
    NSDictionary *message=[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithDouble:mspeed],@"speed",[NSNumber numberWithDouble:mheading],@"heading", targets,@"targets",nil];
    
    //NSLog(@"%@",message);
    
#ifdef USE_DISPATCH
    dispatch_async([Agent rabQueue], ^(){
        [[Agent rabMessages] setValue:message forKey:rabID];
    });
#else
    [[Agent rabMessages] setValue:message forKey:rabID];
#endif
}

#endif

#ifdef SOCIAL_FORCE


//Should only loop over near agents => substitute with agentCache and nearAgents!!!


-(void)updateSocialAcceleration
{
    NSPoint acc=NSMakePoint(0, 0);
    
    for(ObstacleCache *a in nearAgents)
    {
        if(a.penetration>0)
        {
            acc.x-=a.penetration*a.relativePosition.x/a.centerDistance;
            acc.y-=a.penetration*a.relativePosition.y/a.centerDistance;
        }
    }
    
    acc.x*=socialRepulsion*controlUpdatePeriod;
    acc.y*=socialRepulsion*controlUpdatePeriod;
    
    socialAcceleration=acc;
    
}


#endif


-(void)updateDesideredVelocity
{
    //Search begin from the direction to the target
    
    if(control==RVO_C)
    {
        [self updateDesideredVelocityWithRVO];
        return;
    }
    if(control==HRVO_C)
    {
        [self updateDesideredVelocityWithHRVO];
        return;
    }
    
    
    if(interaction==SPEED_AND_HEADING)
    {
        [self setTargetSpeed:optimalSpeed andTargetAngle:targetAngle];
        return;
    }
    else if (interaction==HEADING)
    {
        if(humanStopped)
        {
            [self setTargetSpeed:0 andTargetAngle:targetAngle];
            return;
        }
        
        
        //[self initDistanceCache];
        [self distanceToCollisionWithCacheAtRelativeAngle:targetAngle];
        [self computeDistanceAtRelativeAgle:targetAngle];
        
        double nearestCollision=[self fearedDistanceToCollisionAtRelativeAngle:targetAngle minDistance:optimalSpeed*eta];
        
        double newTargetSpeed;
        
        
        
        if(nearestCollision>0)
        {
            newTargetSpeed=fmin(optimalSpeed,nearestCollision/eta);
        }
        else
        {
            newTargetSpeed=0;
        }
        
        NSLog(@"%.2f -> %.2f",nearestCollision,newTargetSpeed);
        
        [self setTargetSpeed:newTargetSpeed andTargetAngle:targetAngle];
        return;
    }
    
    BOOL foundDirection=NO;
    double a0=targetAngle;
    double da=[self angleResolution];
    double D=effectiveHorizon;
    
    //[self initDistanceCache];
    
#ifdef USE_CURRENT_HEADING_FOR_DESIDERED_SPEED
    [self distanceToCollisionWithCacheAtRelativeAngle:0];
    [self computeDistanceAtRelativeAgle:0];
#endif
    
#ifdef  GUI
    if(debug)
    {
        double r=-aperture;
        while(r<aperture)
        {
            [self distanceToCollisionWithCacheAtRelativeAngle:r];
            [self computeDistanceAtRelativeAgle:r];
            r+=da;
        }
    }
#endif
    
    //relativeAngle is relative to agentToTarget
    
    double searchAngle=0;
    double minPossibleDistanceToTarget;
    minDistanceToTarget=D;//-0.001;
    double d;
    double distanceToTarget;
    double nearestAngle=a0;
    double nearestCollision=0;
    
    int leftOut=0;
    int rightOut=0;
    
    float sn,cs;
    
    
    
    while(searchAngle<HALF_PI && !(leftOut==2 && rightOut==2))
    {
        
        //new in paper
        
        
        //minPossibleDistanceToTarget=sqrt(D*D+effectiveHorizon*effectiveHorizon-2*effectiveHorizon*D*cos(relativeAngle));
        
        
        //modified so to find the true minimum along the trajectory (unlike the paper)
        // minPossibleDistanceToTarget=2*D*sin(0.5*searchAngle);
        
        
        sn=sinf(searchAngle);
        cs=cosf(searchAngle);
        minPossibleDistanceToTarget=fabs(sn*D);
        
        
        //if(debug)printf("\n%.2f (%.2f,%.2f): %.2f <= %.2f \t ",searchAngle,signedNormalize(searchAngle+a0),signedNormalize(searchAngle-a0),minDistanceToTarget,minPossibleDistanceToTarget);
        
        if(minDistanceToTarget<minPossibleDistanceToTarget) break;
        
        
        
        d=[self distanceToCollisionWithCacheAtRelativeAngle:(a0+searchAngle)];
        
        //if(debug)printf("L: %.2f  ",d);
        
        
        
        if(d==UNKNOWN && leftOut==1) leftOut=2;
        if(d!=UNKNOWN && leftOut==0) leftOut=1;
        
        d=fmin(D,d);
        
        if(d!=UNKNOWN)
        {
            
            
            if(cs*D<d)
            {
                distanceToTarget=minPossibleDistanceToTarget;
                //distanceToTarget=fabs(sn*D);
            }
            else
            {
                distanceToTarget=sqrt(D*D+d*d-2*d*D*cs);
            }
            
            //distanceToTarget=sqrt(D*D+d*d-2*d*D*cos(searchAngle));
            
            //if(debug)printf(" => %.2f  ",distanceToTarget);
            
            
            if(distanceToTarget<minDistanceToTarget)
            {
                foundDirection=YES;
                minDistanceToTarget=distanceToTarget;
                nearestAngle=a0+searchAngle;
                //nearestCollision=d;
            }
        }
        
#ifdef ONED
        break;
#endif
        
        if(searchAngle>0)
        {
            d=[self distanceToCollisionWithCacheAtRelativeAngle:(a0-searchAngle)];
            
            
            //if(debug)printf("R: %.2f ",d);
            
            
            if(d==UNKNOWN && rightOut==1) rightOut=2;
            if(d!=UNKNOWN && rightOut==0) rightOut=1;
            
            d=fmin(D,d);
            
            if(d!=UNKNOWN)
            {
                if(cs*D<d)
                {
                    distanceToTarget=minPossibleDistanceToTarget;
                    //distanceToTarget=fabs(sn*D);
                }
                else
                {
                    distanceToTarget=sqrt(D*D+d*d-2*d*D*cs);
                }
                
                //if(debug)printf("=> %.2f",distanceToTarget);
                //distanceToTarget=sqrt(D*D+d*d-2*d*D*cos(searchAngle));
                if(distanceToTarget<minDistanceToTarget)
                {
                    foundDirection=YES;
                    minDistanceToTarget=distanceToTarget;
                    nearestAngle=a0-searchAngle;
                    //nearestCollision=d;
                    
                }
            }
        }
        searchAngle+=da;
    }
    
    
    //NSLog(@"%@ %.10f %.10f",rabID,minDistanceToTarget,D);
    
    //Test if we have found a useful direction
    //if(minDistanceToTarget==D)
    if(!foundDirection)
    {
        
        //NEW SAFETY ACCELERATION TO AVOID DEADLOCKS
        
        
        
        /*
         if(safetyAcceleration.x || safetyAcceleration.y)
         {
         a0=signedNormalize(atan2(-safetyAcceleration.y, -safetyAcceleration.x)-angle);
         // NSLog(@"%@ \t %.2f %.2f %.2f %.2f %.2f %.2f -> %.2f",rabID, position.x,position.y,angle,safetyAcceleration.x, safetyAcceleration.y,atan2(safetyAcceleration.y, safetyAcceleration.x),a0);
         [self setTargetSpeed:-0.3 andTargetAngle:a0];
         
         //safetyPenality=fmin(safetyPenality+fabs(speed)*0.1,0.2);
         }
         else
         {
         // NSLog(@"%@ \t %.2f %.2f %.2f %.2f %.2f",rabID, position.x,position.y,angle,safetyAcceleration.x, safetyAcceleration.y);
         [self setTargetSpeed:0 andTargetAngle:a0];
         }
         
         
         //No usefull direction found
         //So turn towards the target
         
         
         */
        
        [self setTargetSpeed:0 andTargetAngle:a0];
        //NSLog(@"%.0f",100*safetyPenality);
        
        return;
        
        
    }
    
    
    
    
    //leggere paper: Constant-net-time headway as key mechanism behind pedestrian crow dynamics
    //non capisco come combinare le due regole, risp. che distanza usare per calcolare la velocità!!!!
    //nearestCollision=fmin(nearestCollision,[self fearedDistanceToCollisionAtRelativeAngle:nearestAngle]);
    //double pCollision=nearestCollision;
    
#ifdef USE_CURRENT_HEADING_FOR_DESIDERED_SPEED
    nearestCollision=[self fearedDistanceToCollisionAtRelativeAngle:0 minDistance:optimalSpeed*eta];
#else
    nearestCollision=[self fearedDistanceToCollisionAtRelativeAngle:nearestAngle minDistance:optimalSpeed*eta];
#endif
    
    
    double newTargetSpeed;
    if(nearestCollision>0)
    {
        newTargetSpeed=fmin(optimalSpeed,nearestCollision/eta);//exp(1)*fearedDistance/tau-(exp(1)-1)*speed);
#ifdef GUI
        //if(debug) printf("S: %.2f - %.2f => %.2f\n",nearestCollision,eta,newTargetSpeed);
#endif
#ifdef CAREFULL
        if(debug)
        {
            speed=s;
            
            while(![self testIfCollisionFree] && speed>0)
            {
                printf("Collision Expected! Speed %.2f Optimal %.2f Angle %.2f Dynamic D %.2f Static D %.2f E dD %.2f\r\n",speed,optimalSpeed,nearestAngle,pCollision,nearestCollision, controlUpdatePeriod*speed);
                speed=fmax(speed-0.06,0.0);
                printf("speed -> %.2f\r\n",speed);
            }
            
            if(![self testIfCollisionFree])
            {
                printf("No chance!!! Collision Expected! Speed %.2f Optimal %.2f Angle %.2f Dynamic D %.2f Static D %.2f E dD %.2f\r\n",speed,optimalSpeed,nearestAngle,pCollision,nearestCollision, controlUpdatePeriod*speed);
            }
        }
#endif
        
        //deviation=fabs(sin(a0-nearestAngle))*newTargetSpeed;
        //efficacity=(cos(a0-nearestAngle))*newTargetSpeed/optimalSpeed;
    }
    else {
        newTargetSpeed=0;
        //deviation=0;
        //efficacity=0;
    }
    
    
    [self setTargetSpeed:newTargetSpeed andTargetAngle:nearestAngle];
}


-(void)followNearest
{
    // for(NSDictionary)
}

-(void)escapeDeadlockFrustration
{
    double da=[self angleResolution];
    double r=-aperture;
    
    double freeDirection;
    double freePath=0;
    
    while(r<aperture)
    {
        double d=[self distanceToCollisionWithCacheAtRelativeAngle:r];
        r+=da;
        if(d>freePath || (d==freePath && fabs(r)<fabs(freeDirection)))
        {
            freePath=d;
            freeDirection=r;
        }
    }
    
    //NSLog(@"Escape from deadlock frustation %.2f: %.2f %.2f",emotionActivation[frustration],freePath,freeDirection);
    
    if(freePath<0.1)
    {
        [self setTargetSpeed:0 andTargetAngle:aperture];
    }
    else
    {
        [self setTargetSpeed:fmin(optimalSpeed,freePath/eta) andTargetAngle:freeDirection];
    }
}

-(void)escapeDeadlock
{
    [self updateTarget];
    effectiveHorizon=horizon;
    //[self initDistanceCache];
    double da=[self angleResolution];
    double r=-aperture;
    while(r<aperture)
    {
        double d=[self distanceToCollisionWithCacheAtRelativeAngle:r];
        r+=da;
        if(d>0.02*eta)
        {
            if(fabs(signedNormalize(targetAngle-r))<HALF_PI)
            {
                if(isEscaping)
                {
                    state=escapingDeadlock;
                }
                else
                {
                    state=freeState;
                }
                return;
            }
        }
    }
    
    int k=0;
    
    double norm=0.0;
    
    double headingDistribution[resolution];
    
    for(;k<resolution;k++)
    {
        // printf("%.2f,",distanceCache[k]);
        if(distanceCache[k]>1)
        {
            headingDistribution[k]=distanceCache[k]-1;
            norm+=headingDistribution[k];
        }
        else
        {
            headingDistribution[k]=0;
        }
    }
    //printf(", => %.2f\n",norm);
    
    if(norm==0 && aperture<PI)
    {
        [self setTargetSpeed:0 andTargetAngle:aperture];
        return;
    }
    
    double draw=rand()*norm/(double)RAND_MAX;
    
    //printf("DRAW %.2f/%.2f",draw,norm);
    
    for(k=0;k<resolution;k++)
    {
        draw-=headingDistribution[k];
        if(draw<0)
        {
            // printf(" => k=%d\n",k);
            double escapeDistance=1.0*rand()/RAND_MAX+0.5;
            //printf("%.3f\n",escapeDistance);
            double relativeAngle= 2*aperture*k/resolution-aperture;
            target=NSMakePoint(position.x+escapeDistance*cosf(angle+relativeAngle),position.y+escapeDistance*sinf(angle+relativeAngle));
            state=escapingDeadlock;
            isEscaping=YES;
            return;
        }
    }
    
    
    
}


@synthesize shouldDetectDeadlocks,shouldEscapeDeadlocks;

-(void) updateControl
{
    
    
    //NSLog(@"control %d",control);
    
    
    if(state==arrivedState && control!=RVO_C)
    {
        [self setTargetSpeed:0 andTargetAngle:0];
        return;
    }
#ifdef DEADLOCKS
    if(state==freeState || state==escapingDeadlock)
    {
        if(speed<0.01)
        {
            _stopTime=_time;
            state=-state;
        }
    }
    else if(state==deadlockState && speed>0.01 )
    {
        state=freeState;
    }
    else if(shouldDetectDeadlocks && (state==-freeState || state==-escapingDeadlock))
    {
        if(speed>0.01) state=-state;
        else if((_time-_stopTime)>MIN_DEADLOCK_TIME)
        {
            if(rand()<RAND_MAX*(_time-_stopTime-MIN_DEADLOCK_TIME)/MAX_DEADLOCK_TIME)
            {
                numberOfDeadlocks++;
                state=deadlockState;
            }
        }
    }
    
    
    if(state==deadlockState && shouldEscapeDeadlocks)
    {
        [self updateSensing];
        [self escapeDeadlock];
        return;
    }
#endif
    
    
    
    /*
     if(state==freeState && currentEmotion==confusion)
     {
     state=follow;
     }
     else if(state==follow && currentEmotion!=confusion)
     {
     state=freeState;
     }
     */
    
    
    [self updateTarget];
    //[self updatePath];
    
    //NEW safetyAcceleration
    
    safetyAcceleration=NSMakePoint(0,0);
    
    
    [self updateSensing];
    
    
    [self updateEmotion];
    
    [self updateEmotionalModulation];
    
#ifdef SOCIAL_FORCE
    
    [self updateSocialAcceleration];
    
#endif
    
    
    if(state==escapingDeadlock)
    {
        [self escapeDeadlockFrustration];
        
    }
    else
    {
        [self updateDesideredVelocity];
    }
    //else if(state==follow)
    //{
    //    [self followNearest];
    //}
    //else{
    
    //}
    
    
    
    //NSLog(@"control %d desidered velocity (%.3f,%.3f)",control,desideredVelocity.x,desideredVelocity.y);
    
#ifdef RAB
    if(sensor==rab)
    {
        [self sendRabMessage];
    }
#endif
    
    [self publishEmotionMessage];
    
    
}

// NEW Comparison

// Devo farlo offline, rileggendo il csv con il path!!!!! E' un altra routine!!! Forse non ha senso avere piu' di una comparison alla volta. Posso controllare se e' giusta riproducendo il path con gli stessi parametri (ci sara' un certo errore di approssimazione)

// Misura microscopica nel senso che misuro il differenziale del cammino, cioe' la tendenza instantanea a fare una traiettoria diversa

// Come risulato salvo i delta path e le statistiche (un po' come faccio ora ma delta). Sembra abbastanza pulito: leggo un files, lo uso per la conf. del sistema. Se lo faccio offline perdo il vantaggio di avere il gia' calcolato il sensing -> ci metto il doppio. Forse ci stanno le due versioni (che tanto un po' dovrebbero sovrapporsi)
// In piu' posso usare il path offline per generare traiettorie indipendenti dall'interazione umana (ma per questo basterebbe ignorare nel sensing l'agente interattivo)

//Per farlo offline con i robot autonomi dovrei salvare il sensing reale (con sensing error), se no non posso ricostruire l'input!! Per l'umano funziona (prob. per farlo pulito devo prendere errore =0 se no dovrei fare un sampling su tutta la distribuzione e poi fare la media)

/*
 -(void)updateComparisionStatistics:(NSDictionary *)comparison
 {
 Agent *agent=[comparison valueForKey:@"agent"];
 
 double dist=sqrt((agent.position.x-self.position.x)*(agent.position.x-self.position.x)+(agent.position.y-self.position.y)*(agent.position.y-self.position.y));
 
 double oldDist=[[comparison valueForKey:@"dist"] doubleValue];
 
 [comparison setValue:[NSNumber numberWithDouble:dist+oldDist] forKey:@"dist"];
 
 
 for(NSDictionary *n in agent.comparisons)
 {
 [self updateComparisionStatistics:n];
 }
 }
 
 
 -(void)updateComparisionPhysics:(NSDictionary *)comparison
 {
 Agent *agent=[comparison valueForKey:@"agent"];
 [agent update];
 
 for(NSDictionary *n in agent.comparisons)
 {
 [agent updateComparisionPhysics:n];
 }
 }
 
 
 -(void)updateComparisionControl:(NSDictionary *)comparison
 {
 NSString *inheritance=[comparison valueForKey:@"inheritance"];
 Agent *agent=[comparison valueForKey:@"agent"];
 
 agent.position=self.position;
 agent.velocity=self.velocity;
 agent.angle=self.angle;
 agent.speed=self.speed;
 
 
 if([inheritance isEqualToString:@"sensing"])
 {
 NSLog(@"ERROR Not fully implemented");
 
 
 [agent updateSensing]; ///TODO Non deve essere RAB se no non riceve i messaggi (che sono solo per gli agenti fisici, dovrei modificare il codice)
 //updateSensing;
 //updateControl;
 //updateDesideredSpeed;
 
 [agent updateDesideredSpeed];
 }
 else  if([inheritance isEqualToString:@"control"])
 {
 //copy sensing (weak)
 //updateControl
 //updateDesideredSpeed;
 agent->nearAgents=self->nearAgents;
 
 if(control==RVO_C)
 {
 [self computeRVOObstacles];
 }
 else
 {
 [self computeCache];
 }
 
 [agent updateDesideredSpeed];
 }
 else  if([inheritance isEqualToString:@"parameters"])
 {
 //copy sensing (weak)
 //copy control (weak)
 //updateDesideredSpeed;
 
 if(self.control==RVO_C)
 {
 agent.RVOAgent->obstacleNeighbors_=self.RVOAgent->obstacleNeighbors_;
 agent.RVOAgent->agentNeighbors_=self.RVOAgent->agentNeighbors_;
 }
 else
 {
 agent->nearAgents=self->nearAgents;
 agent->nearAgentsStatic=self->nearAgentsStatic;
 }
 
 [agent updateDesideredSpeed];
 }
 else
 {
 NSLog(@"ERROR: not implemented");
 ///TODO: implent
 //set/copy desidered speed; (? meglio evitare questo caso che in pratica e' solo rilevante per tau)
 }
 
 
 for(NSDictionary *n in agent.comparisons)
 {
 
 [agent updateComparision:n];
 }
 
 
 }
 
 */

-(void)setTargetSpeed:(double)tSpeed andTargetAngle:(double)tAngle
{
    
    desideredAngle=tAngle+angle;
    desideredVelocity=NSMakePoint(tSpeed*cos(desideredAngle),tSpeed*sinf(desideredAngle));
    
#ifdef SOCIAL_FORCE
    desideredVelocity.x+=socialAcceleration.x;
    desideredVelocity.y+=socialAcceleration.y;
    
    double n=sqrt(desideredVelocity.x*desideredVelocity.x+desideredVelocity.y*desideredVelocity.y);
    
    if(n>optimalSpeed)
    {
        desideredVelocity.x=desideredVelocity.x/n*optimalSpeed;
        desideredVelocity.y=desideredVelocity.y/n*optimalSpeed;
    }
    
#endif
    
    //double dE=mass*((desideredVelocity.x-velocity.x)*velocity.x+(desideredVelocity.y-velocity.y)*velocity.y);
    //if(dE>0) work+=dE;
#ifdef GUI
    oldAngle=angle;
#endif
    
    rotation=fabs(signedNormalize(angle-desideredAngle));
    
    cumulatedRotation+=rotation;
    
    if(cumulatedRotation-previousCumulatedRotation<minimalRotationToTarget) rotation=0;
    
    if(state==deadlockState && shouldEscapeDeadlocks) deadlockRotation+=fabs(signedNormalize(angle-desideredAngle));
    
    //The cumulatedRotation is defined in this way because for an omnidirectional agent with instantanous acceleration I cannot make sense of the path direction (collisions, but also when it inverts the path. Similar to the human and footbot definitions it is 0 if the path is strainght. Problem with human like because of the tau relaxation it is not the same as the actual path rotation.
    
    
    //Instantaneous (head) rotation
    
    angle=desideredAngle;
    
    
    
    
    if(control!=HUMAN_LIKE)
    {
        self.velocity=desideredVelocity;
    }
    else{
#ifndef RELAXED_ACCELERATION
        //Instantaneous (body) acceleration
        self.velocity=desideredVelocity;
#endif
    }
    
    
    steps++;
}


BOOL strictSafety=NO;


-(NSDictionary *)emotionMessageForAgent:(Agent *)a
{
    if([a respondsToSelector:@selector(agent)])
    {
        return [self emotionMessageForAgent:[a agent]];
    }
    else
    {
        return [[Agent emotionMessages] valueForKey:a.rabID];
    }
}

-(void)setRelativePosition:(NSPoint)p ofObstacle:(ObstacleCache *)obstacle
{
    
    
    
    
    double distanceSquare=p.x*p.x+p.y*p.y;
    double distance=sqrt(distanceSquare);
    
    double r=obstacle.agent.radius;
    // double minDistance=r+radius+0.002; //wrong for human because they compenetrate
    
    obstacle.angle=atan2f(p.y,p.x);
    obstacle.relativePosition=p;
    obstacle.centerDistance=distance;
    obstacle.centerDistanceSquare=distanceSquare;
    obstacle.sensingMargin=safetyMargin;//0;
    obstacle.minDistance=r+radius+obstacle.sensingMargin;
    
    obstacle.agentSensingMargin=r+obstacle.sensingMargin;
    
    obstacle.position=NSMakePoint(obstacle.relativePosition.x+position.x, obstacle.relativePosition.y+position.y);
    
    
     NSDictionary *m=[self emotionMessageForAgent:obstacle.agent];
    
    /*
   
    if(currentEmotion!=urgency)
    {
        if(m && [[m valueForKey:@"emotion"] intValue]==urgency)
        {
            obstacle.minDistance=obstacle.minDistance+0.3;
            obstacle.agentSensingMargin=obstacle.agentSensingMargin+0.3;
        }
        if(m && [[m valueForKey:@"emotion"] intValue]==confusion)
        {
            obstacle.minDistance=obstacle.minDistance+0.2;
            obstacle.agentSensingMargin=obstacle.agentSensingMargin+0.2;
        }
    }
    if(currentEmotion==urgency)
    {
        if(m && [[m valueForKey:@"emotion"] intValue]==urgency)
        {
            
        }
        else
        {
            obstacle.minDistance=r+radius+0.03;
            obstacle.agentSensingMargin=r+0.03;
            //obstacle.minDistance=0;
            //obstacle.agentSensingMargin=0;
        }
    }
     */
    
    
    if(m && [[m valueForKey:@"emotion"] intValue]==urgency)
    {
        obstacle.minDistance=obstacle.minDistance+0.4;
        obstacle.agentSensingMargin=obstacle.agentSensingMargin+0.4;
    }
    
    if(m && [[m valueForKey:@"emotion"] intValue]==confusion)
    {
        obstacle.minDistance=obstacle.minDistance+0.2;
        obstacle.agentSensingMargin=obstacle.agentSensingMargin+0.2;
    }
    
    if([self modulationIsActiveFoEmotion:urgency])
    {
        //if(debug) printf("%.3f: %.3f ->",emotionActivation[urgency],obstacle.agentSensingMargin);
       
        obstacle.agentSensingMargin=r+fmax(0.03,(obstacle.agentSensingMargin-r)*(1-emotionActivation[urgency]));
        obstacle.minDistance= obstacle.agentSensingMargin+radius;
        //if(debug) printf("%.3f\n",obstacle.agentSensingMargin);
    }
    
    
    
    if(distance<obstacle.minDistance)
    {
		if(strictSafety)
		{
			obstacle.visibleAngle=PI/2+0.1;
		}
		else{
            
        	obstacle.visibleAngle=asinf(fmin(obstacle.agentSensingMargin/distance,1));//asinf(r/distance);//PI/2;//asinf(obstacle.agentSensingMargin/distance);//asinf(r/distance); //should be PI/2 to avoid collisions (side-to-side)
            
            //printf("%.2f\n",obstacle.visibleAngle);
            //asinf(fmin((obstacle.agentSensingMargin+r)*0.5/distance,1));
		}
    }
    
    //obstacle.agentSensingMargin=r+socialMargin*0.01;
	//obstacle.sensingMargin=minDistance+2*socialMargin*0.01;
    
    //[obstacle compute];
}

#pragma mark - target
@synthesize target,pathMargin,updatePathBlock,targetNumber,pathMarkers,currentPathMarker,targetAbsoluteAngle,interaction;

@synthesize personality,currentEmotion;

-(void)setPathWithRadius:(CGFloat) r center:(NSPoint)c segments:(NSUInteger)n direction:(int)dir
{
    path=(NSPoint *)calloc(n,sizeof(NSPoint));
    NSPoint *p=path;
    pathEnd=path+n;
    nextPathPoint=path;
    double a=0;
    double da=TWO_PI/n;
    if(dir==0)da=-da;
    while(p<pathEnd)
    {
        p->x=c.x+cos(a)*r;
        p->y=c.x+sin(a)*r;
        a+=da;
        p++;
    }
    target=*path;
}

-(void)setPathWithRadius:(CGFloat) r center:(NSPoint)c segments:(NSUInteger)n
{
    [self setPathWithRadius:r center:c segments:n direction:1];
}

-(void)setPathWithMarkers:(NSArray *)markers
{
    self.pathMarkers=markers;
    currentPathMarkerIndex=0;
    self.currentPathMarker=[self.pathMarkers objectAtIndex:currentPathMarkerIndex];
    target=currentPathMarker.position;
}

-(void)setPathWithPoint:(NSPoint) point
{
    path=(NSPoint *)malloc(2*sizeof(NSPoint));
    *path=position;
    *(path+1)=point;
    pathEnd=path+2;
    nextPathPoint=path;
    target=*path;
}



-(void) setPath:(NSString *)s
{
    NSArray *numStrings=[s componentsSeparatedByString:@" "];
    NSUInteger length=[numStrings count]/2;
    path=(NSPoint *)calloc(length,sizeof(NSPoint));
    NSPoint *p=path;
    int index=0;
    for(NSString *numString in numStrings)
    {
        if(index)
        {
            p->y=[numString doubleValue];
            p++;
        }
        else
        {
            p->x=[numString doubleValue];
        }
        index=!index;
    }
    target=*path;
    nextPathPoint=path;
    pathEnd=path+length;
    
    self.pathMarkers=nil;
}

-(void)advancePath:(NSUInteger) s
{
    if(pathMarkers)
    {
        currentPathMarkerIndex=(s+currentPathMarkerIndex) % [pathMarkers count];
        self.currentPathMarker=[pathMarkers objectAtIndex:currentPathMarkerIndex];
        target=currentPathMarker.position;
    }
    else
    {
        if(s)
        {
            unsigned long k=(s+(nextPathPoint-path)) % (pathEnd-path);
            nextPathPoint=path+k;
        }
        target=*nextPathPoint;
    }
}

-(void)goToTheNearestPoint
{
    NSPoint *p=path;
    double dist=100000;
    double d;
    while(p<pathEnd)
    {
        d=(position.x-p->x)*(position.x-p->x)+(position.y-p->y)*(position.y-p->y);
        if(d<dist)
        {
            nextPathPoint=p;
            dist=d;
        }
        p++;
    }
    target=*nextPathPoint;
}

//The agent has arrived to a target



-(void)updateTarget
{
    if(state==arrivedState) return;
    
    
    if(interaction!=NONE)
    {
        targetAngle=signedNormalize(targetAbsoluteAngle-angle);
        effectiveHorizon=horizon;
        return;
    }
    
    
    
    BOOL newTarget=NO;
    if(updatePathBlock) (newTarget=(self.updatePathBlock)());
    
    
    
    NSPoint sensedTargetPoint=[self senseTargetWithVision:target];
    
    
    
    NSPoint agentToTarget=NSMakePoint(sensedTargetPoint.x-position.x,sensedTargetPoint.y-position.y);
    targetDistance=sqrt(agentToTarget.x*agentToTarget.x+agentToTarget.y*agentToTarget.y);
    targetAngle=signedNormalize(atan2f(agentToTarget.y,agentToTarget.x)-angle);
    
   
    
    
    
    if(useEffectiveHorizon)
    {
        effectiveHorizon=fmin(horizon,targetDistance);
    }
    else
    {
        effectiveHorizon=horizon;
    }
    
    if(newTarget)
    {
        
        //if(targetSensingQuality==0.0 && [self isMemberOfClass:[myopicAgent class]]) NSLog(@"NEW %.2f %.2f %.2f %.2f",position.x,position.y,target.x,target.y);
        
        
        NSPoint ragentToTarget=NSMakePoint(target.x-position.x,target.y-position.y);
        double rtargetDistance=sqrt(ragentToTarget.x*ragentToTarget.x+ragentToTarget.y*ragentToTarget.y);
        double rtargetAngle=signedNormalize(atan2f(ragentToTarget.y,ragentToTarget.x)-angle);
        
        //updateEfficiency
        //We assume that for a specific agent type (foobots, humans) the angle points in the direction of velocity. The mother class Agent is implemented so that the angle is always in the direction of desidered angle!. I could change it but I should decide how to handle the case with speed=0 and the collisions, similar to the human.
        
        minimalPathDuration+=minimalTimeToTarget;
        double duration=_time-lastTimeAtTarget;
        
        
        
        if(numberOfReachedTargets>1)
        {
            pathDuration+=duration;
        }
        else
        {
            
        }
        lastTimeAtTarget=_time;
        
        double da=cumulatedRotation-previousCumulatedRotation;
        double dl=pathLength-previousPathLength;
        double extraRotation=da-minimalRotationToTarget;
        if(numberOfReachedTargets>1)
        {
            cumulatedExtraRotation+=extraRotation;
            cumulatedPathLength+=dl;
            minimalPathLength+=minimalLengthToTarget;
        }
        else
        {
            cumulatedExtraRotation=0;
            energy=0;
            numberOfDeadlocks=0;
            numberOfHits=0;
            deadlockRotation=0;
            minimalPathLength=0;
        }
        previousPathLength=pathLength;
        previousCumulatedRotation=cumulatedRotation;
        minimalRotationToTarget=fabs(rtargetAngle);
        minimalLengthToTarget=rtargetDistance-pathMargin;
        minimalTimeToTarget=minimalLengthToTarget/baseOptimalSpeed;
        
        if([self respondsToSelector:@selector(maxRotationSpeed)])
        {
            minimalTimeToTarget+=minimalRotationToTarget/[[self valueForKey:@"maxRotationSpeed"] doubleValue]*0.5*0.135;
        }
        
        if(numberOfReachedTargets>1)throughputEfficiency=minimalPathDuration/pathDuration;
        
        //NSLog(@"%.4f %.4f",minimalPathDuration,pathDuration);
        
        
        // NSLog(@"%.4f %.4f %.4f %.4f -> %.4f",cumulatedRotation,cumulatedExtraRotation,minimalTimeToTarget,duration,throughputEfficiency);
        
    }
}

-(BOOL)hasReachedTarget
{
    return (sqrt((target.x-position.x)*(target.x-position.x)+(target.y-position.y)*(target.y-position.y))<pathMargin);
}

-(void) updatePath
{
    if(sqrt((target.x-position.x)*(target.x-position.x)+(target.y-position.y)*(target.y-position.y))<pathMargin)
    {
        if([[[World world] experiment] isMemberOfClass:[WorldRandom class]])// || [[[World world] experiment] isKindOfClass:[WorldLEDs class]])
        {
            numberOfReachedTargets++;
            [[[World world] experiment] moveAgentTargetAtRandomAngle:self];
            return;
        }
        
        numberOfReachedTargets++;
        nextPathPoint++;
        if(nextPathPoint==pathEnd) nextPathPoint=path;
        target=*nextPathPoint;
    }
    
    
    NSPoint agentToTarget=NSMakePoint(target.x-position.x,target.y-position.y);
    targetAngle=signedNormalize(atan2f(agentToTarget.y,agentToTarget.x)-angle);
    double D=sqrt(agentToTarget.x*agentToTarget.x+agentToTarget.y*agentToTarget.y);
    effectiveHorizon=fmin(horizon,D);
    
    //effectiveTarget=NSMakePoint(agentToTarget.x/D*effectiveHorizon,agentToTarget.y/D*effectiveHorizon);
    
}

-(void)initTarget
{
    //
}


#pragma mark - physics
#ifdef USE_BULLET_FOR_COLLISION
@synthesize collisionObject,radius,mass;
#endif

-(void)initPhysics
{
    agentsNowAtContact=[[NSMutableSet set] retain];
    agentsAtContact=[[NSMutableSet set] retain];
}


+(btCollisionShape *)collisionShape
{
    static btCollisionShape *shape;
    if(!shape)
    {
        //shape=new btCylinderShapeZ(btVector3(btScalar(RADIUS),btScalar(RADIUS),btScalar(HEIGHT/2)));
        //shape=new btSphereShape([[World world] radius]);
        shape=new btSphereShape(0.1);
        //shape=new btBoxShape(btVector3(btScalar(RADIUS),btScalar(RADIUS),btScalar(HEIGHT/2)));
    }
    return shape;
}

-(btCollisionShape *)shape
{
    return new btSphereShape(radius);
}


-(void)setMass:(double)m
{
    mass=m;
    self.radius=mass/320.0;
}

-(double)mass
{
    return mass;
}

-(void)setRadius:(double)r
{
    radius=r;
    mass=320*r;
#ifdef USE_BULLET_FOR_COLLISION
    if(collisionObject) static_cast<btSphereShape *>(collisionObject->getCollisionShape())->setUnscaledRadius(r);
#endif
}

-(double) radius
{
    return radius;
}

+ (NSSet *)keyPathsForValuesAffectingMass
{
    return [NSSet setWithObjects:@"radius",nil];
}


-(void)hasHit:(Agent *)agent
{
    [agentsNowAtContact addObject:agent];
}

-(void)updateHitCount
{
    //TODO exec bad
    
    if([agentsNowAtContact count])
    {
        [agentsAtContact intersectSet:agentsNowAtContact];
        int c=(int)[agentsNowAtContact count]-(int)[agentsAtContact count];
        if(c)
        {
            numberOfHits+=c;
            // [[World world] setTimeScale:10];
            //NSLog(@"%d",c);
        }
        
    }
    [agentsAtContact setSet:agentsNowAtContact];
}

-(void)advanceTimeByStep:(NSTimeInterval) dT;
{
    dt=dT;
    _time+=dt;
}


-(void)updatePosition
{
    pathLength+=fabs(speed*dt);
    
    
    position.x+=velocity.x*dt;
    position.y+=velocity.y*dt;
    
#ifdef USE_BULLET_FOR_COLLISION
    collisionObject->getWorldTransform().setOrigin(btVector3(position.x,position.y,0));
#endif
}


-(void)updateCollisions
{
    compression=0;
    
    for(CircularWall *w in [[World world] circularWalls]) [self resolveCollisionWithCircularWall:w];
    
    
    
#ifndef USE_BULLET_FOR_COLLISION
    for(Wall *w in [[World world] walls]) [self resolveCollisionWithWall:w];
    //ev. migliora con nearAgent (da aggiornare ogni mezzo secondo (due array uno dentro apertura e uno fuori
    for(Agent *o in agents]) if(o!=self)[self resolveCollisionWithAgent:o];
#endif
}

-(void)update
{
    [self updatePosition];
    
    double previousSpeed=speed;
    
    
    
#ifdef TRACK_ACCELERATION
    acceleration.x=-velocity.x;
    acceleration.y=-velocity.y;
#endif
    
#ifdef RELAXED_ACCELERATION
    
    if(control==HUMAN_LIKE)
    {
        if(tau>0)
        {
            
#ifdef EXACT_INTEGRATION
            self.velocity=NSMakePoint(exp(-dt/tau)*(self.velocity.x-desideredVelocity.x)+desideredVelocity.x,exp(-dt/tau)*(self.velocity.y-desideredVelocity.y)+desideredVelocity.y);
#else
            self.velocity=NSMakePoint((desideredVelocity.x-velocity.x)/tau*dt+velocity.x,(desideredVelocity.y-velocity.y)/tau*dt+velocity.y);
#endif
        }
        else
        {
            self.velocity=desideredVelocity;
        }
    }
#endif
    
    //cumulated rotations: reference is not head beacuse of instaneous head rotation but velocity direction.
    // Fragile by collisions beacuse of angle + PI
    
    
    
    energy+=g(0.5*(speed+previousSpeed)*(speed-previousSpeed));
    
    [self updateCollisions];
    
    
    if(speed>0)
    {
        self.efficacity=cos(atan2(velocity.y,velocity.x)-targetAngle-angle)*speed/optimalSpeed;
    }
    else
    {
        self.efficacity=0;
    }
    
    //NSLog(@"velocity (%.3f,%.3f)",velocity.x,velocity.y);
    
}

#ifndef USE_BULLET_FOR_COLLISION

-(void)detectCollisionWithAgent:(Agent *)agent
{
	NSPoint dx=NSMakePoint(position.x-agent.position.x, position.y-agent.position.y);
	double n=sqrt(dx.x*dx.x+dx.y*dx.y);
	if(n<2*(radius+agent.radius))
	{
        double diff=(2*(radius+agent.radius)+0.02-n);
		dx.x=dx.x/n;
		dx.y=dx.y/n;
		position.x+=dx.x*diff;
		position.y+=dx.y*diff;
	}
}

#endif

//Inelasticity of wall-agent collision <=1





-(void)resolveCollisionWith:(id)object
{
    if([object isMemberOfClass:[Wall class]])
    {
        [self resolveCollisionWithWall:(Wall *)object];
    }
    else
    {
        [self resolveCollisionWithAgent:(Agent *)object];
    }
}




double g(double x)
{
    if(x<0) return 0;
    return fabs(x);
}



-(void)applyContactForce:(NSPoint) dx penetration:(double)diff
{
    double mag=g(diff)*KR;
    compression+=mag;
    mag=mag*dt/self.mass;
    self.velocity=NSMakePoint(velocity.x+dx.x*mag,velocity.y+dx.y*mag);
    hasHit=YES;
}


-(void)resolveCollisionWithCircularWall:(CircularWall *)wall
{
	NSPoint dp=NSMakePoint(position.x-wall.x, position.y-wall.y);
    
    double d=sqrt(dp.x*dp.x+dp.y*dp.y);
    
    double penetration;
    
    BOOL inside=NO;
    
    if(d>wall.radius)
    {
        penetration=d-wall.radius-radius-W_THICKNESS*0.5;
    }
    else
    {
        inside=YES;
        penetration=wall.radius-d-radius-W_THICKNESS*0.5;
    }
    
    if(penetration<0)
    {
        dp.x=dp.x/d;
		dp.y=dp.y/d;
        
        if(inside)
        {
            dp.x*=-1;
            dp.y*=-1;
        }
        
        [self applyContactForce:dp penetration:-penetration];
        
	}
}

-(void)resolveCollisionWithWall:(Wall *)wall
{
	NSPoint dp=NSMakePoint(position.x-wall.x, position.y-wall.y);
	double wa=PI/180.0*wall.angle;
	double d1=-dp.x*sin(wa)+dp.y*cos(wa);
	double d2=dp.x*cos(wa)+dp.y*sin(wa);
    
    double diff1=fabs(d1)-radius-W_THICKNESS*0.5;
    double diff2=fabs(d2)-wall.length-radius;
	
	if(diff1<0 && diff2<0)
	{
        NSPoint dx;
        double diff;
        
		if(fabs(diff1)<fabs(diff2))
		{
            //perp.
			dx.x=-sin(wa);
            dx.y=cos(wa);
            if(d1<0)
            {
                dx.x*=-1;
                dx.y*=-1;
            }
            diff=fabs(diff1);
		}
		else {
            //long.
			dx.x=cos(wa);
            dx.y=sin(wa);
            
            if(d2<0)
            {
                dx.x*=-1;
                dx.y*=-1;
            }
            diff=fabs(diff2);
		}
        
#ifdef FORCE
        [self applyContactForce:dx penetration:diff];
#else
        
        //Elastic recoil: m_wall=/infinity v_wall=0 => /mu=m
        
        double vn=-K_WALL*2*(velocity.x*dx.x+velocity.y*dx.y);
        self.velocity=NSMakePoint(velocity.x+dx.x*vn,velocity.y+dx.y*vn);
        position.x+=dx.x*diff;
		position.y+=dx.y*diff;
#endif
	}
}


-(void)resolveCollisionWithAgent:(Agent *)agent
{
    NSPoint dx=NSMakePoint(position.x-agent.position.x, position.y-agent.position.y);
    double n=sqrt(dx.x*dx.x+dx.y*dx.y);
    double p=(self.radius+agent.radius-n);
	if(p>0)
	{
        dx.x=dx.x/n;
		dx.y=dx.y/n;
        [self hasHit:agent];
        
        //Elastic recoil (instead of using a potential!!! like in the paper that lead to non conservation of energy-momentum)
        
#ifdef FORCE
        
        [self applyContactForce:dx penetration:p];
        
        dx.x=-dx.x;
        dx.y=-dx.y;
        
        [agent applyContactForce:dx penetration:p];
#else
        
        double mu=(self.mass*agent.mass)/(self.mass+agent.mass);
        double vn=-K_AGENT*2*mu*((self.velocity.x-agent.velocity.x)*dx.x+(self.velocity.y-agent.velocity.y)*dx.y);
        self.velocity=NSMakePoint(self.velocity.x+dx.x*vn/self.mass,  self.velocity.y+dx.y*vn/self.mass);
        agent.velocity=NSMakePoint(agent.velocity.x-dx.x*vn/agent.mass,agent.velocity.y-dx.y*vn/agent.mass);
        
        //Instantanuous
        
		self.position.x+=dx.x*p*0.5;
		self.position.y+=dx.y*p*0.5;
        
        agent.position.x-=dx.x*p*0.5;
		agent.position.y-=dx.y*p*0.5;
#endif
	}
}

#pragma mark - mobility

@synthesize hasHit,numberOfHits,position,velocity,angle,speed;

-(void)setVelocity:(NSPoint)value
{
    if(velocity.x==value.x && velocity.y==value.y)return;
    velocity=value;
    speed=sqrt(velocity.x*velocity.x+velocity.y*velocity.y);
}

-(NSPoint)velocity
{
    return velocity;
}

-(Agent *)initAtPosition:(NSPoint)p
{
    _time=0;
    state=freeState;
    isEscaping=NO;
    numberOfDeadlocks=0;
    useEffectiveHorizon=YES;
    self.position=p;
    self.velocity=NSMakePoint(0, 0);
    
    
    angle=TWO_PI*rand()/RAND_MAX;
    hasHit=NO;
    dt=0;
    
    btMatrix3x3 basis;
	basis.setIdentity();
    
#ifdef USE_BULLET_FOR_COLLISION
    collisionObject= new btCollisionObject();
    //collisionObject->setCollisionShape([Agent collisionShape]);
    collisionObject->setCollisionShape([self shape]);
	collisionObject->getWorldTransform().setBasis(basis);
    collisionObject->getWorldTransform().setOrigin(btVector3(position.x,position.y,HEIGHT/2));
    collisionObject->setUserPointer(self);
#endif
    //object->setContactProcessingThreshold(0.04);
    //NSLog(@"Is active %d is static %d type %d state %d contact %.2f",object->isActive(),object->isStaticObject(),object->getInternalType(),object->getActivationState(),object->getContactProcessingThreshold());
    
#ifdef USE_BULLET_FOR_SENSING
    horizonObject= new btCollisionObject();
    horizonObject->setCollisionShape([Agent horizonShape]);
	horizonObject->getWorldTransform().setBasis(basis);
    horizonObject->getWorldTransform().setOrigin(btVector3(position.x,position.y,HEIGHT/2));
    horizonObject->setUserPointer(self);
#endif
    
    
    
    
    return self;
}



#pragma mark - performance

#ifdef TRACK_ACCELERATION
@synthesize acceleration;
-(void)updateAcceleration
{
    
#ifdef PREDICT_CHANGE
    double vc=sqrt((velocity.x+acceleration.x)*(velocity.x+acceleration.x)+(velocity.y+acceleration.y)*(velocity.y+acceleration.y));
    double oldMax= velocityChangeSamples[velocityChangeMaxIndex];
    velocityChangeSamples[velocityChangeIndex]=vc;
    
    if(vc>=oldMax)
    {
        velocityChangeMaxIndex=velocityChangeIndex;
    }
    else if(velocityChangeIndex==velocityChangeMaxIndex)
    {
        int k=1;
        velocityChangeMaxIndex=velocityChangeIndex;
        uint index;
        for (; k<NUMBER_OF_CHANGE_SAMPLES; k++) {
            index=(velocityChangeIndex+k) % NUMBER_OF_CHANGE_SAMPLES;
            if(velocityChangeSamples[index]>=velocityChangeSamples[velocityChangeMaxIndex]) velocityChangeMaxIndex=index;
        }
    }
    velocityChangeIndex=(velocityChangeIndex+1) % NUMBER_OF_CHANGE_SAMPLES;
#endif
    
    
    
    
    
    
    acceleration.x=(velocity.x+acceleration.x)/dt;
    acceleration.y=(velocity.y+acceleration.y)/dt;
    
    
    
    // double aT=(acceleration.x*velocity.y-acceleration.y*velocity.x)/speed;
    // double aL=(acceleration.x*velocity.x+acceleration.y*velocity.y)/speed;
    
    //printf("%.3f,%.3f,",aL,aT);
    
    
    //printf("%.3f,%.3f,",velocity.x,velocity.y);
    
    /*
     if(debug)
     {
     double aL=(acceleration.x*velocity.y-acceleration.y*velocity.x)/speed;
     //printf("%.4f,",aL);
     }
     */
    
    //printf("%.3f,",sqrt(acceleration.x*acceleration.x+acceleration.y*acceleration.y));
    
}
#endif
@synthesize work,deviation,compression,numberOfReachedTargets;
@synthesize pathDuration,throughputEfficiency,cumulatedPathLength,pathLength,energy,cumulatedExtraRotation,cumulatedRotation,minimalDistanceToAgent,minimalPathLength,deadlockRotation,meanEfficacity;

@dynamic efficacity;

-(void)setEfficacity:(double)value
{
    efficacity=value;
    numberOfEfficacityMeasures+=1.0;
    cumulatedEfficacity+=value;
    meanEfficacity=cumulatedEfficacity/numberOfEfficacityMeasures;
}

-(double)efficacity
{
    return efficacity;
}


-(void)initPerformance
{
#ifdef TRACK_ACCELERATION
    self.acceleration=NSMakePoint(0, 0);
#endif
    self.numberOfReachedTargets=0;
    self.work=0;
}



#pragma mark - profiling
@synthesize  controlUpdateTime;


#pragma mark - RVO

@synthesize RVOAgent;
@synthesize timeHorizon,timeHorizonStatic;

-(void)setupRVOAgent
{
    RVOAgent->velocity_=RVO::Vector2(velocity.x,velocity.y);
    RVOAgent->position_=RVO::Vector2(position.x,position.y);
    RVOAgent->radius_=radius;
    RVOAgent->maxNeighbors_=1000;
    RVOAgent->maxSpeed_=optimalSpeed;
    shouldEscapeDeadlocks=NO;
    RVOAgent->timeStep_=controlUpdatePeriod;
}


-(void)computeRVOObstacles
{
    
    RVOAgent->timeHorizon_=timeHorizon;//2*tau;//horizon*2/optimalSpeed;//10;
    RVOAgent->timeHorizonObst_=timeHorizonStatic;//timeHorizon*2;//tau;//horizon/optimalSpeed;//5;
    RVOAgent->neighborDist_=2*horizon;
    
    
    //NSLog(@"%.2f %.2f", RVOAgent->timeHorizon_,horizon);
    float rangeSq = RVO::sqr(RVOAgent->timeHorizonObst_ * RVOAgent->maxSpeed_ + radius+safetyMargin);
    //float rangeSq = horizon*horizon;//sqr(timeHorizonObst_ * maxSpeed_ + radius_);
    
    
    for(int i=0;i<RVOAgent->obstacleNeighbors_.size();i++)
    {
        delete RVOAgent->obstacleNeighbors_[i].second;
    }
    
    
    RVOAgent->obstacleNeighbors_.clear();
    
    ///TODO: list of walls as property of world!
    
    if([[[World world] walls] count]!=0 && RVOAgent->obstacleNeighbors_.size()==0 )
    {
        for(Wall *wall in [[World world] walls])
        {
            
            double alpha=wall.angle*PI/180;
            
            RVO::Vector2 center=RVO::Vector2 (wall.x,wall.y);
            RVO::Vector2 e1=RVO::Vector2 (cos(alpha),sin(alpha));
            RVO::Vector2 e2=RVO::Vector2 (-sin(alpha),cos(alpha));
            
            RVO::Vector2 p1,p2,p3,p4;
            
            
            
            double l=wall.length+safetyMargin;
            double h=W_THICKNESS*0.5+safetyMargin;
            
            p1=center+e1*l+e2*h;
            p2=center-e1*l+e2*h;
            p3=center-e1*l-e2*h;
            p4=center+e1*l-e2*h;
            
            RVO::Obstacle *a=new RVO::Obstacle();
            RVO::Obstacle *b=new RVO::Obstacle();
            RVO::Obstacle *c=new RVO::Obstacle();
            RVO::Obstacle *d=new RVO::Obstacle();
            
            a->point_=p1;
            a->prevObstacle=d;
            a->nextObstacle=b;
            a->isConvex_ = true;
            a->unitDir_ = normalize(p2-p1);
            
            b->point_=p2;
            b->prevObstacle=a;
            b->nextObstacle=c;
            b->isConvex_ = true;
            b->unitDir_ = normalize(p3-p2);
            
            c->point_=p3;
            c->prevObstacle=b;
            c->nextObstacle=d;
            c->isConvex_ = true;
            c->unitDir_ = normalize(p4-p3);
            
            
            d->point_=p4;
            d->prevObstacle=c;
            d->nextObstacle=a;
            d->isConvex_ = true;
            d->unitDir_ = normalize(p1-p4);
            
            
            unsigned long n=RVOAgent->obstacleNeighbors_.size();
            unsigned long nn;
            
            RVOAgent->insertObstacleNeighbor(a, rangeSq);
            
            nn=RVOAgent->obstacleNeighbors_.size();
            if(nn!=n)  n=nn;
            else delete a;
            
            
            RVOAgent->insertObstacleNeighbor(b, rangeSq);
            
            nn=RVOAgent->obstacleNeighbors_.size();
            if(nn!=n)  n=nn;
            else delete b;
            
            RVOAgent->insertObstacleNeighbor(c, rangeSq);
            
            nn=RVOAgent->obstacleNeighbors_.size();
            if(nn!=n)  n=nn;
            else delete c;
            
            RVOAgent->insertObstacleNeighbor(d, rangeSq);
            
            nn=RVOAgent->obstacleNeighbors_.size();
            if(nn!=n)  n=nn;
            else delete d;
            
        }
        
        
        
    }
    
    //insert release here
    /*
     for(int i=0;i<RVOAgent->obstacleNeighbors_.size();i++)
     {
     delete RVOAgent->obstacleNeighbors_[i].second;
     }
     
     
     RVOAgent->obstacleNeighbors_.clear();
     */
    
    rangeSq = (horizon*2)*(horizon*2);
    
    for(int i=0;i<agentNeighbors.size();i++)
    {
        delete agentNeighbors[i];
    }
    
    agentNeighbors.clear();
    
    RVOAgent->agentNeighbors_.clear();
    
    
    
    
    for(ObstacleCache *obstacle in nearAgentsStatic)
    {
        //inset create here
        
        RVO::Agent *a=new RVO::Agent(NULL);
        a->velocity_=RVO::Vector2(obstacle.velocity.x,obstacle.velocity.y);
        
        RVO::Vector2 relativePosition=RVO::Vector2(obstacle.relativePosition.x,obstacle.relativePosition.y);
        
        
        a->position_=relativePosition+RVOAgent->position_;
        a->radius_=obstacle.agentSensingMargin;
        
        agentNeighbors.push_back(a);
        RVOAgent->insertAgentNeighbor(a, rangeSq);
    }
    
    
    
}

-(void)updateDesideredVelocityWithRVO
{
    
    if(state==arrivedState)
    {
        RVOAgent->prefVelocity_=RVO::Vector2(0,0);
    }
    else
    {
        RVO::Vector2 targetPosition=RVO::Vector2(target.x,target.y)-RVOAgent->position_;
        RVOAgent->prefVelocity_=targetPosition*optimalSpeed/abs(targetPosition);
    }
    
    RVOAgent->computeNewVelocity();
    double tAngle=signedNormalize(atan2(RVOAgent->newVelocity_.y(), RVOAgent->newVelocity_.x())-angle);
    double newTargetSpeed=abs(RVOAgent->newVelocity_);
    [self setTargetSpeed:newTargetSpeed andTargetAngle:tAngle];
}




//HRVO

@synthesize HRVOAgent;
-(void)computeHRVOObstacles
{
    ///TODO: adattare gli orizzonti
    ///TODO: non ricaricare gli ostacoli statici
    
    
    HRVOAgent->velocity_=HRVO::Vector2(velocity.x,velocity.y);
    HRVOAgent->orientation_=angle;
    HRVOAgent->position_=HRVO::Vector2(position.x,position.y);
    HRVOAgent->radius_=radius;
    HRVOAgent->maxNeighbors_=1000;
    
    HRVOAgent->neighborDist_=2*horizon;
    shouldEscapeDeadlocks=NO;
    
    HRVOAgent->isColliding_ = false;
    HRVOAgent->neighbors_.clear();
    
    for(int i=0;i<HRVOAgent->obstacles_.size();i++)
    {
        delete HRVOAgent->obstacles_[i];
    }
    
    for(int i=0;i<HRVOAgent->agents_.size();i++)
    {
        delete HRVOAgent->agents_[i];
    }
    
    HRVOAgent->obstacles_.clear();
    HRVOAgent->agents_.clear();
    
    
    float rangeSq = horizon*horizon;//sqr(timeHorizonObst_ * maxSpeed_ + radius_);
    
    
    ///TODO: list of walls as property of world!
    
    if([[[World world] walls] count]!=0 && HRVOAgent->obstacles_.size()==0 )
    {
        for(Wall *wall in [[World world] walls])
        {
            
            double alpha=wall.angle*PI/180;
            
            HRVO::Vector2 center=HRVO::Vector2 (wall.x,wall.y);
            HRVO::Vector2 e1=HRVO::Vector2 (cos(alpha),sin(alpha));
            HRVO::Vector2 e2=HRVO::Vector2 (-sin(alpha),cos(alpha));
            
            HRVO::Vector2 p1,p2,p3,p4;
            
            double l=wall.length+safetyMargin;
            double h=W_THICKNESS*0.5+safetyMargin;
            
            p1=center+e1*l+e2*h;
            p2=center-e1*l+e2*h;
            p3=center-e1*l-e2*h;
            p4=center+e1*l-e2*h;
            
            HRVO::Obstacle *a=new HRVO::Obstacle(p1,p2);
            HRVO::Obstacle *b=new HRVO::Obstacle(p2,p3);
            HRVO::Obstacle *c=new HRVO::Obstacle(p3,p4);
            HRVO::Obstacle *d=new HRVO::Obstacle(p4,p1);
            
            HRVOAgent->obstacles_.push_back(a);
            HRVOAgent->obstacles_.push_back(b);
            HRVOAgent->obstacles_.push_back(c);
            HRVOAgent->obstacles_.push_back(d);
            
            HRVOAgent->insertObstacleNeighbor(0, rangeSq);
            HRVOAgent->insertObstacleNeighbor(1, rangeSq);
            HRVOAgent->insertObstacleNeighbor(2, rangeSq);
            HRVOAgent->insertObstacleNeighbor(3, rangeSq);
            
        }
        
        
        
    }
    
    
    rangeSq = (horizon*2)*(horizon*2);
    
    uint i=0;
    
    for(ObstacleCache *obstacle in nearAgentsStatic)
    {
        //inset create here
        
        HRVO::Agent *a=new HRVO::Agent();
        a->velocity_=HRVO::Vector2(obstacle.velocity.x,obstacle.velocity.y);
        
        HRVO::Vector2 relativePosition=HRVO::Vector2(obstacle.relativePosition.x,obstacle.relativePosition.y);
        
        a->position_=relativePosition+HRVOAgent->position_;
        a->radius_=obstacle.agentSensingMargin;
        a->prefVelocity_=a->velocity_;
        
        
        HRVOAgent->agents_.push_back(a);
        HRVOAgent->insertAgentNeighbor(i, rangeSq);
        i++;
    }
    
}

-(void)updateDesideredVelocityWithHRVO
{
    HRVO::Vector2 targetPosition=HRVO::Vector2(target.x,target.y)-HRVOAgent->position_;
    HRVOAgent->prefVelocity_=targetPosition*optimalSpeed/abs(targetPosition);
    HRVOAgent->prefSpeed_=optimalSpeed;
    HRVOAgent->maxSpeed_=optimalSpeed;
    HRVOAgent->uncertaintyOffset_=0;
    
    
    
    
    HRVOAgent->computeNewVelocity();
    
    double tAngle=signedNormalize(atan2(HRVOAgent->newVelocity_.y(), HRVOAgent->newVelocity_.x())-angle);
    double newTargetSpeed=abs(HRVOAgent->newVelocity_);
    [self setTargetSpeed:newTargetSpeed andTargetAngle:tAngle];
    
    //NSLog(@"%.2f %.2f",HRVOAgent->newVelocity_.x(),HRVOAgent->newVelocity_.y());
    
    //HRVOAgent->computeWheelSpeeds();
    //if non holonomic
}


@end
















@implementation ObstacleCache

@synthesize angle,visibleAngle,C,velocity,relativePosition,minimalDistanceToCollision,minimalDistance,position,visibleDistance,centerDistance,penetration,agent,agentSensingMargin,sensingMargin,minDistance,optimalSpeed,socialMargin,centerDistanceSquare,relativeAngle;


// The obstacle is moving

// PERFORMACE: cos->cosf, sin -> sinf

-(double)distanceToCollisionWhenMovingInDirection:(double)alpha
{
    //if(fabs(C)<MIN_C) return 0;
    if(C<0)
    {
        //if(agent.speed>0.3) NSLog(@"%.2f",visibleAngle);
        
#ifdef GO_AWAY
        NSPoint relativeVelocity=NSMakePoint(velocity.x-optimalSpeed*cosf(alpha),velocity.y-optimalSpeed*sinf(alpha));
        //double A=relativeVelocity.x*relativeVelocity.x+relativeVelocity.y*relativeVelocity.y;
        double B=relativePosition.x*relativeVelocity.x+relativePosition.y*relativeVelocity.y;
        
        //printf("A %.2f B %.2f -> %d\n",A,B,2*B<=A);
        
        if(B<0) return NO_COLLISION;
        return 0;

#endif
        if(fabs(signedNormalize(alpha-angle))<visibleAngle) return 0;
        return NO_COLLISION;

        
        
        
    }
    
    NSPoint relativeVelocity=NSMakePoint(velocity.x-optimalSpeed*cosf(alpha),velocity.y-optimalSpeed*sinf(alpha));
    
    
    //if(agent.speed>0.3)  NSLog(@"(%.2f,%.2f)",relativeVelocity.x,relativeVelocity.y);
    
    double A=relativeVelocity.x*relativeVelocity.x+relativeVelocity.y*relativeVelocity.y;
    double B=relativePosition.x*relativeVelocity.x+relativePosition.y*relativeVelocity.y;
    
    //if(agent.speed>0.3)  NSLog(@"A %.2f B %.2f",A,B);
    
    if(B>0) return NO_COLLISION; //because time should be positive
    double D=B*B-A*C;
    
    
    //if(agent.speed>0.3)  NSLog(@"D %.2f",D);
    
    if(D<0) return NO_COLLISION; //because time should be real
    
    return optimalSpeed*(-B-sqrt(D))/A;
}


// The obstacle is static

-(double)distanceToCollisionInDirection:(double)alpha
{
    //if(fabs(C)<MIN_C) return 0;
    if(C<0)
    {
        
        
#ifdef GO_AWAY
        NSPoint relativeVelocity=NSMakePoint(velocity.x-optimalSpeed*cosf(alpha),velocity.y-optimalSpeed*sinf(alpha));
        double B=relativePosition.x*relativeVelocity.x+relativePosition.y*relativeVelocity.y;
        if(B<0) return NO_COLLISION;
        return 0;
#endif
        
        
        
        if(fabs(signedNormalize(alpha-angle))<visibleAngle) return 0;
#ifdef NEAR_VISION
        return NO_COLLISION;
#else
        return 0;
#endif
    }
    
    double B=-relativePosition.x*cosf(alpha)-relativePosition.y*sinf(alpha);
    if(B>0) return NO_COLLISION;
    double D=B*B-C;
    if(D<0) return NO_COLLISION;
    return -B-sqrt(D);
}



-(BOOL)visibleInSector:(sector *)se atAngle:(double)alpha
{
    
    double a=signedNormalize(angle-visibleAngle-alpha);
    double b=signedNormalize(angle+visibleAngle-alpha);
    double c;
    BOOL splitted=NO;
    if(a>b)
    {
        c=a;
        a=-PI;
        splitted=YES;
    }
    
    
    double visibleAng=0.0;
    sector *s=se;
    while(s->next)
    {
        if(s->angle>b)
        {
            if(splitted)
            {
                a=c;
                b=PI;
            }
            else
            {
                break;
            }
        }
        if(s->next->angle>a && s->distance>=visibleDistance-0.01)
        {
            visibleAng+=fmin(b,s->next->angle)-fmax(a,s->angle);
        }
        s=s->next;
    }
    
    return visibleAng>MIN_VISIBLE_ANGLE;
}


-(void) compute
{
    C=centerDistanceSquare-self.minDistance*self.minDistance;
    
    
    if(C>0)
    {
        NSPoint v=velocity;
        
        double alpha=atan2f(v.y,v.x);
        
        minimalDistance=centerDistance-self.minDistance;
        
        double tau=asinf(self.minDistance/centerDistance);
        double maximalRelativeSpeed=0;
        double rho=sqrt(v.x*v.x+v.y*v.y)/optimalSpeed;
        double relativeDirection=alpha-angle;
        
        double d=sinf(relativeDirection-tau) * rho;
        
        
        BOOL isInternal=fabs(signedNormalize(PI-relativeDirection))<=tau;
        
        
        if(isInternal)
        {
            maximalRelativeSpeed=1+rho;
        }
        else
        {
            if(fabs(d) < 1)
            {
                maximalRelativeSpeed=-rho*cosf(relativeDirection-tau)+sqrt(1-d*d);
            }
            
            d=sinf(-relativeDirection-tau) * rho;
            
            if(fabs(d)< 1)
            {
                maximalRelativeSpeed=fmax(maximalRelativeSpeed,-rho*cosf(-relativeDirection-tau)+sqrt(1-d*d));
            }
        }
        
        
        //if(agent.speed>0.3) NSLog(@"%.3f %.3f",centerDistance,maximalRelativeSpeed);
        
        if(maximalRelativeSpeed>0)
        {
            minimalDistanceToCollision=minimalDistance/maximalRelativeSpeed;
        }
        else
        {
            minimalDistanceToCollision=NO_COLLISION;
        }
        
        
        
        
    }
    else
    {
        
        
        //visibleAngle=asinf(agent.radius/centerDistance);//asinf(agentSensingMargin/centerDistance);
        
        //visibleAngle=HALF_PI;
        minimalDistance=0;
        minimalDistanceToCollision=0;
        //printf("C %.10f M %.10f\n",C,sensingMargin);
    }
}


@end


@implementation RabCache

@synthesize obstacle,lastContactTime,position;

-(void)dealloc
{
    self.obstacle=nil;
    [super dealloc];
}

@end

//Misura felicità come inv numero di scontri
//alternative with raycast
//remove threading in this simulation (use only GCD)
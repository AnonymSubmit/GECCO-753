//
//  Agent.h
//  MultiAgent
//
//  Created by Jérôme Guzzi on 10/22/10.
//  Copyright 2010 Idsia. All rights reserved.
//


#import <Foundation/Foundation.h>
#import "Wall.h"
#import "RVO/Agent.h"
#import "RVO/Vector2.h"
#import "RVO/Obstacle.h"
#import "RVO/Definitions.h"

#import "HRVO/HRVO.h"
#import "HRVO/Agent.h"


@class WorldMarker;

//#import "BulletCollision/CollisionDispatch/btGhostObject.h"

#define UNKNOWN -1
#define RES 20
#define MAX_RESOLUTION 201
#define FORCE
#define K_AGENT 1
#define K_WALL 1
#define KR 5000



#define HEIGHT 0.1
#define NO_COLLISION -2.1

#define MIN_DEADLOCK_TIME 3
#define MAX_DEADLOCK_TIME 10


typedef enum {RVO_C,HRVO_C,HUMAN_LIKE} ControlType;

typedef enum {NONE,HEADING,SPEED_AND_HEADING} interactionType;

@class ObstacleCache,RabCache;

typedef BOOL(^UpdatePathBlockType)(void);

double signedNormalize (double a);

//enum ControlType {GLOBAL,FRONT,OMNI};

double g(double x);

typedef struct sectorStructure sector;

struct sectorStructure
{
    sector *next;
    double angle;
    double distance;
};

enum sensorType {
    vision = 0,
    obstructed_vision=1,
    rab = 2
};

enum navigationState {
    freeState = 1,
    deadlockState = 0,
    assestFreeState =-1,
    assestEscapingState =-2,
    escapingDeadlock=2,
    arrivedState=3,
    follow=4
};


@class World;

//Compressione non risultante delle forze!!!!

extern BOOL strictSafety;

//emotions

#define NUMBER_OF_EMOTIONS 6

enum emotionType {
    confusion,
    fear,
    frustration,
    urgency,
    neutral,
    confort
};

enum personalityType {
    resolute,
    irresolute
};


#define EFFICACITY_TIME 10.0



@interface Agent : NSObject<NSCopying>{
    
    NSUInteger type;
    
    //state
    
    int state;
    bool isEscaping;
    double _time;
    double _stopTime;
    NSUInteger numberOfDeadlocks;
    
    
    //debug
    
#ifdef DEBUG
    BOOL debug;
    int observed;
    double oldAngle;
#endif
    
    //sensing
    
#ifdef CAMERA
    double min_th;
    double min_D;
    bool useFrontCamera;
#endif
    
    sensorType sensor;
    
    double visibilityRange,visibilityFOV;
    
    NSString *rabID;
    NSMutableDictionary *rabCacheCollection;
    NSTimeInterval rabMemoryExpiration;
    NSTimeInterval deltaTime;
    
#ifdef SENSING_ERROR
    boost::mt19937 *rng;
    double speedSensingErrorStd,positionSensingErrorStd;
    double rangeErrorStd,bearingErrorStd;
    boost::variate_generator<boost::mt19937&, boost::normal_distribution<> > *errorDistribution;
#endif
    
    //control
    
    ControlType control;
    
    NSUInteger resolution;
    double optimalSpeed,aperture,tau,horizon,eta;
    
    //eta = SECURE_TIME
    
    double socialMargin,safetyMargin;
    double controlUpdatePeriod;
    
    double minDistanceToTarget;
    NSPoint effectiveTarget;
    
    
    double distanceCache[MAX_RESOLUTION];
	double staticDistanceCache[MAX_RESOLUTION];
    NSInteger steps;
    BOOL on;
    double effectiveHorizon;
    BOOL useEffectiveHorizon;
    NSPoint desideredVelocity;
    double desideredAngle;
    
    
#ifdef USE_BULLET_FOR_SENSING
    btCollisionObject* horizonObject;
#endif
    
    NSMutableArray *nearAgents;
    NSMutableArray *nearAgentsStatic;
    
#ifdef SOCIAL_FORCE
    NSPoint socialAcceleration;
#endif
    
#ifdef PREDICT_CHANGE
    double velocityChangeSamples[NUMBER_OF_CHANGE_SAMPLES];
    uint velocityChangeIndex;
    uint velocityChangeMaxIndex;
#endif
    
    
    //target
    
    UpdatePathBlockType updatePathBlock;
    
    NSPoint *path;
    NSPoint *nextPathPoint;
    NSPoint *pathEnd;
    double pathMargin;
    NSPoint target;
    
    NSPoint sensedTarget;
    
    double targetAngle;
    double targetDistance;
    double targetAbsoluteAngle;
    NSArray *pathMarkers;
    NSUInteger currentPathMarkerIndex;
    WorldMarker *currentPathMarker;
    
    
    NSUInteger targetNumber;
    
    
    interactionType interaction;
    
    // BOOL targetIsInteractive;
    //physics
    
    double radius,mass;
    BOOL hasHit;
    uint numberOfHits;
    double dt;
    
#ifdef USE_BULLET_FOR_COLLISION
    btCollisionObject* collisionObject;
#endif
    NSMutableSet *agentsAtContact;
    NSMutableSet *agentsNowAtContact;
    
    //mobility
    
    NSPoint position;
    double angle;
    NSPoint velocity;
    double speed;
    
    
    
    
    //performance
    
    NSUInteger numberOfReachedTargets;
    double deviation,efficacity,compression,work;
    
    double meanEfficacity,cumulatedEfficacity,numberOfEfficacityMeasures;
    
#ifdef TRACK_ACCELERATION
    NSPoint acceleration;
#endif
    
    
    
    NSTimeInterval lastTimeAtTarget;
    
    //smoothness (rotations)
    double cumulatedRotation,previousCumulatedRotation,throughputEfficiency,minimalRotationToTarget,cumulatedExtraRotation,minimalPathDuration,pathDuration,minimalTimeToTarget,deadlockRotation,minimalPathLength,minimalLengthToTarget,rotation;
    
    
    // a measure of smoothness could be comulatedRotation/pathLength
    
    //smoothness (acceleration)
    
    //energy=\int H(<a,dx>) = \int H(<a,v>)dt
    
    // <a,v>=(v_l)'v_l if v=(v_l cos(alpha),v_l sin(alpha))  [diff geometry for ICT :-|]
    
    // => energy=\int H((v_l)') dt = \sum (delta v_l) vl
    
    //DOES NOT take into account rotational kinetic energy, just that of the center of mass
    
    double energy;
    
    //total length of path, take into account movement due to collisions
    
    double pathLength;
    double cumulatedPathLength;
    double previousPathLength;
    
    //=> other measure of smoothness/efficiency is energy/pathLength;
    
    double minimalDistanceToAgent;
    
    //profiling
    
    NSTimeInterval controlUpdateTime;
    
    
    //RVO
    
    RVO::Agent *RVOAgent;
    
    double timeHorizon;
    double timeHorizonStatic;
    

    
    std::vector<const RVO::Agent*> agentNeighbors;
    
    //HRVO
    
    
    HRVO::Agent *HRVOAgent;
    
    
    
    
    //NEW safetyAcceleration
    
    NSPoint safetyAcceleration;
    double safetyPenality;
    
    
    //Deadlocks
    
    BOOL shouldEscapeDeadlocks;
    BOOL shouldDetectDeadlocks;
    
    //Emotions
    
    double emotionActivation[NUMBER_OF_EMOTIONS];
    double emotionHighThrehold[NUMBER_OF_EMOTIONS];
    double emotionLowThrehold[NUMBER_OF_EMOTIONS];
    NSInteger emotionModulationIsActive;
    BOOL shouldShowEmotion;
    emotionType currentEmotion;
    double confusionThreshold;
    personalityType personality;
    
    double microStateEfficacity;
    
    double baseAperture;
    double baseEta;
    double baseSafetyMargin;
    double baseOptimalSpeed;
    
    double escapeThreshold;
    double baseVisibilityRange;
    double baseVisibilityFOV;
    
    double targetSensingQuality;
}

-(void)startControl;
extern double escapeThreshold;

@property double targetSensingQuality;

@property personalityType personality;
@property emotionType currentEmotion;
@property BOOL shouldShowEmotion;
@property double escapeThreshold;
@property NSInteger emotionModulationIsActive;

@property BOOL shouldEscapeDeadlocks,shouldDetectDeadlocks;


#ifdef DISPATCH
+(dispatch_queue_t)controlQueue;
+(dispatch_queue_t)rabQueue;
#endif


//init
-(void)reset;
-(Agent *)initAtPosition:(NSPoint)p;;
@property NSUInteger type;
@property int state;
@property bool isEscaping;
@property NSUInteger numberOfDeadlocks;
//debug
#ifdef DEBUG
@property BOOL debug;
@property double oldAngle;
@property int observed;
#endif
//sensing

@property sensorType sensor;
@property double visibilityRange;
@property double visibilityFOV;
@property (copy) NSString *rabID;
#ifdef SENSING_ERROR
@property double speedSensingErrorStd,positionSensingErrorStd,rangeErrorStd,bearingErrorStd;
#endif
@property (retain) NSMutableArray *nearAgentsStatic;
#ifdef RAB
+(NSMutableDictionary*)rabMessages;
#endif

//emotions
-(void)updateEmotion;
-(void)updateEmotionalModulation;
-(void)publishEmotionMessage;
+(NSMutableDictionary *)emotionMessages;


@property NSTimeInterval rabMemoryExpiration;


//control
@property BOOL on;
@property ControlType control;
#ifdef USE_BULLET_FOR_SENSING
@property (readonly) btCollisionObject *horizonObject;
#endif
-(void) updateControl;
-(void)updateTarget;
-(void)updateSensing;
-(void)setTargetSpeed:(double)tSpeed andTargetAngle:(double)tAngle;
-(void)setRelativePosition:(NSPoint)p ofObstacle:(ObstacleCache *)obstacle;

#ifdef SOCIAL_FORCE
@property NSPoint socialAcceleration;
-(void)updateSocialAcceleration;
#endif

@property double socialMargin,safetyMargin;

@property double optimalSpeed,aperture,tau,controlUpdatePeriod,horizon,eta;
@property double effectiveHorizon,desideredAngle,minDistanceToTarget;
@property BOOL useEffectiveHorizon;

@property NSPoint effectiveTarget,desideredVelocity;
@property NSUInteger resolution;
-(int) indexOfRelativeAngle:(double)relativeAngle;
//target
-(BOOL)hasReachedTarget;
-(void)setPathWithRadius:(CGFloat) radius center:(NSPoint)c segments:(NSUInteger)n;
-(void)setPathWithRadius:(CGFloat) radius center:(NSPoint)c segments:(NSUInteger)n direction:(int)dir;
-(void)setPath:(NSString *)s;
-(void)setPathWithPoint:(NSPoint) point;

-(void)setPathWithMarkers:(NSArray *)markers;


-(void)advancePath:(NSUInteger) steps;
-(void)goToTheNearestPoint;
@property NSPoint target;
@property double pathMargin;
@property double targetAbsoluteAngle;
@property interactionType interaction;

@property (nonatomic, retain) NSArray *pathMarkers;
@property (nonatomic, assign) WorldMarker *currentPathMarker;
@property NSUInteger targetNumber;
@property (nonatomic, copy) UpdatePathBlockType updatePathBlock;
//physics

-(void)resolveCollisionWith:(id)object;
-(void)resolveCollisionWithAgent:(Agent *)agent;
-(void)resolveCollisionWithWall:(Wall *)wall;
-(void)advanceTimeByStep:(NSTimeInterval)dt;
+(btCollisionShape *)collisionShape;
-(void)update;
-(void)updatePosition;
-(void)updateCollisions;
-(void)updateHitCount;
-(void)applyContactForce:(NSPoint) dx penetration:(double)diff;
#ifdef USE_BULLET_FOR_COLLISION
@property (readonly) btCollisionObject *collisionObject;
#endif
@property double radius,mass;
@property BOOL hasHit;
@property uint numberOfHits;
//mobility

@property NSPoint position,velocity;
@property double angle,speed;

//performance



@property double cumulatedPathLength,pathDuration,throughputEfficiency,pathLength,energy,cumulatedExtraRotation,cumulatedRotation,minimalDistanceToAgent,deadlockRotation,minimalPathLength;


#ifdef TRACK_ACCELERATION
@property NSPoint acceleration;
-(void)updateAcceleration;
#endif

@property double work,deviation,efficacity,meanEfficacity,compression;
@property NSUInteger numberOfReachedTargets;
//profiling

@property NSTimeInterval controlUpdateTime;

-(void)updateDesideredVelocity;

//RVO

-(void)setupRVOAgent;
-(void)computeRVOObstacles;
-(void)updateDesideredVelocityWithRVO;
@property (readonly) RVO::Agent *RVOAgent;
@property double timeHorizon,timeHorizonStatic;


//HRVO

-(void)computeHRVOObstacles;
-(void)updateDesideredVelocityWithHRVO;
@property (readonly) HRVO::Agent *HRVOAgent;

@end





@interface ObstacleCache : NSObject
{
    double angle,visibleAngle,C,minimalDistance,minimalDistanceToCollision,visibleDistance,centerDistance,penetration,agentSensingMargin,sensingMargin,optimalSpeed,socialMargin,centerDistanceSquare,minDistance,relativeAngle;
    NSPoint velocity,relativePosition,position;
    Agent *agent;
}

@property (nonatomic) double angle,visibleAngle,C,minimalDistance,minimalDistanceToCollision,visibleDistance,centerDistance,penetration,agentSensingMargin,sensingMargin,optimalSpeed,socialMargin,centerDistanceSquare,minDistance,relativeAngle;
@property (nonatomic) NSPoint velocity,relativePosition,position;
@property (nonatomic,assign) Agent *agent;

-(BOOL)visibleInSector:(sector *)se atAngle:(double)alpha;

-(double)distanceToCollisionWhenMovingInDirection:(double)alpha;
-(double)distanceToCollisionInDirection:(double)alpha;
-(void)compute;
@end


//I had explicit ivars because if not Gnustep would not compile

@interface RabCache : NSObject
{
    ObstacleCache* obstacle;
    NSTimeInterval lastContactTime;
    NSPoint position;
}

@property (nonatomic,retain) ObstacleCache* obstacle;
@property (nonatomic) NSTimeInterval lastContactTime;
@property (nonatomic) NSPoint position;


@end



#define MIN_C 0.00001f








//
//  Footbot.m
//  MultiAgent
//
//  Created by Jérôme Guzzi on 4/4/11.
//  Copyright 2011 Idsia. All rights reserved.
//

#import "Footbot.h"
#import "Human.h"

static double relax(double x0,double x1, double tau,double dt);

@implementation Footbot

@synthesize speedLeft,speedRight,angularSpeed,positionRight,positionLeft,rotationTau,maxRotationSpeed,maxSpeed,wheelAxis;


#ifdef RVO_HOLO
@synthesize D,useHolonomicContraints;
#endif

BOOL footbotAreDumby=NO;

- (id)copyWithZone:(NSZone *)zone
{
    Footbot *copy = [super copyWithZone:zone];
    
    copy.rotationTau=self.rotationTau;
    copy.maxSpeed=self.maxSpeed;
    copy.maxRotationSpeed=fmin(self.maxRotationSpeed,self.maxSpeed);
    copy.wheelAxis=self.wheelAxis;
#ifdef RVO_HOLO
    copy.useHolonomicContraints=self.useHolonomicContraints;
    copy.D=self.D;
#endif
    return copy;
}


- (id)init
{
    self = [super init];
    if (self) {
        speedLeft=0;
        speedRight=0;
        angularSpeed=0;
        maxRotationSpeed=0.1;
        rotationTau=0.5;
        linearSpeedIsContinuos=NO;
        positionRight=0;
        positionLeft=0.3;
        
        wheelAxis=WHEEL_AXIS_FOOTBOTS;
        maxSpeed=MAX_SPEED_FOOTBOTS;
        
#ifdef RVO_HOLO
        useHolonomicContraints=YES;
        D=wheelAxis*0.5;
#endif
        // Initialization code here.
    }
    return self;
}

#ifdef RVO_HOLO
-(void)setDefaultHolonomicDistance
{
    D=wheelAxis*0.5;
}
#endif


-(void)setWheelSpeedLeft:(double)lSpeed andRight:(double)rSpeed
{
    if(lSpeed>maxSpeed) speedLeft=maxSpeed;
    else if(lSpeed<-maxSpeed) speedLeft=-maxSpeed;
    else speedLeft=lSpeed;
    
    if(rSpeed>maxSpeed) speedRight=maxSpeed;
    else if(rSpeed<-maxSpeed) speedRight=-maxSpeed;
    else speedRight=rSpeed;
    
    
    double previousSpeed=speed;
    
    
    speed=0.5*(speedLeft+speedRight);
    angularSpeed=(speedRight-speedLeft)/wheelAxis;
    
    energy+=g(0.5*(speed+previousSpeed)*(speed-previousSpeed));
}

static double relax(double x0,double x1, double tau,double dt)
{
    return exp(-dt/tau)*(x0-x1)+x1;
}




-(void)setTargetSpeed:(double)tSpeed andTargetAngle:(double)tAngle
{
#ifdef DEBUG
    oldAngle=angle;
#endif
    tAngle=signedNormalize(tAngle);
    desideredAngle=tAngle+angle;
    
    double targetLinearSpeed=0;
    double targetAngularSpeed=(1.0/rotationTau)*tAngle*0.5*wheelAxis;
    
    if(targetAngularSpeed>maxRotationSpeed)
    {
        targetAngularSpeed=maxRotationSpeed;
    }
    else if(targetAngularSpeed<-maxRotationSpeed)
    {
        targetAngularSpeed=-maxRotationSpeed;
    }
    else
    {
        if(linearSpeedIsContinuos)
        {
            targetLinearSpeed=tSpeed*(1-fabs(targetAngularSpeed)/maxRotationSpeed);
        }
        else
        {
            targetLinearSpeed=tSpeed;
        }
    }
    
#ifdef ANGULAR_SPEED_DOMINATE
    
    if(fabs(targetLinearSpeed) + fabs(targetAngularSpeed) > maxSpeed)
    {
        //printf("%.2f - %.2f\n",targetLinearSpeed,targetAngularSpeed);
        if(targetLinearSpeed<0)
        {
            
            targetLinearSpeed=-maxSpeed+fabs(targetAngularSpeed);
        }
        else
        {
            targetLinearSpeed=maxSpeed-fabs(targetAngularSpeed);
        }
    }
    
    
#endif
    
    //printf("%.2f (%.2f) , %.2f ",targetLinearSpeed,tSpeed,targetAngularSpeed);
    
    
    double targetSpeedLeft,targetSpeedRight;
    if(control==HUMAN_LIKE && tau>0)
    {
        targetSpeedLeft=relax(speedLeft, targetLinearSpeed-targetAngularSpeed, tau, controlUpdatePeriod);
        targetSpeedRight=relax(speedRight, targetLinearSpeed+targetAngularSpeed, tau, controlUpdatePeriod);
    }
    else
    {
        targetSpeedLeft=targetLinearSpeed-targetAngularSpeed;
        targetSpeedRight=targetLinearSpeed+targetAngularSpeed;
    }
    //printf("-> %.2f , %.2f\n",targetSpeedLeft,targetSpeedRight);
    
    [self setWheelSpeedLeft:targetSpeedLeft andRight:targetSpeedRight];
}


-(void)update
{
    [self updatePosition];
    angle+=angularSpeed*dt;
    
    cumulatedRotation+=fabs(angularSpeed*dt);
    
    if(state==deadlockState && shouldEscapeDeadlocks) deadlockRotation+=fabs(angularSpeed*dt);
    
    positionLeft+=speedLeft*dt;
    positionRight+=speedRight*dt;
    
    velocity=NSMakePoint(speed*cosf(angle),speed*sinf(angle));
    
    [self updateCollisions];
    
    
    if(speed>0)
    {
        self.efficacity=cos(atan2(velocity.y,velocity.x)-targetAngle-angle)*speed/optimalSpeed;
    }
    else
    {
        self.efficacity=0;
    }
    
}





//Interpolate between safety and social margin


-(void)setRelativePosition:(NSPoint)p ofObstacle:(ObstacleCache *)obstacle withSocialMargin:(double)m
{
    double socialMargin2=m;
    
    double distanceSquare=p.x*p.x+p.y*p.y;
    double distance=sqrt(distanceSquare);
    
    //double safetyMargin=0.1; //could depend on type of obstacle
    //double socialMargin=socialMargin*0.01;//0.2; //should depend on type of obstacle
    double farMargin=1;
    
    double margin;
    
    double distanceToBeSeparated=safetyMargin+radius+obstacle.agent.radius;
    double distanceToBeFar=farMargin+radius+obstacle.agent.radius;
    
    
    if(distance<distanceToBeSeparated)
    {
        margin=safetyMargin;
        obstacle.visibleAngle=PI/2;
        
        //double a=atan2f(p.y,p.x);
        
        //NSLog(@"%.2f %.2f",p.x,p.y);
        
        //NEW SAFETY ACCELERATION
        //safetyAcceleration.x-=cos(a);
        //safetyAcceleration.y-=sin(a);
        
        
    }
    else if(distance>distanceToBeFar)
    {
        margin=socialMargin2;
    }
    else
    {
        margin=(socialMargin2-safetyMargin)/(distanceToBeFar - distanceToBeSeparated ) * (distance - distanceToBeSeparated)+ safetyMargin;
    }
    
    obstacle.angle=atan2f(p.y,p.x);
    obstacle.relativePosition=p;
    obstacle.centerDistance=distance;
    obstacle.centerDistanceSquare=distanceSquare;
    
    obstacle.sensingMargin=margin;
    obstacle.minDistance=radius+obstacle.agent.radius+margin;
    
    obstacle.agentSensingMargin=obstacle.agent.radius+obstacle.sensingMargin;
    
    
}

-(void)setRelativePosition:(NSPoint)p ofObstacle:(ObstacleCache *)obstacle
{
    [self setRelativePosition:p ofObstacle:obstacle withSocialMargin:socialMargin];
}

//Just one margin (safety)

-(void)setRelativePosition1:(NSPoint)p ofObstacle:(ObstacleCache *)obstacle
{
    double distanceSquare=p.x*p.x+p.y*p.y;
    double distance=sqrt(distanceSquare);
    
    
    double distanceToBeSeparated=safetyMargin+radius+obstacle.agent.radius;
    
    
    if(distance<distanceToBeSeparated)
    {
        obstacle.visibleAngle=PI/2;
    }
    
    obstacle.angle=atan2f(p.y,p.x);
    obstacle.relativePosition=p;
    obstacle.centerDistance=distance;
    obstacle.centerDistanceSquare=distanceSquare;
    
    obstacle.sensingMargin=safetyMargin;
    obstacle.minDistance=distanceToBeSeparated;
    
    
    
    
}


/*
 -(void)setRelativePosition:(NSPoint)p ofObstacle:(ObstacleCache *)obstacle
 {
 double distanceSquare=p.x*p.x+p.y*p.y;
 double distance=sqrt(distanceSquare);
 double minFreeDistance=0.000;
 
 double r=obstacle.agent.radius;
 double minDistance=r+radius+minFreeDistance;
 
 
 
 if(distance<minDistance)
 {
 //too near, two footbots con not compenetrate
 
 p=NSMakePoint(p.x/distance*minDistance, p.y/distance*minDistance);
 distance=minDistance;
 distanceSquare=minDistance*minDistance;
 }
 
 obstacle.angle=atan2f(p.y,p.x);
 obstacle.relativePosition=p;
 obstacle.centerDistance=distance;
 obstacle.centerDistanceSquare=distanceSquare;
 
 
 double freeDistance=distance-radius-r;
 double maxMargin=2*socialMargin*0.01;
 double minMargin=0.02;//minFreeDistance;
 
 double margin;
 
 double k=1.2; //k>=1,
 //k=1: no penetration, i.e. free distance by dist<r+radius+2*socialMargin: epsilon => stop by social radius.
 //k=inf: full penetration, i.e. margin by dist>r+radius+minMargin: minMargin => ignore socialMargin, just respect minMargin.
 double maxFreeDistance=minMargin+k*(maxMargin-minMargin);
 
 //freeDistance->freeDistance-margin
 
 if(freeDistance>maxFreeDistance)
 {
 margin=maxMargin;
 }
 else if(freeDistance<minMargin)
 {
 margin=freeDistance-minFreeDistance;
 //margin=minMargin;
 }
 else
 {
 //continuous linear interpolation
 
 margin=(freeDistance-minMargin)/(maxFreeDistance-minMargin)*(maxMargin-minMargin-minFreeDistance)+minMargin-minFreeDistance;
 }
 
 obstacle.sensingMargin=r+radius+margin;
 
 //if(debug)//freeDistance-margin<0)
 //{
 //   printf("%.4f %.4f \n %.4f %.4f %.4f %.4f\n",freeDistance,margin,minFreeDistance,maxFreeDistance,maxMargin,minMargin);
 //}
 
 //distance-sensingMargin=distance-r-radius-margin=freeDistance-margin
 
 [obstacle compute];
 }
 */


/*
 -(void)setRelativePosition:(NSPoint)p ofObstacle:(ObstacleCache *)obstacle
 {
 double distanceSquare=p.x*p.x+p.y*p.y;
 double distance=sqrt(distanceSquare);
 
 
 double r=obstacle.agent.radius;
 double minDistance=r+radius+0.002;
 
 if(distance<minDistance)
 {
 //too near, two footbots con not compenetrate
 
 p=NSMakePoint(p.x/distance*minDistance, p.y/distance*minDistance);
 distance=minDistance;
 }
 
 obstacle.angle=atan2f(p.y,p.x);
 obstacle.relativePosition=p;
 obstacle.centerDistance=distance;
 obstacle.centerDistanceSquare=distanceSquare;
 
 
 if(socialMargin*0.02>(distance-minDistance))
 {
 obstacle.agentSensingMargin=r+(distance-minDistance)*0.5;
 double mySensingMargin=radius+(distance-minDistance)*0.5;
 obstacle.sensingMargin=obstacle.agentSensingMargin+mySensingMargin;
 }
 else
 {
 obstacle.agentSensingMargin=r+socialMargin*0.01;
 obstacle.sensingMargin=r+radius+socialMargin*0.02;
 }
 
 
 //    obstacle.agentSensingMargin=r+socialMargin*0.01;
 //   obstacle.sensingMargin=r+radius+socialMargin*0.02;
 
 // [obstacle compute];
 }
 */

//Modello dell'errore di Alessandro
/*
 The observed position (ρ′,θ′) is given by θ′ = θ+φe; ρ′ = ρ+ρkφe, where: e ∼ N (0, σ) models the localization error in normal- ized image space, φ denotes the camera field of view, and k is a constant depending on the characteristics of the depth estimation approach; in the following, we set σ = 1/128 (i.e. 1 pixel on a 128×96 sensor) and k = 10,
 */




-(void) senseObstacleWithVision:(ObstacleCache *)obstacle
{
    NSPoint p,v;
    
    v=obstacle.agent.velocity;
    p=obstacle.relativePosition;
    
    
#ifdef SENSING_ERROR
    if(positionSensingErrorStd)
    {
        double visionErrorStd=positionSensingErrorStd;
        double theta=obstacle.angle;
        double rho=obstacle.centerDistance;
        
        
        //velocity error
        double d_theta=visibilityFOV*(*errorDistribution)()*visionErrorStd;
        double d_rho=rho*VISION_K*self.visibilityFOV*(*errorDistribution)()*visionErrorStd;
        
        //dx=x(\rho+d\rho,\theta+d\theta)-x(\rho,\theta)= d\rho e1(\theta)+ d\theta \rho e2(\theta)
        //dv=\fract{1}{10}
        
        
        v.x+=VELOCITY_ERROR_FACTOR*(cosf(theta)*d_rho-sinf(theta)*rho*d_theta);
        v.y+=VELOCITY_ERROR_FACTOR*(sinf(theta)*d_rho+cosf(theta)*rho*d_theta);
        
        //position error
        
        theta+=visibilityFOV*(*errorDistribution)()*visionErrorStd;
        rho+=rho*VISION_K*self.visibilityFOV*(*errorDistribution)()*visionErrorStd;
        
        p=NSMakePoint(rho*cosf(theta), rho*sinf(theta));
        
    }
#endif
    
    obstacle.velocity=v;
    [self setRelativePosition:p ofObstacle:obstacle];
}


-(void)updateDesideredVelocity
{
    if(footbotAreDumby)
    {
        for(ObstacleCache *obstacle in nearAgentsStatic)
        {
            if([obstacle.agent isKindOfClass:[Human class]] && obstacle.minimalDistance<1)
            {
                [self setTargetSpeed:0 andTargetAngle:0];
                return;
            }
            
        }
    }
    
    [super updateDesideredVelocity];
    
}

#ifdef RVO_HOLO
-(void)setupRVOAgent
{
    if(!useHolonomicContraints)
    {
        [super setupRVOAgent];
        return;
    }
    
    
    RVOAgent->velocity_=RVO::Vector2(velocity.x,velocity.y);
    
    //See [1] J. Snape, J. van den Berg, S. J. Guy, and D. Manocha, “Smooth and collision-free navigation for multiple robots under differential-drive constraints,” in 2010 IEEE/RSJ International Conference on Intelligent Robots and Systems, 2010, pp. 4584–4589. with D=L/2
    
    //D=WHEEL_AXIS/2;
    
    RVO::Vector2 delta=RVO::Vector2(cosf(angle),sinf(angle))*D;
    RVOAgent->position_=RVO::Vector2(position.x,position.y)+delta;
    RVOAgent->radius_=radius+D;
    
    
    RVOAgent->maxNeighbors_=1000;
    RVOAgent->maxSpeed_=maxSpeed/sqrt(1+RVO::sqr(0.5*wheelAxis/D));
    
    shouldEscapeDeadlocks=NO;
    
    RVOAgent->timeStep_=controlUpdatePeriod;
}


-(void)updateDesideredVelocityWithRVO
{
    if(!useHolonomicContraints)
    {
        [super updateDesideredVelocityWithRVO];
        return;
    }
    
    RVO::Vector2 targetPosition=RVO::Vector2(target.x,target.y)-RVOAgent->position_;
    
    RVOAgent->prefVelocity_=targetPosition*optimalSpeed/abs(targetPosition);
    RVOAgent->computeNewVelocity();
    
    double tAngle=signedNormalize(atan2(RVOAgent->newVelocity_.y(), RVOAgent->newVelocity_.x())-angle);
    double newTargetSpeed=abs(RVOAgent->newVelocity_);
    
    //only if D=L/2
    //[self setWheelSpeedLeft:sqrt(2)*newTargetSpeed*sin(PI/4.0-tAngle) andRight:sqrt(2)*newTargetSpeed*sin(PI/4.0+tAngle)];
    //else
    [self setWheelSpeedLeft:newTargetSpeed*(cosf(tAngle)-wheelAxis*0.5/D*sinf(tAngle)) andRight:newTargetSpeed*(cosf(tAngle)+wheelAxis*0.5/D*sinf(tAngle))];
}
#endif


@end


@implementation SocialFootbot

@synthesize wellness;//,baseEta;

@synthesize kEta,kSpeed,kAperture;
@synthesize modulateEta,modulateSpeed,modulateAperture,modulateSM;

-(void)setRelativePosition:(NSPoint)p ofObstacle:(ObstacleCache *)obstacle
{
    double m=socialMargin;
    if(modulateSM && obstacle.agent.type==type) m=safetyMargin;
    [self setRelativePosition:p ofObstacle:obstacle withSocialMargin:m];
}


-(void)updateEta
{
    //eta=baseEta+fmin(15,fmax(0,kEta*wellness));
    
    eta=fmax(baseEta,fmin(15,baseEta-kEta*wellness));
    
    //if(debug)printf("ETA: %.2f -> %.2f\n",wellness,eta);
}

-(void)updateOptimalSpeed
{
    optimalSpeed=fmin(0.3,fmax(0.1,0.3+kSpeed*wellness));
    
    //printf("SPEED: %.2f + %.2f -> %.2f\n",wellness,kSpeed,optimalSpeed);
    
    //if(debug)printf("ETA: %.2f -> %.2f\n",wellness,eta);
}

-(void)updateAperture
{
    aperture=1-fmin(0.85,fmax(0,kAperture*wellness));
    //if(debug)printf("FOV: %.2f -> %.2f\n",wellness,aperture);
}

/*
 -(double)eta
 {
 //printf("%.2f - %.2f\n",wellness,tau+fmax(0,eta*(1-wellness)));
 //return tau+fmax(0,eta*(1-wellness));
 if(debug)printf("%.2f - %.2f -> %.3f\n",wellness,eta+fmin(30,fmax(0,-30*wellness)),speed);
 
 return eta+fmin(10,fmax(0,30*wellness));
 }
 
 -(void)setEta:(double)e
 {
 eta=e;
 }
 */


double groupSize=2.0;

-(void)updateWellness
{
    wellness=0;
    double k=0;
    double d_group=groupSize;//2.0;
    double d;
    for(ObstacleCache *obstacle in nearAgentsStatic)
    {
        [obstacle compute];
        Agent *a=obstacle.agent;
        
        d=obstacle.visibleDistance-radius;
        
        if(a.type==type) k=1.0;
        else k=-1.0;
        
        wellness+=k*exp(-d/d_group);
    }
    
    wellness/=6.0; //so it should be normed between -1 and 1 (close packed spheres -> 6 neighbords
    
    if(modulateEta) [self updateEta];
    if(modulateAperture)[self updateAperture];
    if(modulateSpeed)[self updateOptimalSpeed];
    
    
}

-(void)updateSensing
{
    [super updateSensing];
    [self updateWellness];
}

- (id)copyWithZone:(NSZone *)zone
{
    SocialFootbot *copy = [super copyWithZone:zone];
    
    //copy.baseEta=self.eta;
    
    copy.modulateAperture=self.modulateAperture;
    copy.modulateEta=self.modulateEta;
    copy.modulateSpeed=self.modulateSpeed;
    copy.modulateSM=self.modulateSM;
    
    copy.kSpeed=self.kSpeed;
    copy.kEta=self.kEta;
    copy.kAperture=self.kAperture;
    
    return copy;
}

- (id)init
{
    self = [super init];
    if (self) {
        modulateAperture=modulateEta=modulateSpeed=modulateSM=NO;
        kSpeed=0.2;//0.1;
        kAperture=0.2;
        kEta=30;
        //modulateEta=YES;
        //modulateSM=YES;
        modulateSpeed=YES;
    }
    return self;
}



@end


@implementation myopicAgent

-(id) init
{
    self=[super init];
    
    targetHeadingError=0.5;
    targetSensingQuality=1.0;
    return self;
}

-(id)copyWithZone:(NSZone *)zone
{
    myopicAgent *copy = [super copyWithZone:zone];
    copy.targetHeadingError=self.targetHeadingError;

    return copy;
}

-(myopicAgent *)initAtPosition:(NSPoint)p
{
    self=[super initAtPosition:p];
    //targetHeadingError=0.5;//0.02*rand()/RAND_MAX;//0.5*PI*rand()/RAND_MAX;
    //NSLog(@"%.3f",targetHeadingError);
    targetSensedOneTime=NO;
    return self;
}


@synthesize targetHeadingError;


-(NSPoint) senseTargetWithVision:(NSPoint)t
{
    
    if(!targetSensedOneTime)
    {
        targetSensedOneTime=YES;
        sensedTargetPosition=target;
    }
    
    if(state==freeState)
    {
        if(rand()/(double) RAND_MAX > targetSensingQuality)
        {
            double d=rand()/(double)RAND_MAX*3+3;
            double a=angle-visibilityFOV+visibilityFOV*2.0*rand()/(double)RAND_MAX;
            sensedTargetPosition.x=sensedTargetPosition.x*0.8+0.2*(position.x+cos(a)*d);
            sensedTargetPosition.y=sensedTargetPosition.y*0.8+0.2*(position.y+sin(a)*d);
        }
        else
        {
            sensedTargetPosition.x=sensedTargetPosition.x*0.8+0.2*(target.x);
            sensedTargetPosition.y=sensedTargetPosition.y*0.8+0.2*(target.y);
        }
       
        return sensedTargetPosition;
    }
    else{
        return t;
    }
}

-(NSPoint) senseTargetWithVision2:(NSPoint)t
{
    
    if(!targetSensedOneTime)
    {
        targetSensedOneTime=YES;
        sensedTargetPosition=target;
    }
    
    if(state==freeState)
    {
        //if(fmod(_time,1)<0.09 )
        //{
        
        
        double d=sqrt((target.x-position.x)*(target.x-position.x)+(target.y-position.y)*(target.y-position.y));
        double a=atan2((target.y-position.y), (target.x-position.x));
        
        //printf("%.3f ->",a);
        
        d+=fabs((*errorDistribution)()*d/2);
        
      
        a+=(*errorDistribution)()*targetHeadingError;
        
        //  printf("%.3f \n",a);
        
        sensedTargetPosition.x=sensedTargetPosition.x*0.5+0.5*(position.x+cos(a)*d);
        sensedTargetPosition.y=sensedTargetPosition.y*0.5+0.5*(position.y+sin(a)*d);
        return sensedTargetPosition;
    }
    else{
        return t;
    }
}



-(NSPoint) senseTargetWithVision1:(NSPoint)t
{
    
    if(!targetSensedOneTime)
    {
        targetSensedOneTime=YES;
        sensedTargetPosition=target;
    }
    
    if(state==freeState)
    {
        //if(fmod(_time,1)<0.09 )
        //{
        
        double d=2+5.0*rand()/RAND_MAX;
        //double a=2.0*visibilityFOV*rand()/RAND_MAX-visibilityFOV;
        
        double a=PI*rand()/RAND_MAX-PI/2;
        
        
        sensedTargetPosition.x=sensedTargetPosition.x*0.99+0.01*(position.x+cos(a+angle)*d);
        sensedTargetPosition.y=sensedTargetPosition.y*0.99+0.01*(position.y+sin(a+angle)*d);
         //   double alpha=atan2(-position.y+t.y,-position.x+t.x);
            //double newTargetAngle=(*errorDistribution)()*targetHeadingError+alpha;
          //  double newTargetAngle=targetHeadingError+alpha;
          //  double newDistance=3;
          //  sensedTargetPosition=NSMakePoint(position.x+cos(newTargetAngle)*newDistance, position.y+sin(newTargetAngle)*newDistance);
            //NSMakePoint(position.x+cos(newTargetAngle)*newDistance, position.y+sin(newTargetAngle)*newDistance);
        //}
       // if(sensedTargetPosition.x==sensedTargetPosition.y) sensedTargetPosition=t;
       // sensedTargetPosition=NSMakePoint(sensedTargetPosition.x+fabs(targetHeadingError*(*errorDistribution)()), sensedTargetPosition.y+fabs(targetHeadingError*(*errorDistribution)()));
        return sensedTargetPosition;
    }
    else{
        return t;
    }
}

-(double) senseTargetAngleWithVision:(double)t
{
    if(state==freeState)
    {
        //NSLog(@".");
        if(fmod(_time,1)<0.09 )
        {
            double newTargetAngle=signedNormalize((*errorDistribution)()*targetHeadingError);
            double newDistance=3;//(*errorDistribution)();
            //target=NSMakePoint(position.x+cos(angle+newTargetAngle)*newDistance, position.y+sin(angle+newTargetAngle)*newDistance);
            return newTargetAngle;
        }
        else
        {
             
            return t;
        }
    }
    else{
        //NSLog(@"go to t %.2f",t);
        return t/2;
    }
}



-(void) updateTarget
{
    
    if(currentEmotion==confusion)
    {
        BOOL helpFound=NO;
        //NSLog(@"try to follow");
        //state=freeState;
        
        
        
        for (NSString *senderId in [Agent emotionMessages])
        {
            if([senderId isEqualToString:rabID]) continue;
            NSDictionary *m=[[Agent emotionMessages] valueForKey:senderId];
            NSDictionary *helpMessage;
            

            
            if ((helpMessage=[m valueForKey:@"help"]))
            {
                if([[helpMessage valueForKey:@"to"] isEqualToString:rabID])
                {
                    NSPoint relativePosition=[[helpMessage valueForKey:@"relativePosition"] pointValue];
                    NSPoint relativeTarget=[[helpMessage valueForKey:@"relativeTarget"] pointValue];
                    
                    double w=0;//emotionActivation[confusion];
                    
                    NSPoint rT=NSMakePoint((w*relativePosition.x+(1-w)*relativeTarget.x),(w*relativePosition.y+(1-w)*relativeTarget.y));
                    
                    
                    double alpha=angle;
                    
                    target=NSMakePoint(position.x+rT.x*cos(alpha)+rT.y*sin(alpha),position.y+ rT.x*sin(-alpha)+rT.y*cos(alpha));
                    
                    //NSLog(@"R (%.2f,%.2f)  [%.2f,%.2f]",target.x,target.y,position.x,position.y
                        //  );
                    
                    

                    helpFound=YES;
                    
                   
                    
                    break;
                    
                }
            }
            
        }
        
        
        if(helpFound && state==freeState)
        {
            state=follow;
        }
        else if(!helpFound && state==follow)
        {
            state=freeState;
            [self advancePath:0];
        }
        
        
    }
    else if(state==follow)
    {
        state=freeState;
        [self advancePath:0];
    }
    
  
    
    [super updateTarget];
    
    
    
    
    if(state==freeState)
    {
        
        //simulate odometry error

        //targetHeadingError=1;//0.1*rotation; //0.05;//fmin(targetHeadingError+0.02,1);
        //NSLog(@"targetHeadingError %.3f",targetHeadingError);
        pathMargin=1;
        
    }
    else{
        sensedTargetPosition=target;
        //targetHeadingError=0;//fmax(targetHeadingError-0.01,0);
        pathMargin=1;
    }
    
}


@end


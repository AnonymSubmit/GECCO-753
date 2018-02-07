//
//  Human.m
//  MultiAgent
//
//  Created by Jérôme Guzzi on 6/26/12.
//  Copyright (c) 2012 Idsia. All rights reserved.
//

#import "Human.h"

@implementation Human


- (id)init
{
    self = [super init];
    if (self) {
        motricityCycle=0;
        motricityVelocity=NSMakePoint(0, 0);
    }
    return self;
}

static double relax(double x0,double x1, double tau,double dt)
{
    return exp(-dt/tau)*(x0-x1)+x1;
}

-(double)leftFootPosition
{
    //double alpha=0.34*cos(TWO_PI*motricityCycle+PI)+0.18;
    double alpha=-0.2*cos(TWO_PI*motricityCycle);
    return sin(alpha);
}

-(double)rightFootPosition
{
    //double alpha=0.34*cos(TWO_PI*motricityCycle)+0.18;
    double alpha=0.2*cos(TWO_PI*motricityCycle);
    return sin(alpha);
}

-(double)leftHandPosition
{
    //double alpha=0.26*cos(TWO_PI*motricityCycle)+0.09;
    double alpha=0.2*cos(TWO_PI*motricityCycle);
    return sin(alpha);
}

-(double)rightHandPosition
{
    //double alpha=0.26*cos(TWO_PI*motricityCycle+PI)+0.09;
    double alpha=-0.2*cos(TWO_PI*motricityCycle);
    return sin(alpha);
}

-(void)setTargetSpeed:(double)tSpeed andTargetAngle:(double)tAngle
{
    desideredAngle=tAngle+angle;
    desideredVelocity=NSMakePoint(tSpeed*cos(desideredAngle),tSpeed*sinf(desideredAngle));
#ifdef DEBUG
    oldAngle=angle;
#endif
}

-(void)update
{
    [self updatePosition];

    
    if(control==HUMAN_LIKE && tau>0)
    {
    
    motricityVelocity.x=relax(motricityVelocity.x, desideredVelocity.x, tau, dt);
    motricityVelocity.y=relax(motricityVelocity.y, desideredVelocity.y, tau, dt);
    }
    else
    {
        motricityVelocity=desideredVelocity;
    }
    
    double motricitySpeed=sqrt(motricityVelocity.x*motricityVelocity.x+motricityVelocity.y*motricityVelocity.y);
    
    double previousSpeed=speed;
    double previousAngle=angle;
    
    //if(motricityVelocity.x || motricityVelocity.y)
    if(motricitySpeed>0.06)
    {
        //double motricityPeriod=4.0*radius/sqrt(motricityVelocity.x*motricityVelocity.x+motricityVelocity.y*motricityVelocity.y);
        //motricityCycle+=dt/motricityPeriod;
        motricityCycle+=dt*sqrt(motricityVelocity.x*motricityVelocity.x+motricityVelocity.y*motricityVelocity.y)/8.0/radius;
        while(motricityCycle>1) motricityCycle-=1.0;
        
        angle=atan2(motricityVelocity.y, motricityVelocity.x);
        self.velocity=motricityVelocity;
    }
    else
    {
        angle=relax(angle, desideredAngle, tau, dt);
        self.velocity=NSMakePoint(0, 0);
    }

    energy+=g(0.5*(speed+previousSpeed)*(speed-previousSpeed));
    cumulatedRotation+=fabs(angle-previousAngle);
    
    if(state==deadlockState && shouldEscapeDeadlocks) deadlockRotation+=fabs(angle-previousAngle);
    
    // velocity to be modified by collision forces
    
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

@end


@implementation CarefulHuman


BOOL humanStopped=NO;

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




@end

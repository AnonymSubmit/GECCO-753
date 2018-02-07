//
//  General.h
//  MultiAgent
//
//  Created by Jérôme Guzzi on 6/27/11.
//  Copyright 2011 Idsia. All rights reserved.
//



#ifndef GENERAL 
#define GENERAL



#define CACHE_MEMORY

//global variables

extern double ratioOfSocialRadiusForSensing;
extern double socialRepulsion;
extern double rabReliability;
extern NSUInteger rabMessageNumber;

#define PI 3.1415926536
#define TWO_PI 6.2831853072
#define HALF_PI 1.570796326



#ifdef DISPATCH
//
#endif

//statistics
/*
#ifdef PREDICT_CHANGE
#define NUMBER_OF_CHANGE_SAMPLES 20
#endif
 */

//physics

#define RELAXED_ACCELERATION //=/tau < /infinity
//con RELAXED_ACC meno ordinato nella doppia linea
//Più ordinato con doppia linea, più ordinato anche se updateControll -> 0


#define EXACT_INTEGRATION
#define USE_BULLET_FOR_COLLISION

//control

//#define ONED
#define CACHE
#define NEAR_VISION //i.e if we don't see a near obstacle when choosing the desideredSpeed
#define SECURE_TIME (4*tau)//(4*tau)//(4*tau) //(tau) //0.5//

//#define USE_CURRENT_HEADING_FOR_DESIDERED_SPEED


//#define SOCIAL_FORCE
//#define CAREFULL 
//#define TRACK_ACCELERATION

//sensing

//#define GO_AWAY


#define RAB
#define SENSING_ERROR

//#define DEADLOCKS
#define RVO_HOLO

//#define USE_BULLET_FOR_SENSING

//No define = same result at each run
//#define RAND_INIT

//define to iexecute one block before the start oh the loop, usefull for time related experiments (initial setup)
//#define FIRST_BLOCK


//Testato con cerchio e migliore (soprattutto quando devo calcolare molti raggi (resolution =>, in ambienti affollatti
//TODO trovare l'errore!!!!, ordine diverso con o senza USE_MAX_TEST
//#define USE_MAX_DIST_TEST
//Se prevedere gli scontri con optimal speed oppure con la velocità attuale
//#define TEST_WITH_CURRENT_SPEED
//#define PREDICT_CHANGE

#endif

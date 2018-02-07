include $(GNUSTEP_MAKEFILES)/common.make


TOOL_NAME = MultiAgent
MultiAgent_OBJCC_FILES = main.mm Agent.mm ShadowAgent.mm Wall.mm World.mm Group.mm Human.mm Footbot.mm Experiment.mm LineExperiment.mm ExperimentWithArguments.mm

MultiAgent_CC_FILES = RVO/Agent.cpp RVO/Obstacle.cpp RVO/RVOSimulator.cpp RVO/KdTree.cpp  HRVO/Agent.cpp HRVO/Goal.cpp HRVO/HRVOSimulator.cpp HRVO/KdTree.cpp HRVO/Obstacle.cpp HRVO/RoadmapVertex.cpp HRVO/Vector2.cpp

MultiAgent_INCLUDE_DIRS += -I/homeb/guzzi/local/include/bullet -I/homeb/guzzi/local/include

MultiAgent_TOOL_LIBS    += -L/homeb/guzzi/local/lib -lBulletCollision -lLinearMath -lboost_random

#MultiAgent_OBJCC_PRECOMPILED_HEADERS = Linux_Prefix.pch


ADDITIONAL_CPPFLAGS =-fblocks -D_GLIBCXX__PTHREADS

ADDITIONAL_OBJCCFLAGS += -include Linux_Prefix.pch -O3

ADDITIONAL_CCFLAGS += -include Linux_PrefixCC.pch -O3

include $(GNUSTEP_MAKEFILES)/tool.make
# A Model of Artificial Emotions for Behavior-Modulation and Implicit Coordination in Multi-robot Systems
## Supplementary material


This repository contains supplementary material for the GECCO-18 paper:

```
Jérôme Guzzi, Alessandro Giusti, Luca M. Gambardella and Gianni A. Di Caro. 2018. A Model of Artificial Emotions for Behavior-Modulation and Implicit Coordination in Multi-robot Systems. In GECCO ’18: Genetic and Evolutionary Computation Conference, July 15–19, 2018, Kyoto, Japan. ACM, New York, NY, USA, 9 pages. https://doi.org/10.1145/3205455.3205650
```

## Source code

We provide an implementation in ObjC that uses the GNUstep runtime

### Installation

Install the dependencies:
  - [GNUStep](http://www.gnustep.org)
  - [clang](https://clang.llvm.org)

Compile the code:
```bash
cmake .
make
```

### Running
```bash
./MultiAgent  --help
```

## video

The folder contains a video that illustrate the experiments reported in the paper.

### Preventing and escaping deadlocks in crowds


![PANIC](https://raw.githubusercontent.com/AnonymSubmit/GECCO-753/master/video/panic.png)


All agents wants start on a circle and want to travel to the antipodal point. A large crowding form in the middle. Orange agent are _frustated_ because they are no more advancing towards their target. Red agent are _fearful_ to get blocked because they see not little free space in front of them. Frustrated agents try to resolve the problem by steering towards the direction with the most free space. Fearful agents move slower while they wait for the problem to be resolved.

### Enabling e cient activity of agents with time-critical tasks

![URGENCY](https://raw.githubusercontent.com/AnonymSubmit/GECCO-753/master/video/urgency.png)]

Two kinds of agents move back and forth. On kind of agent has a maximal time to complete the traveling. When remaining time get low, the agents start to feel _urgency_ (purple), which cause them to move straighter. Agents that feel no urgency keep away from them.

### Assisting robots with sensing issues

![CONFUSION](https://raw.githubusercontent.com/AnonymSubmit/GECCO-753/master/video/confusion.png)

  Blue agents are _confused_ because the estimation of their orientation (returned by sensors) is too noisy.
  Confused agent become more careful, slow down and try to keep a safety distance from other agents.
  Agents surrondigs confused agents act _altruistically_ (green), and share measurements from their working sensors with confused agent.

# A Model of Artificial Emotions for Behavior-Modulation and Implicit Coordination in Multi-robot Systems
## Supplementary material


This repository contains supplementary material for the GECCO-18 paper:

```
Jérôme Guzzi, Alessandro Giusti, Luca M. Gambardella and Gianni A. Di Caro. 2018. 
A Model of Artificial Emotions for Behavior-Modulation and Implicit Coordination in Multi-robot Systems. 
In GECCO ’18: Genetic and Evolutionary Computation Conference, July 15–19, 2018, Kyoto, Japan. ACM, New York, NY, USA, 9 pages. 
https://doi.org/10.1145/3205455.3205650
```

## Read the paper

The paper is available online at https://dl.acm.org/authorize?N653886

## Cite the paper

```bibtex
@inproceedings{Guzzi:2018:MAE:3205455.3205650,
 author = {Guzzi, J{\'e}r\^{o}me and Giusti, Alessandro and Gambardella, Luca M. and Di Caro, Gianni A.},
 title = {A Model of Artificial Emotions for Behavior-modulation and Implicit Coordination in Multi-robot Systems},
 booktitle = {Proceedings of the Genetic and Evolutionary Computation Conference},
 series = {GECCO '18},
 year = {2018},
 isbn = {978-1-4503-5618-3},
 location = {Kyoto, Japan},
 pages = {21--28},
 numpages = {8},
 url = {http://doi.acm.org/10.1145/3205455.3205650},
 doi = {10.1145/3205455.3205650},
 acmid = {3205650},
 publisher = {ACM},
 address = {New York, NY, USA},
 keywords = {artificial emotions, control architecture, multi-robot system},
} 
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

## Video

The folder contains a [video](https://raw.githubusercontent.com/jeguzzi/artificial-emotions/master/video/video.mov) that illustrate the experiments reported in the paper.

### Preventing and escaping deadlocks in crowds


![PANIC](https://raw.githubusercontent.com/jeguzzi/artificial-emotions/master/video/panic.png)


All agents wants start on a circle and want to travel to the antipodal point. A large crowding form in the middle. Orange agent are _frustated_ because they are no more advancing towards their target. Red agent are _fearful_ to get blocked because they see not little free space in front of them. Frustrated agents try to resolve the problem by steering towards the direction with the most free space. Fearful agents move slower while they wait for the problem to be resolved.

### Enabling e cient activity of agents with time-critical tasks

![URGENCY](https://raw.githubusercontent.com/jeguzzi/artificial-emotions/master/video/urgency.png)

Two kinds of agents move back and forth. On kind of agent has a maximal time to complete the traveling. When remaining time get low, the agents start to feel _urgency_ (purple), which cause them to move straighter. Agents that feel no urgency keep away from them.

### Assisting robots with sensing issues

![CONFUSION](https://raw.githubusercontent.com/jeguzzi/artificial-emotions/master/video/confusion.png)

  Blue agents are _confused_ because the estimation of their orientation (returned by sensors) is too noisy.
  Confused agent become more careful, slow down and try to keep a safety distance from other agents.
  Agents surrondigs confused agents act _altruistically_ (green), and share measurements from their working sensors with confused agent.

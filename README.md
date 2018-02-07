# Submission-#753

This repository contains supplementary material for Submission #753 to GECCO-18.

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

### Panic


![PANIC](https://raw.githubusercontent.com/AnonymSubmit/GECCO-753/master/videos/panic.png)


All agents wants start on a circle and want to travel to the antipodal point. A large crowding form in the middle. Orange agent are _frustated_ because they are no more advancing towards their target. Red agent are _fearful_ to get blocked because they see not little free space in front of them. Frustrated agents try to resolve the problem by steering towards the direction with the most free space. Fearful agents move slower while they wait for the problem to be resolved.

### Urgency

![URGENCY](https://raw.githubusercontent.com/AnonymSubmit/GECCO-753/master/videos/urgency.png)]

Two kinds of agents move back and forth. On kind of agent has a maximal time to complete the traveling. When remaining time get low, the agents start to feel _urgency_ (purple), which cause them to move straighter. Agents that feel no urgency keep away from them.

### Confusion

![CONFUSION](https://raw.githubusercontent.com/AnonymSubmit/GECCO-753/master/videos/confusion.png)

  Blue agents are _confused_ because the estimation of their orientation (returned by sensors) is too noisy.
  Confused agent become more careful, slow down and try to keep a safety distance from other agents.
  Agents surrondigs confused agents act _altruistically_ (green), and share measurements from their working sensors with confused agent.

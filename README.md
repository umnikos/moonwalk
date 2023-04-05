# moonwalk
*This software is currently in early alpha. Any commit may be a breaking change. You will probably have to edit your code when switching between commits.*

A state-persistent programming language for your CC:Tweaked turtles! 
Build non-trivial programs that, when rebooted, resume from right where they left off.

## What does it look like?
Something like this:
```
: pace f move r turn r turn ;
{ pace } forever
```
It is a concatenative language, meaning a program simply consists of a list of procedures to call, 
which pass arguments to each other through a single data stack.
For a longer explanation, check out [the tutorial.](/tutorial.md)

## What's in this repo?
- `interpreter.moon` - The moonwalk interpreter
- `stdlib.mw` - Standard library (non-turtle-specific functions)
- `turtle.mw` - Standard library for turtle-specific functions
- `*.mw` - Other programs written in moonwalk, some more useful than others
- `bundle_state_as_program.moon` - A script to turn a half-finished moonwalk execution into a single lua file. Useful when you want to publish software 
- `build_program.moon` - Similar to the above, but uses CCEmuX to do the initial execution for you, quickening the process.

## How do I contribute?
Pull requests, ideas and feedback are all welcome!

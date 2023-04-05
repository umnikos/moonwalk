# moonwalk tutorial

## Language basics
Procedures in moonwalk are called "words".
A program consists of a file full of a bunch of space-delimeted words. There is not much syntax beyond that.
Words that are yet to be executed are stored in a long queue called the word queue.
At the start of the program execution the word queue is just the entire program file.
The word queue basically acts as a big to-do list, and the interpreter will go through the words in order, executing them.
Words accept parameters and then leave return values on what's called the data stack.
You can think of it as a workbench where the most recently put value is what always gets taken out.

Here's a hypothetical moonwalk evaluation state:
```
word queue (executed left to right): 
do_n_pushups  walk_the_dog  calculate_the_thousanth_fibonacci_number

stack (top value is most recent):
25
"Hello, World!"
12345
```

Here the interpreter will first take a word out of the word queue, see that it's `do_n_pushups` and begin executing its definition.
It requires a number, so it'll pop a value from the stack (`25`) and use that as the number of pushups to do.
Once all of that is done it'll repeat that again: take another word, execute its body, pushing and popping as necessary.

So far this is a description of a basic sequencer language, due to the fact we have not introduced anything that will alter the control flow of what words get executed next.
Fortunately I haven't told you what a particular word is capable of doing, and that thing is: anything at all, including modifying the word queue!

Say we want to make a compound word that is actually several words strung together, for example to walk the dog we first find the dog, then we take it outside, then we wait a bit, then we take it back inside.
That is rather easy: make a word that, when executed, appends that list of things to do to the front of the word queue. Continuing our example:
```
word queue (executed left to right): 
walk_the_dog  calculate_the_thousanth_fibonacci_number

stack (top value is most recent):
"Hello, World!"
12345
```
Becomes:
```
word queue (executed left to right): 
find_dog  take_dog_outside  read_a_book  take_dog_inside  calculate_the_thousanth_fibonacci_number

stack (top value is most recent):
"Hello, World!"
12345
```
Furthermore, we can not only add words to the queue but also take them out and use them as parameters.
For example, the `:` word will keep taking words until it finds a `;` word and then use all of those words
to construct a simple word definition like the one above.
In fact, the above word can be defined exactly like so:
`: walk_the_dog find_dog take_dog_outside read_a_book take_dog_inside ;`

Building up on that, `#` is a word that will interpet the very next word as a number and push that number to the stack, 
so one way we could've gotten that `25` onto the stack for `do_n_pushups` to use is `# 25`.

Loops are not hard to envision, either. Here's a very simple one: `: loop loop ;`.
It's a bit dumb, given that it does nothing other than loop forever, but we can make it do something like so: `: loop do_1_squat loop ;`.
In fact, in a manner similar to how `:` works, we can make a word that reads an arbitrary amount of words and then makes a looping word out of them.
But we can do better than have every single word that wants to abstract over a snippet of code have to read a bunch of words until some terminating token.
Presenting: `{` and `}`. `{` Begins to read words until it finds a matching `}` and then pushes the entire code snippet to the stack as a value.
Then we can simply have our forever-looping word take a block of code from the stack and loop that. That's what `forever` does.
Here's how it's used: `{ dab_on_the_haters } forever`

These code blocks are really handy, for they're also used to make conditionals.
`ifelse` takes a boolean and two code snippets, and executes one of them upon seeing `true` and the other upon seeing `false`.
Example: `is_raining? { take_umbrella } { } ifelse`. `if` does the same thing as `ifelse` but assumes the second code block is `{ }`

## State persistence and how it works
When a computercraft computer or turtle gets rebooted, nothing of the original state remains other than what was written to a file.
Therefore the first step moonwalk takes towards state persistence is to write the current state to a file as often as possible.
This is called "checkpointing". It essentially just writes the current word queue and stack to the file so that the rebooted computer knows where it left off.
But that turns out to not be enough, for it is possible that a computer finished executing a word and then got rebooted just before writing down that fact to the state file.
That is a problem, for it will not know just by looking at the file whether the word was already executed or not and thus whether it needs to execute it again or not.
This is where the concept of "recovery words" comes in: for any word that isn't just a combination of previous moonwalk words,
you need to specify a word that will get called if the computer gets rebooted in the middle of executing your word.
The job of that word will mainly be to figure out if your word finished executing or not and what needs to happen in either case.

A good example is moving a turtle forward. We do not want it go forward 0 or 2 times, we want it go forward exactly once,
and there is a good indicator as to whether or not we did so: the turtle's fuel level.
So before we move we save the turtle's current fuel level in some variable (or on the stack). Then we proceed to move.
If we get interrupted in the middle of that, we check whether the fuel level changed. If it didn't, we try to move again.

There's this funny thing though: *any* word that isn't a combination of moonwalk words needs a recovery word, and that includes recovery words, for they're not infallible, either.
Thankfully, this doesn't go on forever, for eventually we get to words that we do not care if they get executed once or a million times (which are so-called idempotent), so we can have `retry` be the recovery word.
Additionally if a word does no IO (no interacting with things outside of the moonwalk state itself) we can have `pure` be the recovery word, which has the special property of not being checkpointed. (checkpointing is slow)

## Defining words using Lua
The previous paragraph mentioned defining words that aren't simply a combination of other moonwalk words, so here's how you do that: with `::`.
It takes the name of the word you're defining, then the name of an already defined recovery word, and then lua code right up until it sees a `;;`.
Examples:
```
:: add pure
	push(pop()+pop())
;;
```
```
:: swap pure
	local x = pop()
	local y = pop()
	push(x)
	push(y)
;;
```
```
:: item_count retry
	push(turtle.getItemCount())
;;
```
You need to take great care when writing lua words when it comes to the recovery of a crash.
Make sure that, when rebooted at any point, the word behaves as if it didn't get rebooted at all.
It is quite easy to accidentally leave extra things on the stack but only if the word got rebooted, which will lead to very devilish bugs.

## Extra tidbits
### The words dictionary
Words, when defined, are put in a single global dictionary. There are no locals.
If a word gets defined multiple times, only the last definition is used and it overwrites all previous definitions retroactively.
This may come in handy when overwriting standard library functions or trying to hotswap code, but honestly it mostly just leads to a bunch of words with `_internal` in their name and generally sucks.
Will almost definitely be changed in the future.

### Errors
Apart from lua errors which just terminate the execution, moonwalk has a C-like error throwing scheme of just returning a success/failure boolean value.
But if every function pushed such a value onto the stack it would get maddening to handle.
Thus this value is instead stored as a separate flag, whose value can be pushed to the stack using `success?`, or set/cleared using `success`/`failure`.
As an additional aid to help know whether a word even sets this flag or not, words which can fail are named with a different verb tense from words that cannot.
For example, `digging` is a word that can fail, but `dig` is a word that cannot (and will simply try over and over until it succeeds).

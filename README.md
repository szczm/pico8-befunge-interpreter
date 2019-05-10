# PICO-8 Befunge Interpreter

![Header GIF representing the interpreter in action](https://github.com/szczm/pico8-befunge-interpreter/blob/master/befunge.p8_0.gif)

[\[Play online!\]](https://www.lexaloffle.com/bbs/?tid=34176)

This is a Befunge-93 interpreter that I made in a few days. Tested on [all examples from Rosetta Code](https://rosettacode.org/wiki/Category:Befunge) that fit. You can finally code in an esoteric language inside a fantasy console!

## Excuse me, what is Befunge?
Befunge is a **stack-based, esoteric programming language**, in which the code is represented on a **two-dimensional grid**. The control flow of the program is directed using instructions such as *v*, *>*, *^* and *<* (respectively: down, right, up, left). If a border is reached, the program wraps around (both directions). Single character instructions can pop values of the stack, or place them on top of the stack, and act based on the retrieved values. Read more [on Wikipedia](http://wikipedia.org/wiki/Befunge).

## …what instructions?

Here's [the list of all instructions explained](https://en.wikipedia.org/wiki/Befunge#Befunge-93_instruction_list), also on Wikipedia. There are not many of them, and most are self-explanatory (arrow instructions, arithmetic operators, numbers). Just like with any other language, the more fun you have with it, the more you'll learn!

## …and why should I care?
In my opinion, Befunge really tests (and improves) your logical thinking and flow control skills. This is also a language like no other, in which you can actually visualize the control flow on a grid. Lastly, this is a stack based language, so it teaches you how to operate under a set of limitations (of course, you can just store and read values using *g* and *p* instructions, but that's cheating (not really)).

Also, you don't have to care if you don't want to! Democracy!

## Okay, maybe some examples?

Sure:

### Hello World!
```
"!dlrow olleh",,,,,,,,,,,,@
```
First, *"* enables string mode; all characters until next *"* will be pushed into the stack as ASCII values. Then, the string *hello world!* is pushed onto the stack (values go bottom to top on the stack). Then *,* prints a single character, so all characters are printed. Finally, *@* ends the program.

### Multiply n numbers together
```
1&>\&*\1-:v
  ^       _\.@
```
Push 1, then prompt user for n (&, stack: 1 [n]). Swap two top values (\, stack: [n] 1). Prompt user for a number a (stack: [n] 1 [a]), then multiply (\*, stack: [n] 1\*[a]). Swap values again (stack: 1\*[a] [n]), subtract 1 (stack: 1\*[a] [n]-1), and if the new value is 0, go right (_), swap values (stack: 0 1\*[a]), print number (.) and end the program (@). Otherwise, repeat.

### 99 Bottles of Beer
```
92+9*07pv,_       $:|
>       >:^:<       >   70g!#@_^
^:+670+1g70"bottles of beer on"<
>"selttob"07g1+067+",llaw eht "^
^" of beer"+76"take one down a"<
>"lttob"07g0"dnuora ti ssap dn"^
^"es of beer on the wall!"+76  <
            vp70.:-1<
```
Sadly, I made this one myself. I'll let you figure this one out. Most important aspects of this code:
- *07p* stores the top value in cell (0,7), *07g* retrieves it
- *+67* is 6+7=13 == "\r", carriage return, which is a newline in PICO-8
- a *0* is always appended after bottle count, that is to be able to discern if a character or a number should be printed
- going past grid borders wraps around

## Features:
- Visualization! See the instruction pointer move and wiggle as the code is being executed!
- Load/save support! And it autosaves when you run! And it apparently also works in the browser!
- Hints! Find out what a certain instruction does by hovering over it with the cursor!
- It just works! I'm surprised that it really works, and it works good!
- You can't copy/paste code in or out! This is a nightmare!
- Procedural sound! Instructions make little bleeps when they are being executed, and so do your keys! Doesn't seem to work in the browser! Family fun!

If you want to share your code, you can either share a screenshot, or you can copy the save file, which should be in your usual PICO-8 cart location under the name *_picofunge_save.p8*. Interwebz!

## How to run:
If you have PICO-8 installed, download the [cart file](befunge.p8.png) and run it in the same way as any other cart.

If you don't have PICO-8 ([and you should](https://www.lexaloffle.com/pico-8.php)), you can [play with the interpreter online](https://www.lexaloffle.com/bbs/?tid=34176) (bear in mind that some features may not work in all browsers).

## How to use:
All the usual ASCII characters from your keyboard work, so just poke the interpreter in any way you want! 

Use **arrow keys** to navigate the grid. Use **Backspace** to erase an instruction and go back one cell, or **Space** to go forward.

Use **Tab** to quickly run code. You can also use the Tab button as an alternative for Enter in situations where you would normally use the latter, since Enter opens the pause menu.

Use **Enter** to enter the pause menu, in which you'll find the following options:
- **RUN/STOP CODE**
- **SAVE**
- **CLEAR GRID**
- **ENABLE/DISABLE AUTOSAVE**
- **ENABLE/DISABLE SOUND**

To reload code, restart the cart. There is no LOAD button, since there are only 5 menu items available to me :(

## Limitations/known bugs/quirks:
- Backspace button doesn't work in the browser (tested in Firefox)
- If the *p* instruction is used to put a nonprintable character in the grid, the character is displayed in a distinct way as a "glitch", it is considered data, and is not saved
- The P key opens up the main menu, which can be sometimes annoying, but is not otherwise a problem
- The grid is smaller than usual Befunge (it's size is 32 columns and 8 rows)
- There is currently no support for big numbers, numbers inside the interpreter are normal PICO-8 numbers (so usual things like integer overflow can happen)
-- Small ASCII character codes assumed for letters, since PICO-8 only supports one case.

## Bug reports
If you encounter any bugs or weird behaviour, please let me know either by [submitting an issue](https://github.com/szczm/pico8-befunge-interpreter/issues/new) or on [Twitter @szczm_](https://twitter.com/szczm_). Bonus points for including a screenshot!

## Source code, or "how can I make this about me"
If you have any ideas on how you could use this project, the source code is extensively documented — each function and class is explained and I tried to comment every important bit that needed explanation or description. This cart is released under a CC4-BY-NC-SA licence on [Lexaloffle BBS](https://www.lexaloffle.com/bbs/?tid=34176) thanks to an upload option, and on GitHub under the [MIT licence](LICENSE). Basically, do anything you want with it, if you want to, and I'll be happy if you let me know!

## Last question — why?
Please don't ask.

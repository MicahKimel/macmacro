# Mac Macro Cli Project

This project records user input and the plays it back

Usage:
```
---------------------------------------------------------
macmacrocli tool used for recording
mouse and text input and playing it back
cliclick is a required dependancy for this application
---------------------------------------------------------
COMMANDS:

macmacro -o output.sh
This command start recording and sets an output file

f5
 is used while running to make focused window fullscreen in order for clicks to always work 


f6
 can used to stop recording


f7
 can used to capture image


f8
 can used to switch application


macmacro -r /path/script1.sh /path/script2.sh
This command runs any scripts togeather to preform complex actions
```

Limitations:
cliclick must be installed. scrollwheel and double tap scrolling are not yet suported, so you must click and drag to scroll with the sroll bar currently.

Recommended to always make active window full screen in order for all clicks to be in the right place


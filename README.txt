Prerequisites:
Bizhawk Version 2.3.2 - I originally tried with version 2.3.0 and couldn't get it to work. For now, I will only support Bizhawk 2.3.2.
LiveSplit Version 1.7+ - This should work on older versions of LiveSplit as well, but I haven't tested.
LiveSplit Server Addon - Allows network connection between LiveSplit and the autosplitter script. Found at https://github.com/LiveSplit/LiveSplit.Server/releases

Setup:
1.) In LiveSplit, add the LiveSplit Server component to your layout. The default port (16834) should be fine for most people, but if for some reason you need to use another port, you will have to edit the lua script.
2.) Extract the MinishCapAutosplitter.zip to somewhere convenient.
3.) From the extracted folder, copy the contents of the "luasocket" folder to the root folder of BizHawk (where EmuHawk.exe, DiscoHawk.exe, etc. are).
4.) From the extracted folder, copy the "MinishCapAutosplitter.lua" file and "MinishCapAutosplitterConfig" folder into the "Lua" folder of BizHawk.
5.) Edit the "MinishCapAutosplitterConfig_CATEGORY.txt" file for each category to match the splits you are using.  Instructions are at the top of the file.

That's it for setup.  Now, any time you start doing run, you have to start the LiveSplit server. This only has to be once when LiveSplit is first opened. To do this, right click on LiveSplit, and select Control->Start Server.
Make sure that the "Category = " line in the "MinishCapAutosplitter.lua" file is set to the category that you are running. More explaination is at the top of the script.

On Bizhawk, load your Minish Cap ROM, then select Tools->Lua Console. In the console, select Scripts->Open Script... and choose the MinishCapAutosplitter.lua file. Any time you start a new run, reset your timer and do a core reboot on BizHawk.  This will reset the varibles in the script.

NOTE: You should set your splits to start at 0.83 seconds.  This is because the flag that tells the script to start the timer is set exaclty 50 frames after hitting the A/start button to start the file.

; Texter
; Author:         Adam Pash <adam@lifehacker.com>
; Gratefully adapted several ideas from AutoClip by Skrommel:
;		http://www.donationcoder.com/Software/Skrommel/index.html#AutoClip
; Huge thanks to Dustin Luck for his contributions
; Script Function:
;	Designed to implement simple, on-the-fly creation and managment 
;	of auto-replacing hotstrings for repetitive text
;	http://lifehacker.com/software//lifehacker-code-texter-windows-238306.php
SetWorkingDir %A_ScriptDir%
#SingleInstance,Force 
#NoEnv
AutoTrim,off
SetKeyDelay,-1
SetWinDelay,0 
Gosub,UpdateCheck
Gosub,READINI
Gosub,RESOURCES
Gosub,TRAYMENU
;Gosub,AUTOCLOSE

FileRead, EnterKeys, bank\enter.csv
FileRead, TabKeys, bank\tab.csv
FileRead, SpaceKeys, bank\space.csv
Gosub,GetFileList
Goto Start

START:
hotkey = 
Input,input,V L99,{SC77}
if hotkey In %cancel%
{
	SendInput,%hotkey%
	Goto,START
}
IfNotInString,FileList,%input%|
{
	SendInput,%hotkey%
	Goto,START
}
else if hotkey = `{Space`}
{
	if input in %SpaceKeys%
	{
		GoSub, Execute
		Goto,START
	}
	else
	{
		SendInput,%hotkey%
		Goto,Start
	}
}
else if hotkey = `{Enter`}
{
	if input in %EnterKeys%
	{
		GoSub, Execute
		Goto,START
	}
	else
	{
		SendInput,%hotkey%
		Goto,Start
	}
}
else if hotkey = `{Tab`}
{
	if input in %TabKeys%
	{
		GoSub, Execute
		GoTo,Start
	}
	else
	{
		SendInput,%hotkey%
		Goto,Start
	}
}
else
{
	SendInput,%hotkey%
	Goto,START
}
return

EXECUTE:
;; below added b/c SendMode Play appears not to be supported in Vista
if (A_OSVersion = "WIN_VISTA")
	SendMode Input
else
	SendMode Play
; Set an option in Preferences to enable for use with Synergy - Use SendMode Input to work with Synergy
SoundPlay, %A_ScriptDir%\resources\replace.wav
ReturnTo := 0
StringLen,BSlength,input
Send, {BS %BSlength%}
FileRead, ReplacementText, replacements\%input%.txt
StringLen,ClipLength,ReplacementText

IfInString,ReplacementText,::scr::
{
	;To fix double spacing issue, replace `r`n (return + new line) as AHK sends a new line for each character
	StringReplace,ReplacementText,ReplacementText,`r`n,`n, All
	StringReplace,Script,ReplacementText,::scr::,,
	SendEvent,%Script%
	return
}
else
{
	;To fix double spacing issue, replace `r`n (return + new line) as AHK sends a new line for each character
	;(but only in compatibility mode)
	if MODE = 0
	{
		StringReplace,ReplacementText,ReplacementText,`r`n,`n, All
	}
	IfInString,ReplacementText,`%c
	{
		StringReplace, ReplacementText, ReplacementText, `%c, %Clipboard%, All
	}
	IfInString,ReplacementText,`%t
	{
		FormatTime, CurrTime, , Time
		StringReplace, ReplacementText, ReplacementText, `%t, %CurrTime%, All
	}
	IfInString,ReplacementText,`%ds
	{
		FormatTime, SDate, , ShortDate
		StringReplace, ReplacementText, ReplacementText, `%ds, %SDate%, All
	}
	IfInString,ReplacementText,`%dl
	{
		FormatTime, LDate, , LongDate
		StringReplace, ReplacementText, ReplacementText, `%dl, %LDate%, All
	}
	IfInString,ReplacementText,`%|
	{
		;in clipboard mode, CursorPoint & ClipLength need to be calculated after replacing `r`n
		if MODE = 0
		{
			MeasurementText := ReplacementText
		}
		else
		{
			StringReplace,MeasurementText,ReplacementText,`r`n,`n, All
		}
		StringGetPos,CursorPoint,MeasurementText,`%|
		StringReplace, ReplacementText, ReplacementText, `%|,, All
		StringReplace, MeasurementText, MeasurementText, `%|,, All
		StringLen,ClipLength,MeasurementText
		ReturnTo := ClipLength - CursorPoint
	}

	if MODE = 0
	{
		if ReturnTo > 0
		{
			if ReplacementText contains !,#,^,+
			{
				SendRaw, %ReplacementText%
				Send,{Left %ReturnTo%}
			}
			else
				Send,%ReplacementText%{Left %ReturnTo%}
		}
		else
			SendRaw,%ReplacementText%
	}
	else
	{
		oldClip = %Clipboard%
		Clipboard = %ReplacementText%
		if ReturnTo > 0
			Send,^v{Left %ReturnTo%}
		else
			Send,^v
		Clipboard = %oldClip%
	}
;	if ReturnTo > 0
;		Send, {Left %ReturnTo%}
}
SendMode Event
IniRead,expanded,texter.ini,Stats,Expanded
IniRead,chars_saved,texter.ini,Stats,Characters
expanded += 1
chars_saved += ClipLength
IniWrite,%expanded%,texter.ini,Stats,Expanded
IniWrite,%chars_saved%,texter.ini,Stats,Characters
Return

HOTKEYS: 
StringTrimLeft,hotkey,A_ThisHotkey,1 
StringLen,hotkeyl,hotkey 
If hotkeyl>1 
  hotkey=`{%hotkey%`} 
Send,{SC77}
Return 

READINI: 
IfNotExist bank
	FileCreateDir, bank
IfNotExist replacements
	FileCreateDir, replacements
IfNotExist resources
	FileCreateDir, resources
IniWrite,0.3,texter.ini,Preferences,Version
cancel := GetValFromIni("Cancel","Keys","{Escape}") ;keys to stop completion, remember {} 
ignore := GetValFromIni("Ignore","Keys","{Tab}`,{Enter}`,{Space}") ;keys not to send after completion 
IniWrite,{Escape}`,{Tab}`,{Enter}`,{Space}`,{Left}`,{Right}`,{Up}`,{Down},texter.ini,Autocomplete,Keys
keys := GetValFromIni("Autocomplete","Keys","{Escape}`,{Tab}`,{Enter}`,{Space}`,{Left}`,{Right}`,{Esc}`,{Up}`,{Down}")
otfhotkey := GetValFromIni("Hotkey","OntheFly","^+H")
managehotkey := GetValFromIni("Hotkey","Management","")
MODE := GetValFromIni("Settings","Mode",0)
EnterBox := GetValFromIni("Triggers","Enter",0)
TabBox := GetValFromIni("Triggers","Tab",0)
SpaceBox := GetValFromIni("Triggers","Space",0)

;; Enable hotkeys for creating new keys and managing replacements
if otfhotkey <>
	Hotkey,%otfhotkey%,NEWKEY
if managehotkey <>
	Hotkey,%managehotkey%,MANAGE


;; Enable triggers (Enter, Tab, Spacebar)
Loop,Parse,keys,`, 
{ 
  StringTrimLeft,key,A_LoopField,1 
  StringTrimRight,key,key,1 
  StringLen,length,key 
  If length=0 
    Hotkey,$`,,HOTKEYS 
  Else 
    Hotkey,$%key%,HOTKEYS 
}

;; This section is intended to exit the input in the Start thread whenever the mouse is clicked or 
;; the user Alt-Tabs to another window so that Texter is prepared
~LButton::Send,{SC77}
$!Tab::
{
	GetKeyState,capsL,Capslock,T
	SetCapsLockState,Off
	pressed = 0
	Loop {
		Sleep,10
		GetKeyState,altKey,Alt,P
		GetKeyState,tabKey,Tab,P
		if (altKey = "D") and (tabKey = "D")
		{
			if pressed = 0
			{
				pressed = 1
				Send,{Alt down}{Tab}
				continue
			}
			else
			{
				continue
			}
		}
		else if (altKey = "D")
		{
			pressed = 0
			continue
		}
		else
		{
			Send,{Alt up}
			break
		}
	}
	Send,{SC77}
	if (capsL = "D")
		SetCapsLockState,On
}
$!+Tab::
{
	GetKeyState,capsL,Capslock,T
	SetCapsLockState,Off
	pressed = 0
	Loop {
		Sleep,10
		GetKeyState,altKey,Alt,P
		GetKeyState,tabKey,Tab,P
		GetKeyState,shiftKey,Shift,P
		if (altKey = "D") and (tabKey = "D") and (shiftKey = "D")
		{
			if pressed = 0
			{
				pressed = 1
				Send,{Alt down}{Shift down}{Tab}
				;Send,{Shift up}
				continue
			}
			else
			{
				continue
			}
		}
		else if (altKey = "D") and (shiftKey != "D")
		{
			pressed = 0
			Send,{Shift up}
			break
		}
		else if (altKey = "D") and (shiftKey = "D")
		{
			pressed = 0
			continue
		}
		else
		{
			Send,{Alt up}{Shift up}
			break
		}
	}
;	Send,{SC77}
	if (capsL = "D")
		SetCapsLockState,On
}

Return


;; method written by Dustin Luck for writing to ini
GetValFromIni(section, key, default)
{
	IniRead,IniVal,texter.ini,%section%,%key%
	if IniVal = ERROR
	{
		IniWrite,%default%,texter.ini,%section%,%key%
		IniVal := default
	}
	return IniVal
}


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; Implementation and GUI for on-the-fly creation ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
NEWKEY:
Gui,1: Destroy
Gui,1: font, s12, Arial  
Gui,1: +AlwaysOnTop -SysMenu +ToolWindow  ;suppresses taskbar button, always on top, removes minimize/close
Gui,1: Add, Text,x10 y20, Hotstring:
Gui,1: Add, Edit, x13 y45 r1 W65 vRString,
Gui,1: Add, Edit, x100 y45 r4 W395 vFullText, Enter your replacement text here...
Gui,1: Add, Text,x115,Trigger:
Gui,1: Add, Checkbox, vEnterCbox yp x175 Checked%EnterBox%, Enter
Gui,1: Add, Checkbox, vTabCbox yp x242 Checked%TabBox%, Tab
Gui,1: Add, Checkbox, vSpaceCbox yp x305 Checked%SpaceBox%, Space
Gui,1: font, s8, Arial 
Gui,1: Add, Button,w80 x320 default,&OK
Gui,1: Add, Button,w80 xp+90 GButtonCancel,&Cancel
Gui,1: font, s12, Arial  
Gui,1: Add,DropDownList,x100 y15 vTextOrScript, Text||Script
Gui,1: Add,Picture,x0 y105,resources\texter.png
Gui,1: Show, W500 H200,Add new hotstring...
Hotkey,IfWinActive, Add new hotstring
Hotkey,Esc,ButtonCancel,On
Hotkey,IfWinActive
return

ButtonCancel:
Gui,1: Destroy
return

ButtonOK:
GuiControlGet,RString,,RString
IfExist, replacements\%RString%.txt
{
	MsgBox,262144,Hotstring already exists, A replacement with the text %Rstring% already exists.  Would you like to try again?
	return
}
GuiControlGet,EnterCbox,,EnterCbox
GuiControlGet,TabCbox,,TabCbox
GuiControlGet,SpaceCbox,,SpaceCbox
if EnterCbox = 0
	if TabCbox = 0
		if SpaceCbox = 0
		{
			MsgBox,262144,Choose a trigger,You need to choose a trigger in order to save a hotstring replacement.
			return
		}
Gui, Submit
If RString<>
{
	if FullText<>
	{		
		if EnterCbox = 1 
		{
			IniWrite,1,texter.ini,Triggers,Enter
			FileAppend,%Rstring%`,, bank\enter.csv
			FileRead, EnterKeys, bank\enter.csv
			if TextOrScript = Script
				FullText = ::scr::%FullText%
			FileAppend,%FullText%,replacements\%Rstring%.txt
		}
		else
			IniWrite,0,texter.ini,Triggers,Enter
		if TabCbox = 1
		{
			IniWrite,1,texter.ini,Triggers,Tab
			FileAppend,%Rstring%`,, bank\tab.csv
			FileRead, TabKeys, bank\tab.csv
			IfNotExist, replacements\%RString%.txt
			{
				if TextOrScript = Script
					FullText = ::scr::%FullText%
				FileAppend,%FullText%,replacements\%Rstring%.txt
			}
		}
		else
			IniWrite,0,texter.ini,Triggers,Tab
		if SpaceCbox = 1
		{
			IniWrite,1,texter.ini,Triggers,Space
			FileAppend,%Rstring%`,, bank\space.csv
			FileRead, SpaceKeys, bank\space.csv
			IfNotExist, replacements\%RString%.txt
			{
				if TextOrScript = Script
					FullText = ::scr::%FullText%
				FileAppend,%FullText%,replacements\%Rstring%.txt
			}
		}
		else
			IniWrite,0,texter.ini,Triggers,Space
	}
}
IniRead,EnterBox,texter.ini,Triggers,Enter
IniRead,TabBox,texter.ini,Triggers,Tab
IniRead,SpaceBox,texter.ini,Triggers,Space
Gosub,GetFileList
return

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; End Implementation and GUI for on-the-fly creation ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



TRAYMENU:
Menu,TRAY,NoStandard 
Menu,TRAY,DeleteAll 
Menu,TRAY,Add,&Manage hotstrings,MANAGE
Menu,TRAY,Add,&Create new hotstring,NEWKEY
Menu,TRAY,Add
Menu,TRAY,Add,P&references...,PREFERENCES
Menu,TRAY,Add,&Help,HELP
Menu,TRAY,Add
Menu,TRAY,Add,&About...,ABOUT
;Menu,TRAY,Add,&Disable,DISABLE
;if disable = 1
;	Menu,Tray,Check,&Disable
Menu,TRAY,Add,E&xit,EXIT
Menu,TRAY,Default,&Manage hotstrings
Menu,Tray,Tip,Texter
Menu,TRAY,Icon,resources\texter.ico
Return

ABOUT:
Gui,4: Destroy
Gui,4: Add,Picture,x200 y0,resources\texter.png
Gui,4: font, s36, Courier New
Gui,4: Add, Text,x10 y35,Texter
Gui,4: font, s8, Courier New
Gui,4: Add, Text,x171 y77,0.3
Gui,4: font, s9, Arial 
Gui,4: Add,Text,x10 y110 Center,Texter is a text replacement utility designed to save`nyou countless keystrokes on repetitive text entry by`nreplacing user-defined abbreviations (or hotstrings)`nwith your frequently-used text snippets.`n`nTexter is written by Adam Pash and distributed`nby Lifehacker under the GNU Public License.`nFor details on how to use Texter, check out the
Gui,4:Font,underline bold
Gui,4:Add,Text,cBlue gHomepage Center x110 y230,Texter homepage
Gui,4: Color,F8FAF0
Gui,4: Show,auto,About Texter
Hotkey,IfWinActive, About Texter
Hotkey,Esc,DismissAbout,On
Hotkey,IfWinActive
Return

DISABLE:
Loop,Parse,keys,`,
{ 
  StringTrimLeft,key,A_LoopField,1 
  StringTrimRight,key,key,1 
  StringLen,length,key 
  If length=0 
	Hotkey,$`,Toggle
  Else 
	Hotkey,$%key%,Toggle
} 
if disable = 0
{
	IniWrite,1,texter.ini,Settings,Disable
	Menu,Tray,Check,&Disable
}
else
{
	IniWrite,0,texter.ini,Settings,Disable
	Menu,Tray,Uncheck,&Disable
}
return

Homepage:
Run http://lifehacker.com/software//lifehacker-code-texter-windows-238306.php
return

BasicUse:
Run http://lifehacker.com/software//lifehacker-code-texter-windows-238306.php#basic
return

Scripting:
Run http://lifehacker.com/software//lifehacker-code-texter-windows-238306.php#advanced
return

DismissAbout:
Gui,4: Destroy
return

HELP:
Gui,5: Destroy
Gui,5: Add,Picture,x200 y5,resources\texter.png
Gui,5: font, s36, Courier New
Gui,5: Add, Text,x20 y40,Texter
Gui,5: font, s9, Arial 
Gui,5: Add,Text,x19 y285 w300 center,All of Texter's documentation can be found online at the
Gui,5:Font,underline bold
Gui,5:Add,Text,cBlue gHomepage Center x125 y305,Texter homepage
Gui,5: font, s9 norm, Arial 
Gui,5: Add,Text,x10 y100 w300,For help by topic, click on one of the following:
Gui,5:Font,underline bold
Gui,5:Add,Text,x30 y120 cBlue gBasicUse,Basic Use: 
Gui,5:Font,norm
Gui,5:Add,Text,x50 y140 w280, Covers how to create basic text replacement hotstrings.
Gui,5:Font,underline bold
Gui,5:Add,Text,x30 y180 cBlue gScripting,Sending advanced keystrokes: 
Gui,5:Font,norm
Gui,5:Add,Text,x50 y200 w280, Texter is capable of sending advanced keystrokes, like keyboard combinations.  This section lists all of the special characters used in script creation, and offers a few examples of how you might use scripts.
Gui,5: Color,F8FAF0
Gui,5: Show,auto,Texter Help
Hotkey,IfWinActive, Texter Help
Hotkey,Esc,DismissHelp,On
Hotkey,IfWinActive
Return

DismissHelp:
Gui,5: Destroy
return

GetFileList:
FileList =
Loop, replacements\*.txt
{
	FileList = %FileList%%A_LoopFileName%|
}
StringReplace, FileList, FileList, .txt,,All
return

PREFERENCES:
if otfhotkey<>
	HotKey,%otfhotkey%,Off
if managehotkey<>
	HotKey,%managehotkey%,Off
Gui,3: Destroy
Gui,3: Add, Tab,x5 y5 w300 h190,General|Print|Stats ;|Import|Export Add these later
Gui,3: Add,Button,x150 y200 w75 GSETTINGSOK Default,&OK
Gui,3: Add,Text,x10 y40,On-the-Fly shortcut:
Gui,3: Add,Hotkey,xp+10 yp+20 w100 vsotfhotkey, %otfhotkey%
Gui,3: Add,Text,x150 y40,Hotstring Management shortcut:
Gui,3: Add,Hotkey,xp+10 yp+20 w100 vsmanagehotkey, %managehotkey%
;code optimization -- use mode value to set in initial radio values
CompatMode := NOT MODE
Gui,3: Add,Radio,x10 y100 vModeGroup Checked%CompatMode%,Compatibility mode (Default)
Gui,3: Add,Radio,Checked%MODE%,Clipboard mode (Faster, but less compatible)
IniRead,OnStartup,texter.ini,Settings,Startup
Gui,3: Add,Checkbox, vStartup x20 yp+30 Checked%OnStartup%,Run Texter at start up
IniRead,Update,texter.ini,Preferences,UpdateCheck
Gui,3: Add,Checkbox, vUpdate x20 yp+20 Checked%Update%,Check for updates at launch?
;Gui,3: Add,Button,x150 y200 w75 GSETTINGSOK Default,&OK
Gui,3: Add,Button,x230 y200 w75 GSETTINGSCANCEL,&Cancel
Gui,3: Tab,2
Gui,3: Add,Button,w150 h150 gPrintableList,Create Printable Texter Cheatsheet
Gui,3: Add,Text,xp+160 y50 w125 Wrap,Click the big button to export a printable cheatsheet of all your Texter hotstrings, replacements, and triggers.
Gui,3: Tab,3
Gui,3: Add,Text,x10 y40,Your Texter stats:
IniRead,expanded,texter.ini,Stats,Expanded
Gui,3: Add,Text,x25 y60,Snippets expanded:   %expanded% 
IniRead,chars_saved,texter.ini,Stats,Characters
Gui,3: Add,Text,x25 y80,Characters saved:     %chars_saved%
SetFormat,FLOAT,0.2
time_saved := chars_saved/24000
Gui,3: Add,Text,x25 y100,Hours saved:             %time_saved% (assuming 400 chars/minute)
;Gui,3: Add,Button,x150 y200 w75 GSETTINGSOK Default,&OK
;Gui,3: Add,Button,x230 y200 w75 GSETTINGSCANCEL,&Cancel
Gui,3: Show,AutoSize,Texter Preferences
Hotkey,IfWinActive, Texter Preferences
Hotkey,Esc,SETTINGSCANCEL,On
Hotkey,IfWinActive
Return

SETTINGSOK:
Gui,3: Submit
If sotfhotkey<>
{
  otfhotkey:=sotfhotkey
  Hotkey,%otfhotkey%,Newkey
  IniWrite,%otfhotkey%,texter.ini,Hotkey,OntheFly
  HotKey,%otfhotkey%,On
}
else
{
	otfhotkey:=sotfhotkey
	IniWrite,%otfhotkey%,texter.ini,Hotkey,OntheFly
}
If smanagehotkey<>
{
  managehotkey:=smanagehotkey
  Hotkey,%managehotkey%,Manage
  IniWrite,%managehotkey%,texter.ini,Hotkey,Management
  HotKey,%managehotkey%,On
}
else
{	
	managehotkey:=smanagehotkey
	IniWrite,%managehotkey%,texter.ini,Hotkey,Management
}
;code optimization -- calculate MODE from ModeGroup
MODE := ModeGroup - 1
IniWrite,%MODE%,texter.ini,Settings,Mode
IniWrite,%Update%,texter.ini,Preferences,UpdateCheck
If Startup = 1
{
	IfNotExist %A_StartMenu%\Programs\Startup\Texter.lnk
		;Get icon for shortcut link:
		;1st from compiled EXE
		if %A_IsCompiled%
		{
			IconLocation=%A_ScriptFullPath%
		}
		;2nd from icon in resources folder
		else IfExist resources\texter.ico
		{
			IconLocation=resources\texter.ico
		}
		;3rd from the AutoHotkey application itself
		else
		{
			IconLocation=%A_AhkPath%
		}
		;use %A_ScriptFullPath% instead of texter.exe
		;to allow compatibility with source version
		FileCreateShortcut,%A_ScriptFullPath%,%A_StartMenu%\Programs\Startup\Texter.lnk,%A_WorkingDir%,,Text replacement system tray application,%IconLocation%
}
else
{
	IfExist %A_StartMenu%\Programs\Startup\Texter.lnk
	{
		FileDelete %A_StartMenu%\Programs\Startup\Texter.lnk
	}
}
IniWrite,%Startup%,texter.ini,Settings,Startup

Return

SETTINGSCANCEL:
Gui,3:Destroy
if otfhotkey<>
	HotKey,%otfhotkey%,On
if managehotkey <>
	HotKey,%managehotkey%,On
Return

MANAGE:
GoSub,GetFileList
StringReplace, FileList, FileList, .txt,,All
Gui,2: Destroy
Gui,2: font, s12, Arial  
Gui,2: Add, Text,x15 y20, Hotstring:
Gui,2: Add, ListBox, x13 y40 r15 W100 vChoice gShowString Sort,%FileList%
Gui,2: Add,DropDownList,x+20 y15 vTextOrScript, Text||Script
Gui,2: Add, Edit, xp y45 r12 W460 vFullText,
Gui,2: Add, Text,y282 x150,Trigger:
Gui,2: Add, Checkbox, vEnterCbox yp xp+60, Enter
Gui,2: Add, Checkbox, vTabCbox yp xp+65, Tab
Gui,2: Add, Checkbox, vSpaceCbox yp xp+60, Space
Gui,2: font, s8, Arial
Gui,2: Add,Button,w80 GPButtonSave yp x500,&Save
Gui,2: Add, Button,w80 default GPButtonOK x420 yp+80,&OK
Gui,2: Add, Button,w80 xp+90 GPButtonCancel,&Cancel
Gui,2: font, s12, Arial 
Gui,2: Add, Button, w35 x20 y320 GAdd,+
Gui,2: Add, Button, w35 x60 y320 GDelete,-
Gui,2: Show, W600 h400, Texter Management
Hotkey,IfWinActive, Texter Management
Hotkey,Esc,PButtonCancel,On
Hotkey,!p,Preferences
Hotkey,IfWinActive
return

ADD:
Loop,Parse,keys,`, 
{ 
  StringTrimLeft,key,A_LoopField,1 
  StringTrimRight,key,key,1 
  StringLen,length,key 
  If length=0 
    Hotkey,$`,,Off
  Else 
    Hotkey,$%key%,Off
}
GoSub,Newkey
IfWinExist,Add new hotstring...
{
	WinWaitClose,Add new hotstring...,,
}
GoSub,GetFileList
StringReplace, FileList, FileList,|%RString%|,|%RString%||
GuiControl,,Choice,|%FileList%
GoSub,ShowString
Loop,Parse,keys,`, 
{ 
  StringTrimLeft,key,A_LoopField,1 
  StringTrimRight,key,key,1
  StringLen,length,key 
  If length=0 
    Hotkey,$`,,On
  Else 
    Hotkey,$%key%,On
}
return

DELETE:
GuiControlGet,ActiveChoice,,Choice
MsgBox,1,Confirm Delete,Are you sure you want to delete this hotstring: %ActiveChoice%
IfMsgBox, OK
{
	FileDelete,replacements\%ActiveChoice%.txt
	if ActiveChoice in %EnterKeys%
	{
		StringReplace, EnterKeys, EnterKeys, %ActiveChoice%`,,,All
		FileDelete, bank\enter.csv
		FileAppend,%EnterKeys%, bank\enter.csv
		FileRead, EnterKeys, bank\enter.csv
	}
	if ActiveChoice in %TabKeys%
	{
		StringReplace, TabKeys, TabKeys, %ActiveChoice%`,,,All
		FileDelete, bank\tab.csv
		FileAppend,%TabKeys%, bank\tab.csv
		FileRead, TabKeys, bank\tab.csv
	}
	if ActiveChoice in %SpaceKeys%
	{
		StringReplace, SpaceKeys, SpaceKeys, %ActiveChoice%`,,,All
		FileDelete, bank\space.csv
		FileAppend,%SpaceKeys%, bank\space.csv
		FileRead, SpaceKeys, bank\space.csv
	}
	GoSub,GetFileList
	GuiControl,,Choice,|%FileList%
	GuiControl,,FullText,
	GuiControl,,EnterCbox,0
	GuiControl,,TabCbox,0
	GuiControl,,SpaceCbox,0
}
else
	return
return

ShowString:
GuiControlGet,ActiveChoice,,Choice
if ActiveChoice in %EnterKeys%
{
	GuiControl,,EnterCbox,1
}
else
	GuiControl,,EnterCbox,0
if ActiveChoice in %TabKeys%
{
	GuiControl,,TabCbox,1
}
else
	GuiControl,,TabCbox,0
if ActiveChoice in %SpaceKeys%
{
	GuiControl,,SpaceCbox,1
}
else
	GuiControl,,SpaceCbox,0

FileRead, Text, replacements\%ActiveChoice%.txt
IfInString,Text,::scr::
{
	GuiControl,,TextOrScript,|Text|Script||
	StringReplace,Text,Text,::scr::,,
}
else
	GuiControl,,TextOrScript,|Text||Script
GuiControl,,FullText,%Text%
return

PButtonSave:
GuiControlGet,ActiveChoice,,Choice
GuiControlGet,SaveText,,FullText
GuiControlGet,ToS,,TextOrScript
FileDelete, replacements\%ActiveChoice%.txt
if ToS = Text
{
	FileAppend,%SaveText%,replacements\%ActiveChoice%.txt
}
else
{
	FileAppend,::scr::%SaveText%,replacements\%ActiveChoice%.txt
}
GuiControlGet,ActiveChoice,,Choice
GuiControlGet,EnterCbox,,EnterCbox
GuiControlGet,TabCbox,,TabCbox
GuiControlGet,SpaceCbox,,SpaceCbox
Gosub,SAVE
;;
return

PButtonCancel:
Gui,2: Destroy
return

PButtonOK:
Gui, Submit
GuiControlGet,ActiveChoice,,Choice
GuiControlGet,SaveText,,FullText
GuiControlGet,ToS,,TextOrScript
FileDelete, replacements\%ActiveChoice%.txt
if ToS = Text
	FileAppend,%SaveText%,replacements\%ActiveChoice%.txt
else
	FileAppend,::scr::%SaveText%,replacements\%ActiveChoice%.txt

GuiControlGet,ActiveChoice,,Choice
GuiControlGet,EnterCbox,,EnterCbox
GuiControlGet,TabCbox,,TabCbox
GuiControlGet,SpaceCbox,,SpaceCbox
Gosub,SAVE

return

SAVE:
if EnterCbox = 1
{
	if ActiveChoice in %EnterKeys%
	{
	}
	else
	{
		FileAppend,%ActiveChoice%`,, bank\enter.csv
		FileRead, EnterKeys, bank\enter.csv
	}
}
else
{
	if ActiveChoice in %EnterKeys%
	{
		StringReplace, EnterKeys, EnterKeys, %ActiveChoice%`,,,All
		FileDelete, bank\enter.csv
		FileAppend,%EnterKeys%, bank\enter.csv
		FileRead, EnterKeys, bank\enter.csv
	}
}
if TabCbox = 1
{
	if ActiveChoice in %TabKeys%
	{
	}
	else
	{
		FileAppend,%ActiveChoice%`,, bank\tab.csv
		FileRead, TabKeys, bank\tab.csv
	}
}
else
{
	if ActiveChoice in %TabKeys%
	{
		StringReplace, TabKeys, TabKeys, %ActiveChoice%`,,,All
		FileDelete, bank\tab.csv
		FileAppend,%TabKeys%, bank\tab.csv
		FileRead, TabKeys, bank\tab.csv
	}

}
if SpaceCbox = 1
{
	if ActiveChoice in %SpaceKeys%
	{
	}
	else
	{
		FileAppend,%ActiveChoice%`,, bank\space.csv
		FileRead, SpaceKeys, bank\space.csv
	}
}
else
{
	if ActiveChoice in %SpaceKeys%
	{
		StringReplace, SpaceKeys, SpaceKeys, %ActiveChoice%`,,,All
		FileDelete, bank\space.csv
		FileAppend,%SpaceKeys%, bank\space.csv
		FileRead, SpaceKeys, bank\space.csv
	}

}
return

RESOURCES:
;code optimization -- removed IfNotExist tests
;redundant when final arg to FileInstall is 0
FileInstall,resources\texter.ico,%A_ScriptDir%\resources\texter.ico,1
FileInstall,resources\replace.wav,%A_ScriptDir%\resources\replace.wav,0
FileInstall,resources\texter.png,%A_ScriptDir%\resources\texter.png,1
FileInstall,resources\style.css,%A_ScriptDir%\resources\style.css,0
return

;AUTOCLOSE:
;:*?B0:(::){Left}
;:*?B0:[::]{Left}
;:*?B0:{::{}}{Left}
;return

PrintableList:
alt := 0
List = <html xmlns="http://www.w3.org/1999/xhtml"><head><link type="text/css" href="style.css" rel="stylesheet"><title>Texter Hotstrings and Replacement Text Cheatsheet</title></head><body><h2>Texter Hostrings and Replacement Text Cheatsheet</h2><span class="hotstring" style="border:none`; color:black`;"><h3>Hotstring</h3></span><span class="replacement" style="border:none`;"><h3>Replacement Text</h3></span><span class="trigger" style="border:none`;"><h3>Trigger(s)</h3></span>
Loop, replacements\*.txt
{
	alt := 1 - alt
	trig =
	hs = %A_LoopFileName%
	StringReplace, hs, hs, .txt
	FileRead, rp, replacements\%hs%.txt
	If hs in %EnterKeys%
		trig = Enter
	If hs in %TabKeys%
		trig = %trig% Tab
	If hs in %SpaceKeys%
		trig = %trig% Space
	StringReplace, rp, rp, <,&lt;,All
	StringReplace, rp, rp, >,&gt;,All
	List = %List%<div class="row%alt%"><span class="hotstring">%hs%</span><span class="replacement">%rp%</span><span class="trigger">%trig%</span></div><br />
	
}
List = %List%</body></html>
IfExist resources\Texter Replacement Guide.html
	FileDelete,resources\Texter Replacement Guide.html
FileAppend,%List%, resources\Texter Replacement Guide.html
Run,resources\Texter Replacement Guide.html
return


UpdateCheck: ;;;;;;; Update the version number on each new release ;;;;;;;;;;;;;
IfNotExist texter.ini 
{
	MsgBox,4,Check for Updates?,Would you like to automatically check for updates when on startup?
	IfMsgBox,Yes
		updatereply = 1
	else
		updatereply = 0
}
update := GetValFromIni("Preferences","UpdateCheck",updatereply)
IniWrite,0.3,texter.ini,Preferences,Version
if (update = 1)
	SetTimer,RunUpdateCheck,10000
return

RunUpdateCheck:
update("texter")
return

update(program) {
	SetTimer, RunUpdateCheck, Off
	UrlDownloadToFile,http://svn.adampash.com/%program%/CurrentVersion.txt,VersionCheck.txt
	if ErrorLevel = 0
	{
		FileReadLine, Latest, VersionCheck.txt,1
		IniRead,Current,%program%.ini,Preferences,Version
		;MsgBox,Latest: %Latest% `n Current: %Current%
		if (Latest > Current)
		{
			MsgBox,4,A new version of %program% is available!,Would you like to visit the %program% homepage and download the latest version?
			IfMsgBox,Yes
				Goto,Homepage
		}
		FileDelete,VersionCheck.txt ;; delete version check
	}
}

return
EXIT: 
ExitApp 
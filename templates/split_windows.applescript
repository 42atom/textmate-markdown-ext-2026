#!/usr/bin/osascript

tell application "TextMate"
	activate
	set editor_id to id of front window
	set original_bounds to bounds of front window
end tell

set x1 to item 1 of original_bounds
set y1 to item 2 of original_bounds
set x2 to item 3 of original_bounds
set y2 to item 4 of original_bounds
set editor_width to (x2 - x1)
set gap to 6

-- Trigger Markdown preview: menu click first, shortcut fallback.
set trigger_ok to false
try
	tell application "System Events"
		tell process "TextMate"
			click menu item "Show Preview" of menu 1 of menu item "Markdown" of menu 1 of menu bar item "Bundles" of menu bar 1
			set trigger_ok to true
		end tell
	end tell
end try

if trigger_ok is false then
	try
		delay 0.12
		tell application "System Events"
			tell process "TextMate"
				key code 35 using {control down, option down, command down}
			end tell
		end tell
		delay 0.12
		set trigger_ok to true
	end try
end if

delay 0.12

-- Resolve preview window (first pass).
set preview_id to missing value
repeat with i from 1 to 80
	tell application "TextMate"
		repeat with w in windows
			if (id of w) is not editor_id then
				set wname to name of w
				if (wname contains "Preview") or (wname contains "预览") then
					set preview_id to id of w
					exit repeat
				end if
			end if
		end repeat
	end tell
	if preview_id is not missing value then
		exit repeat
	end if
	delay 0.05
end repeat

-- Keep A fixed, place B to the right with same width, focus back to A.
tell application "TextMate"
	set bounds of (first window whose id is editor_id) to original_bounds
	
	if preview_id is not missing value then
		set bx1 to x2 + gap
		set bx2 to bx1 + editor_width
		set bounds of (first window whose id is preview_id) to {bx1, y1, bx2, y2}
	end if
	
	set index of (first window whose id is editor_id) to 1
	activate
end tell

-- Workaround: synthetic no-op edit (space + backspace) to force auto-refresh,
-- equivalent to the manual "press space once" that makes CSS appear.
try
	tell application "System Events"
		tell process "TextMate"
			key code 49
			key code 51
		end tell
	end tell
on error
	-- Ignore if editor is read-only; split still works.
end try

delay 0.18

-- Resolve and align again after refresh nudge.
set preview_id to missing value
repeat with i from 1 to 80
	tell application "TextMate"
		repeat with w in windows
			if (id of w) is not editor_id then
				set wname to name of w
				if (wname contains "Preview") or (wname contains "预览") then
					set preview_id to id of w
					exit repeat
				end if
			end if
		end repeat
	end tell
	if preview_id is not missing value then
		exit repeat
	end if
	delay 0.05
end repeat

tell application "TextMate"
	set bounds of (first window whose id is editor_id) to original_bounds
	
	if preview_id is not missing value then
		set bx1 to x2 + gap
		set bx2 to bx1 + editor_width
		set bounds of (first window whose id is preview_id) to {bx1, y1, bx2, y2}
	end if
	
	set index of (first window whose id is editor_id) to 1
	activate
end tell

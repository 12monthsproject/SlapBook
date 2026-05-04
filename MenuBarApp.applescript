-- SlapBook 菜单栏控制器
-- 使用 AppleScript 创建菜单栏图标

property statusItem : missing value
property isRunning : false
property currentPack : "sexy"
property packNames : {sexy:"💋 女声娇喘", yamete:"🇯🇵 Yamete", male:"🔥 男声嚎叫", punch:"🥊 拳击音效", fart:"💨 放屁", goat:"🐐 山羊", number:"🔢 计数"}
property packKeys : {"sexy", "yamete", "male", "punch", "fart", "goat", "number"}

on run
	-- 读取当前配置
	try
		set configFile to "/tmp/slapbook_config.txt"
		set currentPack to (do shell script "cat " & quoted form of configFile) as string
	end try
	
	-- 创建状态栏项目
	tell application "System Events"
		tell application process "SystemUIServer"
			set statusItem to make new status bar item at end of status bar 1
			set title of statusItem to "💋"
		end tell
	end tell
	
	-- 设置点击处理
	-- 注意：AppleScript 状态栏有限制，使用对话框代替
	
	repeat
		try
			tell application "System Events"
				if exists statusItem then
					-- 检查点击（通过检测标题变化或其他方式）
				end if
			end tell
		end try
		delay 1
	end repeat
end run

on quit
	try
		tell application "System Events"
			tell application process "SystemUIServer"
				if exists statusItem then delete statusItem
			end tell
		end tell
	end try
	continue quit
end quit

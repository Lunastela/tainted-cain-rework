-- I stole this from Headcrab, who stole it from DSS repo, but I stole it from Headcrab
local mod = TCainRework
local SaveManager = require('scripts.save_manager')

local menuSaveData = (SaveManager.GetDeadSeaScrollsSave() and SaveManager.GetDeadSeaScrollsSave().saveData) or {}
local function getSaveWrapper()
    local dssSave = SaveManager.GetDeadSeaScrollsSave()
    if dssSave then
        menuSaveData = dssSave.saveData or {}
        return menuSaveData
    end
end

local function storeSaveData()
    local dssSave = SaveManager.GetDeadSeaScrollsSave()
    dssSave.saveData = menuSaveData
end

local DSSModName = "Dead Sea Scrolls (Tainted Cain Rework)"
local MenuProvider = {}
function MenuProvider.SaveSaveData()
    storeSaveData()
end

function MenuProvider.GetPaletteSetting()
    return getSaveWrapper().MenuPalette
end

function MenuProvider.SavePaletteSetting(var)
    getSaveWrapper().MenuPalette = var
end

function MenuProvider.GetHudOffsetSetting()
    if not REPENTANCE then
        return getSaveWrapper().HudOffset
    else
        return Options.HUDOffset * 10
    end
end

function MenuProvider.SaveHudOffsetSetting(var)
    if not REPENTANCE then
        getSaveWrapper().HudOffset = var
    end
end

function MenuProvider.GetGamepadToggleSetting()
    return getSaveWrapper().GamepadToggle
end

function MenuProvider.SaveGamepadToggleSetting(var)
    getSaveWrapper().GamepadToggle = var
end

function MenuProvider.GetMenuKeybindSetting()
    return getSaveWrapper().MenuKeybind
end

function MenuProvider.SaveMenuKeybindSetting(var)
    getSaveWrapper().MenuKeybind = var
end

function MenuProvider.GetMenuHintSetting()
    return getSaveWrapper().MenuHint
end

function MenuProvider.SaveMenuHintSetting(var)
    getSaveWrapper().MenuHint = var
end

function MenuProvider.GetMenuBuzzerSetting()
    return getSaveWrapper().MenuBuzzer
end

function MenuProvider.SaveMenuBuzzerSetting(var)
    getSaveWrapper().MenuBuzzer = var
end

function MenuProvider.GetMenusNotified()
    return getSaveWrapper().MenusNotified
end

function MenuProvider.SaveMenusNotified(var)
    getSaveWrapper().MenusNotified = var
end

function MenuProvider.GetMenusPoppedUp()
    return getSaveWrapper().MenusPoppedUp
end

function MenuProvider.SaveMenusPoppedUp(var)
    getSaveWrapper().MenusPoppedUp = var
end

local dssMenuCore = include("scripts.dssmenucore")
local deadSeaScrollsMod = dssMenuCore.init(DSSModName, MenuProvider)

local displayName = "T. Cain Rework"
local cainCraftingDirectory = {
    main = {
        title = string.lower(displayName),
        buttons = {
            { str = 'resume game', action = 'resume' },
            { str = 'settings',    dest = 'settings' },
            { str = 'credits',    dest = 'credits' },
            deadSeaScrollsMod.changelogsButton,
        },
        tooltip = deadSeaScrollsMod.menuOpenToolTip
    },
    settings = {
        title = 'settings',
        buttons = {
            deadSeaScrollsMod.gamepadToggleButton,
            deadSeaScrollsMod.menuKeybindButton,
        }
    },
    rgonpopup = {
		title = "lazy mattpack",
		fsize = 1,
		buttons = {
            {str = "repentogon required", nosel = true, fsize = 2},
            {str = "", nosel = true},
			{str = "sorry! the lazy mattpack", nosel = true},
			{str = "cannot run without repentogon", nosel = true},
			{str = "", nosel = true},
			{str = "this unfortunately means that it", nosel = true},
			{str = "is currently incompatible with", nosel = true},
			{str = "repentance+", nosel = true},
            {str = "", nosel = true},
			{str = "repentogon can be installed", nosel = true},
			{str = "at repentogon.com", nosel = true},
            {str = "", nosel = true},
			{
				str = "i understand",
				action = "resume",
				fsize = 3,
				glowcolor = 3,
			},
		},
	},
}

local cainCraftingDirectoryKey = {
    Item = cainCraftingDirectory.main,
    Main = 'main',
    Idle = false,
    MaskAlpha = 1,
    Settings = {},
    SettingsChanged = false,
    Path = {},
}

DeadSeaScrollsMenu.AddMenu(displayName, {
    Run = deadSeaScrollsMod.runMenu,
    Open = deadSeaScrollsMod.openMenu,
    Close = deadSeaScrollsMod.closeMenu,
    UseSubMenu = false,
    Directory = cainCraftingDirectory,
    DirectoryKey = cainCraftingDirectoryKey
})

include("scripts.tcainrework.changelogs")
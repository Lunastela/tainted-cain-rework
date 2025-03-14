local modName = "T. Cain Rework"
DeadSeaScrollsMenu.AddChangelog(modName, "v1.0", 
[[Initial release.
]])

DeadSeaScrollsMenu.AddChangelog(modName, "v1.1", 
[[- Added a setting to fade the HUD
when in a boss fight

- Added Eric's Tagline after he 
reminded me again 

- Added recipes for Eye Sore, How to Jump, 
Gamekid, Old Bandage, Everything Jar and
a Yum Heart alternate recipe

Bug Fixes:
- Fixed Lost Soul causing you to
drop your inventory when it dies

- Fixed Mouse Controls with the
Bag of Crafting

- Technically changed the thumbnail
so it would stop being so small
on the Steam Workshop

- Removed Herobrine
]])

DeadSeaScrollsMenu.AddChangelog(modName, "v1.2", 
[[- Fixed the candle recipes being flipped

- Fixed fonts not displaying if the player
had luadebug enabled

- Fixed Issue on Intel GPUs that caused 
shaders to be abhorrently buggy

- Fixed items not rendering on 
Steam Deck and Linux

- Display mod version in Dead Sea Scrolls

- Removed Herobrine
]])

DeadSeaScrollsMenu.AddChangelog(modName, "v1.3", 
[[- Added Graphics settings in 
the Dead Sea Scrolls menu

- Redistributed salvage item weights

- Fixed a bug where salvage would
happen randomly

- Fixed dropping items
not updating recipes properly

- fixed a visual glitch with
the dead sea scrolls menu
where the text wasn't 
highlighting when hovering
over it

- New Recipes for the following:

Ceremonial Robes
Necronomicon
Soy Milk
Number One
Free Lemonade
Spear of Destiny
IV Bag

And more!

- Removed Herobrine

- Does anyone actually read these?
]])

-- Return latest version
for _, changelogList in pairs(DeadSeaScrollsMenu.Changelogs.List) do
    if (changelogList.Name == string.lower(modName)) then
        return (changelogList.List[#changelogList.List].Name)
    end
end
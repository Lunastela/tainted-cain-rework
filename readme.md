<h1 align="center">Tainted Cain Rework</h1>
<p align="center"> My most ambitious project yet.</p>

## About <a name = "about"></a>

This is easily my most ambitious project yet. Completely overhauls Tainted Cain in ways I can only begin to describe below.

I have officially gone insane.

## Features <a name = "features"></a>
- Fully Fledged Inventory System.
  - ITEM REGISTRIES:
    - The ability to create custom items with a single lua file
    - Item Tags within item definitions for recipe use
    - ITEM GENERICS. CARDS, PILLS, COLLECTIBLES
    - COMPONENT / NBT DATA ALONGSIDE!!!
    - MOD SUPPORT. 
      - CUSTOM LOAD ORDERS!!! 
      - MODDED ITEM SUPPORT!!!
  - MOUSE CONTROLS!!!
  - Multiple Inventory Support
  - IF YOU REALLY WANTED YOU COULD ADD MORE WORKSTATIONS???
  - Inventory setup, render functions, generics??? Custom Inventories???
  - slots
    - slots
      - slots
  - item snaking / reconvening / other various things from The game
  - RECIPE BOOK SUPPORT
    - FULL RECIPE INTEGRATION. UNLOCKING ITEMS VIA COLLECTION / TAGS OR INTERACTION
    - recipe previews
    - autocrafting
    - item tag previews that reset when you press the button
  - JSON TO LUA for THINECRAFT RECIPES
  - technically i made that texture to glsl table too but that sucks and is unused so dont pay it any attention
- FULL BAG OF CRAFTING REIMPLEMENTATION
  - Define component data / items based on entity sources
  - Allow grid entities to enter the bag of crafting IF YOU WANTED TO
  - Disallow things going in when the bag is full because I DONT WASTE YOUR SPACE
- 3D ITEM RENDERING
  - raymarched 3d items for items that are dropped from the inventory or blocks
  - full support for enchanted items and other things like animated items
- LOTS OF STUFF I ALREADY FORGOT

THIS WAS REALLY COMPLICATED SORRY IM SUPER PROUD OF IT
## Philosophy <a name = "philosophy"></a>

The philosophy behind this project shifted several times throughout its development. At first, the idea came to me during a road trip where I thought to myself that it would be funny if someone made a mod where Tainted Cain was given the Minecraft Crafting Table UI. 

I quickly realized that was stupid, as Cain's Bag of Crafting uses 8 slots, while Minecraft's Crafting Table uses 9. Alas, I wanted to attempt it anyways, because I thought it was funny. I didn't get around to, until I told some friends about the idea. I framed it as an idea that I had scrapped, because it wasn't as funny to me as it was originally when I realized Cain's crafting uses 8 slots instead. They, instead, said I should make it anyways because it "would be funny." 

The original idea was to create a wrapper for Tainted Cain. I started by using Repentogon's systems to hook into the Bag of Crafting and empty the contents of it. The original item registry was just numeric IDs correlated to the Isaac ones. All it was, was an inventory with a wrapper. The inventory itself was neatly robust, but the item system wasn't anything special. Interestingly, the inventory at that point did not have any of the major features it does now, such as what I call snaking and reconvening. I spent a good chunk of time working on recreating behaviors from Minecraft such as those, analyzing and trying to see if I could emulate them without looking at the source code. I learned things I did not want to about how Minecraft operates under the hood, things no man or woman (meee :3) should know about.

When I finished the inventory, I dreaded the idea of adding a genuine Crafting system, so instead I would procrastinate by fixating over every detail. First it was reworking internals to make Reconvening more accurate (wow, was I wrong), and then working on emulating accurate snaking behaviors. I've taken a liking to these behaviors, and therefore assigned them names that I thought were adequate and sounded quite pleasant. **Reconvening** is shorthand for the ability to double click with the left mouse button to gather a stack of items, whilst **Snaking** is the ability to drag a mouse through multiple cells of the inventory to distribute its contents.

When all was said and done, I wanted to work on items themselves. I didn't really like the limitations the Bag of Crafting had, and REPENTOGON provided no functions to change any of its parameters. Like any Isaac modder, I naturally decided to reimplement it entirely with some changes that made it well worth the decision. The biggest reasons were solely the fact that I could not stop anything from going into the bag when the Inventory was full, and that I could not extract any information from the items themselves other than the basic BoC Item Ids that they used when they were transported into the bag. Instead, I spent a sizeable amount of time creating a modular item system that would let me recreate the effects and systems of putting an item into the bag, with more separations and other things. This created the first shift in my design philosophy; the addition of more items. Instead of just making a wrapper for the Bag of Crafting, I wanted to do more with it, create more recipes among other things. I moved forwards with the systems, eventually iterating them to the point they're at today, allowing for great things like conditionals and providing NBT / Component data alongside conditionals.

The addition of more items, alongside the lack of control I had with the Bag of Crafting made me decide to take drastic measures: I was no longer just making a wrapper for the original recipes. This was partly because I either wanted complete parity with the original system, or to throw it away entirely. After all, with the regular inventory, on average the player would have around 57x more storage space. When the player can hold (over) 581.81x more (condensed) pennies than they would regularly be able to, why should I bother with respecting the original system.

Naturally, I needed to *actually* make recipes work first, which I had no idea how to. It took me a little bit of research to find out nobody actually did, for some reason? So here's my explanation of how Minecraft handles shaped recipes: A list of ingredients create a pattern based on a key and some values, this isn't hard to figure out by just looking at any .json file provided to us by Mojang. What's hard is understanding how the game actually reads the recipes. I figured out that the recipe is read from the top left filled corner to the bottom right filled corner. This means you can fill out patterns that are 2x2 or 1x2 in any space of the table, without making them necessarily shapeless.

In fact, it was a lot easier to figure out shaped recipes than it was to figure out shapeless, for some reason. Shapeless recipes are more chaotic, but my solution for them is personally to *sort the recipe*. Doesn't matter what, as long as it's consistent with *sorting the crafting table as well.* My systems use hashing to sift through a more narrow lens of recipes, and I provide a sorted hash for shapeless recipes and a shape hash for shaped recipes.

I do not recommend doing this. Originally, before Item Tags, I used to provide a hash based on every single item type in the crafting table as well as in the recipe. This way, I did not need to actually match the components, I could quickly glance and put the hash into a map that would retrieve the results of the table. When it came time to add Item Tags, I realized that the one way nature of this meant that I would either have to scrap this system altogether, or create a hash for ***every single combination of items and their possible tags.*** This is bad for OBVIOUS REASONS, so I came up with a really cool middle ground that would, instead, hash the amount of unique types in a recipe. That's great and all, but I clearly didn't understand the assignment, because that creates ***the same issue.*** I am still unable to create a one way transaction that finds the recipe based on one calculation put into a table. I ended up with a middle ground system, one that takes a *shape hash* instead, and provides a table of recipes that fulfill that same hash. This is simple enough, and doesn't need to be hashed, but I still do it because I'm jaded and feel sunk cost fallacy.

The original hash is still used to compare the state of the crafting table to the previous state to ensure that no changes were made during any frame.

When recipes were finished, I was very proud of them, especially with my solution for shapeless recipes. Unfortunately, there was no way to actually view recipes, and my need to add unique recipes for every item meant that it would become incredibly hard for people to actually *find* recipes in the mod. I bit the bullet, and decided I should add the recipe book.

The recipe book opened my eyes, in terms of game design. I figured what I could do with it, I realized that I could hold the player's hand and even force them to experiment a little by limiting their scope. I came up with the idea to force unlock a recipe when salvaging an item, just to encourage and let the player know there was more out there, even when they thought they knew everything you could do with an item. I wanted to encourage both chaos and order, and lots of experimentation in early runs, as well as strategy in late runs. I just had to implement the damn thing. I spent so much time worrying about how long it would take to implement, that I ended up procrastinating until one day I decided to finally do it. It did not take long. That's the thing about programming, the hardest part is always thinking about doing something. Implementing the recipe book was a rollercoaster. At the time of writing, I for some reason decided to scrap sustainability and attempt to "optimize" the recipe book by calculating recipe availability in unconventional ways. At first, recipes would make a list of all items in the inventory and then subtract their components from this list. This worked well enough, until I decided to add item tags. It all went downhill from there...

Item tags were frustrating. I had to restructure the way the recipe book worked for reasons related to subtracting from *the wrong items.* This was more of an oversight with craftability, but the wrong item order could make it look like some other items weren't craftable. Eventually fixing this, I realized that the auto crafting feature, the worst part of the recipe book, would naively try to put the first thing it found into the table. I thought this was okay, until I added item tags, which MEANT the item tags could EMPTY the actual components before they were able to be used. This meant the recipe book also displayed inaccurate "craftable" states, as it would think a tag and ingredients were fulfilled, but they weren't because it was using ***THE SAME ITEMS TO FILL THEM OUT.*** I figured out that I could sort the necessary ingredients by lowest to highest in terms of item tags themselves, with lowest being individual item types and highest being the largest item tags, but this did not fix the top to bottom issue. To fix the top to bottom issue, I had to implement an item tag sorting system, and rework autocrafting entirely to sort through the inventory and attempt to find the cheapest ingredients it could find for something before trying to craft it with anything else. And of course, I had to subtract the used ones from the total count, can't have inaccuracies plaguing the recipe book. Needless to say, completely tedious and incredibly painful experience that left me wanting to tear my hair out. To this day, I still don't sort inventories properly because I try to find the least expensive items *per inventory,* which means that if you place your less expensive items in the hotbar, the main inventory will still try to use everything else beforehand (yes, I'm going to work on it eventually).

The original hash is still used to compare the state of the crafting table to the previous state to ensure that no changes were made 
After item tags, then came the second biggest hurdle: component data in recipes. Minecraft itself doesn't support this, but I figured I could probably parse a json when gathering an item. This took some restructuring to do, mostly in the department of detecting when an item was useable by the recipe book (I do this by appending important values to the end of the item to trick the recipe book into thinking they are separate items. Yeah, I don't know why I didn't just do the recipe book the naive way instead of trying to be a smartass).
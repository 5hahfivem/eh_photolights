# Hello, Thanks for installing my resource!

This resource is a simple photo lights script. It allows you to drop lights and place them on the map. You can then use the target to change the colour of the light or to pick it up.

## Installation
1. Extract the resource to your resources folder.  
2. Add the resource to your `server.cfg` file.  

## Usage
1. Use the item set in `config.lua` to initiate a drop, then follow the TextUI to place/rotate the light.  
2. Use the target to change the colour of the light.  

## Configuration
You can configure the items that are available in the resource by editing the `config.lua` file in the resource folder.

## Item Installation

```lua
photolights = {
    label = 'Studio Lamp',
    weight = 100,
    description = 'A simple photo light.',
    client = {
        image = 'https://items.bit-scripts.com/images/tech/light.png',
    }
},
tripodlight = {
    label = 'Tripod Light',
    weight = 100,
    description = 'A simple tripod photo light.',
    client = {
        image = 'https://items.bit-scripts.com/images/general/worklight.png',
    }
},
```

---

## A Small Note
I put time and effort into making this resource, so please:  
- Don’t rename it.  
- Don’t remove the credits.  
- Be cool and respect the work.  

Thanks for using it, and I hope it helps make your server a little brighter ✨

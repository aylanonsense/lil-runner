-- Load dependencies
local Moat = require('https://raw.githubusercontent.com/revillo/castle-dungeon/master/moat.lua')

-- Render constants
local GAME_WIDTH = 192
local GAME_HEIGHT = 192
local RENDER_SCALE = 3

-- Game constants
local PLATFORM_WIDTH = 60
local SCROLL_SPEED = 80
local DUCK_START_X = 10
local DUCK_COLORS = {
  { 254 / 255, 253 / 255, 56 / 255 },
  { 205 / 255, 34 / 255, 150 / 255 },
  { 12 / 255, 132 / 255, 208 / 255 },
  { 251 / 255, 238 / 255, 230 / 255 },
  { 35 / 255, 175 / 255, 77 / 255 },
  { 239 / 255, 59 / 255, 9 / 255 }
}

-- Game variables
local rightmostPlatform

-- Assets
local duckImage
local spikesImage
local jumpSounds
local bumpSound
local spikeShound

-- Define a unique ID for each type of entity
local ENTITY_TYPES = {
  Player = 0,
  Platform = 1,
  Spike = 2
}

-- Define some constants that configure the way Moat works
local MOAT_CONFIG = {
  TickInterval = 1.0 / 60.0,
  WorldSize = math.max(GAME_WIDTH, GAME_HEIGHT),
  ClientVisibility = math.max(GAME_WIDTH, GAME_HEIGHT)
}

-- Create a new game using Moat, which allows for networked online play
local moat = Moat:new(ENTITY_TYPES, MOAT_CONFIG)

-- Initialize the game
function moat:serverInitWorld(state)
  for i = 0, 1 + GAME_WIDTH / PLATFORM_WIDTH do
    rightmostPlatform = moat:spawn(ENTITY_TYPES.Platform, i * PLATFORM_WIDTH, GAME_HEIGHT - 48, PLATFORM_WIDTH, 48, {
      isHole = false
    })
  end
end
function moat:serverOnClientConnected(clientId)
  moat:serverSpawnPlayer(clientId, DUCK_START_X, 80, 9, 9, {
    vx = 3,
    vy = 0,
    maxX = DUCK_START_X,
    isOnGround = false,
    numMidairJumps = 0,
    walkTimer = 0.00,
    invincibilityTimer = 0.00
  })
end
function moat:clientLoad()
  -- Load assets
  duckImage = love.graphics.newImage('../img/duck.png')
  spikesImage = love.graphics.newImage('../img/spikes.png')
  duckImage:setFilter('nearest', 'nearest')
  spikesImage:setFilter('nearest', 'nearest')
  jumpSounds = {
    love.audio.newSource('../sfx/jump-1.wav', 'static'),
    love.audio.newSource('../sfx/jump-2.wav', 'static'),
    love.audio.newSource('../sfx/jump-3.wav', 'static')
  }
  bumpSound = love.audio.newSource('../sfx/bump.wav', 'static')
  spikeShound = love.audio.newSource('../sfx/spike.wav', 'static')
end

-- Update the game state
function moat:worldUpdate(dt)
  -- Move platforms to the left
  self:eachEntityOfType(ENTITY_TYPES.Platform, function(platform)
    platform.x = platform.x - SCROLL_SPEED * dt
    moat:moveEntity(platform)
  end)

  -- Move spikes to the left
  self:eachEntityOfType(ENTITY_TYPES.Spike, function(spike)
    spike.x = spike.x - SCROLL_SPEED * dt
    moat:moveEntity(spike)
    if spike.x < -10 then
      moat:despawn(spike)
    end
  end)
end
function moat:serverUpdate(dt)
  -- Platforms that move off the left side of the screen become new platforms on the right side of the screen
  self:eachEntityOfType(ENTITY_TYPES.Platform, function(platform)
    if platform.x + platform.w < 0 then
      platform.x = rightmostPlatform.x + rightmostPlatform.w
      -- Randomize the platform's height
      local height = rightmostPlatform.h
      if math.random() < 0.8 then
        height = math.min(math.max(24, height + (math.random() < 0.5 and -16 or 16)), 88)
      end
      platform.h = height
      platform.y = GAME_HEIGHT - platform.h
      platform.isHole = not rightmostPlatform.isHole and math.random() < 0.2
      rightmostPlatform = platform
      -- Use this opportunity to spawn some spikes
      if not platform.isHole and math.random() < 0.22 then
        local numSpikes = math.random(3, 5)
        local x = rightmostPlatform.x + rightmostPlatform.w / 2 + -2.5
        local y = rightmostPlatform.y - 11
        local arrangeVertically = math.random() < 0.5
        for i = 0, numSpikes - 1 do
          moat:spawn(ENTITY_TYPES.Spike, x + (arrangeVertically and 0 or 8 * (i + 0.5 - numSpikes / 2)), y - (arrangeVertically and 8 * i or 0), 7, 7)
        end
      end
    end
    moat:moveEntity(platform)
  end)
end
-- Press space to make the duck jump (or double jump [or triple jump])
function moat:clientKeyPressed(key)
  if key == 'space' then
    self:clientSetInput({ jump = true })
  end
end
function moat:clientUpdate(dt)
  self:clientSetInput({ jump = false })
end
function moat:playerUpdate(duck, input, dt)
  -- Update the duck's timers
  duck.walkTimer = duck.walkTimer + dt
  duck.invincibilityTimer = math.max(0.00, duck.invincibilityTimer - dt)

  -- Press space to make the duck jump (or double jump [or triple jump])
  if input.jump and not duck.isBeingBumped then
    if duck.isOnGround then
      duck.vy = -210
      duck.isOnGround = false
      -- love.audio.play(jumpSounds[1]:clone())
    elseif duck.numMidairJumps == 2 then
      duck.vy = -145
      duck.numMidairJumps = 1
      -- love.audio.play(jumpSounds[2]:clone())
    elseif duck.numMidairJumps == 1 then
      duck.vy = -80
      duck.numMidairJumps = 0
      -- love.audio.play(jumpSounds[3]:clone())
    end
  end

  -- Update the duck's position
  local wasOnGround = duck.isOnGround
  duck.isOnGround = false
  duck.vy = duck.vy + (duck.isBeingBumped and 200 or 400) * dt
  duck.x = math.max(DUCK_START_X, duck.x + (duck.isBeingBumped and -25 or duck.vx) * dt)
  duck.y = duck.y + math.min(duck.vy * dt, 4.5)
  if duck.y > GAME_HEIGHT then
    bumpDuck(duck)
  end
  moat:moveEntity(duck)

  -- Keep track of how far the duck has gotten
  duck.maxX = math.max(duck.x, duck.maxX)

  -- Check for collisions with the ground and with spikes
  self:eachOverlapping(duck, function(entity)
    if entity.type == ENTITY_TYPES.Platform and not entity.isHole and duck.vy > 0 then
      -- Allow the duck to stand on the platform
      if duck.isBeingBumped or duck.y + duck.h < entity.y + 5 or duck.invincibilityTimer > 0.00 then
        duck.y = entity.y - duck.h
        duck.isBeingBumped = false
        duck.vy = 0
        duck.isOnGround = true
        duck.numMidairJumps = 2
        if not wasOnGround then
          duck.walkTimer = 0.00
        end
      -- But if the duck is too far below the platform, bump it backward
      else
        bumpDuck(duck)
        -- love.audio.play(bumpSound:clone())
      end
      moat:moveEntity(duck)
    elseif entity.type == ENTITY_TYPES.Spike and duck.invincibilityTimer <= 0.00 then
      -- Spike collisions bump the duck backwards
      bumpDuck(duck)
      -- love.audio.play(spikeShound:clone())
    end
    moat:moveEntity(duck)
  end)
end

-- Render the game
function moat:clientDraw()
  -- Scale and crop the screen
  love.graphics.setScissor(0, 0, RENDER_SCALE * GAME_WIDTH, RENDER_SCALE * GAME_HEIGHT)
  love.graphics.scale(RENDER_SCALE, RENDER_SCALE)
  love.graphics.clear(252 / 255, 147 / 255, 1 / 255)

  -- Draw the platforms and spikes
  love.graphics.setColor(91 / 255, 20 / 255, 3 / 255)
  self:eachEntityOfType(ENTITY_TYPES.Platform, function(platform)
    if not platform.isHole then
      love.graphics.rectangle('fill', platform.x, platform.y, platform.w, platform.h)
    end
  end)
  self:eachEntityOfType(ENTITY_TYPES.Spike, function(spike)
    drawSprite(spikesImage, 7, 7, 1, spike.x, spike.y)
  end)

  -- Draw the ducks
  self:eachEntityOfType(ENTITY_TYPES.Player, function(duck)
    local sprite
    if duck.isBeingBumped then
      sprite = 7
    elseif duck.isOnGround then
      if duck.walkTimer < 0.08 then
        sprite = 4
      elseif duck.walkTimer % 0.32 < 0.08 then
        sprite = 2
      elseif duck.walkTimer % 0.32 < 0.16 then
        sprite = 3
      else
        sprite = 1
      end
    elseif duck.vy > 0 then
      sprite = 6
    else
      sprite = 5
    end
    if duck.invincibilityTimer % 0.2 < 0.15 then
      love.graphics.setColor(DUCK_COLORS[1 + (duck.clientId % #DUCK_COLORS)])
      -- Draw the duck
      drawSprite(duckImage, 16, 16, sprite, duck.x - 4, duck.y - 7)
      -- Draw the lines showing how far the duck has gotten
      love.graphics.rectangle('fill', duck.x, 0, 1, 5)
      love.graphics.rectangle('fill', duck.maxX, 0, 2, 10)
    end
  end)
end

-- Bumps the duck backwards (after it collides with an obstacle)
function bumpDuck(duck)
  duck.y = math.min(duck.y - 5, GAME_HEIGHT - 25)
  duck.vy = -220
  duck.isBeingBumped = true
  duck.invincibilityTimer = 3.50
end

-- Draws a sprite from a sprite sheet, spriteNum=1 is the upper-leftmost sprite
function drawSprite(spriteSheetImage, spriteWidth, spriteHeight, sprite, x, y, flipHorizontal, flipVertical, rotation)
  local width, height = spriteSheetImage:getDimensions()
  local numColumns = math.floor(width / spriteWidth)
  local col, row = (sprite - 1) % numColumns, math.floor((sprite - 1) / numColumns)
  love.graphics.draw(spriteSheetImage,
    love.graphics.newQuad(spriteWidth * col, spriteHeight * row, spriteWidth, spriteHeight, width, height),
    x + spriteWidth / 2, y + spriteHeight / 2,
    rotation or 0,
    flipHorizontal and -1 or 1, flipVertical and -1 or 1,
    spriteWidth / 2, spriteHeight / 2)
end

-- Run the game
moat:run()

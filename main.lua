-- Render constants
local GAME_WIDTH = 192
local GAME_HEIGHT = 192
local RENDER_SCALE = 3

-- Game constants
local PLATFORM_WIDTH = 60
local SCROLL_SPEED = 80
local DUCK_START_X = 15

-- Game variables
local duck
local spikes
local platforms
local rightmostPlatform

-- Assets
local duckImage
local spikesImage
local jumpSounds
local wallHitSound
local spikeHitSound

-- Initialize the game
function love.load()
  -- Load assets
  duckImage = love.graphics.newImage('img/duck.png')
  duckImage:setFilter('nearest', 'nearest')
  spikesImage = love.graphics.newImage('img/spikes.png')
  spikesImage:setFilter('nearest', 'nearest')
  jumpSounds = {
    love.audio.newSource('sfx/jump-1.wav', 'static'),
    love.audio.newSource('sfx/jump-2.wav', 'static'),
    love.audio.newSource('sfx/jump-3.wav', 'static')
  }
  wallHitSound = love.audio.newSource('sfx/wall-hit.wav', 'static')
  spikeHitSound = love.audio.newSource('sfx/spike-hit.wav', 'static')

  -- Create the duck, our hero!
  duck = {
    x = DUCK_START_X,
    y = 80,
    vx = 3,
    vy = 0,
    maxX = DUCK_START_X,
    isOnGround = false,
    numMidairJumps = 0,
    walkTimer = 0.00,
    invincibilityTimer = 0.00
  }

  -- Create an empty array for spikes
  spikes = {}

  -- Create the ground, which is made up of a series of platforms
  platforms = {}
  for i = 0, 1 + GAME_WIDTH / PLATFORM_WIDTH do
    table.insert(platforms, {
      x = i * PLATFORM_WIDTH,
      width = PLATFORM_WIDTH,
      height = 48,
      isHole = false
    })
  end
  rightmostPlatform = platforms[#platforms]
end

-- Update the game state
function love.update(dt)
  -- Move the platforms to the left
  for _, platform in ipairs(platforms) do
    platform.x = platform.x - SCROLL_SPEED * dt
  end

  -- Platforms that move off the left side of the screen become new platforms on the right side of the screen
  for _, platform in ipairs(platforms) do
    if platform.x + platform.width < 0 then
      platform.x = rightmostPlatform.x + rightmostPlatform.width
      -- Randomize the platform's size
      local height = rightmostPlatform.height
      if math.random() < 0.8 then
        height = math.min(math.max(16, height + (math.random() < 0.5 and -16 or 16)), 80)
      end
      platform.height = height
      platform.isHole = not rightmostPlatform.isHole and math.random() < 0.2
      rightmostPlatform = platform
      -- Use this opportunity to spawn some spikes
      if not platform.isHole and math.random() < 0.22 then
        local numSpikes = math.random(3, 5)
        local x = rightmostPlatform.x + rightmostPlatform.width / 2 + 1
        local y = GAME_HEIGHT - rightmostPlatform.height - 4
        local arrangeVertically = math.random() < 0.5
        for i = 0, numSpikes - 1 do
          table.insert(spikes, {
            x = x + (arrangeVertically and 0 or 8 * (i + 0.5 - numSpikes / 2)),
            y = y - (arrangeVertically and 8 * i or 0)
          })
        end
      end
    end
  end

  -- Update the duck's timers
  duck.walkTimer = duck.walkTimer + dt
  duck.invincibilityTimer = math.max(0.00, duck.invincibilityTimer - dt)

  -- Update the duck's position
  local wasOnGround = duck.isOnGround
  duck.isOnGround = false
  duck.vy = duck.vy + (duck.isBeingBumped and 200 or 400) * dt
  duck.x = math.max(DUCK_START_X, duck.x + (duck.isBeingBumped and -25 or duck.vx) * dt)
  duck.y = duck.y + math.min(duck.vy * dt, 4.5)

  -- Keep track of how far the duck has gotten
  duck.maxX = math.max(duck.x, duck.maxX)

  -- Move spikes to the left
  for i = #spikes, 1, -1 do
    local object = spikes[i]
    object.x = object.x - SCROLL_SPEED * dt
    if object.x < -10 then
      table.remove(spikes, i)
    end
    -- Check for collisions with the duck
    local dx, dy = object.x - duck.x, object.y - duck.y
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist < 7 and duck.invincibilityTimer <= 0.00 then
      -- Collisions bump the duck backwards
      bumpDuck()
      love.audio.play(spikeHitSound:clone())
    end
  end

  -- Check for collisions with the ground
  for _, platform in ipairs(platforms) do
    local platformY = GAME_HEIGHT - platform.height
    if platform.x <= duck.x and duck.x < platform.x + platform.width and duck.y > platformY and not platform.isHole and duck.vy > 0 then
      -- Allow the duck to stand on the platform
      if duck.isBeingBumped or duck.y < platformY + 5 then
        duck.y = platformY
        duck.isBeingBumped = false
        duck.vy = 0
        duck.isOnGround = true
        duck.numMidairJumps = 2
        if not wasOnGround then
          duck.walkTimer = 0.00
        end
      -- But if the duck is too far below the platform, bump it backward
      else
        bumpDuck()
        love.audio.play(wallHitSound:clone())
      end
    end
  end
end

-- Render the game
function love.draw()
  -- Scale and crop the screen
  love.graphics.setScissor(0, 0, RENDER_SCALE * GAME_WIDTH, RENDER_SCALE * GAME_HEIGHT)
  love.graphics.scale(RENDER_SCALE, RENDER_SCALE)
  love.graphics.clear(15 / 255, 217 / 255, 246 / 255)

  -- Draw the lines showing how far the duck has gotten
  love.graphics.setColor(254 / 255, 253 / 255, 56 / 255)
  love.graphics.line(duck.x, 0, duck.x, 5)
  love.graphics.line(duck.maxX, 0, duck.maxX, 10)

  -- Draw the platforms
  love.graphics.setColor(37 / 255, 2 / 255, 72 / 255)
  for _, platform in ipairs(platforms) do
    if not platform.isHole then
      love.graphics.rectangle('fill', platform.x, GAME_HEIGHT - platform.height, platform.width, platform.height)
    end
  end

  -- Draw the duck
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
  love.graphics.setColor(1, 1, 1)
  if duck.invincibilityTimer % 0.2 < 0.15 then
    drawSprite(duckImage, 16, 16, sprite, duck.x - 8, duck.y - 16)
  end

  -- Draw the spikes
  love.graphics.setColor(1, 1, 1)
  for _, object in ipairs(spikes) do
    drawSprite(spikesImage, 7, 7, 1, object.x - 3.5, object.y - 7)
  end
end

-- Press space to make the duck jump (or double jump [or triple jump])
function love.keypressed(key)
  if key == 'space' and not duck.isBeingBumped then
    if duck.isOnGround then
      duck.vy = -210
      duck.isOnGround = false
      love.audio.play(jumpSounds[1]:clone())
    elseif duck.numMidairJumps == 2 then
      duck.vy = -145
      duck.numMidairJumps = 1
      love.audio.play(jumpSounds[2]:clone())
    elseif duck.numMidairJumps == 1 then
      duck.vy = -80
      duck.numMidairJumps = 0
      love.audio.play(jumpSounds[3]:clone())
    end
  end
end

-- Bumps the duck backwards (after it collides with an obstacle)
function bumpDuck()
  duck.y = duck.y - 5
  duck.vy = -150
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

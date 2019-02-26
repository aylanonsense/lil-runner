-- Render constants
local GAME_WIDTH = 200
local GAME_HEIGHT = 200
local RENDER_SCALE = 3

-- Game constants
local PLATFORM_WIDTH = 88
local MOVE_SPEED = 80

-- Game objects
local duck
local spikes
local platforms
local rightmostPlatform

-- Images
local duckImage

-- Sound effects

-- Initializes the game
function love.load()
  -- Load images
  duckImage = love.graphics.newImage('img/duck.png')
  duckImage:setFilter('nearest', 'nearest')

  -- Load sound effects

  -- Create the duck, our hero!
  duck = {
    x = 20,
    y = 50,
    vy = 0,
    isOnGround = false,
    numMidairJumps = 0,
    walkTimer = 0.00
  }

  -- Create an empty array for spikes
  spikes = {}

  -- Create the ground, which is made up of a series of platforms
  platforms = {}
  for i = 0, 1 + GAME_WIDTH / PLATFORM_WIDTH do
    table.insert(platforms, {
      x = i * PLATFORM_WIDTH,
      width = PLATFORM_WIDTH,
      height = 48
    })
  end
  rightmostPlatform = platforms[#platforms]
end

-- Updates the game state
function love.update(dt)
  -- Move the platforms to the left
  for _, platform in ipairs(platforms) do
    platform.x = platform.x - MOVE_SPEED * dt
  end

  -- Platforms that move off the left side of the screen become new platforms on the right side of the screen
  for _, platform in ipairs(platforms) do
    if platform.x + platform.width < 0 then
      platform.x = rightmostPlatform.x + rightmostPlatform.width
      local height = rightmostPlatform.height
      if math.random() < 0.8 then
        height = math.min(math.max(16, height + (math.random() < 0.5 and -16 or 16)), 80)
      end
      platform.height = height
      rightmostPlatform = platform
      -- Spawn some spikes
      if math.random() < 0.6 then
        local numSpikes = math.random(3, 6)
        local arrangedVertically = math.random() < 0.5
        local x = rightmostPlatform.x + rightmostPlatform.width / math.random(1, 2) - 5
        local y = GAME_HEIGHT - platform.height - (math.random() < 0.5 and 2 or 18)
        for i = 0, numSpikes - 1 do
          table.insert(spikes, {
            x = x - (arrangedVertically and 0 or 8 * i),
            y = y - (arrangedVertically and 8 * i or 0)
          })
        end
      end
    end
  end

  -- Update the duck, which includes applying gravity
  local wasOnGround = duck.isOnGround
  duck.walkTimer = duck.walkTimer + dt
  duck.isOnGround = false
  duck.vy = duck.vy + 400 * dt
  duck.y = duck.y + math.min(duck.vy * dt, 4.5)

  -- Move spikes to the left
  for i = #spikes, 1, -1 do
    local spike = spikes[i]
    spike.x = spike.x - MOVE_SPEED * dt
    if spike.x < -10 then
      table.remove(spikes, i)
    end
    -- Check for collisions with the duck
    local dx, dy = spike.x - duck.x, spike.y - duck.y
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist < 7 then
      bumpDuck()
    end
  end

  -- Check for collisions with the ground
  for _, platform in ipairs(platforms) do
    local platformY = GAME_HEIGHT - platform.height
    if platform.x <= duck.x and duck.x < platform.x + platform.width and duck.y > platformY then
      -- If the duck is too far into the ground, that means it failed to jump in time
      if duck.y > platformY + 5 then
        bumpDuck()
      -- Otherwise, move it up on top of the platform
      else
        duck.y = platformY
        if duck.vy > 0 then
          duck.vy = 0
          duck.isOnGround = true
          duck.numMidairJumps = 2
          if not wasOnGround then
            duck.walkTimer = 0.00
          end
        end
      end
    end
  end
end

-- Renders the game
function love.draw()
  -- Scale up the screen
  love.graphics.scale(RENDER_SCALE, RENDER_SCALE)

  -- Clear the screen
  love.graphics.setColor(15 / 255, 217 / 255, 246 / 255)
  love.graphics.rectangle('fill', 0, 0, GAME_WIDTH, GAME_HEIGHT)
  love.graphics.setColor(1, 1, 1)

  -- Draw the platforms
  love.graphics.setColor(37 / 255, 2 / 255, 72 / 255)
  for _, platform in ipairs(platforms) do
    love.graphics.rectangle('fill', platform.x, GAME_HEIGHT - platform.height, platform.width, platform.height)
  end

  -- Draw the duck
  local spriteNum
  if duck.isOnGround then
    if duck.walkTimer < 0.08 then
      spriteNum = 4
    elseif duck.walkTimer % 0.32 < 0.08 then
      spriteNum = 2
    elseif duck.walkTimer % 0.32 < 0.16 then
      spriteNum = 3
    else
      spriteNum = 1
    end
  elseif duck.vy > 0 then
    spriteNum = 6
  else
    spriteNum = 5
  end
  love.graphics.setColor(1, 1, 1)
  drawImage(duckImage, 16, 16, spriteNum, duck.x - 8, duck.y - 16)

  -- Draw the spikes
  love.graphics.setColor(137 / 255, 2 / 255, 72 / 255)
  for _, spike in ipairs(spikes) do
    love.graphics.circle('fill', spike.x, spike.y - 3.5, 3.5)
  end
end

-- Draws a sprite from a sprite sheet image, spriteNum=1 is the upper-leftmost sprite
function drawImage(image, spriteWidth, spriteHeight, spriteNum, x, y)
  local columns = math.floor(image:getWidth() / spriteWidth)
  local col = (spriteNum - 1) % columns
  local row = math.floor((spriteNum - 1) / columns)
  local quad = love.graphics.newQuad(col * spriteWidth, row * spriteHeight, spriteWidth, spriteHeight, image:getDimensions())
  love.graphics.draw(image, quad, x, y)
end

-- Press space to make the duck jump (or double jump [or triple jump])
function love.keypressed(key)
  if key == 'space' then
    if duck.isOnGround then
      duck.vy = -210
      duck.isOnGround = false
    elseif duck.numMidairJumps == 2 then
      duck.vy = -145
      duck.numMidairJumps = 1
    elseif duck.numMidairJumps == 1 then
      duck.vy = -80
      duck.numMidairJumps = 0
    end
  end
end

-- Bump the duck after it gets hit by an obstacle
function bumpDuck()
  duck.y = 0
end

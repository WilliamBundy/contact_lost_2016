require "middleclass"
Stateful = require "stateful"
gamera = require "gamera"
local cron = require "cron"
require "beholder"
require "affable"
local contact_lost = require "contact_lost_items"
local playstate = require "playstate"

function round(x)
	if x - math.floor(x) < .5 then return math.floor(x)
	else return math.ceil(x) end
end

function newEnemy(x,y, attack, defense, maxHealth, speed, alertDist, drops, dropchance, size)
	local enemy = {attack=attack, defense=defense, maxHealth=maxHealth, health=maxHealth, 
	speed=speed, alertDist=alertDist, drops=drops, dropchance=dropchance}
	if size == nil then size = 1 end
	enemy.body = love.physics.newBody(reactor.world, x,y, "dynamic")
	enemy.body:setAngle(rand(0,math.pi*2))
	enemy.body:setLinearDamping(10)
	enemy.body:setAngularDamping(4)
	enemy.shape = love.physics.newPolygonShape(0, -8*size, -8*size,8*size, 8*size,8*size )
	enemy.fixture = love.physics.newFixture(enemy.body, enemy.shape)
	local quad = love.graphics.newQuad(16*(size-1), 0, 16,16, 256,256) --hardcoded image
	enemy.sprite = affable.newSprite(reactor.entityImage, reactor.entityBatch, quad)
	enemy.sprite.originOffset:setXYZ(8,8)
	enemy.sprite.scale:setXYZ(size, size)
	enemy.isEnemy = true
	enemy.fixture:setUserData(enemy)
	return enemy
end

projectileQuad = love.graphics.newQuad(0, 16, 16,16, 256,256)
function newProjectile(vx, vy, x,y, damage)
	local p = {damage=damage}
	p.body = love.physics.newBody(reactor.world, x,y, "dynamic")
	p.shape = love.physics.newCircleShape(4)
	p.fixture = love.physics.newFixture(p.body, p.shape, 1)
	p.sprite = affable.newSprite(reactor.entityImage, reactor.entityBatch, projectileQuad)
	p.sprite.originOffset:setXYZ(8,8)
	p.sprite.scale:setXYZ(.75,.75)
	p.isProjectile = true
	p.body:setLinearVelocity(vx, vy)
	p.body:setAngularVelocity(rand(0, math.pi/2))
	p.fixture:setUserData(p)
	p.fixture:setRestitution(0)
	return p
end

rockQuad = love.graphics.newQuad(64,0, 32,32, 256,256)
function newRock(x,y,s,a)
	local r = {}
	r.body = love.physics.newBody(reactor.world, x,y, "static")
	r.shape = love.physics.newRectangleShape(32*s,32*s)
	r.fixture = love.physics.newFixture(r.body, r.shape)
	r.sprite = affable.newSprite(reactor.entityImage, reactor.entityBatch, rockQuad)
	r.sprite.originOffset:setXYZ(16,16)
	r.sprite.scale:setXYZ(s,s)
	r.sprite.rotation = a
	r.body:setAngle(a)
	r.sprite.position:setXYZ(x,y)
	r.isRock = true
	r.fixture:setUserData(r)
	return r
end

function newMachine(x,y,t)
	local m = {}
	local mx, my = math.floor(x/32),math.floor(y/32)
	reactor.machineGrid[getMachineIndex(mx, my)] = m
	m.inventory = {}
	for i=1,10 do table.insert(m.inventory, "nothing") end
	m.gridIndex = getMachineIndex(mx,my)
	m.sprite = affable.newSprite(reactor.entityImage, reactor.entityBatch, t.quad)
	--m.sprite.originOffset:setXYZ(32,32)
	m.sprite.position:setXYZ(mx*32, my*32)
	m.sprite.scale:setXYZ(2.0, 2.0)
	m.tx = mx
	m.ty = my
	m.isMachine = true
	m.machineType = t.machineType
	m.t = t
	if t.onCreate then t.onCreate(m) end
	return m
end

capsuleQuad = love.graphics.newQuad(16, 16, 16,16, 256,256)
schemaCapsuleQuad = love.graphics.newQuad(32, 16, 16,16, 256,256)
function newCapsule(x,y,n,containsType)
	local c = {}
	c.body = love.physics.newBody(reactor.world, x,y, "dynamic")
	c.shape = love.physics.newCircleShape(8)
	c.fixture = love.physics.newFixture(c.body, c.shape, 2)
	c.sprite = affable.newSprite(reactor.entityImage, reactor.entityBatch, capsuleQuad)
	if containsType == "schema" then
		c.sprite.quad = schemaCapsuleQuad
	end
	c.sprite.originOffset:setXYZ(8,8)
	c.isCapsule = true
	c.containsType= containsType -- either "item" or "schema"
	c.name = n
	c.fixture:setUserData(c)
	c.body:setLinearDamping(10.0)
	c.body:setAngularDamping(5.0)
	c.body:setAngle(rand(0,math.pi*2))
	c.active = true
	return c
end

function rand(n, m)
	local r = math.random()
	return r * (m-n) + n 
end

function addItem(t)
	reactor.itemTypes[t.id] = t
	reactor.itemTypes[t.index] = t
end

function getMachineIndex(x,y)
	return x+32*y
end

function getPlayerMachineIndex()
	local px, py = reactor.player.body:getX()/32, reactor.player.body:getY()/32
	px, py = math.floor(px), math.floor(py)
	return px+32*py
end

function love.load()
	love.graphics.setDefaultImageFilter("nearest", "nearest")
	local font = love.graphics.newFont("DejaVuSansMono.ttf", 14);
	love.graphics.setFont(font);
	--  math.randomseed(1337); math.random(); math.random(); math.random()
	reactor = affable.newReactor()
	reactor:_start()
	reactor.gamera = gamera.new(0,0,1024,2048*32)
	reactor.gamera:setScale(1.0)
	reactor.uilines = {}

	reactor.gunSound = love.audio.newSource("gun.ogg", "static")
	reactor.gunSound:setVolume(.5)
	reactor.stepSound = love.audio.newSource("footstep.ogg", "static")
	--reactor.bgmSound = love.audio.newSource("music.ogg")
	--reactor.bgmSound:setLooping(true)
	--reactor.bgmSound:setVolume(.5)
	--reactor.bgmSound:play()
	reactor.playingSounds = true
	reactor.playingMusic = true


	reactor.terrainImages = {
		water = love.graphics.newImage("slice0.png"),
		grass = love.graphics.newImage("slice1.png"),
		desert = love.graphics.newImage("slice2.png"),
		temple = love.graphics.newImage("slice3.png")
	}
	waterStart = 0
	grassStart = 1
	grassEnd = 4
	desertStart = 5
	desertHalf = 8
	desertEnd = 11
	templeStart = 14
	templeEnd = 19

	reactor.terrainSequence = {
		"water", --2
		"grass","grass","grass","grass", -- 4
		"desert","desert","desert","desert","desert","desert", -- 6
		"temple","temple","temple","temple", -- 4
		"water"
	} -- Total: 16 segments
	reactor.terrainRectangles = {}
	for i=1, #reactor.terrainSequence do
		reactor.terrainRectangles[i] = affable.newRectangle(1024,2048,0,2048*(i-1))
		reactor.terrainRectangles[i].index = i
	end

	reactor.entityImage = love.graphics.newImage("entitysheet.png")
	reactor.entityBatch = love.graphics.newSpriteBatch(reactor.entityImage, 4096)

	love.physics.setMeter(20) -- should work fine for now.
	reactor.world = love.physics.newWorld(0, 0, true)
	reactor.world:setCallbacks(
		function(f1,f2,c) reactor.physicsBeginContact(f1,f2,c) end,
		function(f1,f2,c) reactor.physicsEndContact(f1,f2,c) end,
		function(f1,f2,c) reactor.physicsPreSolve(f1,f2,c) end,
		function(f1,f2,c) reactor.physicsPostSolve(f1,f2,c) end
	)

	reactor.uispace = 24
	reactor.bounds = {}
	reactor.bounds.body = love.physics.newBody(reactor.world, 0,0, "static")
	reactor.bounds.shape = love.physics.newChainShape(true, 0,2048, 1024,2048, 1024,31*2048, 0, 31*2048, 0,2048)
	reactor.bounds.fixture = love.physics.newFixture(reactor.bounds.body, reactor.bounds.shape)
	reactor.bounds.fixture:setUserData("bounds")
	reactor.player = {}
	player = reactor.player
	reactor.player.sprite = affable.newSprite(love.graphics.newImage("playerfinal.png"))
	reactor.player.sprite.originOffset:setXYZ(32,34)
	reactor.player.body = love.physics.newBody(reactor.world, 512, 2048+32, "dynamic")
	reactor.player.shape = love.physics.newCircleShape(7)
	reactor.player.fixture = love.physics.newFixture(
		reactor.player.body, reactor.player.shape, 10)
	reactor.player.moveSpeed = 2000
	reactor.player.body:setLinearDamping(10)
	reactor.player.isPlayer = true
	reactor.player.fixture:setUserData(reactor.player)
	reactor.player.isAlive = true

	--Dvorak keys
	--reactor.keyconfig = {up=",",left="a",right="e",down="o"}
	reactor.keyconfig = {up="w",left="a",right="d",down="s"}

	reactor.player.maxHealth = 100
	reactor.player.health = 100
	reactor.projectiles = {}
	reactor.player.projectileDamage = 16
	reactor.player.projectileSpeed = 500
	reactor.player.defense = 0
	reactor.player.inventory = {"organicfiber", "nothing", "nothing", "nothing", "nothing", "nothing", "nothing", "nothing", "nothing", "nothing"}
	reactor.player.schemas = {"food", "organicfiber"}
	reactor.player.currentSchemaID = 1
	reactor.itemTypes = {}


	-- Miner Initialization
	reactor.minerGrid = {}
	reactor.minerCount = {}
	for y=0,(16*2048/128) do
		for x=0,(1024/128) do
			reactor.minerCount[x+16*y] = math.random(3, 7)
			if y >= desertStart*16 and y <= desertEnd*16 then
				local t = {"metalore", "metalore", "metalore", "crystal"}
				reactor.minerGrid[x+16*y] = t[math.random(1,4)]
			elseif y >=templeStart*16 and y <=templeEnd*16 then
				local t = {"ucell", "ucell", "ucell", "metalore", "crystal"}
				reactor.minerGrid[x+16*y] = t[math.random(1,5)]
			else
				local t = {"organicfiber", "organifiber", "metalore"}
				reactor.minerGrid[x+16*y] = t[math.random(1, 3)]
			end
		end
	end

	contact_lost.addAllItems()

	reactor.machineGrid = {}

	reactor.capsules = {}
	function addCapsule(zone, n, contains, x, y)
		local function getZoneXY(zone) 
			local cx =  rand(4, 1020)
			local cy = (2080)

			if zone == -1 then cy = rand(3000, 2048 * templeEnd)
			elseif zone == 0 then cy = rand(2048, 3000)
			elseif zone == 1 then cy = rand(3000, 2048*desertStart)
			elseif zone == 2 then cy = rand(2048*desertStart, 2048*desertHalf)
			elseif zone == 3 then cy = rand(2048*desertHalf,  2048*templeStart)
			elseif zone == 4 then cy = rand(2048*templeStart, 2048*templeEnd)
			end
			return cx,cy 
		end
		local cx, cy = 0
		if zone then
			cx, cy = getZoneXY(zone)
		else
			cx = x
			cy = y
		end

		table.insert(
			reactor.capsules, 
			newCapsule(
				cx,
				cy,
				reactor.itemTypes[n].id,
				contains))
	end

	addCapsule(0, 32, "item")
	addCapsule(0, 33, "item")
	for i=1,25 do
		if reactor.itemTypes[i] and reactor.itemTypes[i].recipe then
			addCapsule(4, i, "schema")
		end
	end
	for i=1,16 do
		addCapsule(1, "metal", "item")
		addCapsule(2, "metal", "item")
	end
	for i=1,8 do
		addCapsule(1, "crystal", "item")
		addCapsule(2, "crystal", "item")
	end
	for i=1,16 do
		addCapsule(1, "organicfiber", "item")
		addCapsule(1, "food", "item")
	end

	for i,n in pairs{"food", "basicframe", "mechStorageCell", "mechFabricator"} do
		addCapsule(0, n, "schema")
	end
	for i,n in pairs{"syntheticfiber", "wiring", "solenoid", "coil",
			"plate", "capacitor", "electronics", "stdframe"} do
		addCapsule(1, n, "schema")
	end
	for i,n in pairs{"mechCapacitor", "mechFurnace", "mechMiner", "mechChemWasher", "mechGrinder", "sensor", "circuitboard"} do
		addCapsule(2, n,"schema")
	end
	for i,n in pairs{"advframe", "mechTeleporter", "mechReactor", "mechPump", "crystalcapacitor", "sensorarray"} do
		addCapsule(3, n, "schema")
	end
	for i,n in pairs{"mechSignalStabilizer", "mechTransmissionBooster", "mechGalacticNav"} do
		addCapsule(4, n,"schema")
	end

--function newEnemy(x,y, attack, defense, maxHealth, speed, alertDist, drops, dropchance)
	reactor.enemies = {}
	-- Reds
	for i=1,64 do
		table.insert(reactor.enemies, newEnemy(rand(24, 1000), rand(3000, 2048*desertStart),
										 2, 0,
										 64, 450,
										 256,
										 {"organicfiber"}, 1.5, 1))

	end
	-- greens
	for i=1,128 do
		table.insert(reactor.enemies, newEnemy(rand(24, 1000), rand(2048*desertStart, 2048*desertEnd), 
										 8,  4,
										 128, 1800,
										 512,
										 {"organicfiber", "metalingot"}, 0.25, 2))
	end
	-- Blue
	for i=1,64 do
		table.insert(reactor.enemies, newEnemy(rand(24, 1000), rand(2048*desertHalf, 2048*templeEnd), 
										 12, 2,
										 32, 2000, 
										 512,
										 {}, 0.25, 3))
	end
	-- Grey
	for i=1,16 do
		table.insert(reactor.enemies, newEnemy(rand(24, 1000), rand(2048*desertEnd, 2048*templeEnd),
										 16,4,
										 40,2200,
										 512,
										 {}, 0.25, 4))
	end

	reactor.rocks = {}
	for i=1,128 do
		local nrock = math.random(2,8)
		local rX, rY = rand(0,1024), rand(2048+200, 2048*templeEnd)
		for i=1,nrock do
			table.insert(reactor.rocks, newRock(rX+rand(-128,128), rY+rand(-128,128), rand(0.75, 1.25), rand(0, math.pi*2)))

		end
	end

	reactor.endingParticles = love.graphics.newParticleSystem(love.graphics.newImage("endingparticle.png"), 1024)
	e = reactor.endingParticles
	e:setEmissionRate(256)
	e:setSpeed(300)
	e:setParticleLife(3)
	e:setSizes(1.25,1.0,.5,.1,0)
	e:setSpin(.2,math.pi,1)
	e:setOffset(8,8)
	e:setSpread(math.pi*2)
	e:setTangentialAcceleration(100,100)
	e:stop()
	eaw = 0
	reactor.dtsum = 0

	playstate.createPlayState()

	reactor:gotoState("PlayState")

	CreditsState = affable.Reactor:addState("CreditsState")
	credits = [[
Congratulations! 
You teleported home!
You managed to beat the game!
My badly-written, hitchhiker-alluding, made-in-48hr game!
I hope the experience wasn't too mind-numbingly banal or stupidly frustrating.

==========================================
  CONTACT: LOST 
==========================================

A game by William Bundy.
Licenced under the GPL.
Uses Love2D and a bunch of kikito's code. https://github.com/kikito

Code can be found at https://github.com/williambundy

A game made for Ludum Dare 26 -- themed: minimalism
	Share and Enjoy!
	...press any key to quit.]]
	function CreditsState:onKeyPressed(key,unicode)
		love.event.push("quit")
	end

	function CreditsState:draw()
		love.graphics.print("You completed the game in "..reactor.dtsum.." seconds.",8,8)
		love.graphics.print(credits, 8, 100)
	end
end

function love.update(dt)
	reactor:_update(dt)
end

function love.draw()
	reactor:_draw()
end

function love.mousepressed(x,y, button)
	if reactor:getStateStackDebugInfo()[1] == "PlayState" and button == "l" then
		reactor.gunSound:play()
		local a = reactor.player.body:getAngle() + rand(-0.15, 0.15)
		local px, py = reactor.player.body:getX(), reactor.player.body:getY()
		local p = newProjectile(reactor.player.projectileSpeed*math.cos(a),
						  reactor.player.projectileSpeed*math.sin(a), px + 10*math.cos(a), py+10*math.sin(a), reactor.player.projectileDamage)
		table.insert(reactor.projectiles, p)
		cron.after(rand(0.6, 0.8), function(b) b.spent = true; end, p )
	end
end 

function love.keypressed(key, unicode)
	reactor:_onKeyPressed(key, unicode)
end


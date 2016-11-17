require "middleclass"
Stateful = require "stateful"
gamera = require "gamera"
local cron = require "cron"
require "beholder"
require "affable"
local contact_lost = require "contact_lost_items"
module(..., package.seeall)

function createPlayState()

	local PlayState = affable.Reactor:addState("PlayState")
	function PlayState:update(dt)
		reactor.dtsum = reactor.dtsum + dt
		cron.update(dt)
		if not reactor.endingSequence then
			self.world:update(dt)
		end

		local mx, my = self.gamera:toWorld(love.mouse.getX(), love.mouse.getY())
		local px,py = self.player.body:getX(), self.player.body:getY()

		self.gamera:setPosition(px, py)
		self.player.sprite.position:setXYZ(px,py)

		if not reactor.endingSequence then
			local pa = self.player.sprite.position:getAngleBetweenXY(mx,my)
			self.player.sprite.rotation = pa  + math.pi/2
			self.player.body:setAngle(pa)
		end
		
		if player.isAlive then
			local v = affable.newVector()
			if love.keyboard.isDown(self.keyconfig.up)    then
				v.y = v.y - self.player.moveSpeed
			end
			if love.keyboard.isDown(self.keyconfig.down)  then
				v.y = v.y + self.player.moveSpeed
			end
			if love.keyboard.isDown(self.keyconfig.left)  then
				v.x = v.x - self.player.moveSpeed
			end
			if love.keyboard.isDown(self.keyconfig.right) then
				v.x = v.x + self.player.moveSpeed
			end
			if not (v.x * v.y == 0) then
				v:scale(1/1.41421356)
			end
			--if love.keyboard.isDown(" ") then v:scale(200) end 
			local _pmx,_pmy,pmass, _pinertia = self.player.fixture:getMassData()
			self.player.body:applyForce(v.x*pmass,v.y*pmass)
		end

		if self.player.health <= 0 then
			self.player.health = 0
			if player.isAlive then
				for n=1,10 do
					if player.inventory[n] ~= "nothing" then
						local c = newCapsule(player.body:getX(), player.body:getY(),player.inventory[n],"item")
						c.active = false
						cron.after(4, function(v) v.active=true end, c)
						table.insert(reactor.capsules, c)
						c.body:applyLinearImpulse(rand(-500, 500), rand(-500,500))
						player.inventory[n] = "nothing"
					end
				end
				cron.after(5, function()
					player.isAlive = true
					player.body:setX(512)
					player.body:setY(2048 +64)
					player.health = player.maxHealth
				end)
			end
			player.isAlive = false
		end

		self.currentMachine = self.machineGrid[getPlayerMachineIndex()]

		for i,enemy in pairs(reactor.enemies) do
			if enemy.health <= 0 then 
				
				if rand(0, 1) < enemy.dropchance then
					local bx = enemy.body:getX()
					local by = enemy.body:getY()
					local id = enemy.drops[math.random(1, #enemy.drops)]
					addCapsule(nil, id, "item", bx, by)
				end

				enemy.fixture:destroy()
				reactor.enemies[i] = nil
			end 
			local ex, ey = enemy.body:getX(), enemy.body:getY()
			local distPlayer = math.sqrt((ex-px)*(ex-px) + (ey-py)*(ey-py))
			if distPlayer < enemy.alertDist then
				local angle = math.atan2(py-ey,px-ex)
				enemy.body:applyForce(enemy.speed * math.cos(angle), enemy.speed*math.sin(angle))
				enemy.body:setAngle(angle + math.pi/2)
			end
			enemy.sprite.position:setXYZ(enemy.body:getX(), enemy.body:getY())
			enemy.sprite.rotation = enemy.body:getAngle()-- + math.pi/2
		end

		for i,projectile in pairs(reactor.projectiles) do
			projectile.index = i
			projectile.sprite.position:setXYZ(projectile.body:getX(), projectile.body:getY())
			projectile.sprite.rotation = projectile.body:getAngle()
			if projectile.spent then
				projectile.fixture:destroy()
				reactor.projectiles[i] = nil
			end
		end

		for i,capsule in pairs(reactor.capsules) do
			capsule.sprite.position:setXYZ(capsule.body:getX(), capsule.body:getY())
			capsule.sprite.rotation = capsule.body:getAngle()
			if capsule.spent then
				capsule.fixture:destroy()
				reactor.capsules[i] = nil
			end
		end
		reactor.uilines = {}
		reactor.uilines[1] = "HP: "..reactor.player.health.."/"..reactor.player.maxHealth
		reactor.uilines[2] = "X: "..math.floor(reactor.player.body:getX()/32)
		reactor.uilines[3] = "Y: "..math.floor(reactor.player.body:getY()/32)

		if reactor.currentMachine ~= nil then 
			table.insert(reactor.uilines, reactor.currentMachine.t.name)
			reactor.currentMachine.t.onUI(reactor.currentMachine)
		else 
			table.insert(reactor.uilines, "No Machine") 
			for i=1,10 do
				table.insert(reactor.uilines, (i%10)..": "..reactor.itemTypes[reactor.player.inventory[i]].name)
			end
		end

		if player.schemas[player.currentSchemaID] then
			local s = reactor.itemTypes[player.schemas[player.currentSchemaID]]
			table.insert(reactor.uilines, "Schema "..player.currentSchemaID..": "..s.name)
			for i,part in ipairs(s.recipe) do
				if reactor.itemTypes[part] then
					table.insert(reactor.uilines, i..": "..reactor.itemTypes[part].name)
				else 
					table.insert(reactor.uilines, i..": Item<"..part..">")
				end
			end
		else
			table.insert(reactor.uilines, "No schema with ID of "..player.currentSchemaID)
		end

		for i,mech in pairs(reactor.machineGrid) do
			if mech.t.update then
				mech.t.update(mech, dt)
			end
		end

		if reactor.endingSequence then
			reactor.endingParticles:setPosition(px,py)
			reactor.endingParticles:setTangentialAcceleration(10+eaw, -50*eaw)
			reactor.endingParticles:update(dt)
			eaw = eaw + dt*10
			player.sprite.rotation = player.sprite.rotation + eaw * dt
		end

	end


	function PlayState:onKeyPressed(key, unicode)
		if love.keyboard.isDown("lshift") then
			if tonumber(key) ~= nil then
				local n = tonumber(key)
				if n == 0 then n = 10 end
				if player.inventory[n] ~= "nothing" then
					local c = newCapsule(player.body:getX(), player.body:getY(),player.inventory[n],"item")
					c.active = false
					cron.after(4, function(v) v.active=true end, c)
					table.insert(reactor.capsules, c)
					c.body:applyLinearImpulse(rand(-500, 500), rand(-500,500))
					player.inventory[n] = "nothing"
				end
			end
			return nil
		end 
		if key == "left" then
			player.currentSchemaID = reactor.player.currentSchemaID - 1
		elseif key == "right" then
			player.currentSchemaID = reactor.player.currentSchemaID + 1
		end

		if key == "up" then
			local ni = {}
			for i,item in ipairs(player.inventory) do
				local b = i - 1
				if b == 0 then b = 10 end
				ni[b] = item
			end
			player.inventory = ni
		elseif key == "down" then
			local ni = {}
			for i,item in ipairs(player.inventory) do
				local b = i+1
				if b == 11 then b = 1 end
				ni[b] = item
			end
			player.inventory = ni
		end

		if self.currentMachine == nil then
			if tonumber(key) ~= nil then 
				local n = tonumber(key)
				if n == 0 then n = 10 end
				local item = self.player.inventory[n]
				if string.sub(item,1,4) == "mech" then
					if reactor.machineGrid[getPlayerMachineIndex()] ~= nil then return nil end
					newMachine(reactor.player.body:getX(),reactor.player.body:getY(), reactor.itemTypes[item])
					self.player.inventory[n] = "nothing"
				elseif item == "food" then
					player.health = player.health + math.random(10,25)
					if player.health >= player.maxHealth then player.health = player.maxHealth end
					self.player.inventory[n] = "nothing"
				elseif item == "cookedfood" then
					player.health = player.health + math.random(20,45)
					if player.health >= player.maxHealth then player.health = player.maxHealth end
					self.player.inventory[n] = "nothing"
				end
			end
		else
			if key == "q" then
				local m = self.currentMachine
				local m_is_empty = true

				for i, slot in ipairs(m.inventory) do
					if slot ~= "nothing" then
						m_is_empty = false
						break
					end
				end

				if m_is_empty then 
					for i,slot in ipairs(player.inventory) do
						if slot == "nothing" then 
							self.currentMachine = nil
							self.machineGrid[m.gridIndex] = nil
							player.inventory[i] = m.t.id
							break
						end
					end
				end
			else
				if self.currentMachine.t.onKeyPressed and not reactor.endingSequence then
					self.currentMachine.t.onKeyPressed(self.currentMachine, key)
				end
			end
		end
	end

	function PlayState:draw()
		self.gamera:draw(function(l,t,w,h)
			love.graphics.setColor(255,255,255)
			for i,rect in ipairs(reactor.terrainRectangles) do 
				love.graphics.draw(
					reactor.terrainImages[reactor.terrainSequence[rect.index]],
					rect.position.x, rect.position.y)
			end
			love.graphics.setColor(255,255,255)


			reactor.entityBatch:clear()
			for i,mech in pairs(reactor.machineGrid) do
				mech.sprite:onDrawBatch()
			end
			for i,enemy in pairs(reactor.enemies) do
				enemy.sprite:onDrawBatch()
			end
			for i,projectile in pairs(reactor.projectiles) do
				projectile.sprite:onDrawBatch()
			end
			for i,rock in pairs(reactor.rocks) do
				rock.sprite:onDrawBatch()
			end
			for i,capsule in pairs(reactor.capsules) do
				capsule.sprite:onDrawBatch()
			end
			love.graphics.draw(reactor.entityBatch)
			if reactor.endingSequence then
				love.graphics.draw(reactor.endingParticles)
			end
			reactor.player.sprite:onDraw()

		end)
		if not reactor.endingSequence then
			local uistr = table.concat(reactor.uilines, "\n")

			love.graphics.setColor(0,0,0)
			love.graphics.print(uistr, 9,9)
			love.graphics.print(uistr, 10,10)
			love.graphics.setColor(255, 255, 255)
			love.graphics.print(uistr, 8,8)
			love.graphics.print(uistr, 8,8)
		end
	end

	function PlayState.physicsBeginContact(f1,f2,c)
		local function hit(bullet, entity)
			if not (entity.isPlayer or entity.isMachine) then bullet.spent = true end
			if not entity.isEnemy then return nil end
			dDamage = bullet.damage - entity.defense
			if dDamage <= 0 then dDamage = 0 end
			entity.health = entity.health - dDamage
		end
		local function playerHit(player, enemy)
			dDamage = enemy.attack - player.defense
			if dDamage <= 0 then dDamage = 0 end
			player.health = player.health - dDamage
		end
		local function playerPickUp(player, capsule)
			if not capsule.active then return end
			if capsule.containsType == "item" then
				for i,slot in ipairs(player.inventory) do
					if slot == "nothing" then
						player.inventory[i] = capsule.name
						capsule.spent = true
						return
					end
				end
			elseif capsule.containsType == "schema" then
				--don't reinsert known schemas
				for i,slot in ipairs(player.schemas) do 
					if capsule.name == slot then
						capsule.spent = true
						return nil 
					end
				end
				table.insert(player.schemas, capsule.name)
				reactor.player.currentSchemaID = #player.schemas
				capsule.spent = true
			end
		end

		if not f1.getUserData or not f2.getUserData then print("no user data!"); return end
		if f1:getUserData() and f2:getUserData() then
			local f1u, f2u = f1:getUserData(), f2:getUserData()
			if f1u.isProjectile then 
				hit(f1u, f2u)
			elseif f2u.isProjectile then
				hit(f2u, f1u)
			end
			if (f1u.isPlayer and f2u.isEnemy) then
				playerHit(f1u, f2u)
			elseif (f2u.isPlayer and f1u.isEnemy) then
				playerHit(f2u, f1u)
			end
			if f1u.isPlayer and f2u.isCapsule then
				playerPickUp(f1u, f2u)
			elseif f2u.isPlayer and f1u.isCapsule then
				playerPickUp(f2u, f1u)
			end

		end
	end
end

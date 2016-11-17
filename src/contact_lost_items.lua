
module(..., package.seeall)

function addAllItems()
	addItem {id="nothing", name="--", index=0}
	addItem {id="food", name="Potato", index=1, recipe={"organicfiber"}, mechFurnace="cookedfood"}
	addItem {id="metal", name="Metal Ingot", index=2}
	addItem {id="organicfiber", name="Organic Fiber", index=3, recipe={"food"}}
	addItem {id="syntheticfiber", name="Synthetic Fiber", index=4, recipe={"organicfiber", "organicfiber", "crystal"}}
	addItem {id="crystal", name="Crystal", index=5}
	addItem {id="wiring", name="Wiring", index=6, recipe={"metal"}}
	addItem {id="electronics", name="Electronics", index=7, recipe={"wiring", "syntheticfiber"}}
	addItem {id="solenoid", name="Solenoid", index=8, recipe={"wiring", "wiring", "wiring", "metal"}}
	addItem {id="capacitor", name="Capacitor", index=9, recipe={"wiring", "plate"}}
	addItem {id="coil", name="Wire Coil", index=10, recipe={"wiring", "wiring"}}
	addItem {id="can", name="Liquid Can", index=11, recipe={"metal", "organicfiber"}}
	addItem {id="plate", name="Metal Plate", index=12, recipe={"metal", "metal"}}
	addItem {id="motor", name="Motor", index=14, recipe={"solenoid", "capacitor", "coil"}}
	addItem {id="basicframe", name="Basic Frame", index=15, recipe={"organicfiber" , "organicfiber", "organicfiber"}}
	addItem {id="stdframe", name="Standard Frame", index=16, recipe={"basicframe","metal", "syntheticfiber", "electronics"}}
	addItem {id="advframe", name="Advanced Frame", index=17, recipe={"stdframe","plate", "syntheticfiber", "syntheticfiber", "sensorarray", "circuitboard"}}
	addItem {id="ucell", name="Radioactive Cell", index=18}
	addItem {id="sensor", name="Sensor", index=19, recipe={"electronics", "crystal", "crystal", "capacitor"}}
	addItem {id="sensorarray", name="Sensor Array", index=20, recipe={"circuitboard", "sensor", "sensor", "sensor", "syntheticfiber"}}
	addItem {id="circuitboard", name="Circuit Board", index=21, recipe={"electronics", "electronics", "wiring", "syntheticfiber"}}
	addItem {id="metalore", name="Metal Ore", index=22, mechGrinder="metalchunks"}
	addItem {id="metalchunks", name="Ore Chunks", index=23, mechChemWasher="cleanchunks"}
	addItem {id="cleanchunks", name="Clean Ore Chunks", index=24, mechFurnace="metal"}
	addItem {id="crystalcapacitor", name="Crystal Capacitor", index=25, recipe={"wiring","syntheticfiber","syntheticfiber","crystal","crystal","crystal", "crystal"}}
	addItem {id="cookedfood", name="Roast Potato", index=26}

	-- Some utility functions
	function pushInventoryLines(mech)
		for i=1,10 do
			local size = reactor.uispace - #reactor.itemTypes[player.inventory[i]].name
			local linestart = (i%10)..": "..reactor.itemTypes[player.inventory[i]].name
			local lineend = reactor.itemTypes[mech.inventory[i]].name
			local spacetable = {}
			for q=1,size do
				spacetable[q] = " "
			end
			local linespaces = table.concat(spacetable, "")
			local line = linestart .. linespaces .. lineend

			table.insert(reactor.uilines, line)
		end
	end

	function q(x,y) 
		return love.graphics.newQuad(x*16,32+(y or 0)*16,16,16,256,256)
	end

	-- Unused machines
	addItem {id="mechPump", name="Pump", index=36, quad=q(4), recipe={"motor","can","basicframe"}}
	--addItem {id="mechTurbine", name="Turbine Generator", index=37, quad=q(5), recipe={"solenoid","plate","coil","basicframe"}}
	--addItem {id="mechBoiler", name="Boiler", index=38, quad=q(6), recipe={"can", "can", "metal", "basicframe"}}
	--addItem {id="mechSolarpanel", name="Solar Panel", index=42, quad=q(10), recipe={"circuitboard", "sensor", "crystal","stdframe"}}
	--addItem {id="mechTransporter", name="Transporter", index=48, quad=q(0,1), recipe={"motor", "basicframe"}}
	--addItem {id="mechAqueduct", name="Aqueduct", index=49, quad=q(1,1), recipe={"can", "basicframe"}}
	--addItem {id="mechTransformer", name="Transformer", index=50, quad=q(2,1), recipe={"wiring","basicframe"}}


	-- Machines
	addItem {
		id="mechStorageCell", 
		name="Storage Cell", 
		index=32, 
		recipe={"basicframe"}, 
		quad=q(0), 
		onUI=pushInventoryLines, 
		onKeyPressed=function(mech, key)
			if tonumber(key) ~= nil then
				local n = tonumber(key) 
				if n == 0 then n = 10 end
				local m = mech.inventory[n]
				local p = player.inventory[n]
				mech.inventory[n] = p
				player.inventory[n] = m
			end
		end
	}

	addItem {
		id="mechFabricator",
		name="Fabricator",
		index=33, 
		recipe={"basicframe", "metal"},
		quad=q(1), 
		onUI = function(mech)
			pushInventoryLines(mech)
			table.insert(reactor.uilines, "Press ENTER to start fabrication")
			table.insert(reactor.uilines, "Recipe must match schema exactly.")
		end, 
		onKeyPressed = function(mech, key)
			if tonumber(key) ~= nil then
				local n = tonumber(key) 
				if n == 0 then n = 10 end
				local m = mech.inventory[n]
				local p = player.inventory[n]
				mech.inventory[n] = p
				player.inventory[n] = m
			elseif key == "return" then
				local matchesSchema = true
				local s = reactor.itemTypes[player.schemas[player.currentSchemaID]]
				for i=1,#s.recipe do
					if mech.inventory[i] ~= s.recipe[i] then
						matchesSchema = false
						break
					end
				end
				if matchesSchema then
					for i=1,#s.recipe do
						mech.inventory[i] = "nothing"
					end
					mech.inventory[1] = s.id
				end
			end
		end
	}


	addItem {
		id="mechFurnace",
		name="Furnace",
		index=34,
		recipe={"capacitor", "coil", "stdframe"},  
		quad=q(2),
		onCreate=function(mech)mech.isCooking=false end,
		onUI=function(mech)
			if not mech.isCooking then
				pushInventoryLines(mech)
				table.insert(reactor.uilines, "Press ENTER to cook item in Slot 1")
			else
				table.insert(reactor.uilines, "Currently cooking...")
			end
		end,
		onKeyPressed=function(mech, key)
			if tonumber(key) ~= nil and mech.isCooking == false then
				local n = tonumber(key) 
				if n == 0 then n = 10 end
				local m = mech.inventory[n]
				local p = player.inventory[n]
				--if p == "nothing" then
				mech.inventory[n] = p
				player.inventory[n] = m
				--end
			end
			if key == "return" and mech.isCooking == false then
				mech.isCooking = true
				cron.after(10, function(mm)
					if reactor.itemTypes[mech.inventory[1]].mechFurnace then
						mech.inventory[1] = reactor.itemTypes[mech.inventory[1]].mechFurnace
					end
					mech.isCooking = false
				end, mech)
			end
		end
	}

	addItem {
		id="mechMiner", 
		name="Miner", 
		index=35, 
		quad=q(3), 
		recipe={"metal", "metal", "metal","sensor","stdframe"},
		onCreate=function(mech) mech.isMining=0 end,
		onUI=function(mech)
			local mgx, mgy = round(mech.sprite.position.x/128), round(mech.sprite.position.y/128)
			table.insert(reactor.uilines, "MinerX: "..mgx.." MinerY: "..mgy)
			if reactor.minerGrid[mgx+16*mgy] == "nothing" then
				table.insert(reactor.uilines, "This area has aready been mined.")
				pushInventoryLines(mech)
			elseif mech.isMining == 1 then
				table.insert(reactor.uilines, "Currently mining...")
			elseif mech.isMining == 0 then
				table.insert(reactor.uilines, "Press ENTER to start mining procedure")
			end
		end, 
		onKeyPressed=function(mech, key)
			local mgx, mgy = round(mech.sprite.position.x/128), round(mech.sprite.position.y/128)
			if tonumber(key) ~= nil and mech.isMining == 2 then
				local n = tonumber(key) 
				if n == 0 then n = 10 end
				local m = mech.inventory[n]
				local p = player.inventory[n]
				if p == "nothing" then
					mech.inventory[n] = p
					player.inventory[n] = m
				end
			end
			if key == "return" and mech.isMining == 0 then
				cron.after(math.random(20,40), 
			   function(mm) 
				   for i=1,reactor.minerCount[mgx + 16*mgy] do
					   mm.inventory[i] = reactor.minerGrid[mgx+16*mgy];
				   end
				   mm.isMining=2;
				   reactor.minerGrid[mgx+16*mgy] = "nothing"; 
			   end,
			   mech)
				mech.isMining = 1
			end 
		end
	}

	playerUpgrades = {
		{id="def", name="Defense Upgrade", 
		upgrade=function() player.defense = player.defense +1 end, 
		recipe={"plate","plate"}},

		{id="hp", name="Health Upgrade", 
		upgrade=function() player.maxHealth = player.maxHealth + 25 end, 
		recipe={"cookedfood","cookedfood","cookedfood","cookedfood","syntheticfiber"}},

		{id="dmg", name="Damage Upgrade", 
		upgrade=function() player.projectileDamage = player.projectileDamae + 2 end, 
		recipe={"crystal", "capacitor", "capacitor"}},

		{id="spd", name="Speed Upgrade", 
		upgrade=function() player.moveSpeed = player.moveSpeed + 200 end, 
		recipe={"syntheticfiber","syntheticfiber","syntheticfiber","solenoid"}}
	}

	addItem {
		id="mechCapacitor",
		name="Upgrade Station", 
		index=39, 
		quad=q(7), 
		recipe={"capacitor","capacitor", "electronics", "wiring", "stdframe"},
		onUI=function(mech)
			table.insert(reactor.uilines, "Upgrade Schematics: Use schemas 1-4 to select")
			table.insert(reactor.uilines, "2 Metal Plates = +1 Defense")
			table.insert(reactor.uilines, "4 Roast Potatoes and 1 Synthetic Fiber = +25 MaxHP")
			table.insert(reactor.uilines, "1 Crystal and 2 capacitor = +2 Damage")
			table.insert(reactor.uilines, "3 Synthetic Fiber and 1 Solenoid = +200 Speed")
			pushInventoryLines(mech)

			if player.currentSchemaID >=1 and player.currentSchemaID <=4 then
				table.insert(reactor.uilines, "Currently selected: "..playerUpgrades[player.currentSchemaID].name)
			end

			table.insert(reactor.uilines, "Press ENTER to upgrade")
		end, 
		onKeyPressed=function(mech, key)
			if tonumber(key) ~= nil then
				local n = tonumber(key) 
				if n == 0 then n = 10 end
				local m = mech.inventory[n]
				local p = player.inventory[n]
				mech.inventory[n] = p
				player.inventory[n] = m

			end
			if key == "return" then
				if player.currentSchemaID >=1 and player.currentSchemaID <=4 then
					local matchesSchema = true
					local s = playerUpgrades[player.currentSchemaID]
					for i=1,#s.recipe do
						if mech.inventory[i] ~= s.recipe[i] then
							matchesSchema = false
							break
						end
					end
					if matchesSchema then
						for i=1,#s.recipe do
							mech.inventory[i] = "nothing"
						end
						s.upgrade()
					end
				end
			end 
		end
	}

	addItem {
		id="mechGrinder", 
		name="Grinder", 
		index=40, 
		quad=q(8), 
		recipe={"can", "motor", "metal", "crystal", "stdframe"}, 
		onCreate=function(mech)
			mech.isGrinding = false
		end,
		onUI=function(mech)
			if not mech.isGrinding then
				pushInventoryLines(mech)
				table.insert(reactor.uilines, "Press ENTER to start grinding.")
			else
				table.insert(reactor.uilines, "Currently grinding...")
			end
		end,
		onKeyPressed=function(mech,key)
			if tonumber(key) ~= nil and mech.isGrinding == false then
				local n = tonumber(key) 
				if n == 0 then n = 10 end
				local m = mech.inventory[n]
				local p = player.inventory[n]
				mech.inventory[n] = p
				player.inventory[n] = m
			end
			if mech.isGrinding == false and key == "return" then
				mech.isGrinding = true
				cron.after(30, function(mm)
					for i,item in mm.inventory do
						if reactor.itemTypes[item].mechGrinder then
							mm.inventory[i] = reactor.itemTypes[item].mechGrinder
						end
					end
					mm.isGrinding=false
				end, mech)
			end
		end
	}
	addItem {
		id="mechChemWasher", 
		name="Chemical Washer", 
		index=41, 
		quad=q(9),
		recipe={"can", "motor", "coil", "syntheticfiber", "basicframe"},
		onCreate=function(mech)
			mech.isWashing = false
		end,
		onUI=function(mech)
			if not mech.isWashing then
				pushInventoryLines(mech)
				table.insert(reactor.uilines, "Press ENTER to start washing")
			else 
				table.insert(reactor.uilines, "Currently washing...")
			end
		end,
		onKeyPressed=function(mech,key)
			if tonumber(key) ~= nil and mech.isWashing == false then
				local n = tonumber(key) 
				if n == 0 then n = 10 end
				local m = mech.inventory[n]
				local p = player.inventory[n]
				mech.inventory[n] = p
				player.inventory[n] = m
			end
			if mech.isWashing == false and key == "return" then
				mech.isWashing = true
				cron.after(math.random(9,13), function(mm)
					for i,item in mm.inventory do
						if reactor.itemTypes[item].mechChemWasher then
							mm.inventory[i] = reactor.itemTypes[item].mechChemWasher
						end
					end
					mm.isWashing=false
				end, mech)
			end
		end
	}

	addItem {
		id="mechReactor",
		name="Nuclear Reactor", 
		index=43, 
		quad=q(11), 
		recipe={"ucell","capacitor", "syntheticfiber", "syntheticfiber","circuitboard","sensorarray","can","mechPump","advframe","advframe"},
		onCreate = function(mech) 
			mech.isCharged = false 
		end, 
		onUI=function(mech)
			pushInventoryLines(mech)

			local cc = true
			for i,item in ipairs(mech.inventory) do
				cc = cc and (item=="ucell")
			end
			mech.isCharged = cc
			if mech.isCharged then table.insert(reactor.uilines, "The reactor is fully charged!")
			else table.insert(reactor.uilines, "The reactor requires more uranium cells before it will fully charge.")
			end
		end, 
		onKeyPressed=function(mech, key)
			if tonumber(key) ~= nil then
				local n = tonumber(key) 
				if n == 0 then n = 10 end
				local m = mech.inventory[n]
				local p = player.inventory[n]
				mech.inventory[n] = p
				player.inventory[n] = m
			end
		end
	}

	addItem {
		id="mechTeleporter",
		name="Teleporter", 
		index=44,
		quad=q(12), 
		recipe={"crystalcapacitor", "crystalcapacitor", "crystalcapacitor", "sensorarray", "sensorarray", "circuitboard", "circuitboard","wiring","solenoid", "advframe"},
		onUI=function(mech)
			local x,y = mech.tx, mech.ty
			local ss = "mechSignalStabilizer"
			local tb = "mechTransmissionBooster"
			local gn = "mechGalacticNav"
			local nr = "mechReactor"
			local function m(dx,dy) 
				if reactor.machineGrid[(x+dx)+64*(y+dy)] then 
					return reactor.machineGrid[(x+dx)+64*(y+dy)].t.id 
				end 
			end
			local function mmm(dx,dy)
				if reactor.machineGrid[(x+dx)+64*(y+dy)] then 
					return reactor.machineGrid[(x+dx)+64*(y+dy)] 
				end 
			end
			isSetup = (
				m(-2,-2) == tb and --quadrant II
				m(-1,-2) == tb and
				m(-2,-1) == tb and 
				m(-1,-1) == tb and
				m(1,1) == tb and --quadrant 4
				m(2,1) == tb and
				m(1,2) == tb and 
				m(2,2) == tb and 
				m(-1,1) == ss and --quadrant 3
				m(-1,2) == ss and
				m(-2,1) == ss and
				m(-2,2) == ss and
				m(1,-1) == ss and --quadrant 1
				m(1,-2) == ss and
				m(2,-1) == ss and
				m(2,-2) == ss and
				m(-2, 0) == gn and --navigators
				m(2,0) == gn and
				m(0,-2) == gn and
				m(0, 2) == gn and
				m(-1, 0) == nr and mmm(-1,0).isCharged and
				m(1, 0) == nr and mmm(1,0).isCharged and
				m(0, -1) == nr and mmm(0,-1).isCharged and
				m(0,1) == nr and mmm(0,1).isCharged 
			)
			if not isSetup then
				table.insert(reactor.uilines, "Device: INACTIVE")
				table.insert(reactor.uilines, "Error: Incorrect Configuration")
				table.insert(reactor.uilines, "Please refer to accompianing diagrams for the correct configuration.")
				table.insert(reactor.uilines, "Share and Enjoy!")
			else
				table.insert(reactor.uilines, "Device: ACTIVE")
				table.insert(reactor.uilines, "Press ENTER to teleport to sector:")
				table.insert(reactor.uilines, "ZZ9:plural:Z-Alpha")
			end
		end,
		onKeyPressed = function(mech, key)
			if isSetup and key == "return" then
				reactor.endingSequence = true
				reactor.endingParticles:start()
				cron.after(10, function() reactor:gotoState("CreditsState") end)
			end
		end
	}

	addItem {
		id="mechGalacticNav", 
		name="Galactic Navigator", 
		index=45,
		quad=q(13), 
		recipe={"crystalcapacitor","circuitboard","circuitboard","circuitboard",
		"circuitboard","wiring","wiring","capacitor","advframe", "sensorarray"}
	}
	addItem {
		id="mechSignalStabilizer", 
		name="Signal Stabilizer", 
		index=46,
		quad=q(14), 
		recipe={"circuitboard","sensorarray","crystalcapacitor","advframe"}
	}

	addItem {
		id="mechTransmissionBooster",
		name="Transmission Booster", 
		index=47, 
		quad=q(14),
		recipe={"coil", "coil", "coil", "coil","circuitboard","sensorarray","advframe"}
	}
end

parkoursurvive={
	step_timer=0,
	step_time=0.5,
	speed=1,
	player={},
}

minetest.register_globalstep(function(dtime)
	if parkoursurvive.step_timer>parkoursurvive.step_time then
		parkoursurvive.step_timer=0
	else
		parkoursurvive.step_timer=parkoursurvive.step_timer+dtime
		return
	end
	for _,player in ipairs(minetest.get_connected_players()) do
		if not player:get_attach() and player:get_player_control().aux1 then
			local pos=player:get_pos()
			local node=minetest.registered_nodes[minetest.get_node(pos).name]
			if node and (node.liquid_viscosity==0 and not node.climbable and node.damage_per_second==0) then
				local e=minetest.add_entity(pos, "parkoursurvive:player")
				e:get_luaentity().user=player
				player:set_attach(e,"",{x=0,y=0,z=0},{x=0,y=0,z=0})
				e:set_velocity(player:get_player_velocity())
			end
		end

	end
end)

minetest.register_entity("parkoursurvive:player",{
	hp_max = 20,
	physical = true,
	collisionbox = {-0.35,0,-0.35,0.35,1.8,0.35},
	visual =  "sprite",
	textures = {"parkoursurvive_t.png"},
	makes_footstep_sound = true,
	on_punch=function(self, puncher, time_from_last_punch, tool_capabilities)
		if tool_capabilities and tool_capabilities.damage_groups and tool_capabilities.damage_groups.fleshy then
			self.user:set_hp(self.user:get_hp()-tool_capabilities.damage_groups.fleshy)
		end
		return self
	end,
	on_activate=function(self, staticdata)
		minetest.after(0.1, function(self)
			if not self.user then
				self.object:remove()
			end
		end, self)
		self.object:set_acceleration({x=0,y=-20,z =0})
		local pos=self.object:get_pos()
		pos.y=pos.y+0.1
		self.object:set_pos(pos)
		return self
	end,
	on_step=function(self, dtime)
		if self.start>0 then
			self.start=self.start-dtime
			return
		elseif not (self.user and self.user:get_attach()) then
			self.object:remove()
			return
		end
		local key=self.user:get_player_control()
		local pos=self.object:get_pos()
		local node=minetest.registered_nodes[minetest.get_node(pos).name]
		local v=self.object:get_velocity()
		self.object:set_yaw(self.user:get_look_yaw()-math.pi/2)

		if (not key.aux1 and self.speed<=1) or self.user:get_hp()<=0 or not node or node.liquid_viscosity>0 or node.climbable or node.damage_per_second>0 then
			self.user:set_detach()
			self.object:remove()
			return
		end

		if v.y<0 and not self.fallingfrom then
			self.fallingfrom=pos.y
		elseif self.fallingfrom and v.y==0 then
			local from=math.floor(self.fallingfrom+0.5)
			local hit=math.floor(pos.y+0.5)
			local d=from-hit
			self.fallingfrom=nil
			if minetest.get_node({x=pos.x,y=pos.y-2,z=pos.z}).name~="ignore" and d>=10 then
				self.on_punch(self, self.user, 1, {damage_groups={fleshy=d}})
			end
		end

		if key.jump and v.y==0 then
			v.y=self.speed
		elseif key.up and self.speed<10 then
			self.speed=self.speed*1.1
		elseif (key.down or not key.aux1) and self.speed>1 then
			self.speed=self.speed*0.9
		else
			self.speed=self.speed*0.95
			v.x=v.x*self.speed
			v.z=v.z*self.speed
			if math.abs(v.x+v.z)<0.1 or self.speed<=1 then
				v.x=0
				v.z=0
				self.speed=1
			end
		end


		if self.speed>1 then
			local yaw=self.object:get_yaw()
			if yaw ~= yaw or type(yaw)~="number" then
				return
			end
			v.x=math.sin(yaw)*-self.speed
			v.z=math.cos(yaw)*self.speed
		end

		self.object:set_velocity(v)
	end,
	speed=1,
	type="npc",
	team="Sam",
	start=0.15,
})
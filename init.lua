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
		if not player:get_attach() and player:get_player_control().RMB and player:get_wielded_item():get_name()=="" then

			local pos=player:get_pos()
			local node=minetest.registered_nodes[minetest.get_node(pos).name]
			if node and (node.liquid_viscosity==0 and not node.climbable and node.damage_per_second==0) then
				local e=minetest.add_entity(pos, "parkoursurvive:player")
				e:get_luaentity().user=player
				player:set_attach(e,"",{x=0,y=0,z=0},{x=0,y=0,z=0})
				e:set_velocity(player:get_player_velocity())
			--	player:set_eye_offset({x=0,y=0,z=5},{x=0,y=0,z=0})
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
	pointable = false,
	on_punch=function(self, puncher, time_from_last_punch, tool_capabilities)
		if not (puncher:is_player() and puncher:get_player_name()==self.user:get_player_name()) and tool_capabilities and tool_capabilities.damage_groups and tool_capabilities.damage_groups.fleshy then
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
		local pos=self.object:get_pos()
		pos.y=pos.y+0.1
		self.object:set_pos(pos)
		return self
	end,
	falling=function(self,pos)
		if self.v.y<0 and not self.fallingfrom then
			self.fallingfrom=pos.y
		elseif self.fallingfrom and self.v.y==0 then
			local from=math.floor(self.fallingfrom+0.5)
			local hit=math.floor(pos.y+0.5)
			local d=from-hit
			self.fallingfrom=nil
			if minetest.get_node({x=pos.x,y=pos.y-2,z=pos.z}).name~="ignore" and d>=10 then
				self.on_punch(self, self.object, 1, {damage_groups={fleshy=d}})
			end
		end
	end,
	node=function(pos)
		return minetest.registered_nodes[minetest.get_node(pos).name] or minetest.registered_nodes["air"]
	end,
	walls=function(self,pos,key)

		local p={x=0,y=0,z=0}
		local a={x=0,y=-20,z=0}
		local yaw=self.object:get_yaw()
		if yaw ~= yaw or type(yaw)~="number" then
			return
		end
		p.x=math.sin(yaw)*-1
		p.z=math.cos(yaw)*1

		local f={x=pos.x+p.x,y=pos.y,z=pos.z+p.z}
		local b={x=pos.x-p.x,y=pos.y,z=pos.z-p.z}
		local r={x=pos.x+(math.sin(yaw-1.5)*-1),y=pos.y,z=pos.z+math.cos(yaw-1.5)}
		local l={x=pos.x+(math.sin(yaw+1.5)*-1),y=pos.y,z=pos.z+math.cos(yaw+1.5)}

--wall climb/catleap
		if self.v.y~=0 and key.RMB and math.abs(self.v.y)<20 and self.node({x=pos.x,y=pos.y-1,z=pos.z}).walkable==false and
		((self.node(f).walkable and self.node({x=f.x,y=f.y+1,z=f.z}).walkable==false)
		 or (self.node({x=f.x,y=f.y+1,z=f.z}).walkable and self.node({x=f.x,y=f.y+2,z=f.z}).walkable==false)
		or (self.node({x=f.x,y=f.y+2,z=f.z}).walkable and self.node({x=f.x,y=f.y+3,z=f.z}).walkable==false)) then
			a.y=0
			self.active=1
			if key.jump then
				self.v.y=5
				self.speed=2
			elseif key.down then
				self.v.y=7
				self.speed=-10
			else
				self.v.y=0
				self.speed=0
			end
--wallrun
		elseif self.v.y==0 and self.speed>5 and self.node(f).walkable and self.node({x=f.x,y=f.y+1,z=f.z}).walkable then
			if self.node({x=f.x,y=f.y+2,z=f.z}).walkable then
				self.v.y=self.speed*1.2
			else
				self.v.y=self.speed
			end
			self.speed=1
			self.active=1
--kong

		elseif self.v.y==0 and self.speed>9 and key.RMB and self.node(f).walkable and self.node({x=f.x,y=f.y+1,z=f.z}).walkable==false then
			self.v.y=5
			self.speed=30
			self.object:set_pos({x=pos.x,y=pos.y+1,z=pos.z})
		elseif self.v.y==0 and self.speed>0 and self.node(f).walkable then
--hit a wall

			if key.RMB and self.speed<2 then
				self.v.y=7
			else
				self.speed=self.speed*0.9
			end
		end

		self.object:set_acceleration(a)
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
		local node=self.node(pos)
		self.v=self.object:get_velocity()
		self.object:set_yaw(self.user:get_look_yaw()-math.pi/2)
--exit
		if (not key.RMB and not key.jump and math.abs(self.speed)<0.5 and self.active==0) or self.user:get_hp()<=0 or node.liquid_viscosity>0 or node.climbable or node.damage_per_second>0 then
			if self.user then
				self.falling(self,pos)
				self.user:set_detach()
			end
			self.object:remove()
			return
		end
		self.active=0

		self.falling(self,pos)

		if self.walls(self,pos,key) then return end
--control & speed
		if key.jump and self.v.y==0 then
--precision jump
			if self.speed==0 then
				self.v.y=7
				self.speed=14
			else
				self.v.y=self.speed
			end
		elseif key.up and self.speed>=0 and self.speed<10 then
			if self.speed<1 then
			self.speed=2
			end
			self.speed=self.speed*1.05
		elseif not self.fallingfrom then
			if math.abs(self.speed)<0.5 then
				self.v.x=0
				self.v.z=0
				self.speed=0
			end
			self.speed=self.speed*0.9
			self.v.x=self.v.x*self.speed
			self.v.z=self.v.z*self.speed
		end

		if math.abs(self.speed)>1 then
			self.active=1
			local yaw=self.object:get_yaw()
			if yaw ~= yaw or type(yaw)~="number" then
				return
			end
			self.v.x=math.sin(yaw)*-self.speed
			self.v.z=math.cos(yaw)*self.speed
		end

		self.object:set_velocity(self.v)
	end,
	active=1,
	speed=1,
	type="npc",
	team="Sam",
	start=0.15,
})
parkoursurvive={
	step_timer=0,
	step_time=0.5,
	player={},
	playeranim={
		stand={x=1,y=39,speed=30},
		walk={x=41,y=61,speed=30},
		mine={x=65,y=75,speed=30},
		hugwalk={x=80,y=99,speed=30},
		lay={x=113,y=123,speed=0},
		sit={x=101,y=111,speed=0},
	},
}

parkoursurvive.player_anim=function(self,typ)
	if typ==self.anim then
		return
	end
	self.anim=typ
	self.object:set_animation({x=parkoursurvive.playeranim[typ].x, y=parkoursurvive.playeranim[typ].y, },parkoursurvive.playeranim[typ].speed,0)
	return self
end

minetest.register_on_joinplayer(function(player)
	local name=player:get_player_name()
	parkoursurvive.player[name]={
		power=100,
		bar_back=player:hud_add({
			hud_elem_type="statbar",
			position={x=1,y=0},
			text="parkoursurvive_bar2.png",
			number=0,
			size={x=5,y=20},
			direction=1,
		}),
		bar=player:hud_add({
			hud_elem_type="statbar",
			position={x=1,y=0},
			text="parkoursurvive_bar.png",
			number=0,
			size={x=5,y=20},
			direction=1,
		})
	}
end)

parkoursurvive.power=function(player,add)
	local a=parkoursurvive.player[player:get_player_name()]
	if not a or (a.power>=100 and add>0) then
		return
	elseif a.power+add<-10 then
		a.power=-10
	else
		a.power=a.power+add
	end
	if a.power>=100 then
		a.power=100
		player:hud_change(a.bar, "number", 0)
		player:hud_change(a.bar_back, "number", 0)
	else
		player:hud_change(a.bar, "number", a.power)
		player:hud_change(a.bar_back, "number", 100)
	end
end


minetest.register_on_respawnplayer(function(player)
	parkoursurvive.player[player:get_player_name()].power=100
end)

minetest.register_on_leaveplayer(function(player)
	parkoursurvive.player[player:get_player_name()]=nil
end)


minetest.register_globalstep(function(dtime)
	if parkoursurvive.step_timer>parkoursurvive.step_time then
		parkoursurvive.step_timer=0
	else
		parkoursurvive.step_timer=parkoursurvive.step_timer+dtime
		return
	end
	for _,player in ipairs(minetest.get_connected_players()) do
		if not player:get_attach() and player:get_hp()>0 and player:get_player_control().RMB and player:get_wielded_item():get_name()=="" and parkoursurvive.player[player:get_player_name()].power>10 then

			local pos=player:get_pos()
			local node=minetest.registered_nodes[minetest.get_node(pos).name]
			if node and (node.liquid_viscosity==0 and not node.climbable and node.damage_per_second==0) then
				local e=minetest.add_entity({x=pos.x,y=pos.y+1,z=pos.z}, "parkoursurvive:player")
				local p=parkoursurvive.player[player:get_player_name()]
				p.textures=player:get_properties().textures
				e:get_luaentity().user=player
				e:set_velocity(player:get_player_velocity())
				e:set_properties({textures=p.textures})
				e:set_yaw(player:get_look_yaw()-math.pi/2)
				player:set_attach(e,"",{x=0,y=10,z=0},{x=0,y=0,z=0})
				player:hud_change(p.bar_back, "number", 100)
				player:hud_change(p.bar, "number", p.power)
				player:set_properties({textures={"parkoursurvive_t.png","parkoursurvive_t.png","parkoursurvive_t.png","parkoursurvive_t.png","parkoursurvive_t.png","parkoursurvive_t.png"}})
				player:set_eye_offset({x=0,y=-10,z=1},{x=0,y=0,z=0})
			end
		else
			parkoursurvive.power(player,2)
		end
	end
end)

minetest.register_entity("parkoursurvive:player",{
	hp_max = 10000,
	physical = true,
	collisionbox = {-0.35,-1.0,-0.35,0.35,0.8,0.35},
	visual =  "mesh",
	mesh="parkoursurvive_character.b3d",
	makes_footstep_sound = true,
--	pointable = false, makes players can cheat in pvp
	on_punch=function(self, puncher, time_from_last_punch, tool_capabilities)
		if not (puncher:is_player() and puncher:get_player_name()==self.user:get_player_name()) and tool_capabilities and tool_capabilities.damage_groups and tool_capabilities.damage_groups.fleshy then
			local hp=self.user:get_hp()-tool_capabilities.damage_groups.fleshy
			if hp<1 then
				self.exit(self,{},self.object:get_pos())
			end
			self.user:set_hp(hp)
		end
		return self
	end,
	on_activate=function(self, staticdata)
		minetest.after(0, function(self)
			if not (self.user and self.user:get_pos()) then
				self.object:remove()
				return
			end
			self.username=self.user:get_player_name()
		end, self)
		return self
	end,
	exit=function(self,key,pos,power)
		local node=self.node(pos)
		if not power or power<0 or not self.v or (not key.RMB and not key.jump and math.abs(self.speed)<0.5) or self.user:get_hp()<=0 or node.liquid_viscosity>0 or node.climbable or node.damage_per_second>0 then
			if self.user and self.user:get_pos() then
				self.user:set_eye_offset({x=0,y=0,z=0},{x=0,y=0,z=0})
				self.user:set_properties({textures=parkoursurvive.player[self.username].textures})
				parkoursurvive.power(self.user,0)
				self.falling(self,pos)
				self.user:set_detach()
			end
			self.object:remove()
			return
		end
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
		pos={x=pos.x,y=pos.y-0.5,z=pos.z}
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

		if key.RMB and math.abs(self.v.y)<20 and self.node({x=pos.x,y=pos.y-1,z=pos.z}).walkable==false and not self.node({x=pos.x,y=pos.y+2,z=pos.z}).walkable and
		((self.node(f).walkable and self.node({x=f.x,y=f.y+1,z=f.z}).walkable==false)
		 or (self.node({x=f.x,y=f.y+1,z=f.z}).walkable and self.node({x=f.x,y=f.y+2,z=f.z}).walkable==false)
		or (self.node({x=f.x,y=f.y+2,z=f.z}).walkable and self.node({x=f.x,y=f.y+3,z=f.z}).walkable==false)) then
--wall climb/catleap
			a.y=0
			if key.jump then
				self.v.y=5
				self.speed=2
				parkoursurvive.power(self.user,-1)

			elseif key.down then
				self.v.y=7
				self.speed=-10
				parkoursurvive.power(self.user,-3)
			else
				self.v.y=0
				self.speed=0
				parkoursurvive.power(self.user,-0.2)
			end
			self.tic=nil
		elseif key.left and self.node(r).walkable and self.node({x=pos.x,y=pos.y-1,z=pos.z}).walkable==false then
--tic tac left
			if self.v.y>-5 then
				self.v.y=5
			end
			self.tic=true
			self.object:set_velocity({x=math.sin(yaw+1.5)*-10,y=self.v.y,z=math.cos(yaw+1.5)*10})
			parkoursurvive.power(self.user,-0.5)
			return true
		elseif key.right and self.node(l).walkable and self.node({x=pos.x,y=pos.y-1,z=pos.z}).walkable==false then
--tic tac right
			if self.v.y>-5 then
				self.v.y=5
			end
			self.tic=true
			self.object:set_velocity({x=math.sin(yaw-1.5)*-10,y=self.v.y,z=math.cos(yaw-1.5)*10})
			parkoursurvive.power(self.user,-0.5)
			return true
		elseif self.tic then
			if not (key.left or key.right) or self.node({x=pos.x,y=pos.y-1,z=pos.z}).walkable then --self.v.y<-5 then --
				self.tic=nil
			else
				self.object:set_acceleration(a)
				return true
			end	
		elseif key.up and self.v.y==0 and self.speed>5 and self.node(f).walkable and self.node({x=f.x,y=f.y+1,z=f.z}).walkable then
--wallrun
			if self.node({x=f.x,y=f.y+2,z=f.z}).walkable then
				self.v.y=self.speed*1.2
				parkoursurvive.power(self.user,-3)
			else
				parkoursurvive.power(self.user,-2)
				self.v.y=self.speed
			end
			self.speed=1
		elseif key.up and key.LMB and self.v.y>-10 and self.speed>5 and self.node(f).walkable==false and self.node({x=f.x,y=f.y+1,z=f.z}).walkable and self.node({x=f.x,y=f.y-1,z=f.z}).walkable==false then
--"under bar"
			parkoursurvive.power(self.user,-1)
			self.object:set_pos({x=pos.x,y=pos.y-1,z=pos.z})
		elseif key.up and key.LMB and self.v.y>-10 and self.speed>9 and self.speed<15 and self.node(f).walkable then
--kong
			parkoursurvive.power(self.user,-5)
			self.v.y=7
			self.speed=10
			self.object:set_pos({x=pos.x,y=pos.y+1,z=pos.z})
		elseif key.up and key.RMB and self.v.y==0 and self.node(f).walkable and self.node({x=pos.x,y=pos.y-1,z=pos.z}).walkable then
--vault
			parkoursurvive.power(self.user,-1)
			self.v.y=7
		elseif key.up and self.v.y==0 and self.speed<2 and self.node(f).walkable and self.node({x=pos.x,y=pos.y-1,z=pos.z}).walkable then
--hit a wall
			self.speed=self.speed*0.9
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
		local power=parkoursurvive.player[self.username].power
		if power<=0 then
			key={}
		end

		local pos=self.object:get_pos()
		self.v=self.object:get_velocity()
		self.exit(self,key,pos,power)
		self.object:set_yaw(self.user:get_look_yaw()-math.pi/2)
--exit
		self.falling(self,pos)

		if self.walls(self,pos,key) then return end

--control & speed
		if key.jump and self.v.y==0 and not self.fallingfrom then
--precision jump
			if self.speed==0 then
				self.v.y=7
				self.speed=14
				parkoursurvive.power(self.user,-3)
			elseif not self.node({x=pos.x,y=pos.y+2,z=pos.z}).walkable then
				self.v.y=self.speed
				parkoursurvive.power(self.user,-2)
			end
--run
		elseif key.up and self.speed>=0 and self.speed<10 then
			if self.speed<1 then
				self.speed=4
			end
			parkoursurvive.power(self.user,-0.3)
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
		else
			self.object:set_acceleration({x=0,y=-20,z=0})
		end
		if math.abs(self.speed)>0 then
			parkoursurvive.player_anim(self,"walk")
			local yaw=self.object:get_yaw()
			if yaw ~= yaw or type(yaw)~="number" then
				return
			end
			self.v.x=math.sin(yaw)*-self.speed
			self.v.z=math.cos(yaw)*self.speed
		else
			parkoursurvive.player_anim(self,"stand")
		end

		self.object:set_velocity(self.v)
	end,
	speed=0,
	type="npc",
	start=0.15,
})
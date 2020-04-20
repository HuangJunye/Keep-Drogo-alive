pico-8 cartridge // http://www.pico-8.com
version 21
__lua__
-- math.p8
-- by decodoku
math = {}
math.pi = 3.14159
math.max = max
math.sqrt = sqrt
math.floor = flr
function math.random()
  return rnd(1)
end
function math.cos(theta)
  return cos(theta/(2*math.pi))
end
function math.sin(theta)
  return -sin(theta/(2*math.pi))
end
function math.randomseed(time)
end
os = {}
function os.time()
end
-->8
-- microqiskit-lua
-- by decodoku
math.randomseed(os.time())

function quantumcircuit ()

  local qc = {}

  local function set_registers (n,m)
    qc._n = n
    qc._m = m or 0
  end
  qc.set_registers = set_registers

  qc.data = {}

  function qc.initialize (ket)
    ket_copy = {}
    for j, amp in pairs(ket) do
      if type(amp)=="number" then
        ket_copy[j] = {amp, 0}
      else
        ket_copy[j] = {amp[0], amp[1]}
      end
    end
    qc.data = {{'init',ket_copy}}
  end

  function qc.add_circuit (qc2)
    qc._n = math.max(qc._n,qc2._n)
    qc._m = math.max(qc._m,qc2._m)
    for g, gate in pairs(qc2.data) do
      qc.data[#qc.data+1] = ( gate )    
    end
  end
      
  function qc.x (q)
    qc.data[#qc.data+1] = ( {'x',q} )
  end

  function qc.rx (theta,q)
    qc.data[#qc.data+1] = ( {'rx',theta,q} )
  end

  function qc.h (q)
    qc.data[#qc.data+1] = ( {'h',q} )
  end

  function qc.cx (s,t)
    qc.data[#qc.data+1] = ( {'cx',s,t} )
  end

  function qc.measure (q,b)
    qc.data[#qc.data+1] = ( {'m',q,b} )
  end

  function qc.rz (theta,q)
    qc.h(q)
    qc.rx(theta,q)
    qc.h(q)
  end

  function qc.ry (theta,q)
    qc.rx(math.pi/2,q)
    qc.rz(theta,q)
    qc.rx(-math.pi/2,q)
  end

  function qc.z (q)
    qc.rz(math.pi,q)
  end

  function qc.y (q)
    qc.z(q)
    qc.x(q)
  end

  return qc

end

function simulate (qc, get, shots)

  if not shots then
    shots = 1024
  end

  function as_bits (num,bits)
    -- returns num converted to a bitstring of length bits
    -- adapted from https://stackoverflow.com/a/9080080/1225661
    local bitstring = {}
    for index = bits, 1, -1 do
        b = num - math.floor(num/2)*2
        num = math.floor((num - b) / 2)
        bitstring[index] = b
    end
    return bitstring
  end

  function get_out (j)
    raw_out = as_bits(j-1,qc._n)
    out = ""
    for b=0,qc._m-1 do
      if output_map[b] then
        out = raw_out[qc._n-output_map[b]]..out
      end
    end
    return out
  end


  ket = {}
  for j=1,2^qc._n do
    ket[j] = {0,0}
  end
  ket[1] = {1,0}

  output_map = {}

  for g, gate in pairs(qc.data) do

    if gate[1]=='init' then

      for j, amp in pairs(gate[2]) do
          ket[j] = {amp[1], amp[2]}
      end

    elseif gate[1]=='m' then

      output_map[gate[3]] = gate[2]

    elseif gate[1]=="x" or gate[1]=="rx" or gate[1]=="h" then

      j = gate[#gate]

      for i0=0,2^j-1 do
        for i1=0,2^(qc._n-j-1)-1 do
          b1=i0+2^(j+1)*i1 + 1
          b2=b1+2^j

          e = {{ket[b1][1],ket[b1][2]},{ket[b2][1],ket[b2][2]}}

          if gate[1]=="x" then
            ket[b1] = e[2]
            ket[b2] = e[1]
          elseif gate[1]=="rx" then
            theta = gate[2]
            ket[b1][1] = e[1][1]*math.cos(theta/2)+e[2][2]*math.sin(theta/2)
            ket[b1][2] = e[1][2]*math.cos(theta/2)-e[2][1]*math.sin(theta/2)
            ket[b2][1] = e[2][1]*math.cos(theta/2)+e[1][2]*math.sin(theta/2)
            ket[b2][2] = e[2][2]*math.cos(theta/2)-e[1][1]*math.sin(theta/2)
          elseif gate[1]=="h" then
            for k=1,2 do
              ket[b1][k] = (e[1][k] + e[2][k])/math.sqrt(2)
              ket[b2][k] = (e[1][k] - e[2][k])/math.sqrt(2)
            end
          end

        end
      end

    elseif gate[1]=="cx" then

      s = gate[2]
      t = gate[3]

      if s>t then
        h = s
        l = t
      else
        h = t
        l = s
      end

      for i0=0,2^l-1 do
        for i1=0,2^(h-l-1)-1 do
          for i2=0,2^(qc._n-h-1)-1 do
            b1 = i0 + 2^(l+1)*i1 + 2^(h+1)*i2 + 2^s + 1
            b2 = b1 + 2^t
            e = {{ket[b1][1],ket[b1][2]},{ket[b2][1],ket[b2][2]}}
            ket[b1] = e[2]
            ket[b2] = e[1]
          end
        end
      end

    end

  end

  if get=="statevector" then
    return ket
  else

    probs = {}
    for j,amp in pairs(ket) do
      probs[j] = amp[1]^2 + amp[2]^2
    end

    if get=="fast counts" then

      c = {}
      for j,p in pairs(probs) do
        out = get_out(j)
        if c[out] then
          c[out] = c[out] + probs[j]*shots
        else
          if out then -- in case of pico8 weirdness
            c[out] = probs[j]*shots
          end
        end
      end
      return c

    else

      m = {}
      for s=1,shots do
        cumu = 0
        un = true
        r = math.random()
        for j,p in pairs(probs) do
          cumu = cumu + p
          if r<cumu and un then
            m[s] = get_out(j)
            un = false
          end
        end
      end

      if get=="memory" then
        return m

      elseif get=="counts" then
        c = {}
        for s=1,shots do
          if c[m[s]] then
            c[m[s]] = c[m[s]] + 1
          else
            if m[s] then -- in case of pico8 weirdness
              c[m[s]] = 1
            else
              if c["error"] then
                c["error"] = c["error"]+1
              else
                c["error"] = 1
              end
            end
          end
        end
        return c

      end

    end

  end

end
-->8
-- keep drogon alive
-- by Kirais & llunapuert
-- main game
cartdata(0)
function _init()
  t=0
  scene = "title"
  frames = 0

  drogon = {
    sp=0,
    x=59,
    y=10,
    w=8,
    h=8,
    dx=1,
    dy=1/10,
    health=60,
    p=0,
    t=0,
    blue=false,
    imm=false
  }
  crossbows = {}
  arrows = {}
  shake_str = {x=0,y=0}

  init_crossbows()
  music(2)
end

function _update ()
  frames += 1
  if scene == "title" then
    update_title()
  elseif scene == "game" then
    update_game()
  elseif scene == "dead" then
    music(-1)
    update_death()
  elseif scene == "win" then
    update_win()
  end
end

function _draw ()
  if scene == "title" then
    draw_title()
  elseif scene == "game" then
    draw_game()
  elseif scene == "dead" then
    draw_death()
  elseif scene == "win" then
    draw_win()
  end
end

function update_game()
  t+=1
  drogon.y+=drogon.dy

  if drogon.imm then
    drogon.t+=1
    shake()
    if drogon.t>30 then
      camera(0,0)
      drogon.imm=false
      drogon.t=0
    end
  end
  if drogon.y>=100 then scene = "win" end

  update_crossbows()
  update_arrows()
  collision()

  if drogon.health<=0 then scene = "dead" end 

  if(t%8<2) then
    drogon.sp=0
  elseif (t%8<4) then
    drogon.sp=1
  elseif (t%8<6) then
    drogon.sp=2
  else
    drogon.sp=3
  end

  if btn(0) then drogon.x-=drogon.dx end
  if btn(1) then drogon.x+=drogon.dx end
  if btnp(5) then
    if drogon.blue == true then
      drogon.blue = false
    else
      drogon.blue = true
    end
  end
end

function draw_game()
  cls()
  draw_sunset()
  draw_lvl()
  if not drogon.imm or t%8 < 4 then
    if drogon.blue then
      spr(drogon.sp+16,drogon.x,drogon.y)
    else
      spr(drogon.sp,drogon.x,drogon.y)
    end
  end
  
  for a in all(arrows) do
    if a.blue then
      spr(a.sp+16,a.x,a.y)
    else
      spr(a.sp,a.x,a.y)
    end
  end

  for c in all(crossbows) do
    spr(c.sp,c.x,c.y)
    spr(c.sp+16,c.x,c.y+6)
  end

  draw_ui()
end

function draw_ui()
  local health = flr(drogon.health)
  if health >= 100 then health = "max" end
  print(health,5,2,0)
  print(health,5,1,7)
  
  local healthbar = 117
  local ragemode = 7
  if drogon.health < 20 and every(4,0,2) then
    ragemode = 9
  end
  if drogon.blue then color = 12 else color = 8 end
  rectfill(21,2,21+drogon.health,6,ragemode)
  rectfill(20,1,20+drogon.health,5,color)
end

function update_title()
 if btn(4) then
  scene = "game"
 end
end

function draw_title()
 cls()
 print("Keep Drogon Alive",30,50) -- title
 print("press 🅾️ to start",30,80)
 -- print high score from data
 print("high-score",40,100)
 print(dget(0),85,100)
end

function update_death()
  if btn(4) then
     scene = "title"
     sfx(-1)
     music(0)
     _init()
  end
end

function draw_death()
  cls()
  music(8)
  print("game over",50,50,4)
end

function update_win()
end

function draw_win()
  cls()
  print("you win",50,50,4)
end

-- handy functions
function random()
  qc = quantumcircuit()
  qc.set_registers(1,1)
  qc.h(0)
  qc.measure(0,0)
  result = simulate(qc,"counts",1)
  if result["1"]==1 then 
    return true
  else
    return false
  end
end

function lerp(a,b,t)
  return a + t*(b-a)
end

function shake()
 -- shake camera
 shake_str.x=2-rnd(4)
 shake_str.y=2-rnd(4)
 camera(shake_str.x,shake_str.y)
end

function every(duration,offset,period)
  local offset = offset or 0
  local period = period or 1
  local offset_frames = frames + offset
  return offset_frames % duration < period
end

function pythagoras(ax,ay,bx,by)
  local x = ax-bx
  local y = ay-by
  return sqrt(x*x+y*y)
end

-- in game objects
function init_crossbows()
  for i=1,4 do
    local c = {
      sp=32,
      y=110,
      shotpattern=0
    }
    if i%2==0 then
      c.blue = true
    else
      c.blue = false
    end 
    if i%4<2 then
      c.x = 32
    else
      c.x = 96
    end
    add(crossbows, c)
  end
end

function update_crossbows()
  for c in all(crossbows) do
    if t/30 < 5.5 then
      c.shotpattern = 0
    elseif t/30 < 10 then
      c.shotpattern = 1
    else
      c.shotpattern = 2
    end
    if c.shotpattern == 0 then
      if c.blue then
        c.x+=cos(t/(180))
      else
        c.x-=cos(t/(180))
      end
      -- simple shots going downwards
      if every(10) then
        add_arrow(c.x, c.y, c.blue, 0, -1, -1)
      end
    elseif c.shotpattern == 1 then
      -- simple shots going downwards
      if c.blue then
        color = c.blue
        if every(100) then
          for i=-0.2,0.2,0.02 do
            add_arrow(c.x, c.y, color, i, -1, -1)
            color = not color
          end
        end
      else
        color = c.blue
        if every(100,50) then
          for i=-0.2,0.2,0.02 do
            add_arrow(c.x, c.y, color, i, -1, -1)
            color = not color
          end
        end
      end
    elseif c.shotpattern == 2 then
      dir = t/(30*4) - 1
      if c.blue then
        if every(10) then
          add_arrow(c.x, c.y, c.blue, (dir-2)/10, -1, -1)
          add_arrow(c.x, c.y, c.blue, (dir-4)/10, -1, -1)
        end
      else
        if every(10) then
          add_arrow(c.x, c.y, c.blue, (-dir+2)/10, -1, -1)
          add_arrow(c.x, c.y, c.blue, (-dir+4)/10, -1, -1)
        end
      end
    end
  end
end

function add_arrow(cb_x, cb_y, cb_blue, cb_direction, cb_velocity, cb_size) --needs only an x,y
  cb_direction = cb_direction
  cb_velocity = cb_velocity
  cb_blue = cb_blue
  cb_size = cb_size or 1
  -- only shoot arrows that are pointing forward
  if abs(cb_direction) <= 0.2 then
    local arrow = {
      sp = 33,
      x = cb_x,
      y = cb_y,
      direction = cb_direction,
      velocity = cb_velocity, 
      blue = cb_blue, 
      size = cb_size
    }
    add(arrows,arrow)
  end
end

function update_arrows()
  for p in all(arrows) do
    if pythagoras(p.x,p.y,drogon.x+3,drogon.y+4) < 15 and p.blue == drogon.blue then
      p.x = lerp(p.x,drogon.x+4,0.2)
      p.y = lerp(p.y,drogon.y+4,0.2)
    else
      p.x = p.x+p.velocity*sin(p.direction)
      p.y = p.y+p.velocity*cos(p.direction)
    end
  end
  for p = #arrows, 1, -1 do
    local x = arrows[p].x
    local y = arrows[p].y
    if x > 128 or x < 0 or y > 128 or y < 0 then del(arrows,arrows[p]) end
  end
end

function inside(point, enemy)
  if point == nil then return false end
  local px = point.x + 4
  local py = point.y + 4
  return
    px > enemy.x and px < enemy.x + enemy.w and
    py > enemy.y and py < enemy.y + enemy.h
end

function collision()
  -- enemy arrow collisions
  for p = #arrows, 1, -1 do
      if inside(arrows[p], drogon) then
        
        if arrows[p].blue == drogon.blue then
         -- if arrow is the same as drogon
         drogon.health += 1
        elseif arrows[p].blue ~= drogon.blue then
         -- if arrow is not the same as drogon
          if run_qc(arrows[p], drogon) then
            drogon.imm = true
            drogon.health -= 20
          end
        end
        del(arrows,arrows[p])
      end
  end
end

function run_qc(arrow, drogon)
  local qc = quantumcircuit()
  qc.set_registers(1,1)
  if drogon.blue then qc.h(0) end
  if arrow.blue then
    qc.h(0)
    qc.measure(0,0)
  else
    qc.measure(0,0)
  end
  
  result = simulate(qc, "counts", 1)
  if result["1"]==1 then 
    return true
  else
    return false
  end
end

-- Animated Clouds

apartm = {}
apartm.x0 = 0
apartm.y0 = 10
apartm.x1 = 90
apartm.y1 = 40

-- Let's define a couple of cloud styles below

cl01 = {
	current = 0, -- This is the unique timer for this cloud, each cloud object has it's own
	top_offset = 67, -- Off screen starting position for this layer of the cloud
	top_width = 5, -- Layer width
	middle_width = 9,
	middle_offset = 65,
	bottom_width = 4,
	bottom_offset = 68,
	max_size = false, -- Used as a flag to indicate the last animated layer has reached it's max size and should now start animating back.
	delay_start = 0, -- The start of the delay counter
	delay_end = 0 -- End of delay counter for this flag, once the counter reaches this value, the cloud will start it's animation.
}
cl02 = {
	current = 0,
	top_offset = 16,
	top_width = 5,
	middle_width = 9,
	middle_offset = 17,
	bottom_width = 4,
	bottom_offset = 14,
	max_size = false,
	delay_start = 0,
	delay_end = 0
}

cl03 = {
	current = 0,
	top_offset = 0,
	top_width = 5,
	middle_width = 8,
	middle_offset = -1,
	bottom_width = 5,
	bottom_offset = -2,
	max_size = false,
	delay_start = 0,
	delay_end = 200
}

function cloud_draw(cl_next, top) -- cl_next is the supplied, unique object i.e. cl01 or cl02. Top will dictate the vertical position of the cloud.
	if cl_next.delay_start < cl_next.delay_end then -- This counter will determine the start time of the cloud.
		cl_next.delay_start += 1
	else 
		if cl_next.current < 20  then -- Internal ticker, by adjusting the max value of current or the steps it increments by, you adjust the animation speed.
			cl_next.current += 2
			
		else 
			cl_next.current = 0 -- "current" has reached it's theshold so reset it for the next frame and then commence this frames animation
			cl_next.top_offset += 1 -- Move top, middle and bottom 1px
			cl_next.middle_offset += 1
			cl_next.bottom_offset += 1
			if cl_next.bottom_width > 3 and cl_next.bottom_width <= 11 and cl_next.max_size == false then
				cl_next.bottom_width +=1 -- Bottom layer hasn't reached it's max size so grow it's width 1px
		
			elseif cl_next.bottom_width >= 8 then -- Bottom is larger than max size so animate back.
				cl_next.bottom_width -= 1
				cl_next.max_size = true
			
			elseif cl_next.bottom_width < 9 and cl_next.max_size == true then -- Third stage in the width of the bottom layer makes this animation into a loop.
				cl_next.bottom_width += 1
				cl_next.max_size = false
			end
		end
		
		--line1
		for i=0,cl_next.top_width do -- We're using a for loop to render the width of each layer
			if cl_next.top_offset > 128 then -- By adjusting the max value, you can increase or decrease the position the cloud will reach before it returns to the start position.
				cl_next.top_offset = 0
			else
				pset(cl_next.top_offset+i, top, 7) -- draw the layer
			end
		end
		
		--line2
		for i=0,cl_next.middle_width do
			if cl_next.middle_offset > 128 then
				cl_next.middle_offset = 0
			else
				pset(cl_next.middle_offset+i, top+1, 7)
			end
		end
		
		--line3
		for i=0,cl_next.bottom_width do
			if cl_next.bottom_offset > 128 then
				cl_next.bottom_offset = 0
			else
				pset(cl_next.bottom_offset+i, top+2, 7)
			end
		end
	end
end

function draw_lvl()
	cloud01 = cloud_draw(cl01, 34) -- Call as many instances of clouds as needed, each with it's own unique object and vertical position
	cloud02 = cloud_draw(cl02, 48)
  cloud03 = cloud_draw(cl03, 16)
end

function draw_sunset()
  rectfill(0,0,127,83,9)
	line(0,84,127,84,2)
	rectfill(0,85,127,127,1)
	
	local sunx=30
	local suny=60
	local sunsize=7
	
	circfill(sunx,suny,sunsize,10)
	
	pal(5,9)
	pal(6,8)
	pal(7,2)
	for i=0,83 do
		sspr(0,12+(i/84)*56+sin(time()*.1+i*.01)*2,
		     64,1,
		     -10+cos(time()*.1+i*.025)*3,i,147,1)
	end
	
	pal()
	pal(2,0)
	if (sin(time()*.2+.2)>0) then
		pal(7,8)
		pal(6,12)
	else
		pal(7,12)
		pal(6,8)
	end
	spr(61,10,84-8)
	spr(61,23,84-8,1,1,true)
	pal()
	
	local count=120
	for i=1,count do
		
		if (i>count/6 and i-1<=count/6) then
			for x=0,5 do
				for y=0,4 do
					pal()
					pal(2,0)
					local t=(time()*.08+(x+1)*.1*(y+1))
					t-=flr(t)
					if (t>.75) then
						pal(7,8)
						pal(6,1)
					elseif (t>.5) then
						pal(7,1)
						pal(6,8)
					elseif (t>.25) then
						pal(7,12)
						pal(6,1)
					else
						pal(7,1)
						pal(6,12)
					end
					map(x*2,y*2,30+16*x,20+16*y,2,2)
				end
			end
		end
		
		srand(i)
		local speed=rnd(4)+4
		local x=(rnd(128)+time()*speed)%(128+40)-20
		local w=32+rnd(68)
		local h=flr((sin(time()*.5+i*1.618)*.4+.6)*10*(i/count*.7+.3))
		local y=84+i/count*44
		local bx=8
		if (rnd()<.5) then
			bx=40
		end
		if (h>0) then
			if (i<count/7) then
				pal(2,9)
				pal(13,8)
			else
				pal()
				if (x>84) then
					pal(2,13)
					pal(5,0)
				else
					pal(2,9)
					pal(5,2)
				end
			end
			pal(1,1)
			sspr(bx,0,32,8,x-w/2,y-h,w,h)
		end
	end
	
	//srand(time())
	count=800
	local shinew=25
	for i=1,count do
		local rand=rnd()
		local x=rand*shinew-shinew/2+sunx
		rand=1-abs(rand-.5)*2
		if (rnd()<rand) then
			local y=84+rnd()*rnd()*44
			local col=pget(x,y)
			if (col==2) then
				pset(x,y,10)
			elseif (col==13) then
				local col=9
				if (rnd()<.5) then
					col=10
				end
				line(x-1,y,x+1,y,col)
			elseif (rnd()<.3 and y<100) then
				//line(x-1,y,x+1,y,8+rnd(2))
			end
		end
	end
end

__gfx__
00108000101080010010800000108000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0108d000d108d01d1108d0010108d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
18888001dd8881ddd888801d08888000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
d008801d1d188dddd00881dd10088001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
d00888dd001888d0dd188dddd108881d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
dd1188dd000188000d11880ddd1188dd000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
d008880d0008880000088800d008880d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000080800000808000008080d000808d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0010c0001010c0010010c0000010c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010c2000210c2012110c2001010c2000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1cccc00122ccc1222cccc0120cccc000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
200cc012121cc222200cc122100cc001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
200ccc22001ccc20221cc222210ccc12000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2211cc220001cc000211cc022211cc22000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
200ccc02000ccc00000ccc00200ccc02000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000c0c00000c0c00000c0c02000c0c2000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000006060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00444000000800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
04040400000800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
40040040000800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
66666660000800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00040000000800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00040000000800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000500000600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00050d50006060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
050d5d50000c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0d5d5d50000c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0d5d5540000c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
45454404000c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
04000040000c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00444400000c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
0004011d0160001610006100263000640006300462006600076000961000630016300362006600096100b6100d6300e640106301262014600156001661017630186301a6201a6001b6101b6101b6301b6401a630
0003081b3972038730377303673035720347203372032720307402f7102d7102c710297102871025700227001f7001d7001b7001a7001970018700177001570014700147101272011730107300f7300e7300a700
011000001c0501c0501c0501c0501c0501c050150501505015050150501505015050180501a0501c0501c0501c0501c05015050150501505015050180501a0501705017050170501705017050170501705017050
01100000170501705017050170501705017050170501705017050170501705017050170501705017050170501a0501a0501a0501a0501a0501a05013050130501305013050130501305018050170501a0501a050
011000001a0501a050130501305013050130501305013050180501705015050150511505115051150411504115041150411503115031150311503115021150211502115021150111501115011150111501115011
0122001b111441a1441a1541a15013150181501815018150111501a1501a1501b1501b150181501815018150111301b1201b1501a1501a1201815018110171501711018130181101d1501d1501d1501f1500f150
0113000015150151501d1501d1501f1501f1501b1501b1501b1501315020150201501d1501d1501b1501b1501a1501a15018150181501815018150201001d1001d1001c1001c1001a1001a100151001510015100
011300001515015150151500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__music__
00 00414344
03 00014344
01 02434344
00 03424344
02 04424344
01 00010244
00 00010344
02 00010444
03 05424344
00 06424344
02 07424344

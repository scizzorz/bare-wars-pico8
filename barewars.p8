pico-8 cartridge // http://www.pico-8.com
version 16
__lua__
-- bare wars
-- by john weachock

-- enums
local b = {left=0, right=1, up=2, down=3, o=4, x=5}
local c = {
  black=0, darkblue=1, darkpurple=2, darkgreen=3,
  brown=4, darkgrey=5, lightgrey=6, white=7,
  red=8, orange=9, yellow=10, green=11,
  blue=12, indigo=13, pink=14, peach=15,
}
local f = {
  solid=0,
  food=1,
  money=2,
  material=3,
}
local s = {
  splash=0,
  command=1,
  play=2,
  menu=3,
  move=4,
}

-- https://www.lexaloffle.com/bbs/?tid=3389
function pop(stack)
  local v = stack[#stack]
  stack[#stack]=nil
  return v
end

-- https://github.com/clowerweb/Lib-Pico8/blob/9580f8afd84dfa3f33e0c9c9131a595ede1f0a2a/distance.lua
function dst(o1, o2)
 return sqrt(sqr(o1.x - o2.x) + sqr(o1.y - o2.y))
end

function sqr(x) return x * x end

-- mine: tile distance
function tdst(o1, o2)
 return sqrt(sqr(o1.x/8 - o2.x/8) + sqr(o1.y/8 - o2.y/8))
end

-- mine: manhattan distance
function mdst(o1, o2)
  return abs(o1.x - o2.x) + abs(o1.y - o2.y)
end

-- https://github.com/eevee/klinklang/blob/23c5715bda87f3c787e1c5fe78f30443c7bf3f56/object.lua (modified)
local object = {}
object.__index = object


-- constructor
function object:__call(...)
  local this = setmetatable({}, self)
  return this, this:init(...)
end


-- methods
function object:init() end
function object:update() end
function object:draw() end


-- subclassing
function object:extend(proto)
  proto = proto or {}

  -- copy meta values, since lua doesn't walk the prototype chain to find them
  for k, v in pairs(self) do
    if sub(k, 1, 2) == "__" then
      proto[k] = v
    end
  end

  proto.__index = proto
  proto.__super = self

  return setmetatable(proto, self)
end


-- implementing mixins
function object:implement(...)
  for _, mixin in pairs{...} do
    for k, v in pairs(mixin) do
      if self[k] == nil and type(v) == "function" then
        self[k] = v
      end
    end
  end
end


-- typechecking
function object:isa(class)
  local meta = getmetatable(self)
  while meta do
    if meta == class then
      return true
    end
    meta = getmetatable(meta)
  end
  return false
end


-- pathfinding
-- https://www.lexaloffle.com/bbs/?tid=2570
function get_neighbors(x, y)
  dirs = {{1, 0}, {0, 1}, {-1, 0}, {0, -1}}
  res = {}
  for d in all(dirs) do
    if check_cell(x + d[1], y + d[2]) then
      add(res, {x + d[1], y + d[2]})
    end
  end

  return res
end

function contains(t,v)
  for k,val in pairs(t) do
    if (val[1] == v[1] and val[2] == v[2]) then return true end
  end

  return false
end

function check_cell(x, y)
  if x < 128 and x >= 0 and y < 32 and y >= 0 then
    local n = mget(x, y)
    local is_solid = fget(n, f.solid)
    if not is_solid then
      return true
    end
  end

  return false
end

function coord_key(x, y)
  if type(x) == "table" then
    return x[1] .. "_" .. x[2]
  end

  return x .. "_" .. y
end

function get_path(fx, fy, tx, ty)
  local path={}
  local start={fx, fy}
  local flood={start}
  local camefrom={}

  camefrom[coord_key(start)] = nil

  while #flood > 0 do
    local current = flood[1]

    if (current[1] == tx and current[2] == ty) then break end
    -- printh("examining " .. current[1] .. ", " .. current[2])

    neighbs = get_neighbors(current[1], current[2])
    -- printh("found " .. #neighbs .. " neighbors")

    if #neighbs > 0 then
      for neighb in all(neighbs) do
        if camefrom[coord_key(neighb)] == nil and not contains(camefrom, neighb) then
          add(flood,neighb)
          camefrom[coord_key(neighb)] = current

          -- awesome flood debugging
          if debugflood then
            rectfill(neighb[1]*8, neighb[2]*8, (neighb[1]*8)+7, (neighb[2]*8)+7)
            flip()
          end
        end
      end
    end

    del(flood,current)
  end

  local c = {tx, ty}
  while camefrom[coord_key(c)] ~= nil do
    add(path, c)
    c = camefrom[coord_key(c)]
  end

  return path
end


-- camera class
local _camera = object:extend()

function _camera:init()
  self.x = 0
  self.y = 0
  self.tx = 0
  self.ty = 0
end

function _camera:move(x, y)
  self.tx = x
  self.ty = y
end

function _camera:dmove(dx, dy)
  self.tx += dx
  self.ty += dy
end

function _camera:update()
  if (self.x <= self.tx - 1) or (self.x >= self.tx + 1) then
    self.x = (self.x + self.tx) / 2
  end
  if (self.y <= self.ty - 1) or (self.y >= self.ty + 1) then
    self.y = (self.y + self.ty) / 2
  end
end

function _camera:draw()
  camera(self.x, self.y)
end

-- sprite class
local _sprite = object:extend()

function _sprite:init(tile, x, y, palette)
  self.tile = tile
  self.x = x
  self.y = y
  self.palette = palette
  self.flipx = false
  self.flipy = false
  self.w = 1
  self.h = 1
end

function _sprite:update()
  local tile = self.tile
  if type(tile) == "table" then
    tile:update()
  end
end

function _sprite:draw()
  if self.palette then
    self:palette()
  end

  local tile = self.tile

  if type(tile) == "table" then
    tile = tile:frame()
  end

  spr(tile, self.x, self.y, self.w, self.h, self.flipx, self.flipy)

  pal()
  palt()
end

function _sprite:move(x, y)
  self.x = x
  self.y = y
end

function _sprite:dmove(dx, dy)
  self.x += dx
  self.y += dy
end

-- anim class
local _anim = object:extend()

function _anim:init(frames, speed, loop, reverse)
  self.step = 0
  self.cur = 1
  self.frames = frames
  self.loop = loop or true
  self.reverse = reverse or false
  self.speed = speed or 30
end

function _anim:next()
  if self.reverse then
    self.cur -= 1
    if self.cur == 0 then
      if self.loop then
        self.cur = #self.frames
      else
        self.cur = 1
      end
    end
  else
    self.cur += 1
    if self.cur == #self.frames + 1 then
      if self.loop then
        self.cur = 1
      else
        self.cur = #self.frames
      end
    end
  end

  return self.frames[self.cur]
end

function _anim:update()
  self.step += 1
  if self.step % flr(30 / self.speed) == 0 then
    self:next()
  end

  return self.frames[self.cur]
end

function _anim:frame()
  return self.frames[self.cur]
end

function _anim:copy()
  return _anim(self.frames, self.speed, self.loop, self.reverse)
end

-- palettes
function pal_trans_red()
  palt(c.red, true)
  palt(c.black, false)
end

function pal_sel_curs()
  palt(c.red, true)
  palt(c.black, false)
  pal(c.black, c.brown)
  pal(c.darkgrey, c.orange)
  pal(c.white, c.yellow)
end

function pal_race1()
  palt(c.red, true)
  palt(c.black, false)
end

function pal_race2()
  palt(c.red, true)
  palt(c.black, false)
  pal(c.brown, c.darkblue)
  pal(c.orange, c.darkgrey)
end

function pal_race3()
  palt(c.red, true)
  palt(c.black, false)
  pal(c.brown, c.white)
  pal(c.orange, c.lightgrey)
end

-- animations
local anim_stand = 5
local anim_walk = _anim({5, 6, 5, 7}, 10)
local anim_curs = _anim({1, 2, 3, 4}, 10)

-- unit class
local _unit = _sprite:extend()

function _unit:init(x, y, palette)
  self.__super.init(self, 5, x, y, palette)
  self.tx = x
  self.ty = y
  self.path = nil
end

function _unit:update()
  local path = self.path
  if path and #path > 0 then
    local to_coord = path[#path]
    if self.x == to_coord[1] * 8 and self.y == to_coord[2] * 8 then
      pop(self.path)
    else
      if self.x < to_coord[1] * 8 then
        self.x += 1
        self.flipx = false
      end
      if self.x > to_coord[1] * 8 then
        self.x -= 1
        self.flipx = true
      end
      if self.y < to_coord[2] * 8 then
        self.y += 1
      end
      if self.y > to_coord[2] * 8 then
        self.y -= 1
      end
    end
  end
end

function _unit:draw()
  self.__super.draw(self)
  local path = self.path
  if path and #path > 0 then
    line(self.x + 4, self.y + 4, path[#path][1] * 8 + 4, path[#path][2] * 8 + 4, c.yellow)
    for coord=1,#path-1 do
      line(path[coord][1] * 8 + 4, path[coord][2] * 8 + 4, path[coord+1][1] * 8 + 4, path[coord+1][2] * 8 + 4, c.yellow)
    end
  end
end

function _unit:set_dest(tx, ty)
  self.tx = tx
  self.ty = ty
  self.path = self:get_path()
end

function _unit:get_path()
  local cur_x = flr(self.x / 8)
  local cur_y = flr(self.y / 8)
  local dest_x = flr(self.tx / 8)
  local dest_y = flr(self.ty / 8)
  return get_path(cur_x, cur_y, dest_x, dest_y)
end

-- menu class
local _menu = object:extend()

function _menu:init()
  self:clear()
end

function _menu:clear()
  self.labels = {}
  self.callbacks = {}
  self.idx = 1
end

function _menu:add(label, callback)
  add(self.labels, label)
  add(self.callbacks, callback)
end

function _menu:up()
  self.idx = max(1, self.idx - 1)
end

function _menu:down()
  self.idx = min(#self.labels, self.idx + 1)
end

function _menu:call()
  self.callbacks[self.idx]()
end

function _menu:draw()
  local height = #self.labels
  local width = 1
  for label in all(self.labels) do
    width = max(width, ceil(#label/2))
  end

  local px_width = 8 * width + 16
  local px_height = 8 * height + 16
  local top = 4 + cam.y
  local left = 4 + cam.x
  local bottom = top + 8 * height
  local right = left + 8 + 8 * width

  spr(33, left, top, 1, 1, false, false)
  spr(33, right, top, 1, 1, true, false)
  spr(33, left, bottom, 1, 1, false, true)
  spr(33, right, bottom, 1, 1, true, true)

  rectfill(left + 8, top + 8, right - 1, bottom - 1, c.darkblue)

  -- horizontal walls
  for x=1, width do
    spr(34, left + 8 * x, top, 1, 1, false, false)
    spr(34, left + 8 * x, bottom, 1, 1, false, true)
  end

  -- vertical walls
  for y=1, height - 1 do
    spr(35, left, top + 8 * y, 1, 1, false, false)
    spr(35, right, top + 8 * y, 1, 1, true, false)
  end

  --text
  for y=1, height do
    local col = c.lightgrey
    if y == self.idx then
      col = c.white
      spr(49, left + 2, top - 4 + 8 * y)
    end

    print(self.labels[y], left + 10, top - 3 + 8 * y, col)
  end

end

-- elements
local ui = {}
local units = {}

local prev_state = nil
local state = s.command
local play_timer = 128

cam = _camera()
curs = _sprite(anim_curs:copy(), 64, 64, pal_trans_red)
sel_curs = _sprite(anim_curs:copy(), 64, 64, pal_sel_curs)
menu = _menu()
follow = nil

add(ui, curs)

local bear1 = _unit(16, 16, pal_race1)
local bear2 = _unit(16 + 36 * 8, 24, pal_race2)
local bear3 = _unit(16 + 36 * 16, 32, pal_race3)

add(units, bear1)
add(units, bear2)
add(units, bear3)

bear1:set_dest(8, 112)

btns = {[0]=false, [1]=false, [2]=false, [3]=false, [4]=false, [5]=false}
pbtns = btns

-- move the cursor to the closest unit (by manhattan distance, because pythag overflows)
function jump_to_closest_unit()
  local closest_unit = units[1]
  local closest_dist = mdst(units[1], curs)

  for unit in all(units) do
    local unit_dist = mdst(unit, curs)

    -- check if this unit is closer
    if unit_dist < closest_dist or use_next then
      closest_dist = unit_dist
      closest_unit = unit
    end

    -- if we're currently selecting a unit, then move to the next instead
    if closest_dist == 0 then
      jump_to_next_unit()
      return
    end
  end

  -- move cursor to unit
  follow = closest_unit
  sfx(0)
end

-- move the cursor to the next unit (undefined behavior if no unit is under the cursor)
function jump_to_next_unit()
  local i = 0
  for unit in all(units) do
    local unit_dist = mdst(unit, curs)
    i += 1

    if unit_dist == 0 then
      break
    end
  end

  -- decide the next unit
  local unit = units[i + 1]
  if i == #units then
    unit = units[1]
  end

  -- move cursor to unit
  follow = unit
  sfx(0)
end

-- move the cursor to the previous unit (undefined behavior if no unit is under the cursor)
function jump_to_prev_unit()
  -- find the unit we're selecting
  local i = 0
  for unit in all(units) do
    local unit_dist = mdst(unit, curs)
    i += 1

    if unit_dist == 0 then
      break
    end
  end

  -- decide the previous unit
  local unit = units[i - 1]
  if i == 1 then
    unit = units[#units]
  end

  -- move cursor to unit
  follow = unit
  sfx(0)
end

-- change the state, recording the previous one as well
function change_state(to)
  if type(to) == "string" then
    printh("changing state to " .. to)
    to = s[to]
  else
    for k, v in pairs(s) do
      if v == to then
        printh("changing state to " .. k)
        break
      end
    end
  end

  prev_state = state
  state = to
end

function _init()
end

function _update()
  pbtns = btns
  btns = {[0]=btn(0), [1]=btn(1), [2]=btn(2), [3]=btn(3), [4]=btn(4), [5]=btn(5)}

  if state == s.command or state == s.play then
    if btnp(b.left) then
      if btns[b.o] then
        jump_to_prev_unit()
      else
        curs:dmove(-8, 0)
      end
    end

    if btnp(b.right) then
      if btns[b.o] then
        jump_to_next_unit()
      else
        curs:dmove(8, 0)
      end
    end

    if btnp(b.up) then
      curs:dmove(0, -8)
    end

    if btnp(b.down) then
      curs:dmove(0, 8)
    end

    follow = nil
    for unit in all(units) do
      if flr(unit.x) == flr(curs.x) and flr(unit.y) == flr(curs.y) then
        follow = unit
        break
      end
    end

    if follow == nil then
      curs.x = flr(curs.x / 8) * 8
      curs.y = flr(curs.y / 8) * 8
    end

    if not pbtns[b.o] and btns[b.o] then
      jump_to_closest_unit()
    end

    if btnp(b.x) then
      menu:clear()

      if follow ~= nil then
        menu:add("move", function()
          change_state("move")
        end)
      end

      if #menu.labels > 0 then
        change_state("menu")
      end
    end

  elseif state == s.menu then
    if btnp(b.down) then
      menu:down()
    end

    if btnp(b.up) then
      menu:up()
    end

    if btnp(b.x) then
      menu:call()
    end

    if btnp(b.o) then
      change_state(prev_state)
    end

    menu:update()

  elseif state == s.move then
    if btnp(b.left) then
      curs:dmove(-8, 0)
    end

    if btnp(b.right) then
      curs:dmove(8, 0)
    end

    if btnp(b.up) then
      curs:dmove(0, -8)
    end

    if btnp(b.down) then
      curs:dmove(0, 8)
    end

    if btnp(b.x) then
      follow:set_dest(curs.x, curs.y)
      follow = nil
    end

    if btnp(b.x) then
      change_state("command")
    end
  end

  cam:move(curs.x - 60, curs.y - 60)
  cam:update()

  for sprite in all(units) do
    sprite:update()
  end

  curs:update()
  sel_curs:update()

  if follow ~= nil then
    sel_curs.x = follow.x
    sel_curs.y = follow.y
    if state ~= s.move then
      curs.x = follow.x
      curs.y = follow.y
    end
  end
end

function _draw()
  cls()

  cam:draw()
  map(0, 0)

  for sprite in all(units) do
    sprite:draw()
  end

  curs:draw()

  if follow ~= nil then
    sel_curs:draw()
  end

  if state == s.menu then
    menu:draw()
  end

  --[[
  if state == s.splash then
    print('splash', cam.x, cam.y, c.white)
  end
  if state == s.command then
    print('command', cam.x, cam.y, c.white)
  end
  if state == s.play then
    print('play', cam.x, cam.y, c.white)
  end
  if state == s.menu then
    print('menu', cam.x, cam.y, c.white)
  end
  ]]

  local curs_x = flr(curs.x / 8)
  local curs_y = flr(curs.y / 8)
  local cell_n = mget(curs_x, curs_y)
  if fget(cell_n, f.food) then
    print('food', cam.x, cam.y + 8, c.white)
  end
  if fget(cell_n, f.money) then
    print('money', cam.x, cam.y + 8, c.white)
  end
  if fget(cell_n, f.material) then
    print('material', cam.x, cam.y + 8, c.white)
  end
end

__gfx__
00000000875087500875087550875087750875088888888888888888888888883333333300000000000000000000000089444498867777688511115800000000
00000000088888885888888078888885888888878894498888944988889449883333333300000000000000000000000084444448877777788111111800000000
00700700588888877888888888888880088888858840408888404088884040883333333300000000000000000000000084044048870770788101101800000000
00077000788888858888888708888888588888808444044884440448844404483333333300000000000000000000000044440444777707771111011100000000
00077000888888800888888558888887788888888844448888444488884444883333333300000000000000000000000044444444777777771111111100000000
00700700088888885888888078888885888888878849948888499488884994883333333300000000000000000000000084499448877667788115511800000000
00000000588888877888888888888880088888858848848888488888888884883333333300000000000000000000000084499448877667788115511800000000
00000000780578058057805705780578578057808888888888888888888888883333333300000000000000000000000084488448877887788118811800000000
00000000111111111111111111111111111111110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000eeeeeeeeeeeeeee01111111111111110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000088888888888888801111111111111110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000088888888888888801111111111111110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000022222222222222201111111111111110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000111111111111111111111111111111110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000666000000000000006111111111111110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000616666666666666606111111111111110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000666111111111111106111111111111110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000061111111111111106111111111111110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000061111111111111106111111111111110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000061111111111111106111111111111110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000061111111111111106111111111111110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000061111111111111106111111111111110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033333333333333333333333333333333
00000000006600000000000000000000000000000000000000000000000000000000000000000000000000000000000033bb333333bbbb3333344333333bb333
00000000006660000000000000000000000000000000000000000000000000000000000000000000000000000000000033b333b33b2b2bb33344443333bbbb33
00000000006666000000000000000000000000000000000000000000000000000000000000000000000000000000000033333bb33bbbb2b33399993333bbbb33
0000000000666000000000000000000000000000000000000000000000000000000000000000000000000000000000003b3333333b2bbbb3334444333bbbbbb3
0000000000660000000000000000000000000000000000000000000000000000000000000000000000000000000000003bb33b3333bb2b333399993333344333
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033333bb3333bb3333344443333344333
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033333333333333333333333333333333
33333333333333333333333333333333333333333333333333333333333333330000000000000000000000000000000000000000000000000000000000000000
3333333333bb333333bbbb3333344333333bb3333333333333333333333333330000000000000000000000000000000000000000000000000000000000000000
3333333333b333b33b2b2bb33344443333bbbb333333333333333333333333330000000000000000000000000000000000000000000000000000000000000000
3333333333333bb33bbbb2b33399993333bbbb333333333333333333333333330000000000000000000000000000000000000000000000000000000000000000
333333333b3333333b2bbbb3334444333bbbbbb33333333333333333333333330000000000000000000000000000000000000000000000000000000000000000
333333333bb33b3333bb2b3333999933333443333333333333333333333333330000000000000000000000000000000000000000000000000000000000000000
3333333333333bb3333bb33333444433333443333333333333333333333333330000000000000000000000000000000000000000000000000000000000000000
33333333333333333333333333333333333333333333333333333333333333330000000000000000000000000000000000000000000000000000000000000000
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd0000000000000000000000000000000000000000000000000000000000000000
dddddddddddd5ddddddccddddddccddddddddddddddddddddddddddddddddddd0000000000000000000000000000000000000000000000000000000000000000
dddddddddd5dddddddccccddddc7ccddddd5dddddddddddddddddddddddddddd0000000000000000000000000000000000000000000000000000000000000000
ddddddddddddd5ddddcc1ccdddcc7cdddd555ddddddddddddddddddddddddddd0000000000000000000000000000000000000000000000000000000000000000
ddddddddd5dddddddcc111cddd7cc7dddd5555dddddddddddddddddddddddddd0000000000000000000000000000000000000000000000000000000000000000
dddddddddddd5ddddcc11cddddc7ccddd555555ddddddddddddddddddddddddd0000000000000000000000000000000000000000000000000000000000000000
dddddddddd5ddd5dddccccdddddc7dddd555555ddddddddddddddddddddddddd0000000000000000000000000000000000000000000000000000000000000000
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd0000000000000000000000000000000000000000000000000000000000000000
44444444444444444444444444444444444444444444444444444444444444440000000000000000000000000000000000000000000000000000000000000000
444444444494494444bbe44444444444443333444444444444444444444444440000000000000000000000000000000000000000000000000000000000000000
444444444949449444ebb4e444455444433333344444444444444444444444440000000000000000000000000000000000000000000000000000000000000000
4444444444444944444b44be447ee744433333344444444444444444444444440000000000000000000000000000000000000000000000000000000000000000
44444444444944444bbb4bb4447ee744443333444444444444444444444444440000000000000000000000000000000000000000000000000000000000000000
44444444449449444e4bbb44447ee744444554444444444444444444444444440000000000000000000000000000000000000000000000000000000000000000
44444444444944944444b44444777744444554444444444444444444444444440000000000000000000000000000000000000000000000000000000000000000
44444444444444444444444444444444444444444444444444444444444444440000000000000000000000000000000000000000000000000000000000000000
__gff__
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003050900000305090000000000000000000000000003050900000000000000000000000000030509000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
4040404040404040404040404040404040404040404040404040404040404040404040404060606060606060606060606060606060606060606060606060606060606060606060606050505050505050505050505050505050505050505050505050505050505050505050505000000000000000000000000000000000000000
4040404040404040404040404040404040404040404040404040404040404040404040404060606060606060606060606060606060606060606060606060606060606060606060606050505050505050505050505050505050505050505050505050505050505050505050505000000000000000000000000000000000000000
4040404040404040404041404040414040404040434040404040404040424040404040404060606060606060606060606061606060606060606060606060606060606060606064606050505050505050505050505050505050505050505050505050505050505050505050505000000000000000000000000000000000000000
4040404040404040404040404040404040404040404040404440404040404040404040404060606060606260606060606060606060606060606360606060606060606060606060606050505050505050505050505050505450505050505050505050505054505050505050505000000000000000000000000000000000000000
4040404140404040414040404040404040404040404040404040404040404040404040404060606060606060606060606060606060606060606060606060616060606060606060606050505050515050505050505050505050505250505050505050505050505050505050505000000000000000000000000000000000000000
4040404040404040404040404040404040404040404140404040404040404041404040404060606060606060606060606060606060606060606060606060606060636060606060606050505050505050505050505050505050505050505050505050505050505050505050505000000000000000000000000000000000000000
4040404040404040404040404040404040404040404040404040404040404040404040404060606060606060606064606060606060606060606060606060646060606060606060606050505050505050505053505051505050505050505150505050505050505050505050505000000000000000000000000000000000000000
4040404040414040404440404041404040404040404040404040404040404040404040404060606060606061606060606060636060606061606060606060606060606060606060606050505050505050505050505050505050505050505050505050505050505050515050505000000000000000000000000000000000000000
4040404040404040404040404040404040404040404040404040414040404040404040404060606060606060606060606060606060606060606060606060606060606060606064606050505050505250505050505050505050505050505050505050505050505050505050505000000000000000000000000000000000000000
4040404040404040404040404040404042404040404040444040404040404040404040404060606060606060606060606060606060606060606060606260606061606060606060606050505050505050505050505052505050505050505050505350505050505050505050505000000000000000000000000000000000000000
4040404340404040404040404040404040404040404040404040404040404040404040404060606060606060606060606160606060606060606060606060606060606060606060606050505050505050505050505050505050505050505050505050505450505050505050505000000000000000000000000000000000000000
4040404040404040404042404040404040404040414040404040404040404040424040404060606060626060606060606060606060606060636060606060606060606060606060606050505050505054505050505050505050545050505050505050505050505050505050505000000000000000000000000000000000000000
4040404040404040404040404040444040404040404043404040404140404040404040404060606060606060606060606060606062606060606060606060606060606064606060606050505050505050505050505050505050535050505051505050505050505050505050505000000000000000000000000000000000000000
4040404040404040404040404040404040404040404040404040404040404040404040404060606060606060606060646060606060606060606060616060606060606060606060606050505050505050505050505150505050505050505050505050505050505050525050505000000000000000000000000000000000000000
4040404040414040404040404040404040404040404040404040404040404040404040404060606060606060636060606060606060606060606060606060606062606060606060606050505050525050505050505050505050505050505050505050505350505050505050505000000000000000000000000000000000000000
4040404040404040404041404040404041404040404040404040404040404040404040404060606060606060606060606060616060646060606060606060606060606060606060606050505050505050545050505050505050505250505050505050505050505050505050505000000000000000000000000000000000000000
4040404040404040404040404040404040404040404044404040404040404040434040404060606060606060606060616060606060606060606060606360606060606060606060606050505050505050505050505050505050505050505050505050505050505054505050505000000000000000000000000000000000000000
4040404040404040404040404040404040404040404040404040404040404040404040404060606060606060606060606060606060606060606060606060606060606060616060606050505050505050505050505050535050505050505050505050505050505050505050505000000000000000000000000000000000000000
4040404340404040404040404040404040404040404040404040424040404041404040404060606060616060606060606060606060606061606060606060606060606060606060606050505050505050515050505050505050505050545050505051505050505050505050505000000000000000000000000000000000000000
4040404040404040404044404040414040404043404040404040404040404040404040404060606060606060606060606460606060606060606060606060606260606060606060606050505050505050505050505050505050505050505050505050505050525050505050505000000000000000000000000000000000000000
4040404040404040404040404040404040404040404040404040404040404040404040404060606060606060606060606060606063606060606060606060606060606060606060606050505050505050505050505050505050505050505050505050505050505050505050505000000000000000000000000000000000000000
4040404040404140404040404040404040404040404040404040404040404040404040404060606060606060626060606060606060606060606060616060606060606360646060606050505050505050505050505050515050505050505050505350505050505050515050505000000000000000000000000000000000000000
4040404040404040404042404040404040404040404140404040404044404040404040404060606060606060606060606060606060606060606060606060606060606060606060606050505050505052505050505050505050505050505050505050505050505050505050505000000000000000000000000000000000000000
4040404040404040404040404040404044404040404040404040404040404040404040404060606060606060606060616060606060646060606060606060606060606060606060606050505050505050505050505050505050505050505050505050505050505050505050505000000000000000000000000000000000000000
4040404040404040404040404040404040404040404040404040404040404040404040404060606060606060606060606060606060606060606060606060606060606060606060606050505050505050505050505050505050505050505050505050505050505050505050505000000000000000000000000000000000000000
__sfx__
00010000260500500030050300503005030040300403003030030300202d0003a6003a6002f0003960038600386003860038600386002e0002d0002a00028000210001d000190001600013000000000000000000

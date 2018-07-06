pico-8 cartridge // http://www.pico-8.com
version 16
__lua__
-- bare wars
-- by john weachock

-- buttons
b = {left=0, right=1, up=2, down=3, o=4, x=5}

-- colors
c = {
  black=0, darkblue=1, darkpurple=2, darkgreen=3,
  brown=4, darkgrey=5, lightgrey=6, white=7,
  red=8, orange=9, yellow=10, green=11,
  blue=12, indigo=13, pink=14, peach=15,
}

-- player colors
player_colors = {
  c.red,    -- 1
  c.blue,   -- 2
  c.orange, -- 3
  c.pink,   -- 4
  c.yellow, -- 5
  c.green,  -- 6
}

-- flags
f = {
  solid=0,
  food=1,
  material=3,
  castle=4,
  empty=5,
}

-- states
s = {
  splash=0,
  command=1,
  play=2,
  menu=3,
  move=4,
  win=5,
}

-- tiles
t = {
  curs1=1,
  curs2=2,
  curs3=3,
  curs4=4,

  worker_walk1=5,
  worker_walk2=6,
  worker_walk3=7,

  warrior_walk1=24,
  warrior_walk2=25,
  warrior_walk3=26,

  wall=8,
  tower=9,
  cave=10,
  blank=11,
  farm=40,

  meter_end=17,
  meter_mid=18,

  menu_corner=33,
  menu_hor=34,
  menu_vert=35,
  menu_arr=36,

  ui_left_gem=19,
  ui_left_nogem=20,
  ui_mid_gem=21,
  ui_mid_nogem=22,
  ui_corner=23,
  ui_food=49,
  ui_material=51,
  ui_heart=52,
  ui_unit=53,
  ui_sword=54,
  ui_pick=55,
  ui_house=56,

  ter_plain = 64,
  ter_good = 65,
  ter_food = 66,
  ter_money = 67,
  ter_material = 68,
  ter_wall = 69,
  ter_castle1 = 72,
  ter_castle2 = 73,
  ter_castle3 = 74,
  ter_castle4 = 75,
}

-- sfx
a = {
  ping=0,
  ok=1,
  no=2,
  bullet=3,
}

-- unit types
u = {
  worker=0,
  warrior=1,
}

-- unit costs
uc = {
  [u.worker]=10,
  [u.warrior]=14,
}

-- unit stats
stats = {
  [u.worker] = {health=3, fight=1, gather=2},
  [u.warrior] = {health=5, fight=2, gather=1},
}

-- house types
h = {
  castle=0,
  wall=1,
  cave=2,
  tower=3,
  farm=4,
}

-- house costs
hc = {
  [h.wall]=8,
  [h.farm]=10,
  [h.cave]=14,
  [h.tower]=14,
}

-- house stats
hs = {
  [h.castle] = {tile=t.blank, health=12, cap=16},
  [h.wall] = {tile=t.wall, health=4, speed=0},
  [h.tower] = {tile=t.tower, health=6, cap=64},
  [h.cave] = {tile=t.cave, health=6, cap=256},
  [h.farm] = {tile=t.farm, health=6, cap=64},
}

worker_range = 8

function mset2(x, y, n)
  if y > 31 then
    x += 64
    y -= 32
  end
  return mset(x, y, n)
end

function mget2(x, y)
  if y > 31 then
    x += 64
    y -= 32
  end
  return mget(x, y)
end


-- https://www.lexaloffle.com/bbs/?tid=3389
function pop(stack)
  local v = stack[#stack]
  stack[#stack]=nil
  return v
end

-- https://github.com/clowerweb/lib-pico8/blob/9580f8afd84dfa3f33e0c9c9131a595ede1f0a2a/distance.lua
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
object = {}
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
    if can_path(x + d[1], y + d[2]) then
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

function can_path(x, y)
  if x < 64 and x >= 0 and y < 64 and y >= 0 then
    local n = mget2(x, y)
    local is_solid = fget(n, f.solid)
    if not is_solid then
      return true
    end
  end

  return false
end

function can_build(x, y)
  if x < 64 and x >= 0 and y < 64 and y >= 0 then
    local n = mget2(x, y)
    local is_empty = fget(n, f.empty)
    if is_empty then
      return true
    end
  end

  return false
end

function can_build_adj(x, y)
  dirs = {{1, 0}, {0, 1}, {-1, 0}, {0, -1}}
  for dir in all(dirs) do
    if can_build(x + dir[1], y + dir[2]) then
      printh("can build @ " .. dir[1] .. ", " .. dir[2])
      return x + dir[1], y + dir[2]
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

    neighbs = get_neighbors(current[1], current[2])
    if mdst({x=current[1], y=current[2]}, {x=tx, y=ty}) == 1 then
      add(neighbs, {tx, ty})
    end

    if #neighbs > 0 then
      for neighb in all(neighbs) do
        if camefrom[coord_key(neighb)] == nil and not contains(camefrom, neighb) then
          add(flood,neighb)
          camefrom[coord_key(neighb)] = current

          -- awesome flood debugging
          if false then
            rectfill(neighb[1]*8, neighb[2]*8, (neighb[1]*8)+7, (neighb[2]*8)+7, c.blue)
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
_camera = object:extend()

function _camera:init()
  self.x = 0
  self.y = 0
  self.tx = 0
  self.ty = 0
end

function _camera:move(x, y)
  self.tx = x
  self.ty = y
  if self.tx < 0 then
    self.tx = 0
  end
  if self.tx > 385 then
    self.tx = 385
  end
  if self.ty < 0 then
    self.ty = 0
  end
  if self.ty > 385 then
    self.ty = 385
  end
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
_sprite = object:extend()

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
_anim = object:extend()

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

-- animations
an_stand = {
  [u.worker] = t.worker_walk1,
  [u.warrior] = t.warrior_walk1,
}
an_walk = {
  [u.worker] = _anim({t.worker_walk1, t.worker_walk2, t.worker_walk1, t.worker_walk3}, 10),
  [u.warrior] = _anim({t.warrior_walk1, t.warrior_walk2, t.warrior_walk1, t.warrior_walk3}, 10),
}

an_curs = _anim({t.curs1, t.curs2, t.curs3, t.curs4}, 10)

-- palettes
function pal_trans_red()
  palt(c.red, true)
  palt(c.black, false)
end

function pal_sel_curs()
  palt(c.red, true)
  palt(c.black, false)
  if follow then
    pal(c.black, player_colors[follow.owner])
  else
    pal(c.black, c.white)
  end
end

function pal_bad_curs()
  palt(c.red, true)
  palt(c.black, false)
  pal(c.black, c.darkpurple)
end

function pal_race1()
  palt(c.red, true)
  palt(c.black, false)
end

function pal_race2()
  palt(c.red, true)
  palt(c.black, false)
  pal(c.brown, c.darkblue)
  pal(c.orange, c.brown)
end

function pal_race3()
  palt(c.red, true)
  palt(c.black, false)
  pal(c.brown, c.white)
  pal(c.orange, c.blue)
end

function pal_race4()
  palt(c.red, true)
  palt(c.black, false)
  pal(c.black, c.lightgrey)
  pal(c.brown, c.white)
  pal(c.orange, c.darkgrey)
end

races = {pal_race1, pal_race2, pal_race3, pal_race4}

-- unit class
_unit = _sprite:extend()

function _unit:init(owner, x, y, palette, type)
  self.__super.init(self, 0, x, y, palette)
  self.is_unit = true
  self.owner = owner
  self.type = type or u.worker
  self.tile = an_stand[self.type]

  local stats = stats[self.type]
  self.health = stats.health
  self.max_health = stats.health
  self.fight = stats.fight
  self.gather = stats.gather

  self.tx = x
  self.ty = y
  self.ctx = flr(x / 8)
  self.cty = flr(y / 8)
  self.path = nil
  self.step = 0
  self.action = 0
end

function _unit:consume(amt)
  amt = amt or 1
  local owner = players[self.owner]

  self.step += amt
  while self.step >= 32 do
    self.step -= 32
    if owner.food > 0 then
      owner.food -= 1
    else
      self.health -= 1
    end
  end
end

function _unit:act(amt)
  amt = amt or 1
  local owner = players[self.owner]

  local count = 0
  self.action += amt
  while self.action >= 32 do
    self.action -= 32
    count += 1
  end

  return count
end

function _unit:update()
  self.__super.update(self)
  self:consume()

  -- movement
  local path = self.path
  if path and #path > 0 then
    local waypoint = path[#path]

    -- move to waypoint
    if self.x < waypoint[1] * 8 then
      self.x += 1
      self.flipx = false
    end

    if self.x > waypoint[1] * 8 then
      self.x -= 1
      self.flipx = true
    end

    if self.y < waypoint[2] * 8 then
      self.y += 1
    end

    if self.y > waypoint[2] * 8 then
      self.y -= 1
    end

    -- pop current waypoint if we're at it
    if self.x == waypoint[1] * 8 and self.y == waypoint[2] * 8 then
      pop(path)
      if #path == 0 then
        self.tile = an_stand[self.type]
        self.path = nil
      end
    end

  -- perform actions
  elseif self.x == self.tx and self.y == self.ty then
    -- this is wacky but it works
    if self:use_resources(-1, 0) then
    elseif self:use_resources(0, -1) then
    elseif self:use_resources(1, 0) then
    elseif self:use_resources(0, 1) then
    elseif self:fight_enemy() then
    end
  end
end

function _unit:draw()
  local path = self.path
  if path and #path > 0 then
    local col = player_colors[self.owner]
    line(self.x + 4, self.y + 4, path[#path][1] * 8 + 4, path[#path][2] * 8 + 4, col)
    for coord=1,#path-1 do
      line(path[coord][1] * 8 + 4, path[coord][2] * 8 + 4, path[coord+1][1] * 8 + 4, path[coord+1][2] * 8 + 4, col)
    end

    local last_x = path[1][1] * 8 + 3
    local last_y = path[1][2] * 8 + 3
    rectfill(last_x, last_y, last_x + 2, last_y + 2, col)
  end

  if self ~= follow then
    local col = c.pink
    for i=1,self.max_health do
      pset(self.x + i - 1, self.y, col)
      if i == self.health then
        col = c.darkblue
      end
    end
    pset(self.x, self.y + 7, player_colors[self.owner])
  end

  self.__super.draw(self)
end

function _unit:set_dest(tx, ty)
  self.tx = tx
  self.ty = ty
  self.ctx = flr(tx / 8)
  self.cty = flr(ty / 8)
  self.path = self:get_path()
  if #self.path > 0 then
    self.tile = an_walk[self.type]:copy()
  else
    self.path = nil
  end
end

function _unit:get_path()
  local cur_x = flr(self.x / 8)
  local cur_y = flr(self.y / 8)
  return get_path(cur_x, cur_y, self.ctx, self.cty)
end

function _unit:use_resources(rel_x, rel_y)
  local res = get_resources(self.ctx + rel_x, self.cty + rel_y)
  if res and res > 0 then
    local count = self:act(self.gather * 2)
    use_resource(self.ctx + rel_x, self.cty + rel_y, self.owner, count)
    return true
  end

  return false
end

function _unit:fight_enemy()
  for unit in all(units) do
    if unit.owner ~= self.owner and mdst(unit, self) <= 8 then
      local count = self:act(self.fight)
      unit.health -= count
      return
    end
  end

  for house in all(houses) do
    local range = 8
    if house.type == h.castle then
      range = 16
    end
    if house.owner ~= self.owner and mdst(house, self) <= range then
      local count = self:act(self.fight)
      house.health -= count
      return
    end
  end
end


-- house class
-- houses are any building, but i'm not about to type 'building' a hundred times
_house = _sprite:extend()

function _house:init(owner, x, y, type)
  self.__super.init(self, 0, x, y, pal_trans_red)
  self.is_house = true
  self.type = type
  self.owner = owner

  local stats = hs[self.type]
  self.tile = stats.tile
  self.health = stats.health
  self.max_health = stats.health
  self.action = 0
  self.cap = stats.cap or 32
  self.speed = stats.speed or 1
  self.mx = flr(x / 8)
  self.my = flr(y / 8)

  local cell_n = mget2(self.mx, self.my)
  if cell_n <= 75 then
    mset2(self.mx, self.my, t.ter_wall)
  elseif cell_n <= 91 then
    mset2(self.mx, self.my, t.ter_wall + 16)
  elseif cell_n <= 107 then
    mset2(self.mx, self.my, t.ter_wall + 32)
  elseif cell_n <= 123 then
    mset2(self.mx, self.my, t.ter_wall + 48)
  end

  for unit in all(units) do
    if mdst(unit, self) <= worker_range * 10 then
      unit:set_dest(unit.tx, unit.ty)
    end
  end
end

function _house:update()
  if self.action < self.cap then
    self.action += self.speed
  end

  if self.action >= self.cap then
    self:act()
  end
end

function _house:draw()
  if self ~= follow and self.type ~= h.castle then
    local col = c.pink
    for i=1,self.max_health do
      pset(self.x + i - 1, self.y, col)
      if i == self.health then
        col = c.darkblue
      end
    end
    pset(self.x, self.y + 6, player_colors[self.owner])
  end

  local fill = min(flr(self.action / self.cap * 8), 7)
  if fill > 0 then
    line(self.x, self.y + 7, self.x + fill, self.y + 7, c.orange)
  end

  self.__super.draw(self)
end

function _house:act()
  if self.type == h.tower or self.type == h.castle then
    for unit in all(units) do
      if unit.owner ~= self.owner and mdst(unit, self) <= 24 then
        sfx(a.bullet)
        unit.health -= 1
        self.action -= self.cap
        return
      end
    end
  elseif self.type == h.cave then
  elseif self.type == h.farm then
    players[self.owner].food += 1
    self.action -= self.cap
  end
end


-- menu class
_menu = object:extend()

function _menu:init()
  self:clear()
end

function _menu:clear()
  self.back = nil
  self.labels = {}
  self.callbacks = {}
  self.enables = {}
  self.idx = 1
end

function _menu:add(label, callback, enabled)
  if enabled == nil then
    enabled = true
  end

  add(self.labels, label)
  add(self.callbacks, callback)
  add(self.enables, enabled)
end

function _menu:up()
  -- self.idx = max(1, self.idx - 1)
  for i=self.idx - 1, 1, -1 do
    if self.enables[i] then
      self.idx = i
      break
    end
  end
end

function _menu:down()
  for i=self.idx + 1, #self.labels do
    if self.enables[i] then
      self.idx = i
      break
    end
  end
  -- self.idx = min(#self.labels, self.idx + 1)
end

function _menu:call()
  if self.enables[self.idx] then
    self.callbacks[self.idx]()
  end
end

function _menu:draw()
  local height = #self.labels
  local width = 1
  for label in all(self.labels) do
    width = max(width, ceil(#label/2))
  end

  local px_width = 8 * width + 16
  local px_height = 8 * height + 16
  local top = 16 + cam.y
  local left = 4 + cam.x
  local bottom = top + 8 * height
  local right = left + 8 + 8 * width

  -- move out of way of cursor
  if curs.x < right then
    left += 116 - right
    right += 116 - right
  end

  if curs.y < bottom then
    top += 116 - bottom
    bottom += 116 - bottom
  end

  -- corners + fill
  spr(t.menu_corner, left, top, 1, 1, false, false)
  spr(t.menu_corner, right, top, 1, 1, true, false)
  spr(t.menu_corner, left, bottom, 1, 1, false, true)
  spr(t.menu_corner, right, bottom, 1, 1, true, true)
  rectfill(left + 8, top + 8, right - 1, bottom - 1, c.darkblue)

  -- horizontal walls
  for x=1, width do
    spr(t.menu_hor, left + 8 * x, top, 1, 1, false, false)
    spr(t.menu_hor, left + 8 * x, bottom, 1, 1, false, true)
  end

  -- vertical walls
  for y=1, height - 1 do
    spr(t.menu_vert, left, top + 8 * y, 1, 1, false, false)
    spr(t.menu_vert, right, top + 8 * y, 1, 1, true, false)
  end

  --text
  for y=1, height do
    local col = c.lightgrey
    if y == self.idx then
      col = c.white
      spr(t.menu_arr, left + 2, top - 4 + 8 * y)
    end
    if not self.enables[y] then
      col = c.darkgrey
    end

    print(self.labels[y], left + 10, top - 3 + 8 * y, col)
  end
end

-- meter class
_meter = object:extend()

function _meter:init(cap, transparent, base, hi, lo, bg)
  self.x = 0
  self.y = 0
  self.width = 128
  self.cap = cap or 128
  self.amt = self.cap
  self.transparent = transparent or c.red
  self.base = base or c.red
  self.hi = hi or c.pink
  self.lo = lo or c.indigo
  self.bg = bg or c.darkblue
end

function _meter:fill(amt)
  self.amt = min(self.cap, max(0, amt))
end

function _meter:draw()
  palt(c.black, false)
  palt(c.red, true)

  local left = self.x + cam.x
  local top = self.y + cam.y
  local fill = self.amt / self.cap * (self.width - 4)

  rectfill(left + 2, top + 2, left + 2 + self.width - 4, top + 6, self.bg)
  line(left + 2, top + 2, left + 2 + fill, top + 2, self.hi)
  line(left + 2, top + 3, left + 2 + fill, top + 3, self.base)
  line(left + 2, top + 4, left + 2 + fill, top + 4, self.base)
  line(left + 2, top + 5, left + 2 + fill, top + 5, self.lo)

  spr(t.meter_end, left, top, 1, 1, false, false)

  for n=1, ceil((self.width - 16)/8) do
    spr(t.meter_mid, left + 8 * n, top)
  end

  spr(t.meter_end, left + self.width - 8, top, 1, 1, true, false)

  palt()
end

-- infobar class
_info = object:extend()

function _info:init()
  self.x = 0
  self.y = 0
end

function _info:draw()
  palt(c.black, false)
  palt(c.red, true)

  local player_num = cur_player
  if follow ~= nil then
    player_num = follow.owner
  end

  local player = players[player_num]

  local ui_slot = 1
  for i=1, #order do
    if order[i] == player_num then
      ui_slot = i
      break
    end
  end

  if player == nil then
    ui_slot = #order
  end

  for i=1, #units do
    local top = 6 + cam.y + 3 * i
    local left = 2 + cam.x
    local unit = units[i]

    if follow == unit then
      rectfill(left - 1, top - 1, left + 1, top + 1, c.darkgrey)
    end

    pset(left, top, player_colors[units[i].owner])

    if unit.x ~= unit.tx or unit.y ~= unit.ty then
      pset(left + 1, top, c.yellow)
    end

  end

  for i=1, #houses do
    local top = 6 + cam.y + 3 * i
    local left = 5 + cam.x
    local house = houses[i]
    if follow == house then
      rectfill(left - 1, top - 1, left + 1, top + 1, c.darkgrey)
    end

    pset(left, top, player_colors[houses[i].owner])

    if (house.action >= house.cap) and (house.type == h.cave) then
      pset(left + 1, top, c.yellow)
    end
  end

  local left = self.x + cam.x
  local top = self.y + cam.y
  local ui_start = ui_slot
  local ui_end = 16 - #order + ui_slot
  local ui_left = left + ui_start * 8
  local ui_right = left + ui_end * 8 - 16

  for p=1, #order do
    local border_col = c.darkgrey
    if order[p] == cur_player then
      border_col = c.lightgrey
    end

    pal(c.lightgrey, border_col)
    pal(c.pink, player_colors[order[p]])

    if p < ui_slot then
      spr(t.ui_left_gem, left + 8 * (p - 1), top)
    elseif p == ui_slot then
      spr(t.ui_mid_gem, left + 8 * (p - 1), top)
    else
      local i = t.ui_left_gem
      if p == #order then
        i = t.ui_mid_gem
      end
      spr(i, left + 120 - (#order) * 8 + 8 * p, top)
    end
  end

  spr(t.ui_corner, ui_left, top + 7)
  for i=ui_start + 1, ui_end - 2 do
    spr(t.ui_mid_nogem, left + i * 8, top + 7)
  end
  spr(t.ui_mid_nogem, left + ui_end * 8 - 12, top + 7)

  rectfill(ui_left, top, left + ui_end * 8 - 1, top + 6, c.black)

  spr(t.ui_corner, left + ui_end * 8 - 4, top + 7, 1, 1, true)
  spr(t.ui_corner, left + ui_end * 8 - 4, top + 7, 1, 1, true)

  -- reset palette swaps from the gems
  pal()
  palt(c.red, true)

  -- draw resources
  if player ~= nil then
    spr(t.ui_food, ui_left + 3, top - 1)
    print(player.food, ui_left + 10, top, c.white)

    spr(t.ui_material, ui_left + 19, top - 1)
    print(player.materials, ui_left + 26, top, c.white)

    spr(t.ui_house, ui_left + 53, top - 1)
    print(player.houses, ui_left + 62, top, c.white)

    races[player.race]()
    spr(t.ui_unit, ui_left + 36, top - 1)
    print(player.units, ui_left + 44, top, c.white)
  end

  -- reset palette swaps
  pal()
  palt(c.red, true)
  palt(c.black, false)

  -- draw focused map info
  local curs_x = flr(curs.x / 8)
  local curs_y = flr(curs.y / 8)
  local cell_n = mget2(curs_x, curs_y)
  local res = get_resources(curs_x, curs_y)

  -- draw map resource info
  if fget(cell_n, f.food) then
    spr(t.ui_food, ui_right + 4, top + 6)
  elseif fget(cell_n, f.material) then
    spr(t.ui_material, ui_right + 4, top + 6)
  end

  if res then
    local offx = 0
    if res >= 100 then
      offx = -8
    elseif res >= 10 then
      offx = -4
    end
    print(res, ui_right + offx, top + 7, c.white)
  end

  -- draw focused unit stats
  if follow ~= nil then
    if follow.is_unit then
      for i=1, follow.fight do
        spr(t.ui_sword, ui_left + (i + follow.max_health) * 6 + 2, top + 6)
      end

      for i=1, follow.gather do
        spr(t.ui_pick, ui_left + (i + follow.max_health + follow.fight) * 6 + 6, top + 6)
      end
    end

    -- hearts need a wacky palette swap
    palt(c.red, false)
    palt(c.brown, true)

    for i=1, follow.max_health do
      spr(t.ui_heart, ui_left + i * 6 - 2, top + 6)
      if i == follow.health then
        pal(c.red, c.darkblue)
        pal(c.pink, c.indigo)
      end
    end
  end

  pal()
  palt()

  -- draw castle indicators
  for p=1, #order do
    local sx = cam.x + 64
    local sy = cam.y + 64
    local player = players[p]
    local cx = player.castle_x * 8 + 8
    local cy = player.castle_y * 8 + 8
    if cx < cam.x or cy < cam.y or cx > cam.x + 128 or cy > cam.y + 128 then
      local dir = atan2((cx - sx), (cy - sy))
      local ox = flr(sx + cos(dir) * 50)
      local oy = flr(sy + sin(dir) * 50)
      pset(ox, oy, player_colors[p])
    end
  end
end

-- elements
units = {}
houses = {}

prev_state = nil
state = s.command
play_timer = 128
min_players = 2
max_players = 6
num_players = 2
turn_idx = 0
cur_player = 0
players = {}
order = {}

cam = _camera()
curs = _sprite(an_curs:copy(), 64, 64, pal_trans_red)
sel_curs = _sprite(an_curs:copy(), 64, 64, pal_sel_curs)
play_meter = _meter()
play_meter.y = 120
player_ui = _info()
menu = _menu()
follow = nil

btns = {[0]=false, [1]=false, [2]=false, [3]=false, [4]=false, [5]=false}
pbtns = btns

-- initialize all players
function init_players()
  players = {}
  order = {}
  for p=1, num_players do
    local race = flr(rnd(#races) + 1)
    local x = flr(rnd(56)) + 4
    local y = flr(rnd(56)) + 4
    local worker = _unit(p, x * 8, y * 8 + 16, races[race])
    local castle = _house(p, x * 8 + 4, y * 8 + 4, h.castle)

    -- decide which terrain to draw the castle on
    local ter = 0
    if x > 31 and y > 31 then
      ter = 3
    elseif x > 31 then
      ter = 2
    elseif y > 31 then
      ter = 1
    end

    -- draw castle
    mset2(x, y, t.ter_castle1 + ter * 16)
    mset2(x + 1, y, t.ter_castle2 + ter * 16)
    mset2(x, y + 1, t.ter_castle3 + ter * 16)
    mset2(x + 1, y + 1, t.ter_castle4 + ter * 16)

    add(units, worker)
    add(houses, castle)
    add(order, p)
    add(players, {
      castle_x=x,
      castle_y=y,
      race=race,
      materials=0,
      food=20,
      units=1,
    })
  end

  turn_idx = 0
  cur_player = 0
  next_turn()
end

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
  curs:move(closest_unit.x, closest_unit.y)
  sfx(a.ping)
end

-- move the cursor to the next unit (undefined behavior if no unit is under the cursor)
function jump_to_next_unit(list)
  list = list or units
  local i = 0
  for unit in all(list) do
    local unit_dist = mdst(unit, curs)
    i += 1

    if unit_dist == 0 then
      break
    end
  end

  -- decide the next unit
  local unit = list[i + 1]
  if i == #list then
    unit = list[1]
  end

  -- move cursor to unit
  follow = unit
  curs:move(unit.x, unit.y)
  sfx(a.ping)
end

-- move the cursor to the previous unit (undefined behavior if no unit is under the cursor)
function jump_to_prev_unit(list)
  list = list or units
  -- find the unit we're selecting
  local i = 0
  for unit in all(list) do
    local unit_dist = mdst(unit, curs)
    i += 1

    if unit_dist == 0 then
      break
    end
  end

  -- decide the previous unit
  local unit = list[i - 1]
  if i == 1 then
    unit = list[#list]
  end

  -- move cursor to unit
  follow = unit
  curs:move(unit.x, unit.y)
  sfx(a.ping)
end

-- move the cursor to the next unit owned by the cur_player
function jump_to_next_owned()
  local next = fals

  for unit in all(units) do

    if unit.owner == cur_player then
      if next then
        follow = unit
        curs:move(unit.x, unit.y)
        sfx(a.ping)
        return
      end

      local unit_dist = mdst(unit, curs)

      if unit_dist == 0 then
        next = true
      end
    end

  end

  jump_to_first_owned()
end

-- move the cursor to the first unit owned by the cur_player
function jump_to_first_owned()
  for unit in all(units) do
    if unit.owner == cur_player then
      follow = unit
      curs:move(unit.x, unit.y)
      sfx(a.ping)
      break
    end
  end
end

-- change the state, recording the previous one as well
function change_state(to)
  if type(to) == "string" then
    printh("changing state to '" .. to .. "'")
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

-- update owned counts
function update_owned_counts()
  for p=1, num_players do
    local owned_units = 0
    local owned_houses = 0
    local castle_alive = false

    for unit in all(units) do
      if unit.owner == p then
        owned_units += 1
      end
    end

    for house in all(houses) do
      if house.owner == p then
        if house.type == h.castle then
          castle_alive = true
        end
        owned_houses += 1
      end
    end

    players[p].units = owned_units
    players[p].houses = owned_houses
    players[p].castle_alive = castle_alive
  end
end

-- move to the next player, or start the play state
function next_turn()
  turn_idx += 1

  update_owned_counts()

  for p in all(order) do
    if players[p].units == 0 or not players[p].castle_alive then
      del(order, p)
      for unit in all(units) do
        if unit.owner == p then
          del(units, unit)
          players[p].units -= 1
        end
      end

      for house in all(houses) do
        if house.owner == p then
          del(houses, house)
          players[p].houses -= 1
        end
      end
    end
  end

  if #order <= 1 then
    change_state("win")
    return
  end

  -- move to next player
  if turn_idx <= #order then
    change_state("command")
    cur_player = order[turn_idx]
    jump_to_first_owned()

  -- move to play mode
  else
    cur_player = nil
    turn_idx = 0
    play_timer = 128
    change_state("play")

    local new_end = order[1]
    for i=1, #order - 1 do
      order[i] = order[i + 1]
    end
    order[#order] = new_end
  end
end

resources = {}

-- return the resources left on a node, generating if necessary
function get_resources(x, y)
  if x < 0 or y < 0 or x >= 64 or y >= 64 then
    return nil
  end

  local cell = mget2(x, y)
  local is_resource = fget(cell, f.food) or fget(cell, f.material)
  local key = coord_key(x, y)
  if is_resource and resources[key] == nil then
    resources[key] = flr(rnd(24) + 8)
  end

  return resources[key]
end

-- hire a new unit
function hire_unit(unit_type, owner, x, y)
  owner = owner or cur_player
  local player = players[owner]
  x = x or follow.x
  y = y or (follow.y + 8)

  local new = _unit(owner, x, y, races[player.race], unit_type)

  add(units, new)
  player.units += 1
  change_state(prev_state)
  return new
end

-- build a new house
function build_house(house_type, owner, x, y)
  local player = players[owner]
  local new = _house(owner, x * 8, y * 8, house_type)

  add(houses, new)
  player.houses += 1
  change_state(prev_state)
  return new
end

-- make the base menu when clicking from command mode
function make_base_menu()
  local player = players[cur_player]
  menu:clear()

  if follow ~= nil and follow.owner == cur_player then
    if follow.is_unit then
      menu:add("move", function()
        change_state("move")
      end)

      if follow.type == u.worker then
        local curs_x = flr(curs.x / 8)
        local curs_y = flr(curs.y / 8)
        menu:add("build", make_build_menu, can_build_adj(curs_x, curs_y) ~= false)
      end

    elseif follow.is_house then
      if follow.type == h.cave then
        menu:add("awaken", make_hire_menu, follow.action >= follow.cap)
      end
    end
  end

  menu:add("end turn", next_turn)
end

function make_build_menu()
  local player = players[cur_player]
  menu:clear()
  menu.back = make_base_menu

  local curs_x = flr(curs.x / 8)
  local curs_y = flr(curs.y / 8)
  local build_x, build_y = can_build_adj(curs_x, curs_y)

  menu:add(hc[h.farm] .. " farm", function()
    build_house(h.farm, cur_player, build_x, build_y)
    player.materials -= hc[h.farm]
  end, player.materials >= hc[h.farm])

  menu:add(hc[h.cave] .. " cave", function()
    build_house(h.cave, cur_player, build_x, build_y)
    player.materials -= hc[h.cave]
  end, player.materials >= hc[h.cave])

  menu:add(hc[h.tower] .. " tower", function()
    build_house(h.tower, cur_player, build_x, build_y)
    player.materials -= hc[h.tower]
  end, player.materials >= hc[h.tower])
end

function make_hire_menu()
  local player = players[cur_player]
  menu:clear()
  menu.back = make_base_menu

  menu:add("worker", function()
    hire_unit(u.worker)
    follow.action -= follow.cap
  end)

  menu:add("warrior", function()
    hire_unit(u.warrior)
    follow.action -= follow.cap
  end)
end

function use_resource(x, y, owner, amt)
  local res = get_resources(x, y)
  amt = min(amt or 1, res)

  if amt <= 0 then
    return
  end

  local new = res - amt
  resources[coord_key(x, y)] = new

  local cell = mget2(x, y)
  local player = players[owner]

  if fget(cell, f.food) then
    player.food += amt
  elseif fget(cell, f.material) then
    player.materials += amt
  end

  if new == 0 then
    mset2(x, y, flr(cell / 16) * 16)
  end
end

function _init()
  -- next_turn()
  change_state("splash")
end

function _update()
  pbtns = btns
  btns = {[0]=btn(0), [1]=btn(1), [2]=btn(2), [3]=btn(3), [4]=btn(4), [5]=btn(5)}

  if state == s.splash or state == s.win then
    cam.x = 0
    cam.y = 0

  elseif state == s.command or state == s.play then
    local move_amt = 8
    if follow and follow.is_house and follow.type == h.castle then
      move_amt = 12
    end

    if btnp(b.left) then
      if btns[b.o] then
        jump_to_prev_unit()
      else
        curs:dmove(-move_amt, 0)
      end
    end

    if btnp(b.right) then
      if btns[b.o] then
        jump_to_next_unit()
      else
        curs:dmove(move_amt, 0)
      end
    end

    if btnp(b.up) then
      if btns[b.o] then
        jump_to_prev_unit(houses)
      else
        curs:dmove(0, -move_amt)
      end
    end

    if btnp(b.down) then
      if btns[b.o] then
        jump_to_next_unit(houses)
      else
        curs:dmove(0, move_amt)
      end
    end

    follow = nil
    for unit in all(units) do
      if flr(unit.x) == flr(curs.x) and flr(unit.y) == flr(curs.y) then
        follow = unit
        break
      end
    end

    if follow == nil then
      for house in all(houses) do
        if house.type == h.castle then
          if mdst(curs, house) <= 8 then
            follow = house
            break
          end
        end

        if flr(house.x) == flr(curs.x) and flr(house.y) == flr(curs.y) then
          follow = house
          break
        end
      end
    end

    if follow == nil then
      curs.x = flr(curs.x / 8) * 8
      curs.y = flr(curs.y / 8) * 8
    end

    if not pbtns[b.o] and btns[b.o] then
      if cur_player and follow ~= nil then
        jump_to_next_owned()
      else
        jump_to_closest_unit()
      end
    end

    if btnp(b.x) then
      if state == s.command then
        make_base_menu()

        if #menu.labels > 0 then
          change_state("menu")
        end
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
      if menu.back ~= nil then
        menu.back()
      else
        change_state(prev_state)
      end
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

    local dist = mdst(curs, sel_curs)
    if dist > worker_range * 8 then
      curs.palette = pal_bad_curs
      follow:set_dest(follow.x, follow.y)
    else
      curs.palette = pal_trans_red
      if btnp(b.left) or btnp(b.right) or btnp(b.up) or btnp(b.down) then
        follow:set_dest(curs.x, curs.y)
      end
    end

    if not can_path(flr(curs.x / 8), flr(curs.y / 8)) then
      curs.palette = pal_bad_curs
      follow:set_dest(follow.x, follow.y)
    end

    if btnp(b.x) then
      if curs.palette == pal_trans_red then
        curs.palette = pal_trans_red
        follow = nil
        change_state("command")
        sfx(a.ok)
      else
        sfx(a.no)
      end
    end

    if btnp(b.o) then
      follow:set_dest(follow.x, follow.y)
      change_state("command")
    end
  end

  if state == s.play then
    for house in all(houses) do
      house:update()
      if house.health <= 0 then
        del(houses, house)
        if houses[house.owner] and houses[house.owner].houses then
          houses[house.owner].houses -= 1
        end

        -- reset terrain to neutral
        local cell_x = flr(house.x / 8)
        local cell_y = flr(house.y / 8)
        local cell_n = mget2(cell_x, cell_y)
        mset2(cell_x, cell_y, flr(cell_n / 16) * 16)
      end
    end

    for unit in all(units) do
      unit:update()
      if unit.health <= 0 then
        del(units, unit)
        players[unit.owner].units -= 1
      end
    end

    play_timer -= 1
    play_meter:fill(play_timer)
    if play_timer == 0 then
      next_turn()
    end
  end

  if state ~= s.splash and state ~= s.win then
    if curs.x < 0 then
      curs.x = 0
    end
    if curs.x > 504 then
      curs.x = 504
    end
    if curs.y < 0 then
      curs.y = 0
    end
    if curs.y > 504 then
      curs.y = 504
    end

    cam:move(curs.x - 60, curs.y - 60)
    cam:update()

    curs:update()
    sel_curs:update()

    if follow ~= nil then
      sel_curs:move(follow.x, follow.y)
      if state ~= s.move then
        curs:move(follow.x, follow.y)
      end
    end
  end
end

function _draw()
  cls()
  cam:draw()

  if state == s.splash or state == s.win then
    rectfill(0, 0, 128, 128, c.darkgrey)
    palt()
    palt(c.black, false)
    palt(c.green, true)
    spr(76, 0, 96)
    spr(77, 8, 96)
    spr(78, 16, 96)
    spr(79, 24, 96)
    spr(92, 0, 104)
    spr(93, 8, 104)
    spr(94, 16, 104)
    spr(95, 24, 104)
    spr(108, 0, 112)
    spr(109, 8, 112)
    spr(110, 16, 112)
    spr(111, 24, 112)
    spr(124, 0, 120)
    spr(125, 8, 120)
    spr(126, 16, 120)
    spr(127, 24, 120)

    if state == s.splash then
      print("bare wars", 47, 48, c.lightgrey)

      for i=min_players, max_players do
        local col = c.lightgrey
        if i == num_players then
          col = player_colors[i]
        end
        print(i .. "p", i * 16 - 4, 64, col)
      end

      print("press \142+\151", 43, 80, c.lightgrey)

      if btnp(b.left) then
        num_players = max(num_players - 1, min_players)
        sfx(a.ping)
      end

      if btnp(b.right) then
        num_players = min(num_players + 1, max_players)
        sfx(a.ping)
      end

      if btn(b.o) and btn(b.x) then
        init_players()
        change_state("command")
      end

    elseif state == s.win then
      if #order == 1 then
        print("victory", 50, 48, c.lightgrey)

        local off_x = 64 - num_players * 8 - 10
        for i=1, num_players do
          local col = c.indigo
          if i == order[1] then
            col = player_colors[i]
          end
          print(i, i * 16 + off_x, 64, col)
        end
      else
        print("draw", 60, 48, c.lightgrey)
      end

      print("reset \142+\151", 43, 80, c.lightgrey)

      if btn(b.o) and btn(b.x) then
        run()
      end
    end

    local col = player_colors[num_players]
    if state == s.win then
      col = player_colors[order[1]]
    end

    if btn(b.x) then
      print("         \151", 43, 80, col)
    end

    if btn(b.o) then
      print("      \142", 43, 80, col)
    end

  else
    map(0, 0, 0, 0, 64, 32)
    map(64, 0, 0, 256, 64, 32)

    for p in all(order) do
      local player = players[p]
      pset(player.castle_x * 8 + 1, player.castle_y * 8 + 5, player_colors[p])
      pset(player.castle_x * 8 + 2, player.castle_y * 8 + 4, player_colors[p])
      pset(player.castle_x * 8 + 2, player.castle_y * 8 + 5, player_colors[p])
      pset(player.castle_x * 8 + 2, player.castle_y * 8 + 6, player_colors[p])
    end

    -- mark selectable cells
    if state == s.move then
      local mx = flr(follow.x / 8)
      local my = flr(follow.y / 8)
      for x=-8, 8 do
        for y=-8, 8 do
          if can_path(mx + x, my + y) and abs(x) + abs(y) <= worker_range then
            pset((mx + x) * 8 + 4, (my + y) * 8 + 4, c.lightgrey)
          end
        end
      end
    end

    for unit in all(units) do
      unit:draw()
    end

    for house in all(houses) do
      house:draw()
    end

    curs:draw()

    if follow ~= nil then
      sel_curs:draw()
    end

    if state == s.move then
      -- distance tooltip
      if follow.path then
        rectfill(curs.x + 9, curs.y, curs.x + 13, curs.y + 6, c.darkgrey)
        print(#follow.path, curs.x + 10, curs.y + 1, c.white)
      end
    end

    if state == s.menu or state == s.command or state == s.move or state == s.play then
      player_ui:draw()
    end

    if state == s.menu then
      menu:draw()
    end

    if state == s.play then
      play_meter:draw()
    end
  end
end

__gfx__
00000000880088000880088000880088800880088888888888888888888888888888888888888888888888888888888889444498867777688511115885777758
00000000088888880888888088888880888888888894498888944988889449888888888885588558888555888888888884444448877777788111111887777778
00700700088888888888888888888880088888808840408888404088884040888888888885655658885666588888888884044048870770788101101887077078
00077000888888808888888808888888088888808444044884440448844404488555555885d6dd588856dd588888888844440444777707771111011177770777
000770008888888008888880088888888888888888444488884444888844448885dd6d58885d6588856d00588888888844444444777777771111111177777777
0070070008888888088888808888888088888888884994888849948888499488856666588856d58885d000588888888884499448877667788115511887755778
000000000888888888888888888888800888888088488488884888888888848885d6dd5885dd6d5885d001588888888884499448877667788115511887755778
00000000880088008008800800880088088008808888888888888888888888888888888888888888888888888888888884488448877887788118811887788778
00000000000888888888888800666005000000050066600000000000500000008888888888888888888888880000000085588558000000000000000000000000
00000000060000000000000006ee76050000000506ee760000000000850000008894496888944968889449680000000085655658000000000000000000000000
00000000000888888888888806eee6050000000506eee60000000000885000008840406888404068884040680000000085d6dd58000000000000000000000000
00000000808888888888888806eee6050000000506eee60000000000888500008664041886640418866404180000000088566588000000000000000000000000
000000008088888888888888006660500000005000666000000000008888500086644488866444888664448800000000885d6588000000000000000000000000
00000000000888888888888800000500000005000000000000000000888885008849948888499488884994880000000085666658000000000000000000000000
00000000060000000000000000005000000050000000000055555555888888558848848888488888888884880000000085d6dd58000000000000000000000000
00000000000888888888888855555555555555555555555588888888888888888888888888888888888888880000000056666665000000000000000000000000
00000000666000000000000006111111000000000000000000000000000000008888888800000000000000000000000000000000000000000000000000000000
000000006166666666666666061111110077000000000000000000000000000084b3b3b800000000000000000000000000000000000000000000000000000000
00000000666111111111111106111111007770000000000000000000000000008444444800000000000000000000000000000000000000000000000000000000
000000000611111111111111061111110077770000000000000000000000000084b3b3b800000000000000000000000000000000000000000000000000000000
00000000061111111111111106111111007770000000000000000000000000008444444800000000000000000000000000000000000000000000000000000000
000000000611111111111111061111110077000000000000000000000000000084b3b3b800000000000000000000000000000000000000000000000000000000
00000000061111111111111106111111000000000000000000000000000000008444444800000000000000000000000000000000000000000000000000000000
00000000061111111111111106111111000000000000000000000000000000008888888800000000000000000000000000000000000000000000000000000000
00000000888888888888888888888888444444448888888888888888888888888888888800000000000000000000000000000000000000000000000000000000
00000000888878888889988884844488448484448944498888886688886d58888885588800000000000000000000000000000000000000000000000000000000
00000000888f7788889a7988884444884888e844840404888846d688888555888856658800000000000000000000000000000000000000000000000000000000
000000008444f888889aa9888499448844888444844044888845688888445d88856dd58800000000000000000000000000000000000000000000000000000000
0000000084448888889aa98884994888444844448444448884144888844486888565158800000000000000000000000000000000000000000000000000000000
000000008444888888899888884488884444444484999488844888888448888885d1158800000000000000000000000000000000000000000000000000000000
00000000888888888888888888888888444444448888888888888888888888888888888800000000000000000000000000000000000000000000000000000000
00000000888888888888888888888888444444448888888888888888888888888888888800000000000000000000000000000000000000000000000000000000
333333333333333333333333333333333333333333333333333333330000000033335535535533333335666666665333bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
3333333333bb333333bbbb3333344333333bb33333333333333333330000000033335555555533333335d6dd6dd65333bbbbbbbbbbbbbbbbbbbbbbbbbbb333bb
3333333333b333b33b2b2bb33344443333bbbb3333333333333333330000000033335666666533333335666666665333bbbbbbbbbbbbbbbbbbbbbbbb33338333
3333333333333bb33bbbb2b33399993333bbbb3333333333333333330000000033335dd6dd6533333355dd6dd6dd5533bbbbbbbbbbbb3333bbb3333b38388383
333333333b3333333b2bbbb3334444333bbbbbb333333333333333330000000033e45661166533333356666446666533bbbbbbbbbb3334433333003389898883
333333333bb33b3333bb2b33339999333334433333333333336d6d33000000003ee45d1ff1d53333335d6d44446dd533bbbbbbbb333440444444000899999883
3333333333333bb3333bb33333444433333443333333333336d666d30000000033e4561ff16533333556664444666553bbb333333444400044445029aaa99983
333333333333333333333333333333333333333333333333333333330000000033355d1111655333556dd64444dd6d55bbb34445444444044444459aaaaaa983
ffffffffffffffffffffffffffffffffffffffffffffffffffffffff00000000ffff55f55f55fffffff5666666665fffbbb3400444444444444459a7777aa983
ffffffffff9ff9ffffbb8fffffffffffff3333ffffffffffffffffff00000000ffff55555555fffffff5d6dd6dd65fffbbb340444444444455559a77777aa933
fffffffff9f9ff9fff8bbf8ffff55ffff333333fffffffffffffffff00000000ffff56666665fffffff5666666665fffbbb34444444444457667a77777aa993b
fffffffffffff9fffffbffb8ff7ee7fff333333fffffffffffffffff00000000ffff5dd6dd65ffffff55dd6dd6dd55ffbb3344444444444deeee77777aaa993b
fffffffffff9fffffbbbfbbfff7ee7ffff3333ffffffffffffffffff00000000ffe456611665ffffff566664466665ffb33444444444444deeee6aaaaaa9933b
ffffffffff9ff9fff8fbbbffff7ee7fffff55fffffffffffff6d6dff00000000fee45d1ff1d5ffffff5d6d44446dd5ff3344444444444445deed5444999933bb
fffffffffff9ff9fffffbfffff7777fffff55ffffffffffff6d666df00000000ffe4561ff165fffff55666444466655f34444444444444447ee7444433333bbb
ffffffffffffffffffffffffffffffffffffffffffffffffffffffff00000000fff55d1111655fff556dd64444dd6d553444444444444444566544443bbbbbbb
dddddddddddddddddddddddddddddddddddddddddddddddddddddddd00000000dddd55d55d55ddddddd5666666665ddd4444444444444444444444443bbbbbbb
dddddddddddd5ddddddccddddddccddddddddddddddddddddddddddd00000000dddd55555555ddddddd5d6dd6dd65ddd4444444444444444444444443bbbbbbb
dddddddddd5dddddddccccddddc7ccddddd5dddddddddddddddddddd00000000dddd56666665ddddddd5666666665ddd4444444444444444444444333bbbbbbb
ddddddddddddd5ddddcc1ccdddcc7cdddd555ddddddddddddddddddd00000000dddd5dd6dd65dddddd55dd6dd6dd55dd44444444444444444444443bbbbbbbbb
ddddddddd5dddddddcc111cddd7cc7dddd5555dddddddddddddddddd00000000dde456611665dddddd566664466665dd44444444444444444444433bbbbbbbbb
dddddddddddd5ddddcc11cddddc7ccddd555555ddddddddddd6565dd00000000dee45d1ff1d5dddddd5d6d44446dd5dd44444444444444444444433bbbbbbbbb
dddddddddd5ddd5dddccccdddddc7dddd555555dddddddddd656665d00000000dde4561ff165ddddd55666444466655d44444444444444444444443bbbbbbbbb
dddddddddddddddddddddddddddddddddddddddddddddddddddddddd00000000ddd55d1111655ddd556dd64444dd6d5544444444444444444444443bbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb00000000bbbb55b55b55bbbbbbb5666666665bbb444444444444444444444443bbbbbbbb
bbbbbbbbb6bbbb6bbbb9bbbbbb8eeebbbbbebebbbbbbbbbbbbbbbbbb00000000bbbb55555555bbbbbbb5d6dd6dd65bbb444444444444444444444443bbbbbbbb
bbbbbbbbbbbb6bbbb9b3b9bbbb887ebbbbeeeebbbbbbbbbbbbbbbbbb00000000bbbb56666665bbbbbbb5666666665bbb4444444444444444444444433bbbbbbb
bbbbbbbbbbbbbbbbbb3bb3bbbb888ebbbeeeeeebbbbbbbbbbbbbbbbb00000000bbbb5dd6dd65bbbbbb55dd6dd6dd55bb4444444444444444444444443bbbbbbb
bbbbbbbbbbb6bbbbbb3bb3bbbbd888bbbbeeeebbbbbbbbbbbbbbbbbb00000000bbe456611665bbbbbb566664466665bb4444444444444444444444443bbbbbbb
bbbbbbbbbbbbbb6bbb3b3bbbbbbd8bbbbbb44bbbbbbbbbbbbb6d6dbb00000000bee45d1ff1d5bbbbbb5d6d44446dd5bb44444444444444444444444433bbbbbb
bbbbbbbbb6bbbbbbbb3b3bbbbbbbbbbbbbb44bbbbbbbbbbbb6d666db00000000bbe4561ff165bbbbb55666444466655b44444444444444444444444443bbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb00000000bbb55d1111655bbb556dd64444dd6d5544444444444444444444444443bbbbbb
33333333333333333333333333333333333333330000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
38334443333999b33333333333333333333338330000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
9b34ccc44444449b33a333334433333334433b330000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
334ccccddccccc4933b33444cc4433444cc433330000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
334cccd11ddccc4933334ccccccc44cccccc43330000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
334ccd11111dcc433334ccccccccccccccccc4330000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
334cd1111111dc433334ccccccccccccccccc4330000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
34ccd1110011d433334cccc7cccccc7cccccc4330000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
334cd1110011d433334ccccccccccccccccccc43cccccccccccccccc000000000000000000000000000000000000000000000000000000000000000000000000
334ccdd11111d433334ccccccc7ccccccccccc43ccc7cccccccccccc000000000000000000000000000000000000000000000000000000000000000000000000
3334cccd111dc4333334cccccccccccccccccc43cccccccccccccc7c000000000000000000000000000000000000000000000000000000000000000000000000
3394ccccdddc43333334ccc7ccccc7cccccccc43cccccccccccccccc000000000000000000000000000000000000000000000000000000000000000000000000
3394ccccccc43333334ccccccccccccccc7cc433cccc7cccc44ccccc000000000000000000000000000000000000000000000000000000000000000000000000
33b9444ccc433e33334cccccccccccccccccc433cccccccc4334cccc000000000000000000000000000000000000000000000000000000000000000000000000
333b99944433eb33334cccccccccccccccccc433ccccccc433e34ccc000000000000000000000000000000000000000000000000000000000000000000000000
33333333333333333334ccccccccccc7cccccc43cccccc4333334ccc000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000003334cccccc7ccccccccccc43cccccc4333334ccc000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000003334ccccccccccccccccc433cccccc4833a34ccc000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000033334ccccccccccccccc4333ccccccc43334cccc000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000333334cccccc44ccccc433b3cccccccc444ccccc000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000333333444444334cc4433333cc7ccccccccccccc000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000003e3e33333333333443333b33ccccc7ccccccc7cc000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000003b3b333333333333333b3333cccccccccccccccc000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000333333333333333333333333cccccccccccccccc000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
33333333dddddddd33333333dddddddd33333333dddddddd00000000000000000000000000000000000000000000000000000000000000000000000000000000
3333333d3ddddddd33333333dddddddd3333333d3d3ddddd00000000000000000000000000000000000000000000000000000000000000000000000000000000
33333d33dd3ddddd33333333dddddddd33333d33dddddddd00000000000000000000000000000000000000000000000000000000000000000000000000000000
3333333d3ddddddd33333333dddddddd3333333d3d3ddddd00000000000000000000000000000000000000000000000000000000000000000000000000000000
33333333dddddddd33333333dddddddd33333333dddddddd00000000000000000000000000000000000000000000000000000000000000000000000000000000
3333333d3ddddddd3f333f33ddbdddbd3f3f3d3d3dbdbdbd00000000000000000000000000000000000000000000000000000000000000000000000000000000
33333d33dd3ddddd33333333dddddddd33333333dddddddd00000000000000000000000000000000000000000000000000000000000000000000000000000000
3333333d3dddddddf3f3f3f3dbdbdbdbf3f3f3f3dbdbdbdb00000000000000000000000000000000000000000000000000000000000000000000000000000000
ffffffffbbbbbbbb3f3f3f3fbdbdbdbd3f3f3f3fbdbdbdbd00000000000000000000000000000000000000000000000000000000000000000000000000000000
fffffffbfbbbbbbbffffffffbbbbbbbbfffffffbfbbbbbbb00000000000000000000000000000000000000000000000000000000000000000000000000000000
fffffbffbbfbbbbbf3fff3ffbbdbbbdbf3f3fbffbbfbdbdb00000000000000000000000000000000000000000000000000000000000000000000000000000000
fffffffbfbbbbbbbffffffffbbbbbbbbfffffffbfbbbbbbb00000000000000000000000000000000000000000000000000000000000000000000000000000000
ffffffffbbbbbbbbffffffffbbbbbbbbffffffffbbbbbbbb00000000000000000000000000000000000000000000000000000000000000000000000000000000
fffffffbfbbbbbbbffffffffbbbbbbbbfffffffbfbfbbbbb00000000000000000000000000000000000000000000000000000000000000000000000000000000
fffffbffbbfbbbbbffffffffbbbbbbbbfffffbffbbbbbbbb00000000000000000000000000000000000000000000000000000000000000000000000000000000
fffffffbfbbbbbbbffffffffbbbbbbbbfffffffbfbbbbbbb00000000000000000000000000000000000000000000000000000000000000000000000000000000
__label__
00666005005550000000000700770070000000990077007770000404440770000000009444900777000000000550000700000000000000000000000000000000
06cc760505887500000000f770070070000009a79007000070000044440070000000004040400007000000005665000700000000000000000000000000000000
06ccc605058885000000444f00070077700009aa9007000070000499440070000000004404400777000000056dd5000777000000000000000000000000000000
06ccc605058885000000444000070070700009aa9007000070000499400070000000004444400700000000056515000707000000000000000000000000000000
0066605000555000000044400077707770000099007770007000004400077700000000499940077700000005d115000777000000000000000000000000000000
00000500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00005000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55555555555555555000008080008080008080008080008080008080008080008080008080008080001010001010000000000000000000000000000000000000
ffff555ffffffffff5000888e80888e80888e80888e80888e80888e80888e80888e80888e80888e80111d10111d1000000000000000000000000000000000000
ffcb585fffffffffff50008880008880008880008880008880008880008880008880008880008880001110001110000000000000000000000000000000000000
ff8b555ffffffffffff5000800000800000800000800000800000800000800000800000800000800000100000100000000000000000000000000000000000000
fffbffb8ffffffffffff500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005
fbcbfcbffffffffffffff5000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005b
f8fbbbffffffffffffffff55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555bb
ffffbffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff5dd6d5fbbbbbbbb
ff8ff8ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff99999999bbbbbbbb
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffbbbbbbbb
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffbbbbbbbb
ffcffcffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffbbbbbbbb
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffbbbbbbbb
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffbbbbbbbb
ffcffcafffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffbbbbbbbb
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffbbbbbbbb
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffbbbbbbbb
ff8ffcffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffbbbbbbbb
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffbbbbbbbb
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffbbbbbbbb
ffcffcffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffbbbbbbbb
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffbbbbbbbb
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffbbbbbbbb
ffcffcffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffbbbbbbbb
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffbbbbbbbb
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcfffffffffffffffffffffffffffffffffffffffbbbbbbbb
ffcffcffffffffffff3333ffffffffffffffffffffffffffffffffffff9ff9fffffffffffffffffff65775ffffffffffffffffffffffffffffffffffbbbbbbbb
fffffffffffffffff333333ffffffffffffffffffffffffffffffffff9f9ff9ffffffffffffffffff66767ffffffffffffffffffffffffffffffffffbbbbbbbb
fffffffffffffffff333333ffffffffffffffffffffffffffffffffffffff9fffffffffffffffffff176766fffffffffffffffffffffffffffffffffbbbbbbbb
ffcffcffffffffffff3333fffffffffffffffffffffffffffffffffffff9ffffffffffffffffffffff77766fffffffffffffffffffffffffffffffffbbbbbbbb
fffffffffffffffffff55fffffffffffffffffffffffffffffffffffff9ff9ffffffffffffffffffff7557ffffffffffffffffffffffffffffffffffbbbbbbbb
fffffffffffffffffff55ffffffffffffffffffffffffffffffffffffff9ff9fffffffffffffffffff7ff7ffffffffffffffffffffffffffffffffffbbbbbbbb
ffcffcffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffbbbbbbbb
ffffffffcfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcfffffffffffffffffffffffffffffffffffffffffffffffbbbbbbbb
ffffffffff57756fffffffffffffffffffffffffffffffffffffffffffffffffffffffffff57756fffffffffffbb8fffffffffffffffffffffffffffbbbbbbbb
ffcffcffff76766fffffffffffffffffffffffffffffffffffffffffffffffffffffffffff76766fffffffffff8bbf8fffffffffffffffffffffffffbbbbbbbb
fffffffff667671ffffffffffffffffffffffffffffffffffffffffffffffffffffffffff667671ffffffffffffbffb8ffffffffffffffffffffffffbbbbbbbb
fffffffff66777fffffffffffffffffffffffffffffffffffffffffffffffffffffffffff66777fffffffffffbbbfbbfffffffffffffffffffffffffbbbbbbbb
ffcffcffff7557ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff7557fffffffffff8fbbbffffffffffffffffffffffffffbbbbbbbb
ffffffffff7ff7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff7ff7ffffffffffffffbfffffffffffffffffffffffffffbbbbbbbb
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffbbbbbbbb
ffcffcffffffffffffffffffffffffffffffffffffffffffffffffffcfffffffffffffffffffffffcfffffffffffffffffffffffffffffffffffffffbbbbbbbb
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffff57756ffffffffffffffffff65775ffffffffffffffffffffffffffffffffffbbbbbbbb
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffff76766ffffffffffffffffff66767ffffffffffffffffffffffffffffffffffbbbbbbbb
ffcff8fffffffffffffffffffffffffffffffffffffffffffffffffff667671ffffffffffffffffff176766fffffffffffffffffffffffffffffffffbbbbbbbb
fffffffffffffffffffffffffffffffffffffffffffffffffffffffff66777ffffffffffffffffffff77766fffffffffffffffffffffffffffffffffbbbbbbbb
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffff7557ffffffffffffffffffff7557ffffffffffffffffffffffffffffffffffbbbbbbbb
ffcff8ffffffffffffffffffffffffffffffffffffffffffffffffffff7ff7ffffffffffffffffffff7ff7ffffffffffffffffffffffffffffffffffbbbbbbbb
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffbbbbbbbb
ffffffffffffffffffffffffffffffffffffffff8fffffffcfffffffffff55f55f55ffffffffffffffffffffffffffffffffffffffffffffffffffffbbbbbbbb
ffcffcfffffffffffffffffffffffffffffffffff55ff55ff65775ffffff55555555ffffffffffffffffffffffffffffffffffffffffffffff9ff9ffbbbbbbbb
fffffffffffffffffffffffffffffffffffffffff565565ff66767ffffff56666665fffffffffffffffffffffffffffffffffffffffffffff9f9ff9fbbbbbbbb
fffffffffffffffffffffffffffffffffffffffff5d6dd5ff176766fffff5dd6dd65fffffffffffffffffffffffffffffffffffffffffffffffff9ffbbbbbbbb
ffcffcffffffffffffffffffffffffffffffffffff5d65ffff77766fff8488618865fffffffffffffffffffffffffffffffffffffffffffffff9ffffbbbbbbbb
ffffffffffffffffffffffffffffffffffffffffff56d5ffff7557fff8845d1ff1d8ffffffffffffffffffffffffffffffffffffffffffffff9ff9ffbbbbbbbb
fffffffffffffffffffffffffffffffffffffffff5dd6d5fff7ff7ffff84561ff168fffffffffffffffffffffffffffffffffffffffffffffff9ff9fbbbbbbbb
fffffcffffffffffffffffffffffffffffffffff99fffffffffffffffff58d1111655fffffffffffffffffffffffffffffffffffffffffffffffffffbbbbbbbb
fffffffffffffffffffffffffffffffffffffffffffffffffffffffffff5866666665fffffffffff8fffffffcfffffffffffffffffffffffffffffffbbbbbbbb
fffffffffffffffffffffffffffffffffffffffffffffffffffffffffff5d6dd6dd85ffffffffffff4b3b3bff65775ffffffffffffffffffffffffffbbbbbbbb
fffffcaffffffffffffffffffffffffffffffffffffffffffffffffffff5666666685ffffffffffff444444ff66767ffffffffffffffffffffffffffbbbbbbbb
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffff55886d88dd55fffffffffff4b3b3bff176766fffffffffffffffffffffffffbbbbbbbb
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffff566664466665fffffffffff444444fff77766fffffffffffffffffffffffffbbbbbbbb
fffff8ffffffffffffffffffffffffffffffffffffffffffffffffffff5d6d44446dd5fffffffffff4b3b3bfff7557ffffffffffffffffffffffffffbbbbbbbb
fffffffffffffffffffffffffffffffffffffffffffffffffffffffff55666444466655ffffffffff444444fff7ff7ffffffffffffffffffffffffffbbbbbbbb
ffffffffffffffffffffffffffffffffffffffffffffffffffffffff556dd64444dd6d55ffffffffffffffffffffffffffffffffffffffffffffffffbbbbbbbb
fffffcffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcfffffffffffffffffffffffffffffffffffffffbbbbbbbb
ff3333fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff65775ffffffffffffffffffffffffffffffffffbbbbbbbb
f333333ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff66767ffffffffffffffffffffffffffffffffffbbbbbbbb
f3333c3ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff176766fffffffffffffffffffffffffffffffffbbbbbbbb
ff3333ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff77766fffffffffffffffffffffffffffffffffbbbbbbbb
fff55fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff7557ffffffffffffffffffffffffffffffffffbbbbbbbb
fff558ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff7ff7ffffffffffffffffffffffffffffffffffbbbbbbbb
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffbbbbbbbb
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffbbbbbbbb
fffffcffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffbbbbbbbb
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffbbbbbbbb
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffbbbbbbbb
fffffcffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffbbbbbbbb
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffbbbbbbbb
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffbbbbbbbb
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffbbbbbbbb
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffbbbbbbbb
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffbbbbbbbb
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffbbbbbbbb
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffbbbbbbbb
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffbbbbbbbb
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffbbbbbbbb
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffbbbbbbbb
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffbbbbbbbb
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffbbbbbbbb
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffbbbbbbbb
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffbbbbbbbb
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffbbbbbbbb
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffbbbbbbbb
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffbbbbbbbb
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffbbbbbbbb
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffbbbbbbbb
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffbbbbbbbb
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffbbbbbbbb
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffbbbbbbbb
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffbbbbbbbb
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffbbbbbbbb
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffbbbbbbbb
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffbbbbbbbb
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffbbbbbbbb
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff8fffffffffffffffffffffffffffffffffffffffbbbbbbbb
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff9449ffffffffffffffffffffffffffffffffffbbbbbbbb
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff4040ffffffffffffffffffffffffffffffffffbbbbbbbb
fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff444044fffffffffffffffffffffffffffffffffbbbbbbbb
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff4444ffffffffffffffffffffffffffffffffffbbbbbbbb
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff4994ffffffffffffffffffffffffffffffffffbbbbbbbb
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff4ff4ffffffffffffffffffffffffffffffffffbbbbbbbb
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffbbbbbbbb
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffbbbbbbbb
ffffffffffffffffffffffffffffffffffffffffff9ff9ffffffffffffffffffffffffffffffffffffbb8fffffffffffffffffffffffffffffffffffbbbbbbbb
fffffffffffffffffffffffffffffffffffffffff9f9ff9fffffffffffffffffffffffffffffffffff8bbf8fffffffffffffffffffffffffffffffffbbbbbbbb
fffffffffffffffffffffffffffffffffffffffffffff9fffffffffffffffffffffffffffffffffffffbffb8ffffffffffffffffffffffffffffffffbbbbbbbb
fffffffffffffffffffffffffffffffffffffffffff9fffffffffffffffffffffffffffffffffffffbbbfbbfffffffffffffffffffffffffffffffffbbbbbbbb
ffffffffffffffffffffffffffffffffffffffffff9ff9fffffffffffffffffffffffffffffffffff8fbbbffffffffffffffffffffffffffffffffffbbbbbbbb
fffffffffffffffffffffffffffffffffffffffffff9ff9fffffffffffffffffffffffffffffffffffffbfffffffffffffffffffffffffffffffffffbbbbbbbb
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffbbbbbbbb

__gff__
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003050900000301090121001111111100000000000003010901210011111111000000000000030109012100111111110000000000000301090121001111111100000000
0101010101000000000000000000000001010101010000000000000000000000000001010100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
40404040404040404040404040404040404040404040404040404040404040464760606062606060606060606060606060606063606060606060606060606060d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d4d5d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3
4040404040404040404040404040404040404040404040404040404040404046476060606060606060606060606060626060606060606060606060606060646050505050505050505050505050505050505050505050505050505050505050d0d170707070707070707070707070707070707070707070707070707070707070
4040404040404040404041404040414040404040434040404040404040424046476060606060606060606460606060606060606060606160606060606060606050505050505050505050505050505050505050505050505050505050505050d0d170707070707070707070707070707070707070707070707070707070707070
4040404040404040404040404040404040404040404040404440404040404046476060606060606360606060606060606060606060606060606060626060606050505050505050505050505050505450505050505050505050505054505050d0d170707070707070707070707070707070707070707070707070707070707070
4040404140404040414040404040404040404040404040404040404040404046476060606060606060606060606160606460606060606060606060606060606050505050515050505050505050505050505250505050505050505050505050d0d170707070737070707070707470707070707270707070707070707070707070
4040404040404040404040404040404040404240404140404040404040404046476060606060606060606160606060606060606060606063606060606060606050505050505050505050505050505050505050505050505050505050505050d0d170707070707070707070707070707070707070707070707070737070707070
4040404040404040404040404040404040404040404040404040404040404046476060606060606060606060606060606060606060606060606060606060606150505050505050505053505051505050505050505150505050505050505050d0d170707070707070707170707070707070707070707070707071707070707070
4040404040414040404440404041404040404040404040404040404040404046476060606160606060606060606060606060616060606060606060606060606050505050505050505050505050505050505050505050505050505050505050d0d170707070707070707070707070707070707070707070707070707070707070
4040404040404040404040404040404040404040404040404040414040404046476060606060606060606064606060606060606060606060606062606060606050505050505250505050505050505050505050505050505050505050505050d0d170707070707072707070707070707070707070707070707070707070707070
4040404040408081404040404040404042404040404040444040404040404046476060606060606060606060606060636060606060606060606060606060606050505050505050505050505052505050505050505050505350505050505050d0d170707070707070707070707070707070737070707070707070707070707070
4040404340409091404040404040404040404040404040404040404040404046476060606060606260606060606060606060606060606160606060606063606450505050505050505050505050505050505050505050505050505450505050d0d170707070707070707070707070707071707070707070707070707070707070
4040404040404040404042404040404040404040414040404040404040404046476060606060606060606060606060606060606060606060606060606060606050505050505054505050505050505050545050505050505050505050505050d0d170707070707070707070707070707070707070707072707070707070707070
4040404040404040404040404040444040404040404043404040404140404046476060606060606060606160606060606460606060606060606060606060606050505050505050505050505050505050535050505051505050505050505050d0d170707073707070707074707070707070707070707070707070707070707070
4040404040404040404040404040404040404040404040404040404040404046476060606060606060606060606060606060606060606060606060606060606050505050505050505050505150505050505050505050505050505050505050d0d170707070707070707070707070707070707070707070707070747070707070
4040404040414040404040404040404040404040404040404040404040404046476060606060606060606060606060606060606060606060606060606060606050505050525050505050505050505050505050505050505050505350505050d0d170707070707071707070707070707070747070707070707070707070707070
4040404040404040404041404040404041404040404040404040404040404046476060606060606060606060606060606060606060606060606060606060606050505050505050545050505050505050505250505050505050505050505050d0d170707070707070707070707072707070707070707070707070707070707070
4040404040404040404040404040404040404082844044404040404040404046476060606060606060606060606060606060606060606060606060606060606050505050505050505050505050505050505050505050505050505050505054d0d170707070707070707070707070707070707070707070707070707070707070
4040404040404040404040404040404040404092944040404040404040404046476060606060606060646060606060606060606060606060606060606260606050505050505050505050505050535050505050505050505050505050505050d0d170707070707070707070707070707070707170707070707070707070707070
4040404340404240404040404040404040404092944040404040424040404046476060606060606060606060606060606060606060606060606060606060606050505050505050515050505050505050505050545050505051505050505050d0d170707070707070707070707170707070707070707070707070707070707070
4040404040404040404044404040414042404092944040404040404040404046476060606060606060606060606060606060606060606060606061606060606050505050505050505050505050505050505050505050505050505050525050d0d170707070727070707070707070707070707070707070737070707070707070
4040404040404040404040404040404040404092944040404040404040404046476060606060606060606060606060606060606060606060606060606063606050505050505050505050505050505050505050505050505050505050505050d0d170707070707070707070707070707470707070707070707070707070707070
4040404040404140404040404040404040404092944040404040404040404046476060606060606060606460606060606060606060606060606064606060606050505050505050505050505050515050505050505050505350505050505050d0d170707070707070707070707070707070707070707070707070707070707070
4040404040404040404042404040404040404092944140404040404044404046476060606060606160606060606063606060606160606060606060606060606050505050505052505050505050505050505050505050505050505050505050d0d170707070707070707070707070707070707070707070707070707070707070
4040404040404040404040404040404044404092a58383838383844040404046476060606060606060606060606060606060606060606060606060606060606050505050505050505050505050505050505450505050505050505050505050d0d170717070707070737070707070707070707070707070707070707070707070
40404040404040404040404040404040404040a2a3a3a3a39693944040404046476060606060606060606060606060606060606060606060626060606160606050505050505050505050505050505050505050505050505050505054505050d0d170707070707070707070707070707070707070707070707070707070707070
4040404040404040404040404040404040404040404040409293944040404046476060606060606060606060616060606060606060606060606060606060606050505050505050505050505050505050505050505050505052505050505050d0d170707070707070707070707070707070707072707070707070707070707070
4040404040404040808140404044404040404040404040409293944040404046476060606062606060606060606060606060606063606060606060606060606050505050505052505050505050505050505050505050505050505050505050d0d170707070707070707070707070707070707070707070707070707070707070
404440404040404090914040404040404040404040404040a2a3a44040404046476060606060606060606060606060606260606060606060606060606060606450505050505050505050505150505050535050505050505050505050505050d0d170707070707070707070707070707070707070707070707070707073707070
4040404040404140404040404040404040404040404240404040404040404046476060606060606060606064606060606060606060606061606060606060606050505050505050505050505050505050505050505050505050505050505050d0d170707070707070707071707070707070707470707070707070707070707070
4040404040404040404040404040404040404040404040404040404040404046476060606060606063606060606060606060606060606060606060606260606050505050505050505050505050505050505050505050515050505052505050d0d170707070707073707070707070707070707070707070707070707070707070
4040404040404040404040404040434440404140404040404041404040404046476060606060606060606060606061606064606060606060606060606060606050505050505050505050505050505050505250505050505050505050505050d0d170707070707070707070707070707070707070707070707070707070707070
c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c4c5c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c350505050505150505054505050505050505050505050505050505050505050d0d170707070727070707070707070707070707070707070707070707070707070
__sfx__
00020000260500500030050300503005030040300403003030030300202d0003a6003a6002f0003960038600386003860038600386002e0002d0002a00028000210001d000190001600013000000000000000000
000300002e3502d3502c3502b3502a0002b3502c3402d3302e3202d00030000380003d00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000300000635007350083500935000000093500834007330063200430000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000600001c750107301260027800238001f8001b8001d900178002490015800148002a900148002190014800168002c90017800299001980020f001a80021f001b80023f0025a00205002b200395003f50000000
001c00002305023050280502805023050230501a0501a0501a0501e0501e0501e0502305023050260502605026050260502605026050240502405022050220502205024050240502405022050240502405024050
001800002d0502d05028050280502d0502d0503705037050370503405034050340503005030050340503405034050340503405034050350503505032050320503205030050300503005032050300503005030050
001800002405024050210502105024050240502b0502b0502b0502805028050280502405024050280502805028050280502805028050290502905026050260502605024050240502405026050240502405024050
001800001805018050150501505018050180501f0501f0501f0501c0501c0501c05018050180501c0501c0501c0501c0501c0501c0501d0501d0501a0501a0501a0501805018050180501a050180501805018050
__music__
00 05060744


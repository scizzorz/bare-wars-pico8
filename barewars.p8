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
  c.yellow, -- 3
  c.green,  -- 4
  c.orange, -- 5
  c.pink,   -- 6
}

-- flags
f = {
  solid=0,
  food=1,
  money=2,
  material=3,
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
  ui_money=50,
  ui_material=51,
  ui_heart=52,
  ui_unit=53,
  ui_sword=54,
  ui_pick=55,

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
  [u.worker]=6,
  [u.warrior]=8,
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
}

-- house costs
hc = {
  [h.wall]=4,
  [h.cave]=10,
  [h.tower]=10,
}

-- house stats
hs = {
  [h.castle] = {tile=t.blank, health=12, cap=32},
  [h.wall] = {tile=t.wall, health=4, speed=0},
  [h.tower] = {tile=t.tower, health=6, cap=64},
  [h.cave] = {tile=t.cave, health=6, cap=256},
}


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
  if x < 128 and x >= 0 and y < 64 and y >= 0 then
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
  if self.tx > 897 then
    self.tx = 897
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
    self:consume()
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
    line(self.x + 4, self.y + 4, path[#path][1] * 8 + 4, path[#path][2] * 8 + 4, c.yellow)
    for coord=1,#path-1 do
      line(path[coord][1] * 8 + 4, path[coord][2] * 8 + 4, path[coord+1][1] * 8 + 4, path[coord+1][2] * 8 + 4, c.yellow)
    end
  end
  if self ~= follow then
    --[[ health bar?
    local col = c.darkpurple
    for i=1,self.max_health do
      pset(self.x + i, self.y, col)
      if i == self.health then
        col = c.darkblue
      end
    end
    ]]
    pset(self.x, self.y, player_colors[self.owner])
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
    self:consume()
    local count = self:act(self.gather * 2)
    use_resource(self.ctx + rel_x, self.cty + rel_y, self.owner, count)
    return true
  end

  return false
end

function _unit:fight_enemy()
  for unit in all(units) do
    if unit.owner ~= self.owner and mdst(unit, self) <= 8 then
      self:consume()
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
      self:consume()
      local count = self:act(self.fight)
      house.health -= count
      return
    end
  end
end


-- house class
-- houses are any building, but I'm not about to type 'building' a hundred times
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

  local cell_n = mget(self.mx, self.my)
  if cell_n <= 75 then
    mset(self.mx, self.my, t.ter_wall)
  elseif cell_n <= 91 then
    mset(self.mx, self.my, t.ter_wall + 16)
  elseif cell_n <= 107 then
    mset(self.mx, self.my, t.ter_wall + 32)
  elseif cell_n <= 123 then
    mset(self.mx, self.my, t.ter_wall + 48)
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
    pset(self.x, self.y, player_colors[self.owner])
  end

  local fill = min(flr(self.action / self.cap * 8), 7)
  if fill > 0 then
    line(self.x, self.y + 7, self.x + fill, self.y + 7, c.orange)
  end

  self.__super.draw(self)
end

function _house:act()
  if self.type == h.tower then
    for unit in all(units) do
      if unit.owner ~= self.owner and mdst(unit, self) <= 16 then
        sfx(a.bullet)
        unit.health -= 1
        self.action -= self.cap
      end
    end
  elseif self.type == h.cave then
    self.action -= self.cap
    local new = hire_unit(u.warrior, self.owner, self.x, self.y + 8)
  elseif self.type == h.castle then
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
  local top = 4 + cam.y
  local left = 4 + cam.x
  local bottom = top + 8 * height
  local right = left + 8 + 8 * width

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
  if player == nil then
    return
  end

  local ui_slot = 1
  for i=1, #order do
    if order[i] == player_num then
      ui_slot = i
      break
    end
  end

  for i=1, #units do
    local top = 6 + cam.y + 3 * i
    local left = 2 + cam.x
    if follow == units[i] then
      rectfill(left - 1, top - 1, left + 1, top + 1, c.darkgrey)
    end
    pset(left, top, player_colors[units[i].owner])
  end

  for i=1, #houses do
    local top = 6 + cam.y + 3 * i
    local left = 5 + cam.x
    if follow == houses[i] then
      rectfill(left - 1, top - 1, left + 1, top + 1, c.darkgrey)
    end
    pset(left, top, player_colors[houses[i].owner])
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
  spr(t.ui_food, ui_left + 3, top - 1)
  print(player.food, ui_left + 10, top, c.white)

  spr(t.ui_money, ui_left + 23, top - 1)
  print(player.money, ui_left + 30, top, c.white)

  spr(t.ui_material, ui_left + 44, top - 1)
  print(player.materials, ui_left + 51, top, c.white)

  races[player.race]()
  spr(t.ui_unit, ui_left + 65, top - 1)
  print(player.units, ui_left + 73, top, c.white)

  -- reset palette swaps
  pal()
  palt(c.red, true)
  palt(c.black, false)

  -- draw focused map info
  local curs_x = flr(curs.x / 8)
  local curs_y = flr(curs.y / 8)
  local cell_n = mget(curs_x, curs_y)
  local res = get_resources(curs_x, curs_y)

  -- draw map resource info
  if fget(cell_n, f.food) then
    spr(t.ui_food, ui_right + 4, top + 6)
  elseif fget(cell_n, f.material) then
    spr(t.ui_material, ui_right + 4, top + 6)
  elseif fget(cell_n, f.money) then
    spr(t.ui_money, ui_right + 4, top + 6)
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
    local x = flr(rnd(120)) + 4
    local y = flr(rnd(56)) + 4
    local worker = _unit(p, x * 8, y * 8 + 16, races[race])
    local castle = _house(p, x * 8 + 4, y * 8 + 4, h.castle)

    local ter = flr(x / 32)
    -- flip them because i drew the map wrong
    if ter == 1 then
      ter = 2
    elseif ter == 2 then
      ter = 1
    end

    -- draw castle
    mset(x, y, t.ter_castle1 + ter * 16)
    mset(x + 1, y, t.ter_castle2 + ter * 16)
    mset(x, y + 1, t.ter_castle3 + ter * 16)
    mset(x + 1, y + 1, t.ter_castle4 + ter * 16)

    add(units, worker)
    add(houses, castle)
    add(order, p)
    add(players, {
      castle_x=x,
      castle_y=y,
      race=race,
      money=0,
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

-- move to the next player, or start the play state
function next_turn()
  turn_idx += 1

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

  for p in all(order) do
    if players[p].units == 0 or not players[p].castle_alive then
      del(order, p)
      for unit in all(units) do
        if unit.owner == p then
          del(units, unit)
        end
      end

      for house in all(houses) do
        if house.owner == p then
          del(houses, house)
        end
      end
    end
  end

  if #order == 1 then
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
  if x < 0 or y < 0 or x >= 1024 or y >= 64 then
    return nil
  end

  local cell = mget(x, y)
  local is_resource = fget(cell, f.food) or fget(cell, f.money) or fget(cell, f.material)
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
  x = x or player.castle_x * 8
  y = y or (player.castle_y * 8 + 16)

  local new = _unit(owner, x, y, races[player.race], unit_type)

  add(units, new)
  change_state(prev_state)
  return new
end

-- build a new house
function build_house(house_type, owner, x, y)
  local player = players[owner]
  local new = _house(owner, x * 8, y * 8, house_type)

  add(houses, new)
  change_state(prev_state)
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
        menu:add("build", make_build_menu)
      end

    elseif follow.is_house then
      if follow.type == h.castle then
        menu:add("hire", make_hire_menu)
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
  if not check_cell(curs_x, curs_y - 1) then
    menu:add("can't build here", function() end, false)
    return
  end

  menu:add(hc[h.wall] .. " wall", function() build_house(h.wall, cur_player, curs_x, curs_y - 1); player.materials -= hc[h.wall] end, player.materials >= hc[h.wall])
  menu:add(hc[h.cave] .. " cave", function() build_house(h.cave, cur_player, curs_x, curs_y - 1); player.materials -= hc[h.cave] end, player.materials >= hc[h.cave])
  menu:add(hc[h.tower] .. " tower", function() build_house(h.tower, cur_player, curs_x, curs_y - 1); player.materials -= hc[h.tower] end, player.materials >= hc[h.tower])
end

function make_hire_menu()
  local player = players[cur_player]
  menu:clear()
  menu:add(uc[u.worker] .. " worker", function() hire_unit(u.worker); player.money -= uc[u.worker] end, player.money >= uc[u.worker])
  menu:add(uc[u.warrior] .. " warrior", function() hire_unit(u.warrior); player.money -= uc[u.warrior] end, player.money >= uc[u.warrior])
  menu.back = make_base_menu
end

function use_resource(x, y, owner, amt)
  local res = get_resources(x, y)
  amt = min(amt or 1, res)

  if amt <= 0 then
    return
  end

  local new = res - amt
  resources[coord_key(x, y)] = new

  local cell = mget(x, y)
  local player = players[owner]

  if fget(cell, f.food) then
    player.food += amt
  elseif fget(cell, f.money) then
    player.money += amt
  elseif fget(cell, f.material) then
    player.materials += amt
  end

  if new == 0 then
    mset(x, y, flr(cell / 16) * 16)
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
      if cur_player then
        jump_to_next_owned()
      else
        jump_to_next_unit()
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
    if dist > 128 then
      curs.palette = pal_bad_curs
    else
      curs.palette = pal_trans_red
    end

    if not check_cell(flr(curs.x / 8), flr(curs.y / 8)) then
      curs.palette = pal_bad_curs
    end

    if btnp(b.x) then
      if curs.palette == pal_trans_red then
        follow:set_dest(curs.x, curs.y)
        curs.palette = pal_trans_red
        follow = nil
        change_state("command")
        sfx(a.ok)
      else
        sfx(a.no)
      end
    end

    if btnp(b.o) then
      change_state("command")
    end
  end

  if state == s.play then
    for unit in all(units) do
      unit:update()
      if unit.health <= 0 then
        del(units, unit)
      end
    end

    for house in all(houses) do
      house:update()
      if house.health <= 0 then
        del(houses, house)

        -- reset terrain to neutral
        local cell_x = flr(house.x / 8)
        local cell_y = flr(house.y / 8)
        local cell_n = mget(cell_x, cell_y)
        mset(cell_x, cell_y, flr(cell_n / 16) * 16)
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
    if curs.x > 1016 then
      curs.x = 1016
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
      print("victory", 50, 48, c.lightgrey)

      local off_x = 64 - num_players * 8 - 10
      for i=1, num_players do
        local col = c.indigo
        if i == order[1] then
          col = player_colors[i]
        end
        print(i, i * 16 + off_x, 64, col)
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
    map(0, 0, 0, 0, 128, 64)

    for p in all(order) do
      local player = players[p]
      pset(player.castle_x * 8 + 1, player.castle_y * 8 + 5, player_colors[p])
      pset(player.castle_x * 8 + 2, player.castle_y * 8 + 4, player_colors[p])
      pset(player.castle_x * 8 + 2, player.castle_y * 8 + 5, player_colors[p])
      pset(player.castle_x * 8 + 2, player.castle_y * 8 + 6, player_colors[p])
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
00000000666000000000000006111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000616666666666666606111111007700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000666111111111111106111111007770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000061111111111111106111111007777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000061111111111111106111111007770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000061111111111111106111111007700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000061111111111111106111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000061111111111111106111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000888888888888888888888888444444448888888888888888888888880000000000000000000000000000000000000000000000000000000000000000
00000000888878888889988884844488448484448944498888886688886d58880000000000000000000000000000000000000000000000000000000000000000
00000000888f7788889a7988884444884888e844840404888846d688888555880000000000000000000000000000000000000000000000000000000000000000
000000008444f888889aa9888499448844888444844044888845688888445d880000000000000000000000000000000000000000000000000000000000000000
0000000084448888889aa98884994888444844448444448884144888844486880000000000000000000000000000000000000000000000000000000000000000
00000000844488888889988888448888444444448499948884488888844888880000000000000000000000000000000000000000000000000000000000000000
00000000888888888888888888888888444444448888888888888888888888880000000000000000000000000000000000000000000000000000000000000000
00000000888888888888888888888888444444448888888888888888888888880000000000000000000000000000000000000000000000000000000000000000
333333333333333333333333333333333333333333333333000000000000000033335535535533333335666666665333bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
3333333333bb333333bbbb3333344333333bb33333333333000000000000000033335555555533333335d6dd6dd65333bbbbbbbbbbbbbbbbbbbbbbbbbbb333bb
3333333333b333b33b2b2bb33344443333bbbb3333333333000000000000000033335666666533333335666666665333bbbbbbbbbbbbbbbbbbbbbbbb33338333
3333333333333bb33bbbb2b33399993333bbbb3333333333000000000000000033335dd6dd6533333355dd6dd6dd5533bbbbbbbbbbbb3333bbb3333b38388383
333333333b3333333b2bbbb3334444333bbbbbb333333333000000000000000033e45661166533333356666446666533bbbbbbbbbb3334433333003389898883
333333333bb33b3333bb2b3333999933333443333333333300000000000000003ee45d1ff1d53333335d6d44446dd533bbbbbbbb333440444444000899999883
3333333333333bb3333bb333334444333334433333333333000000000000000033e4561ff16533333556664444666553bbb333333444400044445029aaa99983
333333333333333333333333333333333333333333333333000000000000000033355d1111655333556dd64444dd6d55bbb34445444444044444459aaaaaa983
ffffffffffffffffffffffffffffffffffffffffffffffff0000000000000000ffff55f55f55fffffff5666666665fffbbb3400444444444444459a7777aa983
ffffffffff9ff9ffffbb8fffffffffffff3333ffffffffff0000000000000000ffff55555555fffffff5d6dd6dd65fffbbb340444444444455559a77777aa933
fffffffff9f9ff9fff8bbf8ffff55ffff333333fffffffff0000000000000000ffff56666665fffffff5666666665fffbbb34444444444457667a77777aa993b
fffffffffffff9fffffbffb8ff7ee7fff333333fffffffff0000000000000000ffff5dd6dd65ffffff55dd6dd6dd55ffbb3344444444444deeee77777aaa993b
fffffffffff9fffffbbbfbbfff7ee7ffff3333ffffffffff0000000000000000ffe456611665ffffff566664466665ffb33444444444444deeee6aaaaaa9933b
ffffffffff9ff9fff8fbbbffff7ee7fffff55fffffffffff0000000000000000fee45d1ff1d5ffffff5d6d44446dd5ff3344444444444445deed5444999933bb
fffffffffff9ff9fffffbfffff7777fffff55fffffffffff0000000000000000ffe4561ff165fffff55666444466655f34444444444444447ee7444433333bbb
ffffffffffffffffffffffffffffffffffffffffffffffff0000000000000000fff55d1111655fff556dd64444dd6d553444444444444444566544443bbbbbbb
dddddddddddddddddddddddddddddddddddddddddddddddd0000000000000000dddd55d55d55ddddddd5666666665ddd4444444444444444444444443bbbbbbb
dddddddddddd5ddddddccddddddccddddddddddddddddddd0000000000000000dddd55555555ddddddd5d6dd6dd65ddd4444444444444444444444443bbbbbbb
dddddddddd5dddddddccccddddc7ccddddd5dddddddddddd0000000000000000dddd56666665ddddddd5666666665ddd4444444444444444444444333bbbbbbb
ddddddddddddd5ddddcc1ccdddcc7cdddd555ddddddddddd0000000000000000dddd5dd6dd65dddddd55dd6dd6dd55dd44444444444444444444443bbbbbbbbb
ddddddddd5dddddddcc111cddd7cc7dddd5555dddddddddd0000000000000000dde456611665dddddd566664466665dd44444444444444444444433bbbbbbbbb
dddddddddddd5ddddcc11cddddc7ccddd555555ddddddddd0000000000000000dee45d1ff1d5dddddd5d6d44446dd5dd44444444444444444444433bbbbbbbbb
dddddddddd5ddd5dddccccdddddc7dddd555555ddddddddd0000000000000000dde4561ff165ddddd55666444466655d44444444444444444444443bbbbbbbbb
dddddddddddddddddddddddddddddddddddddddddddddddd0000000000000000ddd55d1111655ddd556dd64444dd6d5544444444444444444444443bbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb0000000000000000bbbb55b55b55bbbbbbb5666666665bbb444444444444444444444443bbbbbbbb
bbbbbbbbb6bbbb6bbbb9bbbbbb8eeebbbbbebebbbbbbbbbb0000000000000000bbbb55555555bbbbbbb5d6dd6dd65bbb444444444444444444444443bbbbbbbb
bbbbbbbbbbbb6bbbb9b3b9bbbb887ebbbbeeeebbbbbbbbbb0000000000000000bbbb56666665bbbbbbb5666666665bbb4444444444444444444444433bbbbbbb
bbbbbbbbbbbbbbbbbb3bb3bbbb888ebbbeeeeeebbbbbbbbb0000000000000000bbbb5dd6dd65bbbbbb55dd6dd6dd55bb4444444444444444444444443bbbbbbb
bbbbbbbbbbb6bbbbbb3bb3bbbbd888bbbbeeeebbbbbbbbbb0000000000000000bbe456611665bbbbbb566664466665bb4444444444444444444444443bbbbbbb
bbbbbbbbbbbbbb6bbb3b3bbbbbbd8bbbbbb44bbbbbbbbbbb0000000000000000bee45d1ff1d5bbbbbb5d6d44446dd5bb44444444444444444444444433bbbbbb
bbbbbbbbb6bbbbbbbb3b3bbbbbbbbbbbbbb44bbbbbbbbbbb0000000000000000bbe4561ff165bbbbb55666444466655b44444444444444444444444443bbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb0000000000000000bbb55d1111655bbb556dd64444dd6d5544444444444444444444444443bbbbbb
04040404040404042404040404040404040404040404040404040404040404040606060606060606060606060606060606060606060606060606060606060606
05050505050505050505050505050505050505050505050505050505050505050707070707070707070707070707070707070707070707070707071707070707
04040404040404040404040404040404040404040404040404040404040404040606060606160606060606060606060606060616060606060606060606060606
05050505050505050505050505050505050505050505050505050505050505050707070707070707070707070707070707070707070707370707071707070707
04040404040404040404040404040404040404040404040424040404044404040606060606060606060606064606060606060606060606060606062606060606
05050505050505050505050505050505050505050505050505050505050505050707070707070707070707070707072707070707071707070707070707070707
04040404040404040404040404040404040404040404040404040404040404040606060606060606060606060606060636060606060606060606060606060606
05050505050505050505050505054505050505050505050505050545050505050707070707070707070707070707170747070707070707070707070707070707
04040404040404044404040404040404040404440404040404040404040404040606060606060606260606060606060606060606060606160606060606063606
05050505150505050505050505050505052505050505050505050505050505050707070707070707070707070707070707070707070707070707070707070707
04040404040414040404040404041404040404040404040404040404041404040606060606060606060606060606060606060606060606060606060606060606
05050505050505050505050505050505050505050505050505050505050505050707070707070717070707070707070707070707070707070707070707070707
04040404040404040404040404040404040404040404040404040404040404040606060606060606060606160606060606460606060606060606060606060606
05050505050505050535050515050505050505051505050505050505050505050707070707070707070707070707070707070707070707070707070707070707
04040404040404040404340404040404040404040404040404040404040404040606060606060606060606060606060606060606060606060606060606060606
05050505050505050505050505050505050505050505050505050505050505150707070707070737070707070707070707070707070727070707070707070707
04040404040404040404040404040404040404040414040404040404040404040606060606060606060606060606060606060606060606060606060606060606
05050505052505050505050505050505050505050505050505050505050505050707070707070707070707070707070707070707070707070707070707070707
04040404040404440404040404040404040404040404040444040404040404040606060606060606060606060606060606060606060606060606060606060606
05050505050505050505050525050505050505050505053505050505050505050707070707070707070707070707070707070707070707070707070707070707
04040404040404040404040404040404040404040404040404040404040404040606060606060606060606060606060606060606060606060606060606060606
05050505050505050505050505050505050505050505050505054505050505050707070707070707070707070707070707070707070707070707070707070707
04040404040404040404040404040404040404040404040404040404040404040606060606060606060646060606060606060606060606060606060606260606
05050505050545050505050505050505450505050505050505050505050505050707070707070707070707070707070717070707070707070707070707070707
04040404040404040404040404040404042404040404040404043404040404040606060606060606060606060606060606060606060606060606060606060606
05050505050505050505050505050505350505050515050505050505050505050707070707070707070707070707070707070707070707070707073707070707
04040434040404040404040404040404040444040404040404040404040404140606060606060606060606060616060646060606060606060606060606060606
05050505050505050505051505050505050505050505050505050505050505250707070707070707070707070707270747070707070707070707070707070707
04040404040404040404140404040404040404040404440404040404040404040606060606060606060616060606060606060606060606360606060606060606
05050505250505050505050505050505050505050505050505053505050505050707070707070707070707070707070707070707070707070707070707070707
04040404040404040404040404040404040404040404040404040404040404040606060606060606060606060606060606060606060606060606060606060616
05050505050505450505050505050505052505050505050505050505050505050707070737070707070707070707070707070707070707070707070707070707
04040404040404040404040404040404040404040404040404040404040404040606060616060606060606060606060606061606060606060606060606060606
05050505050505050505050505050505050505050505050505050505050545050707070707070717070707070707070707070707071707070707070707070707
04040404040404040404040404040404040404040404040404040404040404040606060606060606060606460606060606060606060606060606260606060606
05050505050505050505050505350505050505050505050505050505050505050707070707070707070707070707070707070707070707070707070707070707
04040404040404042404040404040404041404040404040404040404044404040606060606060606060606060606063606060606060606060606060606060606
05050505050505150505050505050505050505450505050515050505050505050707070707070707070707072707070707070707072707070707070707070707
04040404040404040404040404040404040434040404040404043404040404040606060606060626060606060606060606060606060616060606060606360646
05050505050505050505050505050505050505050505050505050505250505050707070707070707070707070707070707070707070707070707070707070707
04040404040404040404040404040404040404040404040404040404140404040606060606060606060606060606060606060606060606060606060606060606
05050505050505050505050505050505050505050505050505050505050505050707070707070707070707070707070707070707070707074707070707070707
04040404040404040404040404040404040404040404040404040404040404040606060606060606060606060606060606060606060606060606060606060606
05050505050505050505050505150505050505050505053505050505050505150707070707070717070707070707070707070707070707070707070707070707
04440404040404040404040404040404040404042404040404040404040404040606060606060606060606060606060606060606060606060606060606060606
05050505050525050505050505050505050505050505050505050505050505050707070707070707070707070707070707070707070707070707070707070707
04040404040414040404340404040404040404040404040404040404040404040606060606060606060606061606060606060606060606060606060606060606
05050505050505050505050505050505054505050505050505050505050505050707070707074707070707070707070717070707070707070707070707070707
04040404040404040404040404040404040404040404040404040404044404040606060606260606060606060606060606060606360606060606060606060606
05050505050505050505050505050505050505050505050505050545050505050707070707070707072707070707070707073707070707070707070707070707
04040404040404040404040404041404040404040404040404040404040404040606060606060606060606060606060606060606060606060616060606060606
05050505050505050505050505050505050505050505050525050505050505050707070707070707070707070707070707070707070707070707072707070707
04040404040404040404040404040404040404040404040404040404040404040606060606060606060606060606060606060606060606060606060636060606
05050505050525050505050505050505050505050505050505050505050505050707070707070707070707070707070707070707070707070707070707070707
04040404040404042404040404040404040404040404041404040404040404040606060606060606064606060606060606060606060606060646060606060606
05050505050505050505051505050505350505050505050505050505050505050707070707170707070707070707070707070707070707070717070707070707
04040404040404040404040404040404040404040404040404040404040404040606060606061606060606060636060606061606060606060606060606060606
05050505050505050505050505050505050505050505050505050505050505050707070707070707070707070707070707070707070707070707073707070707
04040404040404040404040404040404040404040404040404040404043404040606060606060606060606060606060606060606060606060606060606060606
05050505050505050505050505050505050505050505150505050525050505050707070707070707370707070707070707070707070707070717070707070707
04040404040404040404040404040404040404040404040404040404040404040606060606060606060606060606060606060606060606260606061606060606
05050505050505050505050505050505052505050505050505050505050505050707070707070707070707070707070707070707070707070707070707070707
04040404040404040404040404040404040404040404040404040404040404040606060606060606060606160606060606060606060606060606060606060606
05050505051505050545050505050505050505050505050505050505050505050707070707070707070707070707070707070707070707070707070707070707
__label__
00666005005550000000000700777077700000000099007770000000000004044407770000000000009444900770000000000000000000000000000000000000
0688760505cc7500000000f7700070707000000009a7907070000000000000444407070000000000004040400070000000000000000000000000000000000000
0688860505ccc5000000444f007770707000000009aa907070000000000004994407070000000000004404400070000000000000000000000000000000000000
0688860505ccc50000004440007000707000000009aa907070000000000004994007070000000000004444400070000000000000000000000000000000000000
00666050005550000000444000777077700000000099007770000000000000440007770000000000004999400777000000000000000000000000000000000000
00000500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00005000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
5555555555555555500000808000808000808000000000660000006d50006d500000000000000000000000000000000000000000000000000000000000000000
333333333333333335000888e80888e80888e800000046d600000005550005550000000000000000000000000000000000000000000000000000000000000000
338338333333333333500088800088800088800000004560000000445d00445d0000000000000000000000000000000000000000000000000000000000000000
33333333333333333335000800000800000800000004144000000444060444060000000000000000000000000000000000000000000000000000000000000000
35553333333333333333500000000000000000000004400000000440000440000000000000000000000000000000000000000000000000000000000000000005
35c53833333333333333350000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000053
35553333333333333333335555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555533
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33333c33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33333c33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333bbbb3333333333333
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333b2b2bb333333333333
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333bbbb2b333333333333
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333b2bbbb333333333333
333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333bb2b3333333333333
3333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333bb33333333333333
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33333333443333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33333334444333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33333339999333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33333334444333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33333339999333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33333334444333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
333333333333333333333333333333333333333333333333333333333333333bbbb3333333333333333333333333333333333333333333333333333333333333
33333333333333333333333333333333333333333333333333333333333333b2b2bb333333333333333333333333333333333333333333333333333333333333
33333333333333333333333333333333333333333333333333333333333333bbbb2b333333333333333333333333333333333333333333333333333333333333
33333333333333333333333333333333333333333333333333333333333333b2bbbb333333333333333333333333333333333333333333333333333333333333
333333333333333333333333333333333333333333333333333333333333333bb2b3333333333333333333333333333333333333333333333333333333333333
3333333333333333333333333333333333333333333333333333333333333333bb33333333333333333333333333333333333333333333333333333333333333
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33333333333333333333333333333333333333333333333333333c33333333333553553553333c33333333333333333333333333333333333333333333333333
333333333333333333333333333333333333333333333333333333335553333335555555533333553355333333333333bb333333333333333333333333333333
33333333333333333333333333333333333333333333333333333335666533333566666653333356556533333333333bbbb33333333333333333333333333333
333333333333333333333333333333333333333333333333333333356dd5333335dd6dd65333335d6dd533333333333bbbb33333333333333333333333333333
33333333333333333333333333333333333333333333333333333356d005333c4566116653333335d6533333333333bbbbbb3333333333333333333333333333
3333333333333333333333333333333333333333333333333333335d000533cc45d1ff1d533333356d5333333333333344333333333333333333333333333333
3333333333333333333333333333333333333333333333333333335d0015333c4561ff165333335dd6d533333333333344333333333333333333333333333333
333333333333333333333333333333333333333333333333333333333333333355d1111655333333333333333333333333333333333333333333333333333333
33333333333333333333333333333333333333333333333333333333333333335666666665333333333333333333333333333333333333333333333333333333
33333333333333333333333333333333333333333333333333333333333333335d6dd6dd65333333333333333333333333333333333333333333333333333333
33333333333333333333333333333333333333333333333333333333333333335666666665333333333333333333333333333333333333333333333333333333
33333333333333333333333333333333333333333333333333333333333333355dd6dd6dd5533333333333333333333333333333333333333333333333333333
33333333333333333333333333333333333333333333333333333333333333356666446666533333333333333333333333333333333333333333333333333333
3333333333333333333333333333333333333333333333333333333333333335d6d44446dd533333333333333333333333333333333333333333333333333333
33333333333333333333333333333333333333333333333333333333333333556664444666553333333333333333333333333333333333333333333333333333
3333333333333333333333333333333333333333333333333333333333333556dd64444dd6d55333333333333333333333333333333333333333333333333333
3333333333333333333333333333333333333333333333333333333333333cc33cc3333333333333333333333333333333333333333333333333333333333333
33333333333333333333333bb3333333333333333333333333333333333333394493c33333333333333333333333333333333333333333333333333333333333
33333333333333333333333b333b3333333333333333333333333333333333340403c33333333333333333333333333333333333333333333333333333333333
33333333333333333333333333bb333333333333333333333333333333333c444044333333333333333333333333333333333333333333333333333333333333
3333333333333333333333b33333333333333333333333333333333333333c344443333333333333333333333333333333333333333333333333333333333333
3333333333333333333333bb33b33333333333333333333333333333333333349943c33333333333333333333333333333333333333333333333333333333333
33333333333333333333333333bb3333333333333333333333333333333333343343c33333333333333333333333333333333333333333333333333333333333
3333333333333333333333333333333333333333333333333333333333333cc33cc3333333333333333333333333333333333333333333333333333333333333
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
333333333333333333333333333333333333333333333333333333333333333bb3333333333333333333333333333333333333333333333bb333333333333333
333333333333333333333333333333333333333333333333333333333333333b333b3333333333333333333333333333333333333333333b333b333333333333
333333333333333333333333333333333333333333333333333333333333333333bb3333333333333333333333333333333333333333333333bb333333333333
33333333333333333333333333333333333333333333333333333333333333b33333333333333333333333333333333333333333333333b33333333333333333
33333333333333333333333333333333333333333333333333333333333333bb33b3333333333333333333333333333333333333333333bb33b3333333333333
333333333333333333333333333333333333333333333333333333333333333333bb3333333333333333333333333333333333333333333333bb333333333333
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33333833333333333553553553333833333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33333333555333333555555553333355335533333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33333335666533333566666653333356556533333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
333333356dd5333335dd6dd65333335d6dd533333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33333356d00533384566116653333335d65333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
3333335d0005338845d1ff1d533333356d5333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
3333335d001533384561ff165333335dd6d533333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
333333333333333355d1111655333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33333333333333335666666665333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33333333333333335d6dd6dd6533333333333333333333333333333333333333bb33333333333333333333333333333bb3333333333333333333333333333333
333333333333333356666666653333333333333333333333333333333333333bbbb3333333333333333333333333333b333b3333333333333333333333333333
33333333333333355dd6dd6dd55333333333333333333333333333333333333bbbb3333333333333333333333333333333bb3333333333333333333333333333
33333333333333356666446666533333333333333333333333333333333333bbbbbb33333333333333333333333333b333333333333333333333333333333333
3333333333333335d6d44446dd53333333333333333333333333333333333333443333333333333333333333333333bb33b33333333333333333333333333333
33333333333333556664444666553333333333333333333333333333333333334433333333333333333333333333333333bb3333333333333333333333333333
3333333333333556dd64444dd6d55333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33333333333338333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33333333333333394493333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33333333333333340403333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33333333333333444044333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33333333333333344443333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33333333333333349943333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33333333333333343343333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
3333333333333333333333333333333bb33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
3333333333333333333333333333333b333b33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
3333333333333333333333333333333333bb33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
333333333333333333333333333333b3333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
333333333333333333333333333333bb33b333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
3333333333333333333333333333333333bb33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
333333333333333333333333333333333333333333333333333333333333333bbbb3333333333333333333333333333333333333333333333333333333333333
33333333333333333333333333333333333333333333333333333333333333b2b2bb333333333333333333333333333333333333333333333333333333333333
33333333333333333333333333333333333333333333333333333333333333bbbb2b333333333333333333333333333333333333333333333333333333333333

__gff__
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003050900000305090100001111111100000000000003050901000011111111000000000000030509010000111111110000000000000305090100001111111100000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
4040404040404040404040404040404040404040404040404040404040404040606060606260606060606060606060606060606360606060606060606060606050505050505050505050505050505050505050505050505050505050505050507070707070707070707070707070707070707070707070707070707070707070
4040404040404040404040404040404040404040404040404040404040404040606060606060606060606060606060626060606060606060606060606060646050505050505050505050505050505050505050505050505050505050505050507070707070707070707070707070707070707070707070707070707070707070
4040404040404040404041404040414040404040434040404040404040424040606060606060606060606460606060606060606060606160606060606060606050505050505050505050505050505050505050505050505050505050505050507070707070707070707070707070707070707070707070707070707070707070
4040404040404040404040404040404040404040404040404440404040404040606060606060606360606060606060606060606060606060606060626060606050505050505050505050505050505450505050505050505050505054505050507070707070707070707070707070707070707070707070707070707070707070
4040404140404040414040404040404040404040404040404040404040404040606060606060606060606060606160606460606060606060606060606060606050505050515050505050505050505050505250505050505050505050505050507070707070737070707070707470707070707270707070707070707070707070
4040404040404040404040404040404040404040404140404040404040404041606060606060606060606160606060606060606060606063606060606060606050505050505050505050505050505050505050505050505050505050505050507070707070707070707070707070707070707070707070707070737070707070
4040404040404040404040404040404040404040404040404040404040404040606060606060606060606060606060606060606060606060606060606060606150505050505050505053505051505050505050505150505050505050505050507070707070707070707170707070707070707070707070707071707070707070
4040404040414040404440404041404040404040404040404040404040404040606060606160606060606060606060606060616060606060606060606060606050505050505050505050505050505050505050505050505050505050505050517070707070707070707070707070707070707070707070707070707070707070
4040404040404040404040404040404040404040404040404040414040404040606060606060606060606064606060606060606060606060606062606060606050505050505250505050505050505050505050505050505050505050505050507070707070707072707070707070707070707070707070707070707070707070
4040404040404040404040404040404042404040404040444040404040404040606060606060606060606060606060636060606060606060606060606060606050505050505050505050505052505050505050505050505350505050505050507070707070707070707070707070707070737070707070707070707070707070
4040404340404040404040404040404040404040404040404040404040404040606060606060606260606060606060606060606060606160606060606063606450505050505050505050505050505050505050505050505050505450505050507070707070707070707070707070707071707070707070707070707070707070
4040404040404040404042404040404040404040414040404040404040404040606060606060606060606060606060606060606060606060606060606060606050505050505054505050505050505050545050505050505050505050505050507070707070707070707070707070707070707070707072707070707070707070
4040404040404040404040404040444040404040404043404040404140404040606060606060606060606160606060606460606060606060606060606060606050505050505050505050505050505050535050505051505050505050505050507070707073707070707074707070707070707070707070707070707070707070
4040404040404040404040404040404040404040404040404040404040404040606060606060606060606060606060606060606060606060606060606060606050505050505050505050505150505050505050505050505050505050505050527070707070707070707070707070707070707070707070707070747070707070
4040404040414040404040404040404040404040404040404040404040404040606060606060606060606060606060606060606060606060606060606060606050505050525050505050505050505050505050505050505050505350505050507070707070707071707070707070707070747070707070707070707070707070
4040404040404040404041404040404041404040404040404040404040404040606060606060606060606060606060606060606060606060606060606060606050505050505050545050505050505050505250505050505050505050505050507070707070707070707070707072707070707070707070707070707070707070
4040404040404040404040404040404040404040404044404040404040404040606060606060606060606060606060606060606060606060606060606060606050505050505050505050505050505050505050505050505050505050505054507070707070707070707070707070707070707070707070707070707070707070
4040404040404040404040404040404040404040404040404040404040404040606060606060606060646060606060606060606060606060606060606260606050505050505050505050505050535050505050505050505050505050505050507070707070707070707070707070707070707170707070707070707070707070
4040404340404040404040404040404040404040404040404040424040404041606060606060606060606060606060606060606060606060606060606060606050505050505050515050505050505050505050545050505051505050505050507070707070707070707070707170707070707070707070707070707070707070
4040404040404040404044404040414040404043404040404040404040404040606060606060606060606060606060606060606060606060606061606060606050505050505050505050505050505050505050505050505050505050525050507070707070727070707070707070707070707070707070737070707070707070
4040404040404040404040404040404040404040404040404040404040404040606060606060606060606060606060606060606060606060606060606063606050505050505050505050505050505050505050505050505050505050505050507070707070707070707070707070707470707070707070707070707070707070
4040404040404140404040404040404040404040404040404040404040404040606060606060606060606460606060606060606060606060606064606060606050505050505050505050505050515050505050505050505350505050505050517070707070707070707070707070707070707070707070707070707070707070
4040404040404040404042404040404040404040404140404040404044404040606060606060606160606060606063606060606160606060606060606060606050505050505052505050505050505050505050505050505050505050505050507070707070707070707070707070707070707070707070707070707070707070
4040404040404040404040404040404044404040404040404040404040404040606060606060606060606060606060606060606060606060606060606060606050505050505050505050505050505050505450505050505050505050505050507070717070707070737070707070707070707070707070707070707070707070
4040404040404040404040404040404040404040404040404040404040404040606060606060606060606060606060606060606060606060626060606160606050505050505050505050505050505050505050505050505050505054505050507070707070707070707070707070707070707070707070707070707070707070
4040404040404040404040404040404040404040404040404040404040404040606060606060606060606060616060606060606060606060606060606060606050505050505050505050505050505050505050505050505052505050505050507070707070707070707070707070707070707072707070707070707070707070
4040404040404040404040404040404040404040404040404040404040404040606060606062606060606060606060606060606063606060606060606060606050505050505052505050505050505050505050505050505050505050505050507070707070707070707070707070707070707070707070707070707070707070
4040404040404040404040404040404040404040404040404040404040404040606060606060606060606060606060606260606060606060606060606060606450505050505050505050505150505050535050505050505050505050505050507070707070707070707070707070707070707070707070707070707073707070
4040404040404140404040404040404040404040404240404040404040404040606060606060606060606064606060606060606060606061606060606060606050505050505050505050505050505050505050505050505050505050505050507070707070707070707071707070707070707470707070707070707070707070
4040404040404040404040404040404040404040404040404040404040404040606060606060606063606060606060606060606060606060606060606260606050505050505050505050505050505050505050505050515050505052505050507070707070707073707070707070707070707070707070707070707070707070
4040404040404040404040404040434040404140404040404041404040404040606060606060606060606060606061606064606060606060606060606060606050505050505050505050505050505050505250505050505050505050505050507070707070707070707070707070707070707070707070707070707070707070
4040404040404040404040404040404040404040404040404040404040404040606060606060606060606061606060606060606060606060636060606060606050505050505150505054505050505050505050505050505050505050505050507070707070727070707070707070707070707070707070707070707070707070
__sfx__
00020000260500500030050300503005030040300403003030030300202d0003a6003a6002f0003960038600386003860038600386002e0002d0002a00028000210001d000190001600013000000000000000000
000300002e3502d3502c3502b3502a0002b3502c3402d3302e3202d00030000380003d00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000300000635007350083500935000000093500834007330063200430000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000600001c750107301260027800238001f8001b8001d900178002490015800148002a900148002190014800168002c90017800299001980020f001a80021f001b80023f0025a00205002b200395003f50000000

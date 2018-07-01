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
}

-- tiles
t = {
  curs1=1,
  curs2=2,
  curs3=3,
  curs4=4,
  walk1=5,
  walk2=6,
  walk3=7,
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
}

-- sfx
a = {
  ping=0,
  ok=1,
  no=2,
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

function pal_bad_curs()
  palt(c.red, true)
  palt(c.black, false)
  pal(c.black, c.red)
  pal(c.darkgrey, c.pink)
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

races = {pal_race1, pal_race2, pal_race3}

-- animations
local anim_stand = t.walk1
local anim_walk = _anim({t.walk1, t.walk2, t.walk1, t.walk3}, 10)
local anim_curs = _anim({t.curs1, t.curs2, t.curs3, t.curs4}, 10)

-- unit class
local _unit = _sprite:extend()

function _unit:init(owner, x, y, palette)
  self.__super.init(self, anim_stand, x, y, palette)
  self.health = 3
  self.max_health = 4
  self.owner = owner
  self.tx = x
  self.ty = y
  self.ctx = flr(x / 8)
  self.cty = flr(y / 8)
  self.path = nil
  self.step = 0
end

function _unit:consume()
  local owner = players[self.owner]

  self.step += 1
  if self.step == 8 then
    self.step = 0
    if owner.food > 0 then
      owner.food -= 1
    else
      self.health -= 1
    end
  end
end

function _unit:update()
  self.__super.update(self)

  local path = self.path
  if path and #path > 0 then
    local to_coord = path[#path]

    -- pop current waypoint if we're at it
    if self.x == to_coord[1] * 8 and self.y == to_coord[2] * 8 then
      pop(path)
      if #path == 0 then
        self.tile = anim_stand
        self.path = nil
      end
    end

    if self.path and (self.x ~= self.tx  or self.y ~= self.ty) then
      self:consume()
    end

    -- move to path
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

  if self.x == self.tx and self.y == self.ty and get_resources(self.ctx, self.cty) > 0 then
    self:consume()
    use_resource(self.ctx, self.cty, self.owner)
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

  self.__super.draw(self)
end

function _unit:set_dest(tx, ty)
  self.tx = tx
  self.ty = ty
  self.ctx = flr(tx / 8)
  self.cty = flr(ty / 8)
  self.path = self:get_path()
  if #self.path > 0 then
    printh("setting animation")
    self.tile = anim_walk:copy()
  else
    self.path = nil
  end
end

function _unit:get_path()
  local cur_x = flr(self.x / 8)
  local cur_y = flr(self.y / 8)
  return get_path(cur_x, cur_y, self.ctx, self.cty)
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

    print(self.labels[y], left + 10, top - 3 + 8 * y, col)
  end
end

-- meter class
local _meter = object:extend()

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
local _info = object:extend()

function _info:init()
  self.x = 0
  self.y = 0
end

function _info:draw()
  palt(c.black, false)
  palt(c.red, true)

  local player = players[cur_player]
  local player_colors = {c.red, c.blue, c.yellow, c.green, c.darkgrey, c.darkgrey, c.darkgrey, c.darkgrey}
  local left = self.x + cam.x
  local top = self.y + cam.y
  local ui_start = cur_player
  local ui_end = 15 - num_players + cur_player
  local ui_left = left + ui_start * 8

  for p=1, num_players do
    pal(c.pink, player_colors[p])
    if p < cur_player then
      spr(t.ui_left_gem, left + 8 * (p - 1), top)
    elseif p == cur_player then
      spr(t.ui_mid_gem, left + 8 * (p - 1), top)
    else
      local i = t.ui_left_gem
      if p == num_players then
        i = t.ui_mid_gem
      end
      spr(i, left + 120 - (num_players) * 8 + 8 * p, top)
    end
  end

  spr(t.ui_corner, ui_left, top + 7)
  for i=ui_start + 1, ui_end - 2 do
    spr(t.ui_mid_nogem, left + i * 8, top + 7)
  end
  spr(t.ui_corner, left + ui_end * 8 - 8, top + 7, 1, 1, true)

  rectfill(ui_left, top, left + ui_end * 8 + 7, top + 6, c.black)

  if cur_player ~= num_players then
    spr(t.ui_left_nogem, left + ui_end * 8, top)
  end

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
  local show_followed = true
  local curs_x = flr(curs.x / 8)
  local curs_y = flr(curs.y / 8)
  local cell_n = mget(curs_x, curs_y)

  if fget(cell_n, f.food) then
    spr(t.ui_food, ui_left + 4, top + 6)
    print(get_resources(curs_x, curs_y), ui_left + 12, top + 7, c.white)
    show_followed = false
  end

  if fget(cell_n, f.material) then
    spr(t.ui_material, ui_left + 4, top + 6)
    print(get_resources(curs_x, curs_y), ui_left + 12, top + 7, c.white)
    show_followed = false
  end

  if fget(cell_n, f.money) then
    spr(t.ui_money, ui_left + 4, top + 6)
    print(get_resources(curs_x, curs_y), ui_left + 12, top + 7, c.white)
    show_followed = false
  end

  -- draw focused unit health
  if show_followed and follow ~= nil then
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

prev_state = nil
state = s.command
play_timer = 128
num_players = 3
cur_player = 0
players = {}

for p=1,num_players do
  add(players, {
    race=p,
    money=200,
    materials=200,
    food=200,
    units=1,
  })
end

cam = _camera()
curs = _sprite(anim_curs:copy(), 64, 64, pal_trans_red)
sel_curs = _sprite(anim_curs:copy(), 64, 64, pal_sel_curs)
play_meter = _meter()
play_meter.y = 120
player_ui = _info()
menu = _menu()
follow = nil

bear1 = _unit(1, 16, 16, races[players[1].race])
bear2 = _unit(2, 16 + 36 * 8, 24, races[players[2].race])
bear3 = _unit(3, 16 + 36 * 16, 32, races[players[3].race])

add(units, bear1)
add(units, bear2)
add(units, bear3)

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
  curs:move(closest_unit.x, closest_unit.y)
  sfx(a.ping)
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
  curs:move(unit.x, unit.y)
  sfx(a.ping)
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
  curs:move(unit.x, unit.y)
  sfx(a.ping)
end

-- move the cursor to the first unit owned by the cur_player
function jump_to_first_owned()
  for unit in all(units) do
    if unit.owner == cur_player then
      follow = unit
      curs:move(unit.x, unit.y)
      sfx(a.ping)
    end
  end
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

-- move to the next player, or start the play state
function next_turn()
  cur_player += 1

  if cur_player <= num_players then
    change_state("command")
    jump_to_first_owned()
    local owned = 0

    for unit in all(units) do
      if unit.owner == cur_player then
        owned += 1
      end
    end

    players[cur_player].units = owned
  else
    cur_player = 0
    play_timer = 128
    change_state("play")
  end
end

resources = {}

-- return the resources left on a node, generating if necessary
function get_resources(x, y)
  local key = coord_key(x, y)
  if resources[key] == nil then
    resources[key] = flr(rnd(128) + 64)
  end

  return resources[key]
end

function use_resource(x, y, owner, amt)
  amt = amt or 1
  local new = get_resources(x, y) - amt
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
  next_turn()
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

      if state == s.command then
        if follow ~= nil and follow.owner == cur_player then
          menu:add("move", function()
            change_state("move")
          end)
        end

        menu:add("end turn", next_turn)
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

    local dist = mdst(curs, sel_curs)
    if dist > 128 then
      curs.palette = pal_bad_curs
    else
      curs.palette = pal_trans_red
    end

    if btnp(b.x) then
      if dist <= 128 then
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

  if state == s.play then
    for unit in all(units) do
      unit:update()
    end

    play_timer -= 1
    play_meter:fill(play_timer)
    if play_timer == 0 then
      next_turn()
    end
  end

  curs:update()
  sel_curs:update()

  if follow ~= nil then
    sel_curs:move(follow.x, follow.y)
    if state ~= s.move then
      curs:move(follow.x, follow.y)
    end
  end
end

function _draw()
  cls()

  cam:draw()
  map(0, 0, 0, 0, 128, 64)

  for sprite in all(units) do
    sprite:draw()
  end

  curs:draw()

  if follow ~= nil then
    sel_curs:draw()
  end

  if state == s.menu or state == s.command or state == s.move then
    player_ui:draw()
  end

  if state == s.menu then
    menu:draw()
  end

  if state == s.play then
    play_meter:draw()
  end
end

__gfx__
00000000875087500875087550875087750875088888888888888888888888880000000000000000000000000000000089444498867777688511115800000000
00000000088888885888888078888885888888878894498888944988889449880000000000000000000000000000000084444448877777788111111800000000
00700700588888877888888888888880088888858840408888404088884040880000000000000000000000000000000084044048870770788101101800000000
00077000788888858888888708888888588888808444044884440448844404480000000000000000000000000000000044440444777707771111011100000000
00077000888888800888888558888887788888888844448888444488884444880000000000000000000000000000000044444444777777771111111100000000
00700700088888885888888078888885888888878849948888499488884994880000000000000000000000000000000084499448877667788115511800000000
00000000588888877888888888888880088888858848848888488888888884880000000000000000000000000000000084499448877667788115511800000000
00000000780578058057805705780578578057808888888888888888888888880000000000000000000000000000000084488448877887788118811800000000
00000000000888888888888800555005000000050055500000000000500000000000000000000000000000000000000000000000000000000000000000000000
00000000060000000000000005ee75050000000505ee750000000000850000000000000000000000000000000000000000000000000000000000000000000000
00000000000888888888888805eee5050000000505eee50000000000885000000000000000000000000000000000000000000000000000000000000000000000
00000000808888888888888805eee5050000000505eee50000000000885000000000000000000000000000000000000000000000000000000000000000000000
00000000808888888888888800555050000000500055500000000000888500000000000000000000000000000000000000000000000000000000000000000000
00000000000888888888888800000500000005000000000000000000888850000000000000000000000000000000000000000000000000000000000000000000
00000000060000000000000000005000000050000000000055555555888885550000000000000000000000000000000000000000000000000000000000000000
00000000000888888888888855555555555555555555555588888888888888880000000000000000000000000000000000000000000000000000000000000000
00000000666000000000000006111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000616666666666666606111111007700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000666111111111111106111111007770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000061111111111111106111111007777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000061111111111111106111111007770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000061111111111111106111111007700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000061111111111111106111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000061111111111111106111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000888888888888888888888888440404448888888800000000000000000000000000000000000000000000000033333333333333333333333333333333
00000000888878888889988884844488408080448944498800000000000000000000000000000000000000000000000033bb333333bbbb3333344333333bb333
00000000888f7788889a7988884444880888e8048404048800000000000000000000000000000000000000000000000033b333b33b2b2bb33344443333bbbb33
000000008444f888889aa98884994488408880448440448800000000000000000000000000000000000000000000000033333bb33bbbb2b33399993333bbbb33
0000000084448888889aa9888499488844080444844444880000000000000000000000000000000000000000000000003b3333333b2bbbb3334444333bbbbbb3
0000000084448888888998888844888844404444849994880000000000000000000000000000000000000000000000003bb33b3333bb2b333399993333344333
00000000888888888888888888888888444444448888888800000000000000000000000000000000000000000000000033333bb3333bb3333344443333344333
00000000888888888888888888888888444444448888888800000000000000000000000000000000000000000000000033333333333333333333333333333333
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
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0000000000000000000000000000000000000000000000000000000000000000
ffffffffff9ff9ffffbb8fffffffffffff3333ffffffffffffffffffffffffff0000000000000000000000000000000000000000000000000000000000000000
fffffffff9f9ff9fff8bbf8ffff55ffff333333fffffffffffffffffffffffff0000000000000000000000000000000000000000000000000000000000000000
fffffffffffff9fffffbffb8ff7ee7fff333333fffffffffffffffffffffffff0000000000000000000000000000000000000000000000000000000000000000
fffffffffff9fffffbbbfbbfff7ee7ffff3333ffffffffffffffffffffffffff0000000000000000000000000000000000000000000000000000000000000000
ffffffffff9ff9fff8fbbbffff7ee7fffff55fffffffffffffffffffffffffff0000000000000000000000000000000000000000000000000000000000000000
fffffffffff9ff9fffffbfffff7777fffff55fffffffffffffffffffffffffff0000000000000000000000000000000000000000000000000000000000000000
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
04040404040404042404040404040404040404040404040404040404040404040404040404060606060606060606060606060606060606060606060606060606
06060606060606060605050505050505050505050505050505050505050505050505050505050505050505050500000000000000000000000000000000000000
04040404040404040404040404040404040404040404040404040404040404040404040404060606060606060606060606060606060606060606060606060606
06060606060606060605050505050505050505050505050505050505050505050505050505050505050505050500000000000000000000000000000000000000
04040404040404040404040404040404040404040404040424040404044404040404040404060606060606160606060606360606060606060606060606060606
06060606060606060605050505050505050505051505050505054505050505050505350505050505050505050500000000000000000000000000000000000000
04040404040404040404040404040404040404040404040404040404040404040404040404060606060606060606060606060606060606060606060606060606
06060606060606060605050505050505050505050505050505050505050505050505050505050515050505050500000000000000000000000000000000000000
04040404040404044404040404040404040404440404040404040404040404040404040404060606060606060606060606060606160606060606060626060606
06060606060606060605050505053505050505050505050505050505050505050505050505050505050505050500000000000000000000000000000000000000
04040404040414040404040404041404040404040404040404040404041404040404040404060606060606060606060606060606060606060606060606060606
06060606060606060605050505050505050505050505050505050525050505050505050505050505050505050500000000000000000000000000000000000000
04040404040404040404040404040404040404040404040404040404040404040404040404060606060606060606060606060606060606060606060606060606
06060636060606060605050505050505050505053505050505050505050505050505050505050505050505050500000000000000000000000000000000000000
04040404040404040404340404040404040404040404040404040404040404040404040404060606060606060606060606060606060606060646060606060606
06060606060606060605050505050505054505050505050515050505050505050505050545050505050505050500000000000000000000000000000000000000
04040404040404040404040404040404040404040414040404040404040404040404040404060606060606460606060606060606060636060606060606060616
06060606060606060605050505050505050505050505050505050505050505250505050505050505050505250500000000000000000000000000000000000000
04040404040404440404040404040404040404040404040444040404040404040404040404060606060606060606060626060606060606060606060606060606
06060606060606060605050515052505050505050505050505050505050505050505050505050505050505050500000000000000000000000000000000000000
04040404040404040404040404040404040404040404040404040404040404042404040404060606060606060606060606060606060606060606060606060606
06060606060606060605050505050505050505050505050505050505050505050505050505050505050505050500000000000000000000000000000000000000
04040404040404040404040404040404040404040404040404040404040404040404040404060606060606160606060606060606060606060616060606060606
06060606060606060605050505050505050505052505050545050505050505050505051505050505050505050500000000000000000000000000000000000000
04040404040404040404040404040404042404040404040404043404040404040404040404060606060606060606060606060606060606060606060606060646
06060606060606060605050505050505050505050505050505050505050505050505050505050505050505050500000000000000000000000000000000000000
04040434040404040404040404040404040444040404040404040404040404140404040404060606060606060606060606060606060606062606060606060606
06060606060606060605050545050505050505050505050505050505050505050505050505050505350505050500000000000000000000000000000000000000
04040404040404040404140404040404040404040404440404040404040404040404040404060606060606060606060606060606060606060606060606060606
06060606060606060605050505050505050505050505050505050505150505050505050505050505050505050500000000000000000000000000000000000000
04040404040404040404040404040404040404040404040404040404040404040404040404060606060606060606060616060606060606060606060606060606
06060606160606060605050505050505051505050505050505050505050505050505050505050505050505050500000000000000000000000000000000000000
04040404040404040404040404040404040404040404040404040404040404040404040404060606060606060606060606060606060606060606060606060606
06060606060606060605050505050525050505050505050505050505050505050505050505050505050505050500000000000000000000000000000000000000
04040404040404040404040404040404040404040404040404040404040404040404040404060606060636060606060606060606060606060606060606060606
06060606060606060605050505050505050505050505050505050505050505050505050505050505050505050500000000000000000000000000000000000000
04040404040404042404040404040404041404040404040404040404044404040404040404060606060606060606060606060606060606060606060606160606
06060606060606060605050505050505050505050505050525050505050505050505050505052505050545050500000000000000000000000000000000000000
04040404040404040404040404040404040434040404040404043404040404040404040404060606060606060606060606060606060606060606060606060606
06060606060606060605050505050505050505050505050505050505050505050505050505050505050505050500000000000000000000000000000000000000
04040404040404040404040404040404040404040404040404040404140404040424040404060606060606060606060646060606060606060606060606060606
06060646060606060605050505050505050505050505050505050505050505050505150505050505050505050500000000000000000000000000000000000000
04040404040404040404040404040404040404040404040404040404040404040404040404060606060606060606060606060606060616060606063606060606
06060606060606060605050505050505050505050505050505050505450505050505050505050505050505050500000000000000000000000000000000000000
04440404040404040404040404040404040404042404040404040404040404040404040404060606061606060606060606060606060606060606060606060606
06060606060606060605050505150505050505051505050505050505050505050505050505050505050505050500000000000000000000000000000000000000
04040404040414040404340404040404040404040404040404040404040404040404040404060606060606060606060606260606060606060606060606060606
06060606060606060605050505050505050505050505050505050505050505050505050505050505050505050500000000000000000000000000000000000000
04040404040404040404040404040404040404040404040404040404044404040404040404060606060606060606060606060606060606060606060606060606
06060616060606060605050505050505050505050505050505050505050505050505050505050505050505050500000000000000000000000000000000000000
04040404040404040404040404041404040404040404040404040404040404040404040404060606060606060606060606060606060606060606060606060606
06060606060606060605050505050505050505050505050505050505050505050505050505050535050505050500000000000000000000000000000000000000
04040404040404040404040404040404040404040404040404040404040404040404040404060606060606060606060606060606060606064606060606060606
06060606060606060605050505050505050505350505050505050505350505050505050505050505050505050500000000000000000000000000000000000000
04040404040404042404040404040404040404040404041404040404040404040404040404060606061606060606060606060606060606060606060606060606
06060606060606060605050505050505050505054505050505050505050505050505050505050505050505050500000000000000000000000000000000000000
04040404040404040404040404040404040404040404040404040404040404040404040404060606060606460606060606060606060616060606060606060626
06060606060606060605050505050505050505050505050505050505050545050505050505050505050505050500000000000000000000000000000000000000
04040404040404040404040404040404040404040404040404040404043404040404040404060606060606060606060606360606060606060606060606060606
06060606060606060605050505050505051505050505050505050505050505050505050515050505050505050500000000000000000000000000000000000000
04040404040404040404040404040404040404040404040404040404040404040404040404060606060606060606060606060606060606060606060606060606
06060606060606060605050505053505050505050505050505050505050505050505050505050505050505050500000000000000000000000000000000000000
04040404040404040404040404040404040404040404040404040404040404040404040404060606060606060606060606060606060606060606060606060606
06060606060606060605050505050505050505050505050505050505050505050505050505050505050505050500000000000000000000000000000000000000
__gff__
0000000000000000000000000000000000000007070000000700000000000000000000000000000707000000000000000000000707000005090000000003050900000305090000000000000000000000000003050900000000000000000000000000030509000000000000000000000000000000000000000000000000000000
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
4040404040404040404040404040404044404040404040404040404040404040404040404060606060606060606060616060606060646060606060606060606060606060606060606050505050505050505050505050505050505450505050505050505050505050505050505000000000000000000000000000000000000000
4040404040404040404040404040404040404040404040404040404040404040404040404060606060606060606060606060606060606060606060606060606060606060606060606050505050505050505050505050505050505050505050505050505054505050505050505000000000000000000000000000000000000000
4040404040404040404040404040404040404040404040404040404040404040404040404060606060606060606060606060606060606060606060606060606060606060606060606050505050505050505050505050505050505050505050505052505050505050505050505000000000000000000000000000000000000000
4040404040404040404040404040404040404040404040404040404040404040404040404060606060606060606060606060606060606060606060606060606060606060606060606050505050505052505050505050505050505050505050505050505050505050505050505000000000000000000000000000000000000000
4040404040404040404040404040404040404040404040404040404040404040404040404060606060606060606060606060606060606060606060606060606060606060606060606050505050505050505050505150505050535050505050505050505050505050505150505000000000000000000000000000000000000000
4040404040404140404040404040404040404040404240404040404040404040404040404060606060606060606064606060606060606060606060606060606060626060606060606050505050505050505050505050505050505050505050505050505050505050505050505000000000000000000000000000000000000000
4040404040404040404040404040404040404040404040404040404040404040424240404060606060606060606060606060606060606060606060606060606060606060606060606050505050505050505050505050505050505050505050515050505052505050505050505000000000000000000000000000000000000000
4040404040404040404040404040434040404140404040404041404040404040404040404060606060606260606060606060606160606060606060606060606060606061606060606050505050505050505050505050505050505250505050505050505050505050505050505000000000000000000000000000000000000000
4040404040404040404040404040404040404040404040404040404040404040404040404060606060606060606060606060606060606060606060646060606060606060606060606050505050505150505054505050505050505050505050505050505050505050505050505000000000000000000000000000000000000000
__sfx__
00020000260500500030050300503005030040300403003030030300202d0003a6003a6002f0003960038600386003860038600386002e0002d0002a00028000210001d000190001600013000000000000000000
000300002e3502d3502c3502b3502a0002b3502c3402d3302e3202d00030000380003d00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000300000635007350083500935000000093500834007330063200430000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000

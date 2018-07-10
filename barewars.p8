pico-8 cartridge // http://www.pico-8.com
version 16
__lua__
-- bare wars
-- by john weachock

-- autogen: castle coordinates
castle_locs = {{14, 6}, {27, 7}, {4, 14}, {37, 17}, {36, 25}, {8, 29}, {19, 34}, {30, 39}}
-- end autogen

function abtn(i)
  for k=0,7 do
    if btn(i, k) then
      return true
    end
  end
  return false
end

function abtnp(i)
  for k=0,7 do
    if btnp(i, k) then
      return true
    end
  end
  return false
end

-- directions
dirs = {{0, -1}, {1, 0}, {0, 1}, {-1, 0}}

-- buttons
b_left = 0
b_right = 1
b_up = 2
b_down = 3
b_o = 4
b_x = 5
b_pause = 6

-- colors
c_black=0
c_darkblue=1
c_darkpurple=2
c_darkgreen=3
c_brown=4
c_darkgrey=5
c_lightgrey=6
c_white=7
c_red=8
c_orange=9
c_yellow=10
c_green=11
c_blue=12
c_indigo=13
c_pink=14
c_peach=15

-- player colors
player_colors = {
  c_red,    -- 1
  c_blue,   -- 2
  c_orange, -- 3
  c_pink,   -- 4
}

-- flags
f_solid=0
f_food=1
f_material=3
f_empty=5

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
t_curs1=1
t_curs2=2
t_curs3=3
t_curs4=4

t_worker_walk1=5
t_worker_walk2=6
t_worker_walk3=7

t_warrior_walk1=24
t_warrior_walk2=25
t_warrior_walk3=26

t_wall=8
t_tower=9
t_cave=10
t_blank=11
t_farm=40

t_meter_end=17
t_meter_mid=18

t_menu_corner=33
t_menu_hor=34
t_menu_vert=35
t_menu_arr=36

t_ui_left_gem=19
t_ui_left_nogem=20
t_ui_mid_gem=21
t_ui_mid_nogem=22
t_ui_corner=23
t_ui_food=49
t_ui_material=51
t_ui_heart=52
t_ui_unit=53
t_ui_sword=54
t_ui_pick=55
t_ui_house=56
t_ui_gem=57
t_ui_halfheart=58

t_ter_plain = 64
t_ter_good = 65
t_ter_food = 66
t_ter_honey = 67
t_ter_material = 68
t_ter_wall = 69
t_ter_build = 70
t_ter_castle1 = 72
t_ter_castle2 = 73
t_ter_castle3 = 74
t_ter_castle4 = 75

-- sfx
sfx_ping=0
sfx_ok=1
sfx_no=2
sfx_bullet=3

-- unit types
u_worker=0
u_warrior=1

-- unit costs
uc = {
  [u_worker]=10,
  [u_warrior]=14,
}

-- unit stats
stats = {
  [u_worker] = {health=3, fight=1, gather=2},
  [u_warrior] = {health=5, fight=2, gather=1},
}

-- house types
h_castle=0
h_cave=2
h_tower=3
h_farm=4
h_castle_tower=5

-- house costs
hc = {
  [h_castle]=16,
  [h_tower]=8,
  [h_farm]=10,
  [h_cave]=14,
  [h_castle_tower]=6,
}

-- house stats
hs = {
  [h_castle] = {tile=t_blank, health=12, cap=64, speed=0},
  [h_tower] = {tile=t_tower, health=8, cap=16},
  [h_cave] = {tile=t_cave, health=6, cap=256},
  [h_farm] = {tile=t_farm, health=4, cap=64},
}

-- map tile colors
tcol = {
  [t_ter_plain] = c_darkgreen,
  [t_ter_good] = c_darkgreen,
  [t_ter_food] = c_pink,
  [t_ter_honey] = c_orange,
  [t_ter_material] = c_brown,
  [t_ter_build] = c_lightgrey,
  [t_ter_castle1] = c_indigo,
  [t_ter_castle2] = c_indigo,
  [t_ter_castle3] = c_indigo,
  [t_ter_castle4] = c_indigo,
}

-- map unit colors
ucol = {
  [u_worker] = c_brown,
  [u_warrior] = c_lightgrey,
}

-- map house colors
hcol = {
  [h_castle] = c_indigo,
  [h_tower] = c_darkgrey,
  [h_cave] = c_darkblue,
  [h_farm] = c_green,
}

-- constants
map_w = 44
map_h = 44
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

function flr8(n)
  return flr(n / 8)
end

-- manhattan distance of two objects
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


-- pathfinding
-- https://www.lexaloffle.com/bbs/?tid=2570
function get_neighbors(x, y)
  res = {}
  for d in all(dirs) do
    if can_path(x + d[1], y + d[2]) then
      add(res, {x + d[1], y + d[2]})
    end
  end

  return res
end

function contains(t,v)
  for k, val in pairs(t) do
    if (val[1] == v[1] and val[2] == v[2]) then return true end
  end

  return false
end

function can_path(x, y)
  if x < 64 and x >= 0 and y < 64 and y >= 0 then
    local n = mget2(x, y)
    if not fget(n, f_solid) then
      return true
    end
  end

  return false
end

function can_build(x, y)
  if x < 64 and x >= 0 and y < 64 and y >= 0 then
    local n = mget2(x, y)
    if fget(n, f_empty) then
      return true
    end
  end

  return false
end

function can_build_adj(x, y)
  for dir in all(dirs) do
    if can_build(x + dir[1], y + dir[2]) then
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

function get_path(from_x, from_y, to_x, to_y)
  local path={}
  local start={from_x, from_y}
  local flood={start}
  local camefrom={}

  camefrom[coord_key(start)] = nil

  while #flood > 0 do
    local current = flood[1]

    if (current[1] == to_x and current[2] == to_y) then break end

    neighbs = get_neighbors(current[1], current[2])
    if mdst({x=current[1], y=current[2]}, {x=to_x, y=to_y}) == 1 then
      add(neighbs, {to_x, to_y})
    end

    if #neighbs > 0 then
      for neighb in all(neighbs) do
        if camefrom[coord_key(neighb)] == nil and not contains(camefrom, neighb) then
          add(flood,neighb)
          camefrom[coord_key(neighb)] = current

          -- awesome flood debugging
          if false then
            rectfill(neighb[1]*8, neighb[2]*8, (neighb[1]*8)+7, (neighb[2]*8)+7, c_blue)
            flip()
          end
        end
      end
    end

    del(flood,current)
  end

  local c = {to_x, to_y}
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
  if self.tx > map_w * 8 - 127 then
    self.tx = map_w * 8 - 127
  end
  if self.ty < 0 then
    self.ty = 0
  end
  if self.ty > map_h * 8 - 127 then
    self.ty = map_h * 8 - 127
  end
end

function _camera:dmove(dx, dy)
  self:move(self.tx + dx, self.ty + dy)
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

  spr(tile, self.x, self.y, 1, 1, self.flipx)

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

function _anim:init(frames)
  self.step = 0
  self.cur = 1
  self.frames = frames
end

function _anim:next()
  self.cur += 1
  if self.cur == #self.frames + 1 then
    self.cur = 1
  end

  return self.frames[self.cur]
end

function _anim:update()
  self.step += 1
  if (self.step % 3) == 0 then
    self:next()
  end

  return self.frames[self.cur]
end

function _anim:frame()
  return self.frames[self.cur]
end

function _anim:copy()
  return _anim(self.frames)
end

-- animations
an_stand = {
  [u_worker] = t_worker_walk1,
  [u_warrior] = t_warrior_walk1,
}
an_walk = {
  [u_worker] = _anim({t_worker_walk1, t_worker_walk2, t_worker_walk1, t_worker_walk3}),
  [u_warrior] = _anim({t_warrior_walk1, t_warrior_walk2, t_warrior_walk1, t_warrior_walk3}),
}

an_curs = _anim({t_curs1, t_curs2, t_curs3, t_curs4})

-- palettes
function pal_trans_red()
  palt(c_red, true)
  palt(c_black, false)
end

function pal_sel_curs()
  pal_trans_red()
  if follow then
    pal(c_black, player_colors[follow.owner])
  else
    pal(c_black, c_white)
  end
end

function pal_bad_curs()
  pal_trans_red()
  pal(c_black, c_darkpurple)
end

pal_race1 = pal_trans_red

function pal_race2()
  pal_trans_red()
  pal(c_brown, c_darkblue)
  pal(c_orange, c_brown)
end

function pal_race3()
  pal_trans_red()
  pal(c_brown, c_white)
  pal(c_orange, c_blue)
end

function pal_race4()
  pal_trans_red()
  pal(c_black, c_lightgrey)
  pal(c_brown, c_white)
  pal(c_orange, c_darkgrey)
end

races = {pal_race1, pal_race2, pal_race3, pal_race4}

function draw_unit_healthbar(self)
  local col = c_pink
  for i=1, self.max_health do
    if i > self.health then
      col = c_darkblue
    end
    pset(self.x + i - 1, self.y, col)
  end
  pset(self.x, self.y + 6, player_colors[self.owner])
end

-- unit class
_unit = _sprite:extend()

function _unit:init(owner, x, y, palette, type, sick)
  self.__super.init(self, 0, x, y, palette)
  self.is_unit = true
  self.owner = owner
  self.type = type or u_worker
  self.tile = an_stand[self.type]
  self.sick = sick

  local stats = stats[self.type]
  self.health = stats.health
  self.max_health = stats.health
  self.fight = stats.fight
  self.gather = stats.gather

  self.tx = x
  self.ty = y
  self.ctx = flr8(x)
  self.cty = flr8(y)
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
  self.sick = false
  self.dir = nil

  -- movement
  local path = self.path
  if path and #path > 0 then
    local waypoint = path[#path]
    local wx = waypoint[1] * 8
    local wy = waypoint[2] * 8

    -- move to waypoint
    if self.x < wx then
      self.x += 1
      self.flipx = false
    end

    if self.x > wx then
      self.x -= 1
      self.flipx = true
    end

    if self.y < wy then
      self.y += 1
    end

    if self.y > wy then
      self.y -= 1
    end

    -- pop current waypoint if we're at it
    if self.x == wx and self.y == wy then
      path[#path] = nil

      if #path == 0 then
        self.tile = an_stand[self.type]
        self.path = nil
      end
    end

  -- perform actions
  elseif self.x == self.tx and self.y == self.ty then
    for i=1, #dirs do
      if self:use_resources(dirs[i][1], dirs[i][2]) then
        self.dir = i
        return
      end
    end

    if self:fight_castle() then
      return
    end

    for i=1, #dirs do
      if self:fight_list(houses, dirs[i][1], dirs[i][2], 2) then
        self.dir = i
        return
      end
    end

    for i=1, #dirs do
      if self:fight_list(units, dirs[i][1], dirs[i][2], 1) then
        self.dir = i
        return
      end
    end
  end
end

function _unit:draw()
  local path = self.path
  local col = player_colors[self.owner]

  if path and #path > 0 then
    line(self.x + 4, self.y + 4, path[#path][1] * 8 + 4, path[#path][2] * 8 + 4, col)
    for coord=1,#path-1 do
      line(path[coord][1] * 8 + 4, path[coord][2] * 8 + 4, path[coord+1][1] * 8 + 4, path[coord+1][2] * 8 + 4, col)
    end

    local last_x = path[1][1] * 8 + 3
    local last_y = path[1][2] * 8 + 3
    rectfill(last_x, last_y, last_x + 2, last_y + 2, col)
  end

  if self ~= follow then
    draw_unit_healthbar(self)
  end

  self.__super.draw(self)

  if self.sick then
    local off = flr((frame % 30) / 10) - 2
    pset(self.x - off, self.y - off, c_darkpurple)
  end

  if state == s.play then
    if self.dir == 1 then
      pset(self.x + 3, self.y + 1, col)
      pset(self.x + 4, self.y + 1, col)
    elseif self.dir == 2 then
      pset(self.x + 6, self.y + 3, col)
      pset(self.x + 6, self.y + 4, col)
    elseif self.dir == 3 then
      pset(self.x + 3, self.y + 6, col)
      pset(self.x + 4, self.y + 6, col)
    elseif self.dir == 4 then
      pset(self.x + 1, self.y + 3, col)
      pset(self.x + 1, self.y + 4, col)
    end
  end
end

function _unit:set_dest(tx, ty)
  self.tx = tx
  self.ty = ty
  self.ctx = flr8(tx)
  self.cty = flr8(ty)
  self.path = self:get_path()
  if #self.path > 0 then
    self.tile = an_walk[self.type]:copy()
  else
    self.path = nil
  end
end

function _unit:get_path()
  local cur_x = flr8(self.x)
  local cur_y = flr8(self.y)
  return get_path(cur_x, cur_y, self.ctx, self.cty)
end

function _unit:use_resources(rel_x, rel_y)
  local res = get_resources(self.ctx + rel_x, self.cty + rel_y)
  if res and res > 0 then
    local count = self:act(self.gather * 2)
    use_resource(self.ctx + rel_x, self.cty + rel_y, self.owner, count)
    return true
  end
end

function _unit:fight_castle()
  for house in all(houses) do
    if house.type == h_castle and house.owner ~= self.owner and mdst(house, self) <= 16 then
      local count = self:act(self.fight)
      house.health -= count / 2
      return true
    end
  end
end

function _unit:fight_list(list, rel_x, rel_y, factor)
  for el in all(list) do
    if el.owner ~= self.owner and el.x == self.x + rel_x * 8 and el.y == self.y + rel_y * 8 then
      local count = self:act(self.fight)
      house.health -= count / factor
      return true
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
  self.mx = flr8(x)
  self.my = flr8(y)

  local cell_n = mget2(self.mx, self.my)
  mset2(self.mx, self.my, t_ter_wall)

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
  if self ~= follow and self.type ~= h_castle then
    draw_unit_healthbar(self)
  end

  local fill = min(flr(self.action / self.cap * 8), 7)
  if fill > 0 then
    line(self.x, self.y + 7, self.x + fill, self.y + 7, c_orange)
  end

  self.__super.draw(self)
end

function _house:act()
  if self.type == h_tower or self.type == h_castle then
    for unit in all(units) do
      if unit.owner ~= self.owner and mdst(unit, self) <= 24 then
        sfx(sfx_bullet)
        unit.health -= 1
        self.action -= self.cap
        return
      end
    end
  elseif self.type == h_farm then
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
    local wid = right - left
    right = cam.x + 116
    left = right - wid
  end

  if curs.y < bottom then
    local hei = bottom - top
    bottom = cam.y + 116
    top = bottom - hei
  end

  -- corners + fill
  spr(t_menu_corner, left, top)
  spr(t_menu_corner, right, top, 1, 1, true)
  spr(t_menu_corner, left, bottom, 1, 1, false, true)
  spr(t_menu_corner, right, bottom, 1, 1, true, true)
  rectfill(left + 8, top + 8, right - 1, bottom - 1, c_darkblue)

  -- horizontal walls
  for x=1, width do
    spr(t_menu_hor, left + 8 * x, top)
    spr(t_menu_hor, left + 8 * x, bottom, 1, 1, false, true)
  end

  -- vertical walls
  for y=1, height - 1 do
    spr(t_menu_vert, left, top + 8 * y)
    spr(t_menu_vert, right, top + 8 * y, 1, 1, true)
  end

  --text
  for y=1, height do
    local col = c_lightgrey
    if y == self.idx then
      col = c_white
      spr(t_menu_arr, left + 2, top - 4 + 8 * y)
    end
    if not self.enables[y] then
      col = c_darkgrey
    end

    print(self.labels[y], left + 10, top - 3 + 8 * y, col)
  end
end

-- turn meter
function draw_meter()
  palt(c_black, false)
  palt(c_red, true)

  local left = cam.x + 2
  local top = cam.y + 122
  local fill = play_timer / 128 * 124

  rectfill(left, top, left + 124, top + 4, c_darkblue)
  line(left, top, left + fill, top, c_pink)
  rect(left, top + 1, left + fill, top + 2, c_red)
  line(left, top + 3, left + fill, top + 3, c_indigo)

  top -= 2
  left -= 2
  spr(t_meter_end, left, top)

  for n=1, 14 do
    spr(t_meter_mid, left + 8 * n, top)
  end

  spr(t_meter_end, left + 120, top, 1, 1, true)

  palt()
end


-- user interface
function draw_info()
  palt(c_black, false)
  palt(c_red, true)

  -- decide which player's info to show
  local player_num = cur_player
  if follow ~= nil then
    player_num = follow.owner
  end

  local player = players[player_num]

  -- decide which ui slot that is
  local ui_slot = 1
  for i=1, #order do
    if order[i] == player_num then
      ui_slot = i
      break
    end
  end

  -- in play state with no player, show them all on the left side
  if player == nil then
    ui_slot = #order
  end

  -- draw side bar units
  for i=1, #units do
    local top = 6 + cam.y + 3 * i
    local left = 2 + cam.x
    local unit = units[i]

    if follow == unit then
      rectfill(left - 1, top - 1, left + 1, top + 1, c_darkgrey)
    end

    pset(left, top, player_colors[units[i].owner])

    if unit.x ~= unit.tx or unit.y ~= unit.ty then
      pset(left + 1, top, c_yellow)
    end

  end

  -- draw side bar houses
  for i=1, #houses do
    local top = 6 + cam.y + 3 * i
    local left = 5 + cam.x
    local house = houses[i]
    if follow == house then
      rectfill(left - 1, top - 1, left + 1, top + 1, c_darkgrey)
    end

    pset(left, top, player_colors[houses[i].owner])

    if (house.action >= house.cap) and (house.type == h_cave) then
      pset(left + 1, top, c_yellow)
    end
  end

  -- draw background + gems
  local left = cam.x
  local top = cam.y
  local ui_start = ui_slot
  local ui_end = 16 - #order + ui_slot
  local ui_left = left + ui_start * 8
  local ui_right = left + ui_end * 8 - 16

  for p=1, #order do
    local border_col = c_darkgrey
    if order[p] == cur_player then
      border_col = c_lightgrey
    end

    pal(c_lightgrey, border_col)
    pal(c_pink, player_colors[order[p]])

    if p < ui_slot then
      spr(t_ui_left_gem, left + 8 * (p - 1), top)
    elseif p == ui_slot then
      spr(t_ui_mid_gem, left + 8 * (p - 1), top)
    else
      local i = t_ui_left_gem
      if p == #order then
        i = t_ui_mid_gem
      end
      spr(i, left + 120 - (#order) * 8 + 8 * p, top)
    end
  end

  spr(t_ui_corner, ui_left, top + 7)
  for i=ui_start + 1, ui_end - 2 do
    spr(t_ui_mid_nogem, left + i * 8, top + 7)
  end
  spr(t_ui_mid_nogem, left + ui_end * 8 - 12, top + 7)

  rectfill(ui_left, top, left + ui_end * 8 - 1, top + 6, c_black)

  spr(t_ui_corner, left + ui_end * 8 - 4, top + 7, 1, 1, true)
  spr(t_ui_corner, left + ui_end * 8 - 4, top + 7, 1, 1, true)

  -- reset palette swaps from the gems
  pal()
  palt(c_red, true)

  -- draw resources
  if player ~= nil then
    draw_resources(player, ui_left + 3, top - 1)
  end

  -- reset palette swaps
  pal()
  palt(c_red, true)
  palt(c_black, false)

  -- draw focused map info
  local curs_x = flr8(curs.x)
  local curs_y = flr8(curs.y)
  local cell_n = mget2(curs_x, curs_y)
  local res = get_resources(curs_x, curs_y)

  -- draw map resource info
  if fget(cell_n, f_food) and fget(cell_n, f_material) then
    spr(t_ui_material, ui_right + 8, top + 6)
    spr(t_ui_food, ui_right + 2, top + 6)
  elseif fget(cell_n, f_food) then
    spr(t_ui_food, ui_right + 2, top + 6)
  elseif fget(cell_n, f_material) then
    spr(t_ui_material, ui_right + 2, top + 6)
  end

  if res and res > 0 then
    local offx = -2
    if res >= 100 then
      offx = -10
    elseif res >= 10 then
      offx = -6
    end
    print(res, ui_right + offx, top + 7, c_white)
  end

  -- draw focused unit stats
  if follow ~= nil then
    if follow.is_unit then
      for i=1, follow.fight do
        spr(t_ui_sword, ui_left + (i + follow.max_health) * 6 + 2, top + 6)
      end

      for i=1, follow.gather do
        spr(t_ui_pick, ui_left + (i + follow.max_health + follow.fight) * 6 + 6, top + 6)
      end
    end

    -- hearts need a wacky palette swap
    pal()
    palt()
    palt(c_red, false)
    palt(c_brown, true)

    for i=1, follow.max_health do
      if i >= follow.health + 1 then
        pal(c_red, c_darkblue)
        pal(c_pink, c_indigo)
      end
      local t = t_ui_heart
      if flr((follow.health - i + 1) * 10) == 5 then
        t = t_ui_halfheart
      end
      spr(t, ui_left + i * 6 - 2, top + 6)
    end
  end

  pal()
  palt()

  -- draw castle indicators
  for p in all(order) do
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

function draw_resources(player, x, y, fix_black)
  local text_y = y + 1
  spr(t_ui_food, x, y)
  print(player.food, x + 7, text_y, c_white)

  spr(t_ui_material, x + 16, y)
  print(player.materials, x + 23, text_y, c_white)

  if fix_black then
    pal(c_darkblue, c_black)
  end

  spr(t_ui_house, x + 50, y)
  print(player.houses, x + 59, text_y, c_white)

  races[player.race]()

  if fix_black and player.race == 2 then
    pal(c_brown, c_black)
    pal(c_black, c_darkgrey)
  end

  spr(t_ui_unit, x + 33, y)
  print(player.units, x + 41, text_y, c_white)
end

-- elements
units = {}
houses = {}

prev_state = nil
state = s.command
play_timer = 128
min_players = 2
max_players = 4
num_players = 2
turn_idx = 0
cur_player = 0
players = {}
order = {}
map_open = false

cam = _camera()
curs = _sprite(an_curs:copy(), 64, 64, pal_trans_red)
sel_curs = _sprite(an_curs:copy(), 64, 64, pal_sel_curs)
menu = _menu()
follow = nil

btns = {[0]=false, [1]=false, [2]=false, [3]=false, [4]=false, [5]=false}
btnd = {[0]=0, [1]=0, [2]=0, [3]=0, [4]=0, [5]=0}

-- initialize all players
function init_players()
  players = {}
  order = {}
  for p=1, num_players do
    -- decide castle location
    local castle_loc = castle_locs[flr(rnd(#castle_locs) + 1)]
    del(castle_locs, castle_loc)
    local x = castle_loc[1]
    local y = castle_loc[2]

    -- make a worker unit and a castle house
    local worker = _unit(p, x * 8, y * 8 + 16, races[p])
    local castle = _house(p, x * 8 + 4, y * 8 + 4, h_castle)

    -- draw castle
    mset2(x, y, t_ter_castle1)
    mset2(x + 1, y, t_ter_castle2)
    mset2(x, y + 1, t_ter_castle3)
    mset2(x + 1, y + 1, t_ter_castle4)

    add(units, worker)
    add(houses, castle)
    add(order, p)
    add(players, {
      castle_x=x,
      castle_y=y,
      race=p,
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
    if unit_dist < closest_dist then
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
  sfx(sfx_ping)
end

-- move the cursor to the next unit (undefined behavior if no unit is under the cursor)
function jump_to_next_unit(list)
  list = list or units
  local i = 0
  for unit in all(list) do
    i += 1
    if unit == follow then
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
  sfx(sfx_ping)
end

-- move the cursor to the previous unit (undefined behavior if no unit is under the cursor)
function jump_to_prev_unit(list)
  list = list or units
  -- find the unit we're selecting
  local i = 0
  for unit in all(list) do
    i += 1
    if unit == follow then
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
  sfx(sfx_ping)
end

-- move the cursor to the next unit owned by the cur_player
function jump_to_next_owned()
  local next = fals

  for unit in all(units) do

    if unit.owner == cur_player then
      if next then
        follow = unit
        curs:move(unit.x, unit.y)
        sfx(sfx_ping)
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
      sfx(sfx_ping)
      break
    end
  end
end

-- change the state, recording the previous one as well
function change_state(to)
  to = to or prev_state

  if type(to) == "string" then
    to = s[to]
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
        if house.type == h_castle then
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
          del_house(house)
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
  local is_resource = fget(cell, f_food) or fget(cell, f_material)
  local key = coord_key(x, y)
  if is_resource and resources[key] == nil then
    resources[key] = flr(rnd(16) + 16)
  end

  return resources[key]
end

-- hire a new unit
function hire_unit(unit_type)
  local player = players[cur_player]

  local new = _unit(cur_player, follow.x, follow.y + 8, races[player.race], unit_type, true)

  add(units, new)
  player.units += 1
  change_state()
end

-- build a new house
function build_house(house_type, x, y)
  local player = players[cur_player]
  local new = _house(cur_player, x * 8, y * 8, house_type)

  add(houses, new)
  player.houses += 1
  change_state()
end

-- make the base menu when clicking from command mode
function make_base_menu()
  local player = players[cur_player]
  menu:clear()

  if follow ~= nil and follow.owner == cur_player then
    if follow.is_unit then
      menu:add("move", function()
        change_state("move")
      end, not follow.sick)

      if follow.type == u_worker then
        menu:add("build", make_build_menu, can_build_adj(flr8(curs.x), flr8(curs.y)) ~= false)
      end

    elseif follow.is_house then
      if follow.type == h_cave then
        local can_awaken = follow.action >= follow.cap
        -- this doesn't prevent you from awakening while someone has the spawn zone targeted
        for unit in all(units) do
          if unit.x == follow.x and unit.y == follow.y + 8 then
            can_awaken = false
          end
        end

        menu:add("awaken", make_hire_menu, can_awaken)
      end

      menu:add("upgrade", make_upgrade_menu)
    end
  end

  menu:add("map", function() change_state() map_open = true end)
  menu:add("end turn", next_turn)
end

function make_build_menu()
  local player = players[cur_player]
  menu:clear()
  menu.back = make_base_menu

  local build_x, build_y = can_build_adj(flr8(curs.x), flr8(curs.y))

  for k in all({{"farm", h_farm}, {"cave", h_cave}, {"tower", h_tower}}) do
    local cost = hc[k[2]]
    menu:add(cost .. " " .. k[1], function()
      build_house(k[2], build_x, build_y)
      player.materials -= cost
    end, player.materials >= cost)
  end
end

function make_hire_menu()
  local player = players[cur_player]
  menu:clear()
  menu.back = make_base_menu

  menu:add("worker", function()
    hire_unit(u_worker)
    follow.action -= follow.cap
  end)

  menu:add("warrior", function()
    hire_unit(u_warrior)
    follow.action -= follow.cap
  end)
end

function make_upgrade_menu()
  local player = players[cur_player]
  menu:clear()
  menu.back = make_base_menu

  local cost = hc[follow.type]
  local repair_cost = flr(cost / 2)

  local repair_text = " repair"
  if follow.max_health < 8 then
    repair_text = " increase health"
  end

  menu:add(repair_cost .. repair_text, function()
    if follow.health < 8 then
      follow.max_health += 1
    end

    if follow.health < follow.max_health then
      follow.health += 1
    end

    player.materials -= repair_cost
    change_state()
  end, player.materials >= repair_cost and (follow.health < follow.max_health or follow.max_health < 8))

  if follow.type == h_castle then
    if follow.speed == 0 then
      menu:add(hc[h_castle_tower] .. " add tower", function()
        follow.speed += 1
        player.materials -= hc[h_castle_tower]
        change_state()
      end, player.materials >= hc[h_castle_tower])

    else
      if follow.cap > 8 then
        local cost = hc[h_castle_tower] + (hs[h_castle].cap - follow.cap) / 2
        menu:add(cost .. " increase speed", function()
          follow.cap /= 2
          player.materials -= cost
          change_state()
        end, player.materials >= cost)
      end
    end

  else
    if follow.speed ~= 2 then
      menu:add(cost .. " increase speed", function()
        follow.speed = 2
        player.materials -= cost
        change_state()
      end, player.materials >= cost)
    end
  end

end

function draw_map()
  local left = cam.x
  local top = cam.y
  local size = 120

  -- draw border
  palt(c_black, false)
  spr(t_menu_corner, left, top)
  spr(t_menu_corner, left + size, top, 1, 1, true)
  spr(t_menu_corner, left, top + size, 1, 1, false, true)
  spr(t_menu_corner, left + size, top + size, 1, 1, true, true)

  for i=1,(size - 8)/8 do
    spr(t_menu_hor, left + i * 8, top)
    spr(t_menu_hor, left + i * 8, top + size, 1, 1, false, true)
    spr(t_menu_vert, left, top + i * 8)
    spr(t_menu_vert, left + size, top + i * 8, 1, 1, true)
  end

  -- draw backdrop
  rectfill(left + 8, top + 8, left + size - 1, top + size - 1, c_darkblue)

  -- draw player stats
  for i=1, #order do
    pal()
    palt()
    palt(c_red, true)
    palt(c_black, false)

    -- palette swaps for gem
    local p = order[i]
    pal(c_pink, player_colors[p])
    if cur_player ~= p then
      pal(c_lightgrey, c_darkgrey)
    end

    -- draw gem
    local y = top + 87 + p * 8
    spr(t_ui_gem, left + 27, y)

    -- draw resources
    pal()
    palt(c_red, true)
    draw_resources(players[p], left + 34, y, true)
  end

  pal()
  palt()

  function draw_tile(x, y, col, owner)
    local tx = left + x * 2
    local ty = top + y * 2
    rect(tx, ty, tx + 1, ty + 1, col)
    if owner then
      pset(tx, ty, player_colors[owner])
    end
  end

  -- draw map
  left += 20
  top += 5
  rectfill(left - 1, top - 1, left + map_w * 2, top + map_w * 2, c_darkgrey)

  for x=0,63 do
    for y=0,63 do
      local cell_n = mget2(x, y)
      if tcol[cell_n] ~= nil then
        draw_tile(x, y, tcol[cell_n])
      end
    end
  end

  -- draw units / houses
  for unit in all(units) do
    local ux = flr(unit.x / 4) / 2
    local uy = flr(unit.y / 4) / 2
    draw_tile(ux, uy, ucol[unit.type], unit.owner)
  end

  for house in all(houses) do
    local hx = flr(house.x / 4) / 2
    local hy = flr(house.y / 4) / 2
    draw_tile(hx, hy, hcol[house.type], house.owner)
    if house.type == h_castle then
      draw_tile(hx, hy, player_colors[house.owner])
    end
  end

  -- draw cursor / camera
  if (frame % 40) < 20 then
    local curs_x = flr(curs.x / 4) / 2
    local curs_y = flr(curs.y / 4) / 2
    draw_tile(curs_x, curs_y, c_black)
  end

  local cam_x = left + flr(cam.x / 4)
  local cam_y = top + flr(cam.y / 4)
  rect(cam_x - 1, cam_y - 1, cam_x + 32, cam_y + 32, c_darkgrey)
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

  if fget(cell, f_food) then
    player.food += amt
  end

  if fget(cell, f_material) then
    player.materials += amt
  end

  if new == 0 then
    mset2(x, y, flr(cell / 16) * 16)
  end
end

function del_house(house)
  del(houses, house)
  if houses[house.owner] and houses[house.owner].houses then
    houses[house.owner].houses -= 1
  end

  -- reset terrain to neutral
  local cell_x = flr8(house.x)
  local cell_y = flr8(house.y)
  local cell_n = mget2(cell_x, cell_y)
  if house.type == h_castle then
    mset2(cell_x, cell_y, flr(cell_n / 16) * 16 + 6)
    mset2(cell_x + 1, cell_y, flr(cell_n / 16) * 16)
    mset2(cell_x, cell_y + 1, flr(cell_n / 16) * 16)
    mset2(cell_x + 1, cell_y + 1, flr(cell_n / 16) * 16 + 3)
  else
    mset2(cell_x, cell_y, flr(cell_n / 16) * 16 + 6)
  end
end

function limit_cursor()
  if curs.x < 0 then
    curs.x = 0
  end
  if curs.x > map_w * 8 - 8 then
    curs.x = map_w * 8 - 8
  end
  if curs.y < 0 then
    curs.y = 0
  end
  if curs.y > map_h * 8 - 8 then
    curs.y = map_h * 8 - 8
  end
end

function _init()
  -- next_turn()
  change_state("splash")
end

frame = 0
function _update()
  for i=0,6 do
    btns[i] = abtn(i)
    if btns[i] then
      btnd[i] += 1
    else
      btnd[i] = 0
    end
  end
  frame += 1

  if state == s.splash or state == s.win then
    cam.x = 0
    cam.y = 0

  elseif state == s.command or state == s.play then
    local move_amt = 8
    if follow and follow.is_house and follow.type == h_castle then
      move_amt = 12
    end

    if btnd[b_left] == 1 or btnd[b_left] > 4 then
      if btns[b_o] then
        jump_to_prev_unit()
      else
        curs:dmove(-move_amt, 0)
      end
    end

    if btnd[b_right] == 1 or btnd[b_right] > 4 then
      if btns[b_o] then
        jump_to_next_unit()
      else
        curs:dmove(move_amt, 0)
      end
    end

    if btnd[b_up] == 1 or btnd[b_up] > 4 then
      if btns[b_o] then
        jump_to_prev_unit(houses)
      else
        curs:dmove(0, -move_amt)
      end
    end

    if btnd[b_down] == 1 or btnd[b_down] > 4 then
      if btns[b_o] then
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
        if house.type == h_castle then
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
      curs.x = flr8(curs.x) * 8
      curs.y = flr8(curs.y) * 8
    end

    if btnd[b_o] == 1 then
      if map_open then
        map_open = false
      elseif cur_player and follow ~= nil then
        jump_to_next_owned()
      else
        jump_to_closest_unit()
      end
    end

    if abtnp(b_x) then
      if map_open then
        map_open = false
      elseif state == s.command then
        make_base_menu()

        if #menu.labels > 0 then
          change_state("menu")
        end
      elseif state == s.play then
        map_open = true
      end
    end

  elseif state == s.menu then
    if abtnp(b_down) then
      menu:down()
    end

    if abtnp(b_up) then
      menu:up()
    end

    if abtnp(b_x) then
      menu:call()
    end

    if abtnp(b_o) then
      if menu.back ~= nil then
        menu.back()
      else
        change_state("command")
      end
    end

    menu:update()

  elseif state == s.move then
    if abtnp(b_left) then
      curs:dmove(-8, 0)
    end

    if abtnp(b_right) then
      curs:dmove(8, 0)
    end

    if abtnp(b_up) then
      curs:dmove(0, -8)
    end

    if abtnp(b_down) then
      curs:dmove(0, 8)
    end

    limit_cursor()

    local dist = mdst(curs, sel_curs)
    if dist > worker_range * 8 then
      curs.palette = pal_bad_curs
      follow:set_dest(follow.x, follow.y)
    else
      curs.palette = pal_trans_red
      if abtnp(b_left) or abtnp(b_right) or abtnp(b_up) or abtnp(b_down) then
        follow:set_dest(curs.x, curs.y)
      end
    end

    if not can_path(flr8(curs.x), flr8(curs.y)) then
      curs.palette = pal_bad_curs
      follow:set_dest(follow.x, follow.y)
    end

    for unit in all(units) do
      if unit ~= follow then
        if (unit.x == curs.x and unit.y == curs.y) or (unit.tx == curs.x and unit.ty == curs.y) then
          curs.palette = pal_bad_curs
          follow:set_dest(follow.x, follow.y)
          break
        end
      end
    end

    if abtnp(b_x) then
      if curs.palette == pal_trans_red then
        curs.palette = pal_trans_red
        follow = nil
        change_state("command")
        sfx(sfx_ok)
      else
        sfx(sfx_no)
      end
    end

    if abtnp(b_o) then
      follow:set_dest(follow.x, follow.y)
      change_state("command")
    end
  end

  if state == s.play then
    for house in all(houses) do
      house:update()
    end

    for unit in all(units) do
      unit:update()
    end

    for house in all(houses) do
      if house.health <= 0 then
        del_house(house)
      end
    end

    for unit in all(units) do
      if unit.health <= 0 then
        del(units, unit)
        players[unit.owner].units -= 1
      end
    end

    play_timer -= 2
    if play_timer == 0 then
      next_turn()
    end
  end

  if state ~= s.splash and state ~= s.win then
    limit_cursor()

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
    rectfill(0, 0, 128, 128, c_darkgrey)
    palt()
    palt(c_black, false)
    palt(c_green, true)
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
      print("bare wars", 47, 48, c_lightgrey)

      for i=min_players, max_players do
        local col = c_lightgrey
        if i == num_players then
          col = player_colors[i]
        end
        print(i .. "p", i * 16 + 13, 64, col)
      end

      print("press \142+\151", 43, 80, c_lightgrey)

      if abtnp(b_left) then
        num_players = max(num_players - 1, min_players)
        sfx(sfx_ping)
      end

      if abtnp(b_right) then
        num_players = min(num_players + 1, max_players)
        sfx(sfx_ping)
      end

      if abtn(b_o) and abtn(b_x) then
        init_players()
        change_state("command")
      end

    elseif state == s.win then
      if #order == 1 then
        print("victory", 50, 48, c_lightgrey)

        local off_x = 64 - num_players * 8 - 10
        for i=1, num_players do
          local col = c_indigo
          if i == order[1] then
            col = player_colors[i]
          end
          print(i, i * 16 + off_x, 64, col)
        end
      else
        print("draw", 60, 48, c_lightgrey)
      end

      print("reset \142+\151", 43, 80, c_lightgrey)

      if abtn(b_o) and abtn(b_x) then
        run()
      end
    end

    local col = player_colors[num_players]
    if state == s.win then
      col = player_colors[order[1]]
    end

    if abtn(b_x) then
      print("         \151", 43, 80, col)
    end

    if abtn(b_o) then
      print("      \142", 43, 80, col)
    end

  else
    if abtnp(b_pause) then
      if not map_open then
        map_open = true
        poke(0x5f30,1)
      end
    end

    map(0, 0, 0, 0, 64, 32)
    map(64, 0, 0, 256, 64, 32)

    for p in all(order) do
      local player = players[p]
      local px = player.castle_x * 8
      local py = player.castle_y * 8
      local pc = player_colors[p]
      pset(px + 1, py + 5, pc)
      pset(px + 2, py + 4, pc)
      pset(px + 2, py + 5, pc)
      pset(px + 2, py + 6, pc)
    end

    -- mark selectable cells
    if state == s.move then
      local mx = flr8(follow.x)
      local my = flr8(follow.y)
      for x=-8, 8 do
        for y=-8, 8 do
          if can_path(mx + x, my + y) and abs(x) + abs(y) <= worker_range then
            pset((mx + x) * 8 + 4, (my + y) * 8 + 4, c_lightgrey)
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
        rectfill(curs.x + 9, curs.y, curs.x + 13, curs.y + 6, c_darkgrey)
        print(#follow.path, curs.x + 10, curs.y + 1, c_white)
      end
    end

    if state == s.menu or state == s.command or state == s.move or state == s.play then
      draw_info()
    end

    if state == s.menu then
      menu:draw()
    end

    if state == s.play then
      draw_meter()
    end

    if map_open then
      draw_map()
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
00000000888888888888888888888888444444448888888888888888888888888888888888888888444444440000000000000000000000000000000000000000
00000000888878888889988884844488448484448944498888886688886d58888885588888666888448414440000000000000000000000000000000000000000
00000000888f7788889a7988884444884888e844840404888846d688888555888856658886ee76884881d1440000000000000000000000000000000000000000
000000008444f888889aa9888499448844888444844044888845688888445d88856dd58886eee688448814440000000000000000000000000000000000000000
0000000084448888889aa98884994888444844448444448884144888844486888565158886eee688444844440000000000000000000000000000000000000000
000000008444888888899888884488884444444484999488844888888448888885d1158888666888444444440000000000000000000000000000000000000000
00000000888888888888888888888888444444448888888888888888888888888888888888888888444444440000000000000000000000000000000000000000
00000000888888888888888888888888444444448888888888888888888888888888888888888888444444440000000000000000000000000000000000000000
333333333333333333333333333333333333333333333333333333330000000033335535535533333335666666665333bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
3333333333bb333333bbbb3333344333333bb33333333333333333330000000033335555555533333335d6dd6dd65333bbbbbbbbbbbbbbbbbbbbbbbbbbb333bb
3333333333b333b33bebebb33344443333bbbb3333333333333333330000000033335666666533333335666666665333bbbbbbbbbbbbbbbbbbbbbbbb33338333
3333333333333bb33bbbbeb33399993333bbbb3333333333333333330000000033335dd6dd6533333355dd6dd6dd5533bbbbbbbbbbbb3333bbb3333b38388383
333333333b3333333bebbbb3334444333bbbbbb333333333333333330000000033e45661166533333356666446666533bbbbbbbbbb3334433333003389898883
333333333bb33b3333bbeb33339999333334433333333333336d6d33000000003ee45d1ff1d53333335d6d44446dd533bbbbbbbb333440444444000899999883
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
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000305090000030b0901210011111111000000000000030b0901210011111111000000000000030b0901210011111111000000000000030b090121001111111100000000
0101010101000000000000000000000001010101010101000000000000000000000001010101010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
4040404040404040404040404040404040404040404040404040404040404040404040404040404040404040000000000000000000000000000000000000000040404040404040404040404040404040404040404040404040404040404040404040404040404040404040400000000000000000000000000000000000000000
4040404040404040404040404040404040404040404040404040404040404040404040404040404040404040000000000000000000000000000000000000000040404040404040404040404040404040404040404040404040404040404040404040404040404040404040400000000000000000000000000000000000000000
4040404040404040404040404040404040404040404040404040404040404040404040404040404040404040000000000000000000000000000000000000000040404040404040404040444040404040404040404040404040404040404040404042404040404040404040400000000000000000000000000000000000000000
4040424040404040404040404040404046404040404040404040464040404040404040404040404040404040000000000000000000000000000000000000000040404040404040404040414040404040404040404040404040404040404040404040404040404040404040400000000000000000000000000000000000000000
4040404040404040404040404042404040404040404040404040404040404040404040404040404044404040000000000000000000000000000000000000000040404040404040404040404040404440404040404040404040464040404040404040404040404040404040400000000000000000000000000000000000000000
4040404040404040404040404040404040404040404040404040404040404040404040404040404040404040000000000000000000000000000000000000000040404042404040404040404040404040404040404040404040404040404040404040404040404040404440400000000000000000000000000000000000000000
4040404044404040404040404040404040404040404040404040404440404040404040404040404040404040000000000000000000000000000000000000000040404040404040404040404040404040464040404040404040404040424040404040404040404040404040400000000000000000000000000000000000000000
4040404040404040404040404040404040404040404041424040404040404040404040404042404040404040000000000000000000000000000000000000000040404040404040404040404040404040404040404040404040404040404040404040404040404040404040400000000000000000000000000000000000000000
4040404040404040404040404040404040404044404040404040404040404040404040404040404040404040000000000000000000000000000000000000000040404040404040404040404040404040404040404040404040404440404040404040404040424040404040400000000000000000000000000000000000000000
4040404040404040404240404040404040404040404040404040404040404040404040404040404040404040000000000000000000000000000000000000000040404040404040404040404040404040404040424040404040404040404040404040404040404040404040400000000000000000000000000000000000000000
4040404040404040404040404040404040404040404040404040404040404040404440404040404040404040000000000000000000000000000000000000000040404040404040444040404040404040404040404040404040404040404040404040404040404040404040400000000000000000000000000000000000000000
4040404040404040404040404040404040404040404040404040404040404040404040404040404040404040000000000000000000000000000000000000000040404040404040404040404040404040404040404040404040404040404040404040404040404040404040400000000000000000000000000000000000000000
4040404040404040404040404040404040404040404040404040404040404040404040404040404040404040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4040404040404040404040404040404040404040404040404040404040404040404040404040404040404040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4040404040404040404040404140444040404040404640404040404040404040404040404040464040404040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4040404040404040444040404040404040404040404040404040404240404040404040404040404040404040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4040404040404040404040404040404040404040404040404040404040404040404040404040404041404040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4040404040404040404040404040404040404040404040404040404040404040404044404040404040404040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4040404040404640404040404040404040404040404040404040404040404040404040404040404040404041000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4040404240404040404040404040404040404040404040404040404040404040404040404040404040404040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4040404040404040404040404040404040404040404040404040404040464040404040404040404040424040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4040404040404140404040404040404040404040404340404040404040404040404040404040404041404040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4040404040404040404040404040404040404040404040404040404040404040404040404040404040414040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4040404040404040404040404046404040404040404040404040404040404040404040404040404040404040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4040404040404040404040404040404040404040404040404040404040404040404040404040424040404040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4040404040404040404040404040404040404040404040404040404040404040404040404040404040404040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4040404040404040404040404040404040404040404040404040404040404040404040404040404040404040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4040404040404040404040404040404040404040404040464040404040404040404040404040404040404040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4040464040404240404040404040404240404040404040404040414040404040404040404040404040404040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4040404040404040404040404040404040404040404040404040404044404040404040404040404440404040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4040404044404040404040404040404040404040404040414040404040404040404040464040404040404040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4040404040404040404040404040404040404040414040404040404040404040404040404040404040404040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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


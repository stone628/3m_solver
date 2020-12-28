Map = {}
Map.__index = Map

local sb = string.byte
local sc = string.char
local ss = string.sub
local ti = table.insert
local tc = table.concat

local function clone_raw_table(t)
  if t == nil then return nil end

  local cloned = {}

  for k, v in pairs(t) do cloned[k] = v end

  return cloned
end

local function inc_table(t, k)
  local prev = t[k]

  if prev == nil then
    t[k] = 1
  else
    t[k] = prev + 1
  end
end

local function shuffle_list(list, rand)
  for i = #list, 2, -1 do
    local r = rand:next_int(1, i + 1)

    list[i], list[r] = list[r], list[i]
  end
end

Map.new = function(rows)
  -- validate
  if type(rows) ~= "table" then return nil, "rows must be array of rows" end

  -- check if every row has same length
  local rows_len = #rows
  local row_lens = {}
  local rl_count = 0

  for i = 1, rows_len do
    local row = rows[i]
    local row_len = #row
    local prev = row_lens[row_len]

    if prev == nil then
      row_lens[row_len] = 0
      rl_count = rl_count + 1
    end
  end

  if rl_count == 0 then return nil, "found now row" end
  if rl_count > 1 then return nil, "inconsistent row width" end

  return setmetatable(
    {
      _width = #rows[1], _height = rows_len,
      _cells = table.concat(rows),
    }, Map)
end

function Map:dim()
  return self._width, self._height
end

function Map:clone()
  return setmetatable(
    {
      _width = self._width, _height = self._height, _cells = self._cells,
      _blocks = clone_raw_table(self._blocks),
      _created_blocks = clone_raw_table(self._created_blocks)
    },
    Map)
end

function Map:cell_at(x, y)
  if x < 0 or x >= self._width or y < 0 or y >= self._height then return nil end
  local index = y * self._width + x + 1
  return sc(sb(self._cells, index, index))
end

-- horizontal 3-match cases: [--_], [-_-], [-__], [_--], [_-_], [__-], [-- -], [- --]
-- vertical 3-match cases: mirror image using y=-x
local match_cases = {
  { -- --_
    coords = { {x = 0, y = 0}, {x = 1, y = 0}, { x = 2, y = 1} },
    mover = { coord = 3, dir_x = 0, dir_y = -1 }
  },
  { -- -_-
    coords = { {x = 0, y = 0}, {x = 1, y = 1}, { x = 2, y = 0} },
    mover = { coord = 2, dir_x = 0, dir_y = -1 }
  },
  { -- -__
    coords = { {x = 0, y = 0}, {x = 1, y = 1}, { x = 2, y = 1} },
    mover = { coord = 1, dir_x = 0, dir_y = 1 }
  },
  { -- _--
    coords = { {x = 0, y = 1}, {x = 1, y = 0}, { x = 2, y = 0} },
    mover = { coord = 1, dir_x = 0, dir_y = -1 }
  },
  { -- _-_
    coords = { {x = 0, y = 1}, {x = 1, y = 0}, { x = 2, y = 1} },
    mover = { coord = 2, dir_x = 0, dir_y = 1 }
  },
  { -- __-
    coords = { {x = 0, y = 1}, {x = 1, y = 1}, { x = 2, y = 0} },
    mover = { coord = 3, dir_x = 0, dir_y = 1 }
  },
  { -- -- -
    coords = { {x = 0, y = 0}, {x = 1, y = 0}, { x = 3, y = 0} },
    mover = { coord = 3, dir_x = -1, dir_y = 0 }
  },
  { -- - --
    coords = { {x = 0, y = 0}, {x = 2, y = 0}, { x = 3, y = 0} },
    mover = { coord = 1, dir_x = 1, dir_y = 0 }
  }
}

local function not_flipped(x, y) return x, y end
local function do_flipped(x, y) return y, x end
local function to_pos_hash(x, y) return y + x * 100 end
local function from_pos_hash(hash) return math.floor(hash / 100), hash % 100 end

local function entry_from_match_case(mc, c, r, flipped)
  local mover_coord = mc.coords[mc.mover.coord]
  local mc_offset_x, mc_offset_y = flipped(mover_coord.x, mover_coord.y)
  local mc_dir_x, mc_dir_y = flipped(mc.mover.dir_x, mc.mover.dir_y)
  local entry = { x = c + mc_offset_x, y = r + mc_offset_y, dir_x = mc_dir_x, dir_y = mc_dir_y, affected = {}}

  for i, coord in ipairs(mc.coords) do
    if i ~= mc.mover.coord then
      local affected_x, affected_y = flipped(coord.x, coord.y)
      local affected = { x = c + affected_x, y = r + affected_y }

      entry.affected[to_pos_hash(affected.x, affected.y)] = affected
    end
  end

  return entry
end

function Map:fill_blocks(block_defs, rand)
  local block_rand = {}
  local accum_ratio = 0

  self._pick_block = function(self)
    local r = rand:next_int(0, accum_ratio)

    for i, b in ipairs(block_rand) do
      if r < b.accum_ratio then
        inc_table(self._created_blocks, b.symbol)
        return b
      end
    end

    return nil
  end

  for i, block_def in ipairs(block_defs) do
    accum_ratio = accum_ratio + block_def.ratio
    ti(block_rand, { accum_ratio = accum_ratio, symbol = block_def.symbol })
  end

  local bs = {}
  local bi = 0

  self._created_blocks = {}
  self._destroyed_blocks = {}

  for r = 0, self._height - 1 do
    for c = 0, self._width - 1 do
      local cell = self:cell_at(c, r)

      if cell == "O" then
        local picked = self:_pick_block()

        if picked == nil then
          bs[bi] = "?"
        else
          bs[bi] = picked.symbol
        end
      else
        bs[bi] = cell
      end

      bi = bi + 1
    end
  end

  self._blocks = bs
end

function Map:block_at(x, y)
  if x < 0 or x >= self._width or y < 0 or y >= self._height then return nil end
  return self._blocks[y * self._width + x]
end

-- assume specified x, y are valid
function Map:_set_block_at(x, y, symbol)
  local index = y * self._width + x
  local prev = self._blocks[index]

  self._blocks[index] = symbol
  return prev
end

local function is_movable_cell(cell)
  if cell == nil then return false end
  return cell == "O"
end

local function is_blocks_matchable(lhs, rhs)
  -- TODO: consider modifier later
  if lhs == nil or rhs == nil then return false end
  return lhs == rhs
end

function Map:find_move_candidates()
  local candidates = {}
  local duplicates = {}
  local w, h = self:dim()
  local check_movable = function(mc, c, r, flipped)
    local mover = mc.mover
    local mover_coord = mc.coords[mover.coord]
    local coord_x, coord_y = flipped(mover_coord.x, mover_coord.y)
    local dir_x, dir_y = flipped(mover.dir_x, mover.dir_y)

    return is_movable_cell(self:cell_at(c + coord_x + dir_x, r + coord_y + dir_y))
  end
  local check_duplicate = function(entry)
    local hash = entry.x + entry.y * 100 + (entry.dir_x + 1) * 10000 + (entry.dir_y + 1) * 100000
    local last_entry = duplicates[hash]

    if last_entry == nil then
      duplicates[hash] = entry
      table.insert(candidates, entry)
    else
      -- merge affected
      for k, v in pairs(entry.affected) do
        last_entry.affected[k] = v
      end
    end
  end

  for r = 0, (h - 1) do
    for c = 0, (w - 1) do
      -- check for match, normal
      for i, mc in ipairs(match_cases) do
        local first_coord = mc.coords[1]
        local block = self:block_at(c + first_coord.x, r + first_coord.y)

        if block == nil then break end

        local valid = true

        for ii = 2, #mc.coords do
          local curr_coord = mc.coords[ii]
          local next_block = self:block_at(c + curr_coord.x, r + curr_coord.y)

          if next_block == nil or not is_blocks_matchable(block, next_block) then
            valid = false
            break
          end
        end

        if valid and check_movable(mc, c, r, not_flipped) then
          check_duplicate(entry_from_match_case(mc, c, r, not_flipped))
        end
      end
      -- check for match, flipped
      for i, mc in ipairs(match_cases) do
        local first_coord = mc.coords[1]
        local block = self:block_at(c + first_coord.y, r + first_coord.x)

        if block == nil then break end

        local valid = true

        for ii = 2, #mc.coords do
          local curr_coord = mc.coords[ii]
          local next_block = self:block_at(c + curr_coord.y, r + curr_coord.x)

          if next_block == nil or not is_blocks_matchable(block, next_block) then
            valid = false
            break
          end
        end

        if valid and check_movable(mc, c, r, do_flipped) then
          check_duplicate(entry_from_match_case(mc, c, r, do_flipped))
        end
      end
    end
  end

  return candidates
end

function Map:_fill_vacancy(cols_with_vacancy)
  local adds = {}

  -- refill empty blocks again
  for k, v in pairs(cols_with_vacancy) do
    -- from bottom to up, check vacancy(nil) and swap
    for r = self._height - 1, 0, -1 do
      local block = self:block_at(k, r)

      if block == nil then
        local done = false

        for rr = r - 1, 0, -1 do
          local bb = self:block_at(k, rr)

          if block ~= nil then
            -- found block, drop it (by swap)
            self:_set_block_at(k, r, self._set_block_at(k, rr, nil))
            done = true
            break
          end
        end

        if not done then
          -- need new block
          local picked = self:_pick_block()
          local add = { x = k, y = r}

          if picked == nil then
            add.symbol = "?"
          else 
            add.symbol = picked.symbol
          end

          self:_set_block_at(k, r, add.symbol)
          ti(adds, add)
        end
      end
    end
  end

  return adds
end

-- cand must be one out of candidates returned from find_move_candidates
-- apply candidate and fill vacants once
function Map:apply_move(cand, rand)
  local removes = {}
  -- apply candidate and remove affected
  local move_from_x, move_from_y = cand.x, cand.y
  local move_to_x, move_to_y = move_from_x + cand.dir_x, move_from_y + cand.dir_y
  local other_symbol = self:block_at(move_to_x, move_to_y)
  local cols_with_vacancy = {}
  local record_affected = function(x, symbol)
    if symbol then
      inc_table(self._destroyed_blocks, symbol)
      inc_table(removes, symbol)
      inc_table(cols_with_vacancy, x)
    end
  end

  -- swap mover and destroy affected blocks
  local mover_symbol = self:block_at(move_from_x, move_from_y)
  self:_set_block_at(move_from_x, move_from_y, mover_symbol)
  
  for i, v in pairs(cand.affected) do
    record_affected(v.x, self:_set_block_at(v.x, v.y, nil))
  end

  -- TODO: generate special block if affected block count exceeds 3
  -- do not generate special block for now
  self:_set_block_at(move_to_x, move_to_y, nil)
  record_affected(move_to_x, mover_symbol)

  return removes, self:_fill_vacancy(cols_with_vacancy)
end

local function check_group_index(a, b)
  if b == nil or a == b then return a end
  return b
end

function Map:check_matching(rand)
  local w, h = self:dim()
  local removes = {}
  local cols_with_vacancy = {}
  local matched_groups = {}
  local matched_group_index = 0
  local coord_to_group = {}
  local new_group = function()
    local result = {}
    local curr_index = matched_group_index

    matched_group_index = matched_group_index + 1
    matched_groups[curr_index] = result
    return result, curr_index
  end
  local record_affected = function(x, symbol)
    inc_table(self._destroyed_blocks, symbol)
    inc_table(removes, symbol)
    inc_table(cols_with_vacancy, x)
  end

  for r = 0, (h - 1) do
    for c = 0, (w - 1) do
      local start_block, hash = self:block_at(c, r), to_pos_hash(c, r)

      -- check for match, horizontal
      local h1_block = self:block_at(c + 1, r)
      local h2_block = self:block_at(c + 2, r)

      if is_blocks_matchable(start_block, h1_block) and is_blocks_matchable(start_block, h2_block) then
        local hash2, hash3 = to_pos_hash(c + 1, r), to_pos_hash(c + 2, r)
        local gi = check_group_index(
          coord_to_group[hash], 
          check_group_index(coord_to_group[hash2], coord_to_group[hash3]))
        local mg 

        if gi == nil then
          mg, gi = new_group()
        else
          mg = matched_groups[gi]
        end

        inc_table(mg, hash)
        coord_to_group[hash] = gi
        inc_table(mg, hash2)
        coord_to_group[hash2] = gi
        inc_table(mg, hash3)
        coord_to_group[hash3] = gi
      end

      -- check for match, vertical
      local v1_block = self:block_at(c, r + 1)
      local v2_block = self:block_at(c, r + 2)

      if is_blocks_matchable(start_block, v1_block) and is_blocks_matchable(start_block, v2_block) then
        local hash2, hash3 = to_pos_hash(c, r + 1), to_pos_hash(c, r + 2)
        local gi = check_group_index(
          coord_to_group[hash2], 
          check_group_index(coord_to_group[hash1], coord_to_group[hash]))

        local mg 

        if gi == nil then
          mg, gi = new_group()
        else
          mg = matched_groups[gi]
        end

        inc_table(mg, hash)
        coord_to_group[hash] = gi
        inc_table(mg, hash2)
        coord_to_group[hash2] = gi
        inc_table(mg, hash3)
        coord_to_group[hash3] = gi
      end
    end
  end

  local final_gis = {}

  for k, v in pairs(coord_to_group) do
    inc_table(final_gis, v)
  end

  for k, v in pairs(final_gis) do
    local group_count = 0

    for hash, vv in pairs(matched_groups[k]) do
      local x, y = from_pos_hash(hash)
      local symbol = self:_set_block_at(x, y, nil)

      if symbol ~= nil then
        inc_table(self._destroyed_blocks, symbol)
        inc_table(removes, symbol)
        inc_table(cols_with_vacancy, x)
      end

      group_count = group_count + 1
    end

    -- TODO: do something with group_count here
  end

  return removes, self:_fill_vacancy(cols_with_vacancy)
end

local function can_shuffle(cell, block)
  if cell == "O" then
    return true
  end
  return false
end

function Map:shuffle(rand)
  local w, h = self:dim()
  local coords = {}
  local index_bucket = {}
  local index = 1
  local changes = {}

  for r = 0, (h - 1) do
    for c = 0, (w - 1) do
      if can_shuffle(self:cell_at(c, r), self:block_at(c, r)) then
        ti(coords, to_pos_hash(c, r))
        ti(index_bucket, index)
        index = index + 1
      end
    end
  end

  shuffle_list(index_bucket, rand)
  
  for i, v in ipairs(index_bucket) do
    local from_x, from_y = from_pos_hash(coords[i])
    local to_x, to_y = from_pos_hash(coords[v])
    local from_block = self:block_at(from_x, from_y)
    local to_block = self:_set_block_at(to_x, to_y, from_block)

    self:_set_block_at(from_x, from_y, to_block)
    ti(
      changes,
      {
        from_x = from_x, from_y = from_y, from_symbol = from_block,
        to_x = to_x, to_y = to_y, to_symbol = to_block
      }
    )
  end

  return changes
end

local sf = string.format
local printf = function(fmt, ...)
  print(sf(fmt, ...))
end

function Map:print(prefix)
  local w, h = self:dim()

  prefix = prefix or ""

  for i = 1, h do
    local index_start = (i - 1) * w + 1
    local row_cells = ss(self._cells, index_start, index_start + w - 1)

    if self._blocks == nil then
      printf("%s%s", prefix, row_cells)
    else
      local row_blocks = {}

      for ii = 0, w - 1 do
        ti(row_blocks, self:block_at(ii, i - 1))
      end

      printf("%s%s  %s", prefix, row_cells, tc(row_blocks))
    end
  end
end

function Map:print_stat(prefix)
  prefix = prefix or ""
  printf("%sdim(%d x %d)", prefix, self._width, self._height)

  local created = {}

  for k, v in pairs(self._created_blocks) do
    ti(created, sf("[%s] x %d", k, v))
  end

  printf("%screated: %s", prefix, tc(created, ", "))

  local destroyed = {}

  for k, v in pairs(self._destroyed_blocks) do
    ti(destroyed, sf("[%s] x %d", k, v))
  end

  printf("%sdestroyed: %s", prefix, tc(destroyed, ", "))
end

return Map

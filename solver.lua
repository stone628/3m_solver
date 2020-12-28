require "map"
require "random"

local sf = string.format
local printf = function(fmt, ...)
  print(sf(fmt, ...))
end

local function wrap_mem_monitor(func, ...)
  collectgarbage("collect")
  local start_mem = math.floor(collectgarbage("count") * 1024)

  func(...)

  collectgarbage("collect")
  local end_mem = math.floor(collectgarbage("count") * 1024)
  printf("mem status: %dB -> %dB (%dB)", start_mem, end_mem, (end_mem - start_mem))
end

local test_map_rows = {
  "OOOOO",
  "OOOOO",
  "OO OO",
  "OOOOO",
  "OOOOO"
}
local test_block_defs = {
  { symbol = "A", ratio = 10 },
  { symbol = "B", ratio = 10 },
  { symbol = "C", ratio = 10 },
  { symbol = "D", ratio = 5 }
}
local test_random_seed = 0x99823476

local function test_map()
  local map, msg = Map.new(test_map_rows) 

  if map == nil then
    printf("init map failed: %s", msg)
    return
  end

  local rand = Random.new(test_random_seed)

  map:fill_blocks(test_block_defs, rand)

  map:print("[AFTER_INIT] ")
  rand:print("[AFTER_INIT] ")

  for try = 1, 5 do
    printf("try to match, #%d", try)
    -- start of loop
    local candidates = map:find_move_candidates()

    if #candidates > 0 then
      for i, c in ipairs(candidates) do
        local affected_count = 0

        for k, v in pairs(c.affected) do
          affected_count = affected_count + 1
        end

        c.affected_count = affected_count
        printf("candidate(%d,%d) move(%d,%d) affected:%d", c.x, c.y, c.dir_x, c.dir_y, affected_count)
      end

      local cand = candidates[1]
      local removes, adds = map:apply_move(cand)

      printf("applying candidate(%d,%d) move(%d,%d) affected:%d", cand.x, cand.y, cand.dir_x, cand.dir_y, cand.affected_count)

      for symbol, count in pairs(removes) do
        printf("removed %s x%d", symbol, count)
      end

      for i, a in ipairs(adds) do
        printf("added[%d,%d]=%s", a.x, a.y, a.symbol)
      end
    else
      -- no candidates, need random shuffle
      print("no candidates, shuffling blocks...")
      local changes = map:shuffle(rand)

      for i, c in ipairs(changes) do
        printf("shuffle(%d,%d)=%s -> (%d,%d)=%s", c.from_x, c.from_y, c.from_symbol, c.to_x, c.to_y, c.to_symbol)
      end
    end

    local prefix = sf("[TRY %d] ", try)
    local remain_try = 1
    map:print(prefix)
    rand:print(prefix)

    while (true)
    do
      print("checked remaining matching")

      local removes, adds = map:check_matching(rand)

      if #removes > 0 or #adds > 0 then
        for symbol, count in pairs(removes) do
          printf("removed %s x%d", symbol, count)
        end

        for i, a in ipairs(adds) do
          printf("added[%d,%d]=%s", a.x, a.y, a.symbol)
        end

        prefix = sf("[TRY %d REMAIN %d] ", try, remain_try)
        map:print(prefix)
        rand:print(prefix)
        remain_try = remain_try + 1
      else
        break
      end
    end
  end

  map:print_stat("[FINAL STAT] ")
end

wrap_mem_monitor(test_map)

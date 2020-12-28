Random = {}
Random.__index = Random

-- assert(min_incl < max_excl)
-- returns value and next seed
local function next_int_impl(seed, min_incl, max_excl)
  return (seed % (max_excl - min_incl)) + min_incl, (seed * 16807) % 2147483647
end

Random.next_int = next_int_impl

Random.new = function(seed)
  return setmetatable({ _curr_seed = seed, _init_seed = seed, _count = 0 }, Random)
end

function Random:init_seed()
  return self._init_seed
end

function Random:curr_seed()
  return self._curr_seed
end

function Random:count()
  return self._count
end

function Random:next_int(min_incl, max_excl)
  local result, next_seed = next_int_impl(self._curr_seed, min_incl, max_excl)

  self._curr_seed = next_seed
  self._count = self._count + 1
  return result
end

local sf = string.format
local printf = function(fmt, ...)
  print(sf(fmt, ...))
end

function Random:print(prefix)
  printf("%sRandom init:%d curr:%d count:%d", prefix or "", self._init_seed, self._curr_seed, self._count)
end

return Random

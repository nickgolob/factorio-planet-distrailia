-- Minimal busted-compatible test runner (no external dependencies).
--
-- Why this exists: a normal `busted` install needs the C module `luasystem`, which can't be
-- built on this Windows box (no compiler). This runner provides just enough of the busted /
-- luassert global API (describe / it / assert.*) to run the project's spec files under a plain
-- Lua interpreter. CI uses real `busted` instead -- the spec files are written to run under both.
--
-- Usage:  lua tools/run_specs.lua spec/a_spec.lua spec/b_spec.lua ...
-- Exit code is non-zero if any test (or spec load) fails.

-- Resolve require("lib.xxx") etc. from the repo root (this is invoked with cwd = repo root).
package.path = "./?.lua;./?/init.lua;" .. package.path

local results = { passed = 0, failed = 0, failures = {} }
local stack = {}

local function context()
  return table.concat(stack, " :: ")
end

local function fail(msg)
  error(msg or "assertion failed", 2)
end

-- luassert-compatible subset.
local assert_t = {}
function assert_t.equals(expected, actual, msg)
  if expected ~= actual then
    fail((msg or "assert.equals") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
  end
  return true
end
assert_t.equal = assert_t.equals
assert_t.are = { equal = assert_t.equals, equals = assert_t.equals }
assert_t.same = assert_t.equals
function assert_t.near(expected, actual, tol, msg)
  tol = tol or 1e-9
  if type(actual) ~= "number" or math.abs(expected - actual) > tol then
    fail((msg or "assert.near") .. ": expected ~" .. tostring(expected) ..
      " (+/- " .. tostring(tol) .. "), got " .. tostring(actual))
  end
  return true
end
function assert_t.is_true(v, msg)
  if v ~= true then fail((msg or "assert.is_true") .. ": got " .. tostring(v)) end
  return true
end
function assert_t.is_false(v, msg)
  if v ~= false then fail((msg or "assert.is_false") .. ": got " .. tostring(v)) end
  return true
end
function assert_t.is_nil(v, msg)
  if v ~= nil then fail((msg or "assert.is_nil") .. ": got " .. tostring(v)) end
  return true
end
function assert_t.is_table(v, msg)
  if type(v) ~= "table" then fail((msg or "assert.is_table") .. ": got " .. type(v)) end
  return true
end

-- Install the busted-style globals (use _G indexing so this file lints cleanly).
_G.assert = setmetatable(assert_t, {
  __call = function(_, v, msg)
    if not v then fail(msg or "assertion failed") end
    return v
  end,
})
_G.describe = function(name, fn)
  stack[#stack + 1] = name
  fn()
  stack[#stack] = nil
end
_G.it = function(name, fn)
  stack[#stack + 1] = name
  local label = context()
  stack[#stack] = nil
  local ok, err = pcall(fn)
  if ok then
    results.passed = results.passed + 1
    print("  ok   - " .. label)
  else
    results.failed = results.failed + 1
    results.failures[#results.failures + 1] = label .. "\n      " .. tostring(err)
    print("  FAIL - " .. label)
  end
end
_G.before_each = function() end
_G.after_each = function() end
_G.setup = function() end
_G.teardown = function() end

local specs = { ... }
if #specs == 0 then
  io.stderr:write("usage: lua tools/run_specs.lua <spec.lua> [<spec.lua> ...]\n")
  os.exit(2)
end

for _, path in ipairs(specs) do
  local chunk, err = loadfile(path)
  if not chunk then
    results.failed = results.failed + 1
    results.failures[#results.failures + 1] = path .. " (load error)\n      " .. tostring(err)
    print("  FAIL - load " .. path)
  else
    local ok, err2 = pcall(chunk)
    if not ok then
      results.failed = results.failed + 1
      results.failures[#results.failures + 1] = path .. " (runtime error)\n      " .. tostring(err2)
      print("  FAIL - run " .. path)
    end
  end
end

print(string.rep("-", 60))
print(string.format("Tests: %d passed, %d failed", results.passed, results.failed))
if results.failed > 0 then
  print("\nFailures:")
  for _, f in ipairs(results.failures) do
    print("  * " .. f)
  end
  os.exit(1)
end
os.exit(0)

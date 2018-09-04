-- Decompiled using luadec 2.0 standard by sztupy (http://luadec51.luaforge.net)
-- Command line was: bin.luac 

require("bit")
borad = {{1, 2, 3}, {4, 5, 6}, {7, 8, 0}}
sx = 3
sy = 3
swap_chess = function(l_1_0, l_1_1, l_1_2, l_1_3)
  local t = borad[l_1_0][l_1_1]
  borad[l_1_0][l_1_1] = borad[l_1_2][l_1_3]
  borad[l_1_2][l_1_3] = t
end

move_chess = function(l_2_0)
  if (l_2_0 == "D" and sy == 1) or l_2_0 == "A" and sy == 3 then
    return 
  end
  if l_2_0 == "S" then
    swap_chess(sx, sy, sx - 1, sy)
    sx = sx - 1
  elseif l_2_0 == "W" then
    swap_chess(sx, sy, sx + 1, sy)
    sx = sx + 1
  elseif l_2_0 == "D" then
    swap_chess(sx, sy, sx, sy - 1)
    sy = sy - 1
  elseif l_2_0 == "A" then
    swap_chess(sx, sy, sx, sy + 1)
    sy = sy + 1
  end
end

randomize = function()
  local d = {"W", "S", "A", "D"}
  math.randomseed(os.time())
  for i = 1, 1000 do
    move_chess(d[math.random(4)])
  end
end

display = function()
  local s = ""
  for x = 1, 3 do
    for y = 1, 3 do
      s = s .. "| " .. borad[x][y] .. " "
    end
    s = s .. "|\n"
    if x ~= 3 then
      s = s .. "-------------\n"
    end
  end
  s = s .. "\n"
  io.write(s)
end

secret = {171, 201, 244, 200, 118, 100, 138, 190, 170, 159, 94, 91, 42, 184, 8, 98, 198, 134, 110, 165, 108, 219, 117, 179, 180, 179, 221, 144, 167, 155}
print("i want to play a game with u")
io.read()
print("finish this game 10000000 times and i'll show u the flag, trust me")
print("use WSAD/wsad to move, ctrl+z to quit")
io.read()
times = 0
total = 10000000
repeat
  repeat
    if times < total then
      randomize()
      f = false
      os.execute("cls")
      print("times: " .. times .. "/" .. total)
      display()
      repeat
        io.write("> ")
        s = io.read()
        if s == nil then
          do return end
        end
        for i = 1, string.len(s) do
          move_chess(string.upper(string.sub(s, i, i)))
        end
        os.execute("cls")
        print("times: " .. times .. "/" .. total)
        display()
        f = true
        for i = 0, 7 do
          if borad[math.floor(i / 3) + 1][i % 3 + 1] ~= i + 1 then
            f = false
        else
          end
        end
        f = not f or borad[3][3] == 0
      until f
      if f then
        times = times + 1
        math.randomseed(times)
        for i = 1, #secret do
          secret[i] = bit.bxor(secret[i], math.random(255))
        end
      else
        os.execute("cls")
        do return end
      end
    else
      if times == total then
        os.execute("cls")
        print("congrats!")
        flag = ""
        for i,v in ipairs(secret) do
          flag = flag .. string.char(v)
        end
        print(flag)
      end
       -- Warning: missing end command somewhere! Added here
    end
     -- Warning: missing end command somewhere! Added here
  end
end


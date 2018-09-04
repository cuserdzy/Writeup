require("bit")

secret = {171, 201, 244, 200, 118, 100, 138, 190, 170, 159, 94, 91, 42, 184, 8, 98, 198, 134, 110, 165, 108, 219, 117, 179, 180, 179, 221, 144, 167, 155}

for times = 0, 9999999 do
  math.randomseed(times + 1)
  for i = 1, #secret do
    secret[i] = bit.bxor(secret[i], math.random(255))
  end
end
flag = ""
for i,v in ipairs(secret) do
  flag = flag .. string.char(v)
end
print(flag)
require("bit")

str = io.read()
unk = "gs2mx}t>{-v<pcp>\"+`v>19*%j=|g ;p{/w=\"tdg?*!!#%$)j*}."
ret = ""
Barray = {}

math.randomseed(0)

for slot3 = 0, string.len(str) - 1, 1 do
	Barray[slot3] = bit.band(bit.bxor(str:byte(slot3 + 1), math.random(128)), 95) + 32
	ret = ret .. string.char(Barray[slot3])
end

if ret == unk then
	print("Bingo")
else
	print("GG")
end

return 

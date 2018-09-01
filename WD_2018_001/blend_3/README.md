# blend
***

此题很有质量，第一次碰见`MBR`引导文件的分析。

#### MBR文件的识别

打开附件发现是`Binary File`，谷歌了下魔数，查到`MBR`引导文件，虽然魔数并不符合，但是文件正巧是`512`个字节，而且最后两个字节是`55 AA`。
再使用`010Editor`的`Driver`模板解析，发现有多种情况，可以根据`OemName`字段判断出是`MBR`文件（oemName应该是个字符串），那么前`446`个字节就是`BootCode`。

载入`IDA`，使用`16-bit`分析（`32-bit`和`16-bit`都试一试），其次需要改变基址到`0x7C00`（计算机病毒原理中有写），使用`Edit->Segments->Rebase Program`。


#### 动态调试

系统加电后会把`MBR`引导文件加载到`0x7C00`处并开始执行，查了很多文章都是用`Bochs`调试的，那么`Qemu`肯定也是可以的。
后来查到一篇类似题目的`wp`，给出了使用`Qemu`的方法，地址[CSAW CTF 2017 - Realism][2]，使用`qemu-system-i386 -drive format=raw,file=main.bin`就可以看到效果。

调试的话加上`-s`（调试参数）、`-S`（暂停在启动处）即可，`gdb`脚本:

```cpp
(gdb) target remote localhost:1234
(gdb) set arch i8086
(gdb) b *0x7c00
(gdb) c
(gdb) set disassembly-flavor intel
```
（用`gef`等工具不行，显示不出来寄存器）

之后的部分就是`gdb`的操作了。



#### 静态分析

程序使用了很多中断，我们依次来分析:

```x86asm
seg000:7C00 loc_7C00:                               ; DATA XREF: seg000:7C81↓r
seg000:7C00                 mov     ax, 13h
seg000:7C03                 int     10h             ; - VIDEO - SET VIDEO MODE
seg000:7C03                                         ; AL = mode
seg000:7C05                 mov     eax, cr0
seg000:7C08                 and     ax, 0FFFBh
seg000:7C0B                 or      ax, 2
seg000:7C0E                 mov     cr0, eax
seg000:7C11                 mov     eax, cr4
seg000:7C14                 or      ax, 600h
seg000:7C17                 mov     cr4, eax
seg000:7C1A                 mov     word ptr ds:1266h, 0Ah
```

`int 10h`是使用`BIOS`的显示服务，`AH`标识调用的功能，`AL`是模式，所以此处实际上移入的是`0013h`，但是会使得`AL = 13h`，`AH = 00h`，似乎没有此种用法，先继续往下看。
下面一部分是改变`cr0`和`cr4`寄存器的值，关于控制寄存器（`cr0`~`cr4`），它们的位数应该也是`32bit`，但似乎只用到了低`16bit`，对于`cr0`它是把第`3`位清零，并把第`2`位置`1`，对于`cr4`它是把第`10`，`11`位置`1`（从低位算起，序号从`1`开始），设置`cr0`是表示系统有协处理器，设置`cr4`是把`OSFXSR`和`OSXMMEXCPT`置`1`，前者的目的是启用多媒体指令集，后者是启用`SIMD`浮点异常。
最后是在`ds:1266h`处移入一个字`000Ah`。

```x86asm
seg000:7C20                 mov     bx, 0
seg000:7C23
seg000:7C23 loc_7C23:                               ; CODE XREF: seg000:7C2C↓j
seg000:7C23                 mov     byte ptr [bx+1234h], 5Fh ; '_'
seg000:7C28                 inc     bx
seg000:7C29                 cmp     bx, 15h
seg000:7C2C                 jle     short loc_7C23
seg000:7C2C                                         ; ;
seg000:7C2E                 mov     ds:byte_7DC8, 0
seg000:7C33
seg000:7C33 loc_7C33:                               ; CODE XREF: seg000:7CF3↓j
seg000:7C33                                         ; seg000:7D0A↓j ...
seg000:7C33                 mov     cx, 1
seg000:7C36                 xor     dx, dx
seg000:7C38
seg000:7C38 loc_7C38:                               ; CODE XREF: seg000:7CDC↓j
seg000:7C38                 mov     ah, 86h
seg000:7C3A                 int     15h             ; SYSTEM - WAIT (AT,XT2,XT286,CONV,PS)
seg000:7C3A                                         ; CX,DX = number of microseconds to wait
seg000:7C3A                                         ; Return: CF clear: after wait elapses, CF set: immediately due to error
```

以上首先是一个循环，在`ds:1234h`处移入`0x15`个下划线，可能就是要求我们输入的位置。
接着把`byte_7DC8`置`0`，最后调用`int 15h`中断，它是`BIOS`调用探测内存的功能，但是我查了一下`ah = 86h`时似乎是`delay`。

```x86asm
seg000:7C3C loc_7C3C:                               ; DATA XREF: seg000:loc_7CDF↓w
seg000:7C3C                 add     byte ptr ds:1278h, 10h
seg000:7C41                 mov     ax, 1300h
seg000:7C44                 mov     bh, 0
seg000:7C46                 mov     bl, ds:1278h
seg000:7C4A                 mov     cx, 10h
seg000:7C4D                 mov     dx, 90Ch
seg000:7C50                 mov     bp, 7D60h
seg000:7C53                 int     10h             ; - VIDEO - WRITE STRING (AT,XT286,PS,EGA,VGA)
seg000:7C53                                         ; AL = mode, BL = attribute if AL bit 1 clear, BH = display page number
seg000:7C53                                         ; DH,DL = row,column of starting cursor position, CX = length of string
seg000:7C53                                         ; ES:BP -> start of string
seg000:7C55                 mov     ax, 1300h
seg000:7C58                 mov     bx, 0Fh
seg000:7C5B                 mov     cx, 14h
seg000:7C5E                 mov     dx, 0C0Ah
seg000:7C61                 mov     bp, 1234h
seg000:7C64                 int     10h             ; - VIDEO - WRITE STRING (AT,XT286,PS,EGA,VGA)
seg000:7C64                                         ; AL = mode, BL = attribute if AL bit 1 clear, BH = display page number
seg000:7C64                                         ; DH,DL = row,column of starting cursor position, CX = length of string
seg000:7C64                                         ; ES:BP -> start of string
```

以上调用两次`int 10h`就是显示字符串，有关它的参数参考[利用BIOS 中断INT 0x10显示字符和字符串][3]，所以第一次显示的字符串是`7D60h`处的字符串，`== ENTER FLAG ==`，长度为`16`，`dx`标识该字符串的位置是第`9`行，第`12`列，感觉字符串闪烁是和`bx`相关，但是资料上语焉不详。
第二次显示字符串同理，它是把`1234h`处的`20`个下划线显示出来。

```x86asm
seg000:7C66                 cmp     ds:byte_7DC8, 13h
seg000:7C6B                 jle     loc_7D0D
```

此处若`byte_7DC8`小于等于`0x13`，则会跳转走，应该是长度判断，若长度已经等于`0x14`，则会进入`check`流程。

```x86asm
seg000:7D0D loc_7D0D:                               ; CODE XREF: seg000:7C6B↑j
seg000:7D0D                 mov     ah, 1
seg000:7D0F                 int     16h             ; KEYBOARD - CHECK BUFFER, DO NOT CLEAR
seg000:7D0F                                         ; Return: ZF clear if character in buffer
seg000:7D0F                                         ; AH = scan code, AL = character
seg000:7D0F                                         ; ZF set if no character in buffer
seg000:7D11                 jz      short loc_7D4A
seg000:7D13                 xor     ah, ah
seg000:7D15                 int     16h             ; KEYBOARD - READ CHAR FROM BUFFER, WAIT IF EMPTY
seg000:7D15                                         ; Return: AH = scan code, AL = character
seg000:7D17                 cmp     al, 8
seg000:7D19                 jz      short loc_7D31
seg000:7D1B                 cmp     al, 0Dh
seg000:7D1D                 jz      short loc_7D4A
seg000:7D1F                 mov     bx, 1234h
seg000:7D22                 mov     cl, ds:byte_7DC8
seg000:7D26                 add     bx, cx
seg000:7D28                 mov     [bx], al
seg000:7D2A                 inc     ds:byte_7DC8
seg000:7D2E                 jmp     loc_7C33
seg000:7D31 ; ---------------------------------------------------------------------------
seg000:7D31
seg000:7D31 loc_7D31:                               ; CODE XREF: seg000:7D19↑j
seg000:7D31                 cmp     ds:byte_7DC8, 1
seg000:7D36                 jl      loc_7C33
seg000:7D3A                 mov     ax, 1234h
seg000:7D3D                 dec     ds:byte_7DC8
seg000:7D41                 mov     bl, ds:byte_7DC8
seg000:7D45                 add     bx, ax
seg000:7D47                 mov     byte ptr [bx], 5Fh ; '_'
seg000:7D4A
seg000:7D4A loc_7D4A:                               ; CODE XREF: seg000:7D11↑j
seg000:7D4A                                         ; seg000:7D1D↑j
seg000:7D4A                 jmp     loc_7C33
seg000:7D4D ; ---------------------------------------------------------------------------
seg000:7D4D
seg000:7D4D loc_7D4D:                               ; CODE XREF: seg000:7C78↑j
seg000:7D4D                                         ; seg000:7CBA↑j
seg000:7D4D                 mov     byte ptr ds:1278h, 4
seg000:7D52                 mov     di, 7D80h
seg000:7D55                 jmp     short loc_7CDF
```

若长度判断跳转成功，则会来到此处，`int 16h`是调用键盘服务，当`ah = 1`时是用来查询键盘缓冲区，且不等待，若缓冲区有字符，`ZF`置`0`，反之置`1`，读入的字符保存在`al`中，可以看到，程序首先扫描键盘的缓冲区，若读到字符，直接跳转到`loc_7D4A`，若没有字符，则等待输入，并判断字符类型，若等于`8`（退格），跳转到`loc_7D31`执行退格流程，若等于`13`（归位），直接跳转到`loc_7D4A`，若都不是，则把当前循环变量处的字符替换，同样的，退格流程也是做字符替换，最后都会跳转到`loc_7C33`，重新显示字符串。
扫描键盘缓冲区的系统调用似乎没什么用，即使读到了字符也不会显示出来，更不会使循环变量自加。
下面来看`check`流程:

```x86asm
seg000:7C6F                 cmp     dword ptr ds:1234h, 'galf'
seg000:7C78                 jnz     loc_7D4D
```

首先就会判断前`4`个字符是否是`flag`，若不是，直接跳转到`loc_7D4D`，来看一下判断失败时程序的执行流程:

```x86asm
seg000:7D4D loc_7D4D:                               ; CODE XREF: seg000:7C78↑j
seg000:7D4D                                         ; seg000:7CBA↑j
seg000:7D4D                 mov     byte ptr ds:1278h, 4
seg000:7D52                 mov     di, 7D80h
seg000:7D55                 jmp     short loc_7CDF
```

把`4`移入`1278h`，并把`7D80h`移入`di`，跳转到`loc_7CDF`。

```x86asm
seg000:7CDF loc_7CDF:                               ; CODE XREF: seg000:7CD1↑j
seg000:7CDF                                         ; seg000:7D55↓j
seg000:7CDF                 mov     byte ptr ds:loc_7C3C+1, 0
seg000:7CE4                 mov     word ptr ds:1266h, 0Ah
seg000:7CEA                 xor     bh, bh
seg000:7CEC                 mov     bl, ds:byte_7DC9
seg000:7CF0                 cmp     bx, 10h
seg000:7CF3                 jge     loc_7C33
seg000:7CF7                 mov     cl, [bx+di]
seg000:7CF9                 mov     [bx+7D60h], cl
seg000:7CFD                 inc     ds:byte_7DC9
seg000:7D01                 mov     dword ptr [bx+7D61h], '>== '
seg000:7D0A                 jmp     loc_7C33
```

此部分不断把`loc_7C3C+1`处的字节置`0`，不太明白，然后若`byte_7DC9`处的值大于等于`0x10`，则跳转，否则把`bx+di`处的字符移入`bx+7D60`处，最后把`>== `移入`bx+0x7D61`处。
看起来是比较绕，但我们仔细看一下，它是不断把错误提示的字符移入`7D60`处，每次循环都有一个`delay`，于是就会显示出字符串依次铺开的效果，当`16`个字符显示完毕后，程序就会进入死循环的状态，实际上就是实现了一个动画效果。
继续看`check`流程:

```x86asm
seg000:7C7C                 movaps  xmm0, xmmword ptr ds:1238h
seg000:7C81                 movaps  xmm5, xmmword ptr ds:loc_7C00
seg000:7C86                 pshufd  xmm0, xmm0, 1Eh
seg000:7C8B                 mov     si, 8
```

此处是把后`16`个字节全部移入`xmm0`，并把`0x7C00`处的`16`个字节移入`xmm5`，多媒体指令集需要调试一下，静态分析的结果不一定准确。
`pshufd`是压缩双字乱序，网上讲得不太详细，其实它是根据第三个操作数来乱序的，它先把第三个操作数转成二进制，那么此处的`1E`就是`00 01 11 10`，同时把源操作数和目的操作数都分成`4`个双字，并把前面得到的`4`个数当作下标，最后根据下标把源操作数映射到目的操作数即可。
最后把`8`移入`si`中。

```x86asm
seg000:7C8E loc_7C8E:                               ; CODE XREF: seg000:7CC1↓j
seg000:7C8E                 movaps  xmm2, xmm0
seg000:7C91                 andps   xmm2, xmmword ptr [si+7D90h]
seg000:7C96                 psadbw  xmm5, xmm2
seg000:7C9A                 movaps  xmmword ptr ds:1268h, xmm5
seg000:7C9F                 mov     di, ds:1268h
seg000:7CA3                 shl     edi, 10h
seg000:7CA7                 mov     di, ds:1270h
seg000:7CAB                 mov     dx, si
seg000:7CAD                 dec     dx
seg000:7CAE                 add     dx, dx
seg000:7CB0                 add     dx, dx
seg000:7CB2                 cmp     edi, [edx+7DA8h]
seg000:7CBA                 jnz     loc_7D4D
seg000:7CBE                 dec     si
seg000:7CBF                 test    si, si
seg000:7CC1                 jnz     short loc_7C8E
```

以上是一个循环。
乱序后的用户输入异或上`[si+7D90h]`处的数据，实际上就是把第`1`个和第`9`个字节清零。
`psadbw`要比前面的`pshufd`更复杂些，它是把源操作数和目的操作数对应的`8`个字节作差，再取绝对值并求和，得到的结果保存在低`16`位中，剩下的`6`个字节全部清零，因为寄存器有`128bit`，所以会分为高`8`个字节和低`8`个字节。
后面是先取低`8`个字节的结果移入`di`，然后把`edi`右移`16bit`，接着再取高`8`个字节移入`di`，目的就是组成`edi`，最后是计算`4 * (dx - 1)`，并与`4 * (dx - 1) + 7DA8h`处的存储的明码比较，也就是取出一个`Dword`。

```x86asm
seg000:7CC3                 mov     byte ptr ds:1278h, 0Ah
seg000:7CC8                 mov     bx, ds:1266h
seg000:7CCC                 mov     di, 7D70h
seg000:7CCF                 test    bx, bx
seg000:7CD1                 jz      short loc_7CDF
seg000:7CD3                 dec     word ptr ds:1266h
seg000:7CD7                 xor     cx, cx
seg000:7CD9                 mov     dx, 14h
seg000:7CDC                 jmp     loc_7C38
```

若正常退出循环，说明输入正确，`7D70h`保存着正确提示字符串，后面就是把正确提示输出。


#### 解密算法

整个程序的流程已经很清楚了，大概是先对用户输入乱序，然后进入一个循环，~~循环内先将第`1`和第`9`个字节清零~~此处就出错了，它是和`[si+7D90h]`处的`16`个字节相与，`si`每轮循环是自减的，所以每次清零的都不固定，分析一下，每次都是第`i`和第`i + 8`个字节清零（`i`是当前轮数），然后和上一次的结果求绝对值差的和（第一次是和一个初值），所以很明显就是`16`个方程，整理得到:

```cpp
//...同下
```
（由低到高的`16`个字节分别使用`a~p`来标识，是非字节序时的顺序）

既然涉及到方程，那么使用`z3`是一个不错的解法，脚本:

```python
from z3 import *

def abs(x):
  return If(x >= 0,x,-x)

a = Int('a')
b = Int('b')
c = Int('c')
d = Int('d')
e = Int('e')
f = Int('f')
g = Int('g')
h = Int('h')
i = Int('i')
j = Int('j')
k = Int('k')
l = Int('l')
m = Int('m')
n = Int('n')
o = Int('o')
p = Int('p')

s = Solver()
s.add(a >= 30)
s.add(b >= 30)
s.add(c >= 30)
s.add(d >= 30)
s.add(e >= 30)
s.add(f >= 30)
s.add(g >= 30)
s.add(h >= 30)
s.add(i >= 30)
s.add(j >= 30)
s.add(k >= 30)
s.add(l >= 30)
s.add(m >= 30)
s.add(n >= 30)
s.add(o >= 30)
s.add(p >= 30)

s.add(a <= 127)
s.add(b <= 127)
s.add(c <= 127)
s.add(d <= 127)
s.add(e <= 127)
s.add(f <= 127)
s.add(g <= 127)
s.add(h <= 127)
s.add(i <= 127)
s.add(j <= 127)
s.add(k <= 127)
s.add(l <= 127)
s.add(m <= 127)
s.add(n <= 127)
s.add(o <= 127)
s.add(p <= 127)

s.add(abs(0-0xb8) + abs(b-0x13) + abs(c-0x00) + abs(d-0xcd) + abs(e-0x10) + abs(f-0x0f) + abs(g-0x20) + abs(h-0xc0) == 0x311)
s.add(abs(0-0x83) + abs(j-0xe0) + abs(k-0xfb) + abs(l-0x83) + abs(m-0xc8) + abs(n-0x02) + abs(o-0x0f) + abs(p-0x22) == 0x304)
s.add(abs(a-0x11) + abs(0-0x03) + abs(c-0x00) + abs(d-0x00) + abs(e-0x00) + abs(f-0x00) + abs(g-0x00) + abs(h-0x00) == 0x2d9)
s.add(abs(i-0x04) + abs(0-0x03) + abs(k-0x00) + abs(l-0x00) + abs(m-0x00) + abs(n-0x00) + abs(o-0x00) + abs(p-0x00) == 0x2cd)
s.add(abs(a-0xd9) + abs(b-0x02) + abs(0-0x00) + abs(d-0x00) + abs(e-0x00) + abs(f-0x00) + abs(g-0x00) + abs(h-0x00) == 0x2d4)
s.add(abs(i-0xcd) + abs(j-0x02) + abs(0-0x00) + abs(l-0x00) + abs(m-0x00) + abs(n-0x00) + abs(o-0x00) + abs(p-0x00) == 0x2db)
s.add(abs(a-0xd4) + abs(b-0x02) + abs(c-0x00) + abs(0-0x00) + abs(e-0x00) + abs(f-0x00) + abs(g-0x00) + abs(h-0x00) == 0x2c4)
s.add(abs(i-0xdb) + abs(j-0x02) + abs(k-0x00) + abs(0-0x00) + abs(m-0x00) + abs(n-0x00) + abs(o-0x00) + abs(p-0x00) == 0x2e2)
s.add(abs(a-0xc4) + abs(b-0x02) + abs(c-0x00) + abs(d-0x00) + abs(0-0x00) + abs(f-0x00) + abs(g-0x00) + abs(h-0x00) == 0x2ce)
s.add(abs(i-0xe2) + abs(j-0x02) + abs(k-0x00) + abs(l-0x00) + abs(0-0x00) + abs(n-0x00) + abs(o-0x00) + abs(p-0x00) == 0x2e2)
s.add(abs(a-0xce) + abs(b-0x02) + abs(c-0x00) + abs(d-0x00) + abs(e-0x00) + abs(0-0x00) + abs(g-0x00) + abs(h-0x00) == 0x2d8)
s.add(abs(i-0xe2) + abs(j-0x02) + abs(k-0x00) + abs(l-0x00) + abs(m-0x00) + abs(0-0x00) + abs(o-0x00) + abs(p-0x00) == 0x2ed)
s.add(abs(a-0xd8) + abs(b-0x02) + abs(c-0x00) + abs(d-0x00) + abs(e-0x00) + abs(f-0x00) + abs(0-0x00) + abs(h-0x00) == 0x2dc)
s.add(abs(i-0xed) + abs(j-0x02) + abs(k-0x00) + abs(l-0x00) + abs(m-0x00) + abs(n-0x00) + abs(0-0x00) + abs(p-0x00) == 0x2e8)
s.add(abs(a-0xdc) + abs(b-0x02) + abs(c-0x00) + abs(d-0x00) + abs(e-0x00) + abs(f-0x00) + abs(g-0x00) + abs(0-0x00) == 0x2dd)
s.add(abs(i-0xe8) + abs(j-0x02) + abs(k-0x00) + abs(l-0x00) + abs(m-0x00) + abs(n-0x00) + abs(o-0x00) + abs(0-0x00) == 0x2f6)

if s.check() == sat:
    ret = s.model()
    flag = chr(int(str(ret[a]))) + chr(int(str(ret[b]))) + chr(int(str(ret[c]))) + chr(int(str(ret[d]))) + chr(int(str(ret[e]))) + chr(int(str(ret[f]))) + chr(int(str(ret[g]))) + chr(int(str(ret[h]))) + chr(int(str(ret[i]))) + chr(int(str(ret[j]))) + chr(int(str(ret[k]))) + chr(int(str(ret[l]))) + chr(int(str(ret[m]))) + chr(int(str(ret[n]))) + chr(int(str(ret[o]))) + chr(int(str(ret[p])))

print flag[12:] + flag[8:12] + flag[0:4] + flag[4:8]
```

解得`mbr_is_funny__eh`，答案略坑，两个下划线，以为做错了。
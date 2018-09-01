# RUA

看到`go_buildid`函数，查了一下发现是`Go`语言，又查了一些`Go`语言的逆向分析教程，发现的确是`Go`语言，第一次接触`Go`语言，需要学习的东西就很多了。

 - `Go`语言的安装与编译
 - `Go`程序启动流程

后来发现文件解密后是个`Luajit`字节码文件，才感觉此题有意思的东西很多，值得研究:

 - `Lua`、`luac`和`LuaJIT`
 - `LuaJIT`反汇编

#### Go语言的安装与编译

因为此题是`pe+`文件。所以我们下载`windows`下的安装包（实际上`golang`是可以跨平台编译的），若使用安装版的话（`.msi`），环境变量也不需要手动设置。
使用`go build [filename]`编译。

#### Go程序启动流程

不同于`C/C++`，`Go`语言没有`start`函数，它其实是从`_rt0_amd64_windows`开始执行（不同的平台名称是不一样的）:

```x86asm
.text:00000000004525C0                 lea     rsi, [rsp+arg_0]
.text:00000000004525C5                 mov     rdi, [rsp+0]
.text:00000000004525C9                 lea     rax, main
.text:00000000004525D0                 jmp     rax
```

在程序启动之前，加载器会把参数和环境变量入栈，无论对于什么语言来说，只要使用的是同一个加载器，便遵循该规则。
所以`[rsp+arg_0]`中是`argv`，`[rsp+0]`中是`argc`，把它们用作参数，跳转（调用）`main`，此处你会发现，`windows`下使用的却是`linux`的调用约定，可见调用约定并不是操作系统决定的。
以上有一个疑问，为什么传`argv`时使用的是`lea`? 很简单，加载器是依次把参数入栈的，而不是压入一个字符串数组的首地址，而`argv`的定义是`char *[]`，所以肯定需要使用`lea`来传地址。
再来看`main`函数:

```x86asm
.text:00000000004525E0                 lea     rax, runtime_rt0_go
.text:00000000004525E7                 jmp     rax
```

简单地跳转到`runtime_rt0_go`，在`runtime_rt0_go`中会完成不少工作。
首先会判断是否是`intel`的`cpu`:

```x86asm
.text:000000000044ECD6                 xor     eax, eax
.text:000000000044ECD8                 cpuid
.text:000000000044ECDA                 mov     esi, eax
.text:000000000044ECDC                 cmp     eax, 0
.text:000000000044ECDF                 jz      loc_44EDE6
.text:000000000044ECE5                 cmp     ebx, 'uneG'
.text:000000000044ECEB                 jnz     short loc_44ED0B
.text:000000000044ECED                 cmp     edx, 'Ieni'
.text:000000000044ECF3                 jnz     short loc_44ED0B
.text:000000000044ECF5                 cmp     ecx, 'letn'
.text:000000000044ECFB                 jnz     short loc_44ED0B
.text:000000000044ECFD                 mov     cs:runtime_isIntel, 1
.text:000000000044ED04                 mov     cs:runtime_lfenceBeforeRdtsc, 1
```

若是，则把`runtime_isIntel`和`runtime_lfenceBeforeRdtsc`置`1`。
注意`eax`传入的是功能号，当功能号为`0`时，`eax`返回`cpu`所支持的最大功能号，`ebx`，`edx`，`ecx`返回一个字符串，可以看到上面会先判断所支持的最大功能号，若为`0`，直接跳过后面对于`cpu`类型的判断，反之则继续判断`cpu`类型。

```x86asm
.text:000000000044ED0B loc_44ED0B:                             ; CODE XREF: runtime_rt0_go+4B↑j
.text:000000000044ED0B                                         ; runtime_rt0_go+53↑j ...
.text:000000000044ED0B                 mov     eax, 1
.text:000000000044ED10                 cpuid
.text:000000000044ED12                 mov     cs:runtime_processorVersionInfo, eax
.text:000000000044ED18                 test    edx, 4000000h
.text:000000000044ED1E                 setnz   cs:runtime_support_sse2
.text:000000000044ED25                 test    ecx, 200h
.text:000000000044ED2B                 setnz   cs:runtime_support_ssse3
.text:000000000044ED32                 test    ecx, 80000h
.text:000000000044ED38                 setnz   cs:runtime_support_sse41
.text:000000000044ED3F                 test    ecx, 100000h
.text:000000000044ED45                 setnz   cs:runtime_support_sse42
.text:000000000044ED4C                 test    ecx, 800000h
.text:000000000044ED52                 setnz   cs:runtime_support_popcnt
.text:000000000044ED59                 test    ecx, 2000000h
.text:000000000044ED5F                 setnz   cs:runtime_support_aes
.text:000000000044ED66                 test    ecx, 8000000h
.text:000000000044ED6C                 setnz   cs:runtime_support_osxsave
.text:000000000044ED73                 test    ecx, 10000000h
.text:000000000044ED79                 setnz   cs:runtime_support_avx
```

接下来继续调用`cpuid`，此次功能号是`1`，`eax`返回`cpu`的家族型号，`ecx`和`edx`返回的是基本功能信息，可以看见其后都在对它们进行判断，以得到`cpu`所支持的功能。

```x86asm
.text:000000000044ED80                 cmp     esi, 7
.text:000000000044ED83                 jl      short loc_44EDC2
.text:000000000044ED85                 mov     eax, 7
.text:000000000044ED8A                 xor     ecx, ecx
.text:000000000044ED8C                 cpuid
.text:000000000044ED8E                 test    ebx, 8
.text:000000000044ED94                 setnz   cs:runtime_support_bmi1
.text:000000000044ED9B                 test    ebx, 20h
.text:000000000044EDA1                 setnz   cs:runtime_support_avx2
.text:000000000044EDA8                 test    ebx, 100h
.text:000000000044EDAE                 setnz   cs:runtime_support_bmi2
.text:000000000044EDB5                 test    ebx, 200h
.text:000000000044EDBB                 setnz   cs:runtime_support_erms
```

以上是判断`cpu`所支持的最大功能号，若小于`7`则跳转走，反之传入功能号`7`并调用`cpuid`，不太清楚其功能，暂时不分析。
后面就不再继续分析了，到最后会调用`runtime_newproc`，目的是创建一个`goroutine`，并把`runtime_main`函数放入就绪线程队列中，之后调用`runtime_mstart`调度该`goroutine`，此时`runtime_main`被调用，而在`main_runtime`中又会调用`main_main`，它就是我们最终要找的`main`函数。
（以上到最后已经非常不详细了。。。未完待续）


#### **题目分析**

从`main_main`函数分析:

```x86asm
.text:0000000000495200                 mov     rcx, gs:28h
.text:0000000000495209                 mov     rcx, [rcx+0]
.text:0000000000495210                 cmp     rsp, [rcx+10h]
.text:0000000000495214                 jbe     loc_4952A4

......

.text:00000000004952A4 loc_4952A4:                             ; CODE XREF: main_main+14↑j
.text:00000000004952A4                 call    runtime_morestack_noctxt
.text:00000000004952A9                 jmp     main_main
```

在`Go`语言中，很多函数都有类似的循环，到底是什么意思呢? 首先需要弄懂`gs`寄存器的意义，查了一下似乎是在`x64`下`fs`寄存器被`gs`寄存器取代了，

继续往下分析:

```x86asm
.text:000000000049521A                 sub     rsp, 40h
.text:000000000049521E                 mov     [rsp+40h+var_8], rbp
.text:0000000000495223                 lea     rbp, [rsp+40h+var_8]

.text:0000000000495228                 lea     rax, byte_4C6B39
.text:000000000049522F                 mov     [rsp+40h+var_40], rax
.text:0000000000495233                 mov     [rsp+40h+var_38], 0Dh
.text:000000000049523C                 call    main_ReadAll
.text:0000000000495241                 mov     rax, [rsp+40h+var_30]
.text:0000000000495246                 mov     rcx, [rsp+40h+var_28]
.text:000000000049524B                 mov     rdx, [rsp+40h+var_20]
```

此处调用了`main_ReadAll`函数，从函数名就可以猜出是读文件的操作，文件名字符串保存在`byte_4C6B39`（`ruaruarua.out`），但是`IDA`并没有分析出来，我猜测是因为`Go`生成的目标文件中的字符串不是用`\0`结尾的，所以才导致`IDA`分析不出来，后面的`0Dh`就是字符串的长度。
需要注意的是最前面的三条指令，它们实际上是在开辟栈帧，首先抬高栈顶，接着把`rbp`移入`[rsp+40h+var_8]`中，最后把`[rsp+40h+var_8]`的地址移入`rbp`，仔细走一遍流程你会发现它们实际上执行的流程和一般开辟栈帧的步骤是一模一样的:

```x86asm
push    rbp
mov     rbp, rsp
sub     rsp, 38h
```

似乎是神仙优化把`push`指令也优化掉了。
后面压入参数也是一样的，没有使用`push`指令，而是把参数直接移入栈顶。
理解了程序怎么传参，但是仍然没有找到返回值是从哪里传出的，后来想到结构体的传参，是直接把返回值放入栈中，那就很容易理解了，该函数返回了一个具有三个字段的结构体，从调试来看，分别是字节数组，长度和一个未知的标志。
继续往下看:

```x86asm
.text:0000000000495250                 mov     [rsp+40h+var_40], rax
.text:0000000000495254                 mov     [rsp+40h+var_38], rcx
.text:0000000000495259                 mov     [rsp+40h+var_30], rdx
.text:000000000049525E                 call    main_InfoIntegration
.text:0000000000495263                 mov     rax, [rsp+40h+var_28]
.text:0000000000495268                 mov     rcx, [rsp+40h+var_20]
.text:000000000049526D                 mov     rdx, [rsp+40h+var_18]
.text:0000000000495272                 lea     rbx, byte_4C62FB
.text:0000000000495279                 mov     [rsp+40h+var_40], rbx
.text:000000000049527D                 mov     [rsp+40h+var_38], 0Ah
.text:0000000000495286                 mov     [rsp+40h+var_30], rax
.text:000000000049528B                 mov     [rsp+40h+var_28], rcx
.text:0000000000495290                 mov     [rsp+40h+var_20], rdx
.text:0000000000495295                 call    main_WriteAll
```

`main_ReadAll`的返回值作为`main_InfoIntegration`的参数，该函数返回的应该仍是一个结构体，最后调用`main_WriteAll`把字节数组写入文件`ruayoufool`中。
可见`main_InfoIntegration`就是关键函数，调试会发现程序在某处调用`os_Exit`直接退出，那剩下的写入文件操作就更不会执行了。
从该函数头看起:

```x86asm
.text:0000000000494EF8                 mov     rax, cs:main_kernel
.text:0000000000494EFF                 mov     [rsp+58h+var_18], rax
.text:0000000000494F04                 lea     rcx, qword_4B76C0
.text:0000000000494F0B                 mov     [rsp+58h+var_58], rcx
.text:0000000000494F0F                 call    runtime_newobject
.text:0000000000494F14                 mov     rax, [rsp+58h+var_50]
.text:0000000000494F19                 mov     [rsp+58h+var_10], rax

.text:0000000000494F1E                 mov     ecx, cs:runtime_writeBarrier
.text:0000000000494F24                 lea     rdx, [rax+18h]
.text:0000000000494F28                 test    ecx, ecx
.text:0000000000494F2A                 jnz     loc_495118
.text:0000000000494F30                 mov     rcx, [rsp+58h+var_18]
.text:0000000000494F35                 mov     [rax+18h], rcx
```

此部分没怎么看懂，取出来的`main_kernel`是一个堆上的地址，接着调用`runtime_newobject`得到的也是一个堆上的地址，分别把两个地址移入`[rsp+58h+var_18]`和`[rsp+58h+var_10]`中。
然后判断`runtime_writeBarrier`，若不为零则跳，调试时得到的是零，所以不跳，接着把`main_kernel`的值移入新建对象的`+18h`处。

```x86asm
.text:0000000000494F39 loc_494F39:                             ; CODE XREF: main_InfoIntegration+260↓j
.text:0000000000494F39                 mov     qword ptr [rax+10h], 0Ch
.text:0000000000494F41                 mov     ecx, cs:runtime_writeBarrier
.text:0000000000494F47                 lea     rdx, [rax+8]
.text:0000000000494F4B                 test    ecx, ecx
.text:0000000000494F4D                 jnz     loc_4950F9
.text:0000000000494F53                 lea     rcx, aCgocallNilclos+232h ; "GetTickCountJoin_ControlKernel32.dllLoa"...
.text:0000000000494F5A                 mov     [rax+8], rcx
```

接下来把`0Ch`移入新建对象的`+10h`处，再次判断`runtime_writeBarrier`，若不为零则跳，此处也是不跳的，把`rcx`移入新建对象的`+8h`处。

```x86asm
.text:0000000000494F5E loc_494F5E:                             ; CODE XREF: main_InfoIntegration+243↓j
.text:0000000000494F5E                 mov     [rsp+58h+var_58], rax
.text:0000000000494F62                 mov     [rsp+58h+var_50], 0
.text:0000000000494F6B                 mov     [rsp+58h+var_48], 0
.text:0000000000494F74                 mov     [rsp+58h+var_40], 0
.text:0000000000494F7D                 call    syscall___LazyProc__Call
.text:0000000000494F82                 mov     rax, [rsp+58h+var_38]
```

以上是把新建对象作参数，以及另外三个参数，调用`syscall_LazyProc_Call`，根据字符串，我猜测调用的可能是`GetTickCount`，因为每次调试得到的结果都不一样，但总是在增长的，可能我们需要一个正确的时间戳。
后面是很复杂的计算，而且和时间戳有关，可以分为三个部分，依次来看:

```x86asm
.text:0000000000494F87                 imul    rax, 0F4240h
.text:0000000000494F8E                 mov     rcx, rax
.text:0000000000494F91                 mov     rax, 9C5FFF26ED75ED55h
.text:0000000000494F9B                 imul    rcx
.text:0000000000494F9E                 lea     rax, [rcx+rdx]
.text:0000000000494FA2                 mov     rdx, rcx
.text:0000000000494FA5                 sar     rcx, 3Fh
.text:0000000000494FA9                 sar     rax, 29h
.text:0000000000494FAD                 sub     rax, rcx
.text:0000000000494FB0                 mov     rbx, 34630B8A000h
.text:0000000000494FBA                 imul    rbx, rax
.text:0000000000494FBE                 mov     rsi, rdx
.text:0000000000494FC1                 sub     rdx, rbx
.text:0000000000494FC4                 xorps   xmm0, xmm0
.text:0000000000494FC7                 cvtsi2sd xmm0, rdx
.text:0000000000494FCC                 movsd   xmm1, cs:$f64_428a3185c5000000
.text:0000000000494FD4                 divsd   xmm0, xmm1
.text:0000000000494FD8                 xorps   xmm1, xmm1
.text:0000000000494FDB                 cvtsi2sd xmm1, rax
.text:0000000000494FE0                 addsd   xmm0, xmm1
.text:0000000000494FE4                 xorps   xmm1, xmm1
.text:0000000000494FE7                 ucomisd xmm0, xmm1
.text:0000000000494FEB                 jnz     short loc_494FF3
.text:0000000000494FED                 jnp     loc_49508C
```

太复杂，只能先不管它们，假设三处判断都是不跳的，那么最后会来到`loc_49508C`处:

```x86asm
.text:000000000049508C loc_49508C:                             ; CODE XREF: main_InfoIntegration+11D↑j
.text:000000000049508C                                         ; main_InfoIntegration+171↑j ...
.text:000000000049508C                 mov     rax, [rsp+58h+arg_0]
.text:0000000000495091                 mov     rcx, [rsp+58h+arg_8]
.text:0000000000495096                 mov     edx, 1
.text:000000000049509B                 jmp     short loc_4950B6
.text:000000000049509D ; ---------------------------------------------------------------------------
.text:000000000049509D
.text:000000000049509D loc_49509D:                             ; CODE XREF: main_InfoIntegration+1F2↓j
.text:000000000049509D                 movzx   ebx, byte ptr [rdx+rax-1]
.text:00000000004950A2                 movzx   esi, dl
.text:00000000004950A5                 xor     rbx, rsi
.text:00000000004950A8                 movzx   esi, byte ptr [rax+rdx]
.text:00000000004950AC                 xor     rsi, rbx
.text:00000000004950AF                 mov     [rax+rdx], sil
.text:00000000004950B3                 inc     rdx
.text:00000000004950B6
.text:00000000004950B6 loc_4950B6:                             ; CODE XREF: main_InfoIntegration+1CB↑j
.text:00000000004950B6                 cmp     rdx, rcx
.text:00000000004950B9                 jge     short loc_4950C6
.text:00000000004950BB                 lea     rbx, [rdx-1]
.text:00000000004950BF                 cmp     rbx, rcx
.text:00000000004950C2                 jb      short loc_49509D
.text:00000000004950C4                 jmp     short loc_495135
```

此处是一个循环，循环变量初值为`1`，若大于等于长度则直接跳走，循环内部就是循环变量异或上前一个字节和当前字节，循环结束后跳转到`loc_4950C6`:

```x86asm
.text:00000000004950C6 loc_4950C6:                             ; CODE XREF: main_InfoIntegration+1E9↑j
.text:00000000004950C6                 mov     [rsp+58h+arg_18], rax
.text:00000000004950CB                 mov     [rsp+58h+arg_20], rcx
.text:00000000004950D3                 mov     rax, [rsp+58h+arg_10]
.text:00000000004950D8                 mov     [rsp+58h+arg_28], rax
.text:00000000004950E0                 mov     rbp, [rsp+58h+var_8]
.text:00000000004950E5                 add     rsp, 58h
.text:00000000004950E9                 retn
```

把传入的字节数组原封不动地传出。
所以说，三处复杂的判断应该是假的，真正加密流程非常简单，就是简单的异或，所以我们把最后一处判断的`jnz`改成`jz`即可。
最后就能得到输出的`ruayoufool`文件了。

#### 算法分析

由于第一个字节是没有变换的（`cipher[i] = plain[i] ^ plain[i - 1] ^ i`），所以求逆就很简单了:

```c
//rua.c
#include <stdio.h>
#include <stdint.h>

int main() {
        FILE *fp = fopen("./ruayoufool", "rb");
        uint8_t buf[439];
        fread(buf, 1, 439, fp);
    fclose(fp);
        
    uint8_t tmp[439];
    tmp[0] = buf[0];
    for(int i = 1; i < 439; i++) {
        tmp[i] = i ^ buf[i - 1] ^ buf[i];
    }
    fp = fopen("./bin", "wb");
    fwrite(tmp, 1, 439, fp);
    fclose(fp);
}
```

（用`python`是真的累）

我以为得到的文件是一个图片或者源码，但是似乎是一个`raw bin`，用`010Editor`打开发现文件尾部有字符串，感觉像是个可执行文件，没想到是个`Luajit`编译得到的字节码文件（查魔数）。


#### Lua、Luac和LuaJIT

`Lua`是一个小巧的脚本语言，是用标准`C`编写的，所以具有跨平台的特性，和`Python`类似的，`Lua`也有对应的字节码文件`Luac`，其解析方法网上有很多教程。
而`LuaJIT`是另一个支持`JIT`方式的`Lua`编译器，`LuaJIT`扩展了原生指令，并更改了`opcode`和操作数的排列方式。

#### LuaJIT反汇编

首先下载`Lua`，解压后进入相应目录，执行`make linux test`，`sudo make install`即可（若出现`readline`错误，先安装`sudo apt-get install libreadline6 libreadline6-dev`）。
再下载`LuaJIT`，解压后进入相应目录，执行`make`，`sudo make install`即可。

使用`luajit -bl [input] [output]`就可以将字节码文件反汇编，但是并不容易看懂，再来考虑`LuaJIT`字节码文件的反编译。
在网上找了一圈教程，找到一个修正后的`ljd`（`LuaJIT`反编译器），地址[LuaJIT反编译总结][1]，但是对于此题会报错，猜测可能是不同版本的`opcode`不同的原因（我使用的是`LuaJIT-2.0.5`）。
`opcode`的定义在`/LuaJIT-2.0.5/src/lj_bc.h`中（从`#define BCDEF(_)`往后），我们需要保证`/ljd-master/ljd/bytecode/instructions.py`和`/ljd-master/ljd/rawdump/code.py`中的`opcode`和前面的一致。

改的时候发现新版本就是新增了一些`opcode`，直接把新增的`opcode`注释掉即可。
最后使用`python3 main.py [input] >> [output]`，得到:

```lua
//rua.lua
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
```

`Lua`是使用`require`来加载模块的，接着使用`io.read`读入用户输入，`math.randomseed`是设置随机数种子，接着是一个循环，循环内部每次调用`bit.band`（也就是`bit-and`，即按位与），相与的两个值是按位异或的结果和`95`，最后加上`32`赋给`Barray[slot3]`。
循环结束后就把`ret`和`unk`比较，若一致就输出正确的信息，有按位与的话爆破比较容易。
使用`luagit [filename]`，使用`lua [filename]`会缺`bit`模块，跑出来得到`102, 90, 76, 97, 11, 85, 44, 95, 55, 73, 15, 8, 125, 91, 23, 125, 36, 46, 61, 87, 74, 103, 58, 24, 85, 28, 77, 19, 107, 75, 4, 108, 7, 107, 81, 106, 24, 33, 118, 41, 11, 46, 118, 4, 87, 96, 71, 16, 18, 5, 64, 89`，所以爆破脚本:

```lua
//rua.lua
require("bit")

unk = "gs2mx}t>{-v<pcp>\"+`v>19*%j=|g ;p{/w=\"tdg?*!!#%$)j*}."

arr = {1, 31, 83, 10, 35, 47, 33, 127, 41, 120, 23, 110, 5, 2, 81, 63, 35, 103, 12, 58, 82, 125, 85, 102, 73, 6, 113, 9, 38, 127, 10, 3, 4, 73, 67, 83, 93, 50, 49, 4, 116, 27, 111, 70, 124, 81, 48, 122, 30, 67, 30, 115, 48, 53, 96, 46, 49, 29, 10, 76, 87, 56, 106, 5, 85, 33, 96, 109, 22, 97, 56, 52, 19, 66, 60, 63, 11, 107, 113, 71, 66, 13, 47, 92, 1, 17, 11, 114, 12, 41, 81, 84, 63, 46, 102, 55, 3, 28, 108, 51}

--math.randomseed(0)

for i = 0, string.len(unk) - 1, 1 do

    rnd = arr[i + 1]--math.random(128)

    for j = 32, 128, 1 do

        tmp = bit.band(bit.bxor(j, rnd), 95) + 32

        if tmp == unk:byte(i+1) then

            io.write(string.char(j))
            --break

        end

    end

end

return 
```

后来发现怎么算都不对，实在没办法只能去查`wp`，发现不同版本的`Lua`生成的竟然随机数不一样! 也是无语了，我用的是`Lua-5.3.4`，后来截取了`wp`中的序列，解得`flag`是`FfLlAaGg[{RrUuAaRrUuAaRrUuAa!!!LlLlLlLlLlLlLlLlLlLlUuAa_1Ss_Ff4Nn_FfUuCcKk1NnGg_Tt4SsTtIiCc]}`，似乎是有多解，若不把`break`注释掉，会得到`FLAG[RUARUARUA!!!LLLLLLLLLLUA_1S_F4N_FUCK1NG_T4STIC]`。
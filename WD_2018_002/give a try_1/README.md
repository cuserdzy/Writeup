# give a try

### 程序流程分析

首先找到消息处理函数`sub_401103`:

```x86asm
.text:0040110C                 push    [ebp+Str]       ; Str
.text:0040110F                 call    ds:strlen
.text:00401115                 add     esp, 4
.text:00401118                 cmp     eax, 2Ah
.text:0040111B                 jz      short loc_401134
```

此处会判断用户输入的长度，应该等于`2Ah`，之后跳转。

```x86asm
.text:00401134 loc_401134:                             ; CODE XREF: sub_401103+18↑j
.text:00401134                 xor     edi, edi
.text:00401136                 mov     esi, [ebp+Str]
.text:00401139                 lodsb
.text:0040113A                 jmp     short loc_401142
.text:0040113C ; ---------------------------------------------------------------------------
.text:0040113C
.text:0040113C loc_40113C:                             ; CODE XREF: sub_401103+41↓j
.text:0040113C                 movzx   eax, al
.text:0040113F                 add     edi, eax
.text:00401141                 lodsb
.text:00401142
.text:00401142 loc_401142:                             ; CODE XREF: sub_401103+37↑j
.text:00401142                 or      al, al
.text:00401144                 jnz     short loc_40113C
```

以上是一个循环，`lodsb`是把`si:di`指向的字符串加载到`al`寄存器，

```x86asm
.text:00401146                 xor     edi, dword_40406C
.text:0040114C                 push    edi
.text:0040114D                 call    ds:srand
.text:00401153                 add     esp, 4
.text:00401156                 xor     ebx, ebx
.text:00401158                 mov     esi, [ebp+Str]
.text:0040115B                 lea     edi, dword_4030B4
.text:00401161                 jmp     loc_4011E9

......

.text:004011E9 loc_4011E9:                             ; CODE XREF: sub_401103+5E↑j
.text:004011E9                 cmp     ebx, 2Ah
.text:004011EC                 jnz     loc_401166
```

以上也是一个循环，把`dword_40406C`（未知值）和`edi`异或后作为`srand`的种子，接着`ebx`清零，当作循环变量，`edi`中保存的是`dword_4030B4`的地址，是一段明码，用于最后的比较。
中间是一大段计算，我们可以直接看一下伪码:

```cpp
  for ( i = 0; i != 42; ++i )
  {
    v6 = (unsigned __int8)Str[i] * rand();
    v7 = v6 * (unsigned __int64)v6 % 0xFAC96621;
    v8 = v7 * (unsigned __int64)v7 % 0xFAC96621;
    v9 = v8 * (unsigned __int64)v8 % 0xFAC96621;
    v10 = v9 * (unsigned __int64)v9 % 0xFAC96621;
    v11 = v10 * (unsigned __int64)v10 % 0xFAC96621;
    v12 = v11 * (unsigned __int64)v11 % 0xFAC96621;
    v13 = v12 * (unsigned __int64)v12 % 0xFAC96621;
    v14 = v13 * (unsigned __int64)v13 % 0xFAC96621;
    v15 = v14 * (unsigned __int64)v14 % 0xFAC96621;
    v16 = v15 * (unsigned __int64)v15 % 0xFAC96621;
    v17 = v16 * (unsigned __int64)v16 % 0xFAC96621;
    v18 = v17 * (unsigned __int64)v17 % 0xFAC96621;
    v19 = v18 * (unsigned __int64)v18 % 0xFAC96621;
    v20 = v19 * (unsigned __int64)v19 % 0xFAC96621;
    v21 = v20 * (unsigned __int64)v20 % 0xFAC96621;
    if ( v6 % 0xFAC96621 * (unsigned __int64)v21 % 0xFAC96621 != dword_4030B4[i] )
      break;
  }
```

~~典型的可以用`Pin`来跑了，可以在题目做完后尝试一下。~~
此算法是不断对前一个数求平方并模上`0xFAC96621`，最后和明码比对，算法很简单，唯一需要解决的是`dword_40406C`的值，查找它的交叉引用，可以找到`tls`回调函数，中间有反调试，具体来分析一下:

```x86asm
pizza:00402000                 push    ebp
pizza:00402001                 mov     ebp, esp
pizza:00402003                 push    ebx
pizza:00402004                 push    esi
pizza:00402005                 push    edi
pizza:00402006                 call    $+5
pizza:0040200B                 add     [esp+10h+var_10], 17h
pizza:00402012                 retn
pizza:00402012 TlsCallback_0   endp ; sp-analysis failed
pizza:00402012
pizza:00402012 ; ---------------------------------------------------------------------------
pizza:00402013 aWatchUrStep    db 'Watch ur step!',0
pizza:00402022 ; ---------------------------------------------------------------------------
pizza:00402022                 cmp     dword ptr [ebp+0Ch], 1
pizza:00402026                 jnz     loc_4020F0
```

它是使用比较巧的方法，首先`call`一个地址，程序会把`call`指令的下一条指令入栈，接着对`[esp]`的内容加上`0x17`，那么再执行`retn`时，`pop`出来的就是改变后的返回地址，即跳转到`loc_402022`，`dword ptr [ebp+0Ch]`取到的似乎是参数，应该等于`1`。

```x86asm
pizza:0040202C                 call    loc_402032
pizza:0040202C ; ---------------------------------------------------------------------------
pizza:00402031                 db 0C2h
pizza:00402032 ; ---------------------------------------------------------------------------
pizza:00402032
pizza:00402032 loc_402032:                             ; CODE XREF: pizza:0040202C↑j
pizza:00402032                 add     dword ptr [esp], 6
pizza:00402036                 retn
pizza:00402037 ; ---------------------------------------------------------------------------
pizza:00402037                 xor     esi, esi
pizza:00402039                 mov     edi, offset sub_4020F7
pizza:0040203E                 call    loc_402044
pizza:0040203E ; ---------------------------------------------------------------------------
pizza:00402043                 db 0E8h
pizza:00402044 ; ---------------------------------------------------------------------------
pizza:00402044
pizza:00402044 loc_402044:                             ; CODE XREF: pizza:0040203E↑j
pizza:00402044                 add     dword ptr [esp], 6
pizza:00402048                 retn
pizza:00402049 ; ---------------------------------------------------------------------------
pizza:00402049                 pushf
pizza:0040204A                 test    dword ptr [esp], 100h
pizza:00402051                 cmovnz  edi, esi
pizza:00402054                 popf
```

以上都是故技重施，真正执行的内容就是把`esi`清零，把`sub_4020F7`的地址移入`edi`，最后是执行`pushf`把标志寄存器入栈，比较是否为`100h`，若是则把`esi`移入`edi`，相当于清零，再把标志寄存器出栈。

```x86asm
pizza:00402055                 call    loc_40205B
pizza:00402055 ; ---------------------------------------------------------------------------
pizza:0040205A                 db 82h
pizza:0040205B ; ---------------------------------------------------------------------------
pizza:0040205B
pizza:0040205B loc_40205B:                             ; CODE XREF: pizza:00402055↑j
pizza:0040205B                 add     dword ptr [esp], 6
pizza:0040205F                 retn
pizza:00402060 ; ---------------------------------------------------------------------------
pizza:00402060                 mov     eax, large fs:30h
pizza:00402066                 test    dword ptr [eax], 10000h
pizza:0040206C                 cmovnz  edi, esi
pizza:0040206F                 call    loc_402075
pizza:0040206F ; ---------------------------------------------------------------------------
pizza:00402074                 db 0Fh
pizza:00402075 ; ---------------------------------------------------------------------------
pizza:00402075
pizza:00402075 loc_402075:                             ; CODE XREF: pizza:0040206F↑j
pizza:00402075                 add     dword ptr [esp], 6
pizza:00402079                 retn
pizza:0040207A ; ---------------------------------------------------------------------------
pizza:0040207A                 call    GetCurrentThread
pizza:0040207F                 call    loc_402085
pizza:0040207F ; ---------------------------------------------------------------------------
pizza:00402084                 db 81h
pizza:00402085 ; ---------------------------------------------------------------------------
pizza:00402085
pizza:00402085 loc_402085:                             ; CODE XREF: pizza:0040207F↑j
pizza:00402085                 add     dword ptr [esp], 6
pizza:00402089                 retn
```

以上同样是花指令，真正执行的部分是判断`fs:30h`和`10000h`，接着调用`GetCurrentThread`。

```x86asm
pizza:0040208A                 push    0
pizza:0040208C                 push    0
pizza:0040208E                 push    11h
pizza:00402090                 push    eax
pizza:00402091                 call    NtSetInformationThread
pizza:00402096                 call    loc_40209C
pizza:00402096 ; ---------------------------------------------------------------------------
pizza:0040209B                 align 4
pizza:0040209C
pizza:0040209C loc_40209C:                             ; CODE XREF: pizza:00402096↑j
pizza:0040209C                 add     dword ptr [esp], 6
pizza:004020A0                 retn
pizza:004020A1 ; ---------------------------------------------------------------------------
pizza:004020A1                 call    GetCurrentProcess
pizza:004020A6                 mov     ebx, eax
pizza:004020A8                 call    loc_4020AE
pizza:004020A8 ; ---------------------------------------------------------------------------
pizza:004020AD                 db 80h
pizza:004020AE ; ---------------------------------------------------------------------------
pizza:004020AE
pizza:004020AE loc_4020AE:                             ; CODE XREF: pizza:004020A8↑j
pizza:004020AE                 add     dword ptr [esp], 6
pizza:004020B2                 retn
```

此部分调用`NtSetInformationThread`，调用该函数时程序直接结束，经查是一个反调试函数，它把第二个参数设置为`11h`时，是告诉操作系统`ThreadHideFromDebugger`，即取消所有附加调试器（可以改变第二个参数来反反调试），接着再调用`GetCurrentProcess`，其返回值移入`ebx`。

```x86asm
pizza:004020B3                 push    0
pizza:004020B5                 push    4
pizza:004020B7                 push    offset dword_40406C
pizza:004020BC                 push    7
pizza:004020BE                 push    ebx
pizza:004020BF                 call    NtQueryInformationProcess
pizza:004020C4                 cmp     eax, 0
pizza:004020C7                 cmovb   edi, esi
pizza:004020CA                 call    loc_4020D0
pizza:004020CA ; ---------------------------------------------------------------------------
pizza:004020CF                 db 5
pizza:004020D0 ; ---------------------------------------------------------------------------
pizza:004020D0
pizza:004020D0 loc_4020D0:                             ; CODE XREF: pizza:004020CA↑j
pizza:004020D0                 add     dword ptr [esp], 6
pizza:004020D4                 retn
pizza:004020D5 ; ---------------------------------------------------------------------------
pizza:004020D5                 cmp     dword_40406C, 0
pizza:004020DC                 cmovnz  edi, esi
pizza:004020DF                 call    loc_4020E5
pizza:004020DF ; ---------------------------------------------------------------------------
pizza:004020E4                 db 0B8h
pizza:004020E5 ; ---------------------------------------------------------------------------
pizza:004020E5
pizza:004020E5 loc_4020E5:                             ; CODE XREF: pizza:004020DF↑j
pizza:004020E5                 add     dword ptr [esp], 6
pizza:004020E9                 retn
pizza:004020EA ; ---------------------------------------------------------------------------
pizza:004020EA                 mov     dword_404036, edi
pizza:004020F0
pizza:004020F0 loc_4020F0:                             ; CODE XREF: pizza:00402026↑j
pizza:004020F0                 pop     edi
pizza:004020F1                 pop     esi
pizza:004020F2                 pop     ebx
pizza:004020F3                 leave
pizza:004020F4                 retn    0Ch
```

此部分调用`NtQueryInformationProcess`，它也是一个反调试函数，当第二个参数设置为`07h`（`ProcessDebugPort`），`1Eh`（`DebugObjectHandle`），`1Fh`（`ProcessDebugFlags`）时，是查询一些反调试相关的成员，比如此处传入的是7，若在调试中，那么在第三个参数处得到`-1`，反之为`0`，接着会判断`NtQueryInformationProcess`的返回值和接收到`ProcessDebugPort`，此处把`loc_4020DC`处的`cmovnz`改成`cmovz`即可。
最后把`edi`（正常情况下是`004020F7`）移入`dword_404036`，在`sub_4020F7`下断，是会断下来的，原因不明。

对于`sub_4020F7`就不再分析，其中仍调用了`NtQueryInformationProcess`，但似乎没有影响什么，只是使得`dword_40406C`等于`4`，后面再是两个异或，得到的应该是一个定值`31333359h`。


#### 算法分析

感觉爆破是不切实际的，因为随机数种子和所有字符的和有关，那么`Pin`也就是不可能的，因为逐字符判断的话是不能决定字符和的。
后来想了一下似乎可以爆破，因为之前我们看到一个有意思的字符串`The flag begins with "flag{"`（在`0040210A`处），也就是说前`5`个字符肯定是`flag{`，那就有意思了，我们可以直接爆破出随机数序列的前`5`个数，而字符和被限定在`42 * 32 ~ 42 * 127`中，那我们又可以爆破字符和，得到字符和后，再回去爆破后面的字符。
注意脚本必须在`Windows`下跑（`srand`/`rand`的问题），后来又想到`rand`的返回值范围是不确定的，那就不能爆破了，查了一下发现其范围是由`RAND_MAX`决定的，将其输出得到`32767`，应该仍在允许爆破的范围之内，脚本:

```c
//try.cpp

```

当脚本怎么调试都是错误的时候，才意识到`IDA`反编译出的伪码是错误的，来看汇编找到它的错误到底在哪里:

```x86asm
.text:00401166                 call    ds:rand
.text:0040116C                 movzx   ecx, byte ptr [ebx+esi]
.text:00401170                 mul     ecx
.text:00401172                 mov     ecx, 0FAC96621h
.text:00401177                 push    eax
.text:00401178                 xor     edx, edx
.text:0040117A                 div     ecx
.text:0040117C                 pop     eax
.text:0040117D                 push    edx
.text:0040117E                 mul     eax
.text:00401180                 div     ecx
.text:00401182                 mov     eax, edx
.text:00401184                 mul     edx

......

.text:004011D4                 div     ecx
.text:004011D6                 mov     eax, edx
.text:004011D8                 mul     edx

.text:004011DA                 div     ecx
.text:004011DC                 mov     eax, edx
.text:004011DE                 pop     edx
.text:004011DF                 mul     edx

.text:004011E1                 div     ecx
```

以上是循环体，首先把`rand`得到的随机数和当前字符相乘，高位保存在`edx`，低位保存在`eax`，接着把低位除以`0FAC96621h`，商保存在`eax`，余数保存在`edx`，此处是`IDA`第一个错的地方，模应该要加上括号，否则优先级错误，然后`mul  eax`，也就是余数和余数相乘（因为之前把乘法结果入栈了，乘法结果总是小于模数的，所以除法的余数总是等于乘法结果，最后把乘法结果出栈，和自己相乘，就相当于余数相乘）。
接下来的部分，把上一步的乘法结果除以`0FAC96621h`后，是余数和余数相乘，此是`IDA`伪码出错的第二个地方。
最后一部分，很明显可以根据`div`分成三个部分，此处`IDA`也分析错误了。
所以伪码不一定是正确的，改正后的脚本:

```cpp
//try.cpp
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <time.h>

uint32_t Calc(uint32_t initial) {
    uint64_t tmp = (uint64_t)(initial % 0xFAC96621) * (initial % 0xFAC96621);
    tmp = (uint64_t)(tmp % 0xFAC96621) * (tmp % 0xFAC96621);
    tmp = (uint64_t)(tmp % 0xFAC96621) * (tmp % 0xFAC96621);
    tmp = (uint64_t)(tmp % 0xFAC96621) * (tmp % 0xFAC96621);
    tmp = (uint64_t)(tmp % 0xFAC96621) * (tmp % 0xFAC96621);
    tmp = (uint64_t)(tmp % 0xFAC96621) * (tmp % 0xFAC96621);
    tmp = (uint64_t)(tmp % 0xFAC96621) * (tmp % 0xFAC96621);
    tmp = (uint64_t)(tmp % 0xFAC96621) * (tmp % 0xFAC96621);
    tmp = (uint64_t)(tmp % 0xFAC96621) * (tmp % 0xFAC96621);
    tmp = (uint64_t)(tmp % 0xFAC96621) * (tmp % 0xFAC96621);
    tmp = (uint64_t)(tmp % 0xFAC96621) * (tmp % 0xFAC96621);
    tmp = (uint64_t)(tmp % 0xFAC96621) * (tmp % 0xFAC96621);
    tmp = (uint64_t)(tmp % 0xFAC96621) * (tmp % 0xFAC96621);
    tmp = (uint64_t)(tmp % 0xFAC96621) * (tmp % 0xFAC96621);
    tmp = (uint64_t)(tmp % 0xFAC96621) * (tmp % 0xFAC96621);
    tmp = (uint64_t)(tmp % 0xFAC96621) * (tmp % 0xFAC96621);
    tmp = (uint64_t)(tmp % 0xFAC96621) * initial;
    return tmp % 0xFAC96621;
}

int main() {
    char flag[] = { 'f', 'l', 'a', 'g', '{' };
    uint32_t cmp[] = { 0x63B25AF1, 0xC5659BA5 ,0x4C7A3C33, 0xE4E4267, 0xB611769B };
    uint32_t rnd[5];
    for (uint32_t i = 0; i < 5; i++) {
        for (uint32_t j = 0; j < RAND_MAX; j++) {
            if (Calc(flag[i] * j) == cmp[i]) {
                rnd[i] = j;
                break;
            }
        }
    }

    for (int i = 32 * 42; i <= 127 * 42; i++) {
        srand(0x31333359 ^ i);
        int j = 0;
        for (j = 0; j < 5; j++) {
            uint32_t tmp = rand();
            if (tmp != rnd[j]) {
                break;
            }
        }
        if (j == 5) {
            printf("%d", i);
        }
    }
}
```

（以上脚本是把字符和爆破出来）


很快就能解得字符和是`3681`，那么剩下的就方便了，直接爆破，脚本:

```cpp
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <time.h>

uint32_t Calc(uint32_t initial) {
    uint64_t tmp = (uint64_t)(initial % 0xFAC96621) * (initial % 0xFAC96621);
    tmp = (uint64_t)(tmp % 0xFAC96621) * (tmp % 0xFAC96621);
    tmp = (uint64_t)(tmp % 0xFAC96621) * (tmp % 0xFAC96621);
    tmp = (uint64_t)(tmp % 0xFAC96621) * (tmp % 0xFAC96621);
    tmp = (uint64_t)(tmp % 0xFAC96621) * (tmp % 0xFAC96621);
    tmp = (uint64_t)(tmp % 0xFAC96621) * (tmp % 0xFAC96621);
    tmp = (uint64_t)(tmp % 0xFAC96621) * (tmp % 0xFAC96621);
    tmp = (uint64_t)(tmp % 0xFAC96621) * (tmp % 0xFAC96621);
    tmp = (uint64_t)(tmp % 0xFAC96621) * (tmp % 0xFAC96621);
    tmp = (uint64_t)(tmp % 0xFAC96621) * (tmp % 0xFAC96621);
    tmp = (uint64_t)(tmp % 0xFAC96621) * (tmp % 0xFAC96621);
    tmp = (uint64_t)(tmp % 0xFAC96621) * (tmp % 0xFAC96621);
    tmp = (uint64_t)(tmp % 0xFAC96621) * (tmp % 0xFAC96621);
    tmp = (uint64_t)(tmp % 0xFAC96621) * (tmp % 0xFAC96621);
    tmp = (uint64_t)(tmp % 0xFAC96621) * (tmp % 0xFAC96621);
    tmp = (uint64_t)(tmp % 0xFAC96621) * (tmp % 0xFAC96621);
    tmp = (uint64_t)(tmp % 0xFAC96621) * initial;
    return tmp % 0xFAC96621;
}

int main() {
    /*char flag[] = { 'f', 'l', 'a', 'g', '{' };
    uint32_t cmp[] = { 0x63B25AF1, 0xC5659BA5 ,0x4C7A3C33, 0xE4E4267, 0xB611769B };
    uint32_t rnd[5];
    for (uint32_t i = 0; i < 5; i++) {
        for (uint32_t j = 0; j < RAND_MAX; j++) {
            if (Calc(flag[i] * j) == cmp[i]) {
                rnd[i] = j;
                break;
            }
        }
    }

    for (int i = 32 * 42; i <= 127 * 42; i++) {
        srand(0x31333359 ^ i);
        int j = 0;
        for (j = 0; j < 5; j++) {
            uint32_t tmp = rand();
            if (tmp != rnd[j]) {
                break;
            }
        }
        if (j == 5) {
            printf("%d", i);
        }
    }*/
    unsigned int unk_4030B4[42] = {
        0x63B25AF1, 0xC5659BA5, 0x4C7A3C33, 0x0E4E4267, 0xB611769B, 0x3DE6438C, 0x84DBA61F, 0xA97497E6,
        0x650F0FB3, 0x84EB507C, 0xD38CD24C, 0xE7B912E0, 0x7976CD4F, 0x84100010, 0x7FD66745, 0x711D4DBF,
        0x5402A7E5, 0xA3334351, 0x1EE41BF8, 0x22822EBE, 0xDF5CEE48, 0xA8180D59, 0x1576DEDC, 0xF0D62B3B,
        0x32AC1F6E, 0x9364A640, 0xC282DD35, 0x14C5FC2E, 0xA765E438, 0x7FCF345A, 0x59032BAD, 0x9A5600BE,
        0x5F472DC5, 0x5DDE0D84, 0x8DF94ED5, 0xBDF826A6, 0x515A737A, 0x4248589E, 0x38A96C20, 0xCC7F61D9,
        0x2638C417, 0xD9BEB996
    };
    srand(0x31333359 ^ 3681);
    for (int i = 0; i < 42; i++) {
        uint32_t rnd = rand();
        for (int j = 30; j < 127; j++) {
            if (Calc(j * rnd) == unk_4030B4[i]) {
                printf("%c", j);
                break;
            }
        }
    }
}
```

解得`flag`是`flag{wh3r3_th3r3_i5_@_w111-th3r3_i5_@_w4y}`。
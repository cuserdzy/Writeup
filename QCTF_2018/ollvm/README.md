# Ollvm

此题要求的一个基本技能就是阅读源码，剩下的就是考汇编功底。

#### 读源码的技巧

该程序没有剔除符号信息，所以我们可以看到很多`gmp`的字样，那么肯定是使用了`gmp`库，该库是开源的，我使用的版本是`gmp-6.1.2`（`gmp.h`需要另行下载）。
`gmp`库的目录是很有层次性的，它基本上是一个操作对应着一个源文件，把操作都定义在头文件当中。
我们以第一个函数为例，即`call    _ZN10__gmp_exprIA1_12__mpz_structS1_EC2Ei ; __gmp_expr<__mpz_struct [1],__mpz_struct [1]>::__gmp_expr(int)`，可以看到`IDA`已经帮助我们解析了，那么调用的函数实际上就是`__gmp_expr<__mpz_struct [1],__mpz_struct [1]>::__gmp_expr(int)`，可以看到它是一个成员函数，而且和`__mpz_struct`结构体有关，该结构体的定义在`gmp.h`中:

```cpp
typedef struct
{
  int _mp_alloc;        /* Number of *limbs* allocated and pointed
                   to by the _mp_d field.  */
  int _mp_size;         /* abs(_mp_size) is the number of limbs the
                   last field points to.  If _mp_size is
                   negative this is a negative number.  */
  mp_limb_t *_mp_d;     /* Pointer to the limbs.  */
} __mpz_struct;
```

我们暂时不知道该结构体是做什么的，再从函数定义来看，发现也看不出来调用的是什么函数，此时可以步入函数，看看是否有线索，你会发现函数内部实际上是调用了`___gmpz_init_set_si`，我们可以在`gmp.h`的`862`行找到它的声明，并在`mpz`目录下的`iset_si.c`找到它的定义:

```cpp
#include "gmp.h"
#include "gmp-impl.h"

void
mpz_init_set_si (mpz_ptr dest, signed long int val)
{
  mp_size_t size;
  mp_limb_t vl;

  ALLOC (dest) = 1;
  PTR (dest) = __GMP_ALLOCATE_FUNC_LIMBS (1);

  vl = (mp_limb_t) ABS_CAST (unsigned long int, val);

  PTR (dest)[0] = vl & GMP_NUMB_MASK;
  size = vl != 0;

#if GMP_NAIL_BITS != 0
  if (vl > GMP_NUMB_MAX)
    {
      MPZ_REALLOC (dest, 2);
      PTR (dest)[1] = vl >> GMP_NUMB_BITS;
      size = 2;
    }
#endif

  SIZ (dest) = val >= 0 ? size : -size;
}
```

看起来是比较难以理解的，我们需要到`gmp.h`和`gmp-impl.h`去查找一些内建函数和定义。。。（未完待续）。
以上是找源码位置的技巧，若是要阅读源码，仍需要深厚的语言功底才行，`gmp`在官网上给出了它的官方文档，可以大致猜测一下调用的函数的用途。

正式分析前，大致看了下伪码，感觉可以把程序分为四个部分，第一部分是判断输入合法性的部分，中间两个是计算的部分，最后是判断结果的部分，因为程序比较冗长，我们依次来分析。

#### 第一部分的分析

看到题目的第一眼，以为是经`ollvm`混淆的程序，但后来仔细分析了一下发现并没有控制流平坦化（可能是混淆失败了，也可能是`ollvm`中其它的混淆方式）。

`main`函数中首先会判断参数个数，用户输入长度（`0x26`）:

```x86asm
.text:00000000004014B0                 push    rbp
.text:00000000004014B1                 mov     rbp, rsp
.text:00000000004014B4                 sub     rsp, 2090h
.text:00000000004014BB                 mov     [rbp+ret], 0
.text:00000000004014C2                 mov     [rbp+argc], edi
.text:00000000004014C5                 mov     [rbp+argv], rsi
.text:00000000004014C9                 cmp     [rbp+argc], 2
.text:00000000004014CD                 jz      loc_4014F6
.text:00000000004014D3                 mov     rdi, offset format ; "Command line parameter error."
.text:00000000004014DD                 mov     al, 0
.text:00000000004014DF                 call    _printf
.text:00000000004014E4                 mov     [rbp+ret], 0
.text:00000000004014EB                 mov     [rbp+unuse_0], eax
.text:00000000004014F1                 jmp     loc_40342B
.text:00000000004014F6 ; ---------------------------------------------------------------------------
.text:00000000004014F6
.text:00000000004014F6 loc_4014F6:                             ; CODE XREF: main+1D↑j
.text:00000000004014F6                 mov     rax, [rbp+argv]
.text:00000000004014FA                 mov     rdi, [rax+8]    ; s
.text:00000000004014FE                 call    _strlen
.text:0000000000401503                 cmp     rax, 26h
.text:0000000000401507                 jz      loc_401530      ;
.text:0000000000401507                                         ; ;
.text:000000000040150D                 mov     rdi, offset aFlagRequire38C ; "flag require 38 chars"
.text:0000000000401517                 mov     al, 0
.text:0000000000401519                 call    _printf
.text:000000000040151E                 mov     [rbp+ret], 0
.text:0000000000401525                 mov     [rbp+unuse_1], eax
.text:000000000040152B                 jmp     loc_40342B
```

值得关注的地方不多，`[rbp+ret]`总是会被莫名其妙地置`0`，并在函数返回时移入`eax`，可能就是为了返回`0`而设置的。
`[rbp+unuse_x]`之类是除了保存返回值，而在其它地方都没有用到的局部变量，所以把它们称为`unuse`，可以不关注。


#### 第二部分的分析

此部分涉及到`gmp`库中的函数，从`loc_401530`起:

```x86asm
.text:0000000000401530 loc_401530:                             ; CODE XREF: main+57↑j
.text:0000000000401530                 mov     [rbp+i], 0
.text:0000000000401537                 mov     [rbp+j], 0      ;
.text:0000000000401537                                         ; ;初始化二重循环的循环变量
.text:000000000040153E                 lea     rdi, [rbp+bignum_1]
.text:0000000000401542                 mov     esi, 1
.text:0000000000401547                 call    _ZN10__gmp_exprIA1_12__mpz_structS1_EC2Ei ; __gmp_expr<__mpz_struct [1],__mpz_struct [1]>::__gmp_expr(int)
.text:000000000040154C ;   try {
.text:000000000040154C                 lea     rdi, [rbp+bignum_2]
.text:0000000000401550                 call    _ZN10__gmp_exprIA1_12__mpz_structS1_EC2Ev ; __gmp_expr<__mpz_struct [1],__mpz_struct [1]>::__gmp_expr(void)
.text:0000000000401550 ;   } // starts at 40154C
.text:0000000000401555                 jmp     $+5
```

首先是初始化二重循环的循环变量（后面会用到），然后移入参数调用`___gmpz_init_set_si`，它是初始化一个大数并为其赋初值，`[rbp+bignum_1]`就是该大数结构体的地址，正巧是`16`个字节。
后面又会调用`___gmpz_init`把`[rbp+bignum_2]`处的大数结构体初始化（不赋值）。

既然我们已经知道此处是结构体/结构体数组，那么我们新建一个结构体并把对应的局部变量做转换，就能让代码更清晰一些（此处有一个小技巧，直接导入`gmp.h`头文件，`IDA`能自动提取出结构体，此处我会报错找不到`stddef.h`，说明要先导入`stddef.h`，但是它又会报错，那样就很麻烦了，所以要么手动导入，要么把头文件删改一下，后来想了一下，只保留结构体又会涉及到很多外部符号，所以手动更方便）。

```x86asm
.text:000000000040155A loc_40155A:                             ; CODE XREF: main+A5↑j
.text:000000000040155A                 lea     rax, [rbp+bignum_arr_0]
.text:0000000000401561                 mov     rcx, rax
.text:0000000000401564                 add     rcx, 640h
.text:000000000040156B                 mov     rdx, rax
.text:000000000040156E                 mov     [rbp+start_0], rax
.text:0000000000401575                 mov     [rbp+end_0], rcx
.text:000000000040157C                 mov     [rbp+current_0], rdx
.text:0000000000401583
.text:0000000000401583 loc_401583:                             ; CODE XREF: main+10A↓j
.text:0000000000401583 ;   try {
.text:0000000000401583                 mov     rax, [rbp+current_0]
.text:000000000040158A                 mov     rdi, rax
.text:000000000040158D                 mov     [rbp+j_current_0], rax
.text:0000000000401594                 call    _ZN10__gmp_exprIA1_12__mpz_structS1_EC2Ev ; __gmp_expr<__mpz_struct [1],__mpz_struct [1]>::__gmp_expr(void)
.text:0000000000401594 ;   } // starts at 401583
.text:0000000000401599                 jmp     $+5
.text:000000000040159E ; ---------------------------------------------------------------------------
.text:000000000040159E
.text:000000000040159E loc_40159E:                             ; CODE XREF: main+E9↑j
.text:000000000040159E                 mov     rax, [rbp+j_current_0]
.text:00000000004015A5                 add     rax, 10h
.text:00000000004015A9                 mov     rcx, [rbp+end_0]
.text:00000000004015B0                 cmp     rax, rcx
.text:00000000004015B3                 mov     [rbp+current_0], rax
.text:00000000004015BA                 jnz     loc_401583
```

以上是一个循环，是不断调用`___gmpz_init`在`[rbp+bignum_arr_0]`处初始化`100`个大数，也就是说生成了一个数组。
接下来是一个双重循环，比较冗长，分多个部分分析:

```x86asm
.text:00000000004015C0                 mov     [rbp+zero], 0
.text:00000000004015C7                 mov     [rbp+i], 0
.text:00000000004015CE
.text:00000000004015CE loc_4015CE:                             ; CODE XREF: main+307↓j
.text:00000000004015CE                 mov     eax, [rbp+i]
.text:00000000004015D1                 mov     ecx, eax
.text:00000000004015D3                 mov     rdx, [rbp+argv]
.text:00000000004015D7                 mov     rdi, [rdx+8]    ; s
.text:00000000004015DB                 mov     [rbp+j_i], rcx
.text:00000000004015E2                 call    _strlen
.text:00000000004015E7                 mov     rcx, [rbp+j_i]
.text:00000000004015EE                 cmp     rcx, rax
.text:00000000004015F1                 jnb     loc_4017BC
.text:00000000004015F7 ;   try {
.text:00000000004015F7                 lea     rdi, [rbp+bignum_1]
.text:00000000004015FB                 mov     esi, 1
.text:0000000000401600                 call    _ZN10__gmp_exprIA1_12__mpz_structS1_EaSEi ; __gmp_expr<__mpz_struct [1],__mpz_struct [1]>::operator=(int)
.text:0000000000401605                 mov     [rbp+unuse_2], rax
.text:000000000040160C                 jmp     $+5
.text:0000000000401611 ; ---------------------------------------------------------------------------
.text:0000000000401611
.text:0000000000401611 loc_401611:                             ; CODE XREF: main+15C↑j
.text:0000000000401611                 mov     rax, [rbp+argv]
.text:0000000000401615                 mov     rax, [rax+8]
.text:0000000000401619                 mov     ecx, [rbp+i]
.text:000000000040161C                 mov     edx, ecx
.text:000000000040161E                 movsx   ecx, byte ptr [rax+rdx]
.text:0000000000401622                 movsx   esi, [rbp+zero]
.text:0000000000401629                 sub     ecx, esi
.text:000000000040162B                 lea     rdi, [rbp+bignum_2]
.text:000000000040162F                 mov     esi, ecx
.text:0000000000401631                 call    _ZN10__gmp_exprIA1_12__mpz_structS1_EaSEi ; __gmp_expr<__mpz_struct [1],__mpz_struct [1]>::operator=(int)
.text:0000000000401636                 mov     [rbp+unused_3], rax
.text:000000000040163D                 jmp     $+5
```

第一部分是设置循环变量，`loc_4015CE`处进入循环体，首先会比较循环变量和长度，若循环变量大于等于长度，直接退出循环。
接下来调用`___gmpz_set_si`给大数赋值，令`bignum_1`等于`1`，`bignum_2`等于当前字符。
下面会进入里循环:

```x86asm
.text:0000000000401649 loc_401649:                             ; CODE XREF: main+209↓j
.text:0000000000401649                 cmp     [rbp+j], 5
.text:000000000040164D                 jnb     loc_401743
.text:0000000000401653                 lea     rdi, [rbp+bignum_1]
.text:0000000000401657                 lea     rsi, [rbp+bignum_2]
.text:000000000040165B                 call    _ZmlIA1_12__mpz_structS1_S1_S1_E10__gmp_exprIN18__gmp_resolve_exprIT_T1_E10value_typeE17__gmp_binary_exprIS2_IS4_T0_ES2_IS5_T2_E23__gmp_binary_multipliesEERKSA_RKSC_ ; operator*<__mpz_struct [1],__mpz_struct [1],__mpz_struct [1],__mpz_struct [1]>(__gmp_expr<__mpz_struct [1],__mpz_struct [1]> const&,__gmp_expr<__mpz_struct [1],__mpz_struct [1]> const&)
.text:0000000000401660                 mov     [rbp+var_1CF0], rdx
.text:0000000000401667                 mov     [rbp+var_1CF8], rax
.text:000000000040166E                 jmp     $+5
.text:0000000000401673 ; ---------------------------------------------------------------------------
.text:0000000000401673
.text:0000000000401673 loc_401673:                             ; CODE XREF: main+1BE↑j
.text:0000000000401673                 mov     rax, [rbp+var_1CF8]
.text:000000000040167A                 mov     [rbp+var_6A8], rax
.text:0000000000401681                 mov     rcx, [rbp+var_1CF0]
.text:0000000000401688                 mov     [rbp+var_6A0], rcx
.text:000000000040168F                 lea     rdi, [rbp+bignum_1]
.text:0000000000401693                 lea     rsi, [rbp+var_6A8]
.text:000000000040169A                 call    _ZN10__gmp_exprIA1_12__mpz_structS1_EaSIS1_17__gmp_binary_exprIS2_S2_23__gmp_binary_multipliesEEERS2_RKS_IT_T0_E ; __gmp_expr<__mpz_struct [1],__mpz_struct [1]>::operator=<__mpz_struct [1],__gmp_binary_expr<__gmp_expr<__mpz_struct [1],__mpz_struct [1]>,__gmp_expr<__mpz_struct [1],__mpz_struct [1]>,__gmp_binary_multiplies>>(__gmp_expr const&<__mpz_struct [1],__gmp_binary_expr<__gmp_expr<__mpz_struct [1],__mpz_struct [1]>,__gmp_expr<__mpz_struct [1],__mpz_struct [1]>,__gmp_binary_multiplies>>)
.text:000000000040169A ;   } // starts at 4015F7
.text:000000000040169F                 mov     [rbp+unused_4], rax
.text:00000000004016A6                 jmp     $+5
.text:00000000004016AB ; ---------------------------------------------------------------------------
.text:00000000004016AB
.text:00000000004016AB loc_4016AB:                             ; CODE XREF: main+1F6↑j
.text:00000000004016AB                 jmp     $+5
.text:00000000004016B0 ; ---------------------------------------------------------------------------
.text:00000000004016B0
.text:00000000004016B0 loc_4016B0:                             ; CODE XREF: main:loc_4016AB↑j
.text:00000000004016B0                 mov     eax, [rbp+j]
.text:00000000004016B3                 add     eax, 1
.text:00000000004016B6                 mov     [rbp+j], eax
.text:00000000004016B9                 jmp     loc_401649
```

里循环的大小是`5`，其中调用的第一个就让人很疑惑，步入发现里面没有调用任何外部函数，是因为太简单而直接合并了吗?
~~后来查了一下发现`__gmp_binary_multiplies`是一个定义在`gmpxx.h`中的结构体，其中定义了几个静态函数，实际上调用的就是`mpz_mul`，结合调试结果，感觉就是单纯的计算当前字符的`5`次方。~~
有些局部变量我没有标出来，因为它们根本是不重要的，完全可以把第一个函数忽略，并把它的参数当作第二个函数的参数，所以正是我们之前所猜测的，里循环是计算当前字符的`5`次方，计算结果保存在`bignum_1`中。
里循环结束后:

```x86asm
.text:0000000000401743 loc_401743:                             ; CODE XREF: main+19D↑j
.text:0000000000401743 ;   try {
.text:0000000000401743                 lea     rdi, [rbp+bignum_1]
.text:0000000000401747                 mov     esi, 143h
.text:000000000040174C                 call    _ZrmIA1_12__mpz_structS1_E10__gmp_exprIT_17__gmp_binary_exprIS2_IS3_T0_El20__gmp_binary_modulusEERKS6_i ; operator%<__mpz_struct [1],__mpz_struct [1]>(__gmp_expr<__mpz_struct [1],__mpz_struct [1]> const&,int)
.text:0000000000401751                 mov     [rbp+var_1D18], rdx
.text:0000000000401758                 mov     [rbp+var_1D20], rax
.text:000000000040175F                 jmp     $+5
.text:0000000000401764 ; ---------------------------------------------------------------------------
.text:0000000000401764
.text:0000000000401764 loc_401764:                             ; CODE XREF: main+2AF↑j
.text:0000000000401764                 mov     rax, [rbp+var_1D20]
.text:000000000040176B                 mov     [rbp+var_6B8], rax
.text:0000000000401772                 mov     rcx, [rbp+var_1D18]
.text:0000000000401779                 mov     [rbp+var_6B0], rcx
.text:0000000000401780                 mov     edx, [rbp+i]
.text:0000000000401783                 mov     esi, edx
.text:0000000000401785                 shl     rsi, 4
.text:0000000000401789                 lea     rdi, [rbp+rsi+bignum_arr_0]
.text:0000000000401791                 lea     rsi, [rbp+var_6B8]
.text:0000000000401798                 call    _ZN10__gmp_exprIA1_12__mpz_structS1_EaSIS1_17__gmp_binary_exprIS2_l20__gmp_binary_modulusEEERS2_RKS_IT_T0_E ; __gmp_expr<__mpz_struct [1],__mpz_struct [1]>::operator=<__mpz_struct [1],__gmp_binary_expr<__gmp_expr<__mpz_struct [1],__mpz_struct [1]>,long,__gmp_binary_modulus>>(__gmp_expr const&<__mpz_struct [1],__gmp_binary_expr<__gmp_expr<__mpz_struct [1],__mpz_struct [1]>,long,__gmp_binary_modulus>>)
.text:0000000000401798 ;   } // starts at 401743
.text:000000000040179D                 mov     [rbp+unused_5], rax
.text:00000000004017A4                 jmp     $+5
.text:00000000004017A9 ; ---------------------------------------------------------------------------
.text:00000000004017A9
.text:00000000004017A9 loc_4017A9:                             ; CODE XREF: main+2F4↑j
.text:00000000004017A9                 jmp     $+5
.text:00000000004017AE ; ---------------------------------------------------------------------------
.text:00000000004017AE
.text:00000000004017AE loc_4017AE:                             ; CODE XREF: main:loc_4017A9↑j
.text:00000000004017AE                 mov     eax, [rbp+i]
.text:00000000004017B1                 add     eax, 1
.text:00000000004017B4                 mov     [rbp+i], eax
.text:00000000004017B7                 jmp     loc_4015CE
```

类似的，也是只有后一个函数起作用了，它是把`bignum_1`模上`0x143`，并把结果放到前面初始化的`100`个大数中。
以上的结果都是调试而来的，而且我还发现一个比较有趣的事情，我们会发现有些标有`gmp`的函数根本没调用外部函数，也不会影响结果，但是紧跟其后的一个功能一模一样的函数，其内部会调用外部函数，并且得到结果，感觉是`gmp`库内部的一些特征，会先调用一个函数做一些初始化工作。
之后离开双重循环:

```x86asm
.text:00000000004017BC loc_4017BC:                             ; CODE XREF: main+141↑j
.text:00000000004017BC                 lea     rax, [rbp+bignum_arr_1]
.text:00000000004017C3                 mov     rcx, rax
.text:00000000004017C6                 add     rcx, 640h
.text:00000000004017CD                 mov     rdx, rax
.text:00000000004017D0                 mov     [rbp+start_1], rax
.text:00000000004017D7                 mov     [rbp+end_1], rcx
.text:00000000004017DE                 mov     [rbp+current_1], rdx
.text:00000000004017E5
.text:00000000004017E5 loc_4017E5:                             ; CODE XREF: main+36C↓j
.text:00000000004017E5 ;   try {
.text:00000000004017E5                 mov     rax, [rbp+current_1]
.text:00000000004017EC                 mov     rdi, rax
.text:00000000004017EF                 mov     [rbp+j_current_1], rax
.text:00000000004017F6                 call    _ZN10__gmp_exprIA1_12__mpz_structS1_EC2Ev ; __gmp_expr<__mpz_struct [1],__mpz_struct [1]>::__gmp_expr(void)
.text:00000000004017F6 ;   } // starts at 4017E5
.text:00000000004017FB                 jmp     $+5
.text:0000000000401800 ; ---------------------------------------------------------------------------
.text:0000000000401800
.text:0000000000401800 loc_401800:                             ; CODE XREF: main+34B↑j
.text:0000000000401800                 mov     rax, [rbp+j_current_1]
.text:0000000000401807                 add     rax, 10h
.text:000000000040180B                 mov     rcx, [rbp+end_1]
.text:0000000000401812                 cmp     rax, rcx
.text:0000000000401815                 mov     [rbp+current_1], rax
.text:000000000040181C                 jnz     loc_4017E5
```

以上是在`[rbp+bignum_arr_1]`处初始化`100`个大数。

```x86asm
.text:0000000000401822                 lea     rdi, [rbp+bignum_arr_0]
.text:0000000000401829                 xor     esi, esi
.text:000000000040182B                 call    _ZmiIA1_12__mpz_structS1_E10__gmp_exprIT_17__gmp_binary_exprIS2_IS3_T0_El18__gmp_binary_minusEERKS6_i ; operator-<__mpz_struct [1],__mpz_struct [1]>(__gmp_expr<__mpz_struct [1],__mpz_struct [1]> const&,int)
.text:0000000000401830                 mov     [rbp+var_1D50], rdx
.text:0000000000401837                 mov     [rbp+var_1D58], rax
.text:000000000040183E                 jmp     $+5
.text:0000000000401843 ; ---------------------------------------------------------------------------
.text:0000000000401843
.text:0000000000401843 loc_401843:                             ; CODE XREF: main+38E↑j
.text:0000000000401843                 mov     rax, [rbp+var_1D58]
.text:000000000040184A                 mov     [rbp+var_D20], rax
.text:0000000000401851                 mov     rcx, [rbp+var_1D50]
.text:0000000000401858                 mov     [rbp+var_D18], rcx
.text:000000000040185F                 mov     rdx, [rbp+argv]
.text:0000000000401863                 mov     rdi, [rdx+8]    ; s
.text:0000000000401867                 call    _strlen
.text:000000000040186C                 lea     rdi, [rbp+var_D20]
.text:0000000000401873                 mov     rsi, rax
.text:0000000000401876                 call    _ZplIA1_12__mpz_struct17__gmp_binary_exprI10__gmp_exprIS1_S1_El18__gmp_binary_minusEES3_IT_S2_IS3_IS7_T0_Em17__gmp_binary_plusEERKS9_m ; operator+<__mpz_struct [1],__gmp_binary_expr<__gmp_expr<__mpz_struct [1],__mpz_struct [1]>,long,__gmp_binary_minus>>(__gmp_expr<__mpz_struct [1],__gmp_binary_expr<__gmp_expr<__mpz_struct [1],__mpz_struct [1]>,long,__gmp_binary_minus>> const&,ulong)
.text:000000000040187B                 mov     [rbp+var_1D60], rdx
.text:0000000000401882                 mov     [rbp+var_1D68], rax
.text:0000000000401889                 jmp     $+5
.text:000000000040188E ; ---------------------------------------------------------------------------
.text:000000000040188E
.text:000000000040188E loc_40188E:                             ; CODE XREF: main+3D9↑j
.text:000000000040188E                 mov     rax, [rbp+var_1D68]
.text:0000000000401895                 mov     [rbp+var_D10], rax
.text:000000000040189C                 mov     rcx, [rbp+var_1D60]
.text:00000000004018A3                 mov     [rbp+var_D08], rcx
.text:00000000004018AA                 lea     rdi, [rbp+bignum_arr_1]
.text:00000000004018B1                 lea     rsi, [rbp+var_D10]
.text:00000000004018B8                 call    _ZN10__gmp_exprIA1_12__mpz_structS1_EaSIS1_17__gmp_binary_exprIS_IS1_S4_IS2_l18__gmp_binary_minusEEm17__gmp_binary_plusEEERS2_RKS_IT_T0_E ; __gmp_expr<__mpz_struct [1],__mpz_struct [1]>::operator=<__mpz_struct [1],__gmp_binary_expr<__gmp_expr<__mpz_struct [1],__gmp_binary_expr<__gmp_expr<__mpz_struct [1],__mpz_struct [1]>,long,__gmp_binary_minus>>,ulong,__gmp_binary_plus>>(__gmp_expr const&<__mpz_struct [1],__gmp_binary_expr<__gmp_expr<__mpz_struct [1],__gmp_binary_expr<__gmp_expr<__mpz_struct [1],__mpz_struct [1]>,long,__gmp_binary_minus>>,ulong,__gmp_binary_plus>>)
.text:00000000004018BD                 mov     [rbp+unused_6], rax
.text:00000000004018C4                 jmp     $+5z
```

以上的部分前两个函数也是不影响结果的，最后一个函数会把令`bignum_arr_1[0] = bignum_arr_0[0] + len`
接下来是一个循环:

```x86asm
.text:00000000004018C9 loc_4018C9:                             ; CODE XREF: main+414↑j
.text:00000000004018C9                 mov     [rbp+i], 1
.text:00000000004018D0
.text:00000000004018D0 loc_4018D0:                             ; CODE XREF: main+4D7↓j
.text:00000000004018D0                 mov     eax, [rbp+i]
.text:00000000004018D3                 mov     ecx, eax
.text:00000000004018D5                 mov     rdx, [rbp+argv]
.text:00000000004018D9                 mov     rdi, [rdx+8]    ; s
.text:00000000004018DD                 mov     [rbp+j_j_i], rcx
.text:00000000004018E4                 call    _strlen
.text:00000000004018E9                 mov     rcx, [rbp+j_j_i]
.text:00000000004018F0                 cmp     rcx, rax
.text:00000000004018F3                 jnb     loc_401A03
.text:00000000004018F9                 mov     eax, [rbp+i]
.text:00000000004018FC                 mov     ecx, eax
.text:00000000004018FE                 mov     eax, ecx
.text:0000000000401900                 shl     rcx, 4
.text:0000000000401904                 lea     rdi, [rbp+rcx+bignum_arr_0]
.text:000000000040190C                 dec     eax
.text:000000000040190E                 mov     ecx, eax
.text:0000000000401910                 shl     rcx, 4
.text:0000000000401914                 lea     rsi, [rbp+rcx+bignum_arr_0]
.text:000000000040191C                 call    _ZplIA1_12__mpz_structS1_S1_S1_E10__gmp_exprIN18__gmp_resolve_exprIT_T1_E10value_typeE17__gmp_binary_exprIS2_IS4_T0_ES2_IS5_T2_E17__gmp_binary_plusEERKSA_RKSC_ ; operator+<__mpz_struct [1],__mpz_struct [1],__mpz_struct [1],__mpz_struct [1]>(__gmp_expr<__mpz_struct [1],__mpz_struct [1]> const&,__gmp_expr<__mpz_struct [1],__mpz_struct [1]> const&)
.text:0000000000401921                 mov     [rbp+var_1D80], rdx
.text:0000000000401928                 mov     [rbp+var_1D88], rax
.text:000000000040192F                 jmp     $+5
.text:0000000000401934 ; ---------------------------------------------------------------------------
.text:0000000000401934
.text:0000000000401934 loc_401934:                             ; CODE XREF: main+47F↑j
.text:0000000000401934                 mov     rax, [rbp+var_1D88]
.text:000000000040193B                 mov     [rbp+var_D30], rax
.text:0000000000401942                 mov     rcx, [rbp+var_1D80]
.text:0000000000401949                 mov     [rbp+var_D28], rcx
.text:0000000000401950                 mov     edx, [rbp+i]
.text:0000000000401953                 mov     esi, edx
.text:0000000000401955                 shl     rsi, 4
.text:0000000000401959                 lea     rdi, [rbp+rsi+bignum_arr_1]
.text:0000000000401961                 lea     rsi, [rbp+var_D30]
.text:0000000000401968                 call    _ZN10__gmp_exprIA1_12__mpz_structS1_EaSIS1_17__gmp_binary_exprIS2_S2_17__gmp_binary_plusEEERS2_RKS_IT_T0_E ; __gmp_expr<__mpz_struct [1],__mpz_struct [1]>::operator=<__mpz_struct [1],__gmp_binary_expr<__gmp_expr<__mpz_struct [1],__mpz_struct [1]>,__gmp_expr<__mpz_struct [1],__mpz_struct [1]>,__gmp_binary_plus>>(__gmp_expr const&<__mpz_struct [1],__gmp_binary_expr<__gmp_expr<__mpz_struct [1],__mpz_struct [1]>,__gmp_expr<__mpz_struct [1],__mpz_struct [1]>,__gmp_binary_plus>>)
.text:0000000000401968 ;   } // starts at 401822
.text:000000000040196D                 mov     [rbp+unused_7], rax
.text:0000000000401974                 jmp     $+5
.text:0000000000401979 ; ---------------------------------------------------------------------------
.text:0000000000401979
.text:0000000000401979 loc_401979:                             ; CODE XREF: main+4C4↑j
.text:0000000000401979                 jmp     $+5
.text:000000000040197E ; ---------------------------------------------------------------------------
.text:000000000040197E
.text:000000000040197E loc_40197E:                             ; CODE XREF: main:loc_401979↑j
.text:000000000040197E                 mov     eax, [rbp+i]
.text:0000000000401981                 add     eax, 1
.text:0000000000401984                 mov     [rbp+i], eax
.text:0000000000401987                 jmp     loc_4018D0
```

循环内部是令`bignum_arr_1[i] = bignum_arr_0[i] + bignum_arr_0[i - 1]`。

```x86asm
.text:0000000000401A03 loc_401A03:                             ; CODE XREF: main+443↑j
.text:0000000000401A03                 lea     rax, [rbp+bignum_arr_2]
.text:0000000000401A0A                 mov     rcx, rax
.text:0000000000401A0D                 add     rcx, 640h
.text:0000000000401A14                 mov     rdx, rax
.text:0000000000401A17                 mov     [rbp+start_2], rax
.text:0000000000401A1E                 mov     [rbp+end_2], rcx
.text:0000000000401A25                 mov     [rbp+current_2], rdx
.text:0000000000401A2C
.text:0000000000401A2C loc_401A2C:                             ; CODE XREF: main+5B3↓j
.text:0000000000401A2C ;   try {
.text:0000000000401A2C                 mov     rax, [rbp+current_2]
.text:0000000000401A33                 mov     rdi, rax
.text:0000000000401A36                 mov     [rbp+j_current_2], rax
.text:0000000000401A3D                 call    _ZN10__gmp_exprIA1_12__mpz_structS1_EC2Ev ; __gmp_expr<__mpz_struct [1],__mpz_struct [1]>::__gmp_expr(void)
.text:0000000000401A3D ;   } // starts at 401A2C
.text:0000000000401A42                 jmp     $+5
.text:0000000000401A47 ; ---------------------------------------------------------------------------
.text:0000000000401A47
.text:0000000000401A47 loc_401A47:                             ; CODE XREF: main+592↑j
.text:0000000000401A47                 mov     rax, [rbp+j_current_2]
.text:0000000000401A4E                 add     rax, 10h
.text:0000000000401A52                 mov     rcx, [rbp+end_2]
.text:0000000000401A59                 cmp     rax, rcx
.text:0000000000401A5C                 mov     [rbp+current_2], rax
.text:0000000000401A63                 jnz     loc_401A2C
```

以上是生成第三个区域的大数了。
至此第二部分分析完成，大概的思路是计算了一下幂取模，并把结果保存在`bignum_arr_0`，然后对幂取模的结果作变换，变换后保存在`bignum_arr_1`，最后是生成新的`bignum_arr_2`。

#### 第三部分的分析

第三部分实际上是一个步骤做了很多次，除了第一部分略有不同。
我们以第一部分为例来分析:

```x86asm
.text:0000000000401A69                 lea     rax, [rbp+allloc_0]
.text:0000000000401A70                 mov     rdi, rax
.text:0000000000401A73                 mov     [rbp+j_alloc_0], rax
.text:0000000000401A7A                 call    __ZNSaIcEC1Ev   ; std::allocator<char>::allocator(void)
.text:0000000000401A7F ;   try {
.text:0000000000401A7F                 mov     ecx, offset a10265147310460 ; "102651473104605400881443209436335207143"...
.text:0000000000401A84                 mov     esi, ecx
.text:0000000000401A86                 lea     rdi, [rbp+str_0]
.text:0000000000401A8D                 mov     rdx, [rbp+j_alloc_0]
.text:0000000000401A94                 call    __ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEC1EPKcRKS3_ ; std::__cxx11::basic_string<char,std::char_traits<char>,std::allocator<char>>::basic_string(char const*,std::allocator<char> const&)
.text:0000000000401A94 ;   } // starts at 401A7F
.text:0000000000401A99                 jmp     $+5
.text:0000000000401A9E ; ---------------------------------------------------------------------------
.text:0000000000401A9E
.text:0000000000401A9E loc_401A9E:                             ; CODE XREF: main+5E9↑j
.text:0000000000401A9E                 lea     rdi, [rbp+allloc_0]
.text:0000000000401AA5                 call    __ZNSaIcED1Ev   ; std::allocator<char>::~allocator()
.text:0000000000401AAA                 lea     rdi, [rbp+alloc_1]
.text:0000000000401AB1                 mov     [rbp+j_alloc_1], rdi
.text:0000000000401AB8                 call    __ZNSaIcEC1Ev   ; std::allocator<char>::allocator(void)
.text:0000000000401ABD ;   try {
.text:0000000000401ABD                 mov     eax, offset a41609 ; "41609"
.text:0000000000401AC2                 mov     esi, eax
.text:0000000000401AC4                 lea     rdi, [rbp+str_1]
.text:0000000000401ACB                 mov     rdx, [rbp+j_alloc_1]
.text:0000000000401AD2                 call    __ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEC1EPKcRKS3_ ; std::__cxx11::basic_string<char,std::char_traits<char>,std::allocator<char>>::basic_string(char const*,std::allocator<char> const&)
.text:0000000000401AD2 ;   } // starts at 401ABD
.text:0000000000401AD7                 jmp     $+5
.text:0000000000401ADC ; ---------------------------------------------------------------------------
.text:0000000000401ADC
.text:0000000000401ADC loc_401ADC:                             ; CODE XREF: main+627↑j
.text:0000000000401ADC                 lea     rdi, [rbp+alloc_1]
.text:0000000000401AE3                 call    __ZNSaIcED1Ev   ; std::allocator<char>::~allocator()
```

以上是用`allocator`把两个`const char*`类型的字符串转成`string`型，意义不明。

```x86asm
.text:0000000000401AE8                 lea     rdi, [rbp+bignum_3]
.text:0000000000401AEF                 lea     rsi, [rbp+str_0]
.text:0000000000401AF6                 xor     edx, edx
.text:0000000000401AF8                 call    _ZN10__gmp_exprIA1_12__mpz_structS1_EC2ERKNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEEi ; __gmp_expr<__mpz_struct [1],__mpz_struct [1]>::__gmp_expr(std::__cxx11::basic_string<char,std::char_traits<char>,std::allocator<char>> const&,int)
.text:0000000000401AF8 ;   } // starts at 401AE8
.text:0000000000401AFD                 jmp     $+5
.text:0000000000401B02 ; ---------------------------------------------------------------------------
.text:0000000000401B02
.text:0000000000401B02 loc_401B02:                             ; CODE XREF: main+64D↑j
.text:0000000000401B02 ;   try {
.text:0000000000401B02                 lea     rdi, [rbp+bignum_4]
.text:0000000000401B09                 lea     rsi, [rbp+str_1]
.text:0000000000401B10                 xor     edx, edx
.text:0000000000401B12                 call    _ZN10__gmp_exprIA1_12__mpz_structS1_EC2ERKNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEEi ; __gmp_expr<__mpz_struct [1],__mpz_struct [1]>::__gmp_expr(std::__cxx11::basic_string<char,std::char_traits<char>,std::allocator<char>> const&,int)
.text:0000000000401B12 ;   } // starts at 401B02
.text:0000000000401B17                 jmp     $+5
```

接着利用之前的两个字符串生成了`bignum_3`和`bignum_4`。

```x86asm
.text:0000000000401B1C loc_401B1C:                             ; CODE XREF: main+667↑j
.text:0000000000401B1C                 lea     rax, [rbp+bignum_arr_4]
.text:0000000000401B23                 mov     rcx, rax
.text:0000000000401B26                 add     rcx, 640h
.text:0000000000401B2D                 mov     rdx, rax
.text:0000000000401B30                 mov     [rbp+start_3], rax
.text:0000000000401B37                 mov     [rbp+end_3], rcx
.text:0000000000401B3E                 mov     [rbp+current_3], rdx
.text:0000000000401B45
.text:0000000000401B45 loc_401B45:                             ; CODE XREF: main+6CC↓j
.text:0000000000401B45 ;   try {
.text:0000000000401B45                 mov     rax, [rbp+current_3]
.text:0000000000401B4C                 mov     rdi, rax
.text:0000000000401B4F                 mov     [rbp+j_current_3], rax
.text:0000000000401B56                 call    _ZN10__gmp_exprIA1_12__mpz_structS1_EC2Ev ; __gmp_expr<__mpz_struct [1],__mpz_struct [1]>::__gmp_expr(void)
.text:0000000000401B56 ;   } // starts at 401B45
.text:0000000000401B5B                 jmp     $+5
.text:0000000000401B60 ; ---------------------------------------------------------------------------
.text:0000000000401B60
.text:0000000000401B60 loc_401B60:                             ; CODE XREF: main+6AB↑j
.text:0000000000401B60                 mov     rax, [rbp+j_current_3]
.text:0000000000401B67                 add     rax, 10h
.text:0000000000401B6B                 mov     rcx, [rbp+end_3]
.text:0000000000401B72                 cmp     rax, rcx
.text:0000000000401B75                 mov     [rbp+current_3], rax
.text:0000000000401B7C                 jnz     loc_401B45
```

然后又是生成了`100`个大数，命名为`bingnum_arr_4`。

剩下的均是重复的，我们可以看一下伪码:

```cpp
      __gmp_expr<__mpz_struct [1],__mpz_struct [1]>::__gmp_expr(
        (__int64)&v62,
        (unsigned int)"57919849217920783735142893327761275876448411493502728132956707072863216231372451540130539410530734"
                      "69369013361150501575074547376711709569924769423461429289194418447983056169061985995139330882603556"
                      "11005569944272199370100603117022881496480050977589835110574267464843965345450302899323560285446873"
                      "42592923922803783495649273096408267525320445022288126075221943749274456753050741344845451290180528"
                      "38382840732057931729685054623877734989743317048739566944221631882336402354241455545642973098107858"
                      "71847211985331083142331310812654985257078602161598996181420924215260846150601683289569813494732069"
                      "91065608827035640385395182812441310805733145868912422735307512348165640379213917204367297929602757"
                      "22323906230679813745761862848876050560200917515341582824225928012205301247512342551448597356502681"
                      "03250087444696329209126451341673288101763271915725197780685388375509457912694074028236959960760548"
                      "89265210839501169276344626279938887699237729275344538821558290431868218566474303662853946230500962"
                      "70959974746147954744490350783923179984193137756012795394185048397300910140125707195624596424604419"
                      "01983572287134461592177518369903317582788143812554852595740375529686451874374671094465711021378197"
                      "49089303219446589473342531325470927244288064411756855877536822423517040253923560090409380732344749"
                      "56418615486167842628067224619996836597531480039361866075267852258199491035971816787169373926023203"
                      "53571005337697261990696538557687569340044125113984430965088369486290276975451384744727515973385277"
                      "68840014851488519919974390498415309",
        0);
      __gmp_expr<__mpz_struct [1],__mpz_struct [1]>::operator=(bignum_arr_4, &v62);
      __gmp_expr<__mpz_struct [1],__mpz_struct [1]>::~__gmp_expr(&v62);
```

此部分实际上就是把一个字符串转成大数，然后赋给`bignum_arr_4`，后面会一直赋到`bignum_arr_4[37]`，很明显是生成了`38`个大数。
以上就是第三部分，目的就是生成`38`个大数。

#### 第四部分的分析

从`loc_40267E`起就是第四部分，我觉得没有看汇编的必要，从伪码来看更清楚一些:

```cpp
      __gmp_expr<__mpz_struct [1],__mpz_struct [1]>::~__gmp_expr(&v25);
      for ( i = 38; i < 0x64; ++i )
      {
        __gmp_expr<__mpz_struct [1],__mpz_struct [1]>::__gmp_expr((__int64)&v24, 4267316LL, 0);
        __gmp_expr<__mpz_struct [1],__mpz_struct [1]>::operator=(&bignum_arr_4[i], &v24);
        __gmp_expr<__mpz_struct [1],__mpz_struct [1]>::~__gmp_expr(&v24);
      }
      for ( i = 0; ; ++i )
      {
        v11 = i;
        if ( v11 >= strlen(argva[1]) )
          break;
        encrypt((__int64)&v23, (__int64)&bignum_arr_1[i], (__int64)&bignum_4, (__int64)&bignum_3);
        __gmp_expr<__mpz_struct [1],__mpz_struct [1]>::operator=(&bignum_arr_2[i], &v23);
        __gmp_expr<__mpz_struct [1],__mpz_struct [1]>::~__gmp_expr(&v23);
        if ( operator!=<__mpz_struct [1],__mpz_struct [1],__mpz_struct [1],__mpz_struct [1]>(
               &bignum_arr_2[i],
               &bignum_arr_4[i]) & 1 )
        {
          v12 = std::operator<<<std::char_traits<char>>(&_bss_start, (unsigned int)"wrong flag.");
          std::ostream::operator<<(v12, (unsigned int)&std::endl<char,std::char_traits<char>>);
          ret = 0;
          goto LABEL_31;
        }
      }
      v13 = std::operator<<<std::char_traits<char>>(&_bss_start, (unsigned int)"bingo!");
      std::ostream::operator<<(v13, (unsigned int)&std::endl<char,std::char_traits<char>>);
      ret = 0;
```

就是把`bignum_arr_1`加密后的结果和第三部分生成的大数比较，一旦不同，直接输出错误信息并跳出循环。
分析到此处，整个程序已经很清晰了，`encrypt`就是`rsa`算法（其中调用了`powm`），`powm`的定义查一下就可以，得知`bignum_4`是公钥（`41609`），`bignum_3`是模数`n`（`10265147310460540088144320943633520714336459390260783110465951325477551892344792341877605318496412.......`）。
若想得到解密的私钥，很明显需要分解模数，但是模数也太大了，一开始以为是调用`__gmpz_init_set_str`传入的基数等于`0`时另有玄机，但是看了下源码，发现并不是:

```cpp
//set.str.c
  /* If BASE is 0, try to find out the base by looking at the initial
     characters.  */
  if (base == 0)
    {
      base = 10;
      if (c == '0')
    {
      base = 8;
      c = (unsigned char) *str++;
      if (c == 'x' || c == 'X')
        {
          base = 16;
          c = (unsigned char) *str++;
        }
      else if (c == 'b' || c == 'B')
        {
          base = 2;
          c = (unsigned char) *str++;
        }
    }
    }
```

它是根据传入的字符串的前几个字符判断的，很明显我们传入的字符串会让`base = 10`，那就没什么问题，看来的确是要硬分解，但是`yafu`跑了半天也没跑出来（[yafu][1]），由于不会其它方法，只能转而爆破，以爆破前几个字符的脚本为例:

```python
def powm(b, e, n):
    result = 1
    while e != 0:
        if (e & 1) == 1:
            result = (result * b) % n
        e >>= 1
        b = (b * b) % n
    return result

e_0 = 5
n_0 = 323
e_1 = int('41609', 10)
n_1 = int('102651473104605400881443209436335207143364593902607831104659513254775518923447923418776053184964127417292310751110954018379230925038183526950825957076822861193097601598650310458833168757490447855063621089262488908245458996608300475771810218545021100532975095664160301297355685288040601637561442455179633110079846710134322730324284152857852000538712290118985202146945804609486282114958343308956178741452118058076488074220293303425550534104695916297651437260840156614208398265649572936591070707149727591261946573549966777759067945870542262596595729532884877741113485459644140649532472144766397594354234108576755815917168003359597993072007662182342629809152936969421895552780144527391604982975657819198048361600023456702313892160810273481932944137974282216381637292972896247123735265111606267014480229602366343234386044792316318028789845062796141719269577108623503432313385433912012680162134432871999515572195678215741149038561107783321860080221501590006190270380869307116405522430479782169008415898242325411271043447827685653357582905940740125675545255630155684164945409286389585255976330122263610987012875989116119004168237430091958750377684385918076049811463810026787681970329875350154256541485562299929744955216059064911687028831046268556619196694147338675484825249402694136964225868844636091765013673567792490217775308571769318669397501731133181116010571526812759760618304461298242712032781458409426120142005834592865613957784145176085762288081896026523415885624361265385011667667343515890459493297688753', 10)

cipher = []
tmp = int('57919849217920783735142893327761275876448411493502728132956707072863216231372451540130539410530734693690133611505015750745473767117095699247694234614292891944184479830561690619859951393308826035561100556994427219937010060311702288149648005097758983511057426746484396534545030289932356028544687342592923922803783495649273096408267525320445022288126075221943749274456753050741344845451290180528383828407320579317296850546238777349897433170487395669442216318823364023542414555456429730981078587184721198533108314233131081265498525707860216159899618142092421526084615060168328956981349473206991065608827035640385395182812441310805733145868912422735307512348165640379213917204367297929602757223239062306798137457618628488760505602009175153415828242259280122053012475123425514485973565026810325008744469632920912645134167328810176327191572519778068538837550945791269407402823695996076054889265210839501169276344626279938887699237729275344538821558290431868218566474303662853946230500962709599747461479547444903507839231799841931377560127953941850483973009101401257071956245964246044190198357228713446159217751836990331758278814381255485259574037552968645187437467109446571102137819749089303219446589473342531325470927244288064411756855877536822423517040253923560090409380732344749564186154861678426280672246199968365975314800393618660752678522581994910359718167871693739260232035357100533769726199069653855768756934004412511398443096508836948629027697545138474472751597338527768840014851488519919974390498415309', 10)
cipher.append(tmp)
tmp = int('78239394434711560271032705122378112734889697416035091439151570024254487654865063682257424150919729612396413811573302590236841938749172114792072084960831519432441193267590442982066064095433772513234729975890002153122557996852035769535519213497239256363465756786870624196371985840818434824748311420851300983387880686184229524419499016067181183662336303297521881956535550625236232195103306719258044091849463016225593889819419925944641601210636489018364211711740374019528131019108873585858142527740873189512254750507228469323822042406708039391793180917337818616551840455782108373728852710487952147359321858002633643039152839120497401325949305497679277537457456716809161948494409137988425103293178215360533770940307129200525279278150876623435345741066589357523651677030097174084257645079571569330133507512234758032145382763171086476094963683310990268403105578885192506204769986333330591941899894648704280520468004407865897784680836655734739246375841194858669943180996863863761347256741475088304359085283411560879734462094163805543807574169106093625703279437506913564661027411656239859757582495488272422391303980512320574761845707339976961338902764923693542736119960425546421661945719159209416151410501004208697758675678107978077737006194081968395580638685917838798167440174102617435049900714932183479987893344190949023540492806302091323265615187042848342303136195854811831019560048015369248544361269062540605776509692251698985213197534907818768192126641718126639153321014800749625091297886102448583526128329355', 10)
cipher.append(tmp)
tmp = int('73844352519027260705131819679892289078420515494690441884927739142072061092258704715675233274425328362872363260182094396420570499803738619965325092239147366400451413367938180037681218499895170661008174641735396169112661303216122252476683231814001702407774656834269285848422493291706688772303517986812027393877723222408206500247564157524777317966716053028464844432929176513904859830411865560424058804476375637962119962025944177353602382632993442714685835711992929006635499221792763806849582216531446564624841296351425541693907268297300868659544832323278807960098787488706945000071154694563875067215276647492738656781393316346955917095238215338917458187880499493075839511978151294920031086281039461207681284338167828651644015815610276123200200487006525978785346407615544461495942755900214723659815704252793834986802323287516842172451939834998181592737780814830941497084109763394222993289125434094614249051952287900872142962832340739935262323787418282623342008505697941711003154631431864368623705675711994846701063279501999988412914574084920958885908228662227830510517130337184212756323270161828441067830160872785144248026296640235815811684577629810237995657860076373051476691958924894611036670055129722880947821586488855549276556857145459970341863532910281244852854605195011758971465819921086429891840088822274193699273231567731346681653158934525545885602690094546574005483769694863102228602426276004071490261208343631415292960943608955174257281763445058668353065550983696010378273436149015889437852192255921', 10)
cipher.append(tmp)
tmp = int('65884526683109931433453270432923602629824597772072419266027693762044714262874519141173054426448076273894518454406229588873637446695325431007944837021320630270792481381269055653649905026489783865588581973133573246803079119265152631938146716559375189461618262718613367710037254447388537457232397011994514799381470440627134182734741763652855832464318992319105888172829842101100421729259440774179140462741672655832110325843950904307627103924194675929681712637430746236125141043907683233009518674158299022672471943397641102024644405621214599682335810463762675761745380468263180351284125062390587011530953817005500047694729219112207881433574701754595888789726119566626167119215442269216189803852915682500478471272717468538989548835504464440494992865350977829358147658683352248582626806678582254238187993379709704463963778515104635179951332903284217274426668446206392916407490116320786591804594399079183435997897263014756171994221373951328368860054508232786520095295977699135064446987610437208968745930530505653512967210523316215123549847800282874070948822234563077748745676794834597422865475426798853673001645146783909223436701597691137298994287237203488892398600303647812793600540136885133665012405233682418975686688089958578996704352446352390075643786368395387046216342605818081350772644726450365028490489539004192608241812279356390474138337894688381953231390617307422853729806918132093981422807947862593840176682070185835401437676895222435471931603403356059218167358774153424873866603544449872256640736909992', 10)
cipher.append(tmp)

flag = ''
for i in range(0, len(cipher)):
    for j in range(30, 128):
        ret_0 = powm(j, e_0, n_0)
        if i == 0:
            ret_0 = ret_0 + 38
        else:
            ret_0 = ret_0 + powm(ord(flag[i - 1]), e_0, n_0)

        ret_1 = powm(ret_0, e_1, n_1)
        if ret_1 == cipher[i]:
            flag = flag + chr(j)
            break
print flag
```

可以解得`QCTF`，再多的部分就继续往`cipher`中添加密文即可，太繁琐就不继续写了，最终的`flag`应该是`QCTF{}`


#### **总结**

唬人的题目，但代码量确实不小，最后需要依次用`rsa`解密的工作量也比较大。
分析的很累，但的确没学到什么东西，只是知道了`gmp`库以及熟悉了一下`rsa`算法，唯一值得深究的地方就是`C++`更深层次的特性，例如模板等，只有了解它们，阅读大型工程的源代码时才不会感到非常难以理解。
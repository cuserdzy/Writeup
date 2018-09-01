# babyre

调试发现会产生`core`文件，看了下是进程直接被中止了，正常执行的话无此错误，目测是反调试，但是找不到在哪里。。。后来用附加试了一下没想到竟然可以，并没有反附加，使用:

```cpp
$ [file_name]

$ ps -ax | grep babyre
$ sudo gdb [file_name] [pid]
```

附加后gdb断在库函数中，步出即到达`read`函数返回处，计算基址有`0x563A8A053000`，后来发现有aslr。。。那基址就不是固定的。
核心代码应该在`sub_A110`中，在`main`中应该是使用的函数指针调用了前者，具体看`sub_A110`:

```cpp
  v41 = 0;
  sub_CCF0(v16, (__int64)off_27B2D0, 1LL, (__int64)"wrong\n", 0LL);
  sub_16AB0((__int128 *)v16, (const char ***)off_27B2D0);// 应该是输出函数
  sub_D4B0(v19);
  v0 = sub_159E0(v19, off_27B2D0);
  *(_QWORD *)v22 = v0;
  sub_15CD0(&v21, (__int64 *)v22, v19);         // 其中有read函数，其中的字符串查了一下，感觉是库函数
  sub_BE30(
    (unsigned __int64)&v21,
    (unsigned __int64)"failed to read from stdin\n",
    25,
    v1,
    v2,
    v3,
    v6,
    v7,
    v8,
    v9,
    v10,
    v11,
    v12,
    v13,
    v14,
    v0,
    v15,
    v16[0],
    v17,
    v18);
  sub_CFC0(v22, "failed to read from stdin\n");
  v4 = sub_D570((__int64)v19);
  sub_DBD0((__int64)v23, v4, v5, (__int64)"\n", 1LL, (__int64)"\n", 0LL);
  sub_D020((struct _Unwind_Exception *)v19);
  *(_QWORD *)v20 = *(_QWORD *)v24;
  *(_OWORD *)v19 = *(_OWORD *)v23;
```

ida分析的参数是有错误的，而且有些函数看起来很像库函数，通过调试可以大致猜到一些，但仍有很多函数看不出来。。。继续往下看:

```cpp
  if ( sub_D4A0((__int64)v19) == 32 )           // 目测是长度
  {
    sub_D500((__int64)v19);
    sub_D250((unsigned __int64)&v27);
    sub_10D10((__int64)&v27);
    sub_D250((unsigned __int64)v25);
    v41 = 1;
    sub_D030(&v27);
    v41 = 0;
    *(_QWORD *)v30 = *(_QWORD *)v26;
    *(_OWORD *)v29 = *(_OWORD *)v25;
    sub_82D0((__int64)(&v27.private_2 + 1), (struct _Unwind_Exception *)v29);
    *(_QWORD *)v34 = *(_QWORD *)v28;
    *(_OWORD *)v33 = *(_OWORD *)(&v27.private_2 + 1);
    sub_89C0((__int64)v31, (struct _Unwind_Exception *)v33);
    *(_QWORD *)v38 = *(_QWORD *)v32;
    *(_OWORD *)v37 = *(_OWORD *)v31;
    sub_9300((__int64)v35, (struct _Unwind_Exception *)v37);
    v40 = v36;
    *(_OWORD *)v39 = *(_OWORD *)v35;
    sub_9F50((struct _Unwind_Exception *)v39);
    v41 = 0;
  }
```

判断长度后就进入了核心逻辑，有效的几个函数是`sub_82D0`、`sub_89C0`、`sub_9300`和最后的`sub_9F50`，其中最后一个函数感觉是明码比较，其中会调用输出正确/错误信息的代码，那么前3个函数可能就是变换，调试看了一下，感觉的确是这样，但是前3个函数的长度非常长，即使它们的形式都一样至少看起来心态是爆炸的。。。看了下CFG图，发现其中有梯形的结构，该梯形结构由多次判断组成，若判断成功，调用`sub_5BD10`退出，反之调用`sub_10DD0`和`sub_10E30`。

通过调试可以发现第一个函数是类似交叉变换，每4个字符一组，而且`sub_10DD0`和`sub_10E30`加起来一共8次，具体做什么变换应该和函数的传入的参数有关。

反正后面就都都都都都不怎么会了。。。后面wp出来了，说是一个`Rust`写的程序，其实我也应该想到的，毕竟很多似是而非的库函数，估计就是其它语言写的了，查一下字符串会发现`babyre.rs`的字样，以`rs`结尾的一般就是`Rust`语言，其实知道这一点也没什么用。。。该看汇编的还是得看，结合调试一起看。
根据汇编，感觉核心代码仍是梯形结构，单独拿汇编来看，可以分割为8个部分，每个部分都是类似的操作:

```x86asm
.text:0000000000008513     loc_8513:                               ; CODE XREF: sub_82D0+1D0↑j
.text:0000000000008513 1A8                 mov     eax, 4
.text:0000000000008518 1A8                 mov     ecx, eax
.text:000000000000851A 1A8                 mov     rdx, [rsp+1A8h+var_30]
.text:0000000000008522 1A8                 mov     rax, rdx
.text:0000000000008525 1A8                 mov     [rsp+1A8h+var_C8], rdx
.text:000000000000852D 1A8                 mul     rcx
.text:0000000000008530 1A8                 seto    sil
.text:0000000000008534 1A8                 test    sil, 1
.text:0000000000008538 1A8                 mov     [rsp+1A8h+var_D0], rax
.text:0000000000008540 1A8                 jnz     loc_88CB
.text:0000000000008546 1A8                 mov     rax, [rsp+1A8h+var_D0]
.text:000000000000854E 1A8                 add     rax, 2
.text:0000000000008552 1A8                 setb    cl
.text:0000000000008555 1A8                 test    cl, 1
.text:0000000000008558 1A8                 mov     [rsp+1A8h+var_D8], rax
.text:0000000000008560 1A8                 jnz     loc_88DB
.text:0000000000008566 1A8                 mov     rdi, [rsp+1A8h+var_90] ; 此处就取到用户输入
.text:000000000000856E 1A8                 mov     rsi, [rsp+1A8h+var_D8]
.text:0000000000008576 1A8                 call    sub_10DD0
.text:000000000000857B 1A8                 mov     [rsp+1A8h+var_E0], rax
.text:0000000000008583 1A8                 jmp     short $+2
```

有两个判断分别跳转到`loc_88CB`和`loc_88DB`，看了一下分别是乘法溢出和加法溢出的提示，若两次都不跳，则会调用`sub_10DD0`，而且这种溢出判断可能是`Rust`的内部机制，毕竟是安全的语言，这样一来就会把简单的代码膨胀到比较复杂的地步，我们来看一下溢出的具体判断，首先是乘法溢出:

```x86asm
.text:0000000000008513     loc_8513:                               ; CODE XREF: sub_82D0+1D0↑j
.text:0000000000008513 1A8                 mov     eax, 4
.text:0000000000008518 1A8                 mov     ecx, eax
.text:000000000000851A 1A8                 mov     rdx, [rsp+1A8h+var_30]
.text:0000000000008522 1A8                 mov     rax, rdx
.text:0000000000008525 1A8                 mov     [rsp+1A8h+var_C8], rdx
.text:000000000000852D 1A8                 mul     rcx
.text:0000000000008530 1A8                 seto    sil
.text:0000000000008534 1A8                 test    sil, 1
.text:0000000000008538 1A8                 mov     [rsp+1A8h+var_D0], rax
.text:0000000000008540 1A8                 jnz     loc_88CB
```

`[rsp+0x1A8+var_30]`的值移入`rax`，同时保存到`[rsp+1A8h+var_C8]`，然后乘以`rcx`，很明显`rcx`固定为4，`seto`是溢出置位，`sli`貌似是个寄存器，然后把乘后的值移入`[rsp+0x1A8+var_D0]`，反正大意就是若溢出则跳，再看加法溢出:

```x86asm
.text:0000000000008546 1A8                 mov     rax, [rsp+1A8h+var_D0]
.text:000000000000854E 1A8                 add     rax, 2
.text:0000000000008552 1A8                 setb    cl
.text:0000000000008555 1A8                 test    cl, 1
.text:0000000000008558 1A8                 mov     [rsp+1A8h+var_D8], rax
.text:0000000000008560 1A8                 jnz     loc_88DB
```

一样的道理，把乘后的结构加上2，再判断溢出，并把结果移入`[rsp+0x1A8+var_D8]`。
继续往下看:

```x86asm
.text:0000000000008566 1A8                 mov     rdi, [rsp+1A8h+var_90] ; 此处就取到用户输入
.text:000000000000856E 1A8                 mov     rsi, [rsp+1A8h+var_D8]
.text:0000000000008576 1A8                 call    sub_10DD0
.text:000000000000857B 1A8                 mov     [rsp+1A8h+var_E0], rax
.text:0000000000008583 1A8                 jmp     short $+2
```

`[rsp+1A8h+var_90]`是我们传入的地址，第一次变换时就是用户输入，然后`[rsp+1A8h+var_D8]`就是我们队某值乘4加2后的值，两个作参数调用`sub_10DD0`，其返回值移入`[rsp+1A8h+var_E0]`根据返回值来看，貌似是根据下标取字符，取到的是一个地址。
再来看第二部分:

```x86asm
.text:0000000000008585 1A8                 mov     eax, 4
.text:000000000000858A 1A8                 mov     ecx, eax
.text:000000000000858C 1A8                 mov     rdx, [rsp+1A8h+var_E0]
.text:0000000000008594 1A8                 mov     sil, [rdx]
.text:0000000000008597 1A8                 mov     rax, [rsp+1A8h+var_C8]
.text:000000000000859F 1A8                 mul     rcx
.text:00000000000085A2 1A8                 seto    dil
.text:00000000000085A6 1A8                 test    dil, 1
.text:00000000000085AA 1A8                 mov     [rsp+1A8h+var_E1], sil
.text:00000000000085B2 1A8                 mov     [rsp+1A8h+var_F0], rax
.text:00000000000085BA 1A8                 jnz     loc_88E9
.text:00000000000085C0 1A8                 mov     rax, [rsp+1A8h+var_F0]
.text:00000000000085C8 1A8                 add     rax, 0
.text:00000000000085CC 1A8                 setb    cl
.text:00000000000085CF 1A8                 test    cl, 1
.text:00000000000085D2 1A8                 mov     [rsp+1A8h+var_F8], rax
.text:00000000000085DA 1A8                 jnz     loc_88F7
.text:00000000000085E0 1A8                 lea     rdi, [rsp+1A8h+var_80]
.text:00000000000085E8 1A8                 mov     rsi, [rsp+1A8h+var_F8]
.text:00000000000085F0 1A8                 call    sub_10E30
.text:00000000000085F5 1A8                 mov     [rsp+1A8h+var_100], rax
.text:00000000000085FD 1A8                 jmp     short $+2
```

第二部分是类似的，只不过调用的是`sub_10E30`，从形式来看，这两个函数差不多。
后面就是重复前两部分了，总是一个`sub_10DD0`后面跟一个`sub_10E30`，而且每轮循环都是4个字符一组，猜测循环有8轮，每一轮中`sub_10DD0`依次取到第3、4、1和2个字符的地址，然后`sub_10E30`依次使用第1、3、2和4个字符的地址，注意到两个函数使用的字符串不一样，调试了一遍发现`sub_10E30`应该是给另一个字符串赋值，总的来说就是一个交换，每4个字符为一组，组内3->1，4->3，1->2，2->4，比如`qwer`就变成`eqrw`，很明显是可逆的，再来看第2个变换，理解流程后，直接看伪码比较快，`sub_10DD0`的下一句就是变换:

```cpp
    v9 = ((_BYTE)v77 + 3) & 0x1F;
    v10 = (_BYTE *)sub_10DD0((__int64)v79, v9);
    v76 = *v10 - 127;
 
    v21 = ((_BYTE)v75 + 3) & 0x1F;
    v19 = (_BYTE *)sub_10E30((__int64)&v80, v21);
    
    
    v23 = ((_BYTE)v74 + 4) & 0x1F;
    v24 = (_BYTE *)sub_10DD0((__int64)v79, v23);
    v72 = *v24 + 7;

    v35 = ((_BYTE)v71 + 4) & 0x1F;
    v33 = (_BYTE *)sub_10E30((__int64)&v80, v35);


    v37 = ((_BYTE)v69 + 5) & 0x1F;
    v38 = (_BYTE *)sub_10DD0((__int64)v79, v37);
 
    v49 = ((_BYTE)v66 + 5) & 0x1F;
    v47 = (_BYTE *)sub_10E30((__int64)&v80, v49);
  
    v51 = ((_BYTE)v64 + 6) & 0x1F;
    v52 = (_BYTE *)sub_10DD0((__int64)v79, v51);
    v62 = *v52 + 88;

    *(_BYTE *)sub_10E30((__int64)&v80, ((_BYTE)v61 + 6) & 0x1F) = v62;
```

一样的道理，把变换后的字符存入一个新的字符串，它是把组内的第4，5，6，7个字符分别作不同的操作，仍是4个字节一组，每组从下标`4 * i + 3`开始，与上`0x1F`是取低32位，可以到达循环取的目的，所以可以把整个字符串取尽，再看第3个变换:

```cpp
    v13 = ((_BYTE)v96 + 9) & 0x1F;
    v95 = *(_BYTE *)sub_10DD0((__int64)v98, v13) >> 2;
  
    v18 = ((_BYTE)v94 + 9) & 0x1F;
    v93 = *(_BYTE *)sub_10DD0((__int64)v98, v18) << 6;
 
    v22 = ((_BYTE)v92 + 9) & 0x1F;
    v20 = (_BYTE *)sub_10E30((__int64)&v99, v22);
    *v20 = v93 | v95;
    

    v29 = ((_BYTE)v91 + 10) & 0x1F;
    v89 = *(_BYTE *)sub_10DD0((__int64)v98, v29) >> 7;
   
    v34 = ((_BYTE)v88 + 10) & 0x1F;
    v86 = 2 * *(_BYTE *)sub_10DD0((__int64)v98, v34);
    
    v36 = (_BYTE *)sub_10E30((__int64)&v99, v38);
    v37 = 4LL;
    LOBYTE(v38) = v86;
    *v36 = v86 | v89;
    
    
    v45 = ((_BYTE)v83 + 11) & 0x1F;
    v81 = *(_BYTE *)sub_10DD0((__int64)v98, v45) >> 4;
    
    v50 = ((_BYTE)v80 + 11) & 0x1F;
    v78 = 16 * *(_BYTE *)sub_10DD0((__int64)v98, v50);
    
    v54 = ((_BYTE)v77 + 11) & 0x1F;
    v52 = (_BYTE *)sub_10E30((__int64)&v99, v54);
    v53 = 4LL;
    LOBYTE(v54) = v78;
    *v52 = v78 | v81;
    
    
    v61 = ((_BYTE)v75 + 12) & 0x1F;
    v73 = *(_BYTE *)sub_10DD0((__int64)v98, v61) >> 5;
    
    v66 = ((_BYTE)v72 + 12) & 0x1F;
    v70 = 8 * *(_BYTE *)sub_10DD0((__int64)v98, v66);
  
    *(_BYTE *)sub_10E30((__int64)&v99, ((_BYTE)v69 + 12) & 0x1F) = v70 | v73;
```

一样的道理，直接可以反推写脚本了:

```python
#!/usr/bin/env python
# _*_ coding: utf-8 _*_

arr = [0xDA, 0xD8, 0x3D, 0x4C, 0xE3, 0x63, 0x97, 0x3D, 0xC1, 0x91, 0x97, 0x0E, 0xE3, 0x5C, 0x8D, 0x7E,
       0x5B, 0x91, 0x6F, 0xFE, 0xDB, 0xD0, 0x17, 0xFE, 0xD3, 0x21, 0x99, 0x4B, 0x73, 0xD0, 0xAB, 0xFE]

#s = 'qwertyuiopasdfghjklzxcvbnm123456'
arr_1 = [0] * 32
arr_2 = [0] * 32
arr_3 = [0] * 32

for i in range(0, 32, 4):
    arr_1[(i + 9) & 0x1F] = ((arr[(i + 9) & 0x1F] << 2) | (arr[(i + 9) & 0x1F] >> 6)) & 0xFF
    arr_1[(i + 10) & 0x1F] = ((arr[(i + 10) & 0x1F] << 7) | (arr[(i + 10) & 0x1F] >> 1)) & 0xFF
    arr_1[(i + 11) & 0x1F] = ((arr[(i + 11) & 0x1F] << 4) | (arr[(i + 11) & 0x1F] >> 4)) & 0xFF
    arr_1[(i + 12) & 0x1F] = ((arr[(i + 12) & 0x1F] << 5) | (arr[(i + 12) & 0x1F] >> 3)) & 0xFF

for i in range(0, 32, 4):
    arr_2[(i + 3) & 0x1F] = (arr_1[(i + 3) & 0x1F] + 127) & 0xFF
    arr_2[(i + 4) & 0x1F] = (arr_1[(i + 4) & 0x1F] - 7) & 0xFF
    arr_2[(i + 5) & 0x1F] = (arr_1[(i + 5) & 0x1F] - 18) & 0xFF
    arr_2[(i + 6) & 0x1F] = (arr_1[(i + 6) & 0x1F] - 88) & 0xFF

for i in range(0, 32, 4):
    #arr_3[i] = arr_2[i + 2]
    #arr_3[i + 2] = arr_2[i + 3]
    #arr_3[i + 1] = arr_2[i]
    #arr_3[i + 3] = arr_2[i + 1]
    arr_3[i + 2] = arr_2[i]
    arr_3[i + 3] = arr_2[i + 2]
    arr_3[i] = arr_2[i + 1]
    arr_3[i + 1] = arr_2[i + 3]


for i in range(32):
    print chr(arr_3[i]),
```

解得`flag`是`QCTF{Rus4_1s_fun4nd_1nt3r3st1ng}`。
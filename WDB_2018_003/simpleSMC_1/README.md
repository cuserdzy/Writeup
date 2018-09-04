# SimpleSMC
***

静态链接的文件，`main`函数是`sub_400D45`，首先会输出字符串并读入用户输入:

```x86asm
.text:0000000000400D5A                 xor     eax, eax
.text:0000000000400D5C                 mov     edi, offset aInputYourFlag ; "input your flag:"
.text:0000000000400D61                 call    sub_410060
.text:0000000000400D66                 lea     rax, [rbp+input]
.text:0000000000400D6A                 mov     rsi, rax
.text:0000000000400D6D                 mov     edi, offset aS  ; "%s"
.text:0000000000400D72                 mov     eax, 0
.text:0000000000400D77                 call    sub_40F790
.text:0000000000400D7C                 lea     rax, [rbp+input]
.text:0000000000400D80                 add     rax, 15h
.text:0000000000400D84                 mov     rdi, rax
.text:0000000000400D87                 call    sub_400BAC
.text:0000000000400D8C                 test    eax, eax
.text:0000000000400D8E                 jz      short loc_400DB1
```

可以看到最后的调用的`loc_400BAC`的参数是`input[21:]`，其返回值应当不为零。
步入该函数，发现加花了，把`loc_400BC8`处的字节`nop`掉即可，再看伪码:

```cpp
signed __int64 __fastcall sub_400BAC(__int64 a1)
{
  int i; // [rsp+Ch] [rbp-Ch]

  for ( i = 0; byte_400AA6[i] != -61; ++i )
    byte_400AA6[i] ^= *(_BYTE *)(i % 7 + a1);
  return 1LL;
}
```

可以看到其中是对`byte_400AA6`处的字节异或，异或上的值和用户输入有关，若当前字节是`C3h`则退出循环，但是和用户输入相关就有些麻烦，似乎是要猜`key`。
因为函数的首部一般都是`push    rbp`，即`0x55`，所以我想到的方法是用特殊部分来反推，但是我试了下第一个字节（`0x46 ^ 0x55`），结果等于`0x13`，很明显是不对的，之后就在此处卡了很久。

正确方法应该是查该数组的交叉引用，能查到第三个函数`init_array`也引用了它，其中也加花了，和之前是一样的套路，`nop`掉即可，该函数的栈也是不平衡的，调整一下就可以`F5`了，其中核心逻辑就是`byte_400AA6[i] ^= *((_BYTE *)sub_41E1B0 + i);`，所以说`byte_400AA6`实际上提前变换了一次:

```cpp
#include <idc.idc>

static main() {
    auto start = 0x400AA6;
    auto i = 0;
    while(Byte(start + i) != 0xC3) {
        PatchByte(start + i, Byte(start + i) ^ Byte(0x41E1B0 + i));
        i++;
    }
}
```

在变换后的基础上反推，就能得到第一个字节是`46h`，即字符`F`，接下来的几个字节仍需要猜测，下一条指令可能是`mov     rbp, rsp`，即`48h`，`89h`，`E5h`，解得`1`，`@`，`g`，第三条指令应该是`sub     rsp, xxx`，此类指令前三个字节总是`48h`，`83h`，`ECh`，而最后一个/多个字节是`xxx`，以此为假设，可以求得最后三个字符是，``h`，`e`，也就是该段用户输入可能是`F1@gChe`，试一下使用该字符串解密:

```cpp
#include <idc.idc>

static main() {
    auto start = 0x400AA6;
    auto i = 0;
    auto str = "F1@gChe";
    while(Byte(start + i) != 0xC3) {
        PatchByte(start + i, Byte(start + i) ^ ord(substr(str, i % 7, i % 7 + 1)));
        i++;
    }
}
```

`IDC`脚本似乎不支持`C`风格的取元素，只能截取字符串再转成字符。

再回头看`main`函数:

```x86asm
.text:0000000000400D90                 lea     rax, [rbp+input]
.text:0000000000400D94                 mov     rdi, rax
.text:0000000000400D97                 call    sub_400AA6
.text:0000000000400D9C                 test    eax, eax
.text:0000000000400D9E                 jz      short loc_400DB1
```

接下来会调用`sub_400AA6`，参数是用户输入，返回值应当不为零，步入:

```x86asm
.text:0000000000400ABF                 xor     eax, eax
.text:0000000000400AC1                 mov     rax, [rbp+input]
.text:0000000000400AC5                 mov     edx, 40h
.text:0000000000400ACA
.text:0000000000400ACA loc_400ACA:
.text:0000000000400ACA                 mov     esi, 20h
.text:0000000000400ACF                 mov     rdi, rax
.text:0000000000400AD2                 call    sub_4009AE
```

函数序言后会调用`sub_4009AE`，参数是用户输入，`0x20`，`0x40`，步入后发现是加花的，同样的方法去除花指令，直接看伪码:

```cpp
void __fastcall sub_4009AE(__int64 a1, signed int a2, int a3)
{
  int initial_64; // [rsp+0h] [rbp-10h]

  initial_64 = a3;
  sub_400A18(a1, a2 >> 1);
  if ( initial_64 )
    sub_4009AE(a1, a2, initial_64 - 1);

```

发现是一个递归，主要的函数是`sub_400A18`，步入:

```cpp
__int64 __fastcall sub_400A18(__int64 a1, int a2)
{
  int i; // [rsp+1Ch] [rbp-4h]

  if ( !a2 )
    return 0LL;
  for ( i = 0; i < a2; ++i )
    *(_BYTE *)(a2 + i + a1) ^= *(_BYTE *)(i + a1);
  return sub_400A18(a1, (unsigned int)(a2 >> 1));
}
```

同样是一个递归，其中是对用户输入作变换。
实际上一个递归可以看作一个循环，两个嵌套的递归就是一个双重循环，该双重循环就是对用户输入作变换，暂时不关注算法，回到`sub_400AA6`继续往下看:

```x86asm
.text:0000000000400AD7 048                 mov     qword ptr [rbp+arr_0], 0
.text:0000000000400ADF 048                 mov     qword ptr [rbp+arr_1], 0
.text:0000000000400AE7 048                 mov     qword ptr [rbp+arr_2], 0
.text:0000000000400AEF 048                 mov     qword ptr [rbp+arr_3], 0
.text:0000000000400AF7 048                 mov     [rbp+unknow], 0
.text:0000000000400AFB 048                 mov     byte ptr [rbp+arr_0], 66h
.text:0000000000400AFF 048                 mov     byte ptr [rbp+arr_0+1], 0Ah
.text:0000000000400B03 048                 mov     byte ptr [rbp+arr_0+2], 7
.text:0000000000400B07 048                 mov     byte ptr [rbp+arr_0+3], 0Bh
.text:0000000000400B0B 048                 mov     byte ptr [rbp+arr_0+4], 1Dh
.text:0000000000400B0F 048                 mov     byte ptr [rbp+arr_0+5], 8
.text:0000000000400B13 048                 mov     byte ptr [rbp+arr_0+6], 51h
.text:0000000000400B17 048                 mov     byte ptr [rbp+arr_0+7], 38h
.text:0000000000400B1B 048                 mov     byte ptr [rbp+arr_1], 1Fh
.text:0000000000400B1F 048                 mov     byte ptr [rbp+arr_1+1], 5Ch
.text:0000000000400B23 048                 mov     byte ptr [rbp+arr_1+2], 14h
.text:0000000000400B27 048                 mov     byte ptr [rbp+arr_1+3], 38h
.text:0000000000400B2B 048                 mov     byte ptr [rbp+arr_1+4], 30h
.text:0000000000400B2F 048                 mov     byte ptr [rbp+arr_1+5], 0Ah
.text:0000000000400B33 048                 mov     byte ptr [rbp+arr_1+6], 1Ah
.text:0000000000400B37 048                 mov     byte ptr [rbp+arr_1+7], 28h
.text:0000000000400B3B 048                 mov     byte ptr [rbp+arr_2], 39h
.text:0000000000400B3F 048                 mov     byte ptr [rbp+arr_2+1], 59h
.text:0000000000400B43 048                 mov     byte ptr [rbp+arr_2+2], 0Ch
.text:0000000000400B47 048                 mov     byte ptr [rbp+arr_2+3], 24h
.text:0000000000400B4B 048                 mov     byte ptr [rbp+arr_2+4], 24h
.text:0000000000400B4F 048                 mov     byte ptr [rbp+arr_2+5], 22h
.text:0000000000400B53 048                 mov     byte ptr [rbp+arr_2+6], 1
.text:0000000000400B57 048                 mov     byte ptr [rbp+arr_2+7], 1Fh
.text:0000000000400B5B 048                 mov     byte ptr [rbp+arr_3], 1Eh
.text:0000000000400B5F 048                 mov     byte ptr [rbp+arr_3+1], 73h
.text:0000000000400B63 048                 mov     byte ptr [rbp+arr_3+2], 1Dh
.text:0000000000400B67 048                 mov     byte ptr [rbp+arr_3+3], 3Ah
.text:0000000000400B6B 048                 mov     byte ptr [rbp+arr_3+4], 8
.text:0000000000400B6F 048                 mov     byte ptr [rbp+arr_3+5], 5
.text:0000000000400B73 048                 mov     byte ptr [rbp+arr_3+6], 15h
.text:0000000000400B77 048                 mov     byte ptr [rbp+arr_3+7], 0Ah
.text:0000000000400B7B 048                 mov     rdx, [rbp+input]
.text:0000000000400B7F 048                 lea     rax, [rbp+arr_0]
.text:0000000000400B83 048                 mov     rsi, rdx
.text:0000000000400B86 048                 mov     rdi, rax
.text:0000000000400B89 048                 call    sub_400360
.text:0000000000400B8E 048                 test    eax, eax
.text:0000000000400B90 048                 setz    al
```

以上为四个大小为`8`的数组赋值，实际上它们是挨在一起的，组成了一个大小为`32`的数组，最后调用`sub_400360`，参数分别是变换后的用户输入和以上的数组，猜测一下应该是个比对函数，若返回零则把`al`置`1`。
现在来反推算法，外层循环大小为`64`，内层循环的`a2`依次是`16`，`8`，`4`，`2`，`1`，也就是说第一次变换`input[16:]`，第二次变换`input[8:15]`，第三次变换`input[4:7]`，第四次变换`input[2:3]`，最后变换`input[1:1]`，所以说第一个字符是没有变换的，从第一个字符倒着往回推，脚本:

```cpp
#include <stdio.h>

int main() {
    unsigned char flag[32] = {
        0x66, 0x0A, 0x07, 0x0B, 0x1D, 0x08, 0x51, 0x38, 0x1F, 0x5C, 0x14, 0x38, 0x30, 0x0A, 0x1A, 0x28,
        0x39, 0x59, 0x0C, 0x24, 0x24, 0x22, 0x01, 0x1F, 0x1E, 0x73, 0x1D, 0x3A, 0x08, 0x05, 0x15, 0x0A
    };
    for (int i = 0; i < 65; i++) {
        uint8_t uc = 1;
        for (int j = 0; j < 5; j++) {
            for (int k = 0; k < uc; k++) {
                flag[uc + k] ^= flag[k];
            }
            uc <<= 1;
        }
    }
    for (int i = 0; i < 32; i++) {
        printf("%c", flag[i]);
    }
}
```

此处要特别注意变换实际上是执行了`65`次:

```cpp
void __fastcall sub_4009AE(__int64 a1, signed int a2, int a3)
{
  int initial_64; // [rsp+0h] [rbp-10h]

  initial_64 = a3;
  sub_400A18(a1, a2 >> 1);
  if ( initial_64 )
    sub_4009AE(a1, a2, initial_64 - 1);

```

可以看到当`initial_64`等于`0`时，也会执行一次变换，共`65`次。
解得`flag{d0_y0u_Kn*w_5mC_F1@gCheCk?}`。
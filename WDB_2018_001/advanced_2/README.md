# Advanced
***

本题可以衍生出很多有意思的问题，我们依次来分析:
 - `So`文件怎么入手分析?
 - `D`语言的语法是什么样的? 应该用什么方法去解析它的符号名?
 - 使用对象作为参数/返回值时，在汇编上怎么具现的?
 - 调用约定到底和什么有关? 
 - 延申（另外两道题）


#### 分析So文件

对于`So`文件，首先要做的就是分析它的导出表，一般来说`So`文件提供的功能不会在`main`函数中，而是导出一些重要功能提供给外部使用，所以我们需要自己写一个`Loader`程序来动态加载`So`文件。
由导出表可以找到一个和加密相关的函数`_D3src7encryptFNaNfAyaZQe`（实际上从导出表来找并不容易，若结合字符串信息可以更快、更精确的定位）。
此处比较麻烦的是要使用`D`语言程序来动态加载`So`库，否则会引起调用约定不一样的问题，（但是我觉得`C`语言也可以，因为它们的调用约定确实很相似，而且对于我们要调用的函数，它的调用约定甚至是一模一样的），后来发现`D`语言动态加载`So`库的方法和`C`语言是一样的，那使用`D`语言肯定更方便，可以使用[Using dlopen/dlsym][1]中的脚本:

```d
//ldc2 loader.d
import core.stdc.stdio;
import core.sys.posix.dlfcn;

void function(immutable(char)[]) p;
void main()
{
    void *hndl = dlopen("./src", RTLD_LAZY);
    if (!hndl) 
        printf("%s\n", dlerror());
    p = cast (void function(immutable(char)[]))dlsym(hndl, "_D3src7encryptFNaNfAyaZQe".ptr);
    if (!p)
        printf("%s\n", dlerror());
    immutable(char)[] str = "qwertyuiop";
    p(str);
}
```

可以看到和`C`语言的脚本是差不多的，有差别的地方就是函数指针的定义，以及强制转换时要加上`cast`。
使用该程序就能调用加密函数，此处有一个地方可能会比较疑惑，为什么从汇编看是使用了两个参数，但是解析出来的函符号名是`pure @safe immutable(char)[] src.encrypt(immutable(char)[])`，很明显只有一个参数，**因为`immutable(char)[]`是一个类，它包含两个字段，长度和字符串，所以我们传参时是使用两个寄存器来传**。

实际上使用`C`语言版的`Loader`也是可以的，因为它们的调用约定是相同的，所以可以混用:

```c
//gcc loader.c -o loader -ldl
#include <stdio.h>
#include <dlfcn.h>

typedef char* (*Func)(int, char*);
int main()
{
    void *hndl = dlopen("./src", RTLD_LAZY);
    if (!hndl) 
        printf("%s\n", dlerror());
    Func p = (Func)dlsym(hndl, "_D3src7encryptFNaNfAyaZQe");
    if (!p)
        printf("%s\n", dlerror());
    p(10, "qwertyuiop");
    return 0;
}
```
（编译时注意加上`-ldl`）


#### D语言语法以及符号名解析

在分析函数之前，我们需要把符号名解析，可以使用`D`语言自带的`demangle`模块，官网上的脚本:

```cpp
import std.ascii : isAlphaNum;
import std.algorithm.iteration : chunkBy, joiner, map;
import std.algorithm.mutation : copy;
import std.conv : to;
import std.demangle : demangle;
import std.functional : pipe;
import std.stdio : stdin, stdout;

void main()
{
    stdin.byLineCopy
        .map!(
            l => l.chunkBy!(a => isAlphaNum(a) || a == '_')
                  .map!(a => a[1].pipe!(to!string, demangle)).joiner
        )
        .copy(stdout.lockingTextWriter);
}
```

（该脚本只能在`Dmd`编译器下成功，原因不明，`Linux`直接下`.deb`后缀的包，直接双击安装，而且我发现`Dmd`不会和`Ldc`冲突，但是`Gdc`会和`Ldc`冲突）。


#### 使用对象作为参数/返回值

先写一个示例:

```cpp
//gcc ./class.cpp -o class
#include <stdio.h>

class A {
public:
    long long field_0;
    long long field_1;
    A() {
        field_0 = 0;
        field_1 = 0;
    }
};
A transform(A one);
int main() {

    A a;
    A b = transform(a);
    printf("%lld\n", b.field_0);
    printf("%lld\n", b.field_1);
    return 0;

}
A transform(A a) {
    a.field_0 = 3;
    a.field_1 = 5;
    return a;
}
```

程序就是调用了一个传入对象，并返回对象的函数，现在我们来看一下该函数的汇编:

```x86asm
.text:00000000004005B9                 mov     rdx, [rbp+var_30]
.text:00000000004005BD                 mov     rax, [rbp+var_28]
.text:00000000004005C1                 mov     rdi, rdx
.text:00000000004005C4                 mov     rsi, rax
.text:00000000004005C7                 call    _Z9transform1A  ; transform(A)
.text:00000000004005CC                 mov     [rbp+var_20], rax
.text:00000000004005D0                 mov     [rbp+var_18], rdx
.text:00000000004005D4                 mov     rax, [rbp+var_20]
.text:00000000004005D8                 mov     rsi, rax
.text:00000000004005DB                 mov     edi, offset format ; "%lld\n"
.text:00000000004005E0                 mov     eax, 0
.text:00000000004005E5                 call    _printf
.text:00000000004005EA                 mov     rax, [rbp+var_18]
.text:00000000004005EE                 mov     rsi, rax
.text:00000000004005F1                 mov     edi, offset format ; "%lld\n"
.text:00000000004005F6                 mov     eax, 0
.text:00000000004005FB                 call    _printf
```

（以上只截取了重点部分）

此部分可以参考`《C++反汇编与逆向分析技术揭秘》`一书的`p220`页。
当对象作为参数时，它不会把对象的地址入栈（因为对象名不像数组名可以代表自身的地址），而是把所有数据复制到寄存器/栈中（`x64`下复制到寄存器，`x86`下是入栈），也就是说把对象中的数据成员看作多个变量。
再看我们的示例，由于书中是`x86`的，并没有讲`x64`的情况，所以此处需要我们自己分析。
书中提到在对象中定义靠前的变量的后入栈，说明编译器把就是把对象简单的展开，所以相应地在`x64`中靠前的变量先移入寄存器，也就是说前后两个字段分别移入`rdi`和`rsi`，而返回时也是把前后两个字段从`rax`和`rdx`返回，但我尝试增加变量时，`gcc`会直接使用栈来传参，导致实验不成功。
还有一个比较有趣的事情，若我把两个字段都设为`int`型，编译器会把两个字段放在一个寄存器里传参，可以试试看（`x86`当真是神仙优化）。


#### 加密函数的分析

有了以上的知识，再来分析加密函数:

```x86asm
.text:00000000000566EC                 push    rbp
.text:00000000000566ED                 mov     rbp, rsp
.text:00000000000566F0                 sub     rsp, 10h
.text:00000000000566F4                 mov     [rbp+len], rdi
.text:00000000000566F8                 mov     [rbp+str], rsi
.text:00000000000566FC                 mov     rdx, [rbp+str]
.text:0000000000056700                 mov     rax, [rbp+len]
.text:0000000000056704                 mov     rdi, rax
.text:0000000000056707                 mov     rsi, rdx
.text:000000000005670A                 call    _D3src__T3encVAyaa3_313131ZQsFNaNfQuZQx
.text:000000000005670F                 mov     rdi, rax
.text:0000000000056712                 mov     rsi, rdx
.text:0000000000056715                 call    _D3src__T3encVAyaa3_323232ZQsFNaNfQuZQx
```

加密函数的定义是`pure @safe immutable(char)[] src.encrypt(immutable(char)[])`，传入传出的都是`immutable`，该函数中调用了很多类似的函数，它们的定义基本上都是`pure @safe immutable(char)[] src.enc!("111").enc(immutable(char)[])`，传入传出的也都是`immutable`对象。
根据前面的知识很容易就能看出来`rdi`和`rax`负责传入/传出长度字段，`rsi`和`rdx`负责传入/传出字符串字段。
下面以第一个函数为例:

```x86asm
.text:00000000000604D0                 push    rbp
.text:00000000000604D1                 mov     rbp, rsp
.text:00000000000604D4                 sub     rsp, 0A0h
.text:00000000000604DB                 mov     [rbp+tmp_0], rbx ;
.text:00000000000604DB                                         ; ;以上是利用局部变量保存寄存器
.text:00000000000604E2                 mov     [rbp+len], rdi  ; 但是以下两步不是，它们是转存参数
.text:00000000000604E6                 mov     [rbp+str], rsi
.text:00000000000604EA                 call    _D3std4conv__T2toTiZ__TQjTmZQoFNaNfmZi
.text:00000000000604EF                 mov     [rbp+j_len], al ;
.text:00000000000604EF                                         ; ;
.text:00000000000604F5                 lea     rcx, unk_AE6A0
.text:00000000000604FC                 xor     eax, eax
.text:00000000000604FE                 mov     [rbp+ret_str], rax
.text:0000000000060502                 mov     [rbp+ret_len], rcx ;
```
`_D3std4conv__T2toTiZ__TQjTmZQoFNaNfmZi`解析后得到`pure @safe int std.conv.to!(int).to!(ulong).to(ulong)`，它是把长度强制转换为`int`，并将结果的低`8`位移入局部变量，此步不会影响什么，然后初始化返回值。

```x86asm
.text:0000000000060506                 lea     rdx, a111       ; "111"
.text:000000000006050D                 mov     esi, 3
.text:0000000000060512                 lea     rdi, [rbp+var_40]
.text:0000000000060516                 call    _D3std5range__T5cycleTAyaZQlFNaNbNiNfQpZSQBnQBm__T5CycleTQBjZQl
.text:000000000006051B                 mov     rbx, rax
```

上面的函数解析得到`pure nothrow @nogc @safe std.range.Cycle!(immutable(char)[]).Cycle std.range.cycle!(immutable(char)[]).cycle(immutable(char)[])`，但是该函数很明显只有一个参数，传入的是`immutable`，但是从汇编看是传入了三个参数，我猜测该函数是一个成员函数，所以额外传入了一个`this`指针，而后两个参数就是`immutable`的两个字段（因为是全局变量，所以被优化了），最后返回的结果会移入`rbx`。

```x86asm
.text:000000000006051E                 push    qword ptr [rbx+18h]
.text:0000000000060521                 push    qword ptr [rbx+10h]
.text:0000000000060524                 push    qword ptr [rbx+8]
.text:0000000000060527                 push    qword ptr [rbx]
.text:0000000000060529                 mov     rdx, [rbp+str]
.text:000000000006052D                 mov     rsi, [rbp+len]
.text:0000000000060531                 lea     rdi, [rbp+var_70]
.text:0000000000060535                 call    _D3std5range__T3zipTSQtQr__T5CycleTAyaZQlTQhZQBeFNaNbNiNfQBlQzZSQCkQCj__T11ZipShortestVEQDi8typecons__T4FlagVQCwa18_616c6c4b6e6f776e53616d654c656e677468ZQByi0TQFjTQEyZQDq
.text:000000000006053A                 add     rsp, 20h
```

此处调用的是`pure nothrow @nogc @safe std.range.ZipShortest!(0, std.range.Cycle!(immutable(char)[]).Cycle, immutable(char)[]).ZipShortest std.range.zip!(std.range.Cycle!(immutable(char)[]).Cycle, immutable(char)[]).zip(std.range.Cycle!(immutable(char)[]).Cycle, immutable(char)[])`，看起来是`6`个参数，但是实际上应该只有`Cycle`和`immutable`两个参数，最后是`zip`对象的`this`指针，应该会在`[rbp+var_70]`初始化一个`zip`对象。
最想不明白的就是`zip`对象是做什么的，只能根据后面的调试结果来猜。

```x86asm
.text:000000000006053E loc_6053E:                              ; CODE XREF: _D3src__T3encVAyaa3_313131ZQsFNaNfQuZQx+B7↓j
.text:000000000006053E                 lea     rdi, [rbp+var_70]
.text:0000000000060542                 call    _D3std5range__T11ZipShortestVEQBc8typecons__T4FlagVAyaa18_616c6c4b6e6f776e53616d654c656e677468ZQByi0TSQDwQDv__T5CycleTQCpZQlTQCwZQEk5emptyMFNaNbNdNiNfZb
.text:0000000000060547                 xor     al, 1
.text:0000000000060549                 jz      short loc_60589 ;
.text:0000000000060549                                         ; ;判断empty()的返回值
.text:000000000006054B                 lea     rdi, [rbp+var_70]
.text:000000000006054F                 call    _D3std5range__T11ZipShortestVEQBc8typecons__T4FlagVAyaa18_616c6c4b6e6f776e53616d654c656e677468ZQByi0TSQDwQDv__T5CycleTQCpZQlTQCwZQEk5frontMFNaNdNfZSQFqQEo__T5TupleTwTwZQl
.text:0000000000060554                 mov     [rbp+tmp_1], rax
.text:0000000000060558                 lea     rax, [rbp+tmp_1]
.text:000000000006055C                 mov     [rbp+j_tmp_1], rax
.text:0000000000060560                 mov     rcx, [rbp+j_tmp_1]
.text:0000000000060564                 lea     rdx, [rcx+4]
.text:0000000000060568                 mov     esi, [rax]
.text:000000000006056A                 xor     esi, [rdx]
.text:000000000006056C                 movzx   ebx, [rbp+j_len]
.text:0000000000060573                 xor     esi, ebx
.text:0000000000060575                 lea     rdi, [rbp+ret_str]
.text:0000000000060579                 call    _d_arrayappendcd
.text:000000000006057E                 lea     rdi, [rbp+var_70]
.text:0000000000060582                 call    _D3std5range__T11ZipShortestVEQBc8typecons__T4FlagVAyaa18_616c6c4b6e6f776e53616d654c656e677468ZQByi0TSQDwQDv__T5CycleTQCpZQlTQCwZQEk8popFrontMFNaNbNiNfZv
.text:0000000000060587                 jmp     short loc_6053E
```

以上是一个循环，首先会判断`pure nothrow @property @nogc @safe bool std.range.ZipShortest!(0, std.range.Cycle!(immutable(char)[]).Cycle, immutable(char)[]).ZipShortest.empty()`的返回值，当对象为空时，返回`true`，然后跳出循环，否则调用`pure @property @safe std.typecons.Tuple!(dchar, dchar).Tuple std.range.ZipShortest!(0, std.range.Cycle!(immutable(char)[]).Cycle, immutable(char)[]).ZipShortest.front()`获取最前面的一个元素，它是把得到的元素分为两个`Dword`，二者相异或后，再和传入的长度异或，调用`_d_arrayappendcd`挂到`array`后面，循环最后调用`pure nothrow @nogc @safe void std.range.ZipShortest!(0, std.range.Cycle!(immutable(char)[]).Cycle, immutable(char)[]).ZipShortest.popFront()`把最前面的元素弹出。

```x86asm
.text:0000000000060589                 mov     rdx, [rbp+ret_len]
.text:000000000006058D                 mov     rax, [rbp+ret_str]
.text:0000000000060591                 mov     rbx, [rbp+tmp_0]
.text:0000000000060598                 leave
.text:0000000000060599                 retn
```

最后返回的就是`immutable(char)[]`，返回值就保存在`rdx`和`rax`中，在下一个函数中使用上一个函数返回的长度和字符串。

总的来看，流程是不难的，主要是`zip`对象实在无法理解，以及调用`_d_arrayappendcd`时总是会使进程挂起，即使我输入正确的答案仍然如此。
但根据调试得到的结果，程序应该是把字符串循环，然后把传入的字符串异或上循环后的字符串以及长度，我感觉程序奇怪地`hang`住应该是题目本身的问题。
既然加密算法就是异或，那么把流程倒着写即可解密:

```python
//advanced.py
import itertools

arr = [0x4B, 0x40, 0x4C, 0x4B, 0x56, 0x48, 0x72, 0x5B, 0x44, 0x58, 0x45, 0x73, 0x4C, 0x73, 0x59, 0x49, 0x40, 0x5C, 0x41, 0x4D, 0x59, 0x49, 0x72, 0x5C, 0x45, 0x49, 0x5A, 0x51]

for i in range(499, 0, -1):
    s = str(i) + str(i) + str(i)
    print s
    count = 0
    for c in itertools.cycle(s):
        arr[count] = arr[count] ^ ord(c) ^ 0x1c
        count = count + 1
        if count >= 0x1c:
            break
for i in range(0x1c):
    print chr(arr[i]),
```

解得`flag`是`flag{d_with_a_template_phew}`。

#### 调用约定和什么有关（`TODO`）

做此题时一直比较疑惑，为什么同是`elf`文件，调用约定却不一样，但是后来发现它们的调用约定是一样的，由于使用了对象作为参数才出现了比较奇怪的情况。
所谓调用约定就是`ABI`的一个分支，`ABI`允许编译好的目标代码在使用兼容`ABI`的系统中无需改动的执行，`ABI`包括调用约定，类型表示和名称修饰三者，有时间再研究。。。

分析`D`语言的程序时，可以尝试在函数列表里搜索一下`dmd`，`gdc`，`ldc`的字样，说不定会有意外收获。

#### 延申（`TODO`）

第一题是`NJCTF 2017`的`On The Fly`，但是它是可执行文件，不像`windows`下一样，`exe`也能被加载。

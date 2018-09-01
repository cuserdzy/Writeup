# asong

题目给了3个文件，应该是有和文件有关的操作，`main`中基本上是调用自写的函数，依次看。

```cpp
  v3 = malloc(0xBCuLL);
  v4 = (const char *)malloc(0x50uLL);
  sub_400BBF();
  sub_400B4C((__int64)v4);
  sub_400C02((__int64)v4);
  sub_400AAA("that_girl", (__int64)v3);
  sub_400E54(v4, (__int64)v3);
```

首先在堆上申请了两个空间，`sub_400BBF`中调用了`setbuf`函数，目测是和标准输入/输出/错误流有关。接着看`sub_400B4C`:

```cpp
  for ( i = 0; ; ++i )
  {
    LOBYTE(v1) = read(0, (void *)(i + a1), 1uLL) == 1;
    if ( !(_BYTE)v1 )
      break;
    if ( *(_BYTE *)(i + a1) == 10 || i > 100 )
    {
      v1 = (_BYTE *)(i + a1);
      *v1 = 0;
      return (char)v1;
    }
  }
```

此循环每次从标准输入流读1个字符，若`read`函数返回零，直接退出循环，反之会判断，若用户输入回车或已经输入超过100个字符，则把回车置0后直接返回，该函数就是简单的读取用户输入。接下来是`sub_400C02`:

```cpp
  dest = malloc(0x50uLL);
  if ( memcmp((const void *)a1, "QCTF{", 5uLL) )
    exit(-1);
  memcpy(dest, (const void *)(a1 + 5), 0x4BuLL);
  v1 = strlen((const char *)dest);
  if ( *((_BYTE *)dest + v1 - 1) == 125 )
    *((_BYTE *)dest + v1 - 1) = 0;
  memcpy((void *)a1, dest, 0x50uLL);
  free(dest);
```

首先比较前5个字符，若不是"QCTF{"则退出程序，然后把之后的用户输入拷贝到dest，判断其最后一个字符是否是'}'，若是，把其置0，最后把花括号中间的字符串再拷回`a1`中，该函数是截取花括号中间的内容。然后是`sub_400AAA`，从参数来看应该有文件操作:

```cpp
  v7 = __readfsqword(0x28u);
  fd = open(a1, 0, a2, a1);
  while ( read(fd, &buf, 1uLL) == 1 )
  {
    v2 = sub_400936(buf);
    ++*(_DWORD *)(4LL * v2 + v4);
  }
```

它是每次从文件中读取1个字符，然后传入`sub_400936`，返回v2，感觉伪码不对，`v4`应该是`a2`，从`open`函数开始参数就分析错了，a2处类似一个桶，每个桶大小为`int`，共47个桶，因为该文件是固定的，所以每个桶也是固定的，暂时不知道是用来做什么的。最后是`sub_400E54`:

```cpp
  v6 = __readfsqword(0x28u);
  v4 = strlen(a1);
  for ( i = 0; i < v4; ++i )
    v5[i] = *(_DWORD *)(4LL * (signed int)sub_400936(a1[i]) + a2);
  sub_400D33((unsigned __int8 *)v5);
  sub_400DB4(v5, v4);
  sub_400CC0((__int64)v5, "out", v4);
```

该函数中先一个循环，它是根据用户输入的字符，经`sub_400936`变换后，去桶中筛出相应的值，然后会依次调用3个函数，最后的`sub_400CC0`应该是写文件，我们最后得到的输出应该要和`out`文件中的输出一样。
首先看`sub_400D33`:

```cpp
  v2[4] = 0;
  *(_DWORD *)v2 = *a1;
  while ( dword_6020A0[*(signed int *)&v2[1]] )
  {
    a1[*(signed int *)&v2[1]] = a1[dword_6020A0[*(signed int *)&v2[1]]];
    *(_DWORD *)&v2[1] = dword_6020A0[*(signed int *)&v2[1]];
  }
  result = v2[0];
  a1[*(signed int *)&v2[1]] = v2[0];
```

循环终止条件是`dword_6020A0[v2[1]]`对应的值是0，后面的变换没看懂。。。反正是对`v5`作变换了，再看`sub_400DB4`:

```cpp
  v3 = *a1 >> 5;
  for ( i = 0; a2 - 1 > i; ++i )
    a1[i] = 8 * a1[i] | (a1[i + 1] >> 5);
  result = &a1[i];
  *result = 8 * *result | v3;
```

该函数每次取当前字符的高5位和后一个字符的低3位组成一个新的字符，循环结束把最后一个字符的高5位和之前记录的第一个字符的低3位组合。
最后一个函数把变换后的数据写入文件。

初始桶大小是47，应该是把用户输入的每一个字符通过`sub_400936`映射成一个小于等于47的值，通过调试可以得到初始桶是:

```cpp
0x603010:   0x00    0x00    0x00    0x00    0x00    0x00    0x00    0x00
0x603030:   0x00    0x00    0x68    0x1e    0x0f    0x1d    0xa9    0x13
0x603050:   0x26    0x43    0x3c    0x00    0x14    0x27    0x1c    0x76
0x603070:   0xa5    0x1a    0x00    0x3d    0x33    0x85    0x2d    0x07
0x603090:   0x22    0x00    0x3e    0x00    0x00    0x00    0x00    0x00
0x6030b0:   0x00    0x28    0x47    0x00    0x00    0x42    0xf5
```

看一下`sub_400936`，有一个大的`switch`，特殊符号会单独处理，然后小写字母减去87，大写字母减去55，数字减去48，也就是说大小写字母偏移一样会映射成同一个值，数字映射到其本身值，其余的特殊字符另算，总共是26 + 10 + 11 = 47。 

然后根据用户输入得到一个字节数组也没错

发现每次都在变换`v2[1]`，而`v2[1]`又被当作下标去访问别的值，`dword_6020A0`数组是不变的，

先把节字合并:

```python
out = [0xEC, 0x29, 0xE3, 0x41, 0xE1, 0xF7, 0xAA, 0x1D, 0x29, 0xED, 0x29, 0x99, 0x39, 0xF3, 0xB7, 0xA9,
       0xE7, 0xAC, 0x2B, 0xB7, 0xAB, 0x40, 0x9F, 0xA9, 0x31, 0x35, 0x2C, 0x29, 0xEF, 0xA8, 0x3D, 0x4B,
       0xB0, 0xE9, 0xE1, 0x68, 0x7B, 0x41]
input = []
tmp = ((out[len(out) - 1] << 5) | (out[0] >> 3)) & 0xFF
input.append(tmp)
for i in range(1, len(out)):
    tmp = ((out[i - 1] << 5) | (out[i] >> 3)) & 0xFF
    input.append(tmp)
```

得到合并前的序列是`0x3d, 0x85, 0x3c, 0x68, 0x3c, 0x3e, 0xf5, 0x43, 0xa5, 0x3d, 0xa5, 0x33, 0x27, 0x3e, 0x76, 0xf5, 0x3c, 0xf5, 0x85, 0x76, 0xf5, 0x68, 0x13, 0xf5, 0x26, 0x26, 0xa5, 0x85, 0x3d, 0xf5, 0x7, 0xa9, 0x76, 0x1d, 0x3c, 0x2d, 0xf, 0x68`。

主要是循环替换没看懂，简化一下:

```cpp
  v2[4] = 0;
  *v2 = *a1;
  while ( dword_6020A0[v2[1]] )
  {
    a1[v2[1]] = a1[dword_6020A0[v2[1]]];
    v2[1] = dword_6020A0[v2[1]];
  }
  result = v2[0];
  a1[v2[1]] = v2[0];
```

我们把`v2[1]`看作下标`index`，则有`a1[index] = a1[dword_6020A0[index]]`和`index = dword_6020A0[index]`，也就是说`index`每次都在置换，而且它总是`dword_6020A0`中的值，这个数组的值是打乱的0~37的序列，我们放入一个初值，它会不断在数组中跳转直到下一跳`dword_6020A0[index]`的值为0，所以我们可以反推出`index`跳转的顺序:

```python
index = 1
for i in range(37):
    for j in range(38):
        if table[j] == index:
            index = j
            print j,
            break
```

得到反序的跳转顺序是"1 7 9 6 2 3 18 10 11 21 8 12 13 16 23 15 24 5 25 26 35 37 31 32 33 34 36 27 28 29 30 4 17 14 19 20 22 0"，那么正序就是`[0, 22, 20, 19, 14, 17, 4, 30, 29, 28, 27, 36, 34, 33, 32, 31, 37, 35, 26, 25, 5, 24, 15, 23, 16, 13, 12, 8, 21, 11, 10, 18, 3, 2, 6, 9, 7, 1]`，所以可知我们第一跳的下标是0，最后一跳的下标是1。

而且仔细观察后，会发现每次`a1[index]`的值是被赋为它下一跳对应的值，从最后一次有`a1[1] = a1[7]`，而`a1[1]`不会再变，前面已经推导出置换后的`a1[1]`是0x85，所以可以推出原序列。

```python
input = [0x3d, 0x85, 0x3c, 0x68, 0x3c, 0x3e, 0xf5, 0x43, 0xa5, 0x3d, 0xa5, 0x33, 0x27, 0x3e, 0x76, 0xf5, 0x3c, 0xf5, 0x85,
         0x76, 0xf5, 0x68, 0x13, 0xf5, 0x26, 0x26, 0xa5, 0x85, 0x3d, 0xf5, 0x07, 0xa9, 0x76, 0x1d, 0x3c, 0x2d, 0xf, 0x68]
jump = [1, 7, 9, 6, 2, 3, 18, 10, 11, 21, 8, 12, 13, 16, 23, 15, 24, 5, 25, 26, 35, 37, 31, 32, 33, 34, 36, 27, 28, 29, 30, 4, 17, 14, 19, 20, 22, 0]

pre = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
       0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]

for i in range(37):
    pre[jump[i]] = input[jump[i + 1]]
pre[1] = input[1]
for i in range(38):
    print hex(pre[i]),
```

得到置换前的序列是`0x0 0x85 0x68 0x85 0xf5 0x26 0x3c 0x3d 0x27 0xf5 0x33 0x68 0x3e 0x3c 0x76 0x26 0xf5 0x76 0xa5 0xf5 0x13 0xa5 0x3d 0xf5 0x3e 0xa5 0x2d 0x3d 0xf5 0x7 0x3c 0x76 0x1d 0x3c 0xf 0x68 0x85 0xa9`

把该序列拿去桶中还原即可。

得到最后的`flag`是`QCTF{that_girl_saying_no_for_your_vindicate}`。
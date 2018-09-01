# martricks
***

核心算法就在`main`中，修改变量名后可以直接看伪码:

```cpp
  canary = __readfsqword(0x28u);
  puts("input your flag:");
  __isoc99_scanf("%49s", input);
  isCorrect = 1;
  i = 0;
  index_0 = 23;
  while ( i <= 48 )
  {
    *((_BYTE *)&savedregs + 7 * (index_0 / 7) + index_0 % 7 - 192) = input[i] ^ index_0;
    *((_BYTE *)&savedregs + 7 * (i / 7) + i % 7 - 128) = byte_601060[index_0] ^ i;
    ++i;
    index_0 = (index_0 + 13) % 49;
  }
```

第一部分是一个循环，比较有趣的是`7 * (index_0 / 7) + index_0 % 7`，仔细算一下，发现它根本就是不起作用的，总是等于`index_0`，也就是说该循环是在为两个数组赋值，`index_0`和`i`分别指出两个数组的下标，`i`是顺序递增的，`index_0`是乱序，跑了一下发现是没有重复的。

```cpp
  ia = 41;
  index_1 = 3;
  index_2 = 4;
  index_3 = 5;
  j = 0;
  while ( j <= 6 && isCorrect )
  {
    k = 0;
    while ( k <= 6 && isCorrect )
    {
      sum = 0;
      l = 0;
      while ( l <= 6 )
      {
        sum += *((_BYTE *)&savedregs + 7 * index_3 + index_2 - 128)
             * *((_BYTE *)&savedregs + 7 * index_1 + index_3 - 192);
        ++l;
        index_3 = (index_3 + 5) % 7;
      }
      for ( index_0a = 17; index_0a != ia; index_0a = (index_0a + 11) % 49 )
        ;
      if ( byte_6010A0[7 * (index_0a / 7) + index_0a % 7] != ((unsigned __int8)index_0a ^ sum) )
        isCorrect = 0;
      ia = (ia + 31) % 49;
      ++k;
      index_2 = (index_2 + 4) % 7;
    }
    ++j;
    index_1 = (index_1 + 3) % 7;
  }
```

下面是一个三重循环，最里面的循环有些像矩阵相乘，但是相乘的行和列都是乱的，第一层循环控制的是后矩阵的行，第二层循环控制的是前矩阵的列，第三层循环控制的是哪两个字符相乘（第三层循环的下标实际上不影响什么，因为它们的和总是相等的）。

#### 算法分析

此步想了很多办法，虽然知道是一个变形的矩阵乘法，但是不会解。
后来觉得凡是矩阵相乘，本质上都是一个线性方程组，但是`7 * 7`的矩阵相乘，就有`49`个方程，我觉得把方程一一列出来很麻烦，就没有用此方法，之后想到我们可以直接用程序格式化输出方程，然后再把方程用`Z3`来解就可以了。

~~具体方法:
 - 先正向生成两个矩阵`mat_input`和`mat_const`
 - 接着利用三重循环生成`49`个方程的左侧
 - 最后每次在第三重循环结束后补上方程的右侧~~

最后使用`Z3`来求解:

```python
from z3 import *

s = Solver()

input =  [BitVec(('x%s' % i),8) for i in range(49) ]

mat_input = [0]*49
mat_const = [0]*49
byte_601060 = [
    0x73, 0x6F, 0x6D, 0x65, 0x20, 0x6C, 0x65, 0x67, 0x65, 0x6E, 0x64, 0x73, 0x20, 0x72, 0x20, 0x74,
    0x6F, 0x6C, 0x64, 0x2C, 0x20, 0x73, 0x6F, 0x6D, 0x65, 0x20, 0x74, 0x75, 0x72, 0x6E, 0x20, 0x74,
    0x6F, 0x20, 0x64, 0x75, 0x73, 0x74, 0x20, 0x6F, 0x72, 0x20, 0x74, 0x6F, 0x20, 0x67, 0x6F, 0x6C,
    0x64
]
index_0 = 23
for i in range(49):
    mat_input[index_0] = input[i] ^ index_0;
    mat_const[i] = byte_601060[index_0] ^ i;
    index_0 = (index_0 + 13) % 49;

index_0 = 41
index_1 = 3
index_2 = 4
index_3 = 5
unk_6010A0 = [
    0xAA, 0x7A, 0x24, 0x0A, 0xA8, 0xBC, 0x3C, 0xFC, 0x82, 0x4B, 0x51, 0x52, 0x5E, 0x1C, 0x82, 0x1F,
    0x79, 0xBA, 0xB5, 0xE3, 0x43, 0x04, 0xFD, 0xAC, 0x10, 0xB5, 0x63, 0xBD, 0x8D, 0xE7, 0x35, 0xD9,
    0xD3, 0xE8, 0x42, 0x6D, 0x71, 0x5A, 0x09, 0x54, 0xE9, 0x9F, 0x4C, 0xDC, 0xA2, 0xAF, 0x11, 0x87,
    0x94
]
for i in range(7):
    for j in range(7):
        sum = 0
        for k in range(7):
            sum = sum + mat_const[7 * index_3 + index_2] * mat_input[7 * index_1 + index_3]
            index_3 = (index_3 + 5) % 7
        s.add((sum ^ index_0) & 0xFF == unk_6010A0[index_0])
        index_0 = (index_0 + 31) % 49
        index_2 = (index_2 + 4) % 7
    index_1 = (index_1 + 3) % 7

if s.check() == sat:
    ret = s.model()
    for i in range(49):
        print chr(ret[input[i]].as_long()),
```

因为使用的是`Bitvec`，所以不用约束范围，解得`flag{Everyth1n_th4t_kill5_m3_m4kes_m3_fee1_ali v3}`。
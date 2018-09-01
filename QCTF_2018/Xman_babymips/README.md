# Xman-babymips

`main`函数是`sub_4009A8`，其中有一个循环对用户输入作变换，从循环大小来看用户输入的长度应该等于32。
对变换后的用户输入，先取前5个字节和`Q|j{g`比较，若相等则会再调用`sub_4007F0`，其参数是用户输入，函数中仍然是对用户输入的判断。
所以先看对用户输入变换的算法:

```cpp
    for(var30 = 0; var30 < 32; ++var30) {
        $$v0 = &var30 + var30;
        *(&var2C + var30) = (unsigned char)(((int)(*($$v0 + 4))) ^ ((int)(((unsigned char)(32 - ((unsigned int)(((unsigned char)var30))))))));
    }
```

虽然很乱，但大致能看出来是每次取用户输入的一个字节，然后异或上`32 - i`，`i`是其下标，可以得到用户输入的前5个字节是`qctf{`。
再看`sub_4007F0`，里面同样是一个大循环，循环结束后作明码比较，看一下其核心逻辑，有一个判断奇偶:

```cpp
            if((var10 & 1) != 0) {
                $$a0 = (int)(((unsigned char)(((int)(*$$v0)) / 4)));
                $$v0 = par00 + var10;
                par00[var10] = (unsigned char)($$a0 | ((((int)(*$$v0)) * 1073741824) >> 24));
            }
            else {
                $$a0 = (((int)(*$$v0)) * 67108864) >> 24;
                $$v0 = par00 + var10;
                par00[var10] = (unsigned char)($$a0 | ((int)(((unsigned char)(((int)(*$$v0)) / 64)))));
            }
```

感觉伪码不对，看汇编才知道第一个分支内是把当前字符算术右移2位，逻辑作移6位后相或，而第二个分支是把当前字符逻辑左移2位，算术右移6位后相或。
第一个分支是把当前字符的高6位后移，低2位前移，第2个分支是把低6位左移，高2位后移，是可逆的，算术/逻辑应该不影响:

```python
arr = [0x52, 0xFD, 0x16, 0xA4, 0x89, 0xBD, 0x92, 0x80, 0x13, 0x41, 0x54, 0xA0, 0x8D,
       0x45, 0x18, 0x81, 0xDE, 0xFC, 0x95, 0xF0, 0x16, 0x79, 0x1A, 0x15, 0x5B, 0x75, 0x1F]
for i in range(len(arr)):
    if (i + 5) & 1 != 0:
        tmp = ((arr[i] << 2) | (arr[i] >> 6)) & 0xFF
        #print hex(tmp),
        print chr(tmp ^ (32 - 5 - i)),
    else:
        tmp = ((arr[i] >> 2) | (arr[i] << 6)) & 0xFF
        #print hex(tmp),
        print chr(tmp ^ (32 - 5 - i)),
```

解得`flag`是`qctf{ReA11y_4_B@89_mlp5_4_XmAn_}`。
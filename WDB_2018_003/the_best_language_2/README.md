# the_best_language

打开附件发现是一个`xml`文档，是由`pyc`格式解析而来的，从魔数可知是`python`版本是`python 2.7`。
解题方式有两种，一种是把`xml`文档还原成`pyc`格式，再对`pyc`反编译，另一种是直接解析`opcode`序列。

### 解析opcode序列

以第一个`opcode`序列为例，脚本:

```pyhton
import binascii
import dis

code = '6400006401006c00005a00006400006402006c01006d02005a0200016400006401006c03005a03006400006401006c04005a04006403005a05006404008400005a06006405008400005a07006506006505006406002083010065070065050064060064070021830100176506006505006407001f830100175a08006500006a090065080083010047486408005a080064010053'
hexcode = binascii.a2b_hex(code)
print dis.dis(hexcode)
```

首先要使用`a2b_hex`把字符串转成`16`进制字符串的格式，才能使用`dis`反汇编，得到:

```python
          0 LOAD_CONST          0 (0)          #push -1
          3 LOAD_CONST          1 (1)          #pusn None
          6 IMPORT_NAME         0 (0)          #pop None, pop -1, push 'base64'
          9 STORE_NAME          0 (0)          #'base64' = 'base64'
         12 LOAD_CONST          0 (0)          #push -1
         15 LOAD_CONST          2 (2)          #push ('md5',)
         18 IMPORT_NAME         1 (1)          #pop ('md5',), pop -1, push 'hashlib'
         21 IMPORT_FROM         2 (2)          #pop md5, from hashlib import md5
         24 STORE_NAME          2 (2)          #md5 = md5
         27 POP_TOP                            #pop
         28 LOAD_CONST          0 (0)          #push -1
         31 LOAD_CONST          1 (1)          #push None
         34 IMPORT_NAME         3 (3)          #pop None, pop -1, import random
         37 STORE_NAME          3 (3)          #random = random
         40 LOAD_CONST          0 (0)          #push -1
         43 LOAD_CONST          1 (1)          #push None
         46 IMPORT_NAME         4 (4)          #pop None, pop -1, import string
         49 STORE_NAME          4 (4)          #string = string

         52 LOAD_CONST          3 (3)          #push 'flag{******}'
         55 STORE_NAME          5 (5)          #pop 'f'
         58 LOAD_CONST          4 (4)          #push code_1
         61 MAKE_FUNCTION       0              #
         64 STORE_NAME          6 (6)          #pop '_'
         67 LOAD_CONST          5 (5)          #push code_2
         70 MAKE_FUNCTION       0              #     
         73 STORE_NAME          7 (7)          #pop '____'

         76 LOAD_NAME           6 (6)          #push '_'
         79 LOAD_NAME           5 (5)          #push 'f'
         82 LOAD_CONST          6 (6)          #push 12
         85 SLICE+2                            #TOS = TOS1[:TOS]
         86 CALL_FUNCTION       1              #call '_'
         89 LOAD_NAME           7 (7)          #push '____'
         92 LOAD_NAME           5 (5)          #push 'f'
         95 LOAD_CONST          6 (6)          #push 12
         98 LOAD_CONST          7 (7)          #push 19
        101 SLICE+3                            #TOS = TOS2[TOS1:TOS]
        102 CALL_FUNCTION       1              #call '____'
        105 BINARY_ADD                         #TOS = TOS + TOS1
        106 LOAD_NAME           6 (6)          #push _
        109 LOAD_NAME           5 (5)          #push f
        112 LOAD_CONST          7 (7)          #push 19
        115 SLICE+1                            #TOS = TOS1[TOS:]
        116 CALL_FUNCTION       1              #call _
        119 BINARY_ADD                         #TOS = TOS + TOS1
        120 STORE_NAME          8 (8)          #pop e
        123 LOAD_NAME           0 (0)          #push 'base64'
        126 LOAD_ATTR           9 (9)          #TOS = 'b64decode'
        129 LOAD_NAME           8 (8)          #push e
        132 CALL_FUNCTION       1              #call base64.b64encode
        135 PRINT_ITEM                         #print TOS
        136 PRINT_NEWLINE                      #print '\n'
        137 LOAD_CONST          8 (8)          #push 'U1VQU05pSHdqCEJrQu7FS7Vngk1OTQ58qqghXmt2AUdrcFBBUEU='
        140 STORE_NAME          8 (8)          #pop e
        143 LOAD_CONST          1 (1)          #push None
        146 RETURN_VALUE
```

`python`虚拟机是基于栈的，官方文档[Python Bytecode Instructions](https://docs.python.org/2.7/library/dis.html?highlight=opcode)。
其中的`TOS`指`top of the stack`，`TOS1`指`second top-most stack item`。
该函数前面一部分都是导入模块，依次是`import base64`，`from hashlib import md5`，`import random`，`import string`。
接下来新建了两个函数，`_`是异或函数，`_____`是哈希函数，我们首先把`input[:12]`作异或，`input[12:19]`作哈希，`input[19:]`作异或，最后和`U1VQU05pSHdqCEJrQu7FS7Vngk1OTQ58qqghXmt2AUdrcFBBUEU=`作比对。
解码后的长度为`38`，则有`12 + 16 + 10 = 38`，那么用户输入的长度肯定`29`。

再分析嵌套的两个对象:

```python
          0 LOAD_CONST          1 (1)          #push ''
          3 LOAD_ATTR           0 (0)          #TOS = 'join'
          6 LOAD_GLOBAL         1 (1)          #push 'random'
          9 LOAD_ATTR           2 (2)          #TOS = 'sample'
         12 LOAD_GLOBAL         3 (3)          #push 'string'
         15 LOAD_ATTR           4 (4)          #TOS = 'digits'
         18 LOAD_CONST          2 (2)          #push 4
         21 CALL_FUNCTION       2              #call random.sample?
         24 CALL_FUNCTION       1              #call string.digits?
         27 STORE_FAST          1 (1)          #pop '__'
         30 LOAD_CONST          1 (1)          #push ''
         33 STORE_FAST          2 (2)          #pop '___'
         36 SETUP_LOOP         70 (to 109)     #
         39 LOAD_GLOBAL         5 (5)          #push 'range'
         42 LOAD_GLOBAL         6 (6)          #push 'len'
         45 LOAD_FAST           0 (0)          #push 'b'
         48 CALL_FUNCTION       1              #call len
         51 CALL_FUNCTION       1              #call range
         54 GET_ITER                           #TOS = iter(TOS)
    >>   55 FOR_ITER           50 (to 108)     #call iter.next
         58 STORE_FAST          3 (3)          #pop 'i'
         61 LOAD_FAST           2 (2)          #push '___'
         64 LOAD_GLOBAL         7 (7)          #push 'chr'
         67 LOAD_GLOBAL         8 (8)          #push 'ord'
         70 LOAD_FAST           0 (0)          #push 'b'
         73 LOAD_FAST           3 (3)          #push 'i'
         76 BINARY_SUBSCR                      #TOS = TOS1[TOS]
         77 CALL_FUNCTION       1              #call ord
         80 LOAD_GLOBAL         8 (8)          #push 'ord'
         83 LOAD_FAST           1 (1)          #push '__'
         86 LOAD_FAST           3 (3)          #push 'i'
         89 LOAD_CONST          2 (2)          #push 4
         92 BINARY_MODULO                      #TOS = TOS1 % TOS
         93 BINARY_SUBSCR                      #TOS = TOS1[TOS]
         94 CALL_FUNCTION       1              #call ord
         97 BINARY_XOR                         #TOS = TOS ^ TOS1
         98 CALL_FUNCTION       1              #call chr
        101 INPLACE_ADD                        #TOS = TOS + TOS1
        102 STORE_FAST          2 (2)          #pop '___'
        105 JUMP_ABSOLUTE      55
    >>  108 POP_BLOCK      
    >>  109 LOAD_FAST           2 (2)
        112 RETURN_VALUE
```

若字节码中出现`LOAD_xxx`之后是`LOAD_ATTR`，多半是调用成员函数，以上就是`''.join`，`random.sample`，`string.digits`三个函数，首先把三个函数入栈，再调用，是典型的嵌套调用，相当于`''.join(random.sample(string.digits, 4))`，即生成一个长度为`4`的字符串。
后面就是使用一个循环对传入的字符串逐字符异或上`str[i % 4]`，新生成的字符添加到另一个字符串上。


```python
          0 LOAD_GLOBAL         0 (0)         #push 'md5'
          3 CALL_FUNCTION       0             #call 'md5'
          6 STORE_FAST          1 (1)         #pop '___'
          9 LOAD_FAST           1 (1)         #push '___'
         12 LOAD_ATTR           1 (1)         #TOS = 'update'
         15 LOAD_FAST           0 (0)         #push 'a'
         18 CALL_FUNCTION       1             #call 'update'
         21 POP_TOP                           #pop
         22 LOAD_FAST           1 (1)         #push '___'
         25 LOAD_ATTR           2 (2)         #TOS = 'digest'
         28 CALL_FUNCTION       0             #call 'digest'
         31 RETURN_VALUE
```

以上的`opcode`序列比较短，可以依次分析，首先调用`md5`得到一个`md5`对象，并放到局部变量中`___`，接着调用`md5.update`，将其返回值弹出后再调用`md5.digest`获取最后的结果。

中间`16`个字节的`md5`解密得到`613u21i`。
对于异或，从`10`个数字里任意取出`4`个数，且有顺序，那么共`10 * 9 * 8 * 7 = 3360`种方式，很明显是可以穷举的，脚本:

```python
import base64
import binascii
import string

str = base64.b64decode('U1VQU05pSHdqCEJrQu7FS7Vngk1OTQ58qqghXmt2AUdrcFBBUEU=')

md5 = str[12:28]
binascii.b2a_hex(md5)

digits = string.digits
xor_1 = str[:12]
for i in digits:
    for j in digits:
        for k in digits:
            for l in digits:
                s = i + j + k + l
                ret = ''
                for m in range(12):
                    ret += chr(ord(xor_1[m]) ^ ord(s[m % 4]))
                print ret
#......
xor_2 = str[28:]

```

可以从多个结果中猜出`flag{PyC_1s_613u21i_N0t_Hard}`。


### 还原pyc格式

从网上可以查到`pyc`到`xml`的脚本，其中使用了`marshal`模块用来序列化/反序列化，序列化是指从对象得到字节流，反序列化是从字节流得到对象，所以从`pyc`到`xml`就是反序列化，我们需要做的就是从`xml`文档中提取出有用的信息，并将它们组合成对象，

首先使用`010Editor`解析`pyc`格式，模板库里的模板会提示魔数不对，要修改一下，`MagicValue`枚举结构里很明显没有`03 F3`对应的值，把最后一个值改成`62211`就能正常解析了。
还有一个问题就是`xml`文档格式不对，`xml`文档只能有一个根节点，对于此题来说，我们需要把所有内容放入一个根节点中，而且对于`<name> '<module>'</name>`的形式，会提示标签没闭合，需要我们转义，改成`<name> '&lt;module&gt;'</name>`。
但仍有一个比较麻烦的事情是`<consts>`标签里嵌套`<code>`时，会把字符串截断，若使用`node.childNode.data`去读数据，只能读到前一部分，所以我只有把后一部分手动提到`<code>`标签之前。

该脚本缺陷很大，首先由于它是递归解析的，所以每个`code`对象生成的字节流需要手动插入到对应的`consts`常量处，其次`<name>`标签的是`TYPE_INTERNED`，需要手动修改为`\x74`。
而且生成的`pyc`没办法使用在线的网站反编译，只能用`uncompyle2`等工具反编译，脚本:

```python
#!/usr/bin/env python
# _*_ coding: utf-8 _*_

import sys
import xml.dom.minidom
import binascii

def parse_pycodeobject(node):
    for node in node.childNodes:
        if node.nodeName == 'argcount':
            co_argcount = int(node.firstChild.data.strip())
            print co_argcount
        elif node.nodeName == 'nlocals':
            co_nlocals = int(node.firstChild.data.strip())
            print co_nlocals
        elif node.nodeName == 'stacksize':
            co_stacksize = int(node.firstChild.data.strip())
            print co_stacksize
        elif node.nodeName == 'flags':
            co_flags = int(node.firstChild.data.strip(), 16)
            print co_flags
        elif node.nodeName == 'code':
            co_code = binascii.a2b_hex(node.firstChild.data.replace(' ', '').replace('\n', ''))
            puts(co_code)
        elif node.nodeName == 'names':
            co_names = eval(node.firstChild.data.strip())
            print co_names
        elif node.nodeName == 'varnames':
            co_varnames = eval(node.firstChild.data.strip())
            print co_varnames
        elif node.nodeName == 'freevars':
            co_freevars = eval(node.firstChild.data.strip())
            print co_freevars
        elif node.nodeName == 'cellvars':
            co_cellvars = eval(node.firstChild.data.strip())
            print co_cellvars
        elif node.nodeName == 'filename':
            co_filename = unicode.encode(node.firstChild.data.strip().replace('\'', ''))
            print co_filename
        elif node.nodeName == 'name':
            co_name = unicode.encode(node.firstChild.data.strip().replace('\'', ''))
            print co_name
        elif node.nodeName == 'firstlineno':
            co_firstlineno = int(node.firstChild.data.strip())
            print co_firstlineno
        elif node.nodeName == 'lnotab':
            co_lnotab = binascii.a2b_hex(node.firstChild.data.replace(' ', '').replace('\n', ''))
            puts(co_lnotab)
            print '\n'
        elif node.nodeName == 'consts':
            items = node.firstChild.data.replace(' ', '').split('\n')
            items = items[1:len(items) - 1]
            if len(items) == 1:
                cstr = '(' + ', '.join(items) + ',)'
            else:
                cstr = '(' + ', '.join(items) + ')'
            co_consts = eval(cstr)
            print co_consts
            const_node = node
    for node in const_node.childNodes:
        if node.nodeName == 'code':
            parse_pycodeobject(node)
    #strcat
    code_object = CodeType(co_argcount, co_nlocals, co_stacksize, co_flags, co_code, co_consts, co_names, co_varnames, co_filename, co_name, co_firstlineno, co_lnotab, co_freevars, co_cellvars)
    with open('e:/output', 'ab') as f:
        marshal.dump(code_object, f)
        f.write('\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF')

def puts(cstr):
    for i in range(len(cstr)):
        print hex(ord(cstr[i]))[2:].rjust(2, '0'),
    print '\r'

import marshal
from types import CodeType
#print sys.argv[1]
dom = xml.dom.minidom.parse('E:\\re.xml')
root = dom.documentElement

for node in root.childNodes:
    if node.nodeName == 'magic':
        cstr = binascii.a2b_hex(node.firstChild.data.strip())
        cstr_magic = '\x03\xf3\x0d\x0a'
        #for c in cstr:
            #cstr_magic += '\\x' + hex(ord(c))[2:]
        with open('e:/output', 'wb') as f:
            f.write(cstr_magic)

    elif node.nodeName == 'moddate':
        cstr = binascii.a2b_hex(node.firstChild.data.strip())
        cstr_moddate = '\x6d\x4a\x69\x5b'
        # for c in cstr:
        # cstr_magic += '\\x' + hex(ord(c))[2:]
        with open('e:/output', 'ab') as f:
            f.write(cstr_moddate)
    elif node.nodeName == 'code':
        #parse pycodeobject
        parse_pycodeobject(node)
```

使用该脚本对此题修改后的`re.xml`处理，得到`output`文件，再对`output`中的`code`对象重组，使用`uncompyle2`反编译，得到:

```python
# 2018.09.04 03:54:46 PDT
#Embedded file name: re2.py
import base64
from hashlib import md5
import random
import string
f = 'flag{*******}'

def _(b):
    __ = ''.join(random.sample(string.digits, 4))
    ___ = ''
    for i in range(len(b)):
        ___ += chr(ord(b[i]) ^ ord(__[i % 4]))

    return ___


def ____(a):
    ___ = md5()
    ___.update(a)
    return ___.digest()


e = _(f[:12]) + ____(f[12:19]) + _(f[19:])
print base64.b64encode(e)
e = 'U1VQU05pSHdqCEJrQu7FS7Vngk1OTQ58qqghXmt2AUdrcFBBUEU='
+++ okay decompyling /home/cuser/Desktop/output 
# decompiled 1 files: 1 okay, 0 failed, 0 verify failed
# 2018.09.04 03:54:46 PDT
```

看起来效果还不错。


### 延申

相关的有`SUCTF 2018`的`the_best_python`。


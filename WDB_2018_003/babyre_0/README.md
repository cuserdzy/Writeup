#　babyre
***
很久没见到`C#`方面的题目了。
载入`dnSpy`，`WindowsApp1`下的`Form1`就是用户窗体，找到`Button1_Click`事件处理函数:

```csharp
public void Button1_Click(object sender, EventArgs e)
{
    Random random = new Random();
    int num = 1000;
    checked
    {
        this.i++;
        bool flag = this.i < num;
        if (flag)
        {
            Interaction.MsgBox(Conversion.Str(this.i) + "/" + Conversion.Str(num), MsgBoxStyle.Information, "flag的价值");
            this.Button1.Top = random.Next(171) + 48;
            this.Button1.Left = random.Next(380) + 12;
        }
        else
        {
            this.i = 0;
            bool flag2 = this.j < this.contents.Length;
            if (flag2)
            {
                Interaction.MsgBox(string.Concat(new string[]
                {
                    "第 ",
                    Conversion.Str(this.j + 1),
                    "/",
                    Conversion.Str(this.contents.Length),
                    " ，拿去吧"
                }), MsgBoxStyle.OkOnly, null);
                TextBox textBox;
                (textBox = this.TextBox1).Text = textBox.Text + Conversions.ToString(this.contents[this.j]);
                this.j++;
            }
            else
            {
                Interaction.MsgBox("已经。。。没有了", MsgBoxStyle.OkOnly, null);
            }
            bool flag3 = this.j > 5;
            if (flag3)
            {
                this.TextBox1.PasswordChar = '*';
            }
        }
    }
}
```

很容易就能看到程序是把`contents`处的字符依次输出，该字符串在`Form1_Load`中被赋值，得到`-11e8-b6dd-000c29dcabfd}`。
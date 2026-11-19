# cjexpr API 与错误代码

## 表达式语法

数字可以写成 `12`、`.5`、`2.`、`1.25e-3`。指数标记 `e` 或 `E` 后允许一个正负号并且至少需要一位数字。变量名区分大小写，使用 ASCII 字母、数字和下划线，首字符为字母或下划线。空格、制表符、CR、LF 和 CRLF 可用于分隔记号。

| 优先级（高到低） | 写法 | 例子 |
| --- | --- | --- |
| 分组 | `(表达式)` | `(2 + 3) * 4` 得到 20 |
| 幂 | `^`，右结合，指数可以带负号 | `2^3^2` 得到 512，`2^-3` 得到 0.125 |
| 一元负号 | `-操作数` | `--3` 得到 3 |
| 乘、除 | `*`、`/`，左结合 | `24 / 4 / 2` 得到 3 |
| 加、减 | `+`、`-`，左结合 | `20 - 5 - 3` 得到 12 |

变量赋值通过 `bind` 完成，乘法显式写作 `2 * x`。数值使用二进制 `Float64`，十进制小数按浮点精度舍入，极小的数值可以下溢为零。输入和结果均须为有限值。括号最多嵌套 64 层。

`-2^2` 表示 `-(2^2)`，负底数可写作 `(-2)^2`。`2^-3^2` 表示 `2^(-(3^2))`。非负底数可使用小数指数，例如 `9^0.5` 得到 3。负底数要求指数的 `Float64` 值为整数。零的零次幂约定为 1，零的负次幂报告除零，幂结果溢出报告 `NON_FINITE`。

## 同步调用

| 签名 | 参数与行为 | 返回或异常 |
| --- | --- | --- |
| `evaluate(expr: String): Float64` | `expr` 是待求值的完整表达式，变量表为空。 | 返回数值。表达式有误时抛出 `ExprException`。 |
| `Evaluator()` | 新实例从空变量表开始。 | 返回可在线程间共享的求值器。 |
| `Evaluator.bind(name: String, value: Float64): Unit` | 按名称插入或覆盖绑定。先校验名称和值，再写入变量表。 | 成功返回 `Unit`。非法名称或非有限值抛出异常，原值保留。 |
| `Evaluator.evaluate(expr: String): Float64` | 先在锁内复制变量表，再解析和求值。 | 返回数值，错误时抛出 `ExprException`。 |

## 重复使用同一个公式

`CompiledExpression(expr: String)` 在构造时解析源文本并保存节点及其位置。非法字符、非法字面量或括号不匹配会立即抛出 `ExprException`。构造成功后可以多次使用同一个对象，也可以将它传给多个线程。

| 调用 | 变量与错误 |
| --- | --- |
| `formula.evaluate(ev: Evaluator): Float64` | 读取本次调用的变量快照。未知变量、除零及运算溢出在本次执行时抛出。 |
| `formula.evaluateAsync(ev: Evaluator): Future<Float64>` | 提交时截取变量快照，将执行结果或异常交给 `get()`。 |

例如，`CompiledExpression("10 / x")` 可以在绑定 `x` 之前构造。将 `x` 绑定为 0 时，求值会报告第 4 列的除零错误。把 `x` 更新为 2，再次执行同一公式即可得到 5。

## 异步调用

`Evaluator.evaluateAsync(expr: String): Future<Float64>` 在提交时截取变量快照。之后调用 `bind` 只会影响后续提交。通过 `Future.get()` 取得数值，后台任务中的 `ExprException` 也由 `get()` 抛出。

```cangjie
let ev = Evaluator()
ev.bind("x", 4.0)
let before = ev.evaluateAsync("x * x")
ev.bind("x", 9.0)
println(before.get())        // 16.000000
println(ev.evaluate("x*x"))  // 81.000000
```

## 错误位置

`ExprException` 继承 `Exception`。`code: String` 供程序分支判断，`message` 说明原因，`line: Int64` 与 `column: Int64` 指向源文本。行列从 1 开始，每个 Unicode 码点占一列，制表符占一列，CRLF 算作一个换行。输入末尾缺少操作数或指数数字时，列号指向最后一个字符之后。

| `code` | 触发条件 | 位置 |
| --- | --- | --- |
| `INVALID_CHARACTER` | 出现无法识别的字符 | 该字符 |
| `INVALID_NUMBER` | 小数点多余、指数缺少数字等 | 出错的小数点或预期数字的位置 |
| `EXPECTED_OPERAND` | 空输入或应出现操作数时遇到运算符、右括号或末尾 | 当前记号或输入末尾 |
| `MISSING_OPERATOR` | 数字、变量或括号表达式直接相邻 | 后一个记号的首字符 |
| `MISSING_CLOSE` | 完成括号内表达式后到达末尾 | 缺少配对的左括号 |
| `UNEXPECTED_CLOSE` | 完整表达式后还有多余右括号 | 多余的右括号 |
| `NESTING_LIMIT` | 括号嵌套超过 64 层 | 第 65 个左括号 |
| `UNKNOWN_VARIABLE` | 表达式引用了未绑定的名字 | 名字首字符 |
| `DIVISION_BY_ZERO` | 除数为正零或负零，或零的指数为负 | 对应的 `/` 或 `^` |
| `POWER_DOMAIN` | 负底数与非整数指数的组合超出本库支持的实数幂范围 | 对应的 `^` |
| `NON_FINITE` | 字面量、绑定值或运算结果为无穷或 NaN | 字面量开头、绑定名开头或运算符 |
| `INVALID_NAME` | `bind` 的名称为空或包含非法字符 | 名称中的第一个非法位置，空名取第 1 列 |

```cangjie
try {
    println(evaluate("8 / (3 - 3)"))
} catch (e: ExprException) {
    println("${e.code}  ${e.message}")  // DIVISION_BY_ZERO  第 1 行，第 3 列：除数为零
}
```

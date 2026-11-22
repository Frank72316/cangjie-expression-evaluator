# 仓颉表达式求值器

`cjexpr` 是用仓颉编写的算术表达式静态库。输入 `2 + 3 * 4` 得到 `14`。如果表达式包含变量，可以复用同一个求值器修改绑定，也可以提交异步任务并在稍后读取结果。库仅依赖仓颉标准库。

代码评审和版本发布在 AtomGit 进行，GitHub 提供同版本镜像。[AtomGit 主仓库](https://atomgit.com/A72316/cangjie-expression-evaluator) · [GitHub 镜像](https://github.com/Frank72316/cangjie-expression-evaluator)

## 在其他工程中调用

使用仓颉 SDK 1.0.5，在调用方的 `cjpm.toml` 中加入以下依赖。[SDK 下载](https://cangjie-lang.cn/download/1.0.5)

```toml
[dependencies]
cjexpr = { git = "https://atomgit.com/A72316/cangjie-expression-evaluator.git", tag = "v0.4.0" }
```

```cangjie
import cjexpr.*

main() {
    let cart = Evaluator()
    cart.bindAll([("price", 12.5), ("count", 4.0)])
    let total = CompiledExpression("price * count")
    let pending = total.evaluateAsync(cart)
    cart.bindAll([("price", 15.0), ("count", 6.0)])
    println(pending.get())          // 50.000000，提交任务时的单价和数量
    println(total.evaluate(cart))   // 90.000000，更新后的单价和数量
}
```

## API

| 调用 | 用途 |
| --- | --- |
| `evaluate(expr: String): Float64` | 使用空变量表计算表达式。 |
| `Evaluator()` | 创建具有独立变量表的求值器。 |
| `bind(name: String, value: Float64): Unit` | 新建或更新一个变量。 |
| `bindAll(entries: Array<(String, Float64)>): Unit` | 一次更新多个变量，全部校验成功后一起生效。 |
| `Evaluator.evaluate(expr: String): Float64` | 使用调用时的变量快照求值。 |
| `evaluateAsync(expr: String): Future<Float64>` | 提交后台计算，使用 `get()` 取得结果或错误。 |
| `CompiledExpression(expr: String)` | 解析并保存公式，可供多个求值器共享。 |
| `formula.evaluate(ev)` / `formula.evaluateAsync(ev)` | 用 `ev` 当前的变量快照同步或异步执行已解析的公式。 |
| `ExprException` | 读取错误代码、中文原因及从 1 起算的行列号。 |

支持十进制小数、科学计数法、四则运算、幂、括号和一元负号。幂从右向左结合，`2^3^2` 得到 512。底数前的负号在幂之后计算，`-2^2` 得到 −4，`(-2)^2` 得到 4。复利公式可写作 `principal * (1 + rate)^years`。[语法与错误代码](doc/api.md)

## 构建和测试

安装 SDK，按安装目录中的 `envsetup` 脚本配置终端，再克隆仓库。Git 建议使用 2.30 或更高版本。

```sh
git clone https://atomgit.com/A72316/cangjie-expression-evaluator.git
cd cangjie-expression-evaluator
```

| 环境 | 构建、测试并运行示例 |
| --- | --- |
| Windows PowerShell | `.\scripts\check.bat` |
| Linux / macOS | `bash scripts/check.sh` |

单独运行单元测试可执行 `cjpm test`。在 `example` 目录执行 `cjpm run`，可看到同一张订单成批更新单价和数量前后的总价 `50` 和 `90`。[可运行示例](example/src/main.cj)

## 实现与版本

词法器记录行列，递归下降解析器把表达式写成按后序排列的节点表，求值器顺序计算每个节点。平坦的长表达式使用循环，括号嵌套上限为 64 层。[设计文档](doc/design.md)

当前版本为 `v0.4.0`，采用 Apache License 2.0。[变更记录](CHANGELOG.md) · [许可证全文](LICENSE)

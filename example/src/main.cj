package expression_example

import cjexpr.*

main() {
    println("2 + 3 * 4 = ${evaluate("2 + 3 * 4")}")
    println("2^3^2 = ${evaluate("2^3^2")}")

    let calculator = Evaluator()
    calculator.bindAll([("price", 12.5), ("count", 4.0)])
    let total = CompiledExpression("price * count")
    let pending = total.evaluateAsync(calculator)
    calculator.bindAll([("price", 15.0), ("count", 6.0)])
    println("提交任务时的总价 = ${pending.get()}")
    println("更新单价和数量后的总价 = ${total.evaluate(calculator)}")

    try {
        println(calculator.evaluate("price / (count - 6)"))
    } catch (e: ExprException) {
        println("${e.code}  ${e.message}")
    }
}

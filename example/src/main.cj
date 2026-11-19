package expression_example

import cjexpr.*

main() {
    println("2 + 3 * 4 = ${evaluate("2 + 3 * 4")}")

    let calculator = Evaluator()
    calculator.bind("price", 12.5)
    calculator.bind("count", 4.0)
    let total = CompiledExpression("price * count")
    let pending = total.evaluateAsync(calculator)
    calculator.bind("price", 15.0)
    println("提交任务时的总价 = ${pending.get()}")
    println("调价后的总价 = ${total.evaluate(calculator)}")

    try {
        println(calculator.evaluate("price / (count - 4)"))
    } catch (e: ExprException) {
        println("${e.code}  ${e.message}")
    }
}

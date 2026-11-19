package cjexpr

import std.collection.ArrayList
import std.unittest.*
import std.unittest.testmacro.*

@Test
class CompiledExpressionTests {
    @TestCase
    func reuseAfterRebinding() {
        let total = CompiledExpression("price * count")
        let ev = Evaluator()
        ev.bind("count", 4.0)
        ev.bind("price", 12.5)
        @Expect(total.evaluate(ev), 50.0)
        ev.bind("price", 15.0)
        @Expect(total.evaluate(ev), 60.0)
    }

    @TestCase
    func independentEvaluators() {
        let formula = CompiledExpression("x + x")
        let left = Evaluator()
        let right = Evaluator()
        left.bind("x", 3.0)
        right.bind("x", 5.0)
        let one = formula.evaluateAsync(left)
        let two = formula.evaluateAsync(right)
        @Expect(one.get(), 6.0)
        @Expect(two.get(), 10.0)
    }

    @TestCase
    func syntaxFailsAtConstruction() {
        let error = captureError({ => CompiledExpression("1/0 +\n)") })
        @Expect(error.code, "EXPECTED_OPERAND")
        @Expect(error.line, 2)
        @Expect(error.column, 1)
    }

    @TestCase
    func literalFailsAtConstruction() {
        let error = captureError({ => CompiledExpression("1 + 1e999") })
        @Expect(error.code, "NON_FINITE")
        @Expect(error.column, 5)
    }

    @TestCase
    func unboundVariableCanBeSuppliedLater() {
        let formula = CompiledExpression("2 +\r\n  rate")
        let ev = Evaluator()
        let error = captureError({ => formula.evaluate(ev) })
        @Expect(error.code, "UNKNOWN_VARIABLE")
        @Expect(error.line, 2)
        @Expect(error.column, 3)
        ev.bind("rate", 3.0)
        @Expect(formula.evaluate(ev), 5.0)
    }

    @TestCase
    func asyncArithmeticErrorAndRecovery() {
        let formula = CompiledExpression("9\n / divisor")
        let ev = Evaluator()
        ev.bind("divisor", 0.0)
        let invalid = formula.evaluateAsync(ev)
        ev.bind("divisor", 3.0)
        let valid = formula.evaluateAsync(ev)
        let error = captureError({ => invalid.get() })
        @Expect(error.code, "DIVISION_BY_ZERO")
        @Expect(error.line, 2)
        @Expect(error.column, 2)
        @Expect(valid.get(), 3.0)
    }

    @TestCase
    func concurrentSubmissionsKeepSeparateValues() {
        let formula = CompiledExpression("x * x - x")
        let ev = Evaluator()
        let tasks = ArrayList<Future<Float64>>()
        for (i in 0..32) {
            ev.bind("x", Float64(i))
            tasks.add(formula.evaluateAsync(ev))
        }
        for (i in 0..tasks.size) {
            @Expect(tasks[i].get(), Float64(i * i - i))
        }
    }

    @TestCase
    func agreesWithStringEntryPoints() {
        let ev = Evaluator()
        for (expr in ["8 / 4 / 2", "-(3 + 4) * --2", "2.5e-2 + .75"]) {
            let formula = CompiledExpression(expr)
            @Expect(formula.evaluate(ev), evaluate(expr))
            @Expect(formula.evaluateAsync(ev).get(), ev.evaluate(expr))
        }
    }

    @TestCase
    func stringAsyncReportsSyntaxThroughFuture() {
        let pending = Evaluator().evaluateAsync("1 +")
        let error = captureError({ => pending.get() })
        @Expect(error.code, "EXPECTED_OPERAND")
        @Expect(error.column, 4)
    }
}

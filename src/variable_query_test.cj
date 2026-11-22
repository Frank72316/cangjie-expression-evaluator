package cjexpr

import std.sync.Barrier
import std.unittest.*
import std.unittest.testmacro.*

@Test
class VariableQueryTests {
    @TestCase
    func preservesFirstOccurrenceAcrossSubexpressions() {
        let formula = CompiledExpression("z^b^-a + (b + c) * z - d")
        @Expect(formula.variableNames(), ["z", "b", "a", "c", "d"])
    }

    @TestCase
    func distinguishesNamesFromNumericExponents() {
        let formula = CompiledExpression("_x2 + 1e-3 * E + 3E+2 * e + _x2")
        @Expect(formula.variableNames(), ["_x2", "E", "e"])
    }

    @TestCase
    func constantFormulaHasNoInputs() {
        let formula = CompiledExpression("-(1.25e-2)^2")
        let ev = Evaluator()
        ev.bind("e", 3.0)
        @Expect(formula.variableNames().size, 0)
        @Expect(formula.missingVariables(ev).size, 0)
    }

    @TestCase
    func returnedArraysAreIndependent() {
        let formula = CompiledExpression("a+b")
        let ev = Evaluator()
        let names = formula.variableNames()
        let missing = formula.missingVariables(ev)
        names[0] = "changed"
        missing[1] = "other"
        @Expect(formula.variableNames(), ["a", "b"])
        @Expect(formula.missingVariables(ev), ["a", "b"])
    }

    @TestCase
    func filtersOnlyBoundNamesIncludingZero() {
        let formula = CompiledExpression("a+A+b+a+C+b")
        let ev = Evaluator()
        ev.bindAll([("A", 0.0), ("unused", 99.0), ("C", -0.0)])
        @Expect(formula.missingVariables(ev), ["a", "b"])
    }

    @TestCase
    func eachQueryUsesItsOwnEvaluatorAndTime() {
        let formula = CompiledExpression("price*qty-discount")
        let ev = Evaluator()
        let other = Evaluator()
        ev.bind("price", 12.5)
        other.bind("discount", 0.0)
        let before = formula.missingVariables(ev)
        ev.bindAll([("qty", 4.0), ("discount", 5.0)])
        @Expect(before, ["qty", "discount"])
        @Expect(formula.missingVariables(ev).size, 0)
        @Expect(formula.missingVariables(other), ["price", "qty"])
        @Expect(formula.evaluate(ev), 45.0)
    }

    @TestCase
    func queryDoesNotRunArithmetic() {
        let formula = CompiledExpression("10/(1-1) + x")
        let ev = Evaluator()
        @Expect(formula.missingVariables(ev), ["x"])
        ev.bind("x", 1.0)
        @Expect(formula.missingVariables(ev).size, 0)
        @Expect(captureError({ => formula.evaluate(ev) }).code, "DIVISION_BY_ZERO")
    }

    @TestCase
    func simultaneousBatchAppearsAsOneChange() {
        let formula = CompiledExpression("x+y+z")
        for (_ in 0..64) {
            let ev = Evaluator()
            let start = Barrier(2)
            let writer = spawn {
                start.wait()
                ev.bindAll([("x", 1.0), ("y", 2.0), ("z", 3.0)])
            }
            start.wait()
            let missing = formula.missingVariables(ev)
            writer.get()
            @Expect(missing.size == 0 || missing.size == 3)
            @Expect(formula.missingVariables(ev).size, 0)
        }
    }
}

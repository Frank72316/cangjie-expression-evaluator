package cjexpr

import std.sync.Barrier
import std.unittest.*
import std.unittest.testmacro.*

@Test
class BatchBindingTests {
    @TestCase
    func mergeNewAndExistingNames() {
        let ev = Evaluator()
        ev.bindAll([("x", 1.0), ("y", 10.0)])
        ev.bindAll([("x", 2.0), ("X", 100.0)])
        @Expect(ev.evaluate("x+y+X"), 112.0)
    }

    @TestCase
    func duplicateUsesLastValue() {
        let ev = Evaluator()
        ev.bindAll([("x", 1.0), ("x", 2.0), ("x", 3.0)])
        @Expect(ev.evaluate("x"), 3.0)
    }

    @TestCase
    func emptyBatchPreservesState() {
        let ev = Evaluator()
        ev.bind("x", 7.0)
        ev.bindAll([])
        @Expect(ev.evaluate("x"), 7.0)
    }

    @TestCase
    func invalidNameDiscardsInsertAndUpdate() {
        let ev = Evaluator()
        ev.bind("x", 1.0)
        let e = captureError({ => ev.bindAll([("x", 2.0), ("y", 3.0), ("bad-name", 4.0)]) })
        @Expect(e.code, "INVALID_NAME")
        @Expect(e.line, 1)
        @Expect(e.column, 4)
        @Expect(e.message.contains("第 3 项"))
        @Expect(e.message.contains("bad-name"))
        @Expect(ev.evaluate("x"), 1.0)
        @Expect(captureError({ => ev.evaluate("y") }).code, "UNKNOWN_VARIABLE")
    }

    @TestCase
    func firstInvalidValueWinsAndRecoveryWorks() {
        let ev = Evaluator()
        ev.bindAll([("price", 12.5), ("qty", 4.0)])
        let e = captureError({ => ev.bindAll([("price", 15.0), ("qty", Float64.Inf), ("", 0.0)]) })
        @Expect(e.code, "NON_FINITE")
        @Expect(e.message.contains("第 2 项"))
        @Expect(ev.evaluate("price*qty"), 50.0)
        ev.bindAll([("price", 15.0), ("qty", 6.0)])
        @Expect(ev.evaluate("price*qty"), 90.0)
    }

    @TestCase
    func laterDuplicateDoesNotHideInvalidEntry() {
        let ev = Evaluator()
        let e = captureError({ => ev.bindAll([("x", Float64.NaN), ("x", 2.0)]) })
        @Expect(e.code, "NON_FINITE")
        @Expect(e.message.contains("第 1 项"))
        @Expect(captureError({ => ev.evaluate("x") }).code, "UNKNOWN_VARIABLE")
    }

    @TestCase
    func submittedTasksKeepTheirBatch() {
        let ev = Evaluator()
        let formula = CompiledExpression("price*qty")
        ev.bindAll([("price", 12.5), ("qty", 4.0)])
        let text = ev.evaluateAsync("price*qty")
        let compiled = formula.evaluateAsync(ev)
        ev.bindAll([("price", 15.0), ("qty", 6.0)])
        @Expect(text.get(), 50.0)
        @Expect(compiled.get(), 50.0)
        @Expect(formula.evaluate(ev), 90.0)
    }

    @TestCase
    func readersSeeWholeBatches() {
        let ev = Evaluator()
        ev.bindAll([("x", 0.0), ("y", 0.0)])
        let difference = CompiledExpression("x-y")
        let start = Barrier(2)
        let writer = spawn {
            start.wait()
            for (i in 1..1001) {
                ev.bindAll([("x", Float64(i)), ("y", Float64(i))])
            }
        }
        start.wait()
        var consistent = true
        for (_ in 0..1000) {
            if (difference.evaluate(ev) != 0.0) { consistent = false }
        }
        writer.get()
        @Expect(consistent)
        @Expect(ev.evaluate("x+y"), 2000.0)
    }

    @TestCase
    func concurrentWritersPreserveUnrelatedUpdates() {
        let ev = Evaluator()
        let start = Barrier(3)
        let batches = spawn {
            start.wait()
            for (i in 1..201) { ev.bindAll([("x", Float64(i)), ("y", Float64(i))]) }
        }
        let otherBatches = spawn {
            start.wait()
            for (i in 1..201) { ev.bindAll([("a", Float64(i)), ("b", Float64(i))]) }
        }
        start.wait()
        for (i in 1..201) { ev.bind("z", Float64(i)) }
        batches.get()
        otherBatches.get()
        @Expect(ev.evaluate("x+y+a+b+z"), 1000.0)
    }
}

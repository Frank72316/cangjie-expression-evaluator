package cjexpr

import std.collection.ArrayList
import std.unittest.*
import std.unittest.testmacro.*

@Test
class BindingTests {
    @TestCase
    func bindAndReuse() {
        let ev = Evaluator()
        ev.bind("price", 12.5)
        ev.bind("count", 4.0)
        @Expect(ev.evaluate("price*count"), 50.0)
    }

    @TestCase
    func updateBinding() {
        let ev = Evaluator()
        ev.bind("x", 3.0)
        @Expect(ev.evaluate("2*x"), 6.0)
        ev.bind("x", 5.0)
        @Expect(ev.evaluate("2*x"), 10.0)
    }

    @TestCase
    func caseSensitiveNames() {
        let ev = Evaluator()
        ev.bind("X", 5.0)
        ev.bind("x", 2.0)
        @Expect(ev.evaluate("X-x"), 3.0)
    }

    @TestCase
    func identifierWithUnderscoreAndDigits() {
        let ev = Evaluator()
        ev.bind("_rate2", 0.5)
        @Expect(ev.evaluate("4*_rate2"), 2.0)
    }

    @TestCase
    func independentInstances() {
        let left = Evaluator()
        let right = Evaluator()
        left.bind("x", 1.0)
        let e = captureError({ => right.evaluate("x") })
        @Expect(e.code, "UNKNOWN_VARIABLE")
    }

    @TestCase
    func emptyBindingName() {
        let e = captureError({ => Evaluator().bind("", 1.0) })
        @Expect(e.code, "INVALID_NAME")
        @Expect(e.column, 1)
    }

    @TestCase
    func digitAtStartOfName() {
        let e = captureError({ => Evaluator().bind("1x", 1.0) })
        @Expect(e.code, "INVALID_NAME")
        @Expect(e.column, 1)
    }

    @TestCase
    func invalidNameSuffix() {
        let e = captureError({ => Evaluator().bind("x-y", 1.0) })
        @Expect(e.code, "INVALID_NAME")
        @Expect(e.column, 2)
    }

    @TestCase
    func rejectNonFiniteUpdate() {
        let ev = Evaluator()
        ev.bind("rate", 0.5)
        let e = captureError({ => ev.bind("rate", Float64.Inf) })
        @Expect(e.code, "NON_FINITE")
        @Expect(ev.evaluate("rate"), 0.5)
    }

    @TestCase
    func rejectNaN() {
        let e = captureError({ => Evaluator().bind("x", Float64.NaN) })
        @Expect(e.code, "NON_FINITE")
    }

    @TestCase
    func futureUsesSubmissionSnapshot() {
        let ev = Evaluator()
        ev.bind("x", 4.0)
        let pending = ev.evaluateAsync("x * x")
        ev.bind("x", 9.0)
        @Expect(pending.get(), 16.0)
        @Expect(ev.evaluate("x * x"), 81.0)
    }

    @TestCase
    func multipleOutstandingFutures() {
        let ev = Evaluator()
        let tasks = ArrayList<Future<Float64>>()
        for (i in 0..32) {
            ev.bind("x", Float64(i))
            tasks.add(ev.evaluateAsync("x + x"))
        }
        for (i in 0..tasks.size) {
            @Expect(tasks[i].get(), Float64(2 * i))
        }
    }

    @TestCase
    func asyncErrorPreservesLocation() {
        let task = Evaluator().evaluateAsync("1 +\n  missing")
        let e = captureError({ => task.get() })
        @Expect(e.code, "UNKNOWN_VARIABLE")
        @Expect(e.line, 2)
        @Expect(e.column, 3)
    }

    @TestCase
    func concurrentReadersAndWriter() {
        let ev = Evaluator()
        ev.bind("x", 0.0)
        let writer = spawn {
            for (i in 1..501) { ev.bind("x", Float64(i)) }
        }
        let reader = spawn {
            for (_ in 0..500) {
                if (ev.evaluate("x-x") != 0.0) { return false }
            }
            true
        }
        writer.get()
        @Expect(reader.get())
        @Expect(ev.evaluate("x"), 500.0)
    }
}

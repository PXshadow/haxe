package unit;

import haxe.ds.List;
import sys.FileSystem;
import sys.io.File;
import unit.Test.*;
import utest.Runner;
import utest.ui.Report;

final asyncWaits = new Array<haxe.PosInfos>();
final asyncCache = new Array<() -> Void>();

@:access(unit.Test)
function main() {
	#if js
	if (js.Browser.supported) {
		var oTrace = haxe.Log.trace;
		var traceElement = js.Browser.document.getElementById("haxe:trace");
		haxe.Log.trace = function(v, ?infos) {
			oTrace(v, infos);
			traceElement.innerHTML += infos.fileName + ":" + infos.lineNumber + ": " + StringTools.htmlEscape(v) + "<br/>";
		}
	}
	#end

	var verbose = #if (cpp || neko || php) Sys.args().indexOf("-v") >= 0 #else false #end;

	TestMainNow.printNow();
	trace("START");
	#if flash
	var tf:flash.text.TextField = untyped flash.Boot.getTrace();
	tf.selectable = true;
	tf.mouseEnabled = true;
	#end
	var classes = [
		// == Tier 1: pure language / codegen. No std beyond the baseline. ==
		new TestNull(), // Null<Int> vs Int comparison
		new TestNumericSeparator(), // literal parsing only, compile-time
		new TestLocalStatic(), // `static var` inside a function
		new TestOverloadsForEveryone(), // `overload extern inline`, resolved at compile time
		new TestOrder(), // `using` + enum shadowing resolution order
		new TestFieldVariance(), // all HelperMacros.typeError, i.e. compile-time only
		new TestConstrainedMonomorphs(), // monomorph constraint inference
		new TestGeneric(), // @:generic expansion
		new TestNaN(), // Math.NaN comparison semantics
		new TestLocals(), // closure capture semantics
		new TestArrowFunctions(), // closures, no std
		new TestSyntaxModule(), // gated to js/php/python: compiles to an empty case here
		new TestInterface(), // interface dispatch + Std.isOfType
		new TestCasts(), // runtime `cast(v, I)` checks -> needs type checks + throw
		new TestNumericSuffixes(), // i32/u32/i64/f64 literals + Int64 toString
		new TestOps(), // 427 loc of operator semantics (shifts, int division, overflow)
		new TestNumericCasts(), // 1525 loc, Int64/UInt conversion matrix. No std, but a big semantics grind
		// == Tier 2: light std -- collections, iterators, pattern matching, macros. ==
		new TestDefaultArgs(), // non-const default args + Int64.toStr
		new TestMapComprehension(), // Map literal comprehension
		new TestHashMap(), // haxe.ds.HashMap + user hashCode/equals
		new TestKeyValueIterator(), // StringMap, key=>value iterators, Reflect.compare
		new TestGADT(), // enum runtime + exhaustive matching
		#if !no_pattern_matching
		new TestMatch(), // full pattern matcher: enum params, Std.string of enums
		#end
		new TestMacro(), // compile-time; runtime side is trivial
		new TestDefaultTypeParameters(), // macros + Assert.same (deep, reflection-based compare)
		new TestNullCoalescing(), // ?? / ?. plus Reflect.field/setField on `this`
		new TestRest(), // haxe.Rest (native varargs) + 22 x Assert.same
		// == Tier 3: real std implementations needed. ==
		new TestBytes(), // haxe.io.Bytes: blit/compare/sub/hex
		new TestIO(), // haxe.io Input/Output/BytesBuffer, endianness
		new TestJson(), // haxe.Json encode/decode over Dynamic anons
		new TestEReg(), // a regex engine with Haxe/PCRE semantics
		new TestInt64(), // 673 loc of the full haxe.Int64 API
		new TestBasetypes(), // broad sweep: String, Array, Math, Map, Lambda + some Reflect
		new TestMisc(), // broad sweep, 647 loc: Date, StringBuf, haxe.io, inline/static init order
		new TestResource(), // needs --resource embedding + Bytes
		new TestXML(), // a full Xml parser + printer
		new TestExceptions(), // haxe.Exception, ValueException, CallStack, and native-exception
		                      // interop. NOTE: `CustomNativeException` has no branch for this
		                      // target, so this file will not even typecheck until one is added.
		// == Tier 4: reflection, RTTI, serialization, runtime services. Hardest. ==
		new TestMeta(), // haxe.rtti.Meta -> metadata must survive to runtime
		new TestReflect(), // 48 Reflect calls + 16 Type calls: fields/callMethod/makeVarArgs/copy
		new TestType(), // 809 loc of Type: resolveClass, createInstance, createEmptyInstance, typeof
		new TestSerialize(), // haxe.Serializer/Unserializer: reflection + enum + Bytes + cycles
		new TestSerializerCrossTarget(), // above, plus byte-exact agreement with other targets
		#if ((dce == "full") && !interp)
		new TestDCE(), // needs -dce full to behave *and* Type.getClassFields to observe it
		#end
		// #if (!flash && !hl && !cppia)
		// new TestCoroutines(), // 648 loc, coroutine state-machine transform + suspension
		// #end
		// new TestGcFinalizer(), // GC finalizer / weak-reference hooks
		// #if (!php && !lua)
		// /* This is annoying and causes spurious CI failures. Let's just make an effort to
		// 	not break it! */
		// // new TestHttps(), // sockets + TLS
		// #end
		// // new TestUnspecified(), // deliberately target-specific/unspecified behaviour
		// == Gated to other targets: never runs here, ignore for ordering. ==
		// #if jvm
		// new TestJava(),
		// #end
		// #if lua
		// new TestLua(),
		// #end
		// #if python
		// new TestPython(),
		// #end
		// #if hl
		// new TestHL(),
		// #end
		// #if php
		// new TestPhp(),
		// #end
		// #if jvm
		// new TestOverloads(),
		// #end
	];

	// TestIssues.addTestClasses("src/unit/teststd", "unit.teststd");
	// TestIssues.addIssueClasses("src/unit/issues", "unit.issues");
	// TestIssues.addIssueClasses("src/unit/hxcpp_issues", "unit.hxcpp_issues");

	var runner = new Runner();
	for (c in classes) {
		runner.addCase(c);
	}
	var report = Report.create(runner);
	report.displayHeader = AlwaysShowHeader;
	report.displaySuccessResults = NeverShowSuccessResults;
	var success = true;
	var passed:Array<String> = [];
	runner.onProgress.add(function(e) {
		var name = e.result.pack + (e.result.pack == "" ? "" : ".") + e.result.cls + "." + e.result.method;
		var methodPassed = true;
		for (a in e.result.assertations) {
			switch a {
				case Success(_), Warning(_), Ignore(_):
				case _:
					methodPassed = false;
					success = false;
			}
		}
		if (methodPassed)
			passed.push(name);
		#if js
		if (js.Browser.supported && e.totals == e.done) {
			untyped js.Browser.window.success = success;
		};
		#end
	});
	
	var fileName = "unittests.txt";
	runner.onComplete.add(_ -> {
		passed.sort((a, b) -> a > b ? 1 : -1);
		if (FileSystem.exists(fileName)) {
			var prev:Array<String> = File.getContent(fileName).split("\n");
			var regressions = [];
			for (t in prev) {
				if (passed.indexOf(t) == -1) {
					regressions.push(t);
				}
			}
			if (regressions.length > 0) {
				Sys.println("REGRESSIONS:");
				for (t in regressions) {
					Sys.println("  " + t);
				}
				Sys.exit(1);
			}else{
				File.saveContent(fileName, passed.join("\n"));
				Sys.exit(0);
			}
		}else{
			Sys.println("Creating new " + fileName);
			Sys.println("if the cache has expired, make sure no regressions have occurred since the last working commit.");
			File.saveContent(fileName, passed.join("\n"));
			Sys.exit(0);
		}
	});
	#if (sys || nodejs)
	if (verbose)
		runner.onTestStart.add(function(test) {
			Sys.println(' $test...'); // TODO: need utest success state for this
		});
	#end
	runner.run();

	#if (flash && fdb)
	flash.Lib.fscommand("quit");
	#end
}
package unit;

import haxe.ds.List;
import sys.FileSystem;
import sys.io.File;
import unit.Test.*;
import utest.Runner;
#if utest
import utest.ui.Report;
#end

final asyncWaits = new Array<haxe.PosInfos>();
final asyncCache = new Array<() -> Void>();

function epochMillis():String {
	var v = Math.ffloor(Date.now().getTime());
	if (v <= 0)
		return "0";
	var digits = "";
	while (v >= 1) {
		var d = Std.int(v - Math.ffloor(v / 10) * 10);
		digits = String.fromCharCode("0".code + d) + digits;
		v = Math.ffloor(v / 10);
	}
	return digits;
}

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
		new TestOps(),
		new TestBasetypes(),
		new TestNumericSuffixes(),
		new TestNumericSeparator(),
		new TestExceptions(),
		new TestBytes(),
		new TestIO(),
		new TestLocals(),
		new TestLocalStatic(),
		new TestEReg(),
		new TestXML(),
		new TestMisc(),
		new TestJson(),
		new TestResource(),
		new TestInt64(),
		new TestDefaultArgs(),
		new TestReflect(),
		new TestSerialize(),
		new TestSerializerCrossTarget(),
		new TestMeta(),
		new TestType(),
		new TestOrder(),
		new TestGADT(),
		new TestGeneric(),
		new TestArrowFunctions(),
		new TestCasts(),
		new TestSyntaxModule(),
		new TestNull(),
		new TestNullCoalescing(),
		new TestNumericCasts(),
		new TestHashMap(),
		new TestRest(),
		#if (!php && !lua)
		/// This is annoying and causes spurious CI failures. Let's just make an effort to not break it!
		// new TestHttps(),
		#end
		#if !no_pattern_matching
		new TestMatch(), // full pattern matcher: enum params, Std.string of enums
		#end
		new TestMacro(), // compile-time; runtime side is trivial
		new TestDefaultTypeParameters(), // macros + Assert.same (deep, reflection-based compare)
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
	#if teststd
	TestIssues.addTestClasses("src/unit/teststd", "unit.teststd");
	#end
	//TestIssues.addIssueClasses("src/unit/issues", "unit.issues");
	// TestIssues.addIssueClasses("src/unit/hxcpp_issues", "unit.hxcpp_issues");

	var runner = new Runner();
	for (c in classes) {
		runner.addCase(c);
	}
	#if utest
	var report = Report.create(runner);
	report.displayHeader = AlwaysShowHeader;
	report.displaySuccessResults = NeverShowSuccessResults;
	var success = true;
	var passed:Array<String> = [];
	var errored = 0;
	var total = 0;
	var jsonPassed = 0;
	var jsonErrored = 0;
	var jsonTotal = 0;
	runner.onProgress.add(function(e) {
		var name = e.result.pack + (e.result.pack == "" ? "" : ".") + e.result.cls + "." + e.result.method;
		var isStd = e.result.pack == "unit.teststd" || StringTools.startsWith(e.result.pack, "unit.teststd.");
		var isJsonData = !isStd;
		total++;
		if (isJsonData)
			jsonTotal++;
		var methodPassed = true;
		var methodErrored = false;
		for (a in e.result.assertations) {
			switch a {
				case Success(_), Warning(_), Ignore(_):
				case Failure(_, _):
					methodPassed = false;
					success = false;
				case _:
					methodPassed = false;
					methodErrored = true;
					success = false;
			}
		}
		if (methodPassed) {
			passed.push(name);
			if (isJsonData)
				jsonPassed++;
		} else if (methodErrored) {
			errored++;
			if (isJsonData)
				jsonErrored++;
		}
		#if js
		if (js.Browser.supported && e.totals == e.done) {
			untyped js.Browser.window.success = success;
		};
		#end
	});
	
	var fileName = "unittests.txt";
	var statsFile = "unittests.json";
	function writeStats() {
		// total = passed + failed + errored; failed is assertion failures only.
		var failed = jsonTotal - jsonPassed - jsonErrored;
		var ms = epochMillis();
		var record = '{"time":$ms,"total":$jsonTotal,"passed":$jsonPassed,"failed":$failed,"errored":$jsonErrored}';
		var records = [];
		if (FileSystem.exists(statsFile)) {
			var prev = StringTools.trim(File.getContent(statsFile));
			if (prev.length > 2) // more than "[]"
				records.push(prev.substring(1, prev.length - 1));
		}
		records.push(record);
		File.saveContent(statsFile, "[" + records.join(",") + "]");
	}
	runner.onComplete.add(_ -> {
		passed.sort((a, b) -> a > b ? 1 : -1);
		writeStats();
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
	#end
	runner.run();

	#if (flash && fdb)
	flash.Lib.fscommand("quit");
	#end
}
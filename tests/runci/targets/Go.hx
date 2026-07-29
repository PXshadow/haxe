package runci.targets;

import sys.FileSystem;
import haxe.io.Path;
import runci.System.*;
import runci.Config.*;

class Go {
	static public function getGoDependencies() {
		// TODO enable this for use with CI
		// haxelibInstallGit("go2hx", "hx2go", true);
		runCommand("go", ["version"]);
	}

	static function buildAndRun(args:Array<String>, output:String, ?run:(String, Array<String>)->Void):Void {
		final run = run ?? runCommand;
		runCommand("haxe", args);
		run("go", ["-C", output, "run", "."]);
	}

	static public function run(args:Array<String>) {
		deleteDirectoryRecursively("bin/go");
		getGoDependencies();

		buildAndRun(["compile-go.hxml"].concat(args), "bin/go/main");
	}
}

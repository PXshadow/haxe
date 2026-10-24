import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import UnicodeSequences.UnicodeString;
import UnicodeSequences.codepointsToString;

class GenTestRes {
	static inline var TESTDIR = "test-res";

	static final symlinks = [
		{target: "../../bin/cpp/UtilityProcess-debug", name: "bin-cpp-debug"},
		{target: "../../bin/cpp/UtilityProcess", name: "bin-cpp"},
		{target: "../../bin/cppia/UtilityProcess.cppia", name: "bin-cppia"},
		{target: "../../bin/go/utilityProcess/main/main", name: "bin-go"},
		{target: "../../bin/hl/UtilityProcess.hl", name: "bin-hl"},
		{target: "../../bin/hlc/utilityProcess/UtilityProcess.exe", name: "bin-hlc"},
		{target: "../../bin/lua/UtilityProcess.lua", name: "bin-lua"},
		{target: "../../bin/java/UtilityProcess-Debug.jar", name: "bin-java-debug"},
		{target: "../../bin/java/UtilityProcess.jar", name: "bin-java"},
		{target: "../../bin/jvm/UtilityProcess.jar", name: "bin-jvm"},
		{target: "../../bin/neko/UtilityProcess.n", name: "bin-neko"},
		{target: "../../bin/php/UtilityProcess/index.php", name: "bin-php"},
		{target: "../../bin/python/UtilityProcess.py", name: "bin-py"},
		{target: "../../bin/eval/UtilityProcess.hxb", name: "bin-eval"},
		{target: "../../bin/js/UtilityProcess.js", name: "bin-js"}
	];

	public static function main():Void {
		generate();
	}

	public static function generate():Void {
		final filenames = [for (f in UnicodeSequences.validFilenames) nameOf(f)];
		final binary = UnicodeSequences.validBytes;

		// delete previous, if any
		if (FileSystem.exists(TESTDIR)) deleteRecursively(TESTDIR);
		FileSystem.createDirectory(TESTDIR);

		// a file with Unicode data
		File.saveBytes(Path.join([TESTDIR, "data.bin"]), binary);

		// sub-directories with symlinks
		FileSystem.createDirectory(Path.join([TESTDIR, "a"]));
		for (name in filenames) {
			FileSystem.createDirectory(Path.join([TESTDIR, name]));
			FileSystem.createDirectory(Path.join([TESTDIR, "a", name]));
			for (link in symlinks)
				symlink(link.target, Path.join([TESTDIR, name, link.name]));
		}

		// files
		FileSystem.createDirectory(Path.join([TESTDIR, "b"]));
		for (name in filenames)
			File.saveBytes(Path.join([TESTDIR, "b", name]), binary);
	}
	
	static function symlink(target:String, path:String):Void {
		#if go
		go.Os.symlink(target, path);
		#else
		if (Sys.systemName() != "Windows")
			Sys.command("ln", ["-s", target, path]);
		#end
	}

	// one filename per entry from its UTF-8 bytes, i.e. the NFC form.
	static function nameOf(u:UnicodeString):String
		return switch u {
			case Only(ref): codepointsToString(ref);
			case Normal(nfc, _): codepointsToString(nfc);
		};

	static function deleteRecursively(path:String):Void {
		if (FileSystem.isDirectory(path)) {
			for (entry in FileSystem.readDirectory(path))
				deleteRecursively(Path.join([path, entry]));
			FileSystem.deleteDirectory(path);
		} else {
			FileSystem.deleteFile(path);
		}
	}
}

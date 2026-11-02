package unit;

using StringTools;

class TestIssues {
	static final brokenIssues = [
		"Issue3450", "Issue6952", "Issue6979", "Issue9149", "Issue7574",
		"Issue3094", "Issue4842", "Issue12415", "Issue12435",
		"Issue3528", "Issue3639", "Issue4203", "Issue6520", "Issue8537", "Issue12539", "Issue7115",
		"Issue3702", "Issue9897", "Issue12657",
		"Issue5793", "Issue6560", "Issue10124",
		"Issue6486", "Issue5113", "Issue6325",
		"Issue3109", "Issue6761", "Issue13046",
		"Issue11425", "Issue5025", "Issue6159",
		"Issue12149", "Issue2378",
		"Issue13043", "Issue2281", "Issue5816",
		"Issue10018", "Issue10955",
		"Issue11054", "Issue3607",
		"Issue4363", "Issue8986", "Issue5477",
	];

	macro static public function addIssueClasses(dir:String, pack:String) {
		var skip = haxe.macro.Context.defined("skip-broken-issues");
		var dir = sys.FileSystem.readDirectory(dir);
		var el = [];
		function add(className:String) {
			var tp = {
				pack: pack.split("."),
				name: className,
				sub: null,
				params: null
			}
			el.push(macro classes.push(new $tp()));
		}
		for (file in dir) {
			if (!file.endsWith(".hx")) {
				continue;
			}
			var className = file.substr(0, -3);
			if (skip && brokenIssues.indexOf(className) != -1) {
				continue;
			}
			add(className);
		}
		return macro $b{el};
	}

	macro static public function addTestClasses(dir:String, pack:String) {
		var el = [];
		function readDir(dir:String, pack:String) {
			for (file in sys.FileSystem.readDirectory(dir)) {
				var path = dir + "/" + file;
				if (sys.FileSystem.isDirectory(path)) {
					readDir(path, pack + "." + file);
				} else if (file.endsWith(".hx") && file.startsWith("Test")) {
					var className = file.substr(0, -3);
					var tp = {
						pack: pack.split("."),
						name: className,
						sub: null,
						params: null
					}
					el.push(macro classes.push(new $tp()));
				}
			}
		}
		readDir(dir, pack);
		return macro $b{el};
	}
}

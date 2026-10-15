pragma Singleton

import Quickshell

Singleton {
	id: root

	property var extensions: []

	function registerExtension(extension) {
		if (extensions.indexOf(extension) !== -1) return;
		extensions = extensions.concat([extension]);
		if (extension.expanded) activate(extension);
	}

	function unregisterExtension(extension) {
		extensions = extensions.filter(item => item !== extension);
	}

	function activate(extension) {
		const group = extension.conflictGroup;
		if (!group) return;

		for (const other of extensions) {
			if (other !== extension && other.expanded && other.conflictGroup === group)
				other.closeRequested();
		}
	}
}

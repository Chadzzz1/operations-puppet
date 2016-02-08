/**
 * Configuration for testreduce client.js script
 * for comparing Parsoid HTML rendering with PHP parser HTML rendering.
 * Use uprightdiff for image diffs
 */
'use strict';

var clientScripts = require('/srv/visualdiff/testreduce/client.scripts.js');
if (typeof module === 'object') {
	module.exports = {
		server: {
			// The address of the master HTTP server (for getting titles and posting results) (no protocol)
			host: 'localhost',

			// The port where the server is running
			port: 8011
		},
		opts: {
			viewportWidth: 1920,
			viewportHeight: 1080,

			wiki: 'enwiki',
			title: 'Main_Page',
			filePrefix: null,
			quiet: true,
			outdir: '/srv/visualdiff/pngs', // Share with clients

			// HTML1 generator options
			html1: {
				name: 'php',
				dumpHTML: false,
				postprocessorScript: '/srv/visualdiff/lib/php_parser.postprocess.js',
				injectJQuery: false,
			},
			// HTML2 generator options
			html2: {
				name: 'parsoid',
				server: 'http://parsoid.svc.eqiad.wmnet:8000',
				dumpHTML: false,
				postprocessorScript: '/srv/visualdiff/lib/parsoid.postprocess.js',
				stylesYamlFile: '/srv/visualdiff/lib/parsoid.custom_styles.yaml',
				injectJQuery: true,
			},

			// Explicitly initialize this (since we cannot use yargv to set defaults)
			// Wait 2 seconds before asking phantomjs to screenshot the page
			screenShotDelay: 2,

			// Engine for image diffs, may be resemble or uprightdiff
			diffEngine: 'uprightdiff',

			// UprightDiff options
			uprightDiffSettings: {
				binary: '/usr/local/bin/uprightdiff'
			},
		},

		postJSON: true,

		gitCommitFetch: clientScripts.gitCommitFetch,

		runTest: clientScripts.generateVisualDiff,
	};
}

<?php
/**
 * Report global function names declared by more than one source (SEC-043).
 *
 * Usage: php find-redeclared-functions.php <status>:<label>=<path> [...]
 *
 *   <status>  loaded   — the source runs on the site: an active plugin, a plugin
 *                        the local-clone step suppressed (active on production),
 *                        a mu-plugin, a drop-in, the active theme or its parent
 *             inactive — an installed plugin that is not active
 *   <label>   how the source is named in the report, e.g. plugin/<slug>
 *   <path>    a directory (its .php files, recursively) or a single file, scanned
 *             whatever its extension — a drop-in parked as `object-cache.php.bak`
 *
 * Runs on PHP 7.4+. Plain PHP, no WordPress bootstrap: it reads files only, so it runs without a
 * database and without WP-CLI. Read-only. Exits 1 when it reports anything.
 *
 * Output, one line per colliding name, tab-separated:
 *   <SEVERITY>  <name>()  <label> <file>:<line>  <label> <file>:<line> ...
 * and a summary on stderr (files, declarations, collisions, seconds).
 *
 * Severity follows how WordPress loads code. Plugin activation runs in a
 * sandbox, so a redeclare in a plugin being activated refuses the activation
 * instead of taking the site down:
 *   CRITICAL  two or more loaded sources declare it — both load in one request
 *   WARNING   exactly one loaded source declares it, the rest are inactive —
 *             the inactive plugin cannot be activated
 *   INFO      only inactive plugins declare it — they cannot be active together
 *
 * WHY TOKENS AND NOT A REGEX. A grep for `function name(` over a real
 * wp-content matched class methods, closures and namespaced functions by the
 * tens of thousands, and a "guard within three lines above" heuristic misread
 * a single `if ( ! function_exists() ) {` block wrapping several functions. The
 * tokenizer knows which braces belong to a class, a function or a guard.
 *
 * What counts as a declaration: a named `function` whose enclosing blocks are
 * neither a class/trait/interface/enum nor another function. The key is the
 * lowercased, namespace-qualified name, since PHP function names are
 * case-insensitive and functions in different namespaces do not collide.
 *
 * What is excluded as guarded (it can never redeclare):
 *   - a declaration inside `if ( ! function_exists( ... ) )` — braced,
 *     alternative `:` / `endif;` syntax, or a single braceless statement;
 *   - everything after a top-level `if ( function_exists( ... ) ) return;` or
 *     `if ( class_exists( ... ) ) return;` early exit.
 *
 * Paths containing a vendor/, node_modules/, tests/ or examples/ directory are
 * skipped: bundled libraries and fixtures that plugin code does not load as its
 * own globals. Inside a directory, a file named like a drop-in (object-cache.php,
 * advanced-cache.php, db.php, ...) is skipped too: it is the template a cache
 * plugin copies into wp-content/, and on one audited site those templates alone
 * produced 56 of 57 collisions — each plugin against its own installed drop-in.
 * A drop-in passed as a single file is always scanned.
 */

if ( PHP_SAPI !== 'cli' ) {
	exit( 2 );
}

// PHP 8 tokenizes `Foo\Bar` and `\foo` as one name token; 7.4 emits T_STRING and
// T_NS_SEPARATOR pieces, which the loops below already accept.
if ( ! defined( 'T_NAME_QUALIFIED' ) ) {
	define( 'T_NAME_QUALIFIED', -10001 );
}
if ( ! defined( 'T_NAME_FULLY_QUALIFIED' ) ) {
	define( 'T_NAME_FULLY_QUALIFIED', -10002 );
}

$started = microtime( true );
$sources = array();
foreach ( array_slice( $argv, 1 ) as $arg ) {
	if ( ! preg_match( '/^(loaded|inactive):([^=]+)=(.+)$/', $arg, $m ) ) {
		fwrite( STDERR, "bad argument: $arg (expected <loaded|inactive>:<label>=<path>)\n" );
		exit( 2 );
	}
	$sources[] = array( 'status' => $m[1], 'label' => $m[2], 'path' => rtrim( $m[3], '/' ) );
}
if ( ! $sources ) {
	fwrite( STDERR, "usage: php find-redeclared-functions.php <loaded|inactive>:<label>=<path> ...\n" );
	exit( 2 );
}

const SKIP_DIRS = array( 'vendor', 'node_modules', 'tests', 'examples' );

// WordPress loads a drop-in only from wp-content/. A file with one of these names inside a
// plugin or theme directory is the template the plugin copies there, not code it loads —
// scanning it reports the plugin colliding with its own installed drop-in.
const DROPIN_TEMPLATES = array(
	'advanced-cache.php', 'object-cache.php', 'db.php', 'db-error.php', 'maintenance.php',
	'php-error.php', 'fatal-error-handler.php', 'sunrise.php',
);

function rf_php_files( $path ) {
	if ( is_file( $path ) ) {
		return array( $path );    // named explicitly: scan it whatever its extension (a parked `*.php.bak` drop-in)
	}
	if ( ! is_dir( $path ) ) {
		return array();
	}
	$out = array();
	$it  = new RecursiveIteratorIterator(
		new RecursiveCallbackFilterIterator(
			new RecursiveDirectoryIterator( $path, FilesystemIterator::SKIP_DOTS ),
			function ( $file ) {
				return ! ( $file->isDir() && in_array( strtolower( $file->getFilename() ), SKIP_DIRS, true ) );
			}
		)
	);
	foreach ( $it as $file ) {
		if ( $file->isFile() && strtolower( $file->getExtension() ) === 'php'
			&& ! in_array( strtolower( $file->getFilename() ), DROPIN_TEMPLATES, true ) ) {
			$out[] = $file->getPathname();
		}
	}
	return $out;
}

/** Index of the next token that is not whitespace or a comment, or null. */
function rf_next( $t, $i ) {
	$n = count( $t );
	for ( $i++; $i < $n; $i++ ) {
		if ( is_array( $t[ $i ] ) && in_array( $t[ $i ][0], array( T_WHITESPACE, T_COMMENT, T_DOC_COMMENT ), true ) ) {
			continue;
		}
		return $i;
	}
	return null;
}

/** Index of the token closing the parenthesis opened at $i. */
function rf_close_paren( $t, $i ) {
	$depth = 0;
	for ( $n = count( $t ); $i < $n; $i++ ) {
		if ( $t[ $i ] === '(' ) {
			$depth++;
		} elseif ( $t[ $i ] === ')' && --$depth === 0 ) {
			return $i;
		}
	}
	return null;
}

/**
 * Classify an if-condition between two indices: 'negated' for
 * `! function_exists(...)`, 'positive' for a bare function_exists/class_exists
 * test, or null.
 */
function rf_condition( $t, $from, $to ) {
	for ( $i = $from; $i < $to; $i++ ) {
		if ( is_array( $t[ $i ] ) && in_array( $t[ $i ][0], array( T_STRING, T_NAME_FULLY_QUALIFIED ), true ) ) {
			$name = strtolower( ltrim( $t[ $i ][1], '\\' ) );
			if ( $name !== 'function_exists' && $name !== 'class_exists' ) {
				continue;
			}
			for ( $j = $i - 1; $j > $from; $j-- ) {
				if ( is_array( $t[ $j ] ) && in_array( $t[ $j ][0], array( T_WHITESPACE, T_NS_SEPARATOR ), true ) ) {
					continue;
				}
				break;
			}
			if ( $t[ $j ] === '!' ) {
				return $name === 'function_exists' ? 'negated' : null;
			}
			return 'positive';
		}
	}
	return null;
}

/** @return array<int, array{0:string,1:int}> [qualified name, line] of unguarded declarations */
function rf_declarations( $code ) {
	$t        = @token_get_all( $code );
	$n        = count( $t );
	$stack    = array();      // block kinds: class | function | guard | namespace | other
	$pending  = null;         // kind the next `{` opens
	$ns       = '';
	$alt      = array();      // open alternative-syntax `if (...) :` blocks: guard | other
	$guard_1  = false;        // braceless guarded single statement
	$file_ok  = false;        // early-return guard seen: rest of file is guarded
	$found    = array();

	for ( $i = 0; $i < $n; $i++ ) {
		$tok = $t[ $i ];
		$id  = is_array( $tok ) ? $tok[0] : $tok;

		if ( $id === T_NAMESPACE ) {
			$j    = rf_next( $t, $i );
			$name = '';
			while ( $j !== null && is_array( $t[ $j ] ) && in_array( $t[ $j ][0], array( T_STRING, T_NAME_QUALIFIED, T_NS_SEPARATOR ), true ) ) {
				$name .= $t[ $j ][1];
				$j     = rf_next( $t, $j );
			}
			if ( $j !== null && ( $t[ $j ] === ';' || $t[ $j ] === '{' ) ) {
				$ns = $name;
				if ( $t[ $j ] === '{' ) {
					$stack[] = 'namespace';
					$i       = $j;
				}
			}
			continue;
		}
		if ( in_array( $id, array( T_CLASS, T_INTERFACE, T_TRAIT ), true ) || ( defined( 'T_ENUM' ) && $id === T_ENUM ) ) {
			$p = $i - 1;
			while ( $p >= 0 && is_array( $t[ $p ] ) && $t[ $p ][0] === T_WHITESPACE ) {
				$p--;
			}
			if ( $p >= 0 && is_array( $t[ $p ] ) && $t[ $p ][0] === T_DOUBLE_COLON ) {
				continue;    // Foo::class
			}
			$pending = 'class';
			continue;
		}
		if ( $id === T_IF ) {
			$open  = rf_next( $t, $i );
			$close = $open !== null && $t[ $open ] === '(' ? rf_close_paren( $t, $open ) : null;
			if ( $close === null ) {
				continue;
			}
			$kind  = rf_condition( $t, $open, $close );
			$after = rf_next( $t, $close );
			if ( $after !== null && $t[ $after ] === ':' ) {
				$alt[] = $kind === 'negated' ? 'guard' : 'other';
				$i     = $after;
				continue;
			}
			if ( $kind === 'negated' && $after !== null ) {
				if ( $t[ $after ] === '{' ) {
					$stack[] = 'guard';
					$i       = $after;
				} else {
					$guard_1 = true;
					$i       = $close;
				}
				continue;
			}
			if ( $kind === 'positive' && $after !== null && ! array_diff( $stack, array( 'namespace' ) ) ) {
				$ret = $t[ $after ] === '{' ? rf_next( $t, $after ) : $after;
				if ( $ret !== null && is_array( $t[ $ret ] ) && $t[ $ret ][0] === T_RETURN ) {
					$file_ok = true;
				}
			}
			continue;
		}
		if ( $id === T_ENDIF && $alt ) {
			array_pop( $alt );
			continue;
		}
		if ( $id === T_FUNCTION ) {
			$j = rf_next( $t, $i );
			if ( $j !== null && $t[ $j ] === '&' ) {
				$j = rf_next( $t, $j );
			}
			$named = $j !== null && is_array( $t[ $j ] ) && $t[ $j ][0] === T_STRING;
			$inside = in_array( 'class', $stack, true ) || in_array( 'function', $stack, true ) || $pending === 'class';
			if ( $named && ! $inside && ! $file_ok && ! $guard_1 && ! in_array( 'guard', $alt, true ) && ! in_array( 'guard', $stack, true ) ) {
				$found[] = array( strtolower( ( $ns !== '' ? $ns . '\\' : '' ) . $t[ $j ][1] ), $t[ $j ][2] );
			}
			$guard_1 = false;
			if ( $pending !== 'class' ) {
				$pending = 'function';
			}
			continue;
		}
		if ( $id === '{' || $id === T_CURLY_OPEN || $id === T_DOLLAR_OPEN_CURLY_BRACES ) {
			$stack[] = ( $id === '{' && $pending ) ? $pending : 'other';
			if ( $id === '{' ) {
				$pending = null;
			}
			continue;
		}
		if ( $id === '}' ) {
			$kind = array_pop( $stack );
			if ( $kind === 'namespace' ) {
				$ns = '';
			}
			if ( ! $stack ) {
				$guard_1 = false;
			}
			continue;
		}
		if ( $id === ';' ) {
			if ( $pending === 'function' ) {
				$pending = null;    // abstract or interface method: no body
			}
			$guard_1 = false;
		}
	}
	return $found;
}

$by_name = array();
$files   = 0;
$decls   = 0;
foreach ( $sources as $s => $src ) {
	foreach ( rf_php_files( $src['path'] ) as $file ) {
		$code = @file_get_contents( $file );
		if ( $code === false ) {
			continue;
		}
		$files++;
		$rel = ltrim( substr( $file, strlen( $src['path'] ) ), '/' );
		foreach ( rf_declarations( $code ) as list( $name, $line ) ) {
			$decls++;
			// First declaration per source: two in one source are that source's own business.
			if ( ! isset( $by_name[ $name ][ $s ] ) ) {
				$by_name[ $name ][ $s ] = ( $rel === '' ? basename( $file ) : $rel ) . ':' . $line;
			}
		}
	}
}

$counts = array( 'CRITICAL' => 0, 'WARNING' => 0, 'INFO' => 0 );
ksort( $by_name );
foreach ( $by_name as $name => $where ) {
	if ( count( $where ) < 2 ) {
		continue;
	}
	$loaded = 0;
	$cells  = array();
	foreach ( $where as $s => $loc ) {
		$loaded += $sources[ $s ]['status'] === 'loaded' ? 1 : 0;
		$cells[] = $sources[ $s ]['label'] . ' ' . $loc;
	}
	$sev = $loaded >= 2 ? 'CRITICAL' : ( $loaded === 1 ? 'WARNING' : 'INFO' );
	$counts[ $sev ]++;
	echo $sev, "\t", $name, "()\t", implode( "\t", $cells ), "\n";
}

fwrite(
	STDERR,
	sprintf(
		"files=%d declarations=%d critical=%d warning=%d info=%d seconds=%.2f\n",
		$files, $decls, $counts['CRITICAL'], $counts['WARNING'], $counts['INFO'], microtime( true ) - $started
	)
);
exit( array_sum( $counts ) > 0 ? 1 : 0 );

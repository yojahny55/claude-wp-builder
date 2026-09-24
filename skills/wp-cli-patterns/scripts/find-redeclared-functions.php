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
 * Runs on PHP 7.4+. Plain PHP, no WordPress bootstrap: it reads files only, so it
 * runs without a database and without WP-CLI. Read-only.
 *
 * Exit status:
 *   0  every source was found and nothing collides
 *   1  at least one collision (printed on stdout)
 *   2  bad usage, or a source path does not exist (`missing source: <label>` on
 *      stderr). Collisions among the sources that were found are still printed,
 *      but the run is incomplete and must not be read as a pass.
 * A directory or file that exists but cannot be read, or a file the tokenizer
 * cannot process, is reported on stderr as `skipped: <path> (<reason>)` and does
 * not change the exit status; the caller lists those lines as partial coverage.
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
 * What counts as a declaration: `function <name> (` whose enclosing blocks are
 * neither a class/trait/interface/enum nor another function. `use function x;`
 * is an import, not a declaration. The key is the lowercased,
 * namespace-qualified name, since PHP function names are case-insensitive and
 * functions in different namespaces do not collide.
 *
 * What is excluded as guarded (it can never redeclare, or only runs once):
 *   - a declaration inside `if` / `elseif` whose condition negates
 *     function_exists, class_exists, interface_exists, trait_exists,
 *     enum_exists or defined — braced, alternative `:` / `endif;` syntax, or a
 *     single braceless statement. The negated test may be any operand of an
 *     `&&` chain; next to an `||` it guards nothing, since the body then also
 *     runs when the other operand holds;
 *   - everything after a top-level `if ( <one of those> ) return;` early exit,
 *     where the test may be any operand of an `||` chain.
 *
 * Paths containing a vendor/, node_modules/, tests/ or examples/ directory are
 * skipped: bundled libraries and fixtures that plugin code does not load as its
 * own globals. Inside a directory, `object-cache.php` and `advanced-cache.php`
 * are skipped too: a cache plugin ships its drop-in as a template it copies into
 * wp-content/, never loads it itself, and on one audited site those two
 * templates produced 56 of 57 collisions — each plugin against its own
 * installed drop-in. A drop-in passed as a single file is always scanned.
 */

if ( PHP_SAPI !== 'cli' ) {
	exit( 2 );
}

// PHP 8 tokenizes `Foo\Bar` and `\foo` as one name token; 7.4 emits T_STRING and
// T_NS_SEPARATOR pieces, which the loops below also accept.
if ( ! defined( 'T_NAME_QUALIFIED' ) ) {
	define( 'T_NAME_QUALIFIED', -10001 );
}
if ( ! defined( 'T_NAME_FULLY_QUALIFIED' ) ) {
	define( 'T_NAME_FULLY_QUALIFIED', -10002 );
}

const RF_SKIP_DIRS       = array( 'vendor', 'node_modules', 'tests', 'examples' );
const RF_DROPIN_TEMPLATE = array( 'advanced-cache.php', 'object-cache.php' );
const RF_GUARD_TESTS     = array( 'function_exists', 'class_exists', 'interface_exists', 'trait_exists', 'enum_exists', 'defined' );

$started = microtime( true );
$sources = array();
foreach ( array_slice( $argv, 1 ) as $arg ) {
	if ( ! preg_match( '/^(loaded|inactive):([^=]*)=(.+)$/', $arg, $m ) ) {
		fwrite( STDERR, "bad argument: $arg (expected <loaded|inactive>:<label>=<path>)\n" );
		exit( 2 );
	}
	if ( '' === trim( $m[2] ) ) {
		// The label names the source in every finding; an empty one would print as a blank column.
		fwrite( STDERR, "bad argument: $arg (empty label — use e.g. loaded:plugin/<slug>=<path>)\n" );
		exit( 2 );
	}
	$sources[] = array( 'status' => $m[1], 'label' => $m[2], 'path' => rtrim( $m[3], '/' ) );
}
if ( ! $sources ) {
	fwrite( STDERR, "usage: php find-redeclared-functions.php <loaded|inactive>:<label>=<path> ...\n" );
	exit( 2 );
}

/** Collect the .php files under $dir into $out; an unreadable directory goes to stderr. */
function rf_walk( $dir, array &$out, array &$seen ) {
	$real = realpath( $dir );
	if ( $real === false || isset( $seen[ $real ] ) ) {
		return;    // a symlink loop, or a directory already walked
	}
	$seen[ $real ] = true;
	$entries       = @scandir( $dir );
	if ( $entries === false ) {
		fwrite( STDERR, "skipped: $dir (cannot be read)\n" );
		return;
	}
	foreach ( $entries as $name ) {
		if ( $name === '.' || $name === '..' ) {
			continue;
		}
		$path = $dir . '/' . $name;
		if ( is_dir( $path ) ) {
			if ( ! in_array( strtolower( $name ), RF_SKIP_DIRS, true ) ) {
				rf_walk( $path, $out, $seen );
			}
		} elseif ( strtolower( pathinfo( $name, PATHINFO_EXTENSION ) ) === 'php'
			&& ! in_array( strtolower( $name ), RF_DROPIN_TEMPLATE, true ) ) {
			$out[] = $path;
		}
	}
}

/** Index of the next token that is not whitespace or a comment, or null. */
function rf_next( $t, $i ) {
	for ( $n = count( $t ), $i++; $i < $n; $i++ ) {
		if ( is_array( $t[ $i ] ) && in_array( $t[ $i ][0], array( T_WHITESPACE, T_COMMENT, T_DOC_COMMENT ), true ) ) {
			continue;
		}
		return $i;
	}
	return null;
}

/** Index of the previous token that is not whitespace or a comment, or null. */
function rf_prev( $t, $i ) {
	for ( $i--; $i >= 0; $i-- ) {
		if ( is_array( $t[ $i ] ) && in_array( $t[ $i ][0], array( T_WHITESPACE, T_COMMENT, T_DOC_COMMENT ), true ) ) {
			continue;
		}
		return $i;
	}
	return null;
}

/** Index of the token closing the parenthesis opened at $i, or null. */
function rf_close_paren( $t, $i ) {
	for ( $depth = 0, $n = count( $t ); $i < $n; $i++ ) {
		if ( $t[ $i ] === '(' ) {
			$depth++;
		} elseif ( $t[ $i ] === ')' && --$depth === 0 ) {
			return $i;
		}
	}
	return null;
}

/**
 * Classify one operand of a condition, tokens $s..$e inclusive: 'negated' for
 * `! function_exists(...)` and the like, 'positive' for a bare test, or null
 * when the operand is anything else. Wrapping parentheses are peeled and an
 * even number of `!` cancels out.
 */
function rf_test_kind( $t, $s, $e ) {
	if ( is_array( $t[ $s ] ) && in_array( $t[ $s ][0], array( T_WHITESPACE, T_COMMENT, T_DOC_COMMENT ), true ) ) {
		$s = rf_next( $t, $s );
	}
	if ( is_array( $t[ $e ] ) && in_array( $t[ $e ][0], array( T_WHITESPACE, T_COMMENT, T_DOC_COMMENT ), true ) ) {
		$e = rf_prev( $t, $e );
	}
	$negated = false;
	while ( $s !== null && $e !== null && $s < $e ) {
		if ( $t[ $s ] === '!' ) {
			$negated = ! $negated;
			$s       = rf_next( $t, $s );
		} elseif ( $t[ $s ] === '(' && rf_close_paren( $t, $s ) === $e ) {
			$s = rf_next( $t, $s );
			$e = rf_prev( $t, $e );
		} else {
			break;
		}
	}
	if ( $s === null || $e === null || $s >= $e ) {
		return null;
	}
	if ( is_array( $t[ $s ] ) && $t[ $s ][0] === T_NS_SEPARATOR ) {
		$s = rf_next( $t, $s );    // 7.4: `\function_exists` is two tokens
	}
	if ( ! is_array( $t[ $s ] ) || ! in_array( $t[ $s ][0], array( T_STRING, T_NAME_FULLY_QUALIFIED ), true )
		|| ! in_array( strtolower( ltrim( $t[ $s ][1], '\\' ) ), RF_GUARD_TESTS, true ) ) {
		return null;
	}
	$open = rf_next( $t, $s );
	if ( $open === null || $t[ $open ] !== '(' || rf_close_paren( $t, $open ) !== $e ) {
		return null;
	}
	return $negated ? 'negated' : 'positive';
}

/**
 * Classify the if-condition between two parenthesis indices by what it
 * guarantees, reading every top-level operand and the operators joining them:
 *   - 'negated' when the body can only run while the name is undeclared: the
 *     operands are joined by `&&` / `and` alone (or there is just one) and at
 *     least one is `! <test>(...)` — `defined( 'X' ) && ! function_exists()`
 *     is a guard, whichever operand comes first;
 *   - 'positive' when the body runs whenever the name exists (the shape an
 *     early `return` needs): operands joined by `||` / `or` alone, at least
 *     one a bare `<test>(...)`;
 *   - null otherwise. An `||` next to a negated test is not a guard — in
 *     `! class_exists( 'Foo' ) || ! function_exists( 'fn' )` the body also
 *     runs whenever Foo is missing — and a mix of `&&` with `||`, `xor`, a
 *     ternary or `??` at the top level is never read as one either.
 */
function rf_condition( $t, $from, $to ) {
	$parts = array();
	$ops   = array();
	$depth = 0;
	$start = $from + 1;
	for ( $i = $from + 1; $i < $to; $i++ ) {
		$tok = $t[ $i ];
		$id  = is_array( $tok ) ? $tok[0] : $tok;
		if ( $id === '(' || $id === '[' || $id === '{' || $id === T_CURLY_OPEN || $id === T_DOLLAR_OPEN_CURLY_BRACES ) {
			$depth++;
			continue;
		}
		if ( $id === ')' || $id === ']' || $id === '}' ) {
			$depth--;
			continue;
		}
		if ( $depth > 0 ) {
			continue;
		}
		if ( $id === T_BOOLEAN_AND || $id === T_LOGICAL_AND ) {
			$ops['and'] = true;
		} elseif ( $id === T_BOOLEAN_OR || $id === T_LOGICAL_OR ) {
			$ops['or'] = true;
		} elseif ( $id === T_LOGICAL_XOR || $id === '?' || $id === T_COALESCE ) {
			return null;
		} else {
			continue;
		}
		$parts[] = array( $start, $i - 1 );
		$start   = $i + 1;
	}
	$parts[] = array( $start, $to - 1 );
	if ( count( $ops ) > 1 ) {
		return null;
	}
	$want = isset( $ops['or'] ) ? 'positive' : ( isset( $ops['and'] ) ? 'negated' : null );
	foreach ( $parts as $part ) {
		if ( $part[0] > $part[1] ) {
			continue;
		}
		$kind = rf_test_kind( $t, $part[0], $part[1] );
		if ( $kind !== null && ( $want === null || $kind === $want ) ) {
			return $kind;
		}
	}
	return null;
}

/**
 * @return array<int, array{0:string,1:int}>|null [qualified name, line] of unguarded
 *         declarations, or null when the source could not be tokenized at all.
 */
function rf_declarations( $code ) {
	$t = @token_get_all( $code );
	if ( ! is_array( $t ) ) {
		return null;    // never folded into "declares nothing": the caller reports it
	}
	$n       = count( $t );
	$stack   = array();    // brace blocks: class | function | guard | namespace | other
	$pending = null;       // the kind the next `{` opens
	$ns      = '';
	$alt     = array();    // open alternative-syntax `if (...) :` chains: guard | other
	$guard_1 = false;      // inside a braceless guarded statement
	$file_ok = false;      // a top-level early-return guard: the rest of the file is guarded
	$found   = array();

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

		// class / interface / trait / enum open a class body. Before PHP 8.1 `enum` is a
		// T_STRING, recognised by its shape: `enum Name {`, `enum Name: type {`, `enum Name implements`.
		$is_type = in_array( $id, array( T_CLASS, T_INTERFACE, T_TRAIT ), true ) || ( defined( 'T_ENUM' ) && $id === T_ENUM );
		if ( ! $is_type && $id === T_STRING && strtolower( $tok[1] ) === 'enum' ) {
			$j       = rf_next( $t, $i );
			$k       = ( $j !== null && is_array( $t[ $j ] ) && $t[ $j ][0] === T_STRING ) ? rf_next( $t, $j ) : null;
			$is_type = $k !== null && ( $t[ $k ] === '{' || $t[ $k ] === ':' || ( is_array( $t[ $k ] ) && $t[ $k ][0] === T_IMPLEMENTS ) );
		}
		if ( $is_type ) {
			$p = rf_prev( $t, $i );
			if ( $p === null || ! is_array( $t[ $p ] ) || $t[ $p ][0] !== T_DOUBLE_COLON ) {
				$pending = 'class';    // not `Foo::class`
			}
			continue;
		}

		if ( $id === T_IF || $id === T_ELSEIF ) {
			$open  = rf_next( $t, $i );
			$close = ( $open !== null && $t[ $open ] === '(' ) ? rf_close_paren( $t, $open ) : null;
			if ( $close === null ) {
				continue;
			}
			$kind  = rf_condition( $t, $open, $close );
			$after = rf_next( $t, $close );
			if ( $after !== null && $t[ $after ] === ':' ) {
				// An alternative-syntax elseif continues the chain its if opened; one endif closes both.
				if ( $id === T_ELSEIF && $alt ) {
					array_pop( $alt );
				}
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
			if ( $kind === 'positive' && $id === T_IF && $after !== null && ! array_diff( $stack, array( 'namespace' ) ) ) {
				$ret = $t[ $after ] === '{' ? rf_next( $t, $after ) : $after;
				if ( $ret !== null && is_array( $t[ $ret ] ) && $t[ $ret ][0] === T_RETURN ) {
					$file_ok = true;
				}
			}
			continue;
		}
		if ( $id === T_ELSE ) {
			$after = rf_next( $t, $i );
			if ( $after !== null && $t[ $after ] === ':' && $alt ) {
				array_pop( $alt );    // the else branch of a guard chain is not guarded
				$alt[] = 'other';
				$i     = $after;
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
			if ( $j !== null && $t[ $j ] === '(' ) {
				if ( $pending !== 'class' ) {
					$pending = 'function';    // a closure: its body is a function body
				}
				continue;
			}
			$paren = $j !== null ? rf_next( $t, $j ) : null;
			if ( $j === null || ! is_array( $t[ $j ] ) || $t[ $j ][0] !== T_STRING || $paren === null || $t[ $paren ] !== '(' ) {
				// Not `function name (`. This is also what excludes every import form —
				// `use function x;`, `use function A\{b, c};`, `use A\{function b, const C};` —
				// since valid PHP never puts `(` after an imported name.
				continue;
			}
			$inside  = in_array( 'class', $stack, true ) || in_array( 'function', $stack, true ) || $pending === 'class';
			$guarded = $file_ok || $guard_1 || in_array( 'guard', $alt, true ) || in_array( 'guard', $stack, true );
			if ( ! $inside && ! $guarded ) {
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
			if ( array_pop( $stack ) === 'namespace' ) {
				$ns = '';
			}
			continue;
		}
		if ( $id === ';' ) {
			if ( $pending === 'function' ) {
				$pending = null;    // an abstract or interface method: no body
			}
			if ( ! in_array( 'function', $stack, true ) ) {
				$guard_1 = false;    // the braceless guarded statement ended
			}
		}
	}
	return $found;
}

$by_name = array();
$files   = 0;
$decls   = 0;
$missing = array();
foreach ( $sources as $s => $src ) {
	$list = array();
	if ( is_file( $src['path'] ) ) {
		$list[] = $src['path'];    // named explicitly: scanned whatever its extension
	} elseif ( is_dir( $src['path'] ) ) {
		$seen = array();
		rf_walk( $src['path'], $list, $seen );
	} else {
		$missing[] = $src['label'];
		fwrite( STDERR, "missing source: {$src['label']} ({$src['path']})\n" );
		continue;
	}
	foreach ( $list as $file ) {
		$code = @file_get_contents( $file );
		if ( $code === false ) {
			fwrite( STDERR, "skipped: $file (cannot be read)\n" );
			continue;
		}
		$decls_in_file = rf_declarations( $code );
		if ( null === $decls_in_file ) {
			fwrite( STDERR, "skipped: $file (cannot be tokenized)\n" );
			continue;
		}
		$files++;
		$rel = ltrim( substr( $file, strlen( $src['path'] ) ), '/' );
		foreach ( $decls_in_file as list( $name, $line ) ) {
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
		"files=%d declarations=%d critical=%d warning=%d info=%d missing=%d seconds=%.2f\n",
		$files, $decls, $counts['CRITICAL'], $counts['WARNING'], $counts['INFO'], count( $missing ), microtime( true ) - $started
	)
);
if ( $missing ) {
	exit( 2 );
}
exit( array_sum( $counts ) > 0 ? 1 : 0 );

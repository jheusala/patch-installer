#!/bin/sh
set -e
SELF_VERSION=0.0.1

# Parse arguments
force='0'
action=''
patch=''
target=''
prev=''
next=''
for arg in "$@"; do
case "$arg" in

# Patch file argument
  --patch=*)
	patch="${arg#--patch=}"
  ;;

# prev
  --prev=*) prev="${arg#--prev=}"
  ;;

# next
  --next=*) next="${arg#--next=}"
  ;;

# Install to target directory
  --install=*)
	target="${arg#--install=}"
	action=install
  ;;

# Install to target directory
  --create=*)
	patch="${arg#--create=}"
	action=create
  ;;

# Install to target directory
  -f|--force)
	force=1
  ;;

# Actions
  --get-patch|--get-checks|--create)
	action="${arg#--}"
  ;;

  get-patch|get-checks|create)
	action="$arg"
  ;;

  ### 
  ### Help
  ### 
  -v|--version)
	echo $SELV_VERSION
  ;;

  ### 
  ### Help
  ### 
  -h|--help|--usage|help)
    echo 'USAGE: $0 OPTION(S) ACTION'
    echo '  where OPTION is one of:'
    echo '     -f  --force        Force action'
    echo '         --install=DIR  Install the embedded patch to DIR'
    echo '         --check=DIR    Verify compatibility of DIR for the embedded patch'
    echo '         --prev=DIR     Original source directory for create action'
    echo '         --next=DIR     New source directory for create action'
    echo '         --create=FILE  Create install script to FILE'
    echo '  where ACTION is one of:'
    echo '         get-checks   Print embedded checksums'
    echo '         get-patch  Print the embedded diff'
    echo '         check      Verify compatibility of the patch'
    echo '         install    Install the patch'
    echo '         create     Create embedded patch installer script'
    echo
    exit 0
  ;;  
esac
done

if test x"$action" = x; then
	$0 --usage
	exit 1
fi

# Execute actions
case "$action" in

get-patch)
	grep -E '^\#:' "$0"|sed -re 's/^\#://'
	;;

get-checks)
	$0 get-patch|grep -E '^(sha1sum|missing)'
	;;

check)
	#$0 get-checks|while read line; do
	#	
	#done
	;;

create)
	tmpdir="$(mktemp -d)"
	tmpfile="$tmpdir/foo.sh"
	tmpfile2="$tmpdir/foo.diff"
	prevln="$tmpdir/prevln"
	nextln="$tmpdir/nextln"
	trap "rm -f -- '$tmpfile' '$tmpfile2' '$prevln' '$nextln'; test -d '$tmpdir' && rmdir '$tmpdir'" EXIT

	chmod 700 "$tmpdir"

	touch "$tmpfile"
	chmod 600 "$tmpfile"

	touch "$tmpfile2"
	chmod 600 "$tmpfile2"

	if test -z "$prev"; then
		echo 'Error: --prev not set' >&2
		exit 1
	fi

	if test -d "$prev"; then
		prev="$(cd "$prev" && pwd)"
	else
		echo 'Error: --prev not directory' >&2
		exit 1
	fi

	if test -z "$next"; then
		echo 'Error: --next not set' >&2
		exit 1
	fi

	if test -d "$next"; then
		next="$(cd "$next" && pwd)"
	else
		echo 'Error: --next not directory' >&2
		exit 1
	fi

	if test -n "$patch" && test -e "$patch"; then
		if test x"$force" = x0; then
			echo 'Error: file exists already: '"$patch" >&2
			exit 1
		fi
	fi

	ln -s "$prev" "$prevln"
	ln -s "$next" $nextln"

	cat "$0" > "$tmpfile"

	echo "#:Embedded patch for patch-installer.sh" >> "$tmpfile"
	echo "#:version:$SELF_VERSION" >> "$tmpfile"

	if (cd "$tmpdir" && diff -purN "prevln/" "nextln/") > "$tmpfile2"; then
		echo "Error: Sources are same!" >&2
		exit 1
	else
		status="$?"
		if test x"$status" = x1; then
			:
		else
			echo 'Error: Failed to patch sources!' >&2
			exit 1
		fi
	fi

	cat "$tmpfile2"|grep -E '^(\-\-\-)'|sed -re 's/^(\-\-\-)\s+//' -e 's/\t.*$//'|sort|uniq|while read file; do
		if test -f "$file"; then
			sha1sum "$file"|sed -re 's/^/#:sha1sum:/' >> "$tmpfile"
		else
			echo "#:missing:$file" >> "$tmpfile"
		fi
	done
	echo "#:" >> "$tmpfile"
	
	cat "$tmpfile2"|sed -re 's/^/#:/' >> "$tmpfile"
	if test -z "$patch"; then
		cat "$tmpfile"
	else
		cp -f "$tmpfile" "$patch"
		chmod 700 "$patch"
	fi

	rm -f -- "$tmpfile" "$tmpfile2" "$prevln" "$nextln"
	rmdir "$tmpdir"
	trap - EXIT
	exit
	;;
esac

exit 0
# EOF #

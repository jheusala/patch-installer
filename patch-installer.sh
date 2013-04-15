#!/bin/sh
# Patch Installer (and Installer Builder)
#
# Check latest version from https://github.com/jheusala/patch-installer
#
# Copyright (C) 2013 by Jaakko-Heikki Heusala <jheusala@iki.fi>
#
# Permission is hereby granted, free of charge, to any person obtaining 
# a copy of this software and associated documentation files (the 
# "Software"), to deal in the Software without restriction, including 
# without limitation the rights to use, copy, modify, merge, publish, 
# distribute, sublicense, and/or sell copies of the Software, and to 
# permit persons to whom the Software is furnished to do so, subject to 
# the following conditions:
#
# The above copyright notice and this permission notice shall be 
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, 
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF 
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND 
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS 
# BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN 
# ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN 
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE 
# SOFTWARE.
#

set -e
SELF_PATH="$(readlink -e "$0")"
SELF_NAME="$(basename "$SELF_PATH")"
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
  --target=*)
	target="${arg#--target=}"
  ;;

# Install to target directory
  --install=*)
	target="${arg#--install=}"
	action=install
  ;;

# Check files
  --check=*)
	target="${arg#--check=}"
	action=check
  ;;

# Create install script
  --create=*)
	patch="${arg#--create=}"
	action=create
  ;;

# Force actions
  -f|--force)
	force=1
  ;;

# Actions
  --get-patch|--get-checks|--create|--check)
	action="${arg#--}"
  ;;

  get-patch|get-checks|create|check)
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
    echo 'USAGE: '"$SELF_NAME"' OPTION(S) ACTION'
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
	$SELF_PATH --usage
	exit 1
fi

# Execute actions
case "$action" in

get-patch)
	grep -E '^\#:' "$SELF_PATH"|sed -re 's/^\#://'
	exit 0
	;;

get-checks)
	$SELF_PATH get-patch|grep -E '^prev:(sha1sum|missing)'
	exit 0
	;;

install)
	
	if test -d "$target"; then
		target="$(cd "$target" && pwd)"
	else
		echo "Cannot find target directory: $target" >&2
		exit 1
	fi

	$SELF_PATH --check="$target"

	cd "$target"
	if $SELF_PATH --get-patch|patch -s -p1; then
		:
	else
		echo "Patch failed!" >&2
		exit 1
	fi

	echo 'Successfully installed to '"$target"
	exit 0
	;;

	
check)
	
	if test -d "$target"; then
		target="$(cd "$target" && pwd)"
	else
		echo "Cannot find target directory: $target" >&2
		exit 1
	fi
	
	$SELF_PATH get-checks|while read line; do
		prev="$(echo ":$line"|awk -F':' '{print $2}')"
		what="$(echo ":$line"|awk -F':' '{print $3}')"
		# FIXME: There might be files with names having ":"?
		file="$(echo ":$line"|awk -F':' '{print $4}')"
		sum="$(echo ":$line"|awk -F':' '{print $5}')"
		if test x"$prev" = xprev; then
			if test "x$what" = "xsha1sum"; then
				if test -f "$target/$file"; then
					targetsum=$(sha1sum "$target/$file"|awk '{print $1}')
					if test "x$sum" = "x$targetsum"; then
						:
					else
						echo "$file: Checksum match error" >&2
						exit 1
					fi
				else
					echo "$file: Target file does not exist - patch might not be compatible?" >&2
					exit 1
				fi
			elif test "x$what" = xmissing; then
				if test -f "$target/$file"; then
					echo "$file: Target file exists - patch might not be compatible?" >&2
					exit 1
				fi
			else
				echo "Unknown check: prev/$what" >&2
				exit 1
			fi
		else
			echo "Unknown check: $prev" >&2
			exit 1
		fi
	done
	exit 0
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
	patch="$(readlink -f "$patch")"

	ln -s "$prev" "$prevln"
	ln -s "$next" "$nextln"

	cat "$SELF_PATH" > "$tmpfile"

	echo "#:Embedded patch for patch-installer.sh" >> "$tmpfile"
	echo "#:version:$SELF_VERSION" >> "$tmpfile"

	cd "$tmpdir"

	if diff -purN prevln/ nextln/ > "$tmpfile2"; then
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

	cat "$tmpfile2"|grep -E '^(\-\-\-)'|sed -re 's/^(\-\-\-)\s+//' -e 's/\t.*$//' -e 's@^prevln/@@'|sort|uniq|while read file; do
		if test -f "prevln/$file"; then
			sum=$(sha1sum "prevln/$file"|awk '{print $1}')
			echo "#:prev:sha1sum:$file:$sum" >> "$tmpfile"
		else
			echo "#:prev:missing:$file" >> "$tmpfile"
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
	echo 'Successfully created '"$patch"

	rm -f -- "$tmpfile" "$tmpfile2" "$prevln" "$nextln"
	rmdir "$tmpdir"
	trap - EXIT

	exit 0
	;;
esac

exit 0
# EOF #

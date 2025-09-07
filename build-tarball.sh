#!/bin/sh
set -x
# Copyright (C) 2024-2025 Free Software Foundation, Inc.
#
# This file is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published
# by the Free Software Foundation, either version 3 of the License,
# or (at your option) any later version.
#
# This file is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

# This script builds the package.
# Usage: build-tarball.sh PACKAGE
# Its output is a tarball: $package/$package-*.tar.gz

package="$1"

# On even days, we use the gnulib submodule.
# On odd days, we use the newest gnulib.
# Rationale:
# <https://lists.gnu.org/archive/html/bug-inetutils/2025-08/msg00006.html>
newest_gnulib=$(expr $(date +%j) % 2)

set -e

# Fetch sources (uses package 'git').
# No '--depth 1' here, to avoid an error "unknown revision" during gen-ChangeLog.
git clone https://https.git.savannah.gnu.org/git/"$package".git
if test $newest_gnulib = 1; then
  git clone --depth 1 "${gnulib_url}"
fi

# Apply patches.
(cd "$package" && patch -p1 < ../patches/tests.diff)
(cd "$package" && patch -p1 < ../patches/0001-Improve-efficiency-of-git-clone.patch)

if test $newest_gnulib = 1; then
  export GNULIB_SRCDIR=`pwd`/gnulib
else
  unset GNULIB_SRCDIR
fi
cd "$package"
if test $newest_gnulib = 1; then
  # Force use of the newest gnulib.
  rm -f .gitmodules
fi

# Fetch extra files and generate files (uses packages wget, python3, automake, autoconf, m4).
date --utc --iso-8601 > .tarball-version
if test $newest_gnulib = 1; then
  ./bootstrap --no-git --gnulib-srcdir="$GNULIB_SRCDIR"
else
  # TODO: Optimize this. We need the gnulib checkout only with depth 1.
  # See how gitsub.sh does it, or look at gettext/autopull.sh:func_git_clone_shallow.
  ./bootstrap
fi

# Configure (uses package 'file').
./configure --config-cache CPPFLAGS="-Wall" > log1 2>&1; rc=$?; cat log1; test $rc = 0 || exit 1
# Build (uses packages make, gcc, ...).
make > log2 2>&1; rc=$?; cat log2; test $rc = 0 || exit 1
# Run the tests.
make check > log3 2>&1; rc=$?; cat log3; test $rc = 0 || exit 1
# Check that tarballs are correct.
make distcheck > log4 2>&1; rc=$?; cat log4; test $rc = 0 || exit 1

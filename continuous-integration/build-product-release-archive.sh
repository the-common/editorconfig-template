#!/usr/bin/env sh
# Build proper product release archive from source
#
# Copyright 2021 林博仁(Buo-ren, Lin) <Buo.Ren.Lin@gmail.com>
# SPDX-License-Identifier: CC-BY-SA-4.0

# Ensure script terminates when problems occurred
set \
    -o errexit \
    -o nounset

PRODUCT_IDENTIFIER="${PRODUCT_IDENTIFIER:-${DRONE_REPO#*/}}"

apk add \
    git \
	gzip \
	tar

git_describe="$(
    git describe \
        --always \
        --tags \
        --dirty
)"
product_version="${git_describe#v}"
product_release_id="${PRODUCT_IDENTIFIER}"-"${product_version}"

git archive \
	--format tar.gz \
	--prefix "${product_release_id}"/ \
	--output "${product_release_id}".tar.gz \
	HEAD

echo
echo Product release archive generated successfully.

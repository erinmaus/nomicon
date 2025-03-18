#!/bin/sh

function has_version() {
    echo $1 | sed -n 's/\([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\)/\1/p'
}

version=$(has_version $1)
if [ -z "$version" ]; then
    echo "Need a version in the format major.minor.revision (e.g., 1.0.0)"
    exit 1
fi

has_pending_changes=$(git status --porcelain)

if [ ! -z "$has_pending_changes" ]; then
    echo "Cannot package release when current directory has pending changes!"
    exit 1
fi

tag="nomicon-v${version}"

set -e

git fetch
git checkout main
git pull
git tag "$tag"
git push origin tag "$tag"

set +e

love_file="$tag.love"
zip_file="$tag.zip"
tar_file="$tag.tar.gz"

zip -r "./$love_file" ./nomicon ./tests/lib/json.lua ./README.md ./LICENSE ./main.lua ./conf.lua
zip -r "./$zip_file" ./nomicon ./README.md ./LICENSE
tar -czvf "./$tar_file" ./nomicon ./README.md ./LICENSE

gh release create --draft --verify-tag -t "nomicon v${version}" "$tag" "./$love_file" "./$zip_file"  "./$tar_file"

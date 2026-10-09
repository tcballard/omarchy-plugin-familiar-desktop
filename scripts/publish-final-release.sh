#!/usr/bin/env bash
# Invoked only by the explicitly dispatched, green-main release workflow.
# Upload the verified build before publishing: GITHUB_TOKEN release events do
# not trigger another workflow, so publication must be complete in this job.
set -Eeuo pipefail
: "${SOURCE_SHA:?}" "${RELEASE_RUN_ID:?}" "${GH_REPO:?}"
[[ "$SOURCE_SHA" =~ ^[0-9a-f]{40}$ && "$RELEASE_RUN_ID" =~ ^[0-9]+$ ]]
[[ "$GH_REPO" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]]
version="$(jq -r .version manifest.json)"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
tag="v$version"
test -f "docs/$tag.md"
test "$(git rev-parse HEAD)" = "$SOURCE_SHA"
if git show-ref --verify --quiet "refs/tags/$tag"; then
  echo "Tag $tag already exists; refusing to replace it. See docs/RELEASE-CHECKLIST.md for recovery." >&2
  exit 1
fi
pins="$PWD/release-binaries.sha256"
stage="$(mktemp -d)"
trap 'rm -rf -- "$stage"' EXIT
gh api "repos/$GH_REPO/actions/runs/$RELEASE_RUN_ID" > "$stage/run.json"
jq -e --arg sha "$SOURCE_SHA" '.head_sha == $sha and .event == "push" and .path == ".github/workflows/release.yml" and .status == "completed" and .conclusion == "success"' "$stage/run.json"
gh run download "$RELEASE_RUN_ID" --name familiar-desktop-release --dir "$stage/assets"
(cd "$stage/assets" && sha256sum --check --strict SHA256SUMS)
jq -e --arg sha "$SOURCE_SHA" --arg version "$version" '.source.commit == $sha and .version == $version and .sourcePinsMatch == true' "$stage/assets/RELEASE-MANIFEST.json"
jq -e --arg sha "$SOURCE_SHA" '.source.commit == $sha' "$stage/assets/SOURCE-MANIFEST.json"
# Checksums shipped beside a bundle are not the independent reviewed pins.
(cd "$stage/assets" && sha256sum --check --strict "$pins")
grep -Fx "release_sha='$SOURCE_SHA'" "$stage/assets/install.sh"
grep -Fx "candidate_sha='$SOURCE_SHA'" "$stage/assets/install-candidate.sh"
chmod u+x "$stage/assets/familiar-desktop-linux-x86_64"
test "$("$stage/assets/familiar-desktop-linux-x86_64" --version)" = "familiar-desktop $version"
# Do not create a tag for a commit superseded while the artifacts downloaded.
test "$(gh api "repos/$GH_REPO/git/ref/heads/main" --jq .object.sha)" = "$SOURCE_SHA"
cp "docs/$tag.md" "$stage/notes.md"
printf '\nExact source: `%s`. [Verified main build](https://github.com/%s/actions/runs/%s).\n' "$SOURCE_SHA" "$GH_REPO" "$RELEASE_RUN_ID" >> "$stage/notes.md"
git tag -a "$tag" "$SOURCE_SHA" -m "Familiar $tag; verified main $SOURCE_SHA"
git push origin "refs/tags/$tag"
gh release create "$tag" --verify-tag --draft --title "$tag" --notes-file "$stage/notes.md" "$stage/assets/"*
# Read back every uploaded byte while still a draft. A failed upload or readback
# leaves it unpublished; never advertise a release with missing installers.
gh release download "$tag" --dir "$stage/download"
for asset in "$stage/assets/"*; do cmp "$asset" "$stage/download/${asset##*/}"; done
gh release edit "$tag" --draft=false --latest
node scripts/verify-release-download.cjs --tag "$tag" --repo "$GH_REPO"

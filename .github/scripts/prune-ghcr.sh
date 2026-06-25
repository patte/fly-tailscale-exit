#!/usr/bin/env sh
# Keep the most-recent tagged releases of the image and delete the rest, so the
# GHCR package retains pinnable :<tailscale-version> tags (and :latest) for
# rollback without growing without bound.
#
# Why a custom script instead of an off-the-shelf "delete untagged versions":
# a release is several package versions. With provenance + SBOM the release is
# an index whose child manifests (image + the provenance/SBOM attestation) are
# *untagged* versions, and cosign stores its signature as a separate artifact
# tagged after the subject digest -- sha256-<hex> (OCI 1.1 referrers fallback)
# or the legacy sha256-<hex>.sig -- which itself references an untagged
# signature manifest. To keep a release usable we must keep all of these; to
# drop one we must delete all of them. So we resolve each kept release to the
# exact set of digests that belong to it and delete everything outside that set.
#
# Env:
#   IMAGE         image ref without tag, e.g. ghcr.io/patte/fly-tailscale-exit
#   OWNER         GHCR owner (user/org) that owns the package
#   PACKAGE       package name, e.g. fly-tailscale-exit
#   MAX_VERSIONS  most-recent tagged releases to keep (default 25; 0 deletes all)
#   GH_TOKEN      token with packages:write on the package (GITHUB_TOKEN is
#                 enough when the package inherits access from this repo;
#                 otherwise a PAT with delete:packages)
set -eu

: "${IMAGE:?}"
: "${OWNER:?}"
: "${PACKAGE:?}"
: "${GH_TOKEN:?}"
MAX_VERSIONS="${MAX_VERSIONS:-25}"

# GHCR refs and package names are lowercase; the caller may pass them straight
# from ${{ github.repository }} etc., which can contain uppercase on some forks.
IMAGE="$(printf '%s' "$IMAGE" | tr '[:upper:]' '[:lower:]')"
OWNER="$(printf '%s' "$OWNER" | tr '[:upper:]' '[:lower:]')"
PACKAGE="$(printf '%s' "$PACKAGE" | tr '[:upper:]' '[:lower:]')"

# Packages live under /users/<user> or /orgs/<org>; GET /users/<owner> reports the type for both
if [ "$(gh api "/users/${OWNER}" -q .type 2>/dev/null)" = "Organization" ]; then
  api="/orgs/${OWNER}/packages/container/${PACKAGE}/versions"
else
  api="/users/${OWNER}/packages/container/${PACKAGE}/versions"
fi
tab="$(printf '\t')"

# Every version: id, digest (.name), created_at, comma-joined tags.
all="$(mktemp)"
gh api --paginate "$api" \
  -q '.[] | [.id, .name, .created_at, ((.metadata.container.tags // []) | join(","))] | @tsv' \
  >"$all"

# A cosign artifact tag is the subject digest rewritten as sha256-<hex>, with an
# optional legacy .sig/.att/.sbom suffix. Such a tag is never a release tag.
sig_re='^sha256-[0-9a-f]+(\.(sig|att|sbom))?$'

# Releases = tagged versions that are not cosign artifacts, newest first by
# creation time (ISO-8601 sorts lexically == chronologically). Keep the digests
# of the MAX_VERSIONS most-recent (:latest is the newest push, always included).
keep_indexes="$(mktemp)"
awk -F"$tab" -v re="$sig_re" 'NF>=4 && $4 != "" && $4 !~ re' "$all" \
  | sort -t"$tab" -k3,3r \
  | awk -F"$tab" -v n="$MAX_VERSIONS" 'NR<=n { print $2 }' \
  >"$keep_indexes"

# Cosign artifacts as "tag<TAB>digest", for referrers lookup by subject digest.
sigmap="$(mktemp)"
awk -F"$tab" -v re="$sig_re" 'NF>=4 && $4 ~ re { print $4 "\t" $2 }' "$all" >"$sigmap"

# Build the keep set: each kept release, the child manifests it references
# (image + provenance/SBOM attestation; `[]?` no-ops for a plain manifest), and
# the cosign artifact covering it plus that artifact's own child manifest(s).
keep="$(mktemp)"
while IFS= read -r d; do
  printf '%s\n' "$d"
  docker buildx imagetools inspect --raw "${IMAGE}@${d}" | jq -r '.manifests[]?.digest'
  want="sha256-${d#sha256:}"
  sdig="$(awk -F"$tab" -v w="$want" '$1 == w || $1 == w ".sig" { print $2; exit }' "$sigmap")"
  if [ -n "$sdig" ]; then
    printf '%s\n' "$sdig"
    docker buildx imagetools inspect --raw "${IMAGE}@${sdig}" | jq -r '.manifests[]?.digest'
  fi
done <"$keep_indexes" >>"$keep"

sort -u -o "$keep" "$keep"

echo "Keeping $(wc -l <"$keep_indexes") release(s) + children + signatures = $(wc -l <"$keep") manifest(s) (max ${MAX_VERSIONS} releases)."

# Delete everything outside the keep set: releases beyond MAX_VERSIONS, the
# children and signatures of those dropped releases, and any stray untagged
# orphans (e.g. a digest a tag was moved off of).
deleted=0
while IFS="$tab" read -r id digest _ tags; do
  if grep -qxF "$digest" "$keep"; then
    continue
  fi
  echo "Deleting $digest (id $id, tags: ${tags:-<none>})"
  gh api --method DELETE "${api}/${id}"
  deleted=$((deleted + 1))
done <"$all"

echo "Prune complete; deleted ${deleted} version(s)."

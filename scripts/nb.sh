#!/bin/zsh
# /nb helper. Usage: scripts/nb.sh start <slug> | gate | land [--after <slug>] | install
# start: worktree ../vorssaint-wt-<slug> on branch nb/<slug> off local `ours`, build cache cloned in.
# gate:  run inside the worktree: swift build, touched test suites only, dash grep on added lines.
# land:  run inside the worktree, serialised by lockf: rebase on ours (rebuild if it moved),
#        merge --no-ff in the main checkout, push origin ours (fast-forward only), remove worktree.
# NB_NO_PUSH=1 lands locally only (dry runs).
# Exit: 0 ok, 2 bad state, 3 conflict (resolve in worktree, rerun), 4 build or push failed, 5 waiting on --after.
set -uo pipefail
COMMON=$(git rev-parse --path-format=absolute --git-common-dir) || exit 2
MAIN=${COMMON%/.git}
LOCK=${NB_LOCK:-/Users/zaryabahmed/Desktop/projects/notch-redesign/.land.lock}
[[ -d ${LOCK:h} ]] || LOCK="$COMMON/nb-land.lock"
cmd=${1:-}; shift || true

case $cmd in
start)
  slug=${1:?slug}; WT="${MAIN}-wt-$slug"
  [[ -e $WT ]] && { echo "exists: $WT"; exit 2; }
  if git -C "$MAIN" fetch -q origin 2>/dev/null; then
    if git -C "$MAIN" merge-base --is-ancestor ours origin/ours && ! git -C "$MAIN" merge-base --is-ancestor origin/ours ours; then
      [[ $(git -C "$MAIN" rev-parse --abbrev-ref HEAD) = ours ]] && git -C "$MAIN" merge -q --ff-only origin/ours
    elif ! git -C "$MAIN" merge-base --is-ancestor origin/ours ours; then
      echo "ours and origin/ours diverged; stop and tell the owner"; exit 2
    fi
  else echo "origin unreachable, using local ours"; fi
  git -C "$MAIN" worktree add -q -b "nb/$slug" "$WT" ours || exit 2
  # Incremental swiftc objects use relative paths, so a clone stays warm (test build 29s -> 3s).
  # SwiftPM's .build holds absolute paths and rebuilds anyway, so it is not cloned.
  mkdir -p "$WT/build" && cp -Rc "$MAIN/build/objects" "$WT/build/objects" 2>/dev/null
  # Skills are untracked in main; point builders at $MAIN/.claude/skills by absolute path.
  echo "$WT" ;;
gate)
  base=$(git merge-base ours HEAD)
  files=("${(@f)$( { git diff --name-only "$base"; git ls-files -o --exclude-standard } | sort -u)}")
  files=(${files:#.claude/*})
  swift build 2>&1 | tail -3; [[ ${pipestatus[1]} -eq 0 ]] || { echo "GATE FAIL: swift build"; exit 4; }
  suites=$(python3 - "$MAIN" "${files[@]}" <<'PY'
import re,sys,glob,os
root=sys.argv[1]; files=sys.argv[2:]
src=open(f"{root}/Tests/MetricsTests.swift").read()
cls={}  # class name -> suite
for m in re.finditer(r'\("([\w-]+)",\s*\{(.*?)\}\)\s*,?\s*(?=\(|\])',src,re.S):
    for c in re.findall(r'(\w+)\.run\(suite\)',m.group(2)): cls[c]=m.group(1)
tests={f:open(f).read() for f in glob.glob("Tests/*.swift")}
out=set()
for f in files:
    names={os.path.splitext(os.path.basename(f))[0]}
    if f.endswith(".swift") and os.path.exists(f):
        names|=set(re.findall(r'^\s*(?:public |final |private |fileprivate )*(?:enum|class|struct|actor|extension)\s+(\w+)',open(f).read(),re.M))
    pat=re.compile(r'\b(?:'+'|'.join(map(re.escape,names))+r')\b')
    for t,txt in tests.items():
        if t==f or pat.search(txt):
            seen=set(); todo=re.findall(r'(?:enum|class|struct)\s+(\w+)',txt)
            while todo:  # walk up through aggregator suites (a test run from another test file)
                c=todo.pop()
                if c in seen: continue
                seen.add(c)
                if c in cls: out.add(cls[c])
                todo+=[d for u,ut in tests.items() if re.search(r'\b'+c+r'\.run\(',ut) for d in re.findall(r'(?:enum|class|struct)\s+(\w+)',ut)]
print(" ".join(sorted(out)))
PY
)
  if [[ -n $suites ]]; then
    args=(); for s in ${=suites}; do args+=("--test-suite=$s"); done
    ./build.sh "${args[@]}" 2>&1 | grep -E 'OK|FAIL|error|✗' | tail -15; [[ ${pipestatus[1]} -eq 0 ]] || { echo "GATE FAIL: tests ($suites)"; exit 4; }
  else echo "no test suite maps to the changed files"; fi
  if git diff -U0 "$base" -- . ':!.claude' | grep -E '^\+' | grep -nE $'\xe2\x80\x94|\xe2\x80\x93'; then echo "GATE FAIL: em or en dash in added lines"; exit 4; fi
  echo "GATE OK (suites: ${suites:-none})" ;;
land)
  after=""; [[ ${1:-} = --after ]] && after=${2:?slug}
  WT=$PWD; br=$(git rev-parse --abbrev-ref HEAD); [[ $WT = ${MAIN}-wt-* ]] || { echo "run from the worktree"; exit 2; }
  if [[ -n $after && ! -e "$COMMON/nb-landed/$after" ]]; then echo "LAND WAIT: $after has not landed. Report READY and stop."; exit 5; fi
  dirty=$(git status --porcelain | grep -vE '^\?\? (\.claude/|out/)$' || true)
  [[ -z $dirty ]] || { echo "uncommitted changes:"; echo "$dirty"; exit 2; }
  NB_NO_PUSH=${NB_NO_PUSH:-} lockf -k "$LOCK" /bin/zsh -c '
    WT=$1 MAIN=$2 COMMON=$3; br=$(git -C $WT rev-parse --abbrev-ref HEAD)
    [[ $(git -C $MAIN rev-parse --abbrev-ref HEAD) = ours ]] || { echo "main checkout not on ours"; exit 2; }
    [[ -z $(git -C $MAIN status --porcelain --untracked-files=no) ]] || { echo "main checkout has tracked changes; tell the lead"; exit 2; }
    if ! git -C $WT merge-base --is-ancestor ours HEAD; then
      git -C $WT rebase ours >/dev/null 2>&1 || { git -C $WT rebase --abort; echo "LAND CONFLICT: git -C $WT rebase ours, fix, swift build, rerun land"; exit 3; }
      (cd $WT && swift build 2>&1 | tail -3; [[ ${pipestatus[1]} -eq 0 ]]) || { echo "LAND FAIL: build after rebase"; exit 4; }
    fi
    git -C $MAIN merge --no-ff -q -m "Merge $br into ours" $br || { git -C $MAIN merge --abort; echo "LAND CONFLICT: merge"; exit 3; }
    [[ -n $NB_NO_PUSH ]] || { git -C $MAIN push origin ours 2>&1 | tail -2; [[ ${pipestatus[1]} -eq 0 ]]; } || { echo "LAND FAIL: push refused (merged locally), never force"; exit 4; }
    mkdir -p $COMMON/nb-landed; touch $COMMON/nb-landed/${br#nb/}; echo "LANDED $br at $(git -C $MAIN rev-parse --short ours)"
  ' _ "$WT" "$MAIN" "$COMMON"; rc=$?
  [[ $rc -eq 0 ]] || exit $rc
  cd "$MAIN" && git worktree remove --force "$WT" && git worktree prune && git branch -d "$br" -q 2>/dev/null; echo "worktree removed" ;;
install)
  cd "$MAIN"; d=$(date +%Y-%m-%d)
  [[ -d /Applications/Vorssaint.app ]] && cp -Rc /Applications/Vorssaint.app ~/Desktop/projects/Legacy-notch/Vorssaint-before-$d.app
  ./build.sh --install 2>&1 | tail -4   # build.sh quits the running app itself
  open -a Vorssaint; sleep 3; echo "processes: $(pgrep -x Vorssaint | wc -l | tr -d ' ') (want 1)" ;;
*) sed -n 2,8p "$0"; exit 2 ;;
esac

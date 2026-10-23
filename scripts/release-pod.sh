#!/usr/bin/env bash
# 发布 Flip-BLE 到 CocoaPods trunk。
#
# 版本只读根目录 Flip-BLE.podspec 的 s.version。先把这个版本提交，再运行本脚本。
# 脚本会：检查 trunk 登录、本地 lint、打不带 v 的 annotated tag、推送当前分支和 tag、
# trunk push。成功后把 podspec 复制到 Flip-BLE/<version>/，该目录只是存档，trunk 不读它。
#
# 用法：
#   scripts/release-pod.sh              发布 podspec 里的版本
#   scripts/release-pod.sh --lint-only  只做本地 pod lib lint
#   scripts/release-pod.sh --yes        跳过发布前确认

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PODSPEC="Flip-BLE.podspec"
LINT_ONLY=0
YES=0

for arg in "$@"; do
  case "$arg" in
    --lint-only) LINT_ONLY=1 ;;
    --yes) YES=1 ;;
    -h|--help)
      sed -n '2,12p' "$0"
      exit 0
      ;;
    *)
      echo "未知参数：${arg}。可用 --lint-only、--yes。" >&2
      exit 1
      ;;
  esac
done

pod_field() {
  local key="$1"
  sed -n "s/^[[:space:]]*s\.${key}[[:space:]]*=[[:space:]]*['\"]\\([^'\"]*\\)['\"].*/\\1/p" "$PODSPEC" | head -n 1
}

require_clean_tree() {
  local dirty
  # The archive and this script are not what trunk builds. Trunk reads the tagged root podspec.
  dirty="$(git status --porcelain --untracked-files=all | grep -Ev '^\?\? Flip-BLE/[0-9]+\.[0-9]+\.[0-9]+/|^.. scripts/release-pod\.sh$' || true)"
  if [[ -n "$dirty" ]]; then
    echo "工作区还有未提交的改动。trunk 会按 git tag 取源码，tag 必须和根目录 podspec 是同一次提交。" >&2
    echo "先提交 s.version，再运行本脚本。" >&2
    printf '%s\n' "$dirty" >&2
    exit 1
  fi
}

resolve_pod() {
  local pod_bin
  # pod --version does not load ffi. trunk push updates the CDN through typhoeus,
  # and this machine's ffi 1.15.5 bundle is x86_64-only. Choose the architecture
  # from ffi alone; do not let a pod --version failure hide a working interpreter.
  pod_bin="$(command -v pod || true)"
  if [[ -z "$pod_bin" ]]; then
    echo "找不到 pod 可执行文件。" >&2
    exit 1
  fi
  if /usr/bin/ruby -e 'require "ffi"' >/dev/null 2>&1; then
    POD=("$pod_bin")
    return
  fi
  if /usr/bin/arch -x86_64 /usr/bin/ruby -e 'require "ffi"' >/dev/null 2>&1; then
    echo "当前系统 Ruby 的 ffi 只能在 x86_64 下加载，后续 pod 命令会加上 arch -x86_64。"
    POD=(/usr/bin/arch -x86_64 "$pod_bin")
    return
  fi
  echo "系统 Ruby 无法加载 ffi。不要运行 gem pristine ffi。" >&2
  /usr/bin/arch -x86_64 /usr/bin/ruby -e 'require "ffi"' >&2 || true
  exit 1
}

confirm() {
  local prompt="$1"
  if [[ "$YES" -eq 1 ]]; then
    return 0
  fi
  if [[ ! -t 0 ]]; then
    echo "当前不是交互终端。确认发布请加上 --yes。" >&2
    exit 1
  fi
  local answer
  read -r -p "$prompt [y/N] " answer
  [[ "$answer" == "y" || "$answer" == "Y" ]]
}

tag_commit() {
  local name="$1"
  if git rev-parse -q --verify "refs/tags/${name}" >/dev/null; then
    git rev-parse "${name}^{commit}"
  fi
}

remote_tag_commit() {
  local name="$1"
  local lines peeled plain object
  # refs/tags/name alone does not include refs/tags/name^{}. An annotated tag then
  # looks like a different commit, and the script stops before trunk push.
  lines="$(git ls-remote origin "refs/tags/${name}" "refs/tags/${name}^{}")"
  [[ -n "$lines" ]] || return 0
  peeled="$(printf '%s\n' "$lines" | awk '/\^\{\}$/ { print $1; exit }')"
  if [[ -n "$peeled" ]]; then
    printf '%s\n' "$peeled"
    return
  fi
  plain="$(printf '%s\n' "$lines" | awk 'NR == 1 { print $1 }')"
  if git rev-parse -q --verify "refs/tags/${name}" >/dev/null; then
    object="$(git rev-parse "refs/tags/${name}")"
    if [[ "$plain" == "$object" ]]; then
      git rev-parse "${name}^{commit}"
      return
    fi
  fi
  printf '%s\n' "$plain"
}

version_on_cdn() {
  local version="$1"
  local shard url body
  shard="$(md5 -q -s "Flip-BLE")"
  url="https://cdn.cocoapods.org/Specs/${shard:0:1}/${shard:1:1}/${shard:2:1}/Flip-BLE/${version}/Flip-BLE.podspec.json"
  # cdn.cocoapods.org returns 301 for every path, including versions that do not exist.
  # Follow it and require the spec JSON itself.
  body="$(curl -fsSL -A "CocoaPods" "$url" 2>/dev/null)" || return 1
  printf '%s' "$body" | grep -F -q "\"version\": \"${version}\""
}

write_archive() {
  local version="$1"
  local archive="Flip-BLE/${version}/Flip-BLE.podspec"
  if [[ -f "$archive" ]]; then
    echo "存档已存在：${archive}"
    return
  fi
  mkdir -p "Flip-BLE/${version}"
  cp "$PODSPEC" "$archive"
  echo "已复制存档到 ${archive}。trunk 不读这个目录，需要的话再单独提交："
  echo "  git add $archive"
  echo "  git commit -m \"[Update] Flip-BLE (${version})\""
}

require_clean_tree

VERSION="$(pod_field version)"
DEPLOYMENT="$(pod_field ios.deployment_target)"
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "根目录 podspec 的 s.version 不是 x.y.z：$VERSION" >&2
  exit 1
fi
if [[ -z "$DEPLOYMENT" ]]; then
  echo "根目录 podspec 没有 s.ios.deployment_target。" >&2
  exit 1
fi

HEAD="$(git rev-parse --short HEAD)"
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
echo "准备发布 Flip-BLE ${VERSION}（iOS ${DEPLOYMENT}），分支 ${BRANCH}，提交 ${HEAD}。"
echo "tag 使用 ${VERSION}，不加 v 前缀。"

if version_on_cdn "$VERSION"; then
  echo "CocoaPods CDN 上已经有 Flip-BLE ${VERSION}，不再 trunk push。"
  write_archive "$VERSION"
  exit 0
fi

resolve_pod

echo "检查 CocoaPods trunk 登录..."
if ! "${POD[@]}" trunk me; then
  echo "trunk 会话不可用。先注册，并打开邮件里的确认链接，然后再运行本脚本：" >&2
  echo "  ${POD[*]} trunk register <邮箱> '<名字>' --description='<这台机器>'" >&2
  exit 1
fi

echo "本地校验 podspec..."
"${POD[@]}" lib lint "$PODSPEC" --allow-warnings

if [[ "$LINT_ONLY" -eq 1 ]]; then
  echo "本地 lint 通过。--lint-only 不会打 tag，也不会 trunk push。"
  exit 0
fi

LOCAL_TAG="$(tag_commit "$VERSION" || true)"
if [[ -n "$LOCAL_TAG" && "$LOCAL_TAG" != "$(git rev-parse HEAD)" ]]; then
  echo "本地 tag ${VERSION} 指向 ${LOCAL_TAG}，不是当前提交。不要移动已经发出去的 tag，请改 s.version。" >&2
  exit 1
fi

REMOTE_TAG="$(remote_tag_commit "$VERSION" || true)"
if [[ -n "$REMOTE_TAG" && "$REMOTE_TAG" != "$(git rev-parse HEAD)" ]]; then
  echo "远程 tag ${VERSION} 指向 ${REMOTE_TAG}，不是当前提交。不要覆盖它，请改 s.version。" >&2
  exit 1
fi

if ! confirm "将把 ${VERSION} 推到 origin 并发布到 CocoaPods trunk。继续？"; then
  echo "已取消。"
  exit 1
fi

if [[ -z "$LOCAL_TAG" ]]; then
  git tag -a "$VERSION" -m "$VERSION"
  echo "已创建 annotated tag ${VERSION}。"
else
  echo "本地 tag ${VERSION} 已指向当前提交。"
fi

echo "推送 ${BRANCH} 和 tag ${VERSION}..."
git push origin HEAD
git push origin "refs/tags/${VERSION}"

REMOTE_TAG="$(remote_tag_commit "$VERSION")"
if [[ "$REMOTE_TAG" != "$(git rev-parse HEAD)" ]]; then
  echo "推送后远程 tag ${VERSION} 仍不是当前提交（${REMOTE_TAG:-缺失}）。" >&2
  exit 1
fi

echo "发布到 CocoaPods trunk..."
if ! "${POD[@]}" trunk push "$PODSPEC" --allow-warnings; then
  # A GitHub API timeout can happen after trunk has already accepted the spec.
  published=0
  for _ in 1 2 3 4; do
    if version_on_cdn "$VERSION"; then
      published=1
      break
    fi
    echo "CDN 上暂时还没有 Flip-BLE ${VERSION}，5 秒后再查。"
    sleep 5
  done
  if [[ "$published" -eq 1 ]]; then
    echo "trunk 命令返回了错误，但 CDN 上已经能读到 Flip-BLE ${VERSION}。按已发布处理，不要重复 push。"
  else
    echo "trunk push 失败，CDN 上也还没有 Flip-BLE ${VERSION}。" >&2
    exit 1
  fi
fi

write_archive "$VERSION"
echo "Flip-BLE ${VERSION} 已发布。其他工程执行 pod update Flip-BLE。"

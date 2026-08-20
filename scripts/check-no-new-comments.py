#!/usr/bin/env python3
import argparse
import json
import re
import subprocess
import sys
from collections import Counter

ALLOWED = re.compile(r"^//\s*(swift-tools-version:|swiftlint:|swiftformat:|sourcery:)")
EMPTY_TREE = "4b825dc642cb6eb9a060e54bf8d69288fbee4904"


def run(*args):
    return subprocess.run(args, capture_output=True, text=True)


def comment_tokens(text):
    tokens = []
    line = 1
    index = 0
    state = "code"
    block_depth = 0
    while index < len(text):
        char = text[index]
        pair = text[index:index + 2]
        triple = text[index:index + 3]
        if state == "code":
            if triple == '"""':
                state = "multiline-string"
                index += 3
                continue
            if char == '"':
                state = "string"
                index += 1
                continue
            if pair == "//":
                end = text.find("\n", index)
                if end < 0:
                    end = len(text)
                token = text[index:end].strip()
                if not ALLOWED.match(token):
                    tokens.append((line, token))
                index = end
                continue
            if pair == "/*":
                tokens.append((line, "/*"))
                state = "block-comment"
                block_depth = 1
                index += 2
                continue
        elif state == "string":
            if char == "\\":
                index += 2
                continue
            if char == '"':
                state = "code"
        elif state == "multiline-string":
            if triple == '"""':
                state = "code"
                index += 3
                continue
        elif state == "block-comment":
            if pair == "/*":
                block_depth += 1
                index += 2
                continue
            if pair == "*/":
                block_depth -= 1
                index += 2
                if block_depth == 0:
                    state = "code"
                continue
        if char == "\n":
            line += 1
        index += 1
    return tokens


def added_lines(diff):
    files = {}
    path = None
    current = None
    for raw in diff.splitlines():
        if raw.startswith("+++ b/"):
            path = raw[6:]
            files.setdefault(path, set())
            continue
        if raw.startswith("@@"):
            match = re.search(r"\+(\d+)(?:,(\d+))?", raw)
            current = int(match.group(1)) if match else None
            continue
        if path is None or current is None:
            continue
        if raw.startswith("+") and not raw.startswith("+++"):
            files[path].add(current)
            current += 1
        elif raw.startswith("-") and not raw.startswith("---"):
            continue
        else:
            current += 1
    return files


def default_base():
    remote = run("git", "symbolic-ref", "--quiet", "--short", "refs/remotes/origin/HEAD")
    candidates = []
    if remote.returncode == 0 and remote.stdout.strip():
        candidates.append(remote.stdout.strip())
    candidates.extend(("origin/main", "origin/master", "main", "master"))
    for candidate in candidates:
        merge_base = run("git", "merge-base", candidate, "HEAD")
        if merge_base.returncode == 0 and merge_base.stdout.strip():
            return merge_base.stdout.strip()
    return EMPTY_TREE


def content_for(path, staged):
    if staged:
        result = run("git", "show", f":{path}")
        return result.stdout if result.returncode == 0 else ""
    try:
        with open(path, encoding="utf-8") as handle:
            return handle.read()
    except OSError:
        return ""


def git_violations(staged):
    command = ["git", "diff", "--unified=0"]
    if staged:
        command.append("--cached")
    else:
        command.append(default_base())
    command.extend(("--", "*.swift"))
    result = run(*command)
    if result.returncode != 0:
        return []
    violations = []
    for path, lines in added_lines(result.stdout).items():
        for line, token in comment_tokens(content_for(path, staged)):
            if line in lines:
                violations.append((path, line, token))
    return violations


def hook_violations():
    try:
        payload = json.load(sys.stdin)
    except ValueError:
        return []
    if payload.get("tool_name") not in ("Edit", "Write", "MultiEdit"):
        return []
    data = payload.get("tool_input") or {}
    path = data.get("file_path", "")
    if not path.endswith(".swift"):
        return []
    edits = data.get("edits") or [data]
    added = Counter()
    for edit in edits:
        before = Counter(token for _, token in comment_tokens(edit.get("old_string", "")))
        after = Counter(token for _, token in comment_tokens(edit.get("content", edit.get("new_string", ""))))
        added.update(after - before)
    return [(path, 0, token) for token in added.elements()]


def selftest():
    assert comment_tokens('let url = "https://example.com"\n') == []
    assert comment_tokens("// swiftlint:disable force_try\n") == []
    assert comment_tokens("// swift-tools-version: 6.2\n") == []
    assert comment_tokens("// MARK: - State\n") == [(1, "// MARK: - State")]
    assert comment_tokens("let value = 1 // explanation\n") == [(1, "// explanation")]
    assert comment_tokens("/* explanation */\n") == [(1, "/*")]
    assert comment_tokens('let text = """\nhttps://example.com\n"""\n') == []
    sample = "@@ -1,1 +1,2 @@\n let a = 1\n+// explanation"
    assert added_lines("+++ b/File.swift\n" + sample) == {"File.swift": {2}}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--staged", action="store_true")
    parser.add_argument("--hook", action="store_true")
    parser.add_argument("--selftest", action="store_true")
    args = parser.parse_args()
    if args.selftest:
        selftest()
        print("Comment checker self-test passed.")
        return 0
    violations = hook_violations() if args.hook else git_violations(args.staged)
    if not violations:
        return 0
    print("New explanatory code comments are not allowed:", file=sys.stderr)
    for path, line, token in violations[:10]:
        location = f"{path}:{line}" if line else path
        print(f"  {location}: {token}", file=sys.stderr)
    if len(violations) > 10:
        print(f"  {len(violations) - 10} more", file=sys.stderr)
    print("Use names, constants, tests, or a concise Engineering Learnings PR section instead.", file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())

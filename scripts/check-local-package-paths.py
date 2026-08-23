#!/usr/bin/env python3
import re
import subprocess
import sys

YAML_PATH = re.compile(r"^\s*path:\s*(\S+)\s*$")
SWIFT_PATH = re.compile(r"\.package\s*\(\s*path:\s*\"([^\"]+)\"")


def run(*args):
    return subprocess.run(args, capture_output=True, text=True)


def default_branch():
    head = run("git", "symbolic-ref", "--quiet", "--short", "refs/remotes/origin/HEAD")
    if head.returncode == 0 and head.stdout.strip():
        return head.stdout.strip().removeprefix("origin/")
    configured = run("git", "config", "--get", "init.defaultBranch")
    if configured.returncode == 0 and configured.stdout.strip():
        return configured.stdout.strip()
    for candidate in ("main", "master"):
        if run("git", "show-ref", "--verify", "--quiet", f"refs/heads/{candidate}").returncode == 0:
            return candidate
    return None


def current_branch():
    result = run("git", "symbolic-ref", "--quiet", "--short", "HEAD")
    return result.stdout.strip() if result.returncode == 0 else ""


def tracked(*patterns):
    result = run("git", "ls-files", "--", *patterns)
    return [line for line in result.stdout.splitlines() if line]


def escapes_repository(path):
    return path.startswith("../") or path.startswith("/")


def findings():
    found = []
    for path in tracked("project.yml", "*/project.yml"):
        for number, line in enumerate(open(path, encoding="utf-8"), start=1):
            match = YAML_PATH.match(line)
            if match and escapes_repository(match.group(1)):
                found.append((path, number, match.group(1)))
    for path in tracked("Package.swift", "*/Package.swift"):
        text = open(path, encoding="utf-8").read()
        for match in SWIFT_PATH.finditer(text):
            if escapes_repository(match.group(1)):
                number = text.count("\n", 0, match.start()) + 1
                found.append((path, number, match.group(1)))
    return found


def main():
    found = findings()
    if not found:
        return 0
    listing = "\n".join(f"  {path}:{number} -> {target}" for path, number, target in found)
    if current_branch() != default_branch():
        print("Local package path overrides present; revert them before this branch merges:")
        print(listing)
        return 0
    print("Local package path overrides are on the default branch:", file=sys.stderr)
    print(listing, file=sys.stderr)
    print("A fresh clone cannot resolve these. Point the dependency at its remote and", file=sys.stderr)
    print("pin the revision in Package.resolved.", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())

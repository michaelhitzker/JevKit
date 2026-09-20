#!/usr/bin/env python3
"""Generate release history from stable version tags and commit subjects."""
import argparse
from datetime import datetime, timezone
from pathlib import Path
import re
import subprocess


VERSION = re.compile(r"(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)")


def git(*args):
    return subprocess.check_output(["git", *args], text=True).strip()


def generate(version):
    if not VERSION.fullmatch(version):
        raise ValueError("Use a stable major.minor.patch version without a v prefix.")
    tags = [tag for tag in git("tag", "--merged", "HEAD").splitlines()
            if VERSION.fullmatch(tag)]
    key = lambda value: tuple(map(int, value.split(".")))
    tags.sort(key=key)
    if version in git("tag", "--list").splitlines():
        raise ValueError("This version tag already exists.")
    if tags and key(version) <= key(tags[-1]):
        raise ValueError("The version must be newer than the previous release.")
    sections = []
    previous = None
    for tag in tags + [version]:
        ref = "HEAD" if tag == version else tag
        if previous:
            subprocess.run(["git", "merge-base", "--is-ancestor", previous, ref], check=True)
        date = (datetime.now(timezone.utc).date().isoformat() if tag == version
                else git("log", "-1", "--format=%cs", tag))
        revision = f"{previous}..{ref}" if previous else ref
        commits = git("log", "--reverse", "--no-merges", "--format=%s%x09%h", revision)
        entries = []
        for line in commits.splitlines():
            subject, sha = line.rsplit("\t", 1)
            # Release bookkeeping is not a product change.
            if subject.startswith("chore(release): "):
                continue
            subject = re.sub(r"([\\`*_{}\[\]<>])", r"\\\1", subject)
            entries.append(f"- {subject} (`{sha}`)")
        sections.append(f"## {tag} — {date}\n\n" + "\n".join(entries or ["- No changes."]))
        previous = tag
    return "# Changelog\n\n" + "\n\n".join(reversed(sections)) + "\n", sections[-1] + "\n"


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("version")
    parser.add_argument("--notes", type=Path, required=True)
    args = parser.parse_args()
    try:
        changelog, notes = generate(args.version)
    except (ValueError, subprocess.CalledProcessError) as error:
        parser.exit(1, f"{error}\n")
    Path("CHANGELOG.md").write_text(changelog)
    args.notes.write_text(notes)

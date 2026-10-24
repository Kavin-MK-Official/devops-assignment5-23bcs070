#!/usr/bin/env bash
# Screen 09: source control state - the repository Jenkins checks out.
set -uo pipefail
cd "$HOME/devops-assignment5"

echo "Repository and remote:"
git remote -v | sed 's#https://[^@]*@#https://#; s#//[^/]*@#//#'
echo
echo "Recent commits:"
git log --oneline -4
echo
echo "Working tree:"
git status -sb
echo
echo "Files in the last commit:"
git show --stat --oneline HEAD | head -14

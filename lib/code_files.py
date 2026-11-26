import functools
import os

from git import git_root


def is_test(path):
    folders = os.path.normpath(path).split(os.sep)[:-1]
    return any(folder == "test" or folder == "snapshots" or folder.endswith(("Test", "Tests")) for folder in folders)


@functools.cache
def root_of(folder):
    return git_root(folder)


def is_tooling(path):
    real = os.path.realpath(path)
    root = root_of(os.path.dirname(real))
    return bool(root) and os.path.relpath(real, os.path.realpath(root)).split(os.sep)[0] == ".claude"

"""Shared loading utilities for tests of standalone helper scripts."""
import importlib.util
import os
import sys


SCRIPT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "scripts"))
FIXTURES_DIR = os.path.join(os.path.dirname(__file__), "fixtures")

if SCRIPT_DIR not in sys.path:
    sys.path.insert(0, SCRIPT_DIR)


def import_script(module_name, filename):
    path = os.path.join(SCRIPT_DIR, filename)
    spec = importlib.util.spec_from_file_location(module_name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def read_fixture(filename):
    with open(os.path.join(FIXTURES_DIR, filename), encoding="utf-8") as fixture:
        return fixture.read()

#!/bin/sh
./venv/bin/isort .
./venv/bin/black .
./venv/bin/ruff check .
# MYPYPATH=src ./venv/bin/mypy --explicit-package-bases .

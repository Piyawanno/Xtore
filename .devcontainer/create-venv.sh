#!/bin/bash

for arg in "$@"; do
    mkdir "$arg"
	python -m venv ./$arg/
	# activate the virtual environment
	# shellcheck source=/dev/null
	source ./$arg/bin/activate
	pip install --upgrade pip
	pip install -r requirements.txt
	python XtoreSetup.py link
	deactivate
done

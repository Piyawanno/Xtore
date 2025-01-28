#!/bin/bash

xargs sudo apt-get install -y < requirements-ubuntu.txt
mkdir venv
python -m venv ./venv/
# activate the virtual environment
# shellcheck source=/dev/null
source ./venv/bin/activate
pip install -r requirements.txt
python setup.py build
python XtoreSetup.py link
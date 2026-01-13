#!/usr/bin/env bash

set -ex

gcc -O$1 -Q --help=optimizers

#!/usr/bin/env bash
set -ex

gcc -x c -dM -E - < /dev/null

gcc -undef -dM -E - < /dev/null

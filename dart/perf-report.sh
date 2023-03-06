#!/bin/bash

sudo perf script | ~/development/FlameGraph/stackcollapse-perf.pl > out.perf-folded
sudo ~/development/FlameGraph/flamegraph.pl out.perf-folded > perf.svg
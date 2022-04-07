#!/usr/bin/env python3
#
# Get benchmarks results from one benchmark
#
# USAGE: ./show-results results/a100/lud 32

import textwrap
import json
import sys
import numpy as np
import re
from collections import OrderedDict

def canonical_name(name):
    try:
        return str(max(list(map(int, re.findall(r'\d+', name)))))
    except:
        return list(filter(lambda x: x, name.split("/")))[-1]

if __name__ == '__main__':
    _, bench = sys.argv

    bits = '32'

    reference = None
    try:
        with open(bench + '/reference/results.json') as f:
            reference = json.load(f)
    except FileNotFoundError:
        pass


    with open(bench + '/futhark/plain.json') as f:
        plain_json = json.load(f)

    with open(bench + '/futhark/optimized.json') as f:
        optimized_json = json.load(f)

    name = list(filter(lambda x: x, bench.split("/")))[-1]

    print("""
\\begin{{table}}[!t]
  \\renewcommand{{\\arraystretch}}{{1.3}}
  \\caption{{{name} Performance ({num} runs)}}
  \\label{{tab:{name}-performance-32}}
  \\centering
  \\begin{{tabular}}{{c||c||c||c||c||c}}
    \\hline
    \\bfseries Dataset & \\bfseries Reference & \\bfseries \\thead{{Unopt. \\\\ Futhark}} & \\bfseries \\thead{{Opt. \\\\ Futhark}} & \\bfseries \\thead{{Opt. \\\\ Impact}} & \\bfseries \\thead{{Mem. \\\\ Red. }} \\\\
    \\hline\\hline
""".format(name = name,
           num = len(list(plain_json.values())[0]["runtimes"])))

    for dataset, results in plain_json.items():
        pretty_name = canonical_name(dataset)

        ref = np.mean(reference[dataset]["runtimes"])
        print('    %% {name} & {reference_us} & {plain_us} & {optimized_us} & {impact}\\\\\n'
              '    {name} & {reference:d}ms & {plain_speedup:.2f}x & {optimized_speedup:.2f}x & {impact:.2f}x & {mem:.0f}\\% \\\\'
              .format(name = pretty_name,
                      reference = int(round(ref / 1000)),
                      reference_us = ref,
                      plain = int(round(np.mean(results["runtimes"]) / 1000)),
                      plain_us = np.mean(results["runtimes"]),
                      plain_speedup = ref / np.mean(results["runtimes"]),
                      optimized = int(round(np.mean(optimized_json[dataset]["runtimes"]) / 1000)),
                      optimized_us = np.mean(optimized_json[dataset]["runtimes"]),
                      optimized_speedup = ref / np.mean(optimized_json[dataset]["runtimes"]),
                      impact = np.mean(results["runtimes"]) / np.mean(optimized_json[dataset]["runtimes"]),
                      mem = (1 - optimized_json[dataset]["bytes"] / results["bytes"]) * 100))

    print("""
    \\hline
  \\end{tabular}
\\end{table}
""")

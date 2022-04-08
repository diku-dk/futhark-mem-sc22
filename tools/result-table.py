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
        return list((list(filter(lambda x: x, name.split("/")))[-1]).split("."))[0]

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

    print("\n{name} Performace ({num} runs)\n"
          .format(name = name,
                  num = len(list(plain_json.values())[0]["runtimes"])))
    print(" Dataset  | Reference | Unopt. Futhark | Opt. Futhark | Opt. Impact")
    print("----------+-----------+----------------+--------------+------------")

    for dataset, results in plain_json.items():
        pretty_name = canonical_name(dataset)

        ref = np.mean(reference[dataset]["runtimes"])
        print(' {name:<8} | {reference:>7d}ms | {plain_speedup:>13.2f}x | {optimized_speedup:>11.2f}x | {impact:>10.2f}x'
              .format(name = pretty_name,
                      reference = int(round(ref / 1000)),
                      plain_speedup = ref / np.mean(results["runtimes"]),
                      optimized_speedup = ref / np.mean(optimized_json[dataset]["runtimes"]),
                      impact = np.mean(results["runtimes"]) / np.mean(optimized_json[dataset]["runtimes"])))

    print("")

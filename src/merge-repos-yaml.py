# SPDX-License-Identifier: Apache-2.0

import hiyapyco
import sys

overlay = sys.argv[1]
destination = sys.argv[2]

repos = hiyapyco.load(destination, overlay, method=hiyapyco.METHOD_MERGE)
with open(destination, "w+") as fp:
    fp.write(hiyapyco.dump(repos, default_flow_style=False))

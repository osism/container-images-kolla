# SPDX-License-Identifier: Apache-2.0

"""Fail an image build on a dependency conflict *inside* the kolla venv.

Unlike everything else in ``src/``, this script runs **inside the image**
during the build, not on the build host. It is copied into the base image
by ``{% block base_header %}`` and invoked from the global footer RUN with
the venv's own interpreter, so that ``sys.prefix`` is the venv and
``importlib.metadata`` sees exactly what the venv sees::

    /var/lib/kolla/venv/bin/python3 /usr/local/bin/kolla-pip-check.py

Why it exists
-------------
kolla builds its venv with ``python3 -m venv --system-site-packages``, so
``pip check`` judges apt-installed ``python3-*`` distributions together
with the venv's own. The two are not equally interesting:

* A conflict *stated by* an apt package is Ubuntu packaging metadata held
  against a venv it knows nothing about. It has no runtime effect -- apt
  Python runs under the system interpreter and sees the system copies --
  and we cannot fix it without patching the distribution. Ubuntu noble's
  ``python3-deprecated 1.2.14`` caps ``wrapt<2`` while 2026.1's
  upper-constraints pin ``wrapt===2.1.1``; that pairing is permanent, and
  it is not a defect in our image.
* A conflict stated by a venv distribution is real: one build layer
  upgraded a package another layer constrained, which is how the keystone
  image shipped a broken cryptography and timed out every deploy lane.

``pip check`` cannot tell them apart. This wrapper can, using the one
field that identifies the speaker: both of pip's diagnostic shapes begin
with the distribution *stating* the requirement.

A name present in both scopes counts as venv-owned, because the venv's
site-packages precedes the system one on ``sys.path`` -- the copy pip
resolved, and therefore the copy that stated the requirement, is ours.

Exit codes
----------
0   no conflict is stated by a venv-owned distribution
1   at least one is; the image is broken, fail the build
2   pip could not be trusted -- it exited unexpectedly, printed something
    this script cannot parse, or contradicted its own exit status. A gate
    that cannot read its input must not report success.
"""

import os
import re
import subprocess
import sys
from importlib.metadata import distributions

CLEAN = "No broken requirements found."

# The two shapes pip check emits, e.g.
#   deprecated 1.2.14 has requirement wrapt<2,>=1.10, but you have wrapt 2.1.1.
#   pygobject 3.42.1 requires pycairo, which is not installed.
CONFLICT = re.compile(
    r"^(?P<dist>\S+) \S+ "
    r"(?:has requirement .+, but you have .+"
    r"|requires \S+, which is not installed)\.?$"
)

EXIT_OK = 0
EXIT_CONFLICT = 1
EXIT_UNTRUSTWORTHY = 2


def canonical(name):
    """Normalise a distribution name the PEP 503 way.

    pip check lowercases what the metadata recorded, so ``Deprecated``
    arrives as ``deprecated``; comparing raw names would miss it.
    """
    return re.sub(r"[-_.]+", "-", name).lower()


def venv_owned_names():
    """Canonical names of the distributions installed *in* the venv.

    Everything under ``sys.prefix`` is the venv's; the system
    ``dist-packages`` visible through --system-site-packages is not.
    """
    prefix = os.path.join(sys.prefix, "")
    owned = set()
    for dist in distributions():
        name = dist.metadata["Name"]
        if not name:
            continue
        if str(dist.locate_file("")).startswith(prefix):
            owned.add(canonical(name))
    return owned


def classify(output, owned):
    """Split pip check's stdout into (venv conflicts, other, unparsed)."""
    ours, theirs, unparsed = [], [], []
    for line in output.splitlines():
        line = line.strip()
        if not line or line == CLEAN:
            continue
        match = CONFLICT.match(line)
        if not match:
            unparsed.append(line)
        elif canonical(match.group("dist")) in owned:
            ours.append(line)
        else:
            theirs.append(line)
    return ours, theirs, unparsed


def run_pip_check():
    """Return (returncode, stdout, stderr) of ``pip check`` in this venv."""
    return subprocess.run(
        [sys.executable, "-m", "pip", "check"],
        capture_output=True,
        text=True,
    )


def note(message):
    """Every line this gate prints is prefixed, so it stands out in a
    build log that is otherwise pip and apt chatter."""
    sys.stderr.write("kolla-pip-check: %s\n" % message)


def fail(message):
    note(message)
    return EXIT_UNTRUSTWORTHY


def main():
    if sys.prefix == sys.base_prefix:
        return fail(
            "not running inside a virtualenv (sys.prefix is %s); every "
            "distribution would look venv-owned" % sys.prefix
        )

    proc = run_pip_check()
    if proc.stderr.strip():
        sys.stderr.write(proc.stderr)

    # pip check exits 0 with no conflicts and 1 with conflicts. Any other
    # status means pip failed rather than reached a verdict.
    if proc.returncode not in (EXIT_OK, EXIT_CONFLICT):
        return fail("pip check unexpected exit status %d" % proc.returncode)

    ours, theirs, unparsed = classify(proc.stdout, venv_owned_names())

    if unparsed:
        for line in unparsed:
            note("unrecognised pip check output: %s" % line)
        return fail("refusing to pass on unrecognised pip check output")

    # pip's verdict and what we parsed must agree, or we misread it.
    found = len(ours) + len(theirs)
    if (proc.returncode == EXIT_CONFLICT) != bool(found):
        return fail(
            "inconsistent pip check result: exit status %d with %d "
            "conflict(s) parsed" % (proc.returncode, found)
        )

    for line in theirs:
        note("ignored (not venv-owned): %s" % line)
    for line in ours:
        note("venv-owned conflict: %s" % line)

    return EXIT_CONFLICT if ours else EXIT_OK


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""Build settings/database/us_states.dat for the decode list State column.

Reads the FCC ULS amateur licence dump (l_amat.zip from
https://data.fcc.gov/download/pub/uls/complete/l_amat.zip) and writes one
"CALL ST" line per active licence, using the licensee's mailing-address
state. Re-run every few months to pick up new and changed calls.

Usage: fcc_us_states.py l_amat.zip us_states.dat
"""
import io
import sys
import zipfile


def rows(zf, name):
    with zf.open(name) as f:
        for line in io.TextIOWrapper(f, encoding="latin-1", newline=""):
            yield line.rstrip("\r\n").split("|")


def main(src, dst):
    with zipfile.ZipFile(src) as zf:
        active = {r[1] for r in rows(zf, "HD.dat") if len(r) > 5 and r[5] == "A"}
        states = {}
        for r in rows(zf, "EN.dat"):
            if len(r) > 17 and r[1] in active and r[4] and len(r[17]) == 2:
                states[r[4].upper()] = r[17].upper()
    with open(dst, "w", encoding="ascii", newline="\n") as out:
        for call in sorted(states):
            out.write(f"{call} {states[call]}\n")
    print(f"{len(states)} active calls written to {dst}")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2])

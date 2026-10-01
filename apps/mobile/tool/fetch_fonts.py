"""Downloads the static TTFs the app bundles (SIL OFL 1.1).

Run from apps/mobile:  python tool/fetch_fonts.py
"""
import pathlib
import re
import urllib.request

CSS_URL = (
    "https://fonts.googleapis.com/css2"
    "?family=Readex+Pro:wght@300;400;500;600;700"
    "&family=Aref+Ruqaa:wght@400;700"
)
LICENSES = {
    "ReadexPro": "https://raw.githubusercontent.com/google/fonts/main/ofl/readexpro/OFL.txt",
    "ArefRuqaa": "https://raw.githubusercontent.com/google/fonts/main/ofl/arefruqaa/OFL.txt",
}
EXPECTED = {("ReadexPro", w) for w in ("300", "400", "500", "600", "700")} | {
    ("ArefRuqaa", w) for w in ("400", "700")
}


def get(url: str) -> bytes:
    # urllib's default user agent gets whole TTF files from Google Fonts
    # (browsers get unicode-range woff2 subsets instead).
    with urllib.request.urlopen(url, timeout=60) as response:
        return response.read()


def main() -> None:
    out = pathlib.Path("assets/fonts")
    out.mkdir(parents=True, exist_ok=True)
    css = get(CSS_URL).decode("utf-8")
    seen = set()
    for block in re.findall(r"@font-face\s*\{[^}]+\}", css):
        family = re.search(r"font-family:\s*'([^']+)'", block).group(1).replace(" ", "")
        weight = re.search(r"font-weight:\s*(\d+)", block).group(1)
        url = re.search(r"url\((https://[^)]+)\)", block).group(1)
        key = (family, weight)
        if key in seen:
            raise SystemExit(
                f"Google returned subset files for {key}; download the static "
                "TTFs manually from fonts.google.com instead."
            )
        seen.add(key)
        data = get(url)
        if data[:4] not in (b"\x00\x01\x00\x00", b"true"):
            raise SystemExit(f"{key} is not a TrueType file (got {data[:4]!r}).")
        (out / f"{family}-{weight}.ttf").write_bytes(data)
        print(f"{family}-{weight}.ttf  {len(data) // 1024} KB")
    if seen != EXPECTED:
        raise SystemExit(f"Missing fonts: {sorted(EXPECTED - seen)}")
    for family, url in LICENSES.items():
        (out / f"OFL-{family}.txt").write_bytes(get(url))
    print("Licenses saved.")


if __name__ == "__main__":
    main()

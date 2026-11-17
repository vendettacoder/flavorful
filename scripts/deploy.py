"""Build and deploy the web app and API from one clean Git commit."""

import argparse
import io
from pathlib import Path
import subprocess
import tarfile
import tempfile
import tomllib

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--flutter", default="~/development/flutter/bin/flutter")
    args = parser.parse_args()
    if subprocess.check_output(
        ["git", "status", "--porcelain"], cwd=ROOT, text=True
    ).strip():
        parser.error("Commit local changes before deploying.")
    commit = subprocess.check_output(
        ["git", "rev-parse", "HEAD"], cwd=ROOT, text=True
    ).strip()
    archive = subprocess.check_output(
        ["git", "archive", "--format=tar", commit], cwd=ROOT
    )
    with tempfile.TemporaryDirectory(prefix="flavorful-release-") as temporary:
        release = Path(temporary)
        with tarfile.open(fileobj=io.BytesIO(archive)) as source:
            source.extractall(release, filter="data")
        app = tomllib.loads((release / "fly.toml").read_text())["app"]
        print(f"Building web app and API from commit {commit}.", flush=True)
        subprocess.run(
            [
                str(Path(args.flutter).expanduser()),
                "build",
                "web",
                "--no-web-resources-cdn",
                "--dart-define=FLAVORFUL_ENV=prod",
                f"--dart-define=API_BASE_URL=https://{app}.fly.dev",
                f"--output={release / 'web'}",
            ],
            cwd=release / "flavorful-ios",
            check=True,
        )
        subprocess.run(
            [
                "flyctl",
                "deploy",
                str(release),
                "--app",
                app,
                "--config",
                str(release / "fly.toml"),
                "--remote-only",
                "--ha=false",
                "--update-only",
                "--no-public-ips",
                "--yes",
                "--image-label",
                f"web-api-{commit[:12]}",
                "--label",
                f"org.opencontainers.image.revision={commit}",
            ],
            cwd=release,
            check=True,
        )
        print(f"Deployed {commit} to https://{app}.fly.dev", flush=True)


if __name__ == "__main__":
    main()

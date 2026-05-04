#!/usr/bin/env python3
import json
import subprocess
import sys


def result(image_digest="", lookup_error=""):
    sys.stdout.write(
        json.dumps(
            {
                "image_digest": image_digest,
                "lookup_error": lookup_error,
            }
        )
    )


def main():
    try:
        query = json.load(sys.stdin)
    except Exception as exc:
        result("", f"invalid query: {exc}")
        return

    repository_name = query.get("repository_name")
    region = query.get("region")

    if not repository_name or not region:
        result("", "repository_name and region are required")
        return

    command = [
        "aws",
        "ecr",
        "describe-images",
        "--repository-name",
        repository_name,
        "--region",
        region,
        "--query",
        "reverse(sort_by(imageDetails,& imagePushedAt))[0].imageDigest",
        "--output",
        "text",
    ]

    try:
        completed = subprocess.run(
            command,
            check=True,
            capture_output=True,
            text=True,
        )
    except Exception as exc:
        result("", str(exc))
        return

    digest = completed.stdout.strip()
    if digest in {"", "None", "null"}:
        result("", "repository has no images")
        return

    result(digest, "")


if __name__ == "__main__":
    main()

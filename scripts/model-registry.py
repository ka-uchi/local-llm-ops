#!/usr/bin/env python3
import json
import sys
from pathlib import Path


REGISTRY_PATH = Path(__file__).resolve().parent.parent / "config" / "model-registry.yaml"


def parse_registry(path: Path) -> dict[str, list[dict[str, str]]]:
    data: dict[str, list[dict[str, str]]] = {}
    section = None
    current = None

    for raw_line in path.read_text().splitlines():
        line = raw_line.rstrip()
        stripped = line.strip()

        if not stripped or stripped.startswith("#"):
            continue

        if not raw_line.startswith(" "):
            key = stripped[:-1]
            if stripped.endswith(":"):
                section = key
                data.setdefault(section, [])
                current = None
            continue

        if raw_line.startswith("  - "):
            if section is None:
                continue
            current = {}
            data[section].append(current)
            rest = raw_line[4:].strip()
            if rest and ": " in rest:
                key, value = rest.split(": ", 1)
                current[key] = value.strip().strip('"')
            elif rest.endswith(":"):
                current[rest[:-1]] = ""
            continue

        if raw_line.startswith("    ") and current is not None and ": " in stripped:
            key, value = stripped.split(": ", 1)
            current[key] = value.strip().strip('"')

    return data


def primary_models(data: dict[str, list[dict[str, str]]]) -> list[dict[str, str]]:
    return [item for item in data.get("models", []) if item.get("role") == "primary"]


def all_models(data: dict[str, list[dict[str, str]]]) -> list[dict[str, str]]:
    return data.get("models", []) + data.get("future_models", [])


def main() -> int:
    if len(sys.argv) != 2:
      print("usage: model-registry.py <json-primary|json-all|health-targets|list>", file=sys.stderr)
      return 1

    command = sys.argv[1]
    data = parse_registry(REGISTRY_PATH)

    if command == "json-primary":
        print(json.dumps(primary_models(data), ensure_ascii=False))
        return 0

    if command == "json-all":
        print(json.dumps(all_models(data), ensure_ascii=False))
        return 0

    if command == "health-targets":
        for item in primary_models(data):
            print(f"{item['id']}\t127.0.0.1\t{item['port']}")
        return 0

    if command == "list":
        for item in all_models(data):
            role = item.get("role", "")
            port = item.get("port", "")
            env_file = item.get("env_file", "-")
            print(f"{item['id']}\t{role}\t{port}\t{env_file}")
        return 0

    print(f"unknown command: {command}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())

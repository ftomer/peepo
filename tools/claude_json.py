"""Ask the local Claude Code CLI a question about images and get JSON back.

The pipeline needs a pair of eyes on the artwork: what room is this, what is
each sprite, where can a prop plausibly sit. That is a vision call, and the
`claude` CLI already on this machine is the cheapest way to make one - it runs
on the existing subscription, so the pipeline needs no API key of its own.

The CLI is given the Read tool and nothing else, so it can look at the raw art
and at anything in the repo it is pointed to, but every file this pipeline
writes is written here, from validated data.
"""
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# A fresh headless session per call: no history to confuse the next scene, and
# nothing from the user's MCP servers, plugins or settings in the context.
BASE_ARGS = [
    "-p",
    "--output-format", "json",
    "--allowedTools", "Read",
    "--permission-mode", "acceptEdits",
    "--strict-mcp-config",
    "--mcp-config", '{"mcpServers":{}}',
    "--disable-slash-commands",
    "--no-session-persistence",
    "--setting-sources", "",
]

FENCE = re.compile(r"```(?:json)?\s*(.*?)\s*```", re.S)


class VisionError(RuntimeError):
    pass


def _extract(text):
    """Pull the JSON value out of a reply that may be fenced or chatty."""
    fenced = FENCE.search(text)
    if fenced:
        text = fenced.group(1)
    text = text.strip()
    if not text.startswith(("{", "[")):
        start = min(
            (text.find(c) for c in "{[" if text.find(c) != -1),
            default=-1,
        )
        if start == -1:
            raise VisionError(f"no JSON in reply: {text[:200]}")
        text = text[start:]
    return json.loads(text)


def ask_json(prompt, *, model="sonnet", attempts=2, quiet=False):
    """Run one headless Claude call and return the JSON value it replied with.

    A reply that will not parse is retried once with the raw text quoted back,
    which is far more reliable than tightening the prompt further.
    """
    if shutil.which("claude") is None:
        raise VisionError(
            "the `claude` CLI is not on PATH; the pipeline needs it for the "
            "vision steps (see docs/scene-pipeline.md)"
        )

    asked = prompt
    last = None
    for attempt in range(attempts):
        result = subprocess.run(
            ["claude", *BASE_ARGS, "--model", model, asked],
            cwd=ROOT,
            capture_output=True,
            text=True,
        )
        if result.returncode != 0:
            raise VisionError(
                f"claude exited {result.returncode}: {result.stderr[-500:]}"
            )
        try:
            envelope = json.loads(result.stdout)
        except json.JSONDecodeError as error:
            raise VisionError(
                f"claude did not return an envelope: {error}"
            ) from error

        if envelope.get("is_error"):
            raise VisionError(f"claude errored: {envelope.get('result')}")
        if not quiet:
            cost = envelope.get("total_cost_usd", 0)
            seconds = envelope.get("duration_ms", 0) / 1000
            print(f"  [claude {model}: ${cost:.2f}, {seconds:.0f}s]",
                  file=sys.stderr)

        last = envelope.get("result", "")
        try:
            return _extract(last)
        except (VisionError, json.JSONDecodeError) as error:
            if attempt == attempts - 1:
                raise VisionError(f"unparsable reply: {error}") from error
            asked = (
                f"{prompt}\n\nYour previous reply could not be parsed as "
                f"JSON:\n{last[:2000]}\n\nReply again with only the JSON "
                f"value, no prose and no code fence."
            )
    raise VisionError(f"unparsable reply: {last}")

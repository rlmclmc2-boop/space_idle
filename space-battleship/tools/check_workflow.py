#!/usr/bin/env python3
"""Validate a private handoff ledger; never uploads data or executes evidence paths.

Required: agent, state (working/blocked/complete), next, blocker, findings.
Each finding: id, owner, decision (accept/defer/reject), reason, status
(open/blocked/verified), next, evidence. Evidence: [{kind, ref}], where kind is
play/check/source. Accepted findings also declare required evidence kinds.
Optional idle: observable_seconds, avoidable_seconds, basis; unknown is null.
"""
import json
import math
import sys


def validate(data):
    errors = []
    if not isinstance(data, dict):
        return ["ledger must be an object"]
    agent = data.get("agent")
    if not isinstance(agent, str) or not agent.strip():
        errors.append("agent is required")
    state = data.get("state")
    if state not in {"working", "blocked", "complete"}:
        errors.append("invalid state")
    if state == "working" and not data.get("next"):
        errors.append("working handoff needs its next action")
    if state == "blocked" and not data.get("blocker"):
        errors.append("blocked handoff needs a concrete blocker")
    findings = data.get("findings")
    if not isinstance(findings, list):
        return errors + ["findings must be a list, including when empty"]
    ids = set()
    kinds = {"play", "check", "source"}
    for item in findings:
        if not isinstance(item, dict):
            errors.append("finding must be an object")
            continue
        key = item.get("id")
        if not isinstance(key, str) or not key or key in ids:
            errors.append("finding IDs must be unique nonempty strings")
        else:
            ids.add(key)
        if item.get("decision") not in {"accept", "defer", "reject"} or not item.get("reason"):
            errors.append(f"{key}: decision and reason required")
        if not item.get("owner") or item.get("status") not in {"open", "blocked", "verified"}:
            errors.append(f"{key}: owner and valid status required")
        evidence = item.get("evidence", [])
        if not isinstance(evidence, list) or any(not isinstance(e, dict) or not isinstance(e.get("kind"), str) or e["kind"] not in kinds or not e.get("ref") for e in evidence):
            errors.append(f"{key}: evidence must have kind and reference")
            evidence = []
        if item.get("decision") != "accept":
            continue
        required = item.get("required")
        if not isinstance(required, list) or not required or any(not isinstance(k, str) or k not in kinds for k in required):
            errors.append(f"{key}: accepted finding needs acceptance evidence kinds")
            required = []
        if item.get("status") == "verified":
            if not required or not set(required).issubset({e["kind"] for e in evidence}):
                errors.append(f"{key}: claimed closure lacks required evidence")
            if not item.get("prevention") or not isinstance(item.get("recurrence"), bool):
                errors.append(f"{key}: closure needs prevention and observed recurrence status")
        elif not item.get("next"):
            errors.append(f"{key}: unresolved accepted finding needs next action")
        if item.get("owner") == agent and item.get("status") == "open" and state in {"complete", "blocked"}:
            errors.append(f"{key}: actionable owned work prevents declaring {state}")
    idle = data.get("idle")
    if idle is not None:
        if not isinstance(idle, dict) or not idle.get("basis"):
            errors.append("idle observations require a basis")
        else:
            a, b = idle.get("avoidable_seconds"), idle.get("observable_seconds")
            if a is not None and (not isinstance(a, (int, float)) or isinstance(a, bool) or not math.isfinite(a) or a < 0 or not isinstance(b, (int, float)) or isinstance(b, bool) or not math.isfinite(b) or b < a):
                errors.append("avoidable idle must fit the observed window; use null when unknown")
    return errors


def validate_review(data):
    """Require distinct evidenced opinions and disposition; never judge score truth."""
    if not isinstance(data, dict):
        return ["review must be an object"]
    expected = data.get("required_participants")
    opinions = data.get("opinions")
    if not isinstance(expected, list) or not expected or any(not isinstance(x, str) or not x for x in expected):
        return ["required_participants must explicitly name the review participants"]
    if not isinstance(opinions, list):
        return ["opinions must be a list"]
    errors, seen = [], set()
    for opinion in opinions:
        if not isinstance(opinion, dict):
            errors.append("opinion must be an object")
            continue
        name = opinion.get("participant")
        if not isinstance(name, str) or not name or name in seen:
            errors.append("each participant needs one independent opinion record")
            continue
        seen.add(name)
        for field in ("source", "scope", "observations", "owner", "action", "after_change"):
            if not opinion.get(field):
                errors.append(f"{name}: missing {field}; state unverified explicitly where appropriate")
        if opinion.get("decision") not in {"accept", "defer", "reject"} or not opinion.get("decision_reason"):
            errors.append(f"{name}: disposition needs a decision and reason")
    for name in sorted(set(expected)-seen):
        errors.append(f"missing independent opinion: {name}")
    if not isinstance(data.get("previous_low_score_followup"), list) or not data["previous_low_score_followup"]:
        errors.append("review must revisit previous low scores and recurrence")
    return errors


if __name__ == "__main__":
    try:
        with open(sys.argv[1], encoding="utf-8") as source:
            result = (validate_review if "--review" in sys.argv[2:] else validate)(json.load(source))
    except (IndexError, OSError, ValueError) as exc:
        result = [str(exc)]
    print("\n".join(result) if result else "Workflow handoff: complete fields; evidence truth still requires review.")
    sys.exit(bool(result))

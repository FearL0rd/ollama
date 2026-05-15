#!/usr/bin/env python3
"""
Security Scanner Script
Scans codebase for common security vulnerabilities.

Usage:
    python .claude/skills/security-scan/scripts/scan.py [path]

Returns JSON with findings.
"""

import os
import re
import json
import sys
from pathlib import Path
from typing import List, Dict, Any

# Patterns to detect vulnerabilities
VULNERABILITY_PATTERNS = {
    "user_id_from_input": {
        "pattern": r"userId.*req\.(body|params|query)",
        "severity": "CRITICAL",
        "message": "User ID from request input - use session instead",
        "owasp": "A01"
    },
    "password_in_response": {
        "pattern": r"(password|senha).*res\.(json|send)",
        "severity": "CRITICAL",
        "message": "Password may be sent in response",
        "owasp": "A02"
    },
    "weak_hash": {
        "pattern": r"createHash\(['\"]md5['\"]\)|createHash\(['\"]sha1['\"]\)",
        "severity": "HIGH",
        "message": "Weak hashing algorithm - use bcrypt or argon2",
        "owasp": "A02"
    },
    "hardcoded_secret": {
        "pattern": r"(password|secret|api_key)\s*=\s*['\"][^'\"]+['\"]",
        "severity": "HIGH",
        "message": "Hardcoded secret detected",
        "owasp": "A02"
    },
    "no_input_validation": {
        "pattern": r"\.mutation\(\s*async\s*\(\s*\{\s*input\s*\}\s*\)",
        "severity": "MEDIUM",
        "message": "Mutation without .input() validation",
        "owasp": "A03"
    },
    "eval_usage": {
        "pattern": r"\beval\s*\(|new\s+Function\s*\(",
        "severity": "CRITICAL",
        "message": "Dangerous eval() or Function() usage",
        "owasp": "A03"
    },
    "sql_concatenation": {
        "pattern": r"(SELECT|INSERT|UPDATE|DELETE).*\+.*req\.",
        "severity": "CRITICAL",
        "message": "SQL query with string concatenation",
        "owasp": "A03"
    },
    "missing_auth_check": {
        "pattern": r"router\.(get|post|put|delete)\s*\([^,]+,\s*async",
        "severity": "MEDIUM",
        "message": "Route may be missing auth middleware",
        "owasp": "A01"
    },
    "cors_wildcard": {
        "pattern": r"cors\(\s*\{\s*origin:\s*['\"]?\*['\"]?\s*\}",
        "severity": "MEDIUM",
        "message": "CORS with wildcard origin",
        "owasp": "A05"
    },
    "stack_trace_leak": {
        "pattern": r"res\.(json|send)\s*\(\s*\{[^}]*error\.stack",
        "severity": "MEDIUM",
        "message": "Stack trace may be leaked in response",
        "owasp": "A05"
    }
}

# File extensions to scan
SCAN_EXTENSIONS = {'.ts', '.tsx', '.js', '.jsx'}

# Directories to skip
SKIP_DIRS = {
    'node_modules', '.next', 'dist', 'build',
    '.git', '__pycache__', 'coverage'
}


def should_scan_file(path: Path) -> bool:
    """Check if file should be scanned."""
    # Skip directories
    for skip in SKIP_DIRS:
        if skip in path.parts:
            return False

    # Check extension
    return path.suffix in SCAN_EXTENSIONS


def scan_file(file_path: Path) -> List[Dict[str, Any]]:
    """Scan a single file for vulnerabilities."""
    findings = []

    try:
        content = file_path.read_text(encoding='utf-8', errors='ignore')
        lines = content.split('\n')

        for vuln_name, vuln_info in VULNERABILITY_PATTERNS.items():
            pattern = re.compile(vuln_info['pattern'], re.IGNORECASE)

            for line_num, line in enumerate(lines, 1):
                if pattern.search(line):
                    findings.append({
                        "file": str(file_path),
                        "line": line_num,
                        "vulnerability": vuln_name,
                        "severity": vuln_info['severity'],
                        "message": vuln_info['message'],
                        "owasp": vuln_info['owasp'],
                        "code": line.strip()[:100]
                    })
    except Exception as e:
        pass  # Skip unreadable files

    return findings


def scan_directory(path: str) -> Dict[str, Any]:
    """Scan directory for vulnerabilities."""
    root = Path(path)
    all_findings = []
    files_scanned = 0

    for file_path in root.rglob('*'):
        if file_path.is_file() and should_scan_file(file_path):
            files_scanned += 1
            findings = scan_file(file_path)
            all_findings.extend(findings)

    # Group by severity
    by_severity = {
        "CRITICAL": [],
        "HIGH": [],
        "MEDIUM": [],
        "LOW": []
    }

    for finding in all_findings:
        severity = finding['severity']
        if severity in by_severity:
            by_severity[severity].append(finding)

    return {
        "summary": {
            "files_scanned": files_scanned,
            "total_findings": len(all_findings),
            "critical": len(by_severity["CRITICAL"]),
            "high": len(by_severity["HIGH"]),
            "medium": len(by_severity["MEDIUM"]),
            "low": len(by_severity["LOW"])
        },
        "findings": by_severity,
        "status": "FAIL" if by_severity["CRITICAL"] else "PASS"
    }


def main():
    """Main entry point."""
    scan_path = sys.argv[1] if len(sys.argv) > 1 else '.'

    if not os.path.exists(scan_path):
        print(json.dumps({"error": f"Path not found: {scan_path}"}))
        sys.exit(1)

    results = scan_directory(scan_path)
    print(json.dumps(results, indent=2))

    # Exit with error if critical findings
    if results['status'] == 'FAIL':
        sys.exit(1)

    sys.exit(0)


if __name__ == '__main__':
    main()

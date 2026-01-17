#!/bin/bash
set -e

# Trivy Security Check Script
# This script runs Trivy to scan for vulnerabilities in Python dependencies

echo "🔍 Running Trivy security scan on backend dependencies..."
echo ""

# Check if trivy is installed
if ! command -v trivy &> /dev/null; then
    echo "❌ Error: Trivy is not installed."
    echo ""
    echo "To install Trivy, run:"
    echo "  Linux/Mac: curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin"
    echo "  Or visit: https://aquasecurity.github.io/trivy/latest/getting-started/installation/"
    exit 1
fi

# Run trivy scan on backend directory
# --ignore-unfixed=false shows vulnerabilities even without available fixes
trivy fs --scanners vuln --severity HIGH,CRITICAL --ignore-unfixed=false backend/

echo ""
echo "✅ Trivy scan completed!"
echo ""
echo "Note: This scan includes both fixed and unfixed vulnerabilities."
echo "Unfixed vulnerabilities should be documented and monitored for upstream patches."

#!/usr/bin/env bash
#
# oscap_auto_tailor.sh
# Dynamically detects RHEL 9 or RHEL 10, scans the host, and creates an
# OpenSCAP tailoring XML profile containing only rules that passed.
#

set -euo pipefail

# --- CONFIGURATION DEFAULTS ---
# Target base profile template name (e.g., cis, stig, standard)
PROFILE_TYPE="cis" 
TAILORING_OUTPUT_FILE="org_compliance_tailoring.xml"

RESULTS_XML="scan_results_baseline.xml"
REPORT_HTML="scan_report_baseline.html"

# --- CHECK PREREQUISITES ---
if [[ $EUID -ne 0 ]]; then
   echo "[!] Error: OpenSCAP scans require root privileges to query system state." >&2
   exit 1
fi

# Ensure /etc/os-release exists to determine system version
if [[ ! -f /etc/os-release ]]; then
    echo "[!] Error: Cannot determine OS. /etc/os-release file missing." >&2
    exit 1
fi

# Source os-release info
. /etc/os-release

# Determine RHEL Major Version
if [[ "${ID:-}" == "rhel" || "${ID_LIKE:-}" =~ rhel ]]; then
    RHEL_MAJOR_VERSION=$(echo "${VERSION_ID:-}" | cut -d'.' -f1)
else
    echo "[!] Error: Unsupported OS distribution. This script is intended for RHEL systems." >&2
    exit 1
fi

# Set dynamic datastream paths and base profile IDs based on RHEL version
case "$RHEL_MAJOR_VERSION" in
    8)
        DATASTREAM_FILE="/usr/share/xml/scap/ssg/content/ssg-rhel8-ds.xml"
        BASE_PROFILE_ID="xccdf_org.ssgproject.content_profile_${PROFILE_TYPE}"
        TAILORED_PROFILE_ID="xccdf_org.ssgproject.content_profile_${PROFILE_TYPE}_org_rhel8_baseline"
        ;;
    9)
        DATASTREAM_FILE="/usr/share/xml/scap/ssg/content/ssg-rhel9-ds.xml"
        BASE_PROFILE_ID="xccdf_org.ssgproject.content_profile_${PROFILE_TYPE}"
        TAILORED_PROFILE_ID="xccdf_org.ssgproject.content_profile_${PROFILE_TYPE}_org_rhel9_baseline"
        ;;
    10)
        DATASTREAM_FILE="/usr/share/xml/scap/ssg/content/ssg-rhel10-ds.xml"
        BASE_PROFILE_ID="xccdf_org.ssgproject.content_profile_${PROFILE_TYPE}"
        TAILORED_PROFILE_ID="xccdf_org.ssgproject.content_profile_${PROFILE_TYPE}_org_rhel10_baseline"
        ;;
    *)
        echo "[!] Error: Detected RHEL version ${RHEL_MAJOR_VERSION}. Only RHEL 9 and RHEL 10 are supported." >&2
        exit 1
        ;;
esac

echo "[+] Detected OS: RHEL ${RHEL_MAJOR_VERSION}"
echo "[+] Using Datastream: ${DATASTREAM_FILE}"

# --- INSTALL PACKAGES IF MISSING ---
if ! command -v oscap &> /dev/null || [[ ! -f "$DATASTREAM_FILE" ]]; then
    echo "[+] Installing missing OpenSCAP and Security Guide packages..."
    dnf install -y openscap-scanner scap-security-guide openscap-utils
fi

if [[ ! -f "$DATASTREAM_FILE" ]]; then
    echo "[!] Error: SCAP Datastream file not found at $DATASTREAM_FILE even after installing packages." >&2
    exit 1
fi

# --- STEP 1: RUN THE INITIAL SCAN ---
echo "[+] Step 1/3: Running baseline OpenSCAP scan..."
set +e # Allow non-zero exit codes (non-passing rules exit with 2)
oscap xccdf eval \
    --profile "$BASE_PROFILE_ID" \
    --results "$RESULTS_XML" \
    --report "$REPORT_HTML" \
    "$DATASTREAM_FILE"
SCAN_EXIT_CODE=$?
set -e

if [[ $SCAN_EXIT_CODE -ne 0 && $SCAN_EXIT_CODE -ne 2 ]]; then
    echo "[!] OpenSCAP scan failed unexpectedly with exit code $SCAN_EXIT_CODE" >&2
    exit $SCAN_EXIT_CODE
fi

echo "[+] Scan finished. Results written to $RESULTS_XML"

# --- STEP 2: PARSE SCAN RESULTS FOR NON-PASSING RULES ---
echo "[+] Step 2/3: Identifying non-passing rules to exclude..."

UNSELECT_ARGS=()
while IFS= read -r rule_id; do
    if [[ -n "$rule_id" ]]; then
        UNSELECT_ARGS+=("--unselect" "$rule_id")
    fi
done < <(python3 -c "
import xml.etree.ElementTree as ET
tree = ET.parse('$RESULTS_XML')
root = tree.getroot()
ns = {'xccdf': 'http://checklists.nist.gov/xccdf/1.2'}

for rr in root.findall('.//xccdf:rule-result', ns):
    result = rr.find('xccdf:result', ns)
    if result is not None and result.text != 'pass':
        rule_id = rr.get('idref')
        if rule_id:
            print(rule_id)
")

echo "[+] Identified ${#UNSELECT_ARGS[@]} rules to unselect in tailoring."

# --- STEP 3: GENERATE TAILORING FILE ---
echo "[+] Step 3/3: Generating custom Tailoring File..."

if command -v autotailor &> /dev/null; then
    autotailor \
        --tailored-profile-id "$TAILORED_PROFILE_ID" \
        "${UNSELECT_ARGS[@]}" \
        -o "$TAILORING_OUTPUT_FILE" \
        "$DATASTREAM_FILE" \
        "$BASE_PROFILE_ID"
else
    oscap xccdf generate custom \
        --profile "$BASE_PROFILE_ID" \
        --new-profile-id "$TAILORED_PROFILE_ID" \
        --output "$TAILORING_OUTPUT_FILE" \
        "${UNSELECT_ARGS[@]}" \
        "$DATASTREAM_FILE"
fi

echo "--------------------------------------------------------"
echo "[✓] Tailoring file generated: $TAILORING_OUTPUT_FILE"
echo "[✓] Tailored Profile ID: $TAILORED_PROFILE_ID"
echo "--------------------------------------------------------"
echo "To scan other RHEL ${RHEL_MAJOR_VERSION} machines with this tailoring profile, run:"
echo ""
echo "  sudo oscap xccdf eval \\"
echo "    --tailoring-file $TAILORING_OUTPUT_FILE \\"
echo "    --profile $TAILORED_PROFILE_ID \\"
echo "    --report system_report.html \\"
echo "    $DATASTREAM_FILE"
echo "--------------------------------------------------------"

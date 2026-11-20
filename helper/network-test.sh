#!/usr/bin/env bash
#
# network-test.sh — network health + upload/download speed report
#
# Runs from any Unix host/container that has bash + curl (AWS EC2/ECS, Docker,
# Virtuozzo, etc). ping / getent are used when available, with fallbacks.
#
# Tests:
#   1. Environment      host, public IP, ISP/ASN, nearest Cloudflare PoP, AWS region
#   2. Latency          packet loss / RTT / jitter (ICMP, falls back to TCP connect)
#   3. DNS + HTTPS      DNS, TCP connect, TLS and TTFB timings to common endpoints
#   4. Download         plain HTTP download of test files hosted on the Rapyd LOMP
#                       speed-test sites (EW1 / UE1 / UW2): 10–100 MB, 1 GB, parallel
#   5. Upload           small files (10–100 MB) + big file (1 GB) to Cloudflare / S3
#
# Usage:
#   ./network-test.sh                  # full test
#   ./network-test.sh --quick          # skip the 1 GB tests
#   ./network-test.sh --json out.json  # also write JSON results
#   ./network-test.sh --help
#
# Upload target defaults to Cloudflare's public speed-test endpoint. For a more
# realistic AWS test, upload to your own bucket instead:
#   ./network-test.sh --s3-bucket my-bucket          (needs aws cli + creds)
#   ./network-test.sh --upload-url 'https://...'     (any URL accepting PUT, e.g. S3 presigned)

set -u
set -o pipefail

# --------------------------------------------------------------------------
# Defaults (override with flags)
# --------------------------------------------------------------------------
SMALL_SIZES="10M 25M 50M 100M"
BIG_SIZE="1G"
PARALLEL_STREAMS=4
PARALLEL_SIZE="100M"
PING_COUNT=10
SMALL_TIMEOUT=120          # seconds per small transfer
BIG_TIMEOUT=600            # seconds per big transfer
UPLOAD_URL="https://speed.cloudflare.com/__up"
UPLOAD_METHOD="POST"
S3_BUCKET=""
# Download servers: NAME=BASE_URL, serving <size>.bin (10M.bin 25M.bin 50M.bin 100M.bin 1G.bin).
# Files live in /var/www/webroot/ROOT/nettest/ on each node.
ORIGINS="EW1=http://speedtest-ew1.ew1.rapyd.cloud/nettest/ UE1=http://speedtest-ue1.ue1.rapyd.cloud/nettest/ UW2=http://speedtest-uw2.uw2.rapyd.cloud/nettest/"
ORIGINS_CUSTOM=0
JSON_OUT=""
REPORT_OUT=""
QUICK=0
SKIP_UPLOAD=0
SKIP_DOWNLOAD=0
TMP_DIR="${TMPDIR:-/tmp}"
# Cloudflare's upload endpoint rejects ~1 GB bodies, so bigger uploads are sent
# as consecutive 90 MiB chunks over one keep-alive connection (= sustained
# single-connection throughput, which is what a big-file transfer measures).
CHUNK=94371840

PING_TARGETS="1.1.1.1 8.8.8.8"
HTTP_TARGETS="speed.cloudflare.com www.google.com github.com s3.amazonaws.com"

# Health thresholds
WARN_LOSS=1;   FAIL_LOSS=5     # %
WARN_RTT=100;  FAIL_RTT=250    # ms
WARN_JITTER=20                 # ms
WARN_DNS=150;  FAIL_DNS=1000   # ms
WARN_DOWN=50                   # Mbit/s
WARN_UP=20                     # Mbit/s

usage() {
    sed -n '2,25p' "$0" | sed 's/^# \{0,1\}//'
    cat <<EOF

Options:
  --quick                 Skip the big (1 GB) download/upload tests
  --small "10M 50M"       Small file sizes (default: "$SMALL_SIZES"; K/M/G suffixes)
  --big 1G                Big file size (default: $BIG_SIZE)
  --streams N             Parallel download streams of $PARALLEL_SIZE (default: $PARALLEL_STREAMS, 0 = skip)
  --upload-url URL        Upload with HTTP PUT to this URL instead of Cloudflare
  --s3-bucket NAME        Upload to s3://NAME/network-test/ using aws cli (objects removed after)
  --origin NAME=URL       Server to download <size>.bin files from (repeatable; replaces the
                          default EW1/UE1/UW2 Rapyd speed-test sites)
  --no-upload             Skip upload tests
  --no-download           Skip download tests
  --json FILE             Also write results as JSON
  --output FILE           Report file (default: \$TMPDIR/network-report-<host>-<time>.txt)
  --tmp DIR               Where temp upload files are created (default: $TMP_DIR)
  -h, --help              Show this help
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --quick)        QUICK=1 ;;
        --small)        SMALL_SIZES="$2"; shift ;;
        --big)          BIG_SIZE="$2"; shift ;;
        --streams)      PARALLEL_STREAMS="$2"; shift ;;
        --upload-url)   UPLOAD_URL="$2"; UPLOAD_METHOD="PUT"; shift ;;
        --s3-bucket)    S3_BUCKET="$2"; shift ;;
        --origin)       [ $ORIGINS_CUSTOM -eq 0 ] && ORIGINS=""; ORIGINS_CUSTOM=1; ORIGINS="$ORIGINS $2"; shift ;;
        --no-upload)    SKIP_UPLOAD=1 ;;
        --no-download)  SKIP_DOWNLOAD=1 ;;
        --json)         JSON_OUT="$2"; shift ;;
        --output)       REPORT_OUT="$2"; shift ;;
        --tmp)          TMP_DIR="$2"; shift ;;
        -h|--help)      usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; usage; exit 2 ;;
    esac
    shift
done

command -v curl >/dev/null 2>&1 || { echo "curl is required" >&2; exit 1; }
if [ -n "$S3_BUCKET" ] && ! command -v aws >/dev/null 2>&1; then
    echo "--s3-bucket needs the aws cli" >&2; exit 1
fi

HOST=$(hostname 2>/dev/null || echo unknown)
STAMP=$(date +%Y%m%d-%H%M%S)
[ -z "$REPORT_OUT" ] && REPORT_OUT="$TMP_DIR/network-report-$HOST-$STAMP.txt"
WORK_DIR=$(mktemp -d "$TMP_DIR/nettest.XXXXXX") || { echo "cannot create temp dir in $TMP_DIR" >&2; exit 1; }
trap 'rm -rf "$WORK_DIR"' EXIT INT TERM

# --------------------------------------------------------------------------
# Helpers
# --------------------------------------------------------------------------
REPORT=""         # accumulated report text
ISSUES=""         # accumulated warnings / failures
JSON_ITEMS=""     # accumulated JSON objects
WORST=0           # 0 = healthy, 1 = degraded, 2 = unhealthy

out()   { REPORT="$REPORT$*"$'\n'; printf '%s\n' "$*"; }
progress() { printf '  … %s\r' "$*" >&2; }
clearp() { printf '\r%80s\r' '' >&2; }

issue() {   # issue <1|2> <message>
    local lvl=$1; shift
    [ "$lvl" -gt "$WORST" ] && WORST=$lvl
    if [ "$lvl" -eq 2 ]; then ISSUES="$ISSUES  ✖ $*"$'\n'; else ISSUES="$ISSUES  ⚠ $*"$'\n'; fi
}

json_add() { JSON_ITEMS="${JSON_ITEMS:+$JSON_ITEMS,}$1"; }

# float compare: gt a b  -> true if a > b
gt() { awk -v a="$1" -v b="$2" 'BEGIN{exit !(a+0>b+0)}'; }

to_bytes() {   # 10M -> 10485760 (binary units, so "1G" = 1 GiB)
    awk -v s="$1" 'BEGIN{
        n=s+0; u=toupper(substr(s,length(s)));
        if(u=="K")n*=1024; else if(u=="M")n*=1048576; else if(u=="G")n*=1073741824;
        printf "%d", n }'
}

human_size() {
    awk -v b="$1" 'BEGIN{
        if(b>=1073741824) printf "%.1f GB", b/1073741824;
        else if(b>=1048576) printf "%.0f MB", b/1048576;
        else if(b>=1024) printf "%.0f KB", b/1024;
        else printf "%d B", b }'
}

now() {   # wall clock with sub-second precision where possible
    local t; t=$(date +%s.%N 2>/dev/null)
    case "$t" in *N*|"") perl -MTime::HiRes=time -e 'printf "%.3f", time' 2>/dev/null || date +%s ;; *) echo "$t" ;; esac
}

mbps() { awk -v b="$1" 'BEGIN{printf "%.1f", b*8/1000000}'; }   # bytes/s -> Mbit/s
ms()   { awk -v s="$1" 'BEGIN{printf "%.0f", s*1000}'; }          # s -> ms

curl_reason() {   # human-readable reason for common curl exit codes
    case "$1" in
        5)  echo "proxy could not be resolved" ;;
        6)  echo "DNS lookup failed" ;;
        7)  echo "connection refused/blocked (outbound port closed or firewall?)" ;;
        28) echo "timed out" ;;
        35) echo "TLS handshake failed" ;;
        52) echo "server sent empty reply" ;;
        56) echo "connection reset while receiving" ;;
        *)  echo "curl exit $1" ;;
    esac
}

status_for() {   # status_for value warn fail [lower_is_worse]
    local v=$1 w=$2 f=$3 inv=${4:-0}
    if [ "$inv" -eq 1 ]; then
        gt "$w" "$v" && { echo "WARN"; return; }
    else
        gt "$v" "$f" && { echo "FAIL"; return; }
        gt "$v" "$w" && { echo "WARN"; return; }
    fi
    echo "OK"
}

# --------------------------------------------------------------------------
# 1. Environment
# --------------------------------------------------------------------------
section_env() {
    local meta ip asn org colo city country region="" os
    progress "collecting environment info"
    meta=$(curl -s -m 10 https://speed.cloudflare.com/meta 2>/dev/null)
    jget() { printf '%s' "$meta" | sed -n "s/.*\"$1\":\"\{0,1\}\([^\",}]*\).*/\1/p"; }
    ip=$(jget clientIp); asn=$(jget asn); org=$(jget asOrganization)
    colo=$(jget colo); city=$(jget city); country=$(jget country)
    if [ -z "$ip" ]; then
        ip=$(curl -s -m 5 https://checkip.amazonaws.com 2>/dev/null | tr -d '[:space:]')
    fi

    # AWS region: env vars, then IMDSv2 (EC2), quietly
    region="${AWS_REGION:-${AWS_DEFAULT_REGION:-}}"
    if [ -z "$region" ]; then
        local tok
        tok=$(curl -s -m 1 -X PUT http://169.254.169.254/latest/api/token \
              -H 'X-aws-ec2-metadata-token-ttl-seconds: 60' 2>/dev/null)
        [ -n "$tok" ] && region=$(curl -s -m 1 -H "X-aws-ec2-metadata-token: $tok" \
              http://169.254.169.254/latest/meta-data/placement/region 2>/dev/null)
    fi
    [ -n "$region" ] && HTTP_TARGETS="$HTTP_TARGETS s3.$region.amazonaws.com"

    os=$(. /etc/os-release 2>/dev/null && echo "$PRETTY_NAME")
    [ -z "$os" ] && os=$(uname -sr)
    clearp

    out "Host        : $HOST ($os)"
    out "Date        : $(date '+%Y-%m-%d %H:%M:%S %Z')"
    out "Public IP   : ${ip:-unknown}"
    [ -n "$org" ]    && out "Network     : $org (AS$asn)"
    [ -n "$colo" ]   && out "Test server : Cloudflare $colo${city:+ – $city}${country:+, $country}"
    [ -n "$region" ] && out "AWS region  : $region"
    if [ -r /etc/resolv.conf ]; then
        out "DNS servers : $(awk '/^nameserver/{printf "%s ", $2}' /etc/resolv.conf)"
    fi
    json_add "{\"test\":\"env\",\"host\":\"$HOST\",\"public_ip\":\"$ip\",\"asn\":\"$asn\",\"org\":\"$org\",\"colo\":\"$colo\",\"aws_region\":\"$region\"}"
}

# --------------------------------------------------------------------------
# 2. Latency / packet loss
# --------------------------------------------------------------------------
ping_target() {   # prints "loss avg jitter method"
    local t=$1 res=""
    if command -v ping >/dev/null 2>&1; then
        res=$(ping -c "$PING_COUNT" -i 0.2 "$t" 2>&1)
        printf '%s' "$res" | grep -q 'packet loss' || res=$(ping -c "$PING_COUNT" "$t" 2>&1)
    fi
    if printf '%s' "$res" | grep -q 'packet loss'; then
        local loss avg jit
        loss=$(printf '%s' "$res" | grep -o '[0-9.]*% packet loss' | grep -o '^[0-9.]*' | awk '{printf "%.0f", $1}')
        # iputils: "rtt min/avg/max/mdev = a/b/c/d ms"  busybox/mac: "round-trip min/avg/max = ..."
        avg=$(printf '%s' "$res" | grep 'min/avg/max' | sed 's/.*= *//' | cut -d/ -f2 | awk '{printf "%.1f", $1}')
        # jitter = mean absolute difference between consecutive replies
        jit=$(printf '%s' "$res" | grep -o 'time=[0-9.]*' | cut -d= -f2 | \
              awk 'NR>1{d=$1-p; if(d<0)d=-d; s+=d; n++} {p=$1} END{printf "%.1f", n?s/n:0}')
        echo "${loss:-100} ${avg:-0} ${jit:-0} icmp"
        return
    fi
    # Fallback: TCP connect time to port 443 (ICMP often blocked in containers)
    local ok=0 fail=0 times=""
    for _ in $(seq 1 "$PING_COUNT"); do
        local tc
        if tc=$(curl -s -o /dev/null -m 3 -w '%{time_connect}' "https://$t" 2>/dev/null) && gt "$tc" 0; then
            ok=$((ok+1)); times="$times $(ms "$tc")"
        else
            fail=$((fail+1))
        fi
    done
    echo "$times" | awk -v ok=$ok -v f=$fail '{
        for(i=1;i<=NF;i++){s+=$i; if(i>1){d=$i-$(i-1); if(d<0)d=-d; j+=d}}
        printf "%.0f %.1f %.1f tcp\n", f*100/(ok+f), (NF?s/NF:0), (NF>1?j/(NF-1):0) }'
}

section_latency() {
    out ""
    out "[ Latency & packet loss ]"
    out "$(printf '  %-22s %7s %10s %10s %6s  %s' Target Loss 'Avg RTT' Jitter Via Status)"
    local t
    for t in $PING_TARGETS; do
        progress "pinging $t"
        set -- $(ping_target "$t")
        local loss=$1 avg=$2 jit=$3 via=$4 st
        clearp
        st=$(status_for "$loss" $WARN_LOSS $FAIL_LOSS)
        [ "$st" = OK ] && st=$(status_for "$avg" $WARN_RTT $FAIL_RTT)
        [ "$st" = OK ] && gt "$jit" $WARN_JITTER && st=WARN
        [ "$st" = WARN ] && issue 1 "$t: loss ${loss}% / RTT ${avg}ms / jitter ${jit}ms"
        [ "$st" = FAIL ] && issue 2 "$t: loss ${loss}% / RTT ${avg}ms"
        out "$(printf '  %-22s %6s%% %8sms %8sms %6s  %s' "$t" "$loss" "$avg" "$jit" "$via" "$st")"
        json_add "{\"test\":\"latency\",\"target\":\"$t\",\"loss_pct\":$loss,\"rtt_ms\":$avg,\"jitter_ms\":$jit,\"method\":\"$via\",\"status\":\"$st\"}"
    done
}

# --------------------------------------------------------------------------
# 3. DNS + HTTPS timings
# --------------------------------------------------------------------------
section_http() {
    out ""
    out "[ DNS & HTTPS ]"
    out "$(printf '  %-28s %7s %8s %7s %7s  %s' Host DNS Connect TLS TTFB Status)"
    local h
    for h in $HTTP_TARGETS; do
        progress "checking $h"
        local r rc
        r=$(curl -s -o /dev/null -m 15 -w '%{http_code} %{time_namelookup} %{time_connect} %{time_appconnect} %{time_starttransfer}' "https://$h/" 2>/dev/null)
        rc=$?
        clearp
        set -- $r
        local code=${1:-000} dns conn tls ttfb st
        dns=$(ms "${2:-0}")
        conn=$(ms "$(awk -v a="${3:-0}" -v b="${2:-0}" 'BEGIN{print a-b}')")
        tls=$(ms "$(awk -v a="${4:-0}" -v b="${3:-0}" 'BEGIN{print (a>b)?a-b:0}')")
        ttfb=$(ms "${5:-0}")
        if [ $rc -ne 0 ] || [ "$code" = "000" ]; then
            st="FAIL (curl exit $rc)"; issue 2 "$h unreachable (curl exit $rc)"
        else
            st=$(status_for "$dns" $WARN_DNS $FAIL_DNS)
            [ "$st" != OK ] && issue 1 "slow DNS for $h (${dns}ms)"
        fi
        out "$(printf '  %-28s %5sms %6sms %5sms %5sms  %s' "$h" "$dns" "$conn" "$tls" "$ttfb" "$st")"
        json_add "{\"test\":\"https\",\"host\":\"$h\",\"http_code\":\"$code\",\"dns_ms\":$dns,\"connect_ms\":$conn,\"tls_ms\":$tls,\"ttfb_ms\":$ttfb,\"status\":\"${st%% *}\"}"
    done
}

# --------------------------------------------------------------------------
# 4. Download (plain HTTP from the speed-test servers)
# --------------------------------------------------------------------------
UP_SMALL_SUM=0; UP_SMALL_N=0; UP_BIG=""
DOWN_SUMMARY=""; BEST_DOWN=0

transfer_row() {   # transfer_row label bytes time speed rc
    local label=$1 bytes=$2 t=$3 sp=$4 rc=$5 note=""
    [ "$rc" -eq 28 ] && note="timeout (partial)"
    [ "$rc" -ne 0 ] && [ "$rc" -ne 28 ] && note="error (curl exit $rc)"
    out "$(printf '  %-18s %10s %8ss %12s Mbit/s  %s' "$label" "$(human_size "$bytes")" "$(printf '%.1f' "$t")" "$(mbps "$sp")" "$note")"
}

section_download() {
    local sizes="$SMALL_SIZES" o s
    [ $QUICK -eq 0 ] && sizes="$sizes $BIG_SIZE"
    out ""
    out "[ Download ]  plain HTTP, Mbit/s per file"
    local hdr; hdr=$(printf '  %-6s %8s %8s' Server Connect TTFB)
    for s in $sizes; do hdr="$hdr$(printf ' %8s' "$s")"; done
    [ "$PARALLEL_STREAMS" -gt 0 ] && hdr="$hdr$(printf ' %8s' "${PARALLEL_STREAMS}x$PARALLEL_SIZE")"
    out "$hdr$(printf '  %s' Status)"

    for o in $ORIGINS; do
        local name=${o%%=*} base=${o#*=} row="" sum=0 n=0 conn="-" ttfb="-" st=OK big="" par=""
        case "$base" in */) ;; *) base="$base/" ;; esac

        # quick reachability check (first 1 KB) so an unreachable server fails fast with a reason
        progress "$name: checking reachability"
        local pc prc
        pc=$(curl -s -o /dev/null -m 15 -r 0-1023 -w '%{http_code}' "${base}${PARALLEL_SIZE}.bin" 2>/dev/null); prc=$?
        clearp
        if [ $prc -ne 0 ] || [ "$pc" = 000 ]; then
            local why; why=$(curl_reason $prc)
            out "$(printf '  %-6s %8s %8s' "$name" - -)  UNREACHABLE: $why"
            issue 2 "$name unreachable: $why (${base})"
            json_add "{\"test\":\"download\",\"server\":\"$name\",\"reachable\":false,\"curl_exit\":$prc,\"reason\":\"$why\"}"
            DOWN_SUMMARY="$DOWN_SUMMARY  Download  $name  unreachable ($why)"$'\n'
            continue
        fi

        for s in $sizes; do
            local to=$SMALL_TIMEOUT r rc code cell
            [ $QUICK -eq 0 ] && [ "$s" = "$BIG_SIZE" ] && to=$BIG_TIMEOUT
            progress "$name: downloading $s"
            r=$(curl -s -o /dev/null -m "$to" -w '%{size_download} %{time_total} %{speed_download} %{http_code} %{time_connect} %{time_starttransfer}' "${base}${s}.bin" 2>/dev/null)
            rc=$?; clearp
            set -- $r
            code=${4:-000}
            if [ "$conn" = "-" ] && [ "$code" != 000 ]; then conn="$(ms "${5:-0}")ms"; ttfb="$(ms "${6:-0}")ms"; fi
            if [ "$code" = 404 ]; then
                cell="n/a"
            elif { [ $rc -ne 0 ] && [ $rc -ne 28 ]; } || [ "$code" != 200 ]; then
                cell="ERR"; st=FAIL
                if [ "$code" = 000 ]; then issue 2 "$name: $s download failed ($(curl_reason $rc))"
                else issue 2 "$name: $s download failed (HTTP $code)"; fi
            else
                cell=$(mbps "$3"); [ $rc -eq 28 ] && cell="$cell*"
                if [ $QUICK -eq 0 ] && [ "$s" = "$BIG_SIZE" ]; then big=$(mbps "$3")
                else sum=$(awk -v a=$sum -v b="$3" 'BEGIN{print a+b}'); n=$((n+1)); fi
            fi
            row="$row$(printf ' %8s' "$cell")"
            json_add "{\"test\":\"download\",\"server\":\"$name\",\"size\":\"$s\",\"bytes\":${1:-0},\"seconds\":${2:-0},\"mbps\":$(mbps "${3:-0}"),\"http_code\":\"$code\",\"curl_exit\":$rc}"
        done

        if [ "$PARALLEL_STREAMS" -gt 0 ]; then
            progress "$name: ${PARALLEL_STREAMS} parallel downloads of $PARALLEL_SIZE"
            local i
            rm -f "$WORK_DIR"/par.*
            for i in $(seq 1 "$PARALLEL_STREAMS"); do
                curl -s -o /dev/null -m $SMALL_TIMEOUT -w '%{size_download} %{time_total}\n' "${base}${PARALLEL_SIZE}.bin" > "$WORK_DIR/par.$i" 2>/dev/null &
            done
            wait
            # streams run concurrently: aggregate = total bytes / slowest stream
            set -- $(cat "$WORK_DIR"/par.* 2>/dev/null | awk '{b+=$1; if($2>t)t=$2} END{if(t<=0)t=0.001; printf "%d %.3f %.0f", b, t, b/t}')
            clearp
            par=$(mbps "$3")
            row="$row$(printf ' %8s' "$par")"
            json_add "{\"test\":\"download_parallel\",\"server\":\"$name\",\"streams\":$PARALLEL_STREAMS,\"bytes\":$1,\"seconds\":$2,\"mbps\":$par}"
        fi

        local avg=""
        [ $n -gt 0 ] && avg=$(awk -v s=$sum -v n=$n 'BEGIN{printf "%.1f", s/n*8/1000000}')
        local best; best=$(printf '%s\n' "$avg" "$big" "$par" | awk 'NF && $1>m{m=$1} END{print m+0}')
        gt "$best" "$BEST_DOWN" && BEST_DOWN=$best
        if [ "$st" = OK ]; then
            gt $WARN_DOWN "$best" && { st=WARN; issue 1 "$name: download only ${best} Mbit/s at best (< ${WARN_DOWN})"; }
            # single stream much slower than parallel => per-connection limit / high-latency path
            if [ -n "$par" ] && [ -n "$avg" ] && gt "$par" "$(awk -v a="$avg" 'BEGIN{print a*2}')"; then
                [ "$st" = OK ] && st=WARN
                issue 1 "$name: single-stream ${avg} Mbit/s is <50% of parallel ${par} Mbit/s (per-connection limit or high latency)"
            fi
        fi
        out "$(printf '  %-6s %8s %8s' "$name" "$conn" "$ttfb")$row  $st"
        DOWN_SUMMARY="$DOWN_SUMMARY  Download  $name  small avg: ${avg:--} Mbit/s${big:+ | big: $big Mbit/s}${par:+ | parallel: $par Mbit/s}"$'\n'
    done
    out "  (* = hit time limit, partial transfer; n/a = file not on server)"
}

# --------------------------------------------------------------------------
# 5. Upload
# --------------------------------------------------------------------------
make_file() {   # make_file bytes name -> path (random data so nothing can compress it)
    local f="$WORK_DIR/$2" mb rem
    mb=$(( $1 / 1048576 )); rem=$(( $1 % 1048576 ))
    : > "$f" || return 1
    if [ $mb -gt 0 ]; then dd if=/dev/urandom bs=1048576 count=$mb 2>/dev/null >> "$f" || return 1; fi
    if [ $rem -gt 0 ]; then dd if=/dev/urandom bs=$rem count=1 2>/dev/null >> "$f" || return 1; fi
    echo "$f"
}

free_mb() { df -Pm "$1" 2>/dev/null | awk 'NR==2{print $4}'; }

with_timeout() { if command -v timeout >/dev/null 2>&1; then timeout "$@"; else shift; "$@"; fi; }

upload_one() {   # upload_one size timeout -> "bytes time speed rc http_code"
    local bytes to=$2 f r rc
    bytes=$(to_bytes "$1")

    if [ -n "$S3_BUCKET" ]; then   # real object upload, aws cli does multipart
        local key="network-test/$HOST-$STAMP-$1" start end
        f=$(make_file "$bytes" "up.bin") || { echo "0 0 0 1 -"; return; }
        start=$(now)
        with_timeout "$to" aws s3 cp --only-show-errors "$f" "s3://$S3_BUCKET/$key" >/dev/null 2>"$WORK_DIR/s3.err"
        rc=$?; end=$(now)
        aws s3 rm --only-show-errors "s3://$S3_BUCKET/$key" >/dev/null 2>&1
        rm -f "$f"; [ $rc -eq 124 ] && rc=28
        awk -v b="$bytes" -v a="$start" -v e="$end" -v rc=$rc 'BEGIN{t=e-a; if(t<=0)t=0.001; printf "%d %.3f %.0f %d -\n", (rc?0:b), t, b/t, rc}'
        return
    fi

    local fmt='%{size_upload} %{time_total} %{http_code}\n' hdr="-H Expect: -H Content-Type:application/octet-stream"
    if [ "$UPLOAD_METHOD" = PUT ]; then   # custom URL (e.g. S3 presigned): one single PUT
        f=$(make_file "$bytes" "up.bin") || { echo "0 0 0 1 -"; return; }
        r=$(curl -s -o /dev/null -m "$to" -H 'Expect:' -X PUT -T "$f" -w "$fmt" "$UPLOAD_URL" 2>/dev/null)
        rc=$?
    else                                  # Cloudflare: repeat a <=90 MiB chunk on one connection
        local n=$bytes rem=0 cnt=1 i
        [ "$bytes" -gt $CHUNK ] && { n=$CHUNK; cnt=$((bytes / CHUNK)); rem=$((bytes % CHUNK)); }
        f=$(make_file "$n" "chunk.bin") || { echo "0 0 0 1 -"; return; }
        [ $rem -gt 0 ] && { make_file "$rem" "rem.bin" >/dev/null || { echo "0 0 0 1 -"; return; }; }
        set --
        for i in $(seq 1 $cnt); do
            [ $# -gt 0 ] && set -- "$@" --next
            set -- "$@" -s -o /dev/null -H 'Expect:' -H 'Content-Type: application/octet-stream' \
                   --data-binary @"$f" -w "$fmt" "$UPLOAD_URL"
        done
        [ $rem -gt 0 ] && set -- "$@" --next -s -o /dev/null -H 'Expect:' -H 'Content-Type: application/octet-stream' \
                   --data-binary @"$WORK_DIR/rem.bin" -w "$fmt" "$UPLOAD_URL"
        r=$(with_timeout "$to" curl "$@" 2>/dev/null)
        rc=$?; [ $rc -eq 124 ] && rc=28
    fi
    rm -f "$WORK_DIR"/up.bin "$WORK_DIR"/chunk.bin "$WORK_DIR"/rem.bin
    printf '%s\n' "$r" | awk -v rc=$rc 'NF{b+=$1; t+=$2; c=$3; if($3!~/^2/){bad=$3}}
        END{if(t<=0)t=0.001; if(bad!="" && rc==0) rc=22; printf "%d %.3f %.0f %d %s\n", b, t, b/t, rc, (bad!=""?bad:(c?c:"-"))}'
}

section_upload() {
    local target
    if [ -n "$S3_BUCKET" ]; then target="s3://$S3_BUCKET (aws cli)"
    else target=$(echo "$UPLOAD_URL" | sed 's|^\(https\{0,1\}://[^/?]*\).*|\1|'); fi
    out ""
    out "[ Upload ]  target: $target"
    out "$(printf '  %-18s %10s %9s %19s' Test Size Time Speed)"

    local s
    for s in $SMALL_SIZES; do
        progress "uploading $s"
        set -- $(upload_one "$s" $SMALL_TIMEOUT); clearp
        transfer_row "small $s" "$1" "$2" "$3" "$4"
        [ "$4" -eq 22 ] && out "                     ↳ server answered HTTP $5"
        [ "$4" -eq 0 ] && { UP_SMALL_SUM=$(awk -v a=$UP_SMALL_SUM -v b="$3" 'BEGIN{print a+b}'); UP_SMALL_N=$((UP_SMALL_N+1)); }
        [ "$4" -ne 0 ] && issue 2 "upload $s failed (curl exit $4, HTTP $5)"
        json_add "{\"test\":\"upload\",\"size\":\"$s\",\"bytes\":$1,\"seconds\":$2,\"mbps\":$(mbps "$3"),\"curl_exit\":$4}"
    done

    if [ $QUICK -eq 0 ]; then
        # Only S3 / custom-URL mode writes the full file to disk; Cloudflare mode uses one 90 MiB chunk
        local need avail
        need=$(( $(to_bytes "$BIG_SIZE") / 1048576 + 50 ))
        [ -z "$S3_BUCKET" ] && [ "$UPLOAD_METHOD" = POST ] && need=150
        avail=$(free_mb "$WORK_DIR")
        if [ -n "$avail" ] && [ "$avail" -lt "$need" ]; then
            out "  big $BIG_SIZE             skipped (needs ${need} MB free in $TMP_DIR, have ${avail} MB; use --tmp)"
            issue 1 "big upload skipped: not enough disk space in $TMP_DIR"
        else
            progress "uploading $BIG_SIZE (max ${BIG_TIMEOUT}s)"
            set -- $(upload_one "$BIG_SIZE" $BIG_TIMEOUT); clearp
            transfer_row "big $BIG_SIZE" "$1" "$2" "$3" "$4"
            [ "$4" -eq 22 ] && out "                     ↳ server answered HTTP $5"
            UP_BIG=$(mbps "$3")
            [ "$4" -ne 0 ] && [ "$4" -ne 28 ] && issue 2 "upload $BIG_SIZE failed (curl exit $4, HTTP $5)"
            json_add "{\"test\":\"upload\",\"size\":\"$BIG_SIZE\",\"bytes\":$1,\"seconds\":$2,\"mbps\":$UP_BIG,\"curl_exit\":$4}"
        fi
    fi
}

# --------------------------------------------------------------------------
# Run
# --------------------------------------------------------------------------
out "=================================================================="
out " NETWORK HEALTH REPORT"
out "=================================================================="
section_env
section_latency
section_http
[ $SKIP_DOWNLOAD -eq 0 ] && [ -n "$ORIGINS" ] && section_download
[ $SKIP_UPLOAD -eq 0 ]   && section_upload

# Summary ---------------------------------------------------------------
avg_up=""
[ $UP_SMALL_N -gt 0 ] && avg_up=$(awk -v s=$UP_SMALL_SUM -v n=$UP_SMALL_N 'BEGIN{printf "%.1f", s/n*8/1000000}')
best_down=$BEST_DOWN
best_up=$(printf '%s\n' "$avg_up" "$UP_BIG" | awk 'NF && $1>m{m=$1} END{print m+0}')
[ $SKIP_UPLOAD -eq 0 ] && gt $WARN_UP "$best_up" && issue 1 "upload below ${WARN_UP} Mbit/s (best ${best_up})"

case $WORST in 0) overall="HEALTHY" ;; 1) overall="DEGRADED" ;; *) overall="UNHEALTHY" ;; esac

out ""
out "[ Summary ]"
[ -n "$DOWN_SUMMARY" ] && out "${DOWN_SUMMARY%$'\n'}"
[ -n "$avg_up" ]   && out "  Upload    small avg: ${avg_up} Mbit/s${UP_BIG:+ | big: ${UP_BIG} Mbit/s}"
out "  Overall   : $overall"
if [ -n "$ISSUES" ]; then
    out "  Issues    :"
    out "${ISSUES%$'\n'}"
fi
out "=================================================================="

printf '%s' "$REPORT" > "$REPORT_OUT" && echo "Report saved: $REPORT_OUT"
if [ -n "$JSON_OUT" ]; then
    printf '{"host":"%s","time":"%s","overall":"%s","download_mbps":%s,"upload_mbps":%s,"results":[%s]}\n' \
        "$HOST" "$STAMP" "$overall" "${best_down:-0}" "${best_up:-0}" "$JSON_ITEMS" > "$JSON_OUT" \
        && echo "JSON saved  : $JSON_OUT"
fi

[ $WORST -ge 2 ] && exit 1
exit 0

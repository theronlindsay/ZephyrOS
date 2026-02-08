#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# ZephyrOS ISO Build & Upload Script
# Builds all ISO variants in parallel and uploads them to Google Drive
# =============================================================================

# Configuration

ISO_OUTPUT_DIR="${ISO_OUTPUT_DIR:-./iso-output}"
TMPDIR="${ISO_OUTPUT_DIR}/tmp"
export TMPDIR
GDRIVE_FOLDER="${GDRIVE_FOLDER:-ZephyrOS/ISOs}"
PARALLEL_BUILDS="${PARALLEL_BUILDS:-1}"  # Build 1 at a time by default
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Ensure TMPDIR exists
mkdir -p "$TMPDIR"
chmod 1777 "$TMPDIR" || true

# ISO variants to build (recipe file : output name)
declare -A RECIPES=(
    ["zephyros.yml"]="ZephyrOS"
    ["zephyros-nvidia.yml"]="ZephyrOS-NVIDIA"
    ["zephyros-console.yml"]="ZephyrOS-Console"
    ["zephyros-nvidia-console.yml"]="ZephyrOS-NVIDIA-Console"
    ["zephyros-laptop.yml"]="ZephyrOS-Laptop"
    ["zephyros-nvidia-laptop.yml"]="ZephyrOS-NVIDIA-Laptop"
    ["zephyros-asus.yml"]="ZephyrOS-ASUS"
    ["zephyros-nvidia-asus.yml"]="ZephyrOS-NVIDIA-ASUS"
)

# Build order matters due to dependencies
# Stage 1: Base images (no dependencies)
BASE_RECIPES=("zephyros.yml" "zephyros-nvidia.yml" "zephyros-console.yml" "zephyros-nvidia-console.yml")
# Stage 2: Laptop images (depend on base)
LAPTOP_RECIPES=("zephyros-laptop.yml" "zephyros-nvidia-laptop.yml")
# Stage 3: ASUS images (depend on laptop)
ASUS_RECIPES=("zephyros-asus.yml" "zephyros-nvidia-asus.yml")

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# =============================================================================
# Prerequisites Check
# =============================================================================
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check for bluebuild
    if ! command -v bluebuild &> /dev/null; then
        log_error "bluebuild CLI not found. Install with:"
        echo "  bash <(curl -s https://raw.githubusercontent.com/blue-build/cli/main/install.sh)"
        exit 1
    fi
    
    # Check for Python (for gdrive upload)
    if ! command -v python3 &> /dev/null; then
        log_error "python3 not found."
        exit 1
    fi
    
    # Check for sudo (needed for bluebuild)
    if [[ $EUID -ne 0 ]]; then
        log_warn "This script needs sudo for bluebuild. You may be prompted for password."
    fi
    
    # Check disk space
    local available_gb=$(df -BG "$PROJECT_DIR" | awk 'NR==2 {print $4}' | tr -d 'G')
    log_info "Available disk space: ${available_gb}GB"
    if [[ $available_gb -lt 50 ]]; then
        log_warn "Low disk space! Each ISO is ~4-8GB. You may run out of space."
    fi
    
    log_success "All prerequisites met!"
}

# =============================================================================
# Build Functions
# =============================================================================
build_iso() {
    local recipe="$1"
    local name="$2"
    local iso_name="${name}.iso"
    local log_file="${ISO_OUTPUT_DIR}/logs/${name}.log"
    
    mkdir -p "${ISO_OUTPUT_DIR}/logs"
    mkdir -p "$ISO_OUTPUT_DIR"
    
    echo "[$(date '+%H:%M:%S')] Building ${name} from ${recipe}..." | tee -a "$log_file"
    
    # Build the ISO. Run bluebuild under sudo but set TMPDIR for the build
    if sudo env TMPDIR="$TMPDIR" bluebuild generate-iso \
        --iso-name "$iso_name" \
        --output-dir "$ISO_OUTPUT_DIR" \
        recipe "${PROJECT_DIR}/recipes/${recipe}" >> "$log_file" 2>&1; then
        echo "[$(date '+%H:%M:%S')] ✅ Built ${iso_name}" | tee -a "$log_file"
        return 0
    else
        echo "[$(date '+%H:%M:%S')] ❌ Failed to build ${iso_name}" | tee -a "$log_file"
        return 1
    fi
}

build_stage() {
    local stage_name="$1"
    shift
    local recipes=("$@")
    
    log_info "========== Building Stage: ${stage_name} (${#recipes[@]} images) =========="
    
    local pids=()
    declare -A pid_to_recipe
    
    for recipe in "${recipes[@]}"; do
        local name="${RECIPES[$recipe]}"
        
        # Run build in background for parallel execution
        build_iso "$recipe" "$name" &
        local pid=$!
        pids+=($pid)
        pid_to_recipe[$pid]="$name"
        
        log_info "Started build: ${name} (PID: ${pid})"
        
        # Limit parallel builds
        while [[ ${#pids[@]} -ge $PARALLEL_BUILDS ]]; do
            sleep 5
            # Remove finished pids
            local new_pids=()
            for p in "${pids[@]}"; do
                if kill -0 "$p" 2>/dev/null; then
                    new_pids+=("$p")
                fi
            done
            pids=("${new_pids[@]}")
        done
    done
    
    # Wait for all remaining builds
    log_info "Waiting for remaining builds to complete..."
    local failed=0
    for pid in "${pids[@]}"; do
        if ! wait "$pid"; then
            ((failed++))
            log_error "Build failed: ${pid_to_recipe[$pid]:-unknown}"
        else
            log_success "Build completed: ${pid_to_recipe[$pid]:-unknown}"
        fi
    done
    
    if [[ $failed -gt 0 ]]; then
        log_error "Stage ${stage_name}: ${failed} build(s) failed"
        return 1
    fi
    
    log_success "Stage ${stage_name}: All ${#recipes[@]} builds completed!"
    return 0
}

build_all_isos() {
    log_info "Starting ISO builds (parallel: ${PARALLEL_BUILDS})..."
    log_info "Output directory: ${ISO_OUTPUT_DIR}"
    
    local start_time=$(date +%s)
    local failed_stages=()
    
    # Build in dependency order
    # Stage 1: Base images (can all build in parallel)
    if ! build_stage "Base Images" "${BASE_RECIPES[@]}"; then
        failed_stages+=("Base")
        log_error "Base images failed - laptop/ASUS images will likely fail too"
    fi
    
    # Stage 2: Laptop images (depend on base)
    if ! build_stage "Laptop Images" "${LAPTOP_RECIPES[@]}"; then
        failed_stages+=("Laptop")
    fi
    
    # Stage 3: ASUS images (depend on laptop)
    if ! build_stage "ASUS Images" "${ASUS_RECIPES[@]}"; then
        failed_stages+=("ASUS")
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local hours=$((duration / 3600))
    local minutes=$(((duration % 3600) / 60))
    
    echo ""
    log_info "========== Build Summary =========="
    log_info "Total time: ${hours}h ${minutes}m"
    log_info "ISOs built:"
    ls -lh "${ISO_OUTPUT_DIR}"/*.iso 2>/dev/null || echo "  (none)"
    
    if [[ ${#failed_stages[@]} -gt 0 ]]; then
        log_error "Failed stages: ${failed_stages[*]}"
        return 1
    fi
    
    log_success "All builds completed successfully!"
    return 0
}

# =============================================================================
# Upload Functions
# =============================================================================
generate_checksums() {
    log_info "Generating checksums..."
    
    cd "$ISO_OUTPUT_DIR"
    for iso in *.iso; do
        if [[ -f "$iso" ]]; then
            log_info "Generating checksum for ${iso}..."
            sha256sum "$iso" > "${iso}-CHECKSUM"
        fi
    done
    cd - > /dev/null
    log_success "Checksums generated!"
}

# =============================================================================
# Cleanup
# =============================================================================
cleanup() {
    if [[ "${KEEP_ISOS:-false}" != "true" ]]; then
        log_info "Cleaning up local ISOs..."
        rm -rf "$ISO_OUTPUT_DIR"
    else
        log_info "Keeping local ISOs in ${ISO_OUTPUT_DIR}"
    fi
}

# =============================================================================
# Main
# =============================================================================
usage() {
    cat << EOF
Usage: $0 [OPTIONS] [COMMAND]

Commands:
    build       Build all ISOs (default)
    list        List configured recipes

Options:
    -r, --recipe RECIPE   Build only specific recipe (e.g., zephyros.yml)
    -p, --parallel N      Number of parallel builds (default: 4)
    -h, --help            Show this help

Environment Variables:
    ISO_OUTPUT_DIR    Output directory (default: ./iso-output)
    PARALLEL_BUILDS   Parallel build count (default: 4)

Examples:
    $0                          # Build all ISOs
    $0 build                    # Build all ISOs
    $0 -r zephyros.yml build    # Build single ISO
    $0 -p 2 build               # Build with 2 parallel jobs
EOF
}

main() {
    local command="build"
    local single_recipe=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -r|--recipe)
                single_recipe="$2"
                shift 2
                ;;
            -p|--parallel)
                PARALLEL_BUILDS="$2"
                shift 2
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            build|list)
                command="$1"
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done

    # List recipes
    if [[ "$command" == "list" ]]; then
        echo "Configured recipes:"
        echo ""
        echo "Base images (Stage 1):"
        for recipe in "${BASE_RECIPES[@]}"; do
            echo "  ${recipe} -> ${RECIPES[$recipe]}.iso"
        done
        echo ""
        echo "Laptop images (Stage 2):"
        for recipe in "${LAPTOP_RECIPES[@]}"; do
            echo "  ${recipe} -> ${RECIPES[$recipe]}.iso"
        done
        echo ""
        echo "ASUS images (Stage 3):"
        for recipe in "${ASUS_RECIPES[@]}"; do
            echo "  ${recipe} -> ${RECIPES[$recipe]}.iso"
        done
        exit 0
    fi

    # Check prerequisites
    check_prerequisites

    # Handle single recipe
    if [[ -n "$single_recipe" ]]; then
        if [[ -z "${RECIPES[$single_recipe]:-}" ]]; then
            log_error "Unknown recipe: $single_recipe"
            log_info "Available recipes:"
            for r in "${!RECIPES[@]}"; do
                echo "  $r"
            done
            exit 1
        fi
        log_info "Building single recipe: $single_recipe"
        mkdir -p "$ISO_OUTPUT_DIR"
        if build_iso "$single_recipe" "${RECIPES[$single_recipe]}"; then
            generate_checksums
        else
            exit 1
        fi
        exit 0
    fi

    # Execute command
    case $command in
        build|*)
            build_all_isos
            generate_checksums
            ;;
    esac

    log_success "Done!"
}

main "$@"

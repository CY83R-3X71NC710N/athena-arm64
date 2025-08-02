#!/bin/bash
# validate-kickstart.sh - Local validation script for the kickstart file

set -e

echo "🔍 Validating AthenaOS ARM64 Kickstart Configuration"
echo "=================================================="

# Check if pykickstart is available
if ! command -v pykickstart &> /dev/null; then
    echo "❌ pykickstart not found. Please install it:"
    echo "   Fedora/RHEL: sudo dnf install pykickstart"
    echo "   Ubuntu/Debian: sudo apt install pykickstart"
    exit 1
fi

# Validate kickstart syntax
echo "📋 Validating kickstart syntax..."
if pykickstart --version F40 athena-iso.ks; then
    echo "✅ Kickstart syntax is valid"
else
    echo "❌ Kickstart syntax validation failed"
    exit 1
fi

# Check repository accessibility for ARM64
echo ""
echo "🌐 Checking repository accessibility for ARM64..."

repos=(
    "https://mirrors.fedoraproject.org/mirrorlist?repo=fedora-40&arch=aarch64"
    "https://mirrors.fedoraproject.org/mirrorlist?repo=updates-released-f40&arch=aarch64"
    "https://copr-be.cloud.fedoraproject.org/results/@athenaos/athenaos/fedora-40-aarch64/"
    "https://copr-be.cloud.fedoraproject.org/results/petersen/nix/fedora-40-aarch64/"
    "https://hub.athenaos.org/athena/aarch64"
)

for repo in "${repos[@]}"; do
    echo -n "  Checking $repo ... "
    if curl -s --head "$repo" | head -n 1 | grep -q "200 OK\|302 Found\|301 Moved"; then
        echo "✅"
    else
        echo "⚠️  (may not be accessible or may not have ARM64 packages)"
    fi
done

# Check required source files
echo ""
echo "📁 Checking required source files..."

required_files=(
    "src/athena-mirrorlist"
    "src/pacman.conf"
    "src/athena.gpg"
    "src/athena-trusted"
    "src/athena-revoked"
    "src/chaotic.gpg"
    "src/chaotic-trusted"
    "src/chaotic-revoked"
)

for file in "${required_files[@]}"; do
    if [ -f "$file" ]; then
        echo "  ✅ $file"
    else
        echo "  ❌ $file (missing)"
    fi
done

echo ""
echo "🎯 Architecture-specific checks..."
echo "  Target architecture: aarch64 (ARM64)"
echo "  Base Fedora version: 40"

# Check for potentially problematic x86_64-specific packages
echo ""
echo "🔍 Scanning for potentially x86_64-specific packages..."
x86_packages=$(grep -E "(intel-|amd-|x86)" athena-iso.ks || true)
if [ -n "$x86_packages" ]; then
    echo "⚠️  Found potentially x86_64-specific packages:"
    echo "$x86_packages"
    echo "   These may need ARM64 alternatives or removal"
else
    echo "✅ No obvious x86_64-specific packages found"
fi

echo ""
echo "📊 Kickstart validation complete!"
echo ""
echo "🚀 To build the ISO:"
echo "   1. Push changes to GitHub"
echo "   2. Go to Actions tab in GitHub repository"
echo "   3. Run 'Build AthenaOS ARM64 ISO' workflow"
echo "   4. Download the built ISO from artifacts or releases"

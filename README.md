# AthenaOS ARM64 🛡️

This repository contains the configuration and build system for creating AthenaOS ISO images for ARM64 (aarch64) architecture.

## 🚀 Automated Builds

This repository uses GitHub Actions to automatically build ARM64 ISO images using macOS runners (Apple Silicon). 

### Building via GitHub Actions

#### Automatic Builds
- **Push to main**: Triggers a development build
- **Create tag**: Triggers a release build
- **Pull Request**: Validates the build configuration

#### Manual Builds
You can trigger a manual build:

1. Go to the **Actions** tab in this repository
2. Select **Build AthenaOS ARM64 ISO** workflow
3. Click **Run workflow**
4. Optionally specify a release version (e.g., `v1.0.0`)
5. Click **Run workflow**

### Download Built ISOs

Built ISO images are available in two places:

1. **Artifacts**: Available for 30 days after each build in the Actions tab
2. **Releases**: Permanent releases with proper versioning

## 📋 Build Process

The build process:

1. Uses `macos-latest` runners (Apple Silicon ARM64)
2. Sets up Docker with ARM64 support via Colima
3. Creates a Fedora container with build tools
4. Builds the ISO using `livemedia-creator`
5. Generates checksums (SHA256, MD5)
6. Creates GitHub releases for tags

## 🛠️ Local Development

To test changes locally before pushing:

1. Validate the kickstart file:
   ```bash
   pykickstart --version F40 athena-iso.ks
   ```

2. Check repository URLs are accessible for ARM64:
   ```bash
   curl -I "https://mirrors.fedoraproject.org/mirrorlist?repo=fedora-40&arch=aarch64"
   ```

## 📁 Repository Structure

```
.
├── .github/workflows/
│   └── build-arm64-iso.yml    # GitHub Actions workflow
├── src/
│   ├── athena-mirrorlist      # Athena repository mirrors
│   ├── athena-revoked         # Revoked keys
│   ├── athena-trusted         # Trusted keys
│   ├── athena.gpg            # GPG keyring
│   ├── chaotic-*             # Chaotic AUR repository configs
│   └── pacman.conf           # Pacman configuration
├── athena-iso.ks             # Main kickstart file
└── README.md                 # This file
```

## 🎯 Target Architecture

- **Architecture**: ARM64 (aarch64)
- **Base Distribution**: Fedora 40
- **Package Manager**: Pacman (Arch-style)
- **Desktop Environment**: XFCE4 (default)

## ⚠️ Important Notes

- This is an experimental ARM64 port of AthenaOS
- Thoroughly test on your target ARM64 device before production use
- Some packages might not be available for ARM64 architecture
- Report issues and compatibility problems

## 🤝 Contributing

1. Fork this repository
2. Make your changes to the kickstart file or configurations
3. Test locally if possible
4. Create a Pull Request
5. The GitHub Actions will validate your changes

## 📞 Support

- **Issues**: Use GitHub Issues for bug reports and feature requests
- **Discussions**: Use GitHub Discussions for general questions
- **Main Project**: Visit the main AthenaOS repository for general support

## 📄 License

This project follows the same license as the main AthenaOS project.
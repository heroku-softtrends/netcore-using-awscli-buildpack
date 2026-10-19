
#!/usr/bin/env bash

# shellcheck source=util/common.sh
source "$BP_DIR/bin/util/common.sh"

awscli_install() {
    local AWS_INSTALL_DIR="$BUILD_DIR/vendor/awscli"
    local AWS_BIN_DIR="$AWS_INSTALL_DIR/bin"
    local AWS_ARCHIVE="/tmp/awscliv2.zip"
    local AWS_URL

    print "Preparing AWS CLI v2 installation"

    mkdir -p "$BUILD_DIR/vendor"

    if ! command -v curl >/dev/null 2>&1; then
        echo "ERROR: curl is required to download AWS CLI." >&2
        return 1
    fi

    if ! command -v unzip >/dev/null 2>&1; then
        echo "ERROR: unzip is required to install AWS CLI." >&2
        return 1
    fi

    case "$(uname -m)" in
        x86_64|amd64)
            AWS_URL="https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip"
            ;;
        aarch64|arm64)
            AWS_URL="https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip"
            ;;
        *)
            echo "ERROR: Unsupported architecture: $(uname -m)" >&2
            return 1
            ;;
    esac

    rm -f "$AWS_ARCHIVE"

    print "Downloading AWS CLI v2"

    if ! curl -fsSL "$AWS_URL" -o "$AWS_ARCHIVE"; then
        echo "ERROR: Failed to download AWS CLI." >&2
        rm -f "$AWS_ARCHIVE"
        return 1
    fi

    rm -rf "$BUILD_DIR/vendor/aws"

    if ! unzip -qq -d "$BUILD_DIR/vendor" "$AWS_ARCHIVE"; then
        echo "ERROR: Failed to extract AWS CLI installer." >&2
        rm -f "$AWS_ARCHIVE"
        return 1
    fi

    print "Installing AWS CLI into slug"

    if ! "$BUILD_DIR/vendor/aws/install" \
        --install-dir "$AWS_INSTALL_DIR" \
        --bin-dir "$AWS_BIN_DIR" \
        --update; then
        echo "ERROR: AWS CLI installation failed." >&2
        rm -rf "$BUILD_DIR/vendor/aws"
        rm -f "$AWS_ARCHIVE"
        return 1
    fi

    rm -rf "$BUILD_DIR/vendor/aws"
    rm -f "$AWS_ARCHIVE"

    if [[ ! -x "$AWS_BIN_DIR/aws" ]]; then
        echo "ERROR: AWS CLI executable was not created at $AWS_BIN_DIR/aws" >&2
        return 1
    fi

    # Make AWS CLI available during compilation.
    export PATH="$AWS_BIN_DIR:$PATH"

    print "AWS CLI installation completed"
    "$AWS_BIN_DIR/aws" --version

    # Make AWS CLI available at runtime.
    mkdir -p "$BUILD_DIR/.profile.d"

    cat > "$BUILD_DIR/.profile.d/awscli.sh" <<'EOF'
#!/usr/bin/env bash
export PATH="/app/vendor/awscli/bin:$PATH"
EOF

    chmod +x "$BUILD_DIR/.profile.d/awscli.sh"
}

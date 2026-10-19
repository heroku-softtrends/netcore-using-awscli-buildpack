```bash
#!/usr/bin/env bash

# shellcheck source=util/common.sh
source "$BP_DIR/bin/util/common.sh"

function awscli_install() {
    local AWS_INSTALL_DIR="$BUILD_DIR/vendor/awscli"
    local AWS_BIN_DIR="$AWS_INSTALL_DIR/bin"
    local AWS_ARCHIVE="/tmp/awscliv2.zip"

    print "Fetching AWS CLI v2"

    mkdir -p "$BUILD_DIR/vendor"

    if ! command -v curl >/dev/null 2>&1; then
        echo "ERROR: curl is required to download AWS CLI."
        return 1
    fi

    if ! command -v unzip >/dev/null 2>&1; then
        echo "ERROR: unzip is required to install AWS CLI."
        return 1
    fi

    if ! curl -fsSL \
        "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" \
        -o "$AWS_ARCHIVE"; then
        echo "ERROR: Failed to download AWS CLI."
        return 1
    fi

    rm -rf "$BUILD_DIR/vendor/aws"

    if ! unzip -qq -d "$BUILD_DIR/vendor" "$AWS_ARCHIVE"; then
        echo "ERROR: Failed to extract AWS CLI installer."
        rm -f "$AWS_ARCHIVE"
        return 1
    fi

    print "Installing AWS CLI into slug"

    if ! "$BUILD_DIR/vendor/aws/install" \
        --install-dir "$AWS_INSTALL_DIR" \
        --bin-dir "$AWS_BIN_DIR" \
        --update; then
        echo "ERROR: AWS CLI installation failed."
        rm -f "$AWS_ARCHIVE"
        return 1
    fi

    rm -rf "$BUILD_DIR/vendor/aws"
    rm -f "$AWS_ARCHIVE"

    if [[ ! -x "$AWS_BIN_DIR/aws" ]]; then
        echo "ERROR: AWS CLI executable was not created at $AWS_BIN_DIR/aws"
        return 1
    fi

    # Make AWS CLI available during the build.
    export PATH="$AWS_BIN_DIR:$PATH"

    print "AWS CLI installation completed"
    "$AWS_BIN_DIR/aws" --version

    # Add AWS CLI to the runtime environment.
    mkdir -p "$BUILD_DIR/.profile.d"

    cat > "$BUILD_DIR/.profile.d/awscli.sh" <<'EOF'
#!/usr/bin/env bash
export PATH="/app/vendor/awscli/bin:$PATH"
EOF

    chmod +x "$BUILD_DIR/.profile.d/awscli.sh"
}
```
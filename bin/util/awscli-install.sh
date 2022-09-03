#!/usr/bin/env bash

# shellcheck source=util/common.sh
source "$BP_DIR/bin/util/common.sh"

function awicli_install(){
	APT_CACHE_DIR="$CACHE_DIR/apt/cache"
	APT_STATE_DIR="$CACHE_DIR/apt/state"
	mkdir -p "$APT_CACHE_DIR/archives/partial"
	mkdir -p "$APT_STATE_DIR/lists/partial"
	APT_OPTIONS="-o debug::nolocking=true -o dir::cache=$APT_CACHE_DIR -o dir::state=$APT_STATE_DIR"
	print "Updating apt caches"
	apt-get $APT_OPTIONS update | indent

	print "AWS cli install"
	print "Fetching AWS CLI into slug"
	#curl --progress-bar -o /tmp/awscli-bundle.zip "https://s3.amazonaws.com/aws-cli/awscli-bundle.zip"
	curl --progress-bar -o /tmp/awscliv2.zip "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip"
	unzip -qq -d "$BUILD_DIR/vendor" /tmp/awscliv2.zip

	print "adding installer script into app/.profile.d"
	mkdir -p ${BUILD_DIR}/.profile.d
	cp $BP_DIR/profile/* $BUILD_DIR/.profile.d/
	cat <<EOF >${BUILD_DIR}/.profile.d/install_awscli.sh
	chmod +x /app/vendor/aws/install
	/app/vendor/aws/install -i /app/vendor/awscli -b /app/vendor/awscli/bin
	chmod u+x /app/vendor/awscli/bin/aws
	mkdir -p ~/.aws
	touch ~/.aws/credentials
	touch ~/.aws/config
	chmod +w ~/.aws/credentials
	chmod +w ~/.aws/config
	/app/vendor/awscli/bin/aws --version
	EOF
	chmod +x $BUILD_DIR/.profile.d/install_awscli.sh

	#cleaning up
	rm -rf /tmp/awscli*
	print "aws cli installation done"
}

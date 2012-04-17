#!/bin/bash
# starts warden daemon

set -uxe

# only set it up if warden isn't running
[ -S /tmp/warden.sock ] && (echo '["ping"]' | nc -U /tmp/warden.sock) && exit 1

# [ -n "$TMP" ] || TMP=$(mktemp -d)
[ -n "$TMP" ] || TMP=/tmp/warden.TzT
rsync -a $PWD/.git $TMP
git submodule foreach --quiet "set -xe; TMP=$TMP;" 'rsync -a $PWD/.git $TMP/$path'
cd $TMP
git reset --hard
git submodule foreach --quiet 'git reset --quiet --hard'
git submodule update --init
git status
source ~/.cloudfoundry_deployment_profile
cd warden
# hack to increase disk size
pushd root/linux/skeleton
dd if=/dev/null of=fs bs=1 seek=10G
mkfs.ext4 -F -O ^has_journal fs
popd
bundle install
sudo aptitude install debootstrap linux-image-generic-lts-backport-oneiric
unset SSH_AUTH_SOCK SSH_CLIENT SSH_CONNECTION SSH_TTY
bundle exec rake setup
sudo -s << WARDEN
source ~/.cloudfoundry_deployment_profile
bundle exec rake warden:start[config/linux.yml]
WARDEN

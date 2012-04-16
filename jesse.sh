#!/bin/bash
# consume containers to run dev_setup

set -u -x -e

[ -S /tmp/warden.sock ] && (echo '["ping"]' | nc -U /tmp/warden.sock) || exit 1
source ~/.cloudfoundry_deployment_profile

cd ~/cloudfoundry/vcap
pushd warden; bundle install; popd
REPL=$PWD/warden/bin/warden-repl
SCRATCH=$(mktemp -d /tmp/vcap_scratch.XXX)
# use a bare repo as cache
rsync -rl $PWD/.git/ /tmp/vcap.git
git clone /tmp/vcap.git $SCRATCH
git submodule foreach "set -xe; rsync -rl \$PWD /$SCRATCH/\$path"

(
  cd $SCRATCH
  git reset --hard
  git submodule foreach 'git reset --quiet --hard'
  git submodule sync
  git submodule update --init --recursive
  git status
)

TEST_RUNNER=$(mktemp /tmp/run_in_jail.XXX)
cat > $TEST_RUNNER <<EOS
#!/bin/bash
set -uxe

apt-get update -qq
apt-get install -y git-core

cd cloudfoundry/vcap
git status

time ~/cloudfoundry/vcap/dev_setup/bin/vcap_dev_setup -a
EOS
chmod +x $TEST_RUNNER

HANDLE=$($REPL -c "create grace_time:7200 disk_size_mb:10240 bind_mount:/var/cache/dev_setup,/var/cache/dev_setup,rw bind_mount:$SCRATCH,/root/cloudfoundry/vcap,rw")
$REPL -c "copy $HANDLE in $TEST_RUNNER $TEST_RUNNER"

W=/tmp/warden.TzT
cd $W/vcap/warden/root/linux/instances
sudo ssh -F $HANDLE/ssh/ssh_config root@container -t $TEST_RUNNER

rm -rvf $TEST_RUNNER

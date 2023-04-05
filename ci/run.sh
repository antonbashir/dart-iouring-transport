#!/bin/bash -e

IP="192.168.122.2"

wait-for-it "$IP:22" -t 300 -s -- echo ready

set -x

ssh -o "StrictHostKeyChecking=no" "runner@$IP" uname -a
scp -r $(pwd) "runner@$IP:/home/runner"
ssh "runner@$IP" "cd dart-iouring-transport/dart && test/test.exe"

if [ $? -eq 0 ]
then
    sudo virsh shutdown inner
    until sudo virsh domstate inner | grep shut; do
        sleep 5
    done
    exit 0
else
  sudo virsh shutdown inner
  until sudo virsh domstate inner | grep shut; do
      sleep 5
  done
  exit 1
fi
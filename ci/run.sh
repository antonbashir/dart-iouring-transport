#!/bin/bash -e

IP="192.168.122.2"

wait-for-it "$IP:22" -t 300 -s -- echo ready

set -x

ssh -o "StrictHostKeyChecking=no" "runner@$IP" uname -a
scp -r $(pwd) "runner@$IP:/home/runner"
ssh "runner@$IP" "sudo apt-get update && sudo apt install -y -q wget apt-transport-https && wget -qO- https://dl-ssl.google.com/linux/linux_signing_key.pub | sudo gpg --dearmor -o /usr/share/keyrings/dart.gpg && sudo echo 'deb [signed-by=/usr/share/keyrings/dart.gpg arch=amd64] https://storage.googleapis.com/download.dartlang.org/linux/debian stable main' | sudo tee /etc/apt/sources.list.d/dart_stable.list && sudo apt-get update && sudo apt-get install -y -q dart"
ssh "runner@$IP" "cd dart-iouring-transport && cd dart && dart pub get && dart compile exe test/test.dart && test/test.exe"

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
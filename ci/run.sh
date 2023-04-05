#!/bin/bash -e

IP="192.168.122.2"

wait-for-it "$IP:22" -t 300 -s -- echo ready

set -x

ssh -o "StrictHostKeyChecking=no" "runner@$IP" uname -a
scp -r $(pwd) "runner@$IP:/home/runner"
ssh "runner@$IP" "sudo apt-get update"
ssh "runner@$IP" "sudo apt install build-essential cmake wget apt-transport-https"
ssh "runner@$IP" "wget -qO- https://dl-ssl.google.com/linux/linux_signing_key.pub | sudo gpg --dearmor -o /usr/share/keyrings/dart.gpg"
ssh "runner@$IP" "sudo echo 'deb [signed-by=/usr/share/keyrings/dart.gpg arch=amd64] https://storage.googleapis.com/download.dartlang.org/linux/debian stable main' | sudo tee /etc/apt/sources.list.d/dart_stable.list"
ssh "runner@$IP" "sudo apt-get update"
ssh "runner@$IP" "sudo apt-get install dart"
ssh "runner@$IP" "cd dart-iouring-transport && cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo . && make -j && cd dart && dart pub get && dart run test/test.dart"

sudo virsh shutdown inner
until sudo virsh domstate inner | grep shut; do
    sleep 5
done

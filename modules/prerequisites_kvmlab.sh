# My test lab script ... 
# Ran as non-root user

templatename=bs_template.qcow2
vmname=bsnode1

cd /var/lib/libvirt/images
sudo qemu-img create -f qcow2 -b ${templatename} ${vmname}.qcow2
sudo qemu-img info ${vmname}.qcow2
# Instantiate the VM
sudo virt-install --name=${vmname} --memory=2048 --vcpus=2 \
  --cpu=host --os-type=linux --os-variant=rhel7 \
  --disk path=/var/lib/libvirt/images/${vmname}.qcow2,device=disk,format=qcow2 \
  --network=network=brpxe,model=virtio \
  --network=network=brprivate,model=virtio \
  --network=network=brpublic,model=virtio \
  --graphics spice --virt-type=kvm --import

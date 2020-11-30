#!/bin/bash
# Author Brokedba https://twitter.com/BrokeDba
RED=$'\e\033[0;31m'
GREEN=$'\e\033[0;32m'
BLUE=$'\e\033[1;34m'
NC=$'\e\033[0m' # No Color
echo "******* Azure Image Selecta ! ************"
echo "Choose your Image ||{**}||${GREEN} " 
echo 
PS3='Select an option and press Enter: '
options=("RHEL" "CentOS" "Oracle Linux" "Ubuntu" "Windows" "Suse" "Exit?")
select opt in "${options[@]}"
do 
  case $opt in
        "RHEL")
          az vm image list -f RHEL -s 83-gen2 --all -p RedHat --query 'reverse(sort_by(@,&version))[:1].{Name:offer,Publisher:publisher,sku:sku,Urn:urn,Version:version}'
          az vm image list -f RHEL -s 7lvm-gen2 --all -p RedHat --query 'reverse(sort_by(@,&version))[:1].{Name:offer,Publisher:publisher,sku:sku,Urn:urn,Version:version}'
          ;;
        "CentOS")
          az vm image list -f CentOS -s 8 -p OpenLogic --all --query 'reverse(sort_by(@,&version))[:1].{Name:offer,Publisher:publisher,sku:sku,Urn:urn,Version:version}'
          az vm image list -f CentOS -s 7.7 -p OpenLogic --all --query 'reverse(sort_by(@,&version))[:1].{Name:offer,Publisher:publisher,sku:sku,Urn:urn,Version:version}'
          ;;

        "Oracle Linux")
          az vm image list -f Oracle-Linux --all  -s ol8 -p Oracle --query '[:1].{Name:offer,Publisher:publisher,sku:sku,Urn:urn,Version:version}'
          az vm image list -f Oracle-Linux --all  -s ol77 -p Oracle --query '[:1].{Name:offer,Publisher:publisher,sku:sku,Urn:urn,Version:version}'
          ;;  

        "Ubuntu")
           az vm image list -l eastus -p Canonical -f UbuntuServer --all  --query 'reverse(sort_by(@,&version))[:1].{Name:offer,Publisher:publisher,sku:sku,Urn:urn,Version:version}'
          ;;
        "Windows")
          az vm image list -f WindowsServer -s 2016 -p MicrosoftWindowsServer --query 'reverse(sort_by(@,&version))[:1].{Name:offer,Publisher:publisher,sku:sku,Urn:urn,Version:version}'
          ;;
        "Suse")
         az vm image list -f SLES -p SUSE --query 'reverse(sort_by(@,&version))[:1].{Name:offer,Publisher:publisher,sku:sku,Urn:urn,Version:version}'
          ;;          
        "Exit?")
          break 
          ;;                              
        *) echo "invalid option";;
  esac
done 
echo "*********************"
echo "list a sample of general puprose vm sizes (D Series) in eastus region with 4VCPUs . "
echo
  az vm list-sizes -l eastus --query "sort_by(@,&memoryInMb)[?numberOfCores == \`4\` && contains(name,\`_D4\`)]|[0:20].{VM:name,VCPUS:numberOfCores,maxDisks:maxDataDiskCount, Size:hardwareProfile.vmSize,Memory_MB:memoryInMb,OSDisk_maxMB:osDiskSizeInMb,UserDisk_maxMB:resourceDiskSizeInMb}"
 
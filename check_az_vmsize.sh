#!/bin/bash
# Author Brokedba https://twitter.com/BrokeDba
RED=$'\e\033[0;31m'
GREEN=$'\e\033[0;32m'
BLUE=$'\e\033[1;34m'
NC=$'\e\033[0m' # No Color
# location=eastus
location=canadacentral
echo 
echo " Note: Default ${RED}Location${NC} is ${GREEN}$location${NC}. To change it, modify the variable ${GREEN}\$location${NC} at the top of this script" 
echo "                  ******* ${BLUE}Azure VM size Selecta ! ${NC}************"
echo "                           Choose your VM compute ||{**}||"
echo "                  *********************************************${GREEN}" 
echo 
echo "List all vm sizes in ${RED}${location}${GREEN} region depending on the CPU and Series selected. "
echo
echo  ">> VM size = number of CPU${NC}"
while true; do
PS3='Select a number of cores and press Enter: '
options=("1 VCPU" "2 VCPUs" "4 VCPUs" "8 VCPUs" "16 VCPUs")
select opt in "${options[@]}"
do 
  case $opt in
        "1 VCPU")
        cpu=1
        break
        ;;
         
        "2 VCPUs")
        cpu=2
        break
          ;;
        "4 VCPUs")
        cpu=4
        break   
        ;; 
        "8 VCPUs")
        cpu=8
        break  
        ;;
        "16 VCPUs")
        cpu=16
        break
        ;;                          
        *) echo "invalid option";;
  esac
done 

echo "${GREEN}>> Pick VM compute Series${NC}"
PS3='Select a VM series and press Enter: '
options=("A Series (Entry-level)" "B Series (Burstable)" "D Series (General purpose)" "E Series (Optimized for in-memory)" "M Series (Memory optimized )" "G Series (Memory and storage optimized )" "F Series (Compute optimized )")
select opt in "${options[@]}"
do 
  case $opt in
        "A Series (Entry-level)")
        serie="_A"
        break
        ;;
        "B Series (Burstable)")
        serie="_B"
        break
          ;;
        "D Series (General purpose)")
        serie="_D"
        break   
        ;; 
        "E Series (Optimized for in-memory)")
        serie="_E"
        break 
        ;; 
        "M Series (Memory optimized )")
        serie="_M"
        break 
        ;; 
        "G Series (Memory and storage optimized )")
        serie="_G"
        break 
        ;; 
        "F Series (Compute optimized )")
        serie="_F"
        break  
        ;;       
        *) echo "invalid option";;
  esac
done 
vm_size=$(az vm list-sizes -l eastus --query "length([?numberOfCores == \`$cpu\` && contains(name, \`$serie\`)])" -o tsv)
if [ -z $vm_size ];
then
echo "${GREEN}There is no listing for such specs please try again or hit CTRL+C${NV}"
else
echo "${GREEN}********************************************************${NC}"
echo "${GREEN}      Non constrained CPU VM list (Using list-sizes)       ${NC}"
echo "${GREEN}********************************************************${NC}"
az vm list-sizes -l $location --query "sort_by(@,&name)[?numberOfCores == \`$cpu\` && contains(name ,\`${serie}${cpu}\`) && !contains(name,'-')].{VM:name,VCPUS:numberOfCores,Memory_MB:memoryInMb,maxDisks:maxDataDiskCount,OSDisk_maxMB:osDiskSizeInMb,TempDisk_maxMB:resourceDiskSizeInMb} " -o table #| sort_by(@,&VM)
echo

echo "${GREEN}********************************************************${NC}"
echo "${GREEN}       Including Constrained CPU VM list (Using list-skus) ${NC}"
echo "${GREEN}********************************************************${NC}"
#az vm list-skus -z --resource-type  virtualMachines --size "${serie}${cpu}" -l $location --query "[?contains(name, \`${serie}${cpu}a\`) || contains(name, \`${serie}${cpu}d\`) || contains(name, \`${serie}${cpu}s\`)].{name:name,size:size,VCPU:capabilities[?name==\`vCPUs\`].value|[0],MemoryGB:capabilities[?name==\`MemoryGB\`].value|[0],maxDisks:capabilities[?name==\`MaxDataDiskCount\`].value|[0],OSDisk_maxMB:capabilities[?name==\`OSVhdSizeMB\`].value|[0],UserDisk_maxMB:capabilities[?name==\`MaxResourceVolumeMB\`].value|[0],zones:to_string(locationInfo[0].zones),location:locations[]|[0]} | sort_by(@,&name)| sort_by(@,&VCPU)" -o table
az vm list-skus -z --resource-type  virtualMachines --size "${serie}" -l $location --query "[?capabilities[?name==\`vCPUsAvailable\`].value|[0] == '${cpu}'].{name:name,VCPU:capabilities[?name==\`vCPUs\`].value|[0],ActualVCPU:capabilities[?name==\`vCPUsAvailable\`].value|[0],MemoryGB:capabilities[?name==\`MemoryGB\`].value|[0],maxDisks:capabilities[?name==\`MaxDataDiskCount\`].value|[0],OSDiskMB:capabilities[?name==\`OSVhdSizeMB\`].value|[0],TempDisk_MaxMB:capabilities[?name==\`MaxResourceVolumeMB\`].value|[0],MaxVnics:capabilities[?name==\`MaxNetworkInterfaces\`].value|[0],zones:to_string(locationInfo[0].zones),region:locations[]|[0]} | reverse(sort_by(@,&name))" -o table

break
#contains(name, \`${serie}\`) &&
fi
done

# 
# az vm list-skus -z --resource-type  virtualMachines --size $serie -l eastus --query "[?contains(capabilities[?name==\`vCPUs\`].value,\`$memo\`)].{name:name,size:size,VCPU:capabilities[?name==\`vCPUs\`].value|[0],MemoryGB:capabilities[?name==\`MemoryGB\`].value|[0],OSDisk_maxMB:capabilities[?name==\`OSVhdSizeMB\`].value|[0],UserDisk_maxMB:capabilities[?name==\`MaxResourceVolumeMB\`].value|[0],zones:to_string(locationInfo[0].zones),location:locations[]|[0]} | sort_by(@,&name)| sort_by(@,&VCPU)"
# az vm list-sizes -l eastus --query "sort_by(@,&memoryInMb)[?numberOfCores == \`$cpu\` && memoryInMb == \`$memo\` && contains(name ,\`$Serie\`)].{VM:name,VCPUS:numberOfCores,Memory_MB:memoryInMb,maxDisks:maxDataDiskCount,OSDisk_maxMB:osDiskSizeInMb,UserDisk_maxMB:resourceDiskSizeInMb} | sort_by(@,&VM)"
# echo  "********* Memory selecta ***********"

# PS3='Select the RAM size and press Enter: '
# options=("0.5GB" "1GB" "2Gb" "4GB" "8GB" "16GB" "32GB")
# select opt in "${options[@]}"
# do 
#   case $opt in
#         "0.5GB")
#         mem=512
#         break
#         ;;
#         "1GB")
#         mem=1024
#         break
#           ;;
#         "2GB")
#         mem=2048
#         break   
#         ;; 
#         "4GB")
#         mem=4096
#         break  
#         ;;
#         "8GB")
#         mem=8192
#         break
#         ;;     
#         "16GB")
#         mem=16384
#         break
#         ;;
#         "32GB")
#         mem=32768
#         break
#         ;;                     
#         *) echo "invalid option";;
#   esac
# done 

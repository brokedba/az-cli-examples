#!/bin/bash
# Author Brokedba https://twitter.com/BrokeDba
set -o pipefail
echo "******* Azure VM launch ! ************"
echo
RED=$'\e\033[0;31m'
GREEN=$'\e\033[0;32m'
BLUE=$'\e\033[1;34m'
NC=$'\e\033[0m' # No Color
echo -e "Note: ${BLUE} Standard_B1s${GREEN} is the minimum vm size supporting linux & windows but you can  pick a different size bt editing \$vm_size variable ${NC}"
#read -p "Enter the Shape name you wish to create [Standard_B1s]: " shape
osdisk_size=20
vm_size="Standard_B1s"
az vm list-sizes -l eastus --query "[?name ==\`$vm_size\`].{VM:name,VCPUS:numberOfCores,Memory_MB:memoryInMb,maxDisks:maxDataDiskCount,OSDisk_maxMB:osDiskSizeInMb,UserDisk_maxMB:resourceDiskSizeInMb} "
echo
echo "********** Resource Group ***********"
while true; do
  echo
  rg_list=$(az group list --query "sort_by(@,&name)[].{Name:name}" -o  tsv)
    if [ -z "$rg_list" ];
    then  
     echo ${RED} no resource group available in this tenancy. Please run create_rg.sh${NC} ;
     exit 1
    fi
  az group list --query "sort_by(@,&name)[].{Name:name,location:location}"
  echo
  read -p "select the resource Group you wish to set for your resources []: " rg_name
  rg_name=${rg_name:-$rg_name}
  rg_name=$(az group show -g "$rg_name" --query name -o tsv)
    if [ -n "$rg_name" ];
    then  
     echo "selected group name :${GREEN} $rg_name ${NC}"
     echo ...
     break
    else echo "${RED}Resource group $rg_name doesn't exist Please retry.${NC}"
    fi 
done
read -p "Enter the name of your new Instance [Demo-Cli-Instance]: " instance_name
instance_name=${instance_name:-"Demo-Cli-Instance"}
 echo -----
 echo selected Instance name :${GREEN} $instance_name ${NC}
 echo Vm size :${GREEN} $vm_size${NC}

echo
echo "********** Network ***********"
#################
# VNET 
#################
echo
echo "         ****${GREEN} VNET ${NC}****"
vnet_list=$(az network vnet list -g "$rg_name")

if [ -z "$vnet_list" ];
then  echo " ${RED}No VNET is associated to $rg_name resource group. Please create a new VNET using ./create_vnet.sh !${NC}";
exit 1
else 
 while true; do
 az network vnet list -g "$rg_name" --query "[].{VNET:name,vnet_CIDR:addressSpace.addressPrefixes[0],resource_group:resourceGroup,region:location}"
 read -p "select the VNET Name for your new instance [$vnet_name]: " vnet_name
 vnet_name=${vnet_name:-$vnet_name}
 vnet_cidr=$(az network vnet show -g "$rg_name"  -n "$vnet_name" --query 'addressSpace.addressPrefixes' -o tsv)
if [ -n "$vnet_cidr" ];
then  
     echo selected VNET name :${GREEN} $vnet_name${NC}
     while true; do
     echo "          ****${GREEN} SUBNET ${NC}***"
     sub_list=$(az network vnet subnet list -g "$rg_name" --vnet-name $vnet_name ) 
     if  [ -n "$sub_list" ];
     then echo 
      az network vnet subnet list -g "$rg_name" --vnet-name $vnet_name --query '[].{Subnet:name,CIDR:addressPrefix,resourceGroup:resourceGroup}'
      read -p "Select The Subnet for your new instance [$sub_name]: " sub_name
      sub_name=${sub_name:-$sub_name}
      sub_id=$(az network vnet subnet show -g "$rg_name" --vnet-name $vnet_name  -n $sub_name --query name -o tsv)
      if  [ -n "$sub_id" ];
      then echo selected subnet name : ${GREEN} $sub_name ${NC} 
      echo
      echo "${GREEN} Subnet exist =>${NC}${BLUE} Checking  the OS menu and Security group rules ${NC}"
      echo ...
      break
      else echo " ${RED} The entered Subnet name doesn't exist for $vnet_name. Please retry ${NC}";
      fi 
     else echo " ${RED}No subnet is associated to $vnet_name VNET.${NC}";
     echo "${BLUE}creating the missing subnet ${NC}"
## SUBNET ADDITION     
     while true; do
     echo
     echo -e Note : ${GREEN}make sure all bytes beyond network prefix length are always zeroed  or you\'ll have an error ${NC}
            sub_cidr=$(echo "$vnet_cidr" |awk -F[/] '{ print $1"/"++$2}')
            read -p " Enter the subnet network CIDR to assign within $vnet_cidr to '/29' [${BLUE}$sub_cidr${NC}]: " sub_cidr
            sub_cidr=${sub_cidr:-"$sub_cidr"};
            if [ "$sub_cidr" = "" ] 
            then echo -e "${RED}Entered CIDR is empty. Please retry${NC}"
            else
              REGEX='^(((25[0-5]|2[0-4][0-9]|1?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|1?[0-9][0-9]?))(\/([8-9]|[1][0-9]|[2][0-9]))([^0-9.]|$)'
                  vnet_pref=$(echo $vnet_cidr | awk -F/ '{print $2}')
                  sub_pref=$(echo "$sub_cidr" | awk -F/ '{print $2}')
              if [[ "$sub_cidr" =~ $REGEX ]]  && (( $sub_pref >= $vnet_pref && $sub_pref <= 29 ))
              then
                echo ...
                while true; do
                read -p "Enter the subnet name you wish to add [${BLUE}CLI-SUB${NC}]: " sub_name
                sub_name=${sub_name:-CLI-SUB}
                echo -e selected Subnet name : ${GREEN}$sub_name${NC}
                break
                done  
              break
              else
                        echo -e "${RED} Entered Subnet CIDR is not valid. Please retry${NC}"
              fi
            fi    
      done
            echo -e " ====${GREEN} Created Subnet details${NC} ===="
            az network vnet subnet create --address-prefixes "$sub_cidr" --vnet-name $vnet_name -g "$rg_name" -n $sub_name --query '{Subnet:name,CIDR:addressPrefix,resourceGroup:resourceGroup}'
            break 
# SUBNET ADDITION END        
     fi
     done 
     break
else echo "${RED}The entered VNET name is not valid. Please retry ${NC}"; 
 fi
 done
fi
########################
# Network Security Group
########################
echo
echo "************ Network security Security Group ! ************"
  sg_name=$(az network vnet subnet show -g "$rg_name" --vnet-name $vnet_name -n $sub_name --query networkSecurityGroup.id -o tsv|awk -F[/] '{print $9}')     
  if [ -z "$sg_name" ];
  then                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            
  # 1. Create a network security group for the front-end subnet
      echo  "${BLUE}        NSG not present creating a new one with Web  ${NC}" 
      echo "${BLUE}creating the missing dedicated security Group for subnet $sub_name${NC}"
      sg_name=$(az network nsg create -g "$rg_name" -n sg_"${sub_name}"_WEB  --query 'NewNSG.name' -o tsv)
            echo -e "${NC}****************${GREEN}  Security Group detail${NC}  ******************"
            echo
            echo  "${GREEN}Creating the instance with the below SG .${NC}"  
            az network nsg rule create -g "$rg_name" --nsg-name "$sg_name" -n Allow-WEB-IN --access Allow --protocol Tcp --direction Inbound --priority 100 --source-address-prefix Internet --source-port-range "*" --destination-address-prefix "*" --destination-port-range 80 443 --description "HTTP-HTTPS ingress trafic"  --query '{Name:name,Source:sourceAddressPrefix,PORT:to_string(destinationPortRanges),Type:direction,Priority:priority}'
            echo  "3. dedicated security Group ingress rules exists  PORT (80,443)."
          echo "****  ${GREEN}associate the NSG with the subnet $sub_name  ${NC}****"
          echo
          az network vnet subnet update --vnet-name $vnet_name --name $sub_name -g "$rg_name" --network-security-group "$sg_name"  
          max_priority=$(az network nsg show -g "$rg_name" -n "$sg_name" --query "securityRules[?direction==\`Inbound\`].priority|max(@)" -o tsv)
  else
      echo "${GREEN} checking the associated  NSG : $sg_name ${NC}"
      # check if the assigned nsg has the required inbound rules
      #  
      nsg_port_single=$(az network nsg show -g "$rg_name" -n "$sg_name" --query securityRules[?direction==\`Inbound\`].destinationPortRange -o tsv)
      nsg_port_range=$(az network nsg show -g "$rg_name"  -n "$sg_name" --query securityRules[?direction==\`Inbound\`].destinationPortRanges[] -o tsv)
      max_priority=$(az network nsg show -g "$rg_name" -n "$sg_name" --query "securityRules[?direction==\`Inbound\`].priority|max(@)" -o tsv)
      #
      [[ " $nsg_port_single $nsg_port_range " =~ [[:space:]]22[[:space:]] ]] && ssh=22
      [[ " $nsg_port_single $nsg_port_range " =~ [[:space:]]80[[:space:]] ]] && http=80
      [[ " $nsg_port_single $nsg_port_range " =~ [[:space:]]443[[:space:]] ]] && https=443
      [[ " $nsg_port_single $nsg_port_range " =~ [[:space:]]3389[[:space:]] ]] && rdp=3389
        if [ -z "$http" ];
        then
             echo "${BLUE}opening Port 80${NC}"
            let "max_priority++"
            az network nsg rule create -g "$rg_name" --nsg-name "$sg_name" -n Allow-HTTP-IN --access Allow --protocol Tcp --direction Inbound --priority "$max_priority" --source-address-prefix Internet --source-port-range "*"  --destination-address-prefix "*" --destination-port-range 80  --description "HTTP ingress trafic"  --query '{Name:name,Source:sourceAddressPrefix,PORT:destinationPortRange,Type:direction,Priority:priority}'
        fi
        if [ -z "$https" ];
        then
             echo "${BLUE}opening Port 443${NC}"
            let "max_priority++"
            az network nsg rule create -g "$rg_name" --nsg-name "$sg_name" -n Allow-HTTPS-IN --access Allow --protocol Tcp --direction Inbound --priority "$max_priority" --source-address-prefix Internet --source-port-range "*"  --destination-address-prefix "*" --destination-port-range 443 --description "HTTPS ingress trafic"  --query '{Name:name,Source:sourceAddressPrefix,PORT:destinationPortRange,Type:direction,Priority:priority}'
        fi
  fi      
    echo "${GREEN}==${BLUE} Creating the instance with the below NSG .${NC}"    
    az network nsg show -g "$rg_name" -n "$sg_name" --query "{Name:name,Combo_rule_Ports:to_string(securityRules[?direction==\`Inbound\`].destinationPortRanges[]),single_rule_Ports:to_string(securityRules[?direction==\`Inbound\`].destinationPortRange),sub:subnets[].id,resourceGroup:resourceGroup}" -o json        
#################
# Az IMAGE
#################
echo "4. Choose your Image ||{**}||" 
echo "******* Azure Image Selecta ! ************"
echo "Choose your Image ||{**}||${GREEN} " 
echo 
PS3='Select an option and press Enter: '
options=("RHEL" "CentOS" "Oracle Linux" "Ubuntu" "Windows" "Suse" "Abort?")
select opt in "${options[@]}"
do 
  case $opt in
        "RHEL")
          az vm image list -f RHEL -s 7lvm-gen2 --all -p RedHat --query 'reverse(sort_by(@,&version))[:1].{Name:offer,Publisher:publisher,sku:sku,Urn:urn,Version:version}'
          urn=$(az vm image list -f RHEL -s 7lvm-gen2 --all -p RedHat --query 'reverse(sort_by(@,&version))[:1].urn' -o tsv)
          userdata="--custom-data @cloud-init/rhel_userdata.txt"
          OS="REDHAT"
          user="azureuser"
          break
          ;;
        "CentOS")
          az vm image list -f CentOS -s 7.7 -p OpenLogic --all --query 'reverse(sort_by(@,&version))[:1].{Name:offer,Publisher:publisher,sku:sku,Urn:urn,Version:version}'
          urn=$(az vm image list -f CentOS -s 7.7 -p OpenLogic --all --query 'reverse(sort_by(@,&version))[:1].urn' -o tsv)
          userdata="--custom-data @cloud-init/centos_userdata.txt"
          OS="CENTOS"
          user="centos"
          break
          ;;

        "Oracle Linux")
          az vm image list -f Oracle-Linux --all  -s ol77 -p Oracle --query '[:1].{Name:offer,Publisher:publisher,sku:sku,Urn:urn,Version:version}'
          urn=$(az vm image list -f Oracle-Linux --all  -s ol77 -p Oracle --query '[:1].urn' -o tsv)
          userdata="--custom-data @cloud-init/olinux_userdata.txt"
          OS="Oracle Linux"
          user="opc"
          break
          ;;  

        "Ubuntu")
          az vm image list -l eastus -p Canonical -f UbuntuServer --all  --query 'reverse(sort_by(@,&version))[:1].{Name:offer,Publisher:publisher,sku:sku,Urn:urn,Version:version}'
          urn=$(az vm image list -l eastus -p Canonical -f UbuntuServer --all  --query 'reverse(sort_by(@,&version))[:1].urn' -o tsv)
          userdata="--custom-data @cloud-init/ubto_userdata.txt"
          OS="Ubuntu"
          user="ubuntu"
          break
          ;;

        "Windows")
          az vm image list -f WindowsServer -s 2016 -p MicrosoftWindowsServer --query 'reverse(sort_by(@,&version))[:1].{Name:offer,Publisher:publisher,sku:sku,Urn:urn,Version:version}'
          urn=$(az vm image list -f WindowsServer -s 2016 -p MicrosoftWindowsServer --query 'reverse(sort_by(@,&version))[:1].urn' -o tsv)
          userdata="--custom-data @cloud-init/Win_userdata.txt"
          OS="Windows"
          user="azureuser"
          break
          ;;

        "Suse")
          az vm image list -f SLES-15-sp2-byos -p SUSE --all --query 'reverse(sort_by(@,&version))[:1].{Name:offer,Publisher:publisher,sku:sku,Urn:urn,Version:version}'
          urn=$(az vm image list -f SLES-15-sp2-byos -p SUSE --all --query 'reverse(sort_by(@,&version))[:1].urn' -o tsv)
          userdata="--custom-data @cloud-init/sles_userdata.txt"
          OS="SUSE"
          user="azureuser"
          break
          ;;  

        "Abort?")
          break 
          ;;                              
        *) echo "invalid option";;
  esac
done 
if [[ "$OS" == "Windows" ]];
then 
          if [ -z "$rdp" ];
          then
            echo "${BLUE}opening Port 3389 ..${NC}"
            let "max_priority++"
            az network nsg rule create -g "$rg_name" --nsg-name "$sg_name" -n Allow-RDP-IN --access Allow --protocol Tcp --direction Inbound --priority "$max_priority" --source-address-prefix Internet --source-port-range "*" --destination-address-prefix "*" --destination-port-range 3389 --description "RDP ingress trafic" --query '{Name:name,Source:sourceAddressPrefix,PORT:destinationPortRange,Type:direction,Priority:priority}'
          fi
else          
          if [ -z "$ssh" ];
          then
             echo "${BLUE}opening Port 22 ..${NC}"
            let "max_priority++"
            az network nsg rule create -g "$rg_name" --nsg-name "$sg_name" -n Allow-SSH-IN --access Allow --protocol Tcp --direction Inbound --priority "$max_priority" --source-address-prefix Internet --source-port-range "*" --destination-address-prefix "*" --destination-port-range 22 --description "SSH ingress trafic" --query '{Name:name,Source:sourceAddressPrefix,PORT:destinationPortRange,Type:direction,Priority:priority}'
          fi
fi

######################
# INSTANCE
######################
 echo =====${BLUE} Instance Deployment Detail${NC} ========
       echo
       echo "selected Subnet name : ${GREEN}$sub_name${NC}"
       echo "selected Instance name : ${GREEN}$instance_name${NC}"
       echo "selected instance Type: ${GREEN}$vm_size${NC}"
       echo "selected Security Group: ${GREEN}$sg_name${NC}"
       echo "user name   : ${GREEN}$user${NC}"
       echo "selected OS : ${GREEN}$OS${NC}"
  echo ...
 # Create a public IP addresses for the VM  
echo "${BLUE}Public IP creation... ${NC}"
az network public-ip create --resource-group $rg_name -n "${instance_name}_pubip" --allocation-method Dynamic --query "publicIp.{Name:name,location:location,stat:provisioningState,Allcoation:publicIpAllocationMethod}"
echo "${BLUE}Network interface creation... ${NC}"
# Create a network interface for the VM  
az network nic create -g "$rg_name" --vnet-name $vnet_name --subnet $sub_name -n "${instance_name}_Nic" --network-security-group "$sg_name" --public-ip-address "${instance_name}_Pubip" --query "{name:NewNIC.name,state:NewNIC.provisioningState,privateIP:NewNIC.ipConfigurations[]|[0].privateIpAddress}"
echo
echo " ==========================================="
echo  "${BLUE}Check the status of the new Instance${NC}"
echo " ==========================================="
echo The compute instance is being created. This will take few minutes ... 
if [[ "$OS" == "Windows" ]];
then 
  while true; do
  list="abc@123 P@$$w0rd P@ssw0rd P@ssword123 Pa$$word pass@word1 Password! Password1 Password22 iloveyou!" 
  read -p "Enter the windows password for [$instance_name] => Minimum:${BLUE}12 characters ;1 lower case character, 1 upper case character, 1 number and 1 special character.${NC}: " v_passwd
    v_passwd=${v_passwd:-$v_passwd}
    if [[ "${v_passwd//[^@#$%&*+=-!]/}" && "${v_passwd}" != "${v_passwd^^}" && "${v_passwd}" != "${v_passwd,,}" && "${v_passwd//[^0-9]/}" && $(echo "${#v_passwd}") -ge 12 ]] ;
      then 
      if [[ $list =~ (^|[[:space:]])"$v_passwd"($|[[:space:]]) ]] ; 
      then  echo "${RED}The entered password is disallowed. Please try another one ${NC}"; 
      else 
      break
      fi
    else echo "${RED}The entered password has less than 12 characters or doesn't match the password policy. Please try again ${NC}";
    fi 
  done
 az vm create -g "$rg_name" --name "$instance_name" --image "${urn}" --size $vm_size --nics "${instance_name}_Nic" --admin-username "$user" --admin-password "$v_passwd" --computer-name $(echo ${instance_name:0:15}) 
 pub_ip=$(az vm show -g "$rg_name" -n "$instance_name" -d --query "publicIps" -o tsv)
 az vm run-command invoke  -g "$rg_name" -n $instance_name --command-id SetRDPPort
 az vm run-command invoke  -g "$rg_name" -n $instance_name --command-id RunPowerShellScript --scripts @cloud-init/Win_userdata.ps1
 echo "Windows connection requires an RDP session using mstsc ==>${BLUE} user: ${user} server : ${pub_ip}  password: $v_passwd ${NC}"
else
read -p "Enter the Path of your ssh key [~/id_rsa_az.pub]: " public_key
public_key=${public_key:-~/id_rsa_az.pub}  # this is a GITbash path
private_key=$(echo "$public_key" |awk -F[.] '{print $1}')
echo selected public key:${GREEN} $public_key${NC}
# run the below which will launch the instance [If an existing NIC is specified, do not specify subnet, VNet, public IP or NSG.]
  az vm create -g "$rg_name" --name "$instance_name" --image "${urn}" --size $vm_size --nics "${instance_name}_Nic" $userdata --admin-username "$user" --ssh-key-values "$public_key" --os-disk-size-gb 20
  pub_ip=$(az vm show -g "$rg_name" -n "$instance_name" -d --query "publicIps" -o tsv)
  echo "ssh connection to the instance ==> sudo ssh -i $private_key ${user}@${pub_ip}"
fi
echo "${BLUE} Your website is ready at this IP :) :${GREEN} http://${pub_ip} ${NC}"
echo "VM termination command ==>${RED} az vm delete -g $rg_name -n $instance_name --yes ${NC}" 
echo "VNIC termination command ==>${RED} az network nic delete -g $rg_name -n ${instance_name}_Nic ${NC}"
echo "IP termination command ==>${RED} az network public-ip delete -g $rg_name -n ${instance_name}_Pubip ${NC}"
echo "VNET termination command ==>${RED} az network vnet delete -g $rg_name -n $vnet_name ${NC}"
echo "Disk termination command ==>${RED} az disk delete -g $rg_name -n $(az vm show -g $rg_name -d -n $instance_name --query 'storageProfile.osDisk.name' -o tsv)${NC}"
 

 
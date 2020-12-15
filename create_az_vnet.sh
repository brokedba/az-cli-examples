#!/bin/bash
# Author Brokedba https://twitter.com/BrokeDba
RED=$'\e\033[0;31m'
GREEN=$'\e\033[0;32m'
BLUE=$'\e\033[1;34m'
NC=$'\e\033[0m' # No Color
# echo -e "Note:  ${RED} VNET CIDR ${GREEN} range is /16 to /18 and last octet is always zeroed even if you specify a non zero value ${NC}"
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
  rg_name=$(az group show -g $rg_name --query name -o tsv)
    if [ -n "$rg_name" ];
    then  
     echo selected group name :${GREEN} $rg_name ${NC}
     echo ...
     break
    else echo "${RED}Resource group $rg_name doesn't exist Please retry.${NC}"
    fi 
done
#################
# VNET 
#################
 while true; do 
   read -p "Enter the VNET name you wish to create [${BLUE}CLI-VNET${NC}]: " vnet_name
   vnet_name=${vnet_name:-CLI-VNET}
   vnet_check=$(az network vnet show -g $rg_name -n $vnet_name --query name -o tsv)
   if [ -n "$vnet_check" ];
   then echo "${RED}The entered vnet exists alreay in $rg_name resource group. Please choose anothe one${NC}";
   else
   echo -e selected VNET name : ${GREEN}$vnet_name${NC}
   break
   fi
 done  
#################
# SUBNET
#################
 while true; do
  read -p "Enter the subnet name you wish to add [${BLUE}CLI-SUB${NC}]: " sub_name
  sub_name=${sub_name:-CLI-SUB}
 if [ -z "$sub_name" ];
    then  echo "${RED}The entered name is empty. Please retry. ${NC} ";
 else
  echo -e selected Subnet name : ${GREEN}$sub_name${NC}
  break
 fi
 done  

    while true; do
    echo
       echo -e Note : ${GREEN}make sure all bytes beyond network prefix length are always zeroed  or you\'ll have an error ${NC}
        read -p " Enter the VNET network CIDR to assign '/8-to-/29' [${BLUE}192.0.0.0/8${NC}]: " vnet_cidr
        vnet_cidr=${vnet_cidr:-"192.0.0.0/8"};
      if [ "$vnet_cidr" = "" ] 
          then echo -e "${RED}Entered CIDR is empty. Please retry${NC}"
          else
           REGEX='^(((25[0-5]|2[0-4][0-9]|1?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|1?[0-9][0-9]?))(\/([8-9]|[1][0-9]|[2][0-9]))([^0-9.]|$)'
           if [[ $vnet_cidr =~ $REGEX ]]
            then
            while true; do
            read -p " Enter the subnet network CIDR to assign within $vnet_cidr to '/29' [${BLUE}192.168.0.0/16${NC}]: " sub_cidr
            sub_cidr=${sub_cidr:-"192.168.0.0/16"};
            if [ "$sub_cidr" = "" ] 
            then echo -e "${RED}Entered CIDR is empty. Please retry${NC}"
            else
              REGEX='^(((25[0-5]|2[0-4][0-9]|1?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|1?[0-9][0-9]?))(\/([8-9]|[1][0-9]|[2][0-9]))([^0-9.]|$)'
                  vnet_pref=`echo $vnet_cidr | awk -F/ '{print $2}'`
                  sub_pref=`echo $sub_cidr | awk -F/ '{print $2}'`
              if [[ $sub_cidr =~ $REGEX ]]  && (( $sub_pref >= $vnet_pref && $sub_pref <= 29 ))
              then
                echo ...
                break
              else
                        echo -e "${RED} Entered Subnet CIDR is not valid. Please retry${NC}"
              fi
            fi    
            done
            break
            else    echo -e "${RED} Entered VNet CIDR is not valid. Please retry${NC}"
            fi             
          fi
    done  

echo -e " ====${GREEN} Created VNET details${NC} ===="
az network vnet create --address-prefixes $vnet_cidr --name $vnet_name --resource-group $rg_name --subnet-name $sub_name --subnet-prefixes $sub_cidr  --query '{VNET:newVNet.name,vnet_CIDR:newVNet.addressSpace.addressPrefixes[0],Subnet:newVNet.subnets[0].name, SUB_CIDR:newVNet.subnets[0].addressPrefix,resource_group:newVNet.resourceGroup,region:newVNet.location}'
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           
#################
# SECURITY GROUP
#################
# Create a network security group for the front-end subnet
echo
echo "************ Network security Security Group ! ************"
echo
echo "Choose The type of security Group you want to create ||{**}||${GREEN}"  
PS3='Select a security group ingress rule and press Enter: ' 
echo
options=("SSH port Only" "SSH, HTTP, and HTTPS" "HTTP,RDP, and HTTPS")
select opt in "${options[@]}"
do
  case $opt in
        "SSH port Only")
          sg_name=$(az network nsg create -g $rg_name -n sg_"${sub_name}"_SSH  --query 'NewNSG.name' -o tsv)
          echo
        echo -e "${NC}*******************${GREEN}  Security Group detail${NC}  ******************"
        echo
          az network nsg rule create -g $rg_name --nsg-name $sg_name -n Allow-SSH-IN --access Allow --protocol Tcp --direction Inbound --priority 100 --source-address-prefix Internet --source-port-range "*" --destination-address-prefix "*" --destination-port-range 22 --description "SSH ingress trafic" --query '{Name:name,Source:sourceAddressPrefix,PORT:destinationPortRange,Type:direction,Priority:priority}'
          break
          ;;
        "SSH, HTTP, and HTTPS")
         sg_name=$(az network nsg create -g $rg_name -n sg_"${sub_name}"_WEB  --query 'NewNSG.name' -o tsv)
        echo -e "${NC}*******************${GREEN}  Security Group detail${NC}  ******************"
        echo
         az network nsg rule create -g $rg_name --nsg-name $sg_name -n Allow-WEB-IN --access Allow --protocol Tcp --direction Inbound --priority 100 --source-address-prefix Internet --source-port-range "*" --destination-address-prefix "*" --destination-port-range 22 80 443 --description "SSH-HTTP-HTTPS ingress trafic"  --query '{Name:name,Source:sourceAddressPrefix,PORT:to_string(destinationPortRanges),Type:direction,Priority:priority}'
          break
          ;;
          
        "HTTP,RDP, and HTTPS")
        sg_name=$(az network nsg create -g $rg_name -n sg_"${sub_name}"_WEB_RDP  --query 'NewNSG.name' -o tsv)
        echo -e "${NC}*******************${GREEN}  Security Group detail${NC}  ******************"
        echo
          az network nsg rule create -g $rg_name --nsg-name $sg_name -n Allow-WEBRDP-IN --access Allow --protocol Tcp --direction Inbound --priority 100 --source-address-prefix Internet --source-port-range "*" --destination-address-prefix "*" --destination-port-range 3389 80 443 --description "RDP-HTTP-HTTPS ingress trafic" --query '{Name:name,Source:sourceAddressPrefix,PORT:to_string(destinationPortRanges),Type:direction,Priority:priority}'
          break
          ;;               
        *) echo "invalid option";;
  esac
done
echo
echo "****  ${GREEN}associate the NSG with the subnet $sub_name  ${NC}****"
echo
az network vnet subnet update --vnet-name $vnet_name --name $sub_name -g $rg_name --network-security-group $sg_name  
echo
echo "${GREEN}Cleanup commands:"
echo
echo -e "${NC} VNET delete command ==>${RED}az network vnet delete -g $rg_name -n $vnet_name" 
echo -e "${NC} SG delete command  ==>${RED} az network nsg delete  -g $rg_name -n $sg_name"
echo -e "${NC} Disassociate NGS from its Subnet =>${RED} az network vnet subnet update --vnet-name $vnet_name --name $sub_name -g $rg_name --network-security-group "" ${NC}"  


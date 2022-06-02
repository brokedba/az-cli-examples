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
######################
#      VNET
######################
 vnet_list=$(az network vnet list -g $rg_name)

if [ -z "$vnet_list" ];
then  echo " ${RED}No VNET is associated to $rg_name resource group. Please create a new VNET using ./create_vnet.sh !${NC}";
exit 1
else 
 while true; do
 az network vnet list -g $rg_name --query "[].{VNET:name,vnet_CIDR:addressSpace.addressPrefixes[0],resource_group:resourceGroup,region:location}"
 read -p "select the VNET Name for your new instance [$vnet_name]: " vnet_name
 vnet_name=${vnet_name:-$vnet_name}
 vnet_cidr=$(az network vnet show -g brokedba -n $vnet_name --query 'addressSpace.addressPrefixes' -o tsv)
if [ -n "$vnet_cidr" ];
then  
     echo selected VNET name :${GREEN} $vnet_name${NC}
     while true; do
     echo ****${GREEN} SUBNET ${NC}***
     sub_list=$(az network vnet subnet list -g $rg_name --vnet-name $vnet_name ) 
     if  [ -n "$sub_list" ];
     then echo 
      az network vnet subnet list -g $rg_name --vnet-name $vnet_name --query '[].{Subnet:name,CIDR:addressPrefix,resourceGroup:resourceGroup}'
      read -p "Select The Subnet for your new instance [$sub_name]: " sub_name
      sub_name=${sub_name:-$sub_name}
      sub_id=$(az network vnet subnet show -g $rg_name --vnet-name $vnet_name  -n $sub_name --query name -o tsv)
      if  [ -n "$sub_id" ];
      then echo selected subnet name : ${GREEN} $sub_name ${NC} 
      echo
      echo "${GREEN} Subnet exist =>${NC}${BLUE} Checking Security group rules ${NC}"
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
            sub_cidr=$(echo $vnet_cidr |awk -F[/] '{ print $1"/"++$2}')
            read -p " Enter the subnet network CIDR to assign within $vnet_cidr to '/29' [${BLUE}$sub_cidr${NC}]: " sub_cidr
            sub_cidr=${sub_cidr:-"$sub_cidr"};
            if [ "$sub_cidr" = "" ] 
            then echo -e "${RED}Entered CIDR is empty. Please retry${NC}"
            else
              REGEX='^(((25[0-5]|2[0-4][0-9]|1?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|1?[0-9][0-9]?))(\/([8-9]|[1][0-9]|[2][0-9]))([^0-9.]|$)'
                  vnet_pref=`echo $vnet_cidr | awk -F/ '{print $2}'`
                  sub_pref=`echo $sub_cidr | awk -F/ '{print $2}'`
              if [[ $sub_cidr =~ $REGEX ]]  && (( $sub_pref >= $vnet_pref && $sub_pref <= 29 ))
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
            az network vnet subnet create --address-prefixes $sub_cidr --vnet-name $vnet_name -g $rg_name -n $sub_name --query '{Subnet:name,CIDR:addressPrefix,resourceGroup:resourceGroup}'
            break 
# SUBNET ADDITION END        
     fi
     done 
     break
else echo "${RED}The entered VNET name is not valid. Please retry ${NC}"; 
 fi
 done
fi
####################################
#                NSG
####################################
echo
echo "************ Network security Security Group ! ************"
sg_name=$(az network vnet subnet show -g $rg_name --vnet-name $vnet_name -n $sub_name --query networkSecurityGroup.id -o tsv|awk -F[/] '{print $9}')            
if [ -z "$sg_name" ];
then                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            
# 1. Create a network security group for the front-end subnet
    echo  "${BLUE}        NSG not present creating a new one ${NC}" 
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
            echo -e "${NC}****************${GREEN}  Security Group detail${NC}  ******************"
            echo
            az network nsg rule create -g $rg_name --nsg-name $sg_name -n Allow-SSH-IN --access Allow --protocol Tcp --direction Inbound --priority 100 --source-address-prefix Internet --source-port-range "*" --destination-address-prefix "*" --destination-port-range 22 --description "SSH ingress trafic" --query '{Name:name,Source:sourceAddressPrefix,PORT:destinationPortRange,Type:direction,Priority:priority}'
            break
            ;;
            "SSH, HTTP, and HTTPS")
            sg_name=$(az network nsg create -g $rg_name -n sg_"${sub_name}"_WEB  --query 'NewNSG.name' -o tsv)
            echo -e "${NC}****************${GREEN}  Security Group detail${NC}  ******************"
            echo
            az network nsg rule create -g $rg_name --nsg-name $sg_name -n Allow-WEB-IN --access Allow --protocol Tcp --direction Inbound --priority 100 --source-address-prefix Internet --source-port-range "*" --destination-address-prefix "*" --destination-port-range 22 80 443 --description "SSH-HTTP-HTTPS ingress trafic"  --query '{Name:name,Source:sourceAddressPrefix,PORT:to_string(destinationPortRanges),Type:direction,Priority:priority}'
            break
            ;;
            
            "HTTP,RDP, and HTTPS")
            sg_name=$(az network nsg create -g $rg_name -n sg_"${sub_name}"_WEB_RDP  --query 'NewNSG.name' -o tsv)
            echo -e "${NC}****************${GREEN}  Security Group detail${NC}  ******************"
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
    # FOR VNICS: az network nic update -g MyResourceGroup -n MyNic --network-security-group MyNewNsg
else
echo "${GREEN} checking the associated  NSG : "$sg_name" ${NC}"
# check if the assigned nsg has the required inbound rules
#  
nsg_port_single=$(az network nsg show -g $rg_name -n $sg_name --query securityRules[?direction==\`Inbound\`].destinationPortRange -o tsv)
nsg_port_range=$(az network nsg show -g $rg_name  -n $sg_name --query securityRules[?direction==\`Inbound\`].destinationPortRanges[] -o tsv)
max_priority=$(az network nsg show -g $rg_name -n $sg_name --query "securityRules[?direction==\`Inbound\`].priority|max(@)" -o tsv)
#
[[ " $nsg_port_single $nsg_port_range " =~ [[:space:]]22[[:space:]] ]] && ssh=22
[[ " $nsg_port_single $nsg_port_range " =~ [[:space:]]80[[:space:]] ]] && http=80
[[ " $nsg_port_single $nsg_port_range " =~ [[:space:]]443[[:space:]] ]] && https=443
[[ " $nsg_port_single $nsg_port_range " =~ [[:space:]]3389[[:space:]] ]] && rdp=3389
###
echo "Choose The type of security Group you want to enforce ||{**}||${GREEN}"  
    PS3='Select a security group ingress rule and press Enter: ' 
    echo
    options=("SSH port Only" "SSH, HTTP, and HTTPS" "HTTP,RDP, and HTTPS")
    select opt in "${options[@]}"
    do
    case $opt in
            "SSH port Only")
            echo -e "${NC}****************${GREEN}  Security Group detail${NC}  ******************"
            echo
            if [ -z "$ssh" ]; 
            then 
            let "max_priority++"
            az network nsg rule create -g $rg_name --nsg-name $sg_name -n Allow-SSH-IN --access Allow --protocol Tcp --direction Inbound --priority "$max_priority" --source-address-prefix Internet --source-port-range 22 --destination-address-prefix "*" --destination-port-range 22 --description "SSH ingress trafic" --query '{Name:name,Source:sourceAddressPrefix,PORT:destinationPortRange,Type:direction,Priority:priority}'
            fi
            break
            ;;
            "SSH, HTTP, and HTTPS")
            echo -e "${NC}****************${GREEN}  Security Group detail${NC}  ******************"
            echo
            if [ -z "$ssh" ];
            then
            let "max_priority++"
            az network nsg rule create -g $rg_name --nsg-name $sg_name -n Allow-SSH-IN --access Allow --protocol Tcp --direction Inbound --priority "$max_priority" --source-address-prefix Internet --source-port-range 22 --destination-address-prefix "*" --destination-port-range 22 --description "SSH ingress trafic" --query '{Name:name,Source:sourceAddressPrefix,PORT:destinationPortRange,Type:direction,Priority:priority}'
            fi
            if [ -z "$http" ];
            then
            let "max_priority++"
            az network nsg rule create -g $rg_name --nsg-name $sg_name -n Allow-HTTP-IN --access Allow --protocol Tcp --direction Inbound --priority "$max_priority" --source-address-prefix Internet --source-port-range 80 --destination-address-prefix "*" --destination-port-range 80  --description "HTTP ingress trafic"  --query '{Name:name,Source:sourceAddressPrefix,PORT:destinationPortRange,Type:direction,Priority:priority}'
            fi
            if [ -z "$https" ];
            then
            let "max_priority++"
            az network nsg rule create -g $rg_name --nsg-name $sg_name -n Allow-HTTPS-IN --access Allow --protocol Tcp --direction Inbound --priority "$max_priority" --source-address-prefix Internet --source-port-range 443 --destination-address-prefix "*" --destination-port-range 443 --description "HTTPS ingress trafic"  --query '{Name:name,Source:sourceAddressPrefix,PORT:destinationPortRange,Type:direction,Priority:priority}'
            fi
            break
            ;;
            
            "HTTP,RDP, and HTTPS")
            echo -e "${NC}****************${GREEN}  Security Group detail${NC}  ******************"
            echo
            if [ -z "$rdp" ];
            then
            let "max_priority++"
            az network nsg rule create -g $rg_name --nsg-name $sg_name -n Allow-RDP-IN --access Allow --protocol Tcp --direction Inbound --priority "$max_priority" --source-address-prefix Internet --source-port-range 3389 --destination-address-prefix "*" --destination-port-range 3389 --description "RDP ingress trafic" --query '{Name:name,Source:sourceAddressPrefix,PORT:destinationPortRange,Type:direction,Priority:priority}'
            fi
            if [ -z "$http" ];
            then
            let "max_priority++"
            az network nsg rule create -g $rg_name --nsg-name $sg_name -n Allow-HTTP-IN --access Allow --protocol Tcp --direction Inbound --priority "$max_priority" --source-address-prefix Internet --source-port-range 80 --destination-address-prefix "*" --destination-port-range 80  --description "HTTP ingress trafic"  --query '{Name:name,Source:sourceAddressPrefix,PORT:destinationPortRange,Type:direction,Priority:priority}'
            fi
            if [ -z "$https" ];
            then 
            let "max_priority++"
            az network nsg rule create -g $rg_name --nsg-name $sg_name -n Allow-HTTPS-IN --access Allow --protocol Tcp --direction Inbound --priority "$max_priority" --source-address-prefix Internet --source-port-range 443 --destination-address-prefix "*" --destination-port-range 443 --description "HTTPS ingress trafic"  --query '{Name:name,Source:sourceAddressPrefix,PORT:destinationPortRange,Type:direction,Priority:priority}'
            fi
            break
            ;;               
            *) echo "invalid option";;
    esac
    done
   
fi
echo
echo "${GREEN}==${BLUE} final status for the Network security group${GREEN}==${NC}"

az network nsg show -g brokedba -n $sg_name --query "{Name:name,Combo_rule_Ports:to_string(securityRules[?direction==\`Inbound\`].destinationPortRanges[]),single_rule_Ports:to_string(securityRules[?direction==\`Inbound\`].destinationPortRange),sub:subnets[].id,resourceGroup:resourceGroup}" -o json
echo
echo "${GREEN}Cleanup commands:"
echo
echo -e "${NC} Disassociate NGS from its Subnet ==>${RED} az network vnet subnet update --vnet-name $vnet_name --name $sub_name -g $rg_name --nsg \"\" ${NC}"  
echo -e "${NC} SUBNET delete command            ==>${RED}  az network vnet subnet delete -g $rg_name --vnet-name $vnet_name -n $sub_name" 
echo -e "${NC} NSG delete command               ==>${RED}  az network nsg delete -g $rg_name -n $sg_name" 

 



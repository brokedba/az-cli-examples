#!/bin/bash
# Author Brokedba https://twitter.com/BrokeDba
RED=$'\e\033[0;31m'
GREEN=$'\e\033[0;32m'
BLUE=$'\e\033[1;34m'
NC=$'\e\033[0m' # No Color
echo
while true; do
echo " Geography selecta ||{**}|| ${GREEN} " 
echo
PS3='Select a geography and press Enter: ' 
options=("US" "Canada"  "Europe" "Asia Pacific" "South America" "Middle East" "Africa" "Exit?")
select opt in "${options[@]}"
do echo ${NC}
  case $opt in
        "US")
          
          az account list-locations --query  "sort_by(@,&name)[?!(contains(name,\`stage\`)) && contains(regionalDisplayName,\`(US)\`)].{Region:name,Location:metadata.physicalLocation}"
          break
          ;;
        "Canada")
          az account list-locations --query  "sort_by(@,&name)[?!(contains(name,\`stage\`)) && contains(regionalDisplayName,\`(Canada)\`)].{Region:name,Location:metadata.physicalLocation}"
          break
          ;;
          "Europe")
          az account list-locations --query  "sort_by(@,&name)[?!(contains(name,\`stage\`)) && contains(regionalDisplayName,\`(Europe)\`)].{Region:name,Location:metadata.physicalLocation}"
          break
          ;;
          
        "Asia Pacific")
          az account list-locations --query  "sort_by(@,&name)[?!(contains(name,\`stage\`)) && contains(regionalDisplayName,\`(Asia Pacific)\`)].{Region:name,Location:metadata.physicalLocation}"
          break
          ;;
        "South America")
          az account list-locations --query  "sort_by(@,&name)[?!(contains(name,\`stage\`)) && contains(regionalDisplayName,\`(South America)\`)].{Region:name,Location:metadata.physicalLocation}"
          break
          ;;
        "Middle East")
          az account list-locations --query  "sort_by(@,&name)[?!(contains(name,\`stage\`)) && contains(regionalDisplayName,\`(Middle East)\`)].{Region:name,Location:metadata.physicalLocation}"
          break
          ;;
        "Africa")
          az account list-locations --query  "sort_by(@,&name)[?!(contains(name,\`stage\`)) && contains(regionalDisplayName,\`(Africa)\`)].{Region:name,Location:metadata.physicalLocation}"
          break
          ;;          
        "Exit?")
          exit 
          ;;                              
        *) echo "invalid option";;
  esac
done 
echo "********* Region ************"

read -p "Pick the region Name you wish to set for your resources [eastus]: " location
 location=${location:-eastus}
 location=$(az account list-locations --query  "[?!(contains(name,\`stage\`)) && name == \`$location\` ].name" -o tsv)
if [ -n "$location" ];
    then  
     echo selected region name :${GREEN} $location${NC}
     echo ...
     break
else echo " ${RED}Region $location doesn't exist Please retry.${NC}" ;
echo "===>" ;
     fi 
 done

read -p "Enter the Name of your resource group [demo_rg]: " rg_name
rg_name=${rg_name:-demo_rg}  # this is a GITbash path
 echo -----
 echo selected Resource group :${GREEN} $rg_name ${NC}
 echo
az group create -l $location  -n $rg_name --query '{name:name,location:location, rg_id:id}'
echo 
echo -e "${NC} resource group delete command ==>${RED}  az group delete -n $rg_name" --no-wait -y

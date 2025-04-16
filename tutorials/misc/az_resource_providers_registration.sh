#/*
#Before you can create resources of a specific type (like Virtual Networks, NSGs, Public IPs, etc., which belong to the Microsoft.Network provider), in terraform the Azure Subscription itself needs to be explicitly
# registered to use that Resource Provider (RP). This is a one-time setup action per subscription per provider.
# you can use the portal or az cli to regiter the manually . CLI example: az provider register --namespace Microsoft.Network
#*/

# Ensure you are logged in and the correct subscription is set
# az login
# az account set --subscription "Your-Subscription-ID-or-Name"

echo "Finding unregistered providers..."
namespaces=$(az provider list --query "[?registrationState=='NotRegistered'].namespace" --output tsv)

if [ -z "$namespaces" ]; then
  echo "No unregistered providers found."
else
  echo "Attempting to register the following providers:"
  echo "$namespaces"
  echo "---"
  for ns in $namespaces; do
    echo "Registering $ns..."
    az provider register --namespace "$ns"
  done
  echo "---"
  echo "Registration commands submitted. Check status individually or wait a few minutes."
fi

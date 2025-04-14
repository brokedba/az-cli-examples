# 🚀 Azure Custom Role: vm-vnet-role (Scoped to an  RG)

This document Defines and provides instructions for the custom Azure role `vm-vnet-role` for managing VMs, VNets, Disks, NICs, Public IPs, NSGs, and Route Tables.

Scoped for assignment only within a specific resource group (e.g., `CloudDude`).

## Prerequisites

*   Azure Subscription ID
*   Target Resource Group name (e.g., `CloudDude`)
*   Azure CLI or PowerShell configured
*   Permissions to create/assign custom roles (Owner/User Access Admin)
*   The `vm-vnet-role-rg-scoped.json` file from this repo

## Role Definition File

*   Located at [`vm-vnet-role-rg-scoped.json`](./vm-vnet-role-rg-scoped.json).
*   **IMPORTANT:** Edit the file to replace `{yourSubscriptionId}` and optionally update the resource group name (`CloudDude`) in `assignableScopes`.

```json
{
  "properties": {
    "roleName": "vm-vnet-role",
    "description": "Allows full management of Virtual Machines and Virtual Networks and their related core components (Disks, NICs, Public IPs, NSGs, Route Tables). Assignable only within the CloudDude resource group.",
    "assignableScopes": [
      "/subscriptions/{yourSubscriptionId}/resourceGroups/CloudDude"
    ],
    "permissions": [
      {
        "actions": [
          "Microsoft.Compute/virtualMachines/*",
          "Microsoft.Compute/disks/*",
          "Microsoft.Compute/snapshots/*",
          "Microsoft.Compute/images/read",
          "Microsoft.Compute/images/write",
          "Microsoft.Compute/images/delete",
          "Microsoft.Compute/availabilitySets/*",
          "Microsoft.Compute/locations/vmSizes/read",
          "Microsoft.Network/virtualNetworks/*",
          "Microsoft.Network/networkInterfaces/*",
          "Microsoft.Network/publicIPAddresses/*",
          "Microsoft.Network/networkSecurityGroups/*",
          "Microsoft.Network/routeTables/*",
          "Microsoft.Network/locations/operations/read",
          "Microsoft.Network/locations/usages/read",
          "Microsoft.Network/locations/CheckDnsNameAvailability/read",
          "Microsoft.Resources/subscriptions/resourceGroups/read",
          "Microsoft.Storage/storageAccounts/read",
          "Microsoft.Storage/storageAccounts/listKeys/action"
        ],
        "notActions": [],
        "dataActions": [],
        "notDataActions": []
      }
    ]
  }
}
```

## Instructions

### Step 1: Prepare JSON File

1.  Download `vm-vnet-role-rg-scoped.json`.
2.  Edit file: Replace `{yourSubscriptionId}` and resource group name (`CloudDude`) in `assignableScopes`.
3.  Save changes.
   
### Step 2: Create/Update Custom Role

(Run once per tenant) Navigate to the directory with the edited `.json` file and run prefered tool commands:

*   **Using Azure CLI:**
 ```bash
    az role definition create --role-definition @vm-vnet-role-rg-scoped.json
   # To update the role if it already exists (e.g., you changed permissions):
    az role definition update --role-definition @vm-vnet-role-rg-scoped.json 
 ```
*   **Using Azure PowerShell:**
 ```Powershell
 New-AzRoleDefinition -InputFile .\vm-vnet-role-rg-scoped.json
 # To update the role if it already exists:
 Set-AzRoleDefinition -InputFile .\vm-vnet-role-rg-scoped.json
```
 
### Step 3: Assign the Role
Assign `vm-vnet-role` to a user/group/SPN within the target resource group (e.g., `CloudDude`). Get the assignee's Object ID (or UPN/SPN).
* **Using Azure CLI:**
```bash
# Replace placeholders: {assigneeObjectIdOrEmail}, {yourSubscriptionId}
az role assignment create --assignee "{assigneeObjectIdOrEmail}" --role "vm-vnet-role" --resource-group "CloudDude" --subscription "{yourSubscriptionId}"
```
(Note: For service principals, using the Object ID (--assignee-object-id) is often more reliable than the SPN)

* **Using Azure PowerShell:**
```powershell
# Replace placeholders: {userEmailOrSPN}, {assigneeObjectId}
# Use -SignInName for users or simple SPN lookup:
New-AzRoleAssignment -SignInName "{userEmailOrSPN}" -RoleDefinitionName "vm-vnet-role" -ResourceGroupName "CloudDude"
# Or use -ObjectId for users, groups, or service principals (more precise):
New-AzRoleAssignment -ObjectId "{assigneeObjectId}" -RoleDefinitionName "vm-vnet-role" -ResourceGroupName "CloudDude"
```
## Notes

*   Replace placeholders (`{yourSubscriptionId}`, `{assigneeObjectIdOrEmail}`, etc.) with actual values.
*   Ensure Resource Group name (`CloudDude`) is correct in `.json` file and commands.
*   Verify role creation and assignment via Portal/CLI/PowerShell.
*   Consider if narrower permissions (least privilege) are possible.

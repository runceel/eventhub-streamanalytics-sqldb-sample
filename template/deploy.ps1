$resourceGroupName = 'rg-eventhub-sqldb-lab'

az group create --name $resourceGroupName --location 'southeastasia'
az deployment group create --resource-group $resourceGroupName --template-file template.bicep

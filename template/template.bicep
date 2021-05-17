param prefix string = 'evt'
param adminLogin string = '${prefix}'
param adminPassword string = 'P@ssw0rd!1234'

var location = resourceGroup().location
var uniqueName = '${prefix}${uniqueString(resourceGroup().id)}'
var sqlServerName = 'sql-${uniqueName}'
var sqlDbName = 'sqldb-${uniqueName}'
var eventHubNamespaceName = 'evhns-${uniqueName}'
var streamAnalyticsName = 'asa-${uniqueName}'
var eventHubName = 'evh-location'

resource sqlserver 'Microsoft.Sql/servers@2020-11-01-preview' = {
  name: sqlServerName
  location: location
  properties: {
    administratorLogin: adminLogin
    administratorLoginPassword: adminPassword
  }

  resource frommicrosoft 'firewallRules' = {
    name: 'FirewallRule'
    properties: {
      startIpAddress: '0.0.0.0'
      endIpAddress: '0.0.0.0'
    }
  }

  resource sqldb 'databases' = {
    name: sqlDbName
    location: location
    sku: {
      name: 'BC_Gen5'
      capacity: 2
    }
  }
}

resource eventhubNamespace 'Microsoft.EventHub/namespaces@2017-04-01' = {
  name: eventHubNamespaceName
  location: location
  sku: {
    name: 'Standard'
    capacity: 1
    tier: 'Standard'
  }
  properties: {
    isAutoInflateEnabled: true
    maximumThroughputUnits: 20
  }

  resource eventhub 'eventhubs' = {
    name: eventHubName
    properties: {
      partitionCount: 32
      messageRetentionInDays: 1
    }

    resource auth 'authorizationRules' = {
      name: 'listen'
      properties: {
        rights: [
          'Listen'
        ]
      }

      dependsOn: [
        
      ]
    }
  }
}

resource stream 'Microsoft.StreamAnalytics/streamingjobs@2016-03-01' = {
  name: streamAnalyticsName
  location: location
  properties: {
    sku: {
      name: 'Standard'
    }
    outputStartMode: 'JobStartTime'
    inputs: [
      {
        name: 'INPUT'
        properties: {
          type: 'Stream'
          serialization: {
            type: 'Json'
            properties: {
              encoding: 'UTF8'
              format: 'Array'
            }
          }
          datasource: {
            type: 'Microsoft.ServiceBus/EventHub'
            properties: {
              serviceBusNamespace: eventhubNamespace.name
              eventHubName: eventhubNamespace::eventhub.name
              sharedAccessPolicyName: 'Listen'
              sharedAccessPolicyKey: listkeys(eventhubNamespace::eventhub::auth.id, '2017-04-01').primaryKey
            }
          }
        }
      }
    ]
    outputs: [
      {
        name: 'OUTPUT'
        properties: {
          datasource: {
            type: 'Microsoft.Sql/Server/Database'
            properties: {
              database: sqlDbName
              password: adminPassword
              user: adminLogin
              server: sqlServerName
              table: 'LOCATIONS'
            }
          }
        }
      }
    ]
    transformation: {
      name: 'TRANSFORMATION'
      properties: {
        query: 'SELECT CAST(term_no AS BIGINT) AS term_no, sokui_time, CAST(latitude AS FLOAT) AS latitude, CAST(longtitude AS FLOAT) AS longtitude INTO OUTPUT FROM INPUT PARTITION BY term_no'
      }
    }
  }
}

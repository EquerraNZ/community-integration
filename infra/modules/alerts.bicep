// What makes silence audible. A dead-letter queue nobody is told about is the
// same as dropping the message, and a subscription that disappeared is the one
// failure where everything looks healthy and nothing arrives.

param namePrefix string
param location string
param serviceBusNamespaceName string
param appInsightsId string

@description('Queues whose dead-letter depth is watched. The parked queue has its own rule below, because a parked message is a decision rather than an exhausted retry.')
param watchedQueueNames array

@description('Where an alert goes. Email is the seam; swap it for whatever operations actually uses without touching anything else.')
param alertEmail string

resource namespace 'Microsoft.ServiceBus/namespaces@2022-10-01-preview' existing = {
  name: serviceBusNamespaceName
}

resource actionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: 'ag-${namePrefix}'
  location: 'global'
  properties: {
    groupShortName: 'intplane'
    enabled: true
    emailReceivers: [
      {
        name: 'operations'
        emailAddress: alertEmail
        useCommonAlertSchema: true
      }
    ]
  }
}

resource deadLetterAlerts 'Microsoft.Insights/metricAlerts@2018-03-01' = [
  for queueName in watchedQueueNames: {
    name: 'alert-dlq-${queueName}-${namePrefix}'
    location: 'global'
    properties: {
      description: 'A message on ${queueName} could not be delivered within its delivery count. Its body and properties are on the dead-letter queue, ready to replay.'
      severity: 2
      enabled: true
      scopes: [namespace.id]
      evaluationFrequency: 'PT5M'
      windowSize: 'PT15M'
      targetResourceType: 'Microsoft.ServiceBus/namespaces'
      criteria: {
        'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
        allOf: [
          {
            name: 'DeadletteredMessages'
            metricName: 'DeadletteredMessages'
            metricNamespace: 'Microsoft.ServiceBus/namespaces'
            dimensions: [
              {
                name: 'EntityName'
                operator: 'Include'
                values: [queueName]
              }
            ]
            operator: 'GreaterThan'
            threshold: 0
            timeAggregation: 'Maximum'
            criterionType: 'StaticThresholdCriterion'
          }
        ]
      }
      actions: [
        {
          actionGroupId: actionGroup.id
        }
      ]
    }
  }
]

resource parkedAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'alert-parked-${namePrefix}'
  location: 'global'
  properties: {
    description: 'The plane decided not to retry a message and parked it. The reason is on the message properties.'
    severity: 2
    enabled: true
    scopes: [namespace.id]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    targetResourceType: 'Microsoft.ServiceBus/namespaces'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'ParkedMessages'
          metricName: 'ActiveMessages'
          metricNamespace: 'Microsoft.ServiceBus/namespaces'
          dimensions: [
            {
              name: 'EntityName'
              operator: 'Include'
              values: ['parked']
            }
          ]
          operator: 'GreaterThan'
          threshold: 0
          timeAggregation: 'Maximum'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: [
      {
        actionGroupId: actionGroup.id
      }
    ]
  }
}

// Subscription drift. It fires even though the health check re-registered,
// because the plane was deaf for up to six hours and the cause is worth knowing,
// not just the recovery.
resource driftAlert 'Microsoft.Insights/scheduledQueryRules@2023-03-15-preview' = {
  name: 'alert-subscription-drift-${namePrefix}'
  location: location
  properties: {
    displayName: 'Business event subscription drift'
    description: 'The plane found a BC business event subscription missing or pointing elsewhere.'
    severity: 1
    enabled: true
    scopes: [appInsightsId]
    evaluationFrequency: 'PT30M'
    windowSize: 'PT6H'
    criteria: {
      allOf: [
        {
          query: 'traces | where message has "health.drift" or message has "health.failed"'
          timeAggregation: 'Count'
          operator: 'GreaterThan'
          threshold: 0
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    actions: {
      actionGroups: [actionGroup.id]
    }
  }
}

output actionGroupId string = actionGroup.id

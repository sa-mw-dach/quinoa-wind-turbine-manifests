#!/bin/bash

echo "... Checking if event listeners are running"
EVENT_LISTENER_RUNNING_DEV=$(oc wait --for=condition=initialized --timeout=60s pods -l eventlistener=wind-turbine -n gitops-demo-dev)
EVENT_LISTENER_RUNNING_STAGE=$(oc wait --for=condition=initialized --timeout=60s pods -l eventlistener=wind-turbine -n gitops-demo-stage)

if [[ $EVENT_LISTENER_RUNNING_DEV == *"condition met"* ]] && [[ $EVENT_LISTENER_RUNNING_STAGE == *"condition met"* ]]; then
  echo "✅ Event listeners are running"
  EVENT_LISTENER_FOR_DEV=$(oc get route el-wind-turbine -o jsonpath='{.spec.host}{"\n"}' -n gitops-demo-dev)
  EVENT_LISTENER_FOR_STAGE=$(oc get route el-wind-turbine -o jsonpath='{.spec.host}{"\n"}' -n gitops-demo-stage)
  echo "--------------------------------------------------------------------------------"
  echo "➡️  Go to your forked github application code project, for example https://github.com/gmodzelewski/quinoa-wind-turbine"
  echo "➡️  Navigate to Settings -> Webhooks and add a Webhook for each entry"
  echo "➡️  Select as a content type application/json"
  echo "➡️  Use these Payload URLs:"
  echo "--------------------------------------------------------------------------------"
  echo "$EVENT_LISTENER_FOR_DEV"
  echo "$EVENT_LISTENER_FOR_STAGE"
  echo "--------------------------------------------------------------------------------"
else
  echo "🚫 Checking if event listeners are running"
  echo "Your event listeners are not running. Please check your deployments."
fi


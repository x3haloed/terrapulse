#!/bin/bash

# This script can be called by a cron job to trigger the tick function.
# It requires the Supabase URL and service key to be set as environment variables.

curl -X POST \
  -H "Authorization: Bearer $SUPABASE_SERVICE_KEY" \
  -H "Content-Type: application/json" \
  "https://<your-project-ref>.supabase.co/functions/v1/tick" 
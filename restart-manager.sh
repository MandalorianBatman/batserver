#!/bin/sh
# Docker container restart manager based on labels
# Uses lightweight approach with bash only

# Configuration
RESTART_LABEL="batserver.restart.schedule"
CHECK_INTERVAL=60  # How often to check for new containers (seconds)
TRACKER_DIR="/app/restart-tracker"

# Ensure tracker directory exists
mkdir -p "$TRACKER_DIR"

# Log function
log() {
  echo "[$(date +"%Y-%m-%d %H:%M:%S")] $1"
}

# Start tracking a container
track_container() {
  CONTAINER_ID="$1"
  INTERVAL="$2"
  CONTAINER_NAME="$3"
  
  # Create a tracker script for this container
  cat > "$TRACKER_DIR/$CONTAINER_ID.sh" <<EOF
#!/bin/sh
while true; do
  # Sleep for the specified interval
  sleep $INTERVAL
  
  # Check if container still exists and has our label
  if docker inspect --format "{{.State.Running}}:{{.Config.Labels.$RESTART_LABEL}}" "$CONTAINER_ID" >/dev/null 2>&1; then
    # Get fresh container data
    CONTAINER_STATUS=\$(docker inspect --format "{{.State.Running}}" "$CONTAINER_ID")
    
    if [ "\$CONTAINER_STATUS" = "true" ]; then 
      echo "[$(date +\"%Y-%m-%d %H:%M:%S\")] Restarting container $CONTAINER_NAME ($CONTAINER_ID)"
      docker restart "$CONTAINER_ID"
      echo "[$(date +\"%Y-%m-%d %H:%M:%S\")] Restart complete for $CONTAINER_NAME"
    else
      echo "[$(date +\"%Y-%m-%d %H:%M:%S\")] Container $CONTAINER_NAME is not running, skipping restart"
    fi
  else
    echo "[$(date +\"%Y-%m-%d %H:%M:%S\")] Container $CONTAINER_NAME no longer exists or missing label, stopping tracker"
    rm "$TRACKER_DIR/$CONTAINER_ID.sh"
    exit 0
  fi
done
EOF

  # Make it executable
  chmod +x "$TRACKER_DIR/$CONTAINER_ID.sh"
  
  # Start the tracker in background
  nohup "$TRACKER_DIR/$CONTAINER_ID.sh" > "$TRACKER_DIR/$CONTAINER_ID.log" 2>&1 &
  
  log "Started tracker for container $CONTAINER_NAME ($CONTAINER_ID) with interval $INTERVAL seconds"
}

# Function to clean up abandoned tracker scripts
cleanup_trackers() {
  # Find all tracker scripts
  for tracker_file in "$TRACKER_DIR"/*.sh; do
    [ -f "$tracker_file" ] || continue
    
    # Extract container ID from filename
    CONTAINER_ID=$(basename "$tracker_file" .sh)
    
    # Check if container still exists with our label
    if ! docker inspect --format "{{.Config.Labels.$RESTART_LABEL}}" "$CONTAINER_ID" >/dev/null 2>&1; then
      log "Container $CONTAINER_ID no longer exists or doesn't have our label, removing tracker"
      
      # Find and kill the tracker process
      PID=$(ps aux | grep "$tracker_file" | grep -v grep | awk '{print $1}')
      if [ -n "$PID" ]; then
        kill "$PID" 2>/dev/null
      fi
      
      # Remove the tracker script
      rm -f "$tracker_file"
      rm -f "$TRACKER_DIR/$CONTAINER_ID.log"
    fi
  done
}

# Main function
main() {
  log "Starting Docker container restart manager"
  
  while true; do
    # Scan for containers with our label
    docker ps -a --filter "label=$RESTART_LABEL" --format "{{.ID}}|{{.Names}}|{{.Label \"$RESTART_LABEL\"}}" | while IFS="|" read -r CONTAINER_ID CONTAINER_NAME INTERVAL; do
      # Skip if we're already tracking this container
      if [ -f "$TRACKER_DIR/$CONTAINER_ID.sh" ]; then
        # Check if the tracker is still running
        PID=$(ps aux | grep "$TRACKER_DIR/$CONTAINER_ID.sh" | grep -v grep | awk '{print $1}')
        if [ -n "$PID" ]; then
          continue
        fi
      fi
      
      # Validate interval
      if [ -n "$INTERVAL" ] && [ "$INTERVAL" -gt 0 ] 2>/dev/null; then
        track_container "$CONTAINER_ID" "$INTERVAL" "$CONTAINER_NAME" 
      else
        log "Invalid restart interval for container $CONTAINER_NAME: $INTERVAL"
      fi
    done
    
    # Clean up abandoned trackers
    cleanup_trackers
    
    # Show status
    TRACKER_COUNT=$(find "$TRACKER_DIR" -name "*.sh" | wc -l)
    log "Currently tracking $TRACKER_COUNT containers"
    
    # Wait before next scan
    sleep $CHECK_INTERVAL
  done
}

# Run the main function
main

#!/bin/bash
# set -ex

usage() {
  echo "Usage: $0 [-h|--help] [ssh_options] SOURCE_PATH TARGET_PATH"
  echo ""
  echo "SOURCE_PATH and TARGET_PATH can be either local or remote paths."
  echo "Remote paths should be in the format user@server:/path"
  echo "Paths don't support wildcard syntax"
  echo ""
  echo "Options:"
  echo "  -h  Display this help message and exit"
  exit 1
}

# Parse options
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      ;;
    -*)
      break;
      ;;
    *)
      break
      ;;
  esac
done

# Check arguments
if [ "$#" -lt 2 ]; then
  usage
fi

# Extract the last two parameters
SOURCE=${@: -2:1}
TARGET=${@: -1}

# Extract the middle parameters as ssh options
SSH_OPTIONS=${@:1:$#-2}

# Check the path format
if [[ $SOURCE == *":"* && $TARGET != *":"* ]]; then
  # Download
  REMOTE_USER=$(echo $SOURCE | cut -d '@' -f 1)
  REMOTE_SERVER=$(echo $SOURCE | cut -d '@' -f 2 | cut -d ':' -f 1)
  REMOTE_PATH=$(echo $SOURCE | cut -d ':' -f 2)
  LOCAL_PATH=$TARGET

  # Check if the source path exists
  ssh $SSH_OPTIONS "$REMOTE_USER@$REMOTE_SERVER" "test -e $REMOTE_PATH"
  if [ $? -ne 0 ]; then
    echo "Remote path $REMOTE_PATH does not exist"
    exit 1
  fi

  # Check if the source path is a directory
  ssh $SSH_OPTIONS "$REMOTE_USER@$REMOTE_SERVER" "test -d $REMOTE_PATH"
  if [ $? -eq 0 ]; then
    # Check if the target exists
    test -e $LOCAL_PATH
    if [ $? -ne 0 ]; then
      realpath $LOCAL_PATH >/dev/null 2>&1
      if [ $? -ne 0 ]; then
        echo "Cannot create directory '$LOCAL_PATH'"
        exit 1
      fi
      # Rename
      ssh $SSH_OPTIONS "$REMOTE_USER@$REMOTE_SERVER" "tar -czf - -C $REMOTE_PATH ." | (mkdir -p $LOCAL_PATH && tar --totals -xzvf - -C $LOCAL_PATH)
    else
      # Check if the target is a directory
      test -d $LOCAL_PATH
      if [ $? -ne 0 ]; then
        echo "Cannot overwrite non-directory '$LOCAL_PATH' with directory '$REMOTE_PATH'"
        exit 1
      else
        # '/path/' and '/path/.' have different operations
        ssh $SSH_OPTIONS "$REMOTE_USER@$REMOTE_SERVER" "tar -czf - -C $(dirname $REMOTE_PATH) $(basename $REMOTE_PATH)" | tar --totals -xzvf - -C $LOCAL_PATH
      fi
    fi
  else
    # Check if the target exists
    test -e $LOCAL_PATH
    if [ $? -ne 0 ]; then
      if [[ $LOCAL_PATH == *"/" ]]; then
        echo "Cannot create regular file '$LOCAL_PATH'"
        exit 1
      fi
      realpath $LOCAL_PATH >/dev/null 2>&1
      if [ $? -ne 0 ]; then
        echo "Cannot create regular file '$LOCAL_PATH'"
        exit 1
      fi
      # Rename
      ssh $SSH_OPTIONS "$REMOTE_USER@$REMOTE_SERVER" "tar -czf - $REMOTE_PATH" | tar --totals -xzvf - -O >$LOCAL_PATH
    else
      # Check if the target is a directory
      test -d $LOCAL_PATH
      if [ $? -ne 0 ]; then
        # Overwrite
        ssh $SSH_OPTIONS "$REMOTE_USER@$REMOTE_SERVER" "tar -czf - $REMOTE_PATH" | tar --totals -xzvf - -O >$LOCAL_PATH
      else
        # Copy to target directory
        ssh $SSH_OPTIONS "$REMOTE_USER@$REMOTE_SERVER" "tar -czf - -C $(dirname $REMOTE_PATH) $(basename $REMOTE_PATH)" | tar --totals -xzvf - -C $LOCAL_PATH
      fi
    fi
  fi

  if [ $? -eq 0 ]; then
    echo "Succeed"
  else
    echo "Failed: $LOCAL_PATH"
  fi

elif [[ $SOURCE != *":"* && $TARGET == *":"* ]]; then
  # Upload
  LOCAL_PATH=$SOURCE
  REMOTE_USER=$(echo $TARGET | cut -d '@' -f 1)
  REMOTE_SERVER=$(echo $TARGET | cut -d '@' -f 2 | cut -d ':' -f 1)
  REMOTE_PATH=$(echo $TARGET | cut -d ':' -f 2)

  # Check if the source path exists
  test -e $LOCAL_PATH
  if [ $? -ne 0 ]; then
    echo "Local path $LOCAL_PATH does not exist"
    exit 1
  fi

  # Check if the source path is a directory
  test -d $LOCAL_PATH
  if [ $? -eq 0 ]; then
    # Check if the target exists
    ssh $SSH_OPTIONS "$REMOTE_USER@$REMOTE_SERVER" "test -e $REMOTE_PATH"
    if [ $? -ne 0 ]; then
      ssh $SSH_OPTIONS "$REMOTE_USER@$REMOTE_SERVER" "realpath $REMOTE_PATH >/dev/null 2>&1"
      if [ $? -ne 0 ]; then
        echo "Cannot create directory '$REMOTE_PATH'"
        exit 1
      fi
      # Rename
      tar -czf - -C $LOCAL_PATH . | ssh $SSH_OPTIONS "$REMOTE_USER@$REMOTE_SERVER" "mkdir -p $REMOTE_PATH && tar --totals -xzvf - -C $REMOTE_PATH"
    else
      # Check if the target is a directory
      ssh $SSH_OPTIONS "$REMOTE_USER@$REMOTE_SERVER" "test -d $REMOTE_PATH"
      if [ $? -ne 0 ]; then
        echo "Cannot overwrite non-directory '$REMOTE_PATH' with directory '$LOCAL_PATH'"
        exit 1
      else
        # '/path/' and '/path/.' have different operations
        tar -czf - -C $(dirname $LOCAL_PATH) $(basename $LOCAL_PATH) | ssh $SSH_OPTIONS "$REMOTE_USER@$REMOTE_SERVER" "tar --totals -xzvf - -C $REMOTE_PATH"
      fi
    fi
  else
    # Check if the target exists
    ssh $SSH_OPTIONS "$REMOTE_USER@$REMOTE_SERVER" "test -e $REMOTE_PATH"
    if [ $? -ne 0 ]; then
      if [[ $REMOTE_PATH == *"/" ]]; then
        echo "Cannot create regular file '$REMOTE_PATH'"
        exit 1
      fi
      ssh $SSH_OPTIONS "$REMOTE_USER@$REMOTE_SERVER" "realpath $REMOTE_PATH >/dev/null 2>&1"
      if [ $? -ne 0 ]; then
        echo "Cannot create regular file '$REMOTE_PATH'"
        exit 1
      fi
      # Rename
      tar -czf - $LOCAL_PATH | ssh $SSH_OPTIONS "$REMOTE_USER@$REMOTE_SERVER" "tar --totals -xzvf - -O >$REMOTE_PATH"
    else
      # Check if the target is a directory
      ssh $SSH_OPTIONS "$REMOTE_USER@$REMOTE_SERVER" "test -d $REMOTE_PATH"
      if [ $? -ne 0 ]; then
        # Overwrite
        tar -czf - $LOCAL_PATH | ssh $SSH_OPTIONS "$REMOTE_USER@$REMOTE_SERVER" "tar --totals -xzvf - -O >$REMOTE_PATH"
      else
        # Copy to target directory
        tar -czf - -C $(dirname $LOCAL_PATH) $(basename $LOCAL_PATH) | ssh $SSH_OPTIONS "$REMOTE_USER@$REMOTE_SERVER" "tar --totals -xzvf - -C $REMOTE_PATH"
      fi
    fi
  fi

  if [ $? -eq 0 ]; then
    echo "Succeed"
  else
    echo "Failed: $REMOTE_PATH"
  fi

else
  echo "Invalid path format. Please ensure that one of source_path and target_path is a local path and the other is a remote path."
  exit 1
fi

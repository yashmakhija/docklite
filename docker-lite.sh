#!/bin/bash

# Check for required commands
check_requirements() {
    # Check if running on Linux
    if [[ $(uname) != "Linux" ]]; then
        echo "Error: This script requires Linux. Current OS is: $(uname)"
        echo "Please use a Linux system or a Linux VM."
        exit 1
    fi

    # Check for root privileges
    if [ "$EUID" -ne 0 ]; then
        echo "Please run as root"
        exit 1
    fi

    # Check for unshare command
    if ! command -v unshare >/dev/null 2>&1; then
        echo "Error: 'unshare' command not found."
        echo "On Ubuntu/Debian, install it with: sudo apt-get install util-linux"
        echo "On CentOS/RHEL, install it with: sudo yum install util-linux"
        exit 1
    fi
}

# Run checks before proceeding
check_requirements

IMAGES_DIR="$(dirname $0)/images"
CONTAINERS_DIR="$(dirname $0)/containers"
mkdir -p "$IMAGES_DIR" "$CONTAINERS_DIR"


build_image() {
    local dockerfile_path="$1"
    local dockerfile_dir=$(dirname "$dockerfile_path")
    
    local image_id=$(openssl rand -hex 6)
    local build_dir="$IMAGES_DIR/$image_id"
    
    echo "Building image $image_id..."
    
    # Create all necessary directories first
    mkdir -p "$build_dir/rootfs/app"
    mkdir -p "$build_dir/rootfs/bin"
    mkdir -p "$build_dir/rootfs/usr/bin"
    mkdir -p "$build_dir/rootfs/usr/local/bin"
    mkdir -p "$build_dir/rootfs/node_modules"
    mkdir -p "$build_dir/rootfs/etc"
    
    # Copy node and npm binaries
    echo "Copying Node.js binaries..."
    cp $(which node) "$build_dir/rootfs/usr/local/bin/" || {
        echo "Failed to copy node binary"
        exit 1
    }
    cp $(which npm) "$build_dir/rootfs/usr/local/bin/" || {
        echo "Failed to copy npm binary"
        exit 1
    }
    
    while IFS= read -r line || [ -n "$line" ]; do
        line=$(echo "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        [ -z "$line" ] && continue
        
        echo "Processing line: '$line'"
        
        if [[ $line =~ ^FROM ]]; then
            local base_image=$(echo $line | cut -d' ' -f2)
            echo "Using base image: $base_image"
            
        elif [[ $line =~ ^WORKDIR ]]; then
            local work_dir=$(echo $line | cut -d' ' -f2)
            echo "Creating workdir: $work_dir"
            mkdir -p "$build_dir/rootfs$work_dir"
            
        elif [[ $line =~ ^COPY ]]; then
            local args=$(echo $line | cut -d' ' -f2-)
            local src=$(echo $args | cut -d' ' -f1)
            local dest=$(echo $args | cut -d' ' -f2)
            echo "Copying $src to $dest"
            cp -r "$dockerfile_dir/$src" "$build_dir/rootfs/app/"
            
        elif [[ $line =~ ^ENV ]]; then
            local env_var=$(echo $line | cut -d' ' -f2-)
            echo "Setting environment variable: $env_var"
            mkdir -p "$build_dir/rootfs/etc"
            echo "export $env_var" >> "$build_dir/rootfs/etc/profile"
            
        elif [[ $line =~ ^RUN ]]; then
            local command=$(echo $line | cut -d' ' -f2-)
            echo "Running: $command"
            cd "$build_dir/rootfs/app" && sh -c "$command" || true
            cd - > /dev/null
            
        elif [[ $line =~ ^CMD ]]; then
            echo "Found CMD instruction: '$line'"
            # Create cmd file with proper format
            cat > "$build_dir/cmd" << 'EOF'
#!/bin/bash
export PATH=/usr/local/bin:/usr/bin:/bin
cd app && exec node server.js
EOF
            chmod +x "$build_dir/cmd"
            echo "Created CMD file at: $build_dir/cmd"
            echo "CMD file contents:"
            cat "$build_dir/cmd"
        fi
    done < <(cat "$dockerfile_path")
    
    # Verify directory structure
    echo "Verifying directory structure..."
    ls -la "$build_dir/rootfs"
    ls -la "$build_dir/rootfs/app"
    ls -la "$build_dir/rootfs/usr/local/bin"
    
    echo "Image built successfully: $image_id"
    echo "Image ID: $image_id"
}


list_images() {
    echo "Available Images:"
    echo "IMAGE ID"
    for img in "$IMAGES_DIR"/*; do
        if [ -d "$img" ]; then
            basename "$img"
        fi
    done
}


run_container() {
    local image_id="$1"
    local container_id=$(openssl rand -hex 6)
    local container_dir="$CONTAINERS_DIR/$container_id"
    local log_file="$container_dir/container.log"
    
    if [ ! -d "$IMAGES_DIR/$image_id" ]; then
        echo "Image not found: $image_id"
        exit 1
    fi
    
    echo "Creating container $container_id..."
    mkdir -p "$container_dir"
    
    # Copy rootfs with proper permissions
    echo "Copying rootfs..."
    cp -r "$IMAGES_DIR/$image_id/rootfs" "$container_dir/" || {
        echo "Failed to copy rootfs"
        remove_container "$container_id"
        exit 1
    }
    
    # Verify directory structure
    echo "Verifying container structure..."
    ls -la "$container_dir/rootfs"
    ls -la "$container_dir/rootfs/app"
    ls -la "$container_dir/rootfs/usr/local/bin"
    
    # Get the CMD instruction from the image
    local cmd=""
    if [ -f "$IMAGES_DIR/$image_id/cmd" ]; then
        cmd=$(cat "$IMAGES_DIR/$image_id/cmd")
        echo "Found CMD: $cmd"
    else
        echo "No CMD found in image"
        remove_container "$container_id"
        exit 1
    fi
    
    echo "Starting container..."
    echo "Container logs will be saved to: $log_file"
    
    # Run the container with namespace isolation
    {
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Container started"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Running command: $cmd"
        
        cd "$container_dir/rootfs" || {
            echo "Failed to change to rootfs directory"
            remove_container "$container_id"
            exit 1
        }
        
        # Use unshare to create isolated namespaces
        unshare --mount --uts --ipc --net --pid --fork --mount-proc chroot . /bin/bash -c "$cmd" 2>&1
        
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Container stopped"
    } | tee "$log_file"
    
    echo "Container exited: $container_id"
    echo "Logs are available at: $log_file"
}


list_containers() {
    echo "Running Containers:"
    echo "CONTAINER ID"
    for container in "$CONTAINERS_DIR"/*; do
        if [ -d "$container" ]; then
            basename "$container"
        fi
    done
}


remove_container() {
    local container_id="$1"
    if [ -d "$CONTAINERS_DIR/$container_id" ]; then
        rm -rf "$CONTAINERS_DIR/$container_id"
        echo "Removed container: $container_id"
    else
        echo "Container not found: $container_id"
    fi
}


remove_image() {
    local image_id="$1"
    if [ -d "$IMAGES_DIR/$image_id" ]; then
        rm -rf "$IMAGES_DIR/$image_id"
        echo "Removed image: $image_id"
    else
        echo "Image not found: $image_id"
    fi
}


case "$1" in
    "build")
        if [ -z "$2" ]; then
            echo "Usage: $0 build <dockerfile-path>"
            exit 1
        fi
        build_image "$2"
        ;;
    "images")
        list_images
        ;;
    "run")
        if [ -z "$2" ]; then
            echo "Usage: $0 run <image-id>"
            exit 1
        fi
        run_container "$2"
        ;;
    "ps")
        list_containers
        ;;
    "rm")
        if [ -z "$2" ]; then
            echo "Usage: $0 rm <container-id>"
            exit 1
        fi
        remove_container "$2"
        ;;
    "rmi")
        if [ -z "$2" ]; then
            echo "Usage: $0 rmi <image-id>"
            exit 1
        fi
        remove_image "$2"
        ;;
    *)
        echo "Usage: $0 {build|images|run|ps|rm|rmi} [args...]"
        exit 1
        ;;
esac

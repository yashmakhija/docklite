#!/bin/bash


if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi


IMAGES_DIR="$(dirname $0)/images"
CONTAINERS_DIR="$(dirname $0)/containers"
mkdir -p "$IMAGES_DIR" "$CONTAINERS_DIR"


build_image() {
    local dockerfile_path="$1"
    if [ ! -f "$dockerfile_path" ]; then
        echo "Dockerfile not found at $dockerfile_path"
        exit 1
    fi
    
    
    local image_id=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 12)
    local build_dir="$IMAGES_DIR/$image_id"
    
    echo "Building image $image_id..."
    mkdir -p "$build_dir"
    
    
    while IFS= read -r line; do
        if [[ $line =~ ^FROM ]]; then
            
            local base_image=$(echo $line | cut -d' ' -f2)
            echo "Using base image: $base_image"
            
            mkdir -p "$build_dir/rootfs"
            
        elif [[ $line =~ ^RUN ]]; then
            
            local command=$(echo $line | cut -d' ' -f2-)
            echo "Running: $command"
            
            chroot "$build_dir/rootfs" /bin/sh -c "$command" || true
            
        elif [[ $line =~ ^CMD ]]; then
            
            echo "$line" > "$build_dir/cmd"
        fi
    done < "$dockerfile_path"
    
    echo "Image built successfully: $image_id"
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
    local container_id=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 12)
    local container_dir="$CONTAINERS_DIR/$container_id"
    
    if [ ! -d "$IMAGES_DIR/$image_id" ]; then
        echo "Image not found: $image_id"
        exit 1
    fi
    
    echo "Creating container $container_id..."
    mkdir -p "$container_dir"
    
    
    cp -r "$IMAGES_DIR/$image_id/rootfs" "$container_dir/"
    
    
    echo "Starting container..."
    unshare --mount --uts --ipc --net --pid --fork --mount-proc \
        chroot "$container_dir/rootfs" /bin/sh
    
    echo "Container exited: $container_id"
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

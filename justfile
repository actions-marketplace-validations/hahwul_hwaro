# Default: just --list
default:
    @echo "Listing available tasks..."
    @just --list

# Serve documents page with builded binary
dev:
    bin/hwaro serve -i docs

# Build binary
build:
    shards build

# Fix lint
fix:
    crystal tool format

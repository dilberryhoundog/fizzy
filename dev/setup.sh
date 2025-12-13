#!/bin/bash

# Merge driver (idempotent)
git config merge.protect.name "Protect from merging"
git config merge.protect.driver true

# Remote (add or update)
git remote add workspace https://github.com/dilberryhoundog/dev-workspace.git 2>/dev/null || git remote set-url workspace https://github.com/dilberryhoundog/dev-workspace.git

echo "Setup complete."

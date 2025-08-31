#!/bin/bash
source ~/.venv/bin/activate

# If no command provided, start interactive bash
if [ $# -eq 0 ]; then
    echo "✅ Zephyr environment ready!"
    echo "🔧 Toolchains: ${TOOLCHAINS}"
    echo "💡 Usage: west init -m https://github.com/zephyrproject-rtos/zephyr --mr <version> <project>"
    exec /bin/bash
else
    # Execute the provided command
    exec "$@"
fi

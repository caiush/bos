This is a utility for listening in on a RabbitMQ server.

Setup: Run "(sudo) pip install -r requirements.txt"

Usage: trace_rabbit.py [-h] [--rabbit-username RABBIT_USERNAME]
                       [--rabbit-password RABBIT_PASSWORD] [--server SERVER]
                       [--port PORT] [--host HOST] [--routing-key ROUTING_KEY]
                       mode [name]

The RABBIT_USERNAME and RABBIT_PASSWORD options are required, but can be provided via environment variables.
The name parameter is required when not in Trace mode.

Use "trace_rabbit.py -h" to see defaults

#! /usr/bin/env python
import pika
import os
import argparse
import sys
import json
import itertools

class SmartFormatter(argparse.HelpFormatter):
    def _split_lines(self, text, width):
        if text.startswith('R|'):
            return text[2:].splitlines()  
        return argparse.HelpFormatter._split_lines(self, text, width)


parser = argparse.ArgumentParser(description='Listen to RabbitMQ messages on an existing queue or exchange.', formatter_class=SmartFormatter)
parser.add_argument('mode',
                    help="R|(e)xchange - listen to messages from a particular exchange\n"
                           "(q)ueue    - listen to messages from a particular queue,\n"
                           "(t)race    - listen to messages from all exchanges")
parser.add_argument('name', nargs='?',
                    help="The exchange or queue name to listen to. Ignored when in trace mode")

parser.add_argument('--rabbit-username', default=os.environ.get('RABBIT_USERNAME'),
                    help='Your RabbitMQ username. Defaults to ENV["RABBIT_USERNAME"]')
parser.add_argument('--rabbit-password', default=os.environ.get('RABBIT_PASSWORD'),
                    help='Your RabbitMQ password. Defaults to ENV["RABBIT_PASSWORD"]')
parser.add_argument('--server', default='localhost', 
                    help='The server on which RabbitMQ is running. Defaults to localhost')
parser.add_argument('--port', default=5672,
                    help='The port on which RabbitMQ is running. Defaults to 5672')
parser.add_argument('--host', default='/',
                    help='The virtual host on which to listen. Defaults to "/"');
parser.add_argument("--routing-key", default="#",
                    help='The routing key to filter by (when in Exchange or Trace mode). Defaults to "#"')

args = parser.parse_args()

if args.rabbit_username == None:
    parser.error('You must provide a username via --rabbit-username or ENV["RABBIT_USERNAME]"!')
if args.rabbit_password == None:
    parser.error('You must provide a password via --rabbit-password or ENV["RABBIT_PASSWORD]"!')

args.mode = args.mode[0].lower()
if args.mode not in ['e','q','t']:
    parser.error('Mode must be one of "(e)xchange", "(q)ueue", or "(t)race"!')
if args.mode in ['e','q'] and not args.name:
    parser.error('Exchange or Queue name required!')

credentials = pika.PlainCredentials(args.rabbit_username, args.rabbit_password)
parameters = pika.ConnectionParameters(args.server, args.port, args.host, credentials)
connection = pika.BlockingConnection(parameters)
channel = connection.channel()

if args.mode == 't':
    args.name = 'amq.rabbitmq.trace'
if args.mode in ['e','t']:
    try:
        channel.exchange_declare(exchange=args.name, passive=True)
    except pika.exceptions.ChannelClosed:
        print "Exchange does not exist!"
        sys.exit(0)
        
    types = ['direct', 'fanout', 'topic', 'headers']
    durables = [True, False]
    internals = [True, False]
    auto_deletes = [True, False]

    options = list(itertools.product(types, durables, internals, auto_deletes))

    while options:
        option = options.pop()
        try:
            channel = connection.channel()
            c = channel.exchange_declare(exchange=args.name,
                                         type=option[0],durable=option[1],internal=option[2], auto_delete=option[3])
            break
        except pika.exceptions.ChannelClosed:
            if not options:
                print "Unable to connect to channel!"
                sys.exit(0)


    result = channel.queue_declare(exclusive=True)
    queue_name = result.method.queue

    channel.queue_bind(exchange=args.name,
                       queue=queue_name,
                       routing_key=args.routing_key)
elif args.mode =='q':
    queue_name = args.name
    try:
        channel.queue_declare(queue=queue_name, passive=True)
    except pika.exceptions.ChannelClosed:
        print "Queue does not exist!"
        sys.exit(0)
    durables = [True,False]
    auto_deletes = [True, False]

    options = list(itertools.product(durables, auto_deletes))

    while options:
        option = options.pop()
        try:
            channel = connection.channel()
            c = channel.queue_declare(queue=queue_name,
                                      durable=option[0], auto_delete=option[1])
            break
        except pika.exceptions.ChannelClosed:
            if not options:
                print "Unable to connect to channel!"
                sys.exit(0)


def callback(ch, method, properties, body):
    try:
        body = json.loads(json.loads(body)['oslo.message'])
        body = json.dumps(body, indent=4)
    except ValueError, KeyError:
        pass
    print " [x]", method.routing_key + ":", body

channel.basic_consume(callback, queue=queue_name, no_ack=True)

if args.mode == 't':
    print 'Are you sure you ran "sudo rabbitmqctl trace_on"?'
print ' [*] Waiting for messages. To exit press CTRL+C'


try:
    channel.start_consuming()
except KeyboardInterrupt:
    print "\nStopping..."
    sys.exit(0)

#!/bin/perl

# It's certainly contains memory leaks because threads are not joined

use warnings;
use strict;

# Libs
use threads;
use Thread::Queue;
use Config::IniFiles;
use IO::Socket::INET;
use NetAddr::IP;
use IO::Handle;
use Getopt::Long;

#Configuring command line
Getopt::Long::Configure(qw{no_auto_abbrev no_ignore_case_always});
my $debug = "";
GetOptions ('debug|d' => \$debug);
# auto-flush on socket
$| = 1; # It's kind of magic
# Config parameters
my $params = Config::IniFiles->new( -file => "./config.ini");
# Setting up CIDR for later comparison
my $CIDR = NetAddr::IP->new($params->val("Server", "authorized"));
# Creating a queue to send the logs and be written some days
my $q = Thread::Queue->new();
# To write into a file the server logs
my $pathToLogServer = $params->val("Server", "logDir") . $params->val("Server", "logServerName");
open(my $l, ">>",  $pathToLogServer) or die "Could not open file '$pathToLogServer' $!";

# Creating the listening socket :
my $socket = new IO::Socket::INET (
    LocalHost => '0.0.0.0',
    LocalPort => $params->val("Server", "port"),
    Proto => 'tcp',
    Listen => $params->val("Server", "listenNumber"),
    Reuse => 1
);
# If we cannot open the socket or another error
die "Unable to create the socket.\n     |-> Reason : $!\n\n" unless $socket;

#############################################################################################################
sub display {
    my $payload = getTimestamp(). " : " .shift;
    print $l $payload;
    print $payload if $debug;
}

sub getTimestamp {
    my $timestamp = $params->val("Server", "timestampFormat");
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time); #Thanks : https://stackoverflow.com/questions/12644322/how-to-write-the-current-timestamp-in-a-perl-file
    # Not the cleanest thing on the Earth but it's "adaptable"
    my $customYear = $year+1900; my $customMonth = $mon + 1;
    $timestamp =~ s/YYYY/$customYear/ig;$timestamp =~ s/MM/$customMonth/ig;$timestamp =~ s/DD/$mday/ig;$timestamp =~ s/HH/$hour/ig;$timestamp =~ s/MM/$min/ig;$timestamp =~ s/SS/$sec/ig;
    return $timestamp; # YYYY-MM-DD HH:MM:SS  aka  2018-1-25 01:59:30
}

# This function dequeue the logs to write (So the server is not slow down with many I/Os)
sub logsWriterWorker {
    my $path = $params->val("Server", "logDir") . $params->val("Server", "logName");
    display($path."\n");
    open(my $f, ">>",  $path) or die "Could not open file '$path' $!";
    # The "funny" thing with thread is that you have to flush them ...
    $f->autoflush;
    # Emptying the queue and writing with log the needed information the logs
    while (my $query = $q->dequeue) 
    {
        display("writing into messages.log"."\n");
        print $f getTimestamp() . " : " . "$query\n";
    }
}

# To filter the connexions
sub isAuthorized {
    my $clientIP = NetAddr::IP->new(shift);
    display("Checking if $clientIP is authorized\n");
    return $clientIP->within($CIDR);
}

# Function to handle the logs
sub handler {
    my $socket = shift;
    # Redfinig the output with the socket
    my $output = shift || $socket;
    my $exit = 0;
    while (my $data = <$socket>) {
        chomp $data;
        # Add the received data to the queue
        display("queuying "."\n");
        $q->enqueue($socket->peerhost() . " : " . $data);
        print $output "ack";
    }
    $socket->close();
    display("Closing connection"."\n");
}

#############################################################################################################
# Creating the working the write the logs on the logs file
threads->create(\&logsWriterWorker);
display("Server waiting for client connection on port " . $params->val("Server", "port") ."\n");
while (1) {
    # Waiting for new connections
    my $client = $socket->accept();
    display("new client from " . $client->peerhost() . "\n");
    if (isAuthorized( $client->peerhost() )) {
        display("Creating thread\n");;
        # Creating a dedicated thread to process his logs
        threads->create(\&handler, $client);
    } else {
        display("Unauthorized connection from " . $client->peerhost() . "\n");
    }
}
$socket->close();
$l->close();
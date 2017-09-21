# vTime Let's Encrypt (LE) Certificate Management Service

## Purpose
This system has three concerns:

1. Generate valid SSL/TLS certificates for HTTPS use with the least amount of hassle
2. Automatially renew certificates that are close to expiry
3. Make availalbe certificates for build systems and server deployment systems.

## Overview

### Involved Services

This service is an orcestration of a number of systems:

* `Jenkins` - To launch and alert of failures when creating, renewing or contacting the LE VM
* `Debian VM + LE's Certbot` - To generate and store the certificates locally,
* `AWS Route53` - To host TXT records for LE DNS verification
* `AWS S3` - To host certificates for other services to consume
* `Config Repo` - To enable a single and version controled truth for what domains to generate certs for, as well as a store for scripts to process the certificates after issue / renewal

### Proceedure

* `Jenkins` starts a daily job to check and renew any certificates. 
* A SSH connection is made and a basic script will check for the `config repo`
* If the repo is not found it is cloned, then the main script from the repo is called
* The main script will ensure the latest configuration with all the domains and configurations are in place
* The main script will then run `certbot certonly -c <config_file>` to generate any new certificates needed. This is done via the `route53` plugin which will update the vtime.net zone in `route53` to add TXT records for the domain in question for the validation challange. Once passed it cleans up the generated TXT record and completes the challange, adding any new certificates to `config/live/<domain>`
* The main script will then run `certbot renew` to refresh any expring certificates using the same plugin as before. Any certificates that need renewing will go through the same process
* The main script will then upload any live and current certificates to `S3` where other services can pull them as needed
* Once finished, the `Jenkins` Job will parse the output from the main script and decide if the job had passed or failed. Notificaiton should be shown on failure.

### Service Diagram
Below is a diagram illiustrating the above:

```
┌──────────────────────────────┐
│      Let's Encrypt (LE)      │░   │
│        SSL Management        │░
└──────────────────────────────┘░   │
 ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
                                    │

                         Internal   │    Internet

                                    │

                  ┌ ─ ─ ─ ─ ─ ┐     │
                    Job Start
                  └ ─ ─ ─ ─ ─ ┘     │
                        │
                        ▼           │
                  *───────────*
    ┌────────────▶│  Jenkins  │     │
    │             *───────────*
    │                   │           │
 Job log                │
    │                   │           │
    │             Check / Renew
    │                   │           │
    │                   │
    │                   ▼           │
    │            *─────────────*               DNS
    │            │  Debian VM  │    │   TXT Verification
    │            │             │                            +─────────────+
    └────────────│┌───────────┐│◀───┼──────────────────────▶│ AWS Route53 │
                 ││    LE     ││           Upload Certs     +─────────────+
                 ││  Certbot  ││    │                       +─────────────+
                 │└───────────┘│───────────────────────────▶│   AWS S3    │
                 *─────────────*    │                       +─────────────+
                    ▲       ▲
                    │       │       │   New Cert Request    +─────────────+
                    │       │                               │     LE      │
                  Pull      └───────┼──────────────────────▶│  Challenge  │
                 Config                                     │   Server    │
                    │               │                       +─────────────+
                    │
             ┌─────────────┐        │
             │     LE      │
             │ Config Repo │        │
             └─────────────┘
                                    │

                                    │
```

### Security / Credentials

As this server creates and stores the private keys for vTime, some security measures should be taken to at least try and keep it all secure. 

#### VM Security
* The Debian VM disk should be encrypted.
* The `le` user which will run the `certbot` application *should not* have sudo access, the config for `certbot` ensures that it has no need to write to root level areas of the disk
* The SSH login for the `le` user should be restricted to running the main script only (SSH Forced Command? Needs investigation). Also SSH extras should be disabled
* Unused applications removed / Firewall all incoming ports except 22 
* Jenkins SSH key-pair should be in authorised keys

#### AWS-CLI Profiles
* One IAM profile for accessing `route53` in order to create and remove the TXT records. This IAM user should have the following policy attached to it (TODO: Get policy from AWS). Note that the `certbot` implemtation of `route53` requires that the `AWS` credentials be in the ENV in order to be picked up. (i.e export AWS_ACCESS_KEY="asdd...").
* One IAM Profile for uploading certs to `s3` buckets (AS this will use the `aws-cli` a seperate profile can be used).
 
#### Config Repo

* Should have controlled access to stop issuing of certs on the sly
* SSH Key security to repo server

## Notes

 
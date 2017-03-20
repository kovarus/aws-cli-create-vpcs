![][icon-url]
# Create a Custom VPC Using the AWS CLI

This shell script leverages the AWS Command Line Interface (AWS CLI) to create a custom AWS Virtual Private Cloud (VPC).  The script automates the creation of a custom IPv4 VPC, having both public and private subnets, and a NAT gateway.

> I created this script as a learning exercise to familiarize myself with the detailed configuration steps required to create a custom VPC.  Administrators are shielded from some of these details when using the AWS Console and I desired a better understanding.


## Table of Contents

- [Getting Started](#getting-started)
    - [Prerequisites](#prerequisites)
    - [Installation](#installation)
    - [Configuration](#configuration)
    - [Usage](#usage)
- [Background](#background)
- [Versioning](#versioning)
- [Authors](#authors)
- [License](#license)
- [Acknowledgments](#acknowledgments)

## Getting Started

### Prerequisites

The script assumes the AWS CLI is installed and configured with the necessary security credentials.  Procedures for installing the AWS CLI can be found by following the links below.

- [Install Python, pip, and the AWS Command Line Interface on Linux][awscli-linux-url]
- [Install the AWS Command Line Interface on Microsoft Windows][awscli-win-url]
- [Install the AWS Command Line Interface on macOS][awscli-macos-url]
- [Install the AWS Command Line Interface in a Virtual Environment][awscli-venv-url]
- [Install the AWS CLI Using the Bundled Installer (Linux, macOS, or Unix)][awscli-bundled-url]

> I use a MacBook Pro and prefer the convenience of a package manager such as [Homebrew](https://brew.sh/).  If you use a Mac and have Homebrew already installed, you can easily install the AWS CLI using the following command.

```sh
$ brew install awscli
```

After the AWS CLI is installed, you'll need to configure it.

```sh
$ aws configure
AWS Access Key ID [None]: AKIAIOSFODNN7EXAMPLE
AWS Secret Access Key [None]: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
Default region name [None]: us-west-2
Default output format [None]: json
```

The AWS CLI will prompt you for four pieces of information. AWS Access Key ID and AWS Secret Access Key are your account credentials.  The two remaining settings are optional.  Detailed information for configuring the AWS CLI [can be found here](http://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html).  If you don't have keys, see the [Getting Set Up](http://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-set-up.html#cli-signup) section.


### Installation

You can either [clone this repository](https://help.github.com/articles/cloning-a-repository/) or download just the script to your workstation.

```sh
$ curl -sL https://raw.githubusercontent.com/kovarus/aws-cli-create-vpcs/master/aws-cli-create-vpc.sh
```

> The GitHub repository must be public for the preceding command to work.


### Configuration

The script is configured by setting a set of variables within the script.

```sh
#==============================================================================
#   MODIFY THE SETTINGS BELOW
#==============================================================================
#
AWS_REGION="us-west-1"
VPC_NAME="My VPC"
VPC_CIDR="10.0.0.0/16"
SUBNET_PUBLIC_CIDR="10.0.1.0/24"
SUBNET_PUBLIC_AZ="us-west-1a"
SUBNET_PUBLIC_NAME="10.0.1.0 - us-west-1a"
SUBNET_PRIVATE_CIDR="10.0.2.0/24"
SUBNET_PRIVATE_AZ="us-west-1c"
SUBNET_PRIVATE_NAME="10.0.2.0 - us-west-1b"
CHECK_FREQUENCY=5
```

The variables are predefined with common values which work out of the box.  Feel free to modify them as follows.

1. Set `AWS_REGION` to the AWS region you wish to create your VPC in.  You can find a [list of AWS regions here](http://docs.aws.amazon.com/general/latest/gr/rande.html#vpc_region).  The list of available regions can change as AWS becomes available in new locations.  A more programmatic method for obtaining a list of available AWS regions would to use the the AWS CLI itself.
    ```
    $ aws ec2 describe-regions --output text
    REGIONS	ec2.ap-south-1.amazonaws.com	ap-south-1
    REGIONS	ec2.eu-west-2.amazonaws.com	eu-west-2
    REGIONS	ec2.eu-west-1.amazonaws.com	eu-west-1
    REGIONS	ec2.ap-northeast-2.amazonaws.com	ap-northeast-2
    REGIONS	ec2.ap-northeast-1.amazonaws.com	ap-northeast-1
    REGIONS	ec2.sa-east-1.amazonaws.com	sa-east-1
    REGIONS	ec2.ca-central-1.amazonaws.com	ca-central-1
    REGIONS	ec2.ap-southeast-1.amazonaws.com	ap-southeast-1
    REGIONS	ec2.ap-southeast-2.amazonaws.com	ap-southeast-2
    REGIONS	ec2.eu-central-1.amazonaws.com	eu-central-1
    REGIONS	ec2.us-east-1.amazonaws.com	us-east-1
    REGIONS	ec2.us-east-2.amazonaws.com	us-east-2
    REGIONS	ec2.us-west-1.amazonaws.com	us-west-1
    REGIONS	ec2.us-west-2.amazonaws.com	us-west-2
    ```
2. Set `VPC_NAME` to the name you prefer for your VPC.  Generally allowed characters are: letters, spaces, and numbers representable in UTF-8, plus the following special characters: + - = . _ : / @.
3. Set `VPC_CIDR` to a single CIDR block sized between a `/16` netmask and `/28` netmask.  See [VPC and Subnet Sizing](http://docs.aws.amazon.com/AmazonVPC/latest/UserGuide/VPC_Subnets.html#VPC_Sizing) for more information.
4. Set `SUBNET_PUBLIC_CIDR` to a valid CIDR block for the VPC CIDR block you specified in the preceding step.  See [VPC and Subnet Sizing](http://docs.aws.amazon.com/AmazonVPC/latest/UserGuide/VPC_Subnets.html#VPC_Sizing) for more information.  EC2 instances deployed into this subnet will be accessible from the Internet.
5. Set `SUBNET_PUBLIC_AZ` to an AWS Availability Zone which is valid for the region you specified in the preceding step.  You can obtain a list of valid Availability Zones using the AWS CLI itself.
    ```
    $ aws ec2 describe-availability-zones --output text --region us-west-1
    AVAILABILITYZONES	us-west-1	available	us-west-1a
    AVAILABILITYZONES	us-west-1	available	us-west-1c
    ```
6. Set `SUBNET_PUBLIC_NAME` to a name of your choosing.  I prefer a format of `<subnet address> - <availability zone>`.  For example, if I was creating a subnet with a CIDR block of `10.0.1.0/24` in the `us-west-1a` region, I would name the subnet as `10.0.1.0 - us-west-1a`.
7. Set `SUBNET_PRIVATE_CIDR` to a valid CIDR block for the VPC CIDR block you specified in the preceding step.  See [VPC and Subnet Sizing](http://docs.aws.amazon.com/AmazonVPC/latest/UserGuide/VPC_Subnets.html#VPC_Sizing) for more information.  EC2 instances deployed into this subnet will NOT be accessible from the Internet, but will have access TO the Internet via a NAT Gateway.
8. Set `SUBNET_PRIVATE_AZ` to an AWS Availability Zone other than the one you specified for the Public Subnet.  Deploying multiple subnets across two or more Availability Zones is a best practice.  Be sure to specify an Availability Zone which is in the same region you specified in the preceding step.
9. Set `SUBNET_PRIVATE_NAME` to a name of your choosing.  See the recommended format per the preceding step.
10. I recommend leaving `CHECK_FREQUENCY` as is.  This specifies the number of seconds the script should wait when repeatedly checking the status of a task for completion.  In this specific case, one of the steps in the script inititates the creation of a NAT Gateway and the script must wait until the NAT Gateway is available before proceeding with the remaining steps.


### Usage

Run the script as follows and monitor the status for completion.

```
$ ./aws-cli-create-vpc.sh
Creating VPC in preferred region...
  VPC ID 'vpc-6c10b108' CREATED in 'us-west-1' region.
  VPC ID 'vpc-6c10b108' NAMED as 'My VPC'.
Creating Public Subnet...
  Subnet ID 'subnet-ebea998f' CREATED in 'us-west-1a' Availability Zone.
  Subnet ID 'subnet-ebea998f' NAMED as '10.0.1.0 - us-west-1a'.
Creating Private Subnet...
  Subnet ID 'subnet-6c54d634' CREATED in 'us-west-1c' Availability Zone.
  Subnet ID 'subnet-6c54d634' NAMED as '10.0.2.0 - us-west-1b'.
Creating Internet Gateway...
  Internet Gateway ID 'igw-ede8c188' CREATED.
  Internet Gateway ID 'igw-ede8c188' ATTACHED to VPC ID 'vpc-6c10b108'.
Creating Route Table...
  Route Table ID 'rtb-8630ace2' CREATED.
  Route to '0.0.0.0/0' via Internet Gateway ID 'igw-ede8c188' ADDED to Route Table ID 'rtb-8630ace2'.
  Public Subnet ID 'subnet-ebea998f' ASSOCIATED with Route Table ID 'rtb-8630ace2'.
  'Auto-assign Public IP' ENABLED on Public Subnet ID 'subnet-ebea998f'.
Creating NAT Gateway...
  Elastic IP address ID 'eipalloc-daeacbe0' ALLOCATED.
  Creating NAT Gateway ID 'nat-007f5446e719fdd4e' and waiting for it to become available.
    Please BE PATIENT as this can take some time to complete.
    ......
    STATUS: AVAILABLE  -  00h:01m:49s elapsed while waiting for NAT Gateway to become available...
    ......
  NAT Gateway ID 'nat-007f5446e719fdd4e' is now AVAILABLE.
  Main Route Table ID is 'rtb-b930acdd'.
  Route to '0.0.0.0/0' via NAT Gateway with ID 'nat-007f5446e719fdd4e' ADDED to Route Table ID 'rtb-b930acdd'.
COMPLETED
```

## Background

When creating a custom VPC, there are several tasks which must be performed.  The AWS Console simplifies the process by abstracting away some of the details and automating some of the procedures.  Below is a listing of the steps required to create a custom VPC having both Public and Private Subnets and configuring the Private Subnet with access to the Internet via a NAT Gateway.

1. Create a VPC
    - Add a tag to name the VPC
2. Create a Public Subnet
    - Add a tag to name the Public Subnet
3. Create a Private Subnet
    - Add a tag to name the Private Subnet
4. Create an Internet Gateway
    - Attach the Internet Gateway to the VPC
5. Create a new Route Table
    - Add a route to the Internet Gateway to the new Route Table
    - Associate the Public Subnet with the new Route Table
    - Enable the _Auto-assign Public IP_ setting on the Public Subnet
6. Configure the Private Subnet with a NAT Gateway
    - Allocate an Elastic IP Address for the NAT Gateway
    - Create a NAT Gateway and **wait** for it to become available
    - Add a route to the NAT Gateway to the _Main_ Route Table

## Versioning

- 0.1.0 — (03/18/2017) first release
- 0.0.1 — (02/25/2017) work in progress


## Authors

- Joe Arauzo - https://github.com/JoeArauzo

## License

Copyright 2017 Joseph Arauzo

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

## Acknowledgments

- [Example: Create an IPv4 VPC and Subnets Using the AWS CLI][awscli-example-url]
- [Controlling Command Output from the AWS Command Line Interface][awscli-output-url]


[icon-url]: https://cloud.githubusercontent.com/assets/4857257/24086546/76828856-0cce-11e7-9ae2-edb5cd835756.png
[awscli-linux-url]: http://docs.aws.amazon.com/cli/latest/userguide/awscli-install-linux.html
[awscli-win-url]: http://docs.aws.amazon.com/cli/latest/userguide/awscli-install-windows.html
[awscli-macos-url]: http://docs.aws.amazon.com/cli/latest/userguide/cli-install-macos.html
[awscli-venv-url]: http://docs.aws.amazon.com/cli/latest/userguide/awscli-install-virtualenv.html
[awscli-bundled-url]: http://docs.aws.amazon.com/cli/latest/userguide/awscli-install-bundle.html
[awscli-example-url]: http://docs.aws.amazon.com/AmazonVPC/latest/UserGuide/vpc-subnets-commands-example.html
[awscli-output-url]: http://docs.aws.amazon.com/cli/latest/userguide/controlling-output.html#controlling-output-filter

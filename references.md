

## How to enable AWS Config
Specific to using AWS Configuration with Firewall Manager, while you can elect to enable additional/all resources, if you only are using AWS Config for Firewall manager this provide
https://docs.aws.amazon.com/waf/latest/developerguide/enable-config.html


## Enable just AWS Shield Advanced
Includes no Firewall Manager configuration. Can be deployed as a stand alone template or StackSet to enable across an AWS Organization
https://github.com/aws-samples/aws-shield-advanced-examples

## Automation to Create Amazon Route 53 Health Checks for Shield Protected Resources
https://github.com/aws-samples/aws-shield-advanced-rapid-deployment/tree/main/code/route53/config-proactive-engagement

## AWS Shield Advanced Protection - Global Accelerator & Amazon Route 53 Hosted ZOnes
Firewall Manager does not support enabling Shield protection.  The below code "mimics" Firewall Manager behavior to enable Shield Protection using AWS Config.

https://github.com/aws-samples/aws-shield-advanced-rapid-deployment/tree/main/code/fms/fms-mimic-shield-protect-global-accelerator
https://github.com/aws-samples/aws-shield-advanced-rapid-deployment/tree/main/code/fms/fms-mimic-shield-protect-route53-hosted-zones
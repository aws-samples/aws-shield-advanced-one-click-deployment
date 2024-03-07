# Overview
AWS Shield Advanced One Click deployments allows customers getting started with Shield Advanced to get an out of the box recommended baseline configuration.  You deploy a single CloudFormation Template and 16 required input parameters with 40 optional parameters to scope and otherwise tune this deployment.  This template creates:  

## Nested Stack

### Central Common resources  
A nested stack creates a central S3 bucket for all WAFv2 logs as well as an Athena Table with useful named queries and views.  

## StackSet
### Subscribe and Configure Shield Advanced  
Subscribes account to Shield via a custom lambda backed resource.  Configures Shield Response Team (SRT) access and proactive engagement

### Firewall Manager Security Policies for Shield Protection  
Creates Security policies in each configured region and globally (if desired) to ensure resources are shield protected based on a provided scope

### Firewall Manager Security Policies for WAFv2  
Creates Security policies in each configured region and globally (if desired) to manage WAFv2 on supported resources based on a provided scope

# How To Video
This [YouTube](https://www.youtube.com/watch?v=LCA3FwMk_QE) video goes into detail about how this solution works and what it achieves.
# Prerequisites

##  AWS Support  
Business or Enterprise Support must be enabled on any account where SRT access and/or Proactive Engagement will be enabled

## AWS Organizations
CloudFormation Service Managed StackSets must be enabled.  Recommended to delegate administration to another account (example video is going to delegate it to the FMS Admin account)
https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/stacksets-prereqs.html

## AWS Firewall Manager
Firewall Manager must be enabled. Recommended to delegate administration to another account
https://docs.aws.amazon.com/waf/latest/developerguide/enable-integration.html

## AWS Config
AWS Config must be enabled with at least the following resources enabled:
```
AWS::ApiGateway::Stage,
AWS::CloudFront::Distribution,
AWS::EC2::EIP,
AWS::ElasticLoadBalancing::LoadBalancer,
AWS::ElasticLoadBalancingV2::LoadBalancer,
AWS::Shield::Protection,
AWS::WAF::WebACL,
AWS::WAFv2::WebACL,
AWS::ShieldRegional::Protection
```
### Recommended deployment
Use the StackSet Sample Template called [Enable AWS Config](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/stacksets-sampletemplates.html) with the following parameters:

1. AllSupported: False

2. ResourceTypes: 
    ```
    AWS::ApiGateway::Stage,
    AWS::CloudFront::Distribution,
    AWS::EC2::EIP,
    AWS::ElasticLoadBalancing::LoadBalancer,
    AWS::ElasticLoadBalancingV2::LoadBalancer,
    AWS::Shield::Protection,
    AWS::WAF::WebACL,
    AWS::WAFv2::WebACL,
    AWS::ShieldRegional::Protection
    ```

# Setup
Run the below from the root directory of the cloned code.This will create a S3 bucket, transform template.yaml and copy the code into that S3 bucket.


Configure AWS Credentials if needed. If you want to deploy to a region other than us-east-1, ensure you configure region to that value.
```
aws configure
```
Get Account and region from credentials.  Create s3 bucket named code-oneclickshield-\<AccountId\>-\<region\> e.g. code-oneclickshield-111111111111-us-east-1

```
export AccountId=$(aws sts get-caller-identity --query "Account" --output text)
export rootId=$(aws organizations list-roots --query Roots[0]."Id" | tr -d '"')
export rootArn=$(aws organizations list-roots --query Roots[0].Arn)
export delegatedServices=$(aws organizations list-delegated-services-for-account --account-id $AccountId --query DelegatedServices)
export FMSAdminValue=$(aws fms get-admin-account --query AdminAccount | tr -d '"')
if [[ $AccountId == $FMSAdminValue ]]; then
    $FMSAdminValue = "SELF"
fi
if [[ $rootArn == *"$AccountId"* ]]; then
    export callAs="SELF"

elif [[ $delegatedServices == *"member.org.stacksets.cloudformation.amazonaws.com"* ]]; then
    export callAs="DELEGATED_ADMIN"
else
    echo "Current account: AccountId is not a Delegated Administrator for CloudFormation Service Managed StackSets"
fi

export region=$(aws configure get region)
if [ -z "$region" ]; then
    export region='us-east-1'
fi

echo "AccountId: $AccountId"
echo "Region: $region"
echo "rootId: $rootId"
echo "RootArn: $rootArn"
echo "CallAs: $callAs"

#Update this to match your bucket name if you prefer to set some other S3 bucket name schema
export BucketName=code-oneclickshield-$AccountId-$region

if [[ $region = "us-east-1" ]]; then
    aws s3api create-bucket --bucket "$BucketName" --region $region
else
    aws s3api create-bucket --bucket "$BucketName" --region $region --create-bucket-configuration LocationConstraint="$region"  
fi

aws s3 sync ./templates/ s3://$BucketName --include "./*.yaml" --exclude ".git/*"

echo -e "\033[0;32mOpen this link to start deploying the CloudFormation Template: \033[0;34m\nhttps://$region.console.aws.amazon.com/cloudformation/home?region=$region#/stacks/quickcreate?templateURL=https%3A%2F%2Fs3.$region.amazonaws.com%2F$BucketName%2Ftemplate.yaml&stackName=aws-shield-advanced-one-click-deploy&param_IncludeGlobalResourceTypes=false&param_ResourceTypes=%3CAll%3E&param_NotificationEmail=%3CNone%3E&param_TopicArn=%3CNew%20Topic%3E&param_DeliveryChannelName=%3CGenerated%3E&param_PrimaryRegion=&param_S3KeyPrefix=%3CNo%20Prefix%3E&param_Frequency=24hours&param_SNS=true&param_AllSupported=true&param_S3BucketName=%3CNew%20Bucket%3E&param_ScopeDetails=$rootId&param_RootId=$rootId&param_CallAs=$callAs&param_ScopeRegions=$region&param_FMSAdministratorAccount=$FMSAdminValue"


```

# Deployment configuration
## Default
If you only provide answers for mandatory fields, the default deployment will do the following:

1. Subscribe and configure Shield Advanced for all AWS accounts within the AWS Organization.  
2. Shield protect all supported regional resources as well as CloudFront distributions.  
3. All CloudFront Distributions, Application Load balancers, and API Gateways will have an AWS WAF WebACL attached (if there was not already one in place).  
4. All WebACLs send WAF logs to a central bucket in a central region. _This S3 bucket is created in the location the initial stack was deployed in._
5.  The WebACl includes the following rules:  
a) A [Rate based rule](https://docs.aws.amazon.com/waf/latest/developerguide/waf-rule-statement-type-rate-based.html) with a value of 10,000 action of COUNT  
b) [Anonymous IP](https://docs.aws.amazon.com/waf/latest/developerguide/aws-managed-rule-groups-ip-rep.html#aws-managed-rule-groups-ip-rep-anonymous) Amazon Managed rule | All rule actions overridden to COUNT  
c) [IP Reputation](https://docs.aws.amazon.com/waf/latest/developerguide/aws-managed-rule-groups-ip-rep.html#aws-managed-rule-groups-ip-rep-amazon) Amazon Managed rule | All rules with action BLOCK  
d) [Core Rule Set](https://docs.aws.amazon.com/waf/latest/developerguide/aws-managed-rule-groups-baseline.html#aws-managed-rule-groups-baseline-crs) Amazon Managed rule | All rule actions overridden to COUNT  
e) [Known Bad Inputs](https://docs.aws.amazon.com/waf/latest/developerguide/aws-managed-rule-groups-baseline.html#aws-managed-rule-groups-baseline-known-bad-inputs) Amazon Managed rule | All rule actions overridden to COUNT    
6. All Shield Protected resources that support AWS WAF (CloudFront and Application Load Balancers) configured with Shield Advanced automatic application layer DDoS mitigation enabled and an action of COUNT
7.  An Athena Table and workgroup created with several named queries and views relevant to reviewing WAF logs.

## **Customization**

CloudFormation parameters allow you to change the default behavior as follows:

### **Scope**
1. You can configure which region(s) are in scope.  This applies to subscribing and configuring Shield as well as Firewall Manager security policies.
2. You can configure which AWS accounts are in scope.  This applies to subscribing and configuring Shield as well as Firewall Manager security policies.
3. Firewall Manager security policies can be scoped to only certain resource types and/or the presence of specific tags on resources.
4. Firewall Manager security policies can be scoped based on the specific tag name/values or existence of specific tag names.  Shield and WAFv2 policies can specify different tag scopes.

### **Configuration**
**Shield**  
1. SRT access can be enabled/disable.
2. SRT can be given access to S3 Buckets.
3. The IAM role used to grant SRT Access (if enabled).
4. Choose to have CloudFormation create the SRT Access role or specify the name of a role that already exists.

**AWS WAF**
1. The rate based rule value and action can be changed between 100 and 2,000,000 and set to "Block".
2. Each Amazon Managed Rule (AMR) can set the action for that AMR to "Count" or "Block".


# How to deploy  

The script under **Setup** returned a link.  This link will launch CLoudFormation and point to the CloudFormation Template that was transformed and uploaded to a S3 bucket in your account.  The following sections require your acknowledgment (Set to _true_) or have a mandatory input that require your attention.  

---
## Must be set to True
* **AWS Shield Advanced Subscription**

## Mandatory Inputs Required  
* **AWS Shield Advanced Configuration** 
* **Scope** 

---

# Parameters
Parameters are divided into logical groups of parameters between mandatory and optional parameters.  Mandatory parameters either require the end user to input/select a value, or explicitly verify something.  Optional parameters allow end users to customize (e.g. WAF rule actions ) or configure optional features (e.g more than one proactive engagement emergency contact)

--- 

## AWS Shield Advanced Subscription **[Mandatory]**

**AcknowledgeServiceTermsPricing**  
Acknowledge AWS Shield Advanced has a $3000 / month subscription fee for a consolidated billing family

    Required: Yes
    Type: Bool
    AllowedValues: True | False

**AcknowledgeServiceTermsDTO**  
Acknowledge AWS Shield Advanced has a Data transfer out usage fees for all protected resources.

    Required: Yes
    Type: Bool
    AllowedValues: True | False

**AcknowledgeServiceTermsCommitment**  
AWS Shield Advanced has a 12 month commitment.

    Required: Yes
    Type: Bool
    AllowedValues: True | False

**AcknowledgeServiceTermsAutoRenew**  
Acknowledge Shield Advanced subscriptions will auto-renewed after 12 months.  However, I can opt out of renewal 30 days prior to the renewal date.

    Required: Yes
    Type: Bool
    AllowedValues: True | False

**AcknowledgeNoUnsubscribe**  
Acknowledge a Shield Advanced subscription commitment will continue even if this CloudFormation Stack is deleted.

    Required: Yes
    Type: Bool
    AllowedValues: True | False

--- 

## AWS Shield Advanced Configuration **[Mandatory]**

**EnableSRTAccess**  
AWS Shield Advanced allows you to create and authorize SRT (Shield Response Team) access to update your AWS WAF WebACLs.  Specify if this feature should be enabled or disabled.

    Required: Yes
    Type: Bool
    AllowedValues: True | False


**EnabledProactiveEngagement**  
AWS SRT (Shield Response Team) can proactively reach out when Shield Advanced detects a DDoS event and your application health is impacted (required configuring Route 53 health checks).  One or more emergency contacts must also be configured

    Required: Yes
    Type: Bool
    AllowedValues: True | False

**EmergencyContactEmail1**  
During a Proactive Engagement, SRT (Shield Response Team) will reach out to your emergency contacts.  You must configure one or more emergency contacts along with enabling Proactive Engagement.  Specify a valid e-mail address

    Required: Yes
    Type: String
    AllowedPattern: ^\S+@\S+\.\S+$|\<na\>

**EmergencyContactPhone1**  
During a Proactive Engagement, SRT (Shield Response Team) will reach out to your emergency contacts.  You must configure one or more emergency contacts along with enabling Proactive Engagement.  Specify a valid phone number + country code.  e.g. \+ 15555555555

    Required: Yes
    Type: String
    AllowedPattern: ^\+[0-9]{11}|\<na\>

**EmergencyContactNote1**  
During a Proactive Engagement, SRT (Shield Response Team) will reach out to your emergency contacts.  You must configure one or more emergency contacts along with enabling Proactive Engagement.  Provide notes/comments about this contact. E.g. SOC

    Required: Yes
    Type: String
    AllowedPattern: ^[\w\s\.\-,:/()+@]*$|\<na\>

## Scope **[Mandatory]**

**ScopeType**  
CloudFormation Service Managed StackSets can be deployed to an entire AWS Organization, a list of OUs, or a list of accounts.  Specify which scope you would like to target for this deployment.  This applies to subscribing and configured, Shield protecting resources, and WAFv2 protecting resources.

    Required: Yes
    Type: String
    AllowedValues:
    - Org
    - OUs
    - Accounts

**ScopeDetails**  
If ScopeType is Org, this parameter requires the root-id for the Organization.  E.g. r-1234
If ScopeType is OUs, this parameter is a comma separated list of AWS Organization OUs.
If ScopeType is Accounts, this parameter is a comma separated list of AWS Account IDs

    Required: Yes
    Type: CommaDelimitedList
    AllowedPattern: 
    - (^r-[0-9a-z]{4,32}$)
        or
    - ((ou-[0-9a-z]{4,32}-[a-z0-9]{8,32})((,\s*|,\)ou-[0-9a-z]{4,32}-[a-z0-9]{8,32}$)*)
        or
    - (\d{12})(,\s*\d{12})*)
    
**IncludeExcludeScope**  
If ScopeType is OUs or Account IDs, is the value provided as ScopeDetails what is in scope or out of scope?

    Required: Yes
    Type: String
    Default: Include
    AllowedValues:
    - Include

**FMSAdministratorAccount**  
What account should Firewall Manager security policies be created in.  By default (<Self>, the local account is assumed the Firewall Manager Administrator (delegated or default as payer))

    Required: Yes
    Type: String
    AllowedPatterns:
      - <Self>
      - \d{12}

**ScopeRegions**  
List of all AWS regions that are in scope for CloudFormation Stack Sets to deploy Firewall Manager Security policies

    Required: Yes
    Type: CommaDelimitedList
    AllowedPattern: ((af|ap|ca|eu|me|sa|us)-(central|north|(north(?:east|west))|south|south(?:east|west)|east|west)-\d+)(,\s(af|ap|ca|eu|me|sa|us)-(central|north|(north(?:east|west))|south|south(?:east|west)|east|west)-\d+)*

**CallAs**  
CloudFormation Service Managed StackSets being run from a delegated CloudFormation StackSet administrator to specify they are calling as such.

    Required: Yes
    Type: String
    AllowedValues:
    - DELEGATED_ADMIN
    - SELF

--- 

## Stack Set Deployment options **[Optional]**

**ProtectRegionalResourceTypes**  
Firewall Manager can establish Shield Protection on regional Resources.  Select one of the following combinations of supported regional resources

    Required: No  
    Type: String  
    Default: AWS::ElasticLoadBalancingV2::LoadBalancer,AWS::ElasticLoadBalancing::LoadBalancer,AWS::EC2::EIP  
    AllowedValues:
      - AWS::ElasticLoadBalancingV2::LoadBalancer,AWS::ElasticLoadBalancing::LoadBalancer,AWS::EC2::EIP
      - AWS::ElasticLoadBalancingV2::LoadBalancer,AWS::ElasticLoadBalancing::LoadBalancer
      - AWS::ElasticLoadBalancingV2::LoadBalancer,AWS::EC2::EIP
      - AWS::ElasticLoadBalancing::LoadBalancer,AWS::EC2::EIP
      - AWS::ElasticLoadBalancingV2::LoadBalancer
      - AWS::ElasticLoadBalancing::LoadBalancer
      - AWS::EC2::EIP
      - <na>    

**ProtectCloudFront**  
Firewall Manager can establish Shield Protection on Global Resources; today this is only CloudFront.  Select CloudFront global resources that should be Shield Protected.

    Required: No
    Type: String
    Default: AWS::CloudFront::Distribution  
    AllowedValues:
      - AWS::CloudFront::Distribution
      - <na>

**WAFv2ProtectRegionalResourceTypes**  
Firewall Manager can create and associate a WebACl on regional Resources.  Select one of the following combinations of supported regional resources

    Required: No
    Type: String
    Default: AWS::ApiGateway::Stage,AWS::ElasticLoadBalancingV2::LoadBalancer  
    AllowedValues:
      - AWS::ApiGateway::Stage,AWS::ElasticLoadBalancingV2::LoadBalancer
      - AWS::ElasticLoadBalancingV2::LoadBalancer
      - AWS::ApiGateway::Stage
      - <na>

**WAFv2ProtectCloudFront**  
Firewall Manager can create and associate a WebACl on global Resources. Select one of the following combinations of supported global resources

    Required: No
    Type: String
    Default: AWS::CloudFront::Distribution
    AllowedValues:
      - AWS::CloudFront::Distribution
      - <na>

**ShieldAutoRemediate**  
Firewall Manager can establish Shield Protection for regional and global resources.  For resources that are in scope, should in scope AWS resource types have Shield Advanced protection automatically be remediated?

    Required: No
    Type: String
    Default: Yes
    AllowedValues: 
    - Yes
    - No

**WAFv2AutoRemediate**  
Firewall Manager can create and associate WAF WebACLs for regional and global resources.  Should in scope AWS resource types that support AWS WAF automatically be remediated? For resources that are in scope, if a resource does not have the Firewall Managed WebACL, what action should be taken.  Firewall Manager, when remediating, can only remediate if no WebACL is in place or force associate its WebACL.

    Required: No
    Type: String
    Default: Yes | If no current WebACL
    AllowedValues:
    - Yes | Replace existing existing WebACL
    - Yes | If no current WebACL
    - No

--- 

## AWS WAF v2 Configuration **[Optional]**

**RateLimitValue**  
The value for the WebACL deployed by Firewall Manager rate based rule.  This value represents how many request by IP can be made in a 5 minute look-back period.  IPs that exceed this limit take whatever action is configured by RateLimitAction (Default is block)

    Required: No
    Type: Number
    Default: 10000
    MinValue: 100
    MaxValue: 2,000,000

**RateLimitAction**  
The action for the WebACL deployed by Firewall Manager rate based rule. By default this will block

    Required: No
    Type: String
    Default: Block
    AllowedValues:
    - Count
    - Block

**IPReputationAMRAction**  
The WebACL deployed by Firewall Manager includes the AMR (Amazon Managed Rule)  [IPReputationAMRAction]().  The default action for this rule is COUNT.

    Required: No
    Type: String
    Default: Block
    AllowedValues:
    - Count
    - Block

**AnonymousIPAMRAction**  
The WebACL deployed by Firewall Manager includes the AMR (Amazon Managed Rule)  [AWSManagedRulesAnonymousIpList](https://docs.aws.amazon.com/waf/latest/developerguide/aws-managed-rule-groups-ip-rep.html#aws-managed-rule-groups-ip-rep-anonymoushttps://docs.aws.amazon.com/waf/latest/developerguide/aws-managed-rule-groups-ip-rep.html#aws-managed-rule-groups-ip-rep-amazon).  The default action for this rule is COUNT.

    Required: No
    Type: String
    Default: Count
    AllowedValues:
    - Count
    - Block

**KnownBadInputsAMRAction**  
The WebACL deployed by Firewall Manager includes the AMR (Amazon Managed Rule) 	[KnownBadInputsAMRAction](https://docs.aws.amazon.com/waf/latest/developerguide/aws-managed-rule-groups-baseline.html#aws-managed-rule-groups-baseline-known-bad-inputs).  The default action for this rule is COUNT.

    Required: No
    Type: String
    Default: Count
    AllowedValues:
    - Count
    - Block

**CoreRuleSetAMRAction**  
The WebACL deployed by Firewall Manager includes the AMR (Amazon Managed Rule)	[CoreRuleSetAMRAction](https://docs.aws.amazon.com/waf/latest/developerguide/aws-managed-rule-groups-baseline.html#aws-managed-rule-groups-baseline-crs).  The default action for this rule is COUNT.

    Required: No
    Type: String
    Default: Count
    AllowedValues:
    - Count
    - Block

--- 

## AWS Shield Advanced Protected Resource Configuration **[Optional]**

**RegionalAutomaticResponseStatus**  
Shield Advanced automatic application layer DDoS mitigation allows Shield Advanced in response to a HTTP flood against a protected regional resource (Application Load Balancers) based on a baseline from historic traffic.

    Required: No
    Type: String
    Default: ENABLED
    AllowedValues:
    - ENABLED
    - DISABLED

**RegionalAutomaticResponseAction**  
Specify the action the rule group created and managed by Shield Advanced automatic application layer DDoS mitigation on regional resources should take

    Required: No
    Type: String
    Default: COUNT
    AllowedValues:
    - COUNT
    - BLOCK

**CloudFrontAutomaticResponseStatus**  
Shield Advanced automatic application layer DDoS mitigation allows Shield Advanced in response to a HTTP flood against a protected CloudFront resource (Application Load Balancers) based on a baseline from historic traffic.

    Required: No
    Type: String
    Default: ENABLED
    AllowedValues:
    - ENABLED
    - DISABLED

**CloudFrontAutomaticResponseAction**  
Specify the action the rule group created and managed by Shield Advanced automatic application layer DDoS mitigation on CloudFront resources should take

    Required: No
    Type: String
    Default: COUNT
    AllowedValues:
    - COUNT
    - BLOCK

--- 

## AWS Shield Advanced SRT Access **[Optional]**

**SRTAccessRoleName**  
When SRT Access is granted that role will have this name.  Depending on the value of SRTAccessRoleAction, this is either the name of the role that will be created, or that already exists and should be used. If none, is specified, CloudFormation will generate the name for the role.

    Required: No
    Type: String
    Default: <Generated>

**SRTAccessRoleAction**  
When SRT Access is granted, is the role specified in SRTAccessRoleName a role that CloudFormation needs to create or that already exists.

    Required: No
    Type: String
    Default: CreateRole
    AllowedValues:
    - UseExisting
    - CreateRole

**SRTBuckets**  
When SRT Access is granted, you can optionally grant access to one or more S3 buckets.  This is not required for SRT to have access to WAF logs.

    Required: No
    Type: CommaDelimitedList
    Default: <na>

--- 

## AWS Shield Advanced Proactive Engagement **[Optional]**

**EmergencyContactEmail2**  
During a Proactive Engagement, SRT (Shield Response Team) will reach out to your emergency contacts.  You must configure one or more emergency contacts along with enabling Proactive Engagement.  Specify a valid e-mail address

    Required: Yes
    Type: String
    Default: <na>
    AllowedPattern: ^\S+@\S+\.\S+$|\<na\>

**EmergencyContactPhone2**  
During a Proactive Engagement, SRT (Shield Response Team) will reach out to your emergency contacts.  You must configure one or more emergency contacts along with enabling Proactive Engagement.  Specify a valid phone number + country code.  e.g. \+ 15555555555

    Required: Yes
    Type: String
    Default: <na>
    AllowedPattern: ^\+[0-9]{11}|\<na\>

**EmergencyContactNote2**  
During a Proactive Engagement, SRT (Shield Response Team) will reach out to your emergency contacts.  You must configure one or more emergency contacts along with enabling Proactive Engagement.  Provide notes/comments about this contact. E.g. SOC

    Required: Yes
    Type: String
    Default: <na>
    AllowedPattern: ^[\w\s\.\-,:/()+@]*$|\<na\>

**EmergencyContactEmail3**  
During a Proactive Engagement, SRT (Shield Response Team) will reach out to your emergency contacts.  You must configure one or more emergency contacts along with enabling Proactive Engagement.  Specify a valid e-mail address

    Required: No
    Type: String
    Default: <na>
    AllowedPattern: ^\S+@\S+\.\S+$|\<na\>

**EmergencyContactPhone3**  
During a Proactive Engagement, SRT (Shield Response Team) will reach out to your emergency contacts.  You must configure one or more emergency contacts along with enabling Proactive Engagement.  Specify a valid phone number + country code.  e.g. \+ 15555555555

    Required: No
    Type: String
    Default: <na>
    AllowedPattern: ^\+[0-9]{11}|\<na\>

**EmergencyContactNote3**  
During a Proactive Engagement, SRT (Shield Response Team) will reach out to your emergency contacts.  You must configure one or more emergency contacts along with enabling Proactive Engagement.  Provide notes/comments about this contact. E.g. SOC

    Required: No
    Type: String
    Default: <na>
    AllowedPattern: ^[\w\s\.\-,:/()+@]*$|\<na\>

**EmergencyContactEmail4**  
During a Proactive Engagement, SRT (Shield Response Team) will reach out to your emergency contacts.  You must configure one or more emergency contacts along with enabling Proactive Engagement.  Specify a valid e-mail address

    Required: No
    Type: String
    Default: <na>
    AllowedPattern: ^\S+@\S+\.\S+$|\<na\>

**EmergencyContactPhone4**  
During a Proactive Engagement, SRT (Shield Response Team) will reach out to your emergency contacts.  You must configure one or more emergency contacts along with enabling Proactive Engagement.  Specify a valid phone number + country code.  e.g. \+ 15555555555

    Required: No
    Type: String
    Default: <na>
    AllowedPattern: ^\+[0-9]{11}|\<na\>

**EmergencyContactNote4**  
During a Proactive Engagement, SRT (Shield Response Team) will reach out to your emergency contacts.  You must configure one or more emergency contacts along with enabling Proactive Engagement.  Provide notes/comments about this contact. E.g. SOC

    Required: No
    Type: String
    Default: <na>
    AllowedPattern: ^[\w\s\.\-,:/()+@]*$|\<na\>

**EmergencyContactEmail5**  
During a Proactive Engagement, SRT (Shield Response Team) will reach out to your emergency contacts.  You must configure one or more emergency contacts along with enabling Proactive Engagement.  Specify a valid e-mail address

    Required: No
    Type: String
    Default: <na>
    AllowedPattern: ^\S+@\S+\.\S+$|\<na\>

**EmergencyContactPhone5**  
During a Proactive Engagement, SRT (Shield Response Team) will reach out to your emergency contacts.  You must configure one or more emergency contacts along with enabling Proactive Engagement.  Specify a valid phone number + country code.  e.g. \+ 15555555555

    Required: No
    Type: String
    Default: <na>
    AllowedPattern: ^\+[0-9]{11}|\<na\>

**EmergencyContactNote5**  
During a Proactive Engagement, SRT (Shield Response Team) will reach out to your emergency contacts.  You must configure one or more emergency contacts along with enabling Proactive Engagement.  Provide notes/comments about this contact. E.g. SOC

    Required: No
    Type: String
    Default: <na>
    AllowedPattern: ^[\w\s\.\-,:/()+@]*$|\<na\>

--- 

## Shield Resource Scoping **[Optional]**

**ResourceTagUsage**  
If tags are used to scope with Firewall Manager Security Policies, are these tags what to include (in scope) or what to exclude (out of scope).

    Required: No
    Type: String
    Default: Include
    AllowedValues:
      - Include
      - Exclude

**ShieldScopeTagName1**  
For Firewall Manager Security policies for Shield protection, one or more tag names can be used to define in scope resources. If you only specify a scope tag name, resources with this tag and any value are in scope.

    Required: No
    Type: String
    Default: <na>

**ShieldScopeTagName2**  
For Firewall Manager Security policies for Shield protection, one or more tag names can be used to define in scope resources. If you only specify a scope tag name, resources with this tag and any value are in scope.

    Required: No
    Type: String
    Default: <na>

**ShieldScopeTagName3**  
For Firewall Manager Security policies for Shield protection, one or more tag names can be used to define in scope resources. If you only specify a scope tag name, resources with this tag and any value are in scope.

    Required: No
    Type: String
    Default: <na>

**ShieldScopeTagValue1**  
For Firewall Manager Security policies for Shield protection, one or more tag name/value can be used to define in scope resources. This defines the exact value for the corresponding tag to be considered in scope.

    Required: No
    Type: String
    Default: <na>

**ShieldScopeTagValue2**  
For Firewall Manager Security policies for Shield protection, one or more tag name/value can be used to define in scope resources. This defines the exact value for the corresponding tag to be considered in scope.

    Required: No
    Type: String
    Default: <na>

**ShieldScopeTagValue3**  
For Firewall Manager Security policies for Shield protection, one or more tag name/value can be used to define in scope resources. This defines the exact value for the corresponding tag to be considered in scope.

    Required: No
    Type: String
    Default: <na>

## WAFv2 Resource Scoping **[Optional]**
**WAFv2ScopeTagName1**  
For Firewall Manager Security policies for WAFv2 protection, one or more tag names can be used to define in scope resources. If you only specify a scope tag name, resources with this tag and any value are in scope.

    Required: No
    Type: String
    Default: <na>

**WAFv2ScopeTagName2**  
For Firewall Manager Security policies for WAFv2 protection, one or more tag names can be used to define in scope resources. If you only specify a scope tag name, resources with this tag and any value are in scope.

    Required: No
    Type: String
    Default: <na>

**WAFv2ScopeTagName3**  
For Firewall Manager Security policies for WAFv2 protection, one or more tag names can be used to define in scope resources. If you only specify a scope tag name, resources with this tag and any value are in scope.

    Required: No
    Type: String
    Default: <na>

**WAFv2ScopeTagValue1**  
For Firewall Manager Security policies for WAFv2 protection, one or more tag name/value can be used to define in scope resources. This defines the exact value for the corresponding tag to be considered in scope.

    Required: No
    Type: String
    Default: <na>

**WAFv2ScopeTagValue2**  
For Firewall Manager Security policies for WAFv2 protection, one or more tag name/value can be used to define in scope resources. This defines the exact value for the corresponding tag to be considered in scope.

    Required: No
    Type: String
    Default: <na>

**WAFv2ScopeTagValue3**  
For Firewall Manager Security policies for WAFv2 protection, one or more tag name/value can be used to define in scope resources. This defines the exact value for the corresponding tag to be considered in scope.

    Required: No
    Type: String
    Default: <na>

--- 

## Misc **[Optional]**

**UseLakeFormationPermissions**  
If using AWS LakeFormation, should S3 permissions use LakeFormation or S3? Only needed if you have enabled AWS LakeFormation.

    Required: No
    Type: String
    Default: False
    AllowedValues:
      - True
      - False

**optimizeUnassociatedWebACLValue**  
If you want Firewall Manager to manage unassociated web ACLs, then enable Manage unassociated web ACLs.

    Required: No
    Type: String
    Default: True
    AllowedValues:
      - True
      - False

**S3BucketName**  
If you want to use an existing S3 Bucket or have this create a new bucket for WAF logs.  Specify <Generated> to have a bucket created.

    Required: No
    Type: String
    Default: <Generated>

**RootId**  
Specify the AWS Organization Root Id.  StackSets to deploy FMS and potentially scope FMS to accounts using Service Managed StackSets requires providing an OU/root and then list of accounts to only target.  You can retrieve your root ID from the payer or an AWS Organizations delegated administrator of your AWS Organization.

> aws organizations list-roots --query Roots[0]."Id"
> r-1a2b

    Required: No
    Type: String

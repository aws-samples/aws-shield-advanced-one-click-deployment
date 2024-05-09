# Overview
AWS Shield Advanced One Click deployments allows customers getting started with Shield Advanced to get an out of the box recommended baseline configuration.  You execute a single Python script and 16 required input parameters with 39 optional parameters to scope and otherwise tune this deployment.  This template creates:  

## Core Deployment

### Central Common resources  
A core deployment creates a central S3 bucket for all WAFv2 logs as well as an Athena Table with useful named queries and views, and some additional supporting resources.  

## Organizational Deployment
### Subscribe and Configure Shield Advanced  
Subscribes account to Shield via a custom lambda backed resource.  Configures Sheild Response Team (SRT) access and proactive engagement

### Firewall Manager Security Policies for Shield Protection  
Creates Security policies in each configured region and globally (if desired) to ensure resources are shield protected based on a provided scope

### Firewall Manager Security Policies for WAFv2  
Creates Security policies in each configured region and globally (if desired) to manage WAFv2 on supported resources based on a provided scope


# Prerequisites

##  AWS Support  
Business or Enterprise Support must be enabled on any account where SRT access and/or Proactive Engagment will be enabled

## AWS Organizations
This will only apply to accounts that are members of your designated AWS Organization. The Python script queries your Organization Management account to identify all the member Organizational Units and Accounts
Recommended to delegate administration to another account such as your default Firewall Manager administrator account. (see below)

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

# Deployment configuration
## Default
If you only provide answers for mandatory fields, the default deployment will do the following:

1. Subscribe and configure Shield Advanced for all AWS accounts within the AWS Organization.  
2. Shield protect all supported regional resources as well as CloudFront distributions.  
3. All CloudFront Distributions, Application Load balancers, and API Gateways will have an AWS WAF WebACL attached (if there was not already one in place).  
4. All WebACLs send WAF logs to a central bucket in a central region. _This S3 bucket is created in the location the initial stack was deployed in._
5.  The WebACl includes the following rules:  
a) A [Rate based rule](https://docs.aws.amazon.com/waf/latest/developerguide/waf-rule-statement-type-rate-based.html) with a value of 10,000 action of Count  
b) [Anonymous IP](https://docs.aws.amazon.com/waf/latest/developerguide/aws-managed-rule-groups-ip-rep.html#aws-managed-rule-groups-ip-rep-anonymous) Amazon Managed rule | All rule actions overridden to Count  
c) [IP Reputation](https://docs.aws.amazon.com/waf/latest/developerguide/aws-managed-rule-groups-ip-rep.html#aws-managed-rule-groups-ip-rep-amazon) Amazon Managed rule | All rules with action Block  
d) [Core Rule Set](https://docs.aws.amazon.com/waf/latest/developerguide/aws-managed-rule-groups-baseline.html#aws-managed-rule-groups-baseline-crs) Amazon Managed rule | All rule actions overridden to Count  
e) [Known Bad Inputs](https://docs.aws.amazon.com/waf/latest/developerguide/aws-managed-rule-groups-baseline.html#aws-managed-rule-groups-baseline-known-bad-inputs) Amazon Managed rule | All rule actions overridden to Count  
6.  An Athena Table and workgroup created with several named queries and views relevant to reviewing WAF logs.

## **Customization**

Terraform variables allow you to change the default behavior as follows:

### **Scope**
1. You can configure which region(s) are in scope.  This applies to subscribing and configuring Shield as well as Firewall Manager security policies.
2. You can configure which AWS accounts are in scope.  This applies to subscribing and configuring Shield as well as Firewall Manager security policies.
3. Firewall Manager security policies can be scoped to only certain resource types and/or the presence of specific tags on resources.
4. Firewall Manager security policies can be scoped based on the specific tag name/values or existance of specific tag names.  Shield and WAFv2 policies can specify different tag scopes.

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

The python script tfstacks.py executes both the core-deployment and organizational-deployment Terraform configurations. 
You will need 2 separate tfvars files to be referenced during the script execution. See below for example execution of the python script. (It is advised to run this inside a python virtual environment). The `core-var-file` and the `org-var-file` tfvars are relative to the `core-deployment` and `organizational-deployment` directories respectively.

```
python3 tfstacks.py --core-var-file example.tfvars --org-var-file example.tfvars
```

The following sections require your acknowledgment (Set to _true_) or have a mandatory input that require your attention.

# Required Terraform Configuration 

In order to properly configure Terraform for your environment the backend configuration *MUST* be customized to your environment. In the `core-deployment` and `organizational-deployment` directories in the `terraform` block within `main.tf` you *MUST* enter the appropriate values for your backend s3 configuration (or leverage another backend). 

*NOTE:* The execution of this relies on workspaces to control the deployments to the individual accounts.
```
backend "s3" {
    // Backend state MUST be properly confgured and is specific to deployment environment.
    bucket = "<BACKEND_STATE_BUCKET>"
    workspace_key_prefix = "<WORKSPACE_KEY_PREFIX>"
    key = "<BACKEND_STATE_FILE_KEY>"
    region = "<BACKEND_REGION>"
  }
```

# Variables
Variables are divided into logical groups of parameters between mandatory and optional parameters.  Mandatory parameters either require the end user to input/select a value, or explicity verify something.  Optional parameters allow end users to customize (e.g. WAF rule actions ) or configure optional features (e.g more than one proactive engagement emergency contact)

--- 

## Core Deployment
The core-deployment has only 2 variables that must be set to be available to set up.

- `scope_regions`: This will determine which regions will be affected. The python script utilizes this variable in addition to Terraform to determine which regions in the Organization Accounts will be targeted.
- `use_lake_formation_permisisons`: This determines if lake formation permissions are used when creating the Athena
```
scope_regions = ["<region1>", "<region2>", ..., "regionN"]
use_lake_formation_permissions = true | false
```
- `region`: This is the target region for the primary deployment in which the aws provider is anchored.

## AWS Shield Advanced Subscription **[Mandatory]**

**AcknowledgeServiceTermsPricing**  
Acknowledge AWS Shield Advanced has a $3000 / month subscription fee for a consolidated billing family

    Variable: acknowledge_service_terms_pricing
    Required: Yes
    Type: bool
    AllowedValues: true, false

**AcknowledgeServiceTermsDTO**  
Acknowledge AWS Shield Advanced has a Data transfer out usage fees for all protected resources.

    Variable: acknowledge_service_terms_dto
    Required: Yes
    Type: bool
    AllowedValues: true, false

**AcknowledgeServiceTermsCommitment**  
AWS Shield Advanced has a 12 month commitment.

    Variable: acknowledge_service_terms_commitment
    Required: Yes
    Type: bool
    AllowedValues: true, false

**AcknowledgeServiceTermsAutoRenew**  
Acknowledge Shield Advanced subscriptions will auto-renewed after 12 months.  However, I can opt out of renewal 30 days prior to the renewal date.

    Variable: acknowledge_service_terms_auto_renew
    Required: Yes
    Type: bool
    AllowedValues: true, false

**AcknowledgeNoUnsubscribe**  
Acknowledge a Shield Advanced subscription comittment will continue even if this Terraform Deployment is deleted.

    Variable: acknowledge_no_unsubscribe
    Required: Yes
    Type: bool
    AllowedValues: true, false

--- 

## AWS Shield Advanced Configuration **[Mandatory]**

**EnableSRTAccess**  
AWS Shield Advanced allows you to create and authorize SRT (Shield Response Team) access to update your AWS WAF WebACLs.  Specify if this feature should be enabled or disabled.

    Variable: enable_srt_access
    Required: Yes
    Type: bool
    AllowedValues: true, false


**EnabledProactiveEngagement**  
AWS SRT (Shield Response Team) can proactively reach out when Shield Advanced detects a DDoS event and your application health is impacted (required configuring Route 53 health checks).  One or more emergency contacts must also be configured

    Variable: enable_proactive_engagement
    Required: Yes
    Type: bool
    AllowedValues: true, false

**EmergencyContactEmail1**  
During a Proactive Engagement, SRT (Shield Response Team) will reach out to your emergency contacts.  You must configure one or more emergency contacts along with enabling Proactive Engagement.  Specify a valid e-mail address

    Variable: emergency_contact_email1
    Required: Yes
    Type: String
    AllowedPattern: ^\S+@\S+\.\S+$|\<na\>

**EmergencyContactPhone1**  
During a Proactive Engagement, SRT (Shield Response Team) will reach out to your emergency contacts.  You must configure one or more emergency contacts along with enabling Proactive Engagement.  Specify a valid phone number + country code.  e.g. \+ 15555555555

    Variable: emergency_contact_phone1
    Required: Yes
    Type: String
    AllowedPattern: ^\+[0-9]{11}|\<na\>

**EmergencyContactNote1**  
During a Proactive Engagement, SRT (Shield Response Team) will reach out to your emergency contacts.  You must configure one or more emergency contacts along with enabling Proactive Engagement.  Provide notes/comments about this contact. E.g. SOC

    Variable: emergency_contact_note1
    Required: Yes
    Type: String
    AllowedPattern: ^[\w\s\.\-,:/()+@]*$|\<na\>

## Scope **[Mandatory]**

**FMSAdministratorAccountId**
The account ID where Firewall Manager security policies be created in.  There is no default and the account ID must be provided.

    Variable: fms_admin_account_id
    Required: Yes
    Type: String
    AllowedPatterns:
      - \d{12}

**ScopeType**  
CloudFormation Service Managed StackSets can be deployed to an entire AWS Organization, a list of OUs, or a list of accounts.  Specify which scope you would like to target for this deployment.  This applies to subscribing and configured, Shield protecting resources, and WAFv2 protecting resources.

    Variable: scope_type
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

    Variable: scope_details
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

    Variable: include_exclude_scope
    Required: Yes
    Type: String
    Default: Include
    AllowedValues:
    - Include

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
    AllowedValues:
      - AWS::CloudFront::Distribution
      - <na>

**WAFv2ProtectRegionalResourceTypes**  
Firewall Manager can create and associate a WebACl on regional Resources.  Select one of the following combinations of supported regional resources

    Required: No
    Type: String
    AllowedValues:
      - AWS::ApiGateway::Stage,AWS::ElasticLoadBalancingV2::LoadBalancer
      - AWS::ElasticLoadBalancingV2::LoadBalancer
      - AWS::ApiGateway::Stage
      - <na>

**WAFv2ProtectCloudFront**  
Firewall Manager can create and associate a WebACl on global Resources. Select one of the following combinations of supported global resources

    Required: No
    Type: String
    AllowedValues:
      - AWS::CloudFront::Distribution
      - <na>

**ShieldAutoRemediate**  
Firewall Manager can establish Shield Protection for regional and global resources.  For resources that are in scope, should in scope AWS resource types have Shield Advanced protection automatically be remediated?

    Required: No
    Type: String
    AllowedValues: 
    - Yes
    - No

**WAFv2AutoRemediate**  
Firewall Manager can create and associate WAF WebACLs for regional and global resources.  Should in scope AWS resource types that support AWS WAF automatically be remediated? For resources that are in scope, if a resource does not have the Firewall Managered WebACL, what action should be taken.  Firewall Manager, when remeidating, can only remediate if no WebACL is in place or force associate its WebACL.

    Required: No
    Type: String
    Default: Yes | If no current WebACL
    AllowedValues:
    - Yes | Replace existing exsiting WebACL
    - Yes | If no current WebACL
    - No

--- 

## AWS WAF v2 Configuration **[Optional]**

**RateLimitValue**  
The value for the WebACL deployed by Firewall Manager rate based rule.  This value represents how many request by IP can be made in a 5 minute lookback period.  IPs that exceed this limit take whatever action is configured by RateLimitAction (Default is block)

    Required: No
    Type: Number
    Minvalue: 100
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

## AWS Shield Advanced SRT Access **[Optional]**

**SRTAccessRoleName**  
When SRT Access is granted that role will have this name.  Depending on the value of SRTAccessRoleAction, this is either the name of the role that will be created, or that already exists and should be used. If none, is specified, CloudFormation will generate the name for the role.

    Required: No
    Type: String

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
    AllowedPattern: ^\S+@\S+\.\S+$|\<na\>

**EmergencyContactPhone2**  
During a Proactive Engagement, SRT (Shield Response Team) will reach out to your emergency contacts.  You must configure one or more emergency contacts along with enabling Proactive Engagement.  Specify a valid phone number + country code.  e.g. \+ 15555555555

    Required: Yes
    Type: String
    AllowedPattern: ^\+[0-9]{11}|\<na\>

**EmergencyContactNote2**  
During a Proactive Engagement, SRT (Shield Response Team) will reach out to your emergency contacts.  You must configure one or more emergency contacts along with enabling Proactive Engagement.  Provide notes/comments about this contact. E.g. SOC

    Required: Yes
    Type: String
    AllowedPattern: ^[\w\s\.\-,:/()+@]*$|\<na\>

**EmergencyContactEmail3**  
During a Proactive Engagement, SRT (Shield Response Team) will reach out to your emergency contacts.  You must configure one or more emergency contacts along with enabling Proactive Engagement.  Specify a valid e-mail address

    Required: No
    Type: String
    AllowedPattern: ^\S+@\S+\.\S+$|\<na\>

**EmergencyContactPhone3**  
During a Proactive Engagement, SRT (Shield Response Team) will reach out to your emergency contacts.  You must configure one or more emergency contacts along with enabling Proactive Engagement.  Specify a valid phone number + country code.  e.g. \+ 15555555555

    Required: No
    Type: String
    AllowedPattern: ^\+[0-9]{11}|\<na\>

**EmergencyContactNote3**  
During a Proactive Engagement, SRT (Shield Response Team) will reach out to your emergency contacts.  You must configure one or more emergency contacts along with enabling Proactive Engagement.  Provide notes/comments about this contact. E.g. SOC

    Required: No
    Type: String
    AllowedPattern: ^[\w\s\.\-,:/()+@]*$|\<na\>

**EmergencyContactEmail4**  
During a Proactive Engagement, SRT (Shield Response Team) will reach out to your emergency contacts.  You must configure one or more emergency contacts along with enabling Proactive Engagement.  Specify a valid e-mail address

    Required: No
    Type: String
    AllowedPattern: ^\S+@\S+\.\S+$|\<na\>

**EmergencyContactPhone4**  
During a Proactive Engagement, SRT (Shield Response Team) will reach out to your emergency contacts.  You must configure one or more emergency contacts along with enabling Proactive Engagement.  Specify a valid phone number + country code.  e.g. \+ 15555555555

    Required: No
    Type: String
    AllowedPattern: ^\+[0-9]{11}|\<na\>

**EmergencyContactNote4**  
During a Proactive Engagement, SRT (Shield Response Team) will reach out to your emergency contacts.  You must configure one or more emergency contacts along with enabling Proactive Engagement.  Provide notes/comments about this contact. E.g. SOC

    Required: No
    Type: String
    AllowedPattern: ^[\w\s\.\-,:/()+@]*$|\<na\>

**EmergencyContactEmail5**  
During a Proactive Engagement, SRT (Shield Response Team) will reach out to your emergency contacts.  You must configure one or more emergency contacts along with enabling Proactive Engagement.  Specify a valid e-mail address

    Required: No
    Type: String
    AllowedPattern: ^\S+@\S+\.\S+$|\<na\>

**EmergencyContactPhone5**  
During a Proactive Engagement, SRT (Shield Response Team) will reach out to your emergency contacts.  You must configure one or more emergency contacts along with enabling Proactive Engagement.  Specify a valid phone number + country code.  e.g. \+ 15555555555

    Required: No
    Type: String
    AllowedPattern: ^\+[0-9]{11}|\<na\>

**EmergencyContactNote5**  
During a Proactive Engagement, SRT (Shield Response Team) will reach out to your emergency contacts.  You must configure one or more emergency contacts along with enabling Proactive Engagement.  Provide notes/comments about this contact. E.g. SOC

    Required: No
    Type: String
    AllowedPattern: ^[\w\s\.\-,:/()+@]*$|\<na\>

--- 

## Shield Resource Scoping **[Optional]**

**ResourceTagUsage**  
If tags are used to scope with Firewall Manager Security Policies, are these tags what to include (in scope) or what to exclude (out of scope).

    Required: No
    Type: String
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

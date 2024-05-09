variable "srt_access_role_name" {
  type    = string
  default = "<Generated>"
}

variable "target_aws_account_region" {
  type    = string
}

variable "srt_access_role_action" {
  type    = string
  default = "CreateRole"
  validation {
    condition     = contains(["CreateRole", "UseExisting"], var.srt_access_role_action)
    error_message = "Allowed values are [ CreateRole | UseExisting ]"
  }
}

variable "enable_srt_access" {
  type    = bool
  default = false
}

variable "enable_proactive_engagement" {
  type    = bool
  default = false
  description = "Enable Proactive Engagement.  Note you must also configure emergency contact(s) and health checks for protected resources for this feature to be effective"
}

variable "srt_buckets" {
  type    = list(string)
  default = []
  validation {
    condition     = length(var.srt_buckets) <= 10
    error_message = "At most 10 buckets are allowed"
  }
}

variable "acknowledge_service_terms_pricing" {
  description = "Shield Advanced Service Term | Pricing | $3000 / month subscription fee for a consolidated billing family"
  type    = bool
  default = false
}

variable "acknowledge_service_terms_dto" {
  description = "Shield Advanced Service Term | Pricing | Data transfer out usage fees for all protected resources."
  type    = bool
  default = false
}

variable "acknowledge_service_terms_commitment" {
  description = "Shield Advanced Term | Commitment | I am committing to a 12 month subscription."
 type    = bool
  default = false
}

variable "acknowledge_service_terms_auto_renew" {
  description = "Shield Advanced Term | Auto renewal | Subscription will be auto-renewed after 12 months. However, I can opt out of renewal 30 days prior to the renewal date."
  type    = bool
  default = false
}

variable "acknowledge_no_unsubscribe" {
  description = "Shield Advanced does not un-subscribe on delete | Shield Advanced does not un-subscribe if you delete this stack/this resource."
  type    = bool
  default = false
}

variable "emergency_contact_email1" {
  type    = string
  default = "<na>"
  validation {
    condition     = can(regex("^\\S+@\\S+\\.\\S+$|<na>", var.emergency_contact_email1))
    error_message = "Invalid input for variable"
  }
}

variable "emergency_contact_email2" {
  type    = string
  default = "<na>"
  validation {
    condition     = can(regex("^\\S+@\\S+\\.\\S+$|<na>", var.emergency_contact_email2))
    error_message = "Invalid input for variable"
  }
}

variable "emergency_contact_email3" {
  type    = string
  default = "<na>"
  validation {
    condition     = can(regex("^\\S+@\\S+\\.\\S+$|<na>", var.emergency_contact_email3))
    error_message = "Invalid input for variable"
  }
}

variable "emergency_contact_email4" {
  type    = string
  default = "<na>"
  validation {
    condition     = can(regex("^\\S+@\\S+\\.\\S+$|<na>", var.emergency_contact_email4))
    error_message = "Invalid input for variable"
  }
}

variable "emergency_contact_email5" {
  type    = string
  default = "<na>"
  validation {
    condition     = can(regex("^\\S+@\\S+\\.\\S+$|<na>", var.emergency_contact_email5))
    error_message = "Invalid input for variable"
  }
}

variable "emergency_contact_phone1" {
  type    = string
  default = "<na>"
  validation {
    condition     = can(regex("^\\+[0-9]{11}|<na>", var.emergency_contact_phone1))
    error_message = "Invalid input for variable"
  }
}

variable "emergency_contact_phone2" {
  type    = string
  default = "<na>"
  validation {
    condition     = can(regex("^\\+[0-9]{11}|<na>", var.emergency_contact_phone2))
    error_message = "Invalid input for variable"
  }
}

variable "emergency_contact_phone3" {
  type    = string
  default = "<na>"
  validation {
    condition     = can(regex("^\\+[0-9]{11}|<na>", var.emergency_contact_phone3))
    error_message = "Invalid input for variable"
  }
}

variable "emergency_contact_phone4" {
  type    = string
  default = "<na>"
  validation {
    condition     = can(regex("^\\+[0-9]{11}|<na>", var.emergency_contact_phone4))
    error_message = "Invalid input for variable"
  }
}

variable "emergency_contact_phone5" {
  type    = string
  default = "<na>"
  validation {
    condition     = can(regex("^\\+[0-9]{11}|<na>", var.emergency_contact_phone5))
    error_message = "Invalid input for variable"
  }
}

variable "emergency_contact_note1" {
  type    = string
  default = "<na>"
  nullable = true
  validation {
    condition     = can(regex("^[\\w\\s\\.\\-,:/()+@]*$|<na>", var.emergency_contact_note1))
    error_message = "Invalid input for variable"
  }
}

variable "emergency_contact_note2" {
  type    = string
  default = "<na>"
  nullable = true
  validation {
    condition     = can(regex("^[\\w\\s\\.\\-,:/()+@]*$|<na>", var.emergency_contact_note2))
    error_message = "Invalid input for variable"
  }
}

variable "emergency_contact_note3" {
  type    = string
  default = "<na>"
  nullable = true
  validation {
    condition     = can(regex("^[\\w\\s\\.\\-,:/()+@]*$|<na>", var.emergency_contact_note3))
    error_message = "Invalid input for variable"
  }
}

variable "emergency_contact_note4" {
  type    = string
  default = "<na>"
  nullable = true
  validation {
    condition     = can(regex("^[\\w\\s\\.\\-,:/()+@]*$|<na>", var.emergency_contact_note4))
    error_message = "Invalid input for variable"
  }
}

variable "emergency_contact_note5" {
  type    = string
  default = "<na>"
  nullable = true
  validation {
    condition     = can(regex("^[\\w\\s\\.\\-,:/()+@]*$|<na>", var.emergency_contact_note5))
    error_message = "Invalid input for variable"
  }
}
variable "airly_api_key" {
  description = "API key generated for you. String value, of apikey from https://developer.airly.eu/docs#general.authentication. No default."
  type        = string
}

variable "airly_base_url" {
  default     = "https://airapi.airly.eu/v2" # current version of API when code was being written
  description = "Base URL of Airly API. String value. Default is \"https://airapi.airly.eu/v2\"."
  type        = string
}

variable "airly_max_distance" {
  default     = 5 # safe value for having acurate reading without need of interpolation
  description = "Maximal distance, in km, of measurements point to use. Numeric value. Default is 5."
  type        = number
}

variable "airly_measurements_methods" {
  default     = "measurements/nearest" # current method string when code was being written
  description = "API method to call for measurements from nearest installation. String value, defined in https://developer.airly.eu/docs#endpoints.meta.measurements. Default is \"easurements/nearest\"."
  type        = string
}

variable "aws_access_key" {
  description = "Access key of IAM user used to deploy infrastructure. Set it together with aws_secret_key, or set aws_credentials_file and aws_profile. String value. No default."
  type        = string
}

variable "aws_credentials_file" {
  default     = "$HOME/.aws/credentials" # default value used by Linux or WSL
  description = "Location of AWS credentials file to use together with aws_profile name. On different operaing systems may require change. String value. Default is \"$HOME/.aws/credentials\"."
  type        = string
}

variable "aws_profile" {
  description = "Name of AWS profile defined in aws_credentials_file of IAM user used to deploy infrastructure. Set it together with aws_credentials_file, or set aws_access_key and aws_secret_key. String value. No default."
  type        = string
}

variable "aws_secret_key" {
  description = "Secret key of IAM user used to deploy infrastructure. Set it together with aws_access_key, or set aws_credentials_file and aws_profile. String value. No default."
  type        = string
}

variable "aws_region" {
  default     = "eu-west-1" # main region in Europa, having most up to dat features
  description = "Name of AWS region used for deploying infrastructure. String value. Default is \"eu-west-1\"."
  type        = string
}

variable "log_retention" {
  default     = 30 # safe value of 1 month
  description = "Number of days to retaing Lambda logs in CloudWatch. Numeric values. Default is 30."
  type        = number
}

variable "enable_bucket_creation" {
  default     = true # will try to create s3_bucket bucket
  description = "Switch for enabling (true) S3 bucket for placing deployment package. If s3_bucket points to already existing bucket no need of enabling it. Boolean value. Default is true."
  type        = bool
}

variable "enable_bucket_termination" {
  default     = true # will destroy s3_bucket bucket when whole stack is terminated
  description = "Switch for enabling (true) S3 bucket termination when whole stack is terminated. Will delete bucket is not empty. Better set false if you use already existing bucket. Boolean value. Default is true."
}

variable "function_description" {
  default     = "Airly API integration for gathering air pollution information periodicaly" # some default jolly description
  description = "Description of Lambda function visible in console page. String value. Default as example."
  type        = string
}

variable "function_dir" {
  default     = "source" # default location
  description = "Name of directory with Lambda source. Change if you choose to move it. String value. Default is \"source\"."
  type        = string
}

variable "function_memory_limit" {
  default     = 128 # lowest value, as function is very simple
  description = "Memory limit for Lamnda. Numeric value. Default is 128."
  type        = number
}

variable "function_name" {
  default     = "airly-api-notifications" # some default value
  description = "Name of Lambda function visible in console page. String value. Default is \"airly-api-notifications\"."
  type        = string
}

variable "function_runtime" {
  default     = "python3.7" # Lambda was tested written in tested in Python 3.7 in mind
  description = "Name of Lambda runtime used. String value. Default is \"python3.7\"."
  type        = string

}

variable "function_timeout" {
  default     = 3 # safe value as it's simple function
  description = "Timeout of Lambda function. Numeric value. Default is 3."
  type        = number
}

variable "user_email" {
  description = "Email address to send air quality reports to. Can be empty. String value. No default."
  type        = string
}

variable "user_locations" {
  default = [
    {
      expression = "cron(0 11 ? * * *)"                         # trumpet call played at 12:00 each day - https://en.wikipedia.org/wiki/St._Mary%27s_Trumpet_Call
      map_point  = "https://airly.eu/map/en/#50.06170,19.93734" # location of Krakow Cloth Hall - https://en.wikipedia.org/wiki/Krak%C3%B3w_Cloth_Hall
      name       = "Sukiennice"                                 # name of this place in Polish
    }
  ]
  description = "List of location objects defining probing spots and times for checks. See README.md for details. List of object. Example of Sukiennice as default."
  type = list(object({
    expression = string # CW cron or rate for triggering Lambda, can be empty, time in UTC
    map_point  = string # full URL of map point to check
    name       = string # name of map point
  }))
}

variable "user_phone" {
  description = "Phone number to send air quality reports to. In international format. Can be empty. String value. No default."
  type        = string
}

variable "s3_bucket" {
  description = "Name of S3 bucket for placing Lambda deployment packages. String value. Default will be created in locals in main.tf."
  type        = string
}

variable "s3_key" {
  description = "Name of s3 key on s3_bucket for Lambda package. String value. Default will be created in locals in main.tf."
  type        = string
}

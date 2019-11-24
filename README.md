# lambda-airly


# CAUTION: This project is at work-in-progress stage
Some parts of it may not be committed to this repository yet or are not working properly.<br>
Some parts are still placeholders for functionality that will be added in near future.<br>
If you found it somehow, tried to run it already and have some questions or remarks please use [issues link](https://github.com/Krzysztof-Szyper-Epam/lambda-airly/issues).

# Description
[AWS](https://aws.amazon.com/) [Lambda](https://aws.amazon.com/lambda/) function/application invoking [Airly](https://airly.eu/) [API](https://developer.airly.eu/) to get some basic information about current [air quality](https://www.airqualitynow.eu/pollution_home.php).

Lambda code is writen in [Python](https://www.python.org/) and is rather easy to understand. As it only calls API and filters the result.

# Prerequisites
- [AWS](https://aws.amazon.com/) account, free tier should be enough to run it.
- [Airly devloper](https://developer.airly.eu/) account with [API key](https://developer.airly.eu/docs#general.authentication)
- [Python](https://www.python.org/) and [Terraform](https://www.terraform.io/) basics
- [Linux](https://www.linux.org/) or [WSL](https://docs.microsoft.com/pl-pl/windows/wsl/install-win10) for running deployment scripts and tasks
- [Docker](https://www.docker.com/) host application to run the deployment (for building Python requirements)

# Terraform disclaimer
Infrastructure part can be easily deployed with [Terraform](https://www.terraform.io/) with already existing definition.<br>
It's meant be just an example of implementation, hence S3 bucket used for Lambda package will be created and destroy by default.<br>
For simplicity Terraform backend is set be local only, so don't run it in a container or untrusted host, because you may loose or expose your tfstate file.<br>
To adjust it to your existing infrastructure some Terraform basic knowledge is necessary.

# AWS credentials
Since example is meant to be run from automation tool or locally as one of many other separated stacks credentials used by Terraform need to be explicitly provided.<br>
There are two ways of doing it:
- Use IAM keys by setting `aws_access_key` and `aws_secret_key`.
- Use credentials file and choose profile from it by setting `aws_credentials_file` and `aws_profile`.
If both configurations are defined keys will be used.

# Configuration
Create `secrets.tfvars` file and put there your values as in example below.<br>
For more details see description of those variables in `variables.tf`.<br>
Example shows value that you *NEED* to set, other values can be overwritten if you like.
```hcl-terraform
airly_api_key             = "1234567890abcdefABCDEF1234567890"
aws_access_key            = ""
aws_credentials_file      = "$HOME/.aws/credentials"
aws_profile               = "example"
aws_secret_key            = ""
enable_bucket_creation    = true
enable_bucket_termination = true
user_email                = ""
user_locations = [{
  expression = "cron(0 11 ? * * *)"                         # trumpet call played at 12:00 each day - https://en.wikipedia.org/wiki/St._Mary%27s_Trumpet_Call
  map_point  = "https://airly.eu/map/en/#50.06170,19.93734" # location of Krakow Cloth Hall - https://en.wikipedia.org/wiki/Krak%C3%B3w_Cloth_Hall
  name       = "Sukiennice"                                 # name of this place in Polish
}]
user_phone = ""
s3_bucket  = ""
s3_key     = ""
```

# Test

# Deploy
- `cd terraform`
- `terraform init`
- `terraform apply -var-file=secrets.tfvars`

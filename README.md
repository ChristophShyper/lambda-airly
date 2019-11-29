# lambda-airly


# Description
[AWS](https://aws.amazon.com/) [Lambda](https://aws.amazon.com/lambda/) function/application invoking [Airly](https://airly.eu/) [API](https://developer.airly.eu/) to get some basic information about current [air quality](https://www.airqualitynow.eu/pollution_home.php).

Lambda code is writen in [Python](https://www.python.org/) and is rather easy to understand. As it only calls API and filters the result.

## Email notification
Full information about at all indexes, pollutants and weather conditions.<br>  
Example of email received when there is bad air quality at location named Home:
![Email notification example](https://raw.githubusercontent.com/Krzysztof-Szyper-Epam/lambda-airly/master/images/email.png)

## SMS notification
Only basic information, about main index value, percentage of pollutants indexes, and weather conditions.<br>
Example of SMS received when there is good air quality at location named Home.
![SMS notification example](https://raw.githubusercontent.com/Krzysztof-Szyper-Epam/lambda-airly/master/images/sms.png)

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
Follow instruction in [AWS documentation](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-configure.html).

# Configuration
Create `secrets.tfvars` file and put there your values as in example below.<br>
For more details see description of those variables in `variables.tf`.<br>
Example shows value that you *NEED* to set, other values can be overwritten if you like.
```hcl-terraform
airly_api_key             = "1234567890abcdefABCDEF1234567890"
enable_bucket_creation    = true
enable_bucket_termination = true
user_email                = "" # can be empty - email notification will not be sent
user_locations = [{
  expression = "cron(0 11 ? * * *)"                         # trumpet call played at 12:00 each day - https://en.wikipedia.org/wiki/St._Mary%27s_Trumpet_Call
  map_point  = "https://airly.eu/map/en/#50.06170,19.93734" # location of Krakow Cloth Hall - https://en.wikipedia.org/wiki/Krak%C3%B3w_Cloth_Hall
  name       = "Sukiennice"                                 # name of this place in Polish
}]
user_phone = ""          # can be empty - text notification will not be sent
s3_bucket  = "my-bucket" # must be provided
s3_key     = ""          # can be empty - default location will be created
```

# Test

# Deploy
- `cd terraform`
- `terraform init`
- `terraform apply -var-file=secrets.tfvars`

provider "aws" {
  region  = "eu-central-1"
  profile = "team1"
}

provider "vault" {
  token   = "s.6Vk2jElZwOWLpqdwBkh1UkH5"
  address = "https://vault.dv-gidideals.co.uk"
}
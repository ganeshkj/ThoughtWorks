output "CompanyNewsWeb" {
  value = "${aws_instance.CompanyNewsWeb.public_ip}"
}

output "CompanyNewsAppl" {
  value = "${aws_instance.CompanyNewsAppl.public_ip}"
}
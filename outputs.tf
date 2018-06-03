output "vpc_id" {
  value = "${aws_vpc.this.id}"
}

output "vpc_cidr_block" {
  value = "${aws_vpc.this.cidr_block}"
}

output "vpc_avaiability_zones" {
  value = "${data.aws_availability_zones.available.names}"
}

output "public_subnets" {
  value = "${aws_subnet.public.*.id}"
}

output "private_subnets" {
  value = "${aws_subnet.private.*.id}"
}

output "database_subnets" {
  value = "${aws_subnet.database.*.id}"
}

output "database_subnet_group_name" {
  value = "${aws_db_subnet_group.database.id}"
}

output "database_subnets_cidr_blocks" {
  description = "List of cidr_blocks of database subnets"
  value       = ["${aws_subnet.database.*.cidr_block}"]
}

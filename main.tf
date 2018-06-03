module "label" {
  source     = "git::https://github.com/cloudposse/terraform-null-label.git?ref=tags/0.2.1"
  namespace  = "${var.namespace}"
  stage      = "${var.environment}"
  name       = "${var.name}"
  tags       = "${var.tags}"
}

data "aws_availability_zones" "available" {}

resource "aws_vpc" "this" {
  cidr_block = "${var.cidr_block}"

  enable_dns_hostnames = "${var.enable_dns_hostnames}"
  enable_dns_support   = "${var.enable_dns_support}"

  tags = "${module.label.tags}"
}

# ################ #
# INTERNET GATEWAY #
# ################ #

resource "aws_internet_gateway" "main" {
  vpc_id = "${aws_vpc.this.id}"
  
  tags = "${merge(module.label.tags, map("Name", format("%s-internet-gateway", module.label.id)))}"
}

# ############# #
# PUBLIC SUBNET #
# ############# #

resource "aws_subnet" "public" {
  count = "${var.amount_of_subnets}"

  vpc_id = "${aws_vpc.this.id}"

  cidr_block = "${cidrsubnet(var.cidr_block, 8, count.index)}"
  availability_zone = "${element(data.aws_availability_zones.available.names, count.index)}"

  tags = "${merge(module.label.tags, map("Name", format("%s-public-%s", module.label.id, element(data.aws_availability_zones.available.names, count.index))))}"
}

# ############## #
# PRIVATE SUBNET #
# ############## #

resource "aws_subnet" "private" {
  count = "${var.enable_private_subnet ? var.amount_of_subnets : 0}"

  vpc_id = "${aws_vpc.this.id}"

  cidr_block = "${cidrsubnet(var.cidr_block, 8, (length(data.aws_availability_zones.available.names) + count.index))}"
  availability_zone = "${element(data.aws_availability_zones.available.names, count.index)}"

  tags = "${merge(module.label.tags, map("Name", format("%s-private-%s", module.label.id, element(data.aws_availability_zones.available.names, count.index))))}"
}

# ############### #
# DATABASE SUBNET #
# ############### #

resource "aws_subnet" "database" {
  count = "${var.amount_of_subnets < 2 ? 2 : var.amount_of_subnets}"

  vpc_id = "${aws_vpc.this.id}"

  cidr_block = "${cidrsubnet(var.cidr_block, 8, (length(data.aws_availability_zones.available.names) * 2 + count.index))}"
  availability_zone = "${element(data.aws_availability_zones.available.names, count.index)}"

  tags = "${merge(module.label.tags, map("Name", format("%s-database-%s", module.label.id, element(data.aws_availability_zones.available.names, count.index))))}"
}

resource "aws_db_subnet_group" "database" {
  depends_on = ["aws_subnet.database"]

  name = "${format("%s-database", module.label.id)}"

  subnet_ids = ["${aws_subnet.database.*.id}"]

  tags = "${merge(module.label.tags, map("Name", format("%s-database", module.label.id)))}"
}

# ############ #
# PUBLIC ROUTE #
# ############ #

resource "aws_route_table" "external" {
  vpc_id = "${aws_vpc.this.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.main.id}"
  }

  tags = "${merge(module.label.tags, map("Name", format("%s-route-table", module.label.id)))}"
}

resource "aws_route_table_association" "public_external" {
  count = "${var.amount_of_subnets}"

  subnet_id = "${element(aws_subnet.public.*.id, count.index)}"
  route_table_id = "${aws_route_table.external.id}"
}

# resource "aws_route" "public_nat_gateway" {
#   count = "${var.enable_nat_gateway ? length(data.aws_availability_zones.available.names) : 0}"

#   route_table_id         = "${element(aws_route_table.external.*.id, count.index)}"
#   destination_cidr_block = "0.0.0.0/0"
#   nat_gateway_id         = "${element(aws_nat_gateway.this.*.id, count.index)}"
# }

# ############# #
# PRIVATE ROUTE #
# ############# #

resource "aws_route_table" "private" {
  count = "${var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : var.amount_of_subnets) : 0}"
  
  vpc_id           = "${aws_vpc.this.id}"
  propagating_vgws = ["${var.private_propagating_vgws}"]

  route {
    cidr_block = "0.0.0.0/0"

    nat_gateway_id = "${element(aws_nat_gateway.this.*.id, count.index)}"
  }

  tags = "${merge(var.tags, map("Name", format("%s-private-%s", module.label.id, element(data.aws_availability_zones.available.names, (var.single_nat_gateway ? 0 : count.index)))))}"
}

resource "aws_route_table_association" "private" {
  count = "${var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : var.amount_of_subnets) : 0}"

  subnet_id = "${element(aws_subnet.private.*.id, count.index)}"
  route_table_id = "${element(aws_route_table.private.*.id, count.index)}"
}

# ############## #
# DATABASE ROUTE #
# ############## #

resource "aws_route_table_association" "database_external" {
  # count = "${var.amount_of_subnets}"
  count = "${var.amount_of_subnets < 2 ? 2 : var.amount_of_subnets}"

  subnet_id = "${element(aws_subnet.database.*.id, count.index)}"
  route_table_id = "${aws_route_table.external.id}"
}

# ########### #
# NAT Gateway #
# ########### #

resource "aws_eip" "nat" {
  count = "${var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : var.amount_of_subnets) : 0}"

  vpc = true
}

resource "aws_nat_gateway" "this" {
  count = "${var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : var.amount_of_subnets) : 0}"

  allocation_id = "${element(aws_eip.nat.*.id, (var.single_nat_gateway ? 0 : count.index))}"
  subnet_id     = "${element(aws_subnet.public.*.id, (var.single_nat_gateway ? 0 : count.index))}"

  tags = "${merge(var.tags, map("Name", format("%s-%s", module.label.id, element(data.aws_availability_zones.available.names, (var.single_nat_gateway ? 0 : count.index)))))}"

  depends_on = ["aws_internet_gateway.main"]
}

# ######################### #
# VPC Endpoint for DynamoDB #
# ######################### #
data "aws_vpc_endpoint_service" "dynamodb" {
  count = "${var.enable_dynamodb_endpoint}"

  service = "dynamodb"
}

resource "aws_vpc_endpoint" "dynamodb" {
  count = "${var.enable_dynamodb_endpoint}"

  vpc_id       = "${aws_vpc.this.id}"
  service_name = "${data.aws_vpc_endpoint_service.dynamodb.service_name}"
}

resource "aws_vpc_endpoint_route_table_association" "private_dynamodb" {
  count = "${var.enable_private_subnet && var.enable_dynamodb_endpoint ? var.amount_of_subnets : 0}"

  vpc_endpoint_id = "${aws_vpc_endpoint.dynamodb.id}"
  route_table_id  = "${element(aws_route_table.private.*.id, count.index)}"
}

resource "aws_vpc_endpoint_route_table_association" "public_dynamodb" {
  count = "${var.enable_dynamodb_endpoint ? var.amount_of_subnets : 0}"

  vpc_endpoint_id = "${aws_vpc_endpoint.dynamodb.id}"
  route_table_id  = "${aws_route_table.external.id}"
}
# ######################### #
# VPC Endpoint for S3       #
# ######################### #

data "aws_vpc_endpoint_service" "s3" {
  count = "${var.enable_s3_endpoint}"

  service = "s3"
}

resource "aws_vpc_endpoint" "s3" {
  count = "${var.enable_s3_endpoint}"

  vpc_id       = "${aws_vpc.this.id}"
  service_name = "${data.aws_vpc_endpoint_service.s3.service_name}"
}

resource "aws_vpc_endpoint_route_table_association" "private_s3" {
  count = "${var.enable_private_subnet && var.enable_dynamodb_endpoint ? var.amount_of_subnets : 0}"

  vpc_endpoint_id = "${aws_vpc_endpoint.s3.id}"
  route_table_id  = "${element(aws_route_table.private.*.id, count.index)}"
}

resource "aws_vpc_endpoint_route_table_association" "public_s3" {
  count = "${var.enable_dynamodb_endpoint ? var.amount_of_subnets : 0}"

  vpc_endpoint_id = "${aws_vpc_endpoint.s3.id}"
  route_table_id  = "${aws_route_table.external.id}"
}

# ################# #
# DATABASE FLOW LOG #
# ################# #

resource "aws_cloudwatch_log_group" "db_log" {
  count   = "${var.amount_of_subnets < 2 ? 1 : var.amount_of_subnets}"

  name    = "${format("%s-database-%s", module.label.id, element(data.aws_availability_zones.available.names, count.index))}"
}

resource "aws_flow_log" "db_log" {
  count          = "${var.amount_of_subnets < 2 ? 1 : var.amount_of_subnets}"
  log_group_name = "${aws_cloudwatch_log_group.db_log.name}"

  iam_role_arn   = "${aws_iam_role.vpc_flow.arn}"
  # vpc_id         = "${aws_vpc.this.id}"
  subnet_id      = "${element(aws_subnet.database.*.id, count.index)}"
  traffic_type   = "ALL"
}

resource "aws_cloudwatch_log_group" "vpc_log" {
  count   = "${var.amount_of_subnets < 2 ? 1 : var.amount_of_subnets}"

  name    = "${module.label.id}-vpc"
}

resource "aws_flow_log" "vpc_log" {
  log_group_name = "${aws_cloudwatch_log_group.vpc_log.name}"

  iam_role_arn   = "${aws_iam_role.vpc_flow.arn}"
  vpc_id         = "${aws_vpc.this.id}"

  traffic_type   = "ALL"
}

resource "aws_iam_role" "vpc_flow" {
  name = "vpc_flow_log_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "vpc-flow-logs.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "vpc_flow" {
  name = "vpcFlowLogPolicy"
  role = "${aws_iam_role.vpc_flow.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

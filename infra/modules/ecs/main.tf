data "aws_region" "current" {}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

locals {
  subnet_ids = length(var.subnets) > 0 ? var.subnets : data.aws_subnets.default.ids
}

resource "aws_security_group" "ecs" {
  name        = "${var.cluster_name}-sg"
  description = "Security group for ECS tasks"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description     = "Allow traffic from ALB"
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [var.alb_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Environment = "${var.env}"
    ManagedBy   = "terraform"
  }
}

resource "aws_ecs_cluster" "this" {
  name = var.cluster_name

  tags = {
    Environment = "${var.env}"
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_role" "task_execution" {
  name = "${var.cluster_name}-task-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Environment = "${var.env}"
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_role" "task_role" {
  name = "${var.cluster_name}-task"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Environment = "${var.env}"
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_role_policy_attachment" "task_execution_policy" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "task_role_policies" {
  for_each   = toset(var.task_role_policy_arns)
  role       = aws_iam_role.task_role.name
  policy_arn = each.value
}

resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${var.cluster_name}"
  retention_in_days = 7
  tags = {
    Environment = "${var.env}"
    ManagedBy   = "terraform"
  }
}

resource "aws_ecs_task_definition" "this" {
  family                   = var.cluster_name
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.task_execution.arn
  task_role_arn            = aws_iam_role.task_role.arn

  container_definitions = jsonencode([
    {
      name      = var.container_name
      image     = var.container_image
      essential = true
      portMappings = [
        {
          containerPort = var.container_port
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
          "awslogs-region"        = data.aws_region.current.region
          "awslogs-stream-prefix" = var.cluster_name
        }
      }
    }
  ])

  tags = {
    Environment = "${var.env}"
    ManagedBy   = "terraform"
  }
}

resource "aws_ecs_service" "this" {
  name            = "${var.cluster_name}-service"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = local.subnet_ids
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = var.assign_public_ip
  }

  load_balancer {
    target_group_arn = var.alb_target_group_arn
    container_name   = var.container_name
    container_port   = var.container_port
  }

  depends_on = [
    aws_iam_role_policy_attachment.task_execution_policy
  ]

  tags = {
    Environment = "${var.env}"
    ManagedBy   = "terraform"
  }
}

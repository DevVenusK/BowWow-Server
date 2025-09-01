# BowWow AWS 배포 가이드 (미국 타겟)

## 🇺🇸 미국 시장 타겟 AWS 배포 전략

### Phase 1: 기본 인프라 구축

#### 1. VPC 및 네트워킹 설정
```bash
# VPC 생성 (US-East-1)
aws ec2 create-vpc \
  --cidr-block 10.0.0.0/16 \
  --region us-east-1 \
  --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=BowWow-VPC}]'

# 서브넷 생성
# Public Subnet (ALB용)
aws ec2 create-subnet \
  --vpc-id <vpc-id> \
  --cidr-block 10.0.1.0/24 \
  --availability-zone us-east-1a

# Private Subnet (ECS 서비스용)  
aws ec2 create-subnet \
  --vpc-id <vpc-id> \
  --cidr-block 10.0.2.0/24 \
  --availability-zone us-east-1a
```

#### 2. ECS 클러스터 설정
```yaml
# ecs-cluster.yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: 'BowWow ECS Fargate Cluster'

Resources:
  BowWowCluster:
    Type: AWS::ECS::Cluster
    Properties:
      ClusterName: bowwow-cluster
      CapacityProviders:
        - FARGATE
        - FARGATE_SPOT
      DefaultCapacityProviderStrategy:
        - CapacityProvider: FARGATE
          Weight: 1
        - CapacityProvider: FARGATE_SPOT
          Weight: 4
```

#### 3. Aurora Serverless v2 설정
```yaml
Database:
  Type: AWS::RDS::DBCluster
  Properties:
    Engine: aurora-postgresql
    EngineVersion: '15.4'
    DatabaseName: bowwow
    ServerlessV2ScalingConfiguration:
      MinCapacity: 0.5  # 최소 0.5 ACU
      MaxCapacity: 16   # 최대 16 ACU
    VpcSecurityGroupIds:
      - !Ref DatabaseSecurityGroup
```

### Phase 2: 마이크로서비스 배포

#### 1. Docker 이미지 빌드 및 ECR 푸시
```bash
# ECR 레포지토리 생성
aws ecr create-repository --repository-name bowwow/gateway --region us-east-1
aws ecr create-repository --repository-name bowwow/user-service --region us-east-1
aws ecr create-repository --repository-name bowwow/location-service --region us-east-1
aws ecr create-repository --repository-name bowwow/signal-service --region us-east-1
aws ecr create-repository --repository-name bowwow/push-service --region us-east-1
aws ecr create-repository --repository-name bowwow/analytics-service --region us-east-1

# Docker 빌드 및 푸시
docker build -t bowwow/gateway .
docker tag bowwow/gateway:latest 123456789012.dkr.ecr.us-east-1.amazonaws.com/bowwow/gateway:latest
docker push 123456789012.dkr.ecr.us-east-1.amazonaws.com/bowwow/gateway:latest
```

#### 2. ECS 서비스 정의 예시 (Gateway)
```json
{
  "family": "bowwow-gateway",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "256",
  "memory": "512",
  "executionRoleArn": "arn:aws:iam::123456789012:role/ecsTaskExecutionRole",
  "containerDefinitions": [
    {
      "name": "gateway",
      "image": "123456789012.dkr.ecr.us-east-1.amazonaws.com/bowwow/gateway:latest",
      "portMappings": [
        {
          "containerPort": 8000,
          "protocol": "tcp"
        }
      ],
      "environment": [
        {
          "name": "DATABASE_URL",
          "value": "postgresql://bowwow_user:password@aurora-endpoint:5432/bowwow"
        },
        {
          "name": "USER_SERVICE_URL", 
          "value": "http://user-service.bowwow.local:8001"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/bowwow-gateway",
          "awslogs-region": "us-east-1",
          "awslogs-stream-prefix": "ecs"
        }
      }
    }
  ]
}
```

### Phase 3: 로드 밸런서 및 Auto Scaling

#### 1. Application Load Balancer 설정
```yaml
LoadBalancer:
  Type: AWS::ElasticLoadBalancingV2::LoadBalancer
  Properties:
    Name: bowwow-alb
    Scheme: internet-facing
    Type: application
    Subnets: 
      - !Ref PublicSubnet1
      - !Ref PublicSubnet2
    SecurityGroups:
      - !Ref ALBSecurityGroup

# Target Groups for each service
GatewayTargetGroup:
  Type: AWS::ElasticLoadBalancingV2::TargetGroup
  Properties:
    Name: bowwow-gateway-tg
    Port: 8000
    Protocol: HTTP
    TargetType: ip
    VpcId: !Ref VPC
    HealthCheckPath: /health
```

#### 2. Auto Scaling 설정
```yaml
GatewayAutoScalingTarget:
  Type: AWS::ApplicationAutoScaling::ScalableTarget
  Properties:
    ServiceNamespace: ecs
    ResourceId: service/bowwow-cluster/bowwow-gateway
    ScalableDimension: ecs:service:DesiredCount
    MinCapacity: 2
    MaxCapacity: 20

GatewayScalingPolicy:
  Type: AWS::ApplicationAutoScaling::ScalingPolicy
  Properties:
    PolicyName: bowwow-gateway-scaling-policy
    PolicyType: TargetTrackingScaling
    ScalingTargetId: !Ref GatewayAutoScalingTarget
    TargetTrackingScalingPolicyConfiguration:
      TargetValue: 70.0
      PredefinedMetricSpecification:
        PredefinedMetricType: ECSServiceAverageCPUUtilization
```

### Phase 4: 모니터링 및 로깅

#### 1. CloudWatch 대시보드
```yaml
BowWowDashboard:
  Type: AWS::CloudWatch::Dashboard
  Properties:
    DashboardName: BowWow-Metrics
    DashboardBody: !Sub |
      {
        "widgets": [
          {
            "type": "metric",
            "properties": {
              "metrics": [
                ["AWS/ECS", "CPUUtilization", "ServiceName", "bowwow-gateway"],
                [".", "MemoryUtilization", ".", "."]
              ],
              "period": 300,
              "stat": "Average",
              "region": "us-east-1",
              "title": "ECS Service Metrics"
            }
          }
        ]
      }
```

#### 2. CloudWatch Alarms
```yaml
HighCPUAlarm:
  Type: AWS::CloudWatch::Alarm
  Properties:
    AlarmName: BowWow-HighCPU
    AlarmDescription: High CPU utilization
    MetricName: CPUUtilization
    Namespace: AWS/ECS
    Statistic: Average
    Period: 300
    EvaluationPeriods: 2
    Threshold: 80
    ComparisonOperator: GreaterThanThreshold
    AlarmActions:
      - !Ref SNSTopicForAlerts
```

## 💰 비용 최적화 전략

### 1. Fargate Spot 사용
- 70% 비용 절감 가능
- 비중요 워크로드에 활용

### 2. Aurora Serverless v2 활용
- 트래픽 없을 때 0.5 ACU까지 축소
- 사용량 기반 과금

### 3. Reserved Instances
- 안정적인 워크로드는 1년 예약
- 최대 75% 할인 가능

## 🌍 글로벌 확장 준비

### 1. CloudFront CDN 설정
```yaml
CloudFrontDistribution:
  Type: AWS::CloudFront::Distribution
  Properties:
    DistributionConfig:
      Origins:
        - Id: BowWowALB
          DomainName: !GetAtt LoadBalancer.DNSName
          CustomOriginConfig:
            HTTPPort: 80
            OriginProtocolPolicy: http-only
      Enabled: true
      PriceClass: PriceClass_100  # US, Canada, Europe
```

### 2. Route53 지역별 라우팅
```yaml
BowWowRecordSet:
  Type: AWS::Route53::RecordSet
  Properties:
    HostedZoneId: !Ref HostedZone
    Name: api.bowwow.app
    Type: A
    SetIdentifier: US-East-1
    GeolocationContinentCode: NA  # North America
    AliasTarget:
      DNSName: !GetAtt LoadBalancer.DNSName
      HostedZoneId: !GetAtt LoadBalancer.CanonicalHostedZoneID
```

## 🚀 배포 명령어

### 전체 스택 배포
```bash
# CloudFormation 스택 배포
aws cloudformation deploy \
  --template-file bowwow-infrastructure.yaml \
  --stack-name bowwow-prod \
  --parameter-overrides Environment=production \
  --capabilities CAPABILITY_IAM \
  --region us-east-1

# ECS 서비스 업데이트
aws ecs update-service \
  --cluster bowwow-cluster \
  --service bowwow-gateway \
  --force-new-deployment \
  --region us-east-1
```

### 모니터링 명령어
```bash
# 서비스 상태 확인
aws ecs describe-services \
  --cluster bowwow-cluster \
  --services bowwow-gateway bowwow-user-service \
  --region us-east-1

# 로그 확인
aws logs tail /ecs/bowwow-gateway --follow --region us-east-1
```

## 📊 예상 비용 (미국 시장 기준)

### 초기 단계 (월 사용자 1,000명)
- ECS Fargate: $80-120
- Aurora Serverless: $30-60  
- ElastiCache: $20-40
- ALB: $16
- CloudWatch: $10-20
- **총합: $156-256/월**

### 성장 단계 (월 사용자 10,000명)
- ECS Fargate: $300-500
- Aurora Serverless: $100-200
- ElastiCache: $60-120
- CloudFront: $20-50
- 기타: $50-100
- **총합: $530-970/월**

## ⚡ 성능 최적화

### 1. WebSocket 최적화
- ALB의 Target Group Stickiness 활성화
- Connection Draining 설정

### 2. 데이터베이스 최적화
- Aurora Read Replicas 추가
- Connection Pooling (PgBouncer)

### 3. 캐싱 전략
- ElastiCache Redis Cluster Mode
- Application-level 캐싱

---

이 가이드는 BowWow 시스템을 미국 시장에 최적화된 AWS 인프라에 배포하기 위한 완전한 로드맵입니다.
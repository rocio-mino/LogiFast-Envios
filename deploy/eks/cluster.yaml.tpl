# =============================================================================
# Clúster Amazon EKS para LogiFast-Envios (AWS Academy Learner Lab).
# Plantilla para eksctl: scripts/eks-cluster.sh reemplaza ${AWS_ACCOUNT_ID},
# ${AWS_REGION} y ${EKS_CLUSTER_NAME} antes de crearlo.
#
# Restricciones del Learner Lab consideradas:
#   - No se pueden crear roles IAM: el clúster y los nodos usan el rol "LabRole".
#   - Regiones permitidas: us-east-1 / us-west-2; tipos de instancia hasta "large".
# Costo aproximado mientras está encendido: plano de control EKS + 2 nodos
# t3.medium + 1 Network Load Balancer. Eliminarlo al terminar:
#   ./scripts/eks-cluster.sh delete
# =============================================================================
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: ${EKS_CLUSTER_NAME}
  region: ${AWS_REGION}
  tags:
    project: logifast-envios
    curso: DOY0101-EP3

iam:
  serviceRoleARN: arn:aws:iam::${AWS_ACCOUNT_ID}:role/LabRole
  withOIDC: false

# us-east-1e no admite EKS; se fijan dos zonas para alta disponibilidad.
availabilityZones: ["${AWS_REGION}a", "${AWS_REGION}b"]

vpc:
  # Nodos en subredes públicas: se evita el costo del NAT Gateway.
  nat:
    gateway: Disable

accessConfig:
  authenticationMode: API_AND_CONFIG_MAP

managedNodeGroups:
  - name: ng-logifast
    instanceType: t3.medium
    desiredCapacity: 2
    minSize: 2
    maxSize: 3
    volumeSize: 20
    privateNetworking: false
    iam:
      instanceRoleARN: arn:aws:iam::${AWS_ACCOUNT_ID}:role/LabRole
    labels:
      project: logifast-envios
    tags:
      project: logifast-envios

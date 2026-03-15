#!/usr/bin/env bash
# =============================================================================
# Kubernetes Base AMI 준비 스크립트
# =============================================================================
# 용도: Ubuntu 24.04 LTS 인스턴스에서 실행하여 kubeadm 기반 K8s 노드 AMI 생성
# 대상: 컨트롤 플레인 + 워커 노드 공용
# 설계 기준: K8S-001 (kubeadm + containerd + Flannel + kube-proxy iptables)
#
# 사용법:
#   1. Ubuntu 24.04 LTS EC2 인스턴스 생성 (ap-northeast-2)
#   2. SSH 접속 후 이 스크립트 실행: sudo bash prepare-k8s-ami.sh
#   3. 완료 후 인스턴스에서 AMI 생성 (AWS 콘솔 또는 CLI)
#   4. 생성된 AMI ID를 Terraform에 반영
#
# 참조 문서:
#   [1] kubeadm 설치 가이드
#       https://kubernetes.io/ko/docs/setup/production-environment/tools/kubeadm/install-kubeadm/
#   [2] 컨테이너 런타임 (containerd 설치, 커널 모듈, sysctl, cgroup)
#       https://kubernetes.io/ko/docs/setup/production-environment/container-runtimes/
#   [3] containerd 공식 Getting Started (바이너리 설치, runc, CNI plugins)
#       https://github.com/containerd/containerd/blob/main/docs/getting-started.md
#   [4] AWS AMI 생성 베스트 프랙티스 (SSH 키·cloud-init·machine-id 정리)
#       https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/creating-an-ami-ebs.html
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# 버전 설정
# -----------------------------------------------------------------------------
KUBE_VERSION="1.33"
CONTAINERD_VERSION="1.7.27"
RUNC_VERSION="1.2.6"
CNI_PLUGINS_VERSION="1.6.2"
CRICTL_VERSION="1.33.0"

# 아키텍처 자동 감지 (x86_64 → amd64, aarch64 → arm64)
case "$(uname -m)" in
  x86_64)  ARCH="amd64" ;;
  aarch64) ARCH="arm64" ;;
  *)       echo "ERROR: 지원하지 않는 아키텍처: $(uname -m)"; exit 1 ;;
esac

echo "============================================="
echo " Kubernetes Base AMI 준비"
echo " Kubernetes: v${KUBE_VERSION}.x"
echo " containerd: v${CONTAINERD_VERSION}"
echo " runc: v${RUNC_VERSION}"
echo "============================================="

# -----------------------------------------------------------------------------
# 0. 사전 확인
# -----------------------------------------------------------------------------
if [ "$(id -u)" -ne 0 ]; then
  echo "ERROR: root 권한으로 실행하세요 (sudo bash $0)"
  exit 1
fi

# -----------------------------------------------------------------------------
# 1. 시스템 업데이트 및 기본 패키지
#    - socat, conntrack: kubelet 런타임 의존성 [1]
#    - ipset: kube-proxy iptables 모드 의존성 [1]
#    - amazon-ssm-agent: SSH 외 SSM Session Manager 접속 경로 확보
# -----------------------------------------------------------------------------
echo "[1/8] 시스템 업데이트 및 기본 패키지 설치..."
apt-get update
apt-get upgrade -y
apt-get install -y \
  apt-transport-https \
  ca-certificates \
  curl \
  gnupg \
  lsb-release \
  socat \
  conntrack \
  ipset \
  ethtool \
  jq \
  bash-completion

# SSM Agent 설치 (Ubuntu 24.04 기본 포함 여부 불확실 — 명시적 보장)
if ! systemctl list-unit-files | grep -q amazon-ssm-agent; then
  snap install amazon-ssm-agent --classic
fi
systemctl enable snap.amazon-ssm-agent.amazon-ssm-agent.service

# -----------------------------------------------------------------------------
# 2. Swap 비활성화 [1]
#    kubeadm이 swap 활성 상태에서 init/join을 거부함
# -----------------------------------------------------------------------------
echo "[2/8] Swap 비활성화..."
swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab

# 확인
if [ "$(swapon --show | wc -l)" -gt 0 ]; then
  echo "WARNING: swap이 아직 활성 상태입니다"
fi

# -----------------------------------------------------------------------------
# 3. 커널 모듈 및 sysctl 설정 [2]
#    - overlay: containerd가 overlayfs 스토리지 드라이버 사용
#    - br_netfilter: 브릿지 트래픽이 iptables 규칙을 통과하도록 허용
#    - net.ipv4.ip_forward: Pod 간 통신 및 Service→Pod 패킷 포워딩에 필수
#    - net.bridge.bridge-nf-call-iptables: kube-proxy가 Service 트래픽 처리에 필요
# -----------------------------------------------------------------------------
echo "[3/8] 커널 모듈 및 sysctl 설정..."

# 필수 커널 모듈 영구 로드
cat <<EOF > /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

# sysctl 파라미터
cat <<EOF > /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sysctl --system

# 검증
echo "  - br_netfilter: $(lsmod | grep -c br_netfilter)"
echo "  - overlay: $(lsmod | grep -c overlay)"
echo "  - ip_forward: $(sysctl -n net.ipv4.ip_forward)"

# -----------------------------------------------------------------------------
# 4. containerd 설치 [2][3]
#    - 바이너리 직접 설치 (containerd + runc + CNI plugins)
#    - SystemdCgroup=true: kubelet과 cgroup 드라이버 일치 필수 [2]
# -----------------------------------------------------------------------------
echo "[4/8] containerd ${CONTAINERD_VERSION} 설치..."

# containerd 바이너리
curl -fsSL "https://github.com/containerd/containerd/releases/download/v${CONTAINERD_VERSION}/containerd-${CONTAINERD_VERSION}-linux-${ARCH}.tar.gz" \
  -o /tmp/containerd.tar.gz
tar Cxzf /usr/local /tmp/containerd.tar.gz
rm /tmp/containerd.tar.gz

# systemd service
mkdir -p /etc/systemd/system
curl -fsSL "https://raw.githubusercontent.com/containerd/containerd/main/containerd.service" \
  -o /etc/systemd/system/containerd.service

# runc
curl -fsSL "https://github.com/opencontainers/runc/releases/download/v${RUNC_VERSION}/runc.${ARCH}" \
  -o /tmp/runc
install -m 755 /tmp/runc /usr/local/sbin/runc
rm /tmp/runc

# CNI plugins
mkdir -p /opt/cni/bin
curl -fsSL "https://github.com/containernetworking/plugins/releases/download/v${CNI_PLUGINS_VERSION}/cni-plugins-linux-${ARCH}-v${CNI_PLUGINS_VERSION}.tgz" \
  -o /tmp/cni-plugins.tgz
tar Cxzf /opt/cni/bin /tmp/cni-plugins.tgz
rm /tmp/cni-plugins.tgz

# containerd 기본 설정 생성 후 systemd cgroup 활성화
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

# sandbox image를 registry.k8s.io/pause:3.10으로 고정
sed -i 's|sandbox_image = "registry.k8s.io/pause:.*"|sandbox_image = "registry.k8s.io/pause:3.10"|' /etc/containerd/config.toml

# containerd 시작
systemctl daemon-reload
systemctl enable --now containerd

echo "  - containerd: $(containerd --version)"
echo "  - runc: $(runc --version | head -1)"

# -----------------------------------------------------------------------------
# 5. crictl 설치
# -----------------------------------------------------------------------------
echo "[5/8] crictl ${CRICTL_VERSION} 설치..."

curl -fsSL "https://github.com/kubernetes-sigs/cri-tools/releases/download/v${CRICTL_VERSION}/crictl-v${CRICTL_VERSION}-linux-${ARCH}.tar.gz" \
  -o /tmp/crictl.tar.gz
tar Cxzf /usr/local/bin /tmp/crictl.tar.gz
rm /tmp/crictl.tar.gz

# crictl 기본 설정
cat <<EOF > /etc/crictl.yaml
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 10
EOF

# -----------------------------------------------------------------------------
# 6. kubeadm, kubelet, kubectl 설치 [1]
#    - apt-mark hold: 자동 업그레이드 방지 (K8s 업그레이드는 kubeadm 절차 필수)
# -----------------------------------------------------------------------------
echo "[6/8] kubeadm, kubelet, kubectl v${KUBE_VERSION} 설치..."

# Kubernetes apt 저장소 GPG 키
mkdir -p /etc/apt/keyrings
curl -fsSL "https://pkgs.k8s.io/core:/stable:/v${KUBE_VERSION}/deb/Release.key" \
  | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# apt 저장소 추가
cat <<EOF > /etc/apt/sources.list.d/kubernetes.list
deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${KUBE_VERSION}/deb/ /
EOF

apt-get update
apt-get install -y kubelet kubeadm kubectl

# 버전 고정 (자동 업그레이드 방지)
apt-mark hold kubelet kubeadm kubectl

# kubelet 활성화 (kubeadm init/join 전까지 crashloop 상태 — 정상)
systemctl enable kubelet

echo "  - kubeadm: $(kubeadm version -o short)"
echo "  - kubelet: $(kubelet --version)"
echo "  - kubectl: $(kubectl version --client -o yaml | grep gitVersion)"

# -----------------------------------------------------------------------------
# 7. 필수 이미지 사전 pull
# -----------------------------------------------------------------------------
echo "[7/8] kubeadm 필수 이미지 사전 pull..."
kubeadm config images pull

# -----------------------------------------------------------------------------
# 8. apt 캐시 정리 (디스크 절약)
# -----------------------------------------------------------------------------
echo "[8/8] apt 캐시 정리..."
apt-get clean
rm -rf /var/lib/apt/lists/*

echo ""
echo "============================================="
echo " Kubernetes 구성요소 설치 완료!"
echo "============================================="
echo ""
echo " 설치된 구성요소:"
echo "   - containerd ${CONTAINERD_VERSION} (SystemdCgroup=true)"
echo "   - runc ${RUNC_VERSION}"
echo "   - CNI plugins ${CNI_PLUGINS_VERSION}"
echo "   - crictl ${CRICTL_VERSION}"
echo "   - kubeadm, kubelet, kubectl v${KUBE_VERSION}.x"
echo "   - 커널 모듈: overlay, br_netfilter"
echo "   - sysctl: ip_forward, bridge-nf-call"
echo "   - swap: 비활성화"
echo "   - arch: ${ARCH}"
echo ""
echo " 다음 단계:"
echo "   1. 설치 상태 확인 후 AMI 정리 스크립트 실행"
echo "      sudo bash cleanup-before-ami.sh"
echo "      ※ 실행 후 SSH 재접속 불가 — AMI 바로 생성해야 함"
echo ""
echo "   2. 이 인스턴스에서 AMI 생성 (인스턴스 재부팅 후 스냅샷)"
echo "      aws ec2 create-image --instance-id <INSTANCE_ID> \\"
echo "        --name \"k8s-v${KUBE_VERSION}-\$(date +%Y%m%d)\" \\"
echo "        --description \"Kubernetes ${KUBE_VERSION} base AMI (kubeadm+containerd+${ARCH})\""
echo ""
echo "   3. 생성된 AMI ID를 Terraform에 반영"
echo ""
echo "   4. 컨트롤 플레인 부팅 후:"
echo "      sudo kubeadm init --pod-network-cidr=10.244.0.0/16"
echo ""
echo "   5. 워커 노드 부팅 후:"
echo "      sudo kubeadm join <CP_IP>:6443 --token <TOKEN> \\"
echo "        --discovery-token-ca-cert-hash sha256:<HASH>"
echo "============================================="

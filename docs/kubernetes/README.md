# docs/kubernetes/

Kubernetes 관련 문서는 이 디렉터리에서 관리한다.

- 설계 본문은 이 디렉터리에 둔다.
- 개별 기술 선택 근거는 `docs/architecture/DR-xxx`로 분리한다.
- 설계 본문에서는 결론만 적고, 상세 비교는 DR로 연결한다.
- 현재 공식 설계 기준선은 이 디렉터리와 `docs/architecture`를 따른다.
- `v3-kubernetes/docs`는 참고 자료로만 본다.

## 문서 목록

- [K8S-001 최종 설계서](K8S-001-final-design.md): v3 Kubernetes 최종 설계 문서의 기준선
- [K8S-002 CNI 비교 연구](K8S-002-cni-comparison-study.md): Flannel, Calico, Cilium을 비교한 연구 문서
- [K8S-003 Flannel 심화](K8S-003-flannel-deep-dive.md): Flannel을 현재 1차 선택지로 본 이유 정리
- [K8S-004 Calico 심화](K8S-004-calico-deep-dive.md): Calico를 후속 재검토 1순위 후보로 본 이유 정리
- [K8S-005 Cilium 심화](K8S-005-cilium-deep-dive.md): Cilium을 장기 고도화 후보로 본 이유 정리
- [K8S-006 Service 데이터플레인 비교 연구](K8S-006-service-dataplane-comparison-study.md): `kube-proxy` 모드와 eBPF replacement 비교
- [K8S-007 kube-proxy iptables 심화](K8S-007-kube-proxy-iptables-deep-dive.md): `iptables`를 현재 기준선으로 둔 이유 정리
- [K8S-008 kube-proxy nftables 심화](K8S-008-kube-proxy-nftables-deep-dive.md): `nftables`를 후속 후보로 둔 이유 정리
- [K8S-009 kube-proxy ipvs 심화](K8S-009-kube-proxy-ipvs-deep-dive.md): `ipvs`가 무엇이었고 왜 비선정인지 정리
- [K8S-010 eBPF Service 데이터플레인 메모](K8S-010-ebpf-service-dataplane-note.md): eBPF replacement를 현재 제외한 이유 정리

## 읽는 순서

1. [K8S-001-final-design.md](K8S-001-final-design.md)
2. [DR-004 Kubernetes 배포 방식 선정](../architecture/DR-004-kubernetes-distribution-selection.md)
3. [DR-005 컨트롤 플레인 구조 선정](../architecture/DR-005-kubernetes-control-plane-topology.md)
4. [DR-006 Kubernetes CNI 선정](../architecture/DR-006-kubernetes-cni-selection.md)
5. [K8S-002-cni-comparison-study.md](K8S-002-cni-comparison-study.md)
6. [K8S-003-flannel-deep-dive.md](K8S-003-flannel-deep-dive.md)
7. [K8S-004-calico-deep-dive.md](K8S-004-calico-deep-dive.md)
8. [K8S-005-cilium-deep-dive.md](K8S-005-cilium-deep-dive.md)
9. [DR-007 트래픽 진입점 API 선정](../architecture/DR-007-kubernetes-gateway-api-selection.md)
10. [DR-008 Kubernetes Gateway Controller 선정](../architecture/DR-008-kubernetes-gateway-controller-selection.md)
11. [DR-009 도메인 및 인증서 관리 방식 선정](../architecture/DR-009-domain-and-certificate-management.md)
12. [DR-010 Service 데이터플레인 전략 선정](../architecture/DR-010-kube-proxy-and-service-dataplane-strategy.md)
13. [K8S-006 Service 데이터플레인 비교 연구](K8S-006-service-dataplane-comparison-study.md)
14. [K8S-007 kube-proxy iptables 심화](K8S-007-kube-proxy-iptables-deep-dive.md)
15. [K8S-008 kube-proxy nftables 심화](K8S-008-kube-proxy-nftables-deep-dive.md)
16. [K8S-009 kube-proxy ipvs 심화](K8S-009-kube-proxy-ipvs-deep-dive.md)
17. [K8S-010 eBPF Service 데이터플레인 메모](K8S-010-ebpf-service-dataplane-note.md)
18. 필요 시 `v3-kubernetes/docs` 참고 자료

현재 기준으로 Kubernetes 네트워크 기준선은 아래 문서 묶음으로 확인하면 된다.

- [DR-004 Kubernetes 배포 방식 선정](../architecture/DR-004-kubernetes-distribution-selection.md)
- [DR-005 컨트롤 플레인 구조 선정](../architecture/DR-005-kubernetes-control-plane-topology.md)
- [DR-006 Kubernetes CNI 선정](../architecture/DR-006-kubernetes-cni-selection.md)
- [K8S-002 CNI 비교 연구](K8S-002-cni-comparison-study.md)
- [DR-007 트래픽 진입점 API 선정](../architecture/DR-007-kubernetes-gateway-api-selection.md)
- [DR-008 Kubernetes Gateway Controller 선정](../architecture/DR-008-kubernetes-gateway-controller-selection.md)
- [DR-009 도메인 및 인증서 관리 방식 선정](../architecture/DR-009-domain-and-certificate-management.md)
- [DR-010 Service 데이터플레인 전략 선정](../architecture/DR-010-kube-proxy-and-service-dataplane-strategy.md)
- [K8S-006 Service 데이터플레인 비교 연구](K8S-006-service-dataplane-comparison-study.md)

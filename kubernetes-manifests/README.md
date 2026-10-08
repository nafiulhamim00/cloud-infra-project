# Lab 5: Talos Kubernetes Cluster Setup

## Table of Contents

- [Table of Contents](#table-of-contents)
- [Part 7](#part-7)
  - [Submission](#submission)
- [Ideas to Improve Your Deployment](#ideas-to-improve-your-deployment)
- [Next Steps](#next-steps)

## Part 7

- **Duration:** ~90 minutes
- **Prerequisites:** Completed Part 6.

Convert the multi-service stack from [Lab 4's `4docker/stack/`](../../4docker/3-compose/README.md) into a Kubernetes deployment, you may compose your own service, deployment manifests as needed.
Use the docker images you used previously when creating the pods/deployments.
Additionally, include health checks into your deployment.

Additional ref: [https://kubebyexample.com/](https://kubebyexample.com/)

### Submission

- Submit your code to the GitHub repository before the deadline.
- Attend the lab session to demonstrate your deployment and obtain approval.
- If you submit before the lab session but cannot get approval on the last date (because of the queue), we will try to approve it in the next lab session without any issues.

## Ideas to Improve Your Deployment

1. **Implement SSL/TLS** termination with cert-manager
2. **Add monitoring** with Prometheus and Grafana
3. **Implement CI/CD** pipeline for application updates
4. **Configure log aggregation** with ELK stack
5. **Add caching layer** with Redis
6. **Implement database replication** for high availability

## Next Steps

Congratulations! You have successfully deployed a application on Kubernetes.

Consider exploring advanced topics like:

- Service mesh (Istio, Linkerd)
- GitOps workflows (ArgoCD, Flux)
- Advanced security (OPA, Falco)
- Multi-cluster management
- Cloud-native development practices

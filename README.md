# Deploying IBM Enterprise Records

IBM IBM Enterprise Records offers enterprise-level scalability and flexibility to handle the most demanding content challenges, the most complex business processes, and integration to all your existing systems. FileNet P8 is a reliable, scalable, and highly available enterprise platform that enables you to capture, store, manage, secure, and process information to increase operational efficiency and lower total cost of ownership. FileNet P8 enables you to streamline and automate business processes, access and manage all forms of content, and automate records management to help meet compliance needs.

## Requirements and prerequisites

Perform the following tasks to prepare to deploy your IBM Enterprise Records images on Kubernetes:

- Prepare your IBM Enterprise Records environment. These procedures include setting up databases, LDAP, storage, and configuration files that are required for use and operation. You must complete all of the [preparation steps for IBM Enterprise Records]( https://www.ibm.com/support/knowledgecenter/SSNVVQ_5.2.1/com.ibm.p8.installingrm.doc/container/frmin012.htm) before you are ready to deploy the container images. 

- Prepare your Kubernetes environment. See [Preparing for deployment with an operator]( https://www.ibm.com/support/knowledgecenter/SSNVVQ_5.2.1/com.ibm.p8.installingrm.doc/container/frmin012.htm)

## Deploying with an operator

The IBM Enterprise Records operator is built from the Red Hat and Kubernetes Operator Framework, which is an open source toolkit that is designed to automate features such as updates, backups, and scaling. The operator handles upgrades and reacts to failures automatically.

To prepare your operator and deploy your IBM Enterprise Records components, follow the instructions for your operator platform:

- [Certified Kubernetes](operator/platform/k8s/README.md)
- [Red Hat OpenShift](operator/platform/ocp/README.md)

## Completing post deployment configuration

After you deploy your container images, you perform some required and some optional steps to get your IBM Enterprise Records environment up and running. For detailed instructions, see [Completing post deployment tasks for IBM IBM Enterprise Records](https://www.ibm.com/support/knowledgecenter/SSNVVQ_5.2.1/com.ibm.p8.installingrm.doc/container/frmin026.htm)

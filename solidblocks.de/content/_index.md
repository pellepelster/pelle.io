---
title: "Solidblocks"
subtitle: Bespoke Application Hosting
date: 2024-02-20T22:00:00+01:00
draft: false
---

<script>var LHC_API = LHC_API||{};
LHC_API.args = {mode:'widget',lhc_base_url:'https://solidblocks.livehelperchat.com/',wheight:450,wwidth:350,pheight:520,pwidth:500,domain:'solidblocks.de',fresh:true,leaveamessage:true,department:["1"],check_messages:false,proactive:false,lang:'eng/'};
(function() {
var po = document.createElement('script'); po.type = 'text/javascript'; po.setAttribute('crossorigin','anonymous'); po.async = true;
var date = new Date();po.src = 'https://solidblocks.livehelperchat.com/design/defaulttheme/js/widgetv2/index.js?'+(""+date.getFullYear() + date.getMonth() + date.getDate());
var s = document.getElementsByTagName('script')[0]; s.parentNode.insertBefore(po, s);
})();
</script>

<div class="container">
  
  Solidblocks is a collection of components, patterns and best practices around infrastructure and application deployments.
  With a focus on the [Hetzner Cloud](https://cloud.hetzner.com) as a deployment target it leans towards simple and easy
  to maintain architectures based on battle-tested open source components.

  Many components are already available as [open source](https://github.com/pellepelster/solidblocks) components, and as an
  infrastructure specialist I am happy to provide you with hands on help and support for your application deployment
  needs, ranging from turnkey ready-to-use solutions to partially or fully managed environments for your applications.
  
  <div class="container d-flex justify-content-center py-4">
      <a href="/contact/" class="btn btn-lg col-4 my-3 btn-primary align-self-center">
          <i class="fas fa-mail-bulk"></i>
          Contact
      </a>
  </div>

</div>

<div class="feature-divider"></div>

{{<feature-container title="Simplicity">}}

{{<feature-row>}}
    {{<feature title="Your code" iconClasses="fa-code-branch solidblocks-orange">}}
      You own the code for your solution, no proprietary components you can fork it anytime you want.
    {{</feature>}}
    
    {{<feature title="Your Servers and Data" iconClasses="fa-cloud solidblocks-yellow">}}
      For mananged solutions all resources can be hosted in you cloud projects so you have always access to all VMs and data.
    {{</feature>}}

    {{<feature title="VMs and Servers" iconClasses="fa-server solidblocks-green">}}
      Although a fully blown container orchestration like Kubernetes has its benefits, sometimes a simple solution based 
      on VMs or even bare metal can be more cost-effective and easier to handle, maintain and operate.
    {{</feature>}}


  {{</feature-row>}}

  {{<feature-row>}}

    {{<feature title="Infrastructure as Code" iconClasses="fa-code solidblocks-green">}}
      All deployed infrastructure is described and deployed with infrastructure as code solutions like Terraform, OpenTofu,
      Ansible and similar tools.   
    {{</feature>}}
    
    {{<feature title="Developer experience" iconClasses="fa-play solidblocks-orange">}}
      The deployment process is designed to be easy to use on the developer machines, and also to integrate into common CI/CD
      systems like Github, Gitlab, Jenkins and others.  
    {{</feature>}}

  {{</feature-row>}}
{{</feature-container>}}

<div class="feature-divider"></div>

{{<feature-container title="Security & Data Safety">}}
  {{<feature-row>}}
    
    {{<feature title="Updates" iconClasses="fa-arrows-rotate solidblocks-orange">}}
      All components like operating systems and software packages are regularly updated. Where applicable tools like <a href="https://github.com/renovatebot/renovate">renovate</a>
      are integrated into the deployment process to ensure everything is always up-to-date.  
    {{</feature>}}
    
    {{< feature title="Encryption" iconClasses="fa-lock solidblocks-green">}}
      Data that is stored outside the cloud, like e.g. backups is encrypted by default to protect against accidental exposure of
      sensitive information.
    {{</feature>}}
    
    {{< feature title="Secret Rotation" iconClasses="fa-key solidblocks-yellow">}}
      All secrets and user credentials can be rotated at anytime to mitigate the risk of long-lived credentials that may leak
      over time.
    {{</feature>}}
    
  {{</feature-row>}}

  {{<feature-row>}}

    {{< feature title="Backups" iconClasses="fa-cloud-arrow-up solidblocks-yellow">}}
      Encrypted data backups to other clouds like AWS or GCP provide an extra layer of security for your data and reduce the blast 
      radius in case of accidental deletion or configuration mistakes. 
    {{</feature>}}

    {{< feature title="CVE Scanning" iconClasses="fa-magnifying-glass solidblocks-green">}}
      Automated CVE scans and an always up to date SBOM make it easy to discover security critical bugs and mitgitate them.
    {{</feature>}}

    {{< feature title="IDP/IAM" iconClasses="fa-id-card solidblocks-orange">}}
      IDM solutions like <a href="https://www.keycloak.org">Keycloak</a> can easily be integrated to secure your application or, 
      in combination with <a href="https://www.vaultproject.io">Hashicorp Vault</a>, to secure SSH access to your VMs with 
      short-lived secrets.
    {{</feature>}}
    
  {{</feature-row>}}
{{</feature-container>}}

<div class="feature-divider"></div>

{{<feature-container title="Deployment lifecycle" >}}
  {{<feature-row>}}

    {{<feature title="Environments" iconClasses="fa-layer-group solidblocks-yellow">}}
      Mutli-environment support is a first class citizen and can be used to support your application lifecycle and to provide
      different test environments.
    {{< /feature>}}
    
    {{<feature title="Bootstrapping" iconClasses="fa-terminal solidblocks-orange">}}
      Deletion and bootstrapping of environments from zero is tested on a regular basis to ensure that no cyclic dependencies
      are hidden in the infrastructure setup and that the code that is only executed during initial setup still works.
    {{</feature>}}
    
    {{<feature title="Disaster Recovery" iconClasses="fa-fire solidblocks-green">}}
      Bootstrapping environments from backup is tested on a regular basis and part of
      the playbooks and developer briefings. 
      All components are designed so that the whole environment can be destroyed at anytime and be fully rebuilt from backups.
    {{</feature>}}

  {{</feature-row>}}
{{</feature-container >}}

<div class="feature-divider"></div>

{{<feature-container title="Logging and Monitoring" >}}
  {{<feature-row>}}

    {{<feature title="Logs" iconClasses="fa-server solidblocks-green">}}
      Logging platforms like Elasticsearch can be used to ingest all application and VM logs and help
      to resolve errors and debug application state and health.
    {{</feature>}}

    {{<feature title="Metrics" iconClasses="fa-chart-line solidblocks-orange">}}
      Application as well as VM metrics can be gathered on analytics platforms like Grafana or Elasticsearch, to detect and
      and visualized application usage, performance and longtime trends and help with sizing decisions.
    {{</feature>}}

    {{<feature title="Tagging" iconClasses="fa-tag solidblocks-yellow">}}
      Logs and metrics are tagged with information about environment, service, version etc. and enriched with events like
      deployments, making it easy to correlate issues and bugs caused by different application versions and bugs.
    {{</feature>}}

  {{</feature-row>}}
{{</feature-container>}}

<div class="feature-divider"></div>

{{<feature-container title="CI/CD" >}}

  {{<feature-row>}}

    {{<feature title="Deployment" iconClasses="fa-infinity solidblocks-yellow">}}
      The deployment can easily be integrated into all major CI/CD systems or into already existing application build
      pipelines.
    {{</feature>}}

    {{< feature title="Testing" iconClasses="fa-crow solidblocks-green">}}
      Infrastructure integration tests in the deployment process ensure, that the deployment is successful, and
      also serve as canary to warn when parts of the infrastructure or application are broken or in a degraded state.
    {{</feature>}}

  {{</feature-row>}}
{{</feature-container>}}

<div class="feature-divider"></div>

{{<feature-container title="Documentation & Support" >}}

  {{<feature-row>}}

    {{<feature title="Playbooks" iconClasses="fa-list-ol solidblocks-green">}}
      Playbooks provide detailed steps for important steps like disaster recovery or secret rotaion in case of emergencies.
    {{</feature>}}

    {{<feature title="Fire Drills" iconClasses="fa-fire-extinguisher solidblocks-orange">}}
      Regular exercises ensure that important steps that are seldom used still work and that developers are comfortable with executing them.
    {{</feature>}}

    {{<feature title="Support" iconClasses="fa-phone solidblocks-yellow">}}
      In case of critical errors emergency support is also available via email, phone or chat.
    {{</feature>}}

  {{</feature-row>}}
{{</feature-container>}}

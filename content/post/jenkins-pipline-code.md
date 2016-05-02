---
title: "Jenkins piplines as code"
description: "Revisiting Jenkins jobs from code"
date: "2016-05-01"
categories:
  - "jenkins"
---

When it comes to creation of jobs, Jenkins has in the past been a quite UI heavy continuous integration integration tool. Several plugins strive to retrofit the ability to store Jenkins jobs as code but (at least to me) none of them had a very convincing approach to this problem.
A common approach to tackle the problem is the generation of job definitions `config.xml` using some sort of templating system but to be honest generating XML never lead to anything good =).
Another problem I had with Jenkins in the past is that building deployment pipelines never felt right because I always ended up with a bunch of jobs representing the single pipeline steps and the "pipeline view plugin of the day" to visualize it.

With Jenkins 2.0 released this week, it now supports fully featured [build pipelines](https://jenkins.io/doc/pipeline/) out of the box and together with its new Groovy based [DSL](https://jenkins.io/doc/pipeline/steps/) to describe these pipelines it can also retrieve them from SCM.

A new build type called *GitHub Organization* provides this functionality by either scanning the whole organization or a specific GitHub repository for a `Jenkinsfile` containing the job description DSL.

**example Jenkinsfile**
```
node {

    stage 'Checkout'

    git url: 'https://github.com/pellepelster/jenkins-pipeline-code.git'

    stage 'Build'
    dir("application1") {
        sh "./gradlew build"
    }
}
```

When it encounters a new or updated `Jenkinsfile` the contained definition is created as a new job within the organizations folder. So the only thing you have to create is a relatively small job pointing to the organization and the rest is done by Jenkins.
This reduces the need to make use of the UI to create new jobs and makes Jenkins a more scriptable.

For the evaluation of the features I created a self contained Ansible provisioned Vagrant box that you can use to try it out by yourself:

```
git clone https://github.com/pellepelster/jenkins-pipeline-code.git
cd jenkins-pipeline-code
vagrant up
```

wait a few minutes and then point your browser to [http://localhost:8080](http://localhost:8080). Upon creation of the box an initial repository scan is initiated and it should automatically create a job for the [example repository](https://github.com/jenkins-pipeline-code/jenkins-pipeline-code).
After job creation the first build is automatically started and you can see the new [pipeline view](http://localhost:8080/job/github-organization-folder/job/jenkins-pipeline-code/branch/master/) after a few seconds.

{{< figure src="/img/posts/jenkins-pipeline-code_1.png" link="http://localhost:8080/job/github-organization-folder/job/jenkins-pipeline-code/branch/master/" title="Jenkins build pipeline view" >}}

I had to resolve some obstacles during the creation of this Vagrant box that may also help you scripting Jenkins:

* Passwords in Jenkins 2.0 are encrypted using the Blowfish based BCrpt algorithm the Ansible playbook uses the following ruby snippet to create new passwords:
```
require 'bcrypt';
puts BCrypt::Password.create('{{item.password}}')\"
```
and keep in mind they have to be prefixed with `#jbcrypt:` so Jenkins can distinguish the different password encoders.

* The GitHub API rate limit for unauthorized API calls is quite low, so it is always advisable to create an API token for the periodical repository scans. The needed credentials are registered via a generated Groovy file that is feed into the Jenkins command line client:

  ```
  import [...]

  domain = Domain.global()
  store = Jenkins.instance.getExtensionList('com.cloudbees.plugins.credentials.SystemCredentialsProvider')[0].getStore()

  usernameAndPassword = new UsernamePasswordCredentialsImpl(
    CredentialsScope.GLOBAL,
    "$name", "$description",
    "$username",
    "$api_token"
  )

  store.addCredentials(domain, usernameAndPassword)
  ```

* The first run installer that comes with Jenkins 2.0 is suppressed by setting the Java system property `jenkins.install.runSetupWizard` to `false`.

* The recommended default plugin set (that is needed for the organizational folder feature) and that is normally created by the first run installer in manually installed using the Jenkins CLI. The recommended list of plugins is taken from [https://raw.githubusercontent.com/jenkinsci/jenkins/master/war/src/main/js/api/plugins.js](https://raw.githubusercontent.com/jenkinsci/jenkins/master/war/src/main/js/api/plugins.js).

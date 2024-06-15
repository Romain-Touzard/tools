FROM jenkins/jenkins:latest
ENV JAVA_OPTS -Djenkins.install.runSetupWizard=false
ENV CASC_JENKINS_CONFIG /var/jenkins_home/casc.yaml
COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN mkdir -p /usr/share/jenkins/ref/plugins

RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt
EXPOSE 8080
EXPOSE 50000
COPY casc.yaml /var/jenkins_home/casc.yaml
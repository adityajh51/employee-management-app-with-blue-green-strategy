FROM openjdk:19-jdk-alpine3.16
WORKDIR /app
ADD ./target/*.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java","-jar","app.jar"]

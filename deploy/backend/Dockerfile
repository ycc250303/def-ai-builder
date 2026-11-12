FROM alpine:3.21 AS build
RUN sed -i 's#https://dl-cdn.alpinelinux.org#https://mirrors.aliyun.com#g' /etc/apk/repositories \
    && apk add --no-cache openjdk21
WORKDIR /src
COPY backend/ .
RUN chmod +x mvnw && ./mvnw -B -ntp -Dmaven.test.skip=true package

FROM alpine:3.21
RUN sed -i 's#https://dl-cdn.alpinelinux.org#https://mirrors.aliyun.com#g' /etc/apk/repositories \
    && apk add --no-cache openjdk21-jre
WORKDIR /app
COPY --from=build /src/target/plant-0.0.1-SNAPSHOT.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/app/app.jar"]

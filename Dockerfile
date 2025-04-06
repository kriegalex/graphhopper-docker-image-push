FROM node:22.14.0 as frontend-build

WORKDIR /graphhopper-maps
COPY graphhopper-maps .
RUN npm ci && npm run build

FROM maven:3.9.5-eclipse-temurin-21 as build

WORKDIR /graphhopper-maps
# Copy the pre-built graphhopper-maps from the frontend-build stage
COPY --from=frontend-build /graphhopper-maps/dist ./dist

WORKDIR /graphhopper
COPY graphhopper .

# Use the pre-built maps from the frontend stage
RUN mvn clean install -DskipTests -Dskip.npm.download=true -Dmaps.local.dir=/graphhopper-maps

RUN rm -rf /graphhopper-maps

FROM eclipse-temurin:21.0.1_12-jre

ENV JAVA_OPTS "-Xmx1g -Xms1g"

RUN mkdir -p /data

WORKDIR /graphhopper

COPY --from=build /graphhopper/web/target/graphhopper*.jar ./

COPY graphhopper.sh graphhopper/config-example.yml ./

# Enable connections from outside of the container
RUN sed -i '/^ *bind_host/s/^ */&# /p' config-example.yml

VOLUME [ "/data" ]

EXPOSE 8989 8990

HEALTHCHECK --interval=5s --timeout=3s CMD curl --fail http://localhost:8989/health || exit 1

ENTRYPOINT [ "./graphhopper.sh", "-c", "config-example.yml" ]

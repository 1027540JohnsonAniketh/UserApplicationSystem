package com.webapp.cloud;

import java.io.FileNotFoundException;
import java.io.IOException;

import javax.sql.DataSource;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.builder.SpringApplicationBuilder;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.boot.jdbc.DataSourceBuilder;
import org.springframework.boot.web.servlet.support.SpringBootServletInitializer;
import org.springframework.context.annotation.Bean;

import io.prometheus.client.spring.boot.EnablePrometheusEndpoint;
import io.prometheus.client.spring.boot.EnableSpringBootMetricsCollector;

@SpringBootApplication
//@EnablePrometheusEndpoint
//Pull all metrics from Actuator and expose them as Prometheus metrics. Need to disable security feature in properties file.
//@EnableSpringBootMetricsCollector
public class WorkApplication  extends SpringBootServletInitializer {
	public static void main(String[] args) throws FileNotFoundException, IOException {
		SpringApplication.run(WorkApplication.class, args);
	}
	

	@Override
	protected SpringApplicationBuilder configure(SpringApplicationBuilder application) {
		return application.sources(WorkApplication.class);
	}
	
}

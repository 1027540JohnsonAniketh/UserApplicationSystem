package com.webapp.cloud.databaseConfig;

import javax.sql.DataSource;
import javax.persistence.EntityManagerFactory;

import org.springframework.context.annotation.Configuration;
import org.springframework.transaction.annotation.EnableTransactionManagement;
import org.springframework.data.jpa.repository.config.EnableJpaRepositories;
import org.springframework.context.annotation.Primary;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.boot.jdbc.DataSourceBuilder;
import org.springframework.context.annotation.Bean;
import org.springframework.orm.jpa.LocalContainerEntityManagerFactoryBean;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.boot.orm.jpa.EntityManagerFactoryBuilder;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.orm.jpa.JpaTransactionManager;

@Configuration
@EnableTransactionManagement
@EnableJpaRepositories(entityManagerFactoryRef = "entityManagerFactory1",
    basePackages = {"com.webapp.cloud.replicaDatabase"})
public class SecondaryDatabase {
	@Bean(name = "seconddataSource")
	@ConfigurationProperties(prefix = "spring.seconddatasource")
	public DataSource secondaryDataSource() {
		return DataSourceBuilder.create().build();
	}
	
	@Bean(name = "entityManagerFactory1")
	public LocalContainerEntityManagerFactoryBean entityManagerFactory(
		EntityManagerFactoryBuilder builder, @Qualifier("seconddataSource") DataSource dataSource) {
	    return builder.dataSource(dataSource).packages("com.webapp.cloud.model").persistenceUnit("User")
	        .build();
	}
	
	@Bean(name = "transactionManager1")
	public PlatformTransactionManager transactionManager(
	      @Qualifier("entityManagerFactory1") EntityManagerFactory entityManagerFactory) {
	    return new JpaTransactionManager(entityManagerFactory);
	}

}

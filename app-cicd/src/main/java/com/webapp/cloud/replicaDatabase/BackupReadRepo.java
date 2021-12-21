package com.webapp.cloud.replicaDatabase;

import org.springframework.data.jpa.repository.JpaRepository;

import com.webapp.cloud.model.User;

public interface BackupReadRepo extends JpaRepository<User, Integer>{
	boolean existsByUsername(String username);
	User findByUsername(String username);
}

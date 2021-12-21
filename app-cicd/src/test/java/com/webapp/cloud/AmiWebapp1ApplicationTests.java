package com.webapp.cloud;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;

import com.webapp.cloud.WorkApplication;
import com.webapp.cloud.model.User;

@SpringBootTest(classes = WorkApplication.class)
class AmiWebapp1ApplicationTests {

	@Test
	void contextLoads() {
	}
	@Test
	public void assertUserFirstName() {
		User user=new User();
		String username="fu@gmail.com";
		user.setUsername(username);
		assert(user.getUsername().equals(username));
	}
}

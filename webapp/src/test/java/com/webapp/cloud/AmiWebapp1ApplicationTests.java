package com.webapp.cloud;


import org.junit.jupiter.api.Test;

import com.webapp.cloud.model.User;

class AmiWebapp1ApplicationTests {

	@Test
	void contextLoads() {
	}
	@Test
	public void assertUserName() {
		User user=new User();
		String username="fu@gmail.com";
		user.setUsername(username);
		assert(user.getUsername().equals(username));
	}
}

package com.webapp.cloud.api;


import java.util.List;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

import com.amazonaws.services.s3.AmazonS3;
import com.timgroup.statsd.NonBlockingStatsDClient;
import com.timgroup.statsd.StatsDClient;
import com.webapp.cloud.model.MyUserDetails;
import com.webapp.cloud.model.User;
import com.webapp.cloud.replicaDatabase.BackupReadRepo;
import com.webapp.cloud.repository.ImageRepository;
import com.webapp.cloud.repository.MetadataRepository;
import com.webapp.cloud.repository.UserRepository;

import com.amazonaws.services.sns.AmazonSNSAsync;
import com.amazonaws.services.sns.AmazonSNSClient;
import com.amazonaws.services.sns.AmazonSNSClientBuilder;
import com.amazonaws.services.sns.model.ListTopicsResult;
import com.amazonaws.services.sns.model.PublishRequest;
import com.amazonaws.services.sns.model.PublishResult;
import com.amazonaws.services.sns.model.Topic;

import java.util.Calendar;
import java.util.concurrent.ExecutionException;


@RestController
@RequestMapping("/v1")
public class UserService implements UserDetailsService  {
	
	private UserImpl userHelper=new UserImpl();
	@Autowired
	private UserRepository userRepository;
	@Autowired
	private BackupReadRepo backupReadRepository;
	@Autowired
	private ImageRepository imageRepository;
	@Value("${cloud.aws.region.bucket.name}")
    private String bucketName;

	@Autowired
	private StatsDClient metric=new NonBlockingStatsDClient("statsd", "localhost", 8125);
	@Autowired
	private MetadataRepository metadataRepository;
	
    private AmazonSNSAsync amazonSNSClient;
    
    Logger logger=LoggerFactory.getLogger(UserService.class);
    int counterGetUser=0;
    int counterGetUsersAll=0;
    int counterCreateUser=0;
    int counterUpdateUser=0;
    int counterVerifyUser=0;
	@Autowired
	private AmazonS3 amazonS3;
	@GetMapping("/users/{username}")
	public User getUser(@PathVariable("username") String username) {
		counterGetUser++;
		logger.info("82:User getUser() execution started");
		metric.incrementCounter("getUserCounterAPI");
		long startTime = System.currentTimeMillis();
		loadUserByUsername(username);
		
		
		if (!backupReadRepository.existsByUsername(username)) {
			metric.recordExecutionTime("getUserTimeAPI", System.currentTimeMillis() - startTime);
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "The User "+username+" does not exist");
		}
		
		long startTimeDB = System.currentTimeMillis();
		User retUser=backupReadRepository.findByUsername(username);
		if(!retUser.getVerified())
			throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "You are not authorized");
		metric.recordExecutionTime("getUserTimeAPIForDB", System.currentTimeMillis() - startTimeDB);
		metric.recordExecutionTime("getUserTimeAPI", System.currentTimeMillis() - startTime);
		logger.info("99:The getUser() is successfull");
		logger.info("100:The number of times getUser() is called="+counterGetUser);
		return retUser;
	}
	

	@GetMapping("/users")
	public List<User> getUsersAll() {
		counterGetUsersAll++;
		logger.info("108:User getUsersAll() execution started");
		metric.incrementCounter("getUsersAllCounterAPI");
		long startTime = System.currentTimeMillis();
		long startTimeDB = System.currentTimeMillis();
		List<User> retUser=backupReadRepository.findAll();
		metric.recordExecutionTime("getUsersAllTimeAPIForDB", System.currentTimeMillis() - startTimeDB);
		metric.recordExecutionTime("getUsersAllTimeAPI", System.currentTimeMillis() - startTime);
		logger.info("115:The getUsersAll() is successfull");
		logger.info("116:The number of times getUser() is called="+counterGetUsersAll);
		return retUser;
	}

	@PostMapping("/users")
	public User createUser(@RequestBody User user) throws InterruptedException, ExecutionException {
		counterCreateUser++;
		logger.info("123:User createUser() execution started");
		metric.incrementCounter("createUserCounterAPI");
		long startTime = System.currentTimeMillis();
		System.out.println("Inside createUser");
		if (!userRepository.existsByUsername(user.getUsername()) && userHelper.isValidUsername(user.getUsername())) {
			System.out.println("Inside userRepository");
			System.out.println("Setting pwd");
			String pwd=userHelper.generateBcryptedPassword(user.getPassword());
			System.out.println("Setting uuid");
			String uuid = userHelper.generateRandomUUID();
			user.setId(uuid);
			System.out.println("Setting pwd");
			user.setPassword(pwd);
			System.out.println("Setting setAccountcreated");
			String date=userHelper.getDate();
			user.setAccountcreated(date);
			System.out.println("Setting setAccountupdated");
			user.setAccountupdated(date);
			System.out.println("Setting setVerified");
			user.setVerified(false);
			System.out.println("Setting setVerified_on");
			user.setVerified_on(date);
		} else {
			System.out.println("Inside else");
			if(!userHelper.isValidUsername(user.getUsername())) {
				System.out.println("The username is invalid");
				metric.recordExecutionTime("createUserTimeAPI", System.currentTimeMillis() - startTime);
				throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "The username is invalid");
			}
			metric.recordExecutionTime("createUserTimeAPI", System.currentTimeMillis() - startTime);
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "The username is already present");
		}
		long startTimeDB = System.currentTimeMillis();
		System.out.println("Above ListTopicsResult");
 //       BasicAWSCredentials awsCreds = new BasicAWSCredentials("XXXXXX", "XXXXXX");
//        AmazonSNSClient amazonSNSClient=(AmazonSNSClient) AmazonSNSClientBuilder.standard()
//                .withCredentials(new AWSStaticCredentialsProvider(awsCreds))
//                .withRegion("us-west-2").build();
        AmazonSNSClient amazonSNSClient=(AmazonSNSClient) AmazonSNSClientBuilder.standard()
                .withRegion("us-west-2").build();
		ListTopicsResult listTopicsResult=amazonSNSClient.listTopics();
		System.out.println("Above topicList");
	    List<Topic> topicList=listTopicsResult.getTopics();
	    Topic topic=topicList.get(0);
	    System.out.println(topic.toString());
	    Calendar now = Calendar.getInstance();
        System.out.println("Minutes:" + now.get(Calendar.MINUTE));
        String token=userHelper.generateRandomUUID();
        String messageType="Mime";
        String message=user.getUsername()+" "+token+" "+messageType;
	    PublishRequest publishRequest = new PublishRequest(topic.getTopicArn(), message+" "+"This is sent from Intellij");
	    PublishResult publishResultFuture = amazonSNSClient.publish(publishRequest);
	    
		User retUser=userRepository.save(user);
		metric.recordExecutionTime("createUserTimeAPIForDB", System.currentTimeMillis() - startTimeDB);
		metric.recordExecutionTime("createUserTimeAPI", System.currentTimeMillis() - startTime);
		logger.info("179:The createUser() is successfull");
		logger.info("180:The number of times createUser() is called="+counterCreateUser);
		return retUser;
	}
	@PutMapping("/users/{username}")
	public User updateUser(@RequestBody User updateUser, @PathVariable("username") String username) {
		counterUpdateUser++;
		logger.info("186:User updateUser() execution started");
		metric.incrementCounter("updateUserCounterAPI");
		long startTime = System.currentTimeMillis();
		loadUserByUsername(username);
		
		User user = userRepository.findByUsername(username);
		if(!user.getVerified())
			throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "You are not authorized");
		if (userHelper.checkForValidUpdateFields(updateUser)) {
			metric.recordExecutionTime("updateUserTimeAPI", System.currentTimeMillis() - startTime);
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "You are not allowed to update some fields");
		}

		if (!(updateUser.getFirstname() == null)) {
			user.setFirstname(updateUser.getFirstname());
		}

		if (!(updateUser.getLastname() == null)) {
			user.setLastname(updateUser.getLastname());
		}

		if (!(updateUser.getPassword() == null)) {
			String pwd=userHelper.generateBcryptedPassword(user.getPassword());
			
			user.setPassword(pwd);
		}
		String date=userHelper.getDate();
		user.setAccountupdated(date);
		long startTimeDB = System.currentTimeMillis();
		User retUser=userRepository.save(user);
		metric.recordExecutionTime("updateUserTimeAPIForDB", System.currentTimeMillis() - startTimeDB);
		metric.recordExecutionTime("updateUserTimeAPI", System.currentTimeMillis() - startTime);
		logger.info("207:User updateUser() is successfull");
		logger.info("219:The number of times updateUser() is called="+counterUpdateUser);
		return retUser;
	}
	@GetMapping("/users/verifyUserEmail/{username}")
	public User verifyUser(@PathVariable("username") String username) {
		counterVerifyUser++;
		logger.info("212:User verifyUser() execution started");
		metric.incrementCounter("verifyUserCounterAPI");
		long startTime = System.currentTimeMillis();
		loadUserByUsername(username);
		User user = userRepository.findByUsername(username);
		//******************************************************************
		String userCreatedDate=user.getAccountcreated();
		logger.info("user.getAccountcreated()="+userCreatedDate);
		String minutes=userCreatedDate.split(":")[1];
		String date=userHelper.getDate();
		String currentMinute=date.split(":")[1];
		logger.info("minutes="+minutes);
		logger.info("date="+date);
		logger.info("currentMinute="+currentMinute);
		if(Math.abs(Integer.parseInt(minutes)-Integer.parseInt(currentMinute))>2)
			throw new ResponseStatusException(HttpStatus.REQUEST_TIMEOUT,"Sorry!!!The link for user:"+username+" has been expired");
		//******************************************************************
		user.setVerified_on(date);
		user.setVerified(true);
		long startTimeDB = System.currentTimeMillis();
		User retUser=userRepository.save(user);
		metric.recordExecutionTime("verifyUserTimeAPIForDB", System.currentTimeMillis() - startTimeDB);
		metric.recordExecutionTime("verifyUserTimeAPI", System.currentTimeMillis() - startTime);
		logger.info("224:The verifyUser() is successfull");
		logger.info("238:The number of times verifyUser() is called="+counterVerifyUser);
		return retUser;
	}
	@Override
	public UserDetails loadUserByUsername(String userId) throws UsernameNotFoundException {
		User user = userRepository.findByUsername(userId);
		if(user==null) 
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "The User "+userId+" does not exist");
		else 
		    return new MyUserDetails(user);
	}

}

package com.webapp.cloud.api;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.util.List;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.ResponseBody;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.server.ResponseStatusException;

import com.amazonaws.SdkClientException;
import com.amazonaws.auth.AWSCredentials;
import com.amazonaws.auth.AWSStaticCredentialsProvider;
import com.amazonaws.auth.BasicAWSCredentials;
import com.amazonaws.services.s3.AmazonS3;
import com.amazonaws.services.s3.AmazonS3ClientBuilder;
import com.amazonaws.services.s3.model.ListObjectsV2Result;
import com.amazonaws.services.s3.model.ObjectMetadata;
import com.amazonaws.services.s3.model.S3ObjectSummary;
import com.timgroup.statsd.NonBlockingStatsDClient;
import com.timgroup.statsd.StatsDClient;
import com.webapp.cloud.EC2.EC2Info;
import com.webapp.cloud.model.ImageEntity;
import com.webapp.cloud.model.Metadata;
import com.webapp.cloud.model.User;
import com.webapp.cloud.replicaDatabase.BackupReadRepo;
import com.webapp.cloud.repository.ImageRepository;
import com.webapp.cloud.repository.MetadataRepository;
import com.webapp.cloud.repository.UserRepository;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;


@RestController
@RequestMapping("/v1/image")
public class ImageService {
	@Value("${cloud.aws.region.bucket.name}")
    private String bucketName;
	
	private UserImpl userHelper=new UserImpl();
	@Autowired
	private UserRepository userRepository;
	@Autowired
	private ImageRepository imageRepository;
	@Autowired
	private EC2Info ec2Info;
	@Autowired
	private BackupReadRepo backupReadRepository;
	@Autowired
	private AmazonS3 amazonS3;
	
	@Autowired
	private MetadataRepository metadataRepository;
	
	@Autowired
    private StatsDClient metric=new NonBlockingStatsDClient("statsd", "localhost", 8125);

	Logger logger=LoggerFactory.getLogger(ImageService.class);
	
	
	@GetMapping("/users/{username}/{imagename}")
	public ImageEntity getImage(@PathVariable("username") String username,@PathVariable("imagename")String imagename) {
		logger.info("77:User getImage() execution started");
		metric.incrementCounter("getImageCounterAPI");
		long startTime = System.currentTimeMillis();
		if (!backupReadRepository.existsByUsername(username)) {
			metric.recordExecutionTime("getImageTimeAPI", System.currentTimeMillis() - startTime);
			throw new ResponseStatusException(HttpStatus.NOT_FOUND, "The User "+username+" does not exist");
		}
		if(imageRepository.findByFileNameAndUserId(imagename, userRepository.findByUsername(username).getId())==null) {
			metric.recordExecutionTime("getImageTimeAPI", System.currentTimeMillis() - startTime);
			throw new ResponseStatusException(HttpStatus.NOT_FOUND, "The User "+username+" does not have a profile image");
		}
		if(!backupReadRepository.findByUsername(username).getVerified())
			throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "You are not authorized");
		long startTimeDB = System.currentTimeMillis();
		ImageEntity retImageEntity=imageRepository.findByFileNameAndUserId(imagename, userRepository.findByUsername(username).getId());
		metric.recordExecutionTime("getImageTimeAPIForDB", System.currentTimeMillis() - startTimeDB);
		metric.recordExecutionTime("getImageTimeAPI", System.currentTimeMillis() - startTime);
		logger.info("94:The getImage() is successfull");
		return retImageEntity;
	}
	
	@PostMapping(path="/users/{username}/{imagename}")
	@ResponseBody
	public ImageEntity fileUpload( @RequestPart(value = "file")MultipartFile file,@PathVariable("username")String username,
			@PathVariable("imagename")String imagename) throws Exception {
		logger.info("102:User fileUpload() execution started");
		metric.incrementCounter("fileUploadCounterAPI");
		long startTime = System.currentTimeMillis();
		amazonS3=AmazonS3ClientBuilder.standard()
		        .withRegion("us-west-2")
		        .build();
		bucketName=bucketName.trim();
		if(!backupReadRepository.existsByUsername(username)) {
			metric.recordExecutionTime("fileUploadTimeAPI", System.currentTimeMillis() - startTime);
			throw new ResponseStatusException(HttpStatus.NOT_FOUND, "The User "+username+" does not exist");
		}
		User user=userRepository.findByUsername(username);
		if(!user.getVerified())
			throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "You are not authorized");
		ImageEntity update=imageRepository.findByUserId(user.getId());
		ImageEntity imageEntity=new ImageEntity();
		if(update!=null &&	imageRepository.existsById(update.getId())) {
			System.out.println("");
			imagename=update.getUser_id()+imagename;
			update.setFile_name(imagename);
			String url=buildUrl(update.getUrl(),imagename);
			update.setUrl(url);
			ListObjectsV2Result result = amazonS3.listObjectsV2(bucketName);
	        List<S3ObjectSummary> objects = result.getObjectSummaries();
	        for (S3ObjectSummary os : objects) {
	        	if(os.getKey().contains(user.getId())) {
	        		amazonS3.deleteObject(bucketName, os.getKey());
	        		Metadata meta=metadataRepository.findByKey(os.getKey());
	        		metadataRepository.delete(meta);
	        		break;
	        	}
	        }
	        File files = convertMultiPartToFile(file);
	        long startTimeS3Bucket = System.currentTimeMillis();
	        uploadToS3Bucket(bucketName,files,imagename);
	        metric.recordExecutionTime("fileUploadTimeAPIForS3Bucket", System.currentTimeMillis() - startTimeS3Bucket);
	        long startTimeDB = System.currentTimeMillis();
	        ImageEntity retImageEntity=imageRepository.save(update);
	        metric.recordExecutionTime("fileUploadTimeAPIForDB", System.currentTimeMillis() - startTimeDB);
	        metric.recordExecutionTime("fileUploadTimeAPI", System.currentTimeMillis() - startTime);
			return retImageEntity;
		}else if(!imageRepository.existsByUserId(user.getId())) {
			String uuid = userHelper.generateRandomUUID();
			imageEntity.setId(uuid);
			String date=userHelper.getDate();
			imageEntity.setUpload_date(date);
			imagename=user.getId()+imagename;
			StringBuilder sb=new StringBuilder(bucketName+"/"+user.getId()+"/"+imagename);
			imageEntity.setUrl(sb.toString());
			imageEntity.setFile_name(imagename);
			imageEntity.setUser_id(user.getId());
		} 	
		File files = convertMultiPartToFile(file);
		long startTimeS3Bucket = System.currentTimeMillis();
		uploadToS3Bucket(bucketName,files,imagename);
		metric.recordExecutionTime("fileUploadTimeAPIForS3Bucket", System.currentTimeMillis() - startTimeS3Bucket);
		long startTimeDB = System.currentTimeMillis();
		ImageEntity retImageEntity=imageRepository.save(imageEntity);
		metric.recordExecutionTime("fileUploadTimeAPIForDB", System.currentTimeMillis() - startTimeDB);
		metric.recordExecutionTime("fileUploadTimeAPI", System.currentTimeMillis() - startTime);
		logger.info("162:The fileUpload() is successfull");
		return retImageEntity;
	}
	private File convertMultiPartToFile(MultipartFile file) throws IOException {
    	File convFile = new File(file.getOriginalFilename());
    	FileOutputStream fos = new FileOutputStream(convFile);
    	fos.write(file.getBytes());
    	fos.close();
    	return convFile;
    }
	private void uploadToS3Bucket(String bucketName,File file,String imagename) throws Exception {
		amazonS3=AmazonS3ClientBuilder.standard()
	        .withRegion("us-west-2")
	        .build();
		amazonS3.putObject(bucketName, imagename, file);
		try {
			if (!amazonS3.doesBucketExistV2(bucketName)) {
				throw new Exception("Exception");
			}
			ObjectMetadata metadata = new ObjectMetadata();
			metadata.setContentLength(file.getTotalSpace());
			amazonS3.putObject(bucketName, imagename, file);
			Metadata meta=new Metadata();
			meta.setKey(imagename);
			meta.setLastModified(userHelper.getDate());
			meta.setSize(file.getTotalSpace());
			meta.setStorageClass(bucketName);
			metadataRepository.save(meta);
		} catch (SdkClientException | IOException e) {
			throw new Exception("Exception");
		}
	}
	private String buildUrl(String url, String imagename) {
		int lastIndex=url.lastIndexOf("/");
		StringBuilder sb=new StringBuilder(url);
		sb.delete(lastIndex+1,sb.length());
		sb.append(imagename);
		return sb.toString();
	}
	
	
	@DeleteMapping("/users/{username}/{imagename}")
	public String deleteImage(@PathVariable("username") String username ,@PathVariable("imagename") String imagename){
		logger.info("205:User deleteImage() execution started");
		metric.incrementCounter("deleteImageCounterAPI");
		long startTime = System.currentTimeMillis();
		bucketName=bucketName.trim();
		if(!backupReadRepository.existsByUsername(username)) {
			metric.recordExecutionTime("deleteImageTimeAPI", System.currentTimeMillis() - startTime);
			throw new ResponseStatusException(HttpStatus.NOT_FOUND, "The User "+username+" does not exist");
		}
		if(!backupReadRepository.findByUsername(username).getVerified())
			throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "You are not authorized");
		User user=backupReadRepository.findByUsername(username);
		ImageEntity image=imageRepository.findByFileNameAndUserId(imagename,user.getId());
		if(image==null||!imageRepository.existsById(image.getId())) {
			metric.recordExecutionTime("deleteImageTimeAPI", System.currentTimeMillis() - startTime);
			throw new ResponseStatusException(HttpStatus.NOT_FOUND, "The User with image "+imagename+" does not exist");
		}
		long startTimeS3Bucket = System.currentTimeMillis();
		deleteImageFromS3Bucket(user.getId(),image.getFile_name());
		metric.recordExecutionTime("deleteImageTimeAPIForS3Bucket", System.currentTimeMillis() - startTimeS3Bucket);
		long startTimeDB = System.currentTimeMillis();
		imageRepository.delete(image);
		metric.recordExecutionTime("deleteImageTimeAPIForDB", System.currentTimeMillis() - startTimeDB);
		metric.recordExecutionTime("deleteImageTimeAPI", System.currentTimeMillis() - startTime);
		logger.info("228:User deleteImage() is successfull");
		return "Image "+imagename+" successfully deleted";
	}

	private String deleteImageFromS3Bucket(String userId,String file_name) {
		bucketName=bucketName.trim();
		amazonS3=AmazonS3ClientBuilder.standard()
		        .withRegion("us-west-2")
		        .build();
		if (!amazonS3.doesBucketExistV2(bucketName)) {
			return "No Bucket Found";
		}
		ListObjectsV2Result result = amazonS3.listObjectsV2(bucketName);
        List<S3ObjectSummary> objects = result.getObjectSummaries();
        for (S3ObjectSummary os : objects) {
        	if(os.getKey().contains(userId)) {
        		amazonS3.deleteObject(bucketName, os.getKey());
        		Metadata meta=metadataRepository.findByKey(os.getKey());
        		metadataRepository.delete(meta);
        		break;
        	}
        }
		return "File deleted successfully";
	}
}

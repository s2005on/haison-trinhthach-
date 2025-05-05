DROP DATABASE IF EXISTS thegioididong;
CREATE DATABASE IF NOT EXISTS thegioididong;
USE thegioididong;

CREATE TABLE phone_model (
  phoneModelID INT NOT NULL AUTO_INCREMENT,
  name VARCHAR(50) NOT NULL,
  manufacturerID INT NOT NULL,
  countView INT NOT NULL,
  countSold INT NOT NULL,
  warrantyID INT,
  articleID INT,
  PRIMARY KEY (phoneModelID)
);

CREATE TABLE phone_model_option (
  phoneModelOptionID INT NOT NULL AUTO_INCREMENT,
  phoneModelID INT NOT NULL,
  price INT NOT NULL,
  name VARCHAR(100) NOT NULL,
  colorHex INT,
  colorName VARCHAR(20),
  PRIMARY KEY (phoneModelOptionID)
);

CREATE TABLE phone_tech_spec (
  phoneModelOptionID INT NOT NULL,
  techSpecID INT NOT NULL,
  infoText VARCHAR(100),
  infoNum DECIMAL(10,3),
  PRIMARY KEY (phoneModelOptionID, techSpecID)
);

CREATE TABLE technical_spec (
  techSpecID INT NOT NULL AUTO_INCREMENT,
  name VARCHAR(30) NOT NULL,
  description TEXT,
  PRIMARY KEY (techSpecID)
);

CREATE TABLE manufacturer (
  manufacturerID INT NOT NULL AUTO_INCREMENT,
  name VARCHAR(15) NOT NULL,
  description TEXT,
  PRIMARY KEY (manufacturerID)
);

CREATE TABLE warranty (
  warrantyID INT NOT NULL AUTO_INCREMENT,
  name VARCHAR(50) NOT NULL,
  description TEXT,
  warrantyDuration INT NOT NULL,
  PRIMARY KEY (warrantyID)
);

CREATE TABLE article (
  articleID INT NOT NULL AUTO_INCREMENT,
  content TEXT,
  PRIMARY KEY (articleID)
);

CREATE TABLE phone_review (
  reviewID INT NOT NULL AUTO_INCREMENT,
  phoneModelID INT NOT NULL,
  phoneModelOptionID INT,
  userID INT NOT NULL,
  rating DECIMAL(3,2) NOT NULL,
  likes INT NOT NULL,
  timePosted DATETIME NOT NULL,
  PRIMARY KEY (reviewID)
);

CREATE TABLE phone_review_detail (
  reviewID INT NOT NULL,
  content TEXT NOT NULL,
  PRIMARY KEY (reviewID)
);

CREATE TABLE phone (
  phoneID INT NOT NULL AUTO_INCREMENT,
  phoneModelOptionID INT NOT NULL,
  imei VARCHAR(15) NOT NULL,
  customPrice INT,
  phoneCondition ENUM('New', 'Used', 'Refurbished') NOT NULL,
  status ENUM('InStore', 'Active', 'Repairing', 'Inactive') NOT NULL,
  ownedByUserID INT,
  warrantyID INT,
  warrantyUntil DATE,
  inStoreID INT,
  PRIMARY KEY (phoneID)
);

CREATE TABLE store (
  storeID INT NOT NULL AUTO_INCREMENT,
  name VARCHAR(50) NOT NULL,
  address VARCHAR(100) NOT NULL,
  phoneNumber VARCHAR(15) NOT NULL,
  gps_longitude DECIMAL(10, 5) NOT NULL,
  gps_latitude DECIMAL(10, 5) NOT NULL,
  districtID INT NOT NULL,
  openTime TIME,
  closeTime TIME,
  PRIMARY KEY (storeID)
);

CREATE TABLE province (
  provinceID INT NOT NULL,
  name VARCHAR(50) NOT NULL,
  PRIMARY KEY (provinceID)
);

CREATE TABLE district (
  districtID INT NOT NULL,
  name VARCHAR(50) NOT NULL,
  provinceID INT NOT NULL,
  PRIMARY KEY (districtID)
);


CREATE TABLE services (
  serviceID INT NOT NULL AUTO_INCREMENT,
  name VARCHAR(50) NOT NULL,
  price INT NOT NULL,
  serviceTypeID INT NOT NULL,
  PRIMARY KEY (serviceID)
);

CREATE TABLE service_type (
  serviceTypeID INT NOT NULL AUTO_INCREMENT,
  name VARCHAR(50) NOT NULL,
  description TEXT,
  PRIMARY KEY (serviceTypeID)
);

CREATE TABLE users (
  userID INT NOT NULL AUTO_INCREMENT,
  fullName VARCHAR(50) NOT NULL,
  email VARCHAR(50),
  phone VARCHAR(15),
  address VARCHAR(100),
  districtID INT,
  role ENUM('Customer', 'Employee') NOT NULL,
  storeID INT,
  PRIMARY KEY (userID)
);

CREATE TABLE orders (
  orderID INT NOT NULL AUTO_INCREMENT,
  orderTime DATETIME NOT NULL,
  shippedTime DATETIME,
  status ENUM('Pending', 'Preparing', 'Delivering', 'Completed', 'Cancelled') NOT NULL,
  comment TEXT,
  userID INT NOT NULL,
  fromStoreID INT NOT NULL,
  employeeID INT,
  PRIMARY KEY (orderID)
);

CREATE TABLE order_detail (
  orderID INT NOT NULL,
  phoneID INT NOT NULL,
  serviceID INT NOT NULL,
  promotionID INT,
  originalPrice INT NOT NULL,
  finalPrice INT NOT NULL,
  PRIMARY KEY (orderID, phoneID, serviceID)
);

CREATE TABLE promotion (
  promotionID INT NOT NULL AUTO_INCREMENT,
  startDate DATE NOT NULL,
  endDate DATE NOT NULL,
  name VARCHAR(50) NOT NULL,
  description TEXT,
  quantity INT,
  PRIMARY KEY (promotionID)
);

CREATE TABLE promotion_detail_phone (
  promotionID INT NOT NULL,
  phoneModelID INT NOT NULL,
  phoneModelOptionID INT NOT NULL,
  discountPercent DECIMAL(5,2),
  discountFixed INT,
  fixedNewPrice INT,
  PRIMARY KEY (promotionID, phoneModelID, phoneModelOptionID)
);

CREATE TABLE promotion_detail_service (
  promotionID INT NOT NULL,
  serviceTypeID INT NOT NULL,
  serviceID INT NOT NULL,
  discountPercent DECIMAL(5,2),
  discountFixed INT,
  fixedNewPrice INT,
  PRIMARY KEY (promotionID, serviceTypeID, serviceID)
);
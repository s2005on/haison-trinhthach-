DELIMITER $$

-- 1. LỌC SẢN PHẨM THEO MANUFACTURER
DROP PROCEDURE IF EXISTS GetPhonesByManufacturer $$
CREATE PROCEDURE GetPhonesByManufacturer(IN manufacturerName VARCHAR(50))
BEGIN
    SELECT 
        pm.name AS PhoneName, 
        pm.countView, 
        pm.countSold, 
        mf.name AS Manufacturer
    FROM phone_model pm
    JOIN manufacturer mf ON pm.manufacturerID = mf.manufacturerID
    WHERE mf.name = manufacturerName;
END $$

-- 1. LỌC SẢN PHẨM THEO GIÁ TIỀN
DROP PROCEDURE IF EXISTS GetPhonesByPrice $$
CREATE PROCEDURE GetPhonesByPrice(IN minPrice INT, IN maxPrice INT)
BEGIN
    SELECT
        pm.name AS PhoneModel, 
        pmo.name AS OptionName,
        pmo.price AS Price, 
        mf.name AS Manufacturer
    FROM phone_model pm
    JOIN phone_model_option pmo ON pm.phoneModelID = pmo.phoneModelID
    JOIN manufacturer mf ON pm.manufacturerID = mf.manufacturerID
    WHERE pmo.price BETWEEN minPrice AND maxPrice
    ORDER BY pmo.price ASC;
END $$

-- 3. LỌC SẢN PHẨM THEO TECH_SPEC
DROP PROCEDURE IF EXISTS GetPhonesByTechSpec $$
CREATE PROCEDURE GetPhonesByTechSpec(
    IN p_techSpecID INT, 
    IN p_infoNumMin DECIMAL(10,3), 
    IN p_infoNumMax DECIMAL(10,3)
)
BEGIN
    SELECT 
        pm.name AS PhoneModel, 
        pmo.name AS OptionName,
        pts.infoNum AS SpecValue,
        pts.infoText AS TechSpecDescription
    FROM phone_model pm
    INNER JOIN phone_model_option pmo ON pm.phoneModelID = pmo.phoneModelID
    INNER JOIN phone_tech_spec pts ON pmo.phoneModelOptionID = pts.phoneModelOptionID
    WHERE pts.techSpecID = p_techSpecID 
      AND pts.infoNum BETWEEN p_infoNumMin AND p_infoNumMax;
END $$

-- 4. ĐỀ XUẤT SẢN PHẨM BÁN CHẠY THEO THÁNG
DROP PROCEDURE IF EXISTS GetBestSellingPhonesByMonth $$

CREATE PROCEDURE GetBestSellingPhonesByMonth(IN targetMonth INT, IN targetYear INT)
BEGIN
    SELECT 
        pm.name AS PhoneModel, 
        COUNT(DISTINCT(CONCAT(od.orderID, '-', od.phoneID))) AS TotalSold
    FROM phone_model pm
    JOIN phone_model_option pmo ON pmo.phoneModelID = pm.phoneModelID
    JOIN phone p ON p.phoneModelOptionID = pmo.phoneModelOptionID
    JOIN order_detail od ON p.phoneID = od.phoneID
    JOIN orders o ON od.orderID = o.orderID
    WHERE MONTH(o.orderTime) = targetMonth 
      AND YEAR(o.orderTime) = targetYear
    GROUP BY pm.phoneModelID
    ORDER BY TotalSold DESC
    LIMIT 5;
END $$ 



-- 5. ĐỀ XUẤT CÁC SẢN PHẨM TƯƠNG TỰ DỰA TRÊN ID VỚI PHONE CONDITION KHÁC NHAU
DROP PROCEDURE IF EXISTS GetSimilarPhones $$

CREATE PROCEDURE GetSimilarPhones(IN phoneID INT)
BEGIN
	SELECT DISTINCT 
        pmo.name AS PhoneName,
        p.customPrice, 
        p.phoneCondition
    FROM phone p
    JOIN phone_model_option pmo ON p.phoneModelOptionID = pmo.phoneModelOptionID
    WHERE pmo.phoneModelID IN 
        (SELECT pmo1.phoneModelID 
         FROM phone p1 
         JOIN phone_model_option pmo1 ON p1.phoneModelOptionID = pmo1.phoneModelOptionID
         WHERE p1.phoneID = phoneID);
END $$ 

-- 6. CHECK BẢO HÀNH CÒN KHẢ DỤNG KHÔNG
DROP PROCEDURE IF EXISTS CheckWarranty $$
CREATE PROCEDURE CheckWarranty(IN phoneID INT, IN currentDate DATE)
BEGIN
    SELECT
        p.phoneID,
        p.phoneCondition,
        p.warrantyID,
        p.warrantyUntil,
        CASE
            WHEN p.warrantyUntil >= currentDate THEN 'Valid'
            ELSE 'Expired'
        END AS WarrantyStatus
    FROM phone p
    WHERE p.phoneID = phoneID;
END $$


-- 7. TÌM KIẾM ĐỊA CHỈ GẦN NGƯỜI DÙNG NHẤT
DROP PROCEDURE IF EXISTS GetNearbyStores $$
CREATE PROCEDURE GetNearbyStores(IN userLongitude DECIMAL(10, 5), IN userLatitude DECIMAL(10, 5))
BEGIN
    SELECT
        storeID,
        name AS StoreName,
        address,
        phoneNumber,
        SQRT(POW(gps_longitude - userLongitude, 2) + POW(gps_latitude - userLatitude, 2)) AS Distance
    FROM store
    ORDER BY Distance ASC;
END $$


-- 8. THỐNG KÊ CHI TIẾT DOANH THU HÀNG THÁNG
DROP PROCEDURE IF EXISTS ListMonthlyRevenue $$
CREATE PROCEDURE ListMonthlyRevenue(IN targetMonth INT, IN targetYear INT)
BEGIN
    SELECT
        DATE(o.orderTime) AS OrderDate,
        COUNT(DISTINCT o.orderID) AS TotalOrders,
        SUM(od.finalPrice) AS DailyRevenue
    FROM orders o
    JOIN order_detail od ON o.orderID = od.orderID
    WHERE YEAR(o.orderTime) = targetYear AND MONTH(o.orderTime) = targetMonth
    GROUP BY OrderDate
    ORDER BY OrderDate;
END $$

-- 9. TÍNH TỔNG SỐ ĐƠN HÀNG VÀ TỔNG SỐ TIỀN NHÂN ĐƯỢC CỦA THÁNG
DROP PROCEDURE IF EXISTS GetMonthlyRevenue $$
CREATE PROCEDURE GetMonthlyRevenue(IN targetMonth INT, IN targetYear INT)
BEGIN
    SELECT
        MONTH(o.orderTime) AS Month,
        COUNT(DISTINCT o.orderID) AS TotalOrders,
        SUM(od.finalPrice) AS MonthlyRevenue
    FROM orders o
    JOIN order_detail od ON o.orderID = od.orderID
    WHERE YEAR(o.orderTime) = targetYear AND MONTH(o.orderTime) = targetMonth
    GROUP BY Month;
END $$

-- 10. XUẤT HÓA ĐƠN
DROP PROCEDURE IF EXISTS ExportInvoice $$
CREATE PROCEDURE ExportInvoice(IN orderID INT)
BEGIN
    SELECT
        o.orderID AS OrderID,
        CASE 
            WHEN od.serviceID = 0 THEN pmo.name
            ELSE s.name
        END AS ItemName,
        o.orderTime AS OrderTime,
        od.originalPrice AS OriginalPrice,
        od.finalPrice AS FinalPrice,
        p.name AS DiscountName
    FROM orders o
    JOIN order_detail od ON o.orderID = od.orderID
    JOIN phone ph on ph.phoneID = od.phoneID
    LEFT JOIN phone_model_option pmo ON ph.phoneModelOptionID = pmo.phoneModelOptionID
    LEFT JOIN services s ON od.serviceID = s.serviceID
    LEFT JOIN promotion p ON od.promotionID = p.promotionID
    WHERE o.orderID = orderID;
END $$

-- 11. TỔNG SỐ TIỀN PHẢI THANH TOÁN
DROP PROCEDURE IF EXISTS TotalMoneyCustomerHaveToPay $$
CREATE PROCEDURE TotalMoneyCustomerHaveToPay(IN orderID INT)
BEGIN
    SELECT
        o.orderID AS OrderID,
		u1.fullName AS EmployeeName,
        u2.fullName AS CustomerName,
        sto.name AS StoreName,
        sto.address AS StoreAdress,
        o.orderTime AS OrderTime,
        SUM(od.originalPrice) AS OriginalPrice,
        SUM(od.finalPrice) AS FinalPrice,
        SUM(od.originalPrice) - SUM(od.finalPrice) AS TotalMoneySaved 
    FROM orders o
    JOIN store sto on sto.storeID = o.FromStoreID
	JOIN users u1 on u1.userID = o.employeeID
    JOIN users u2 on u2.userID = o.userID
    JOIN order_detail od ON o.orderID = od.orderID
    GROUP BY o.orderID
    HAVING o.orderID = orderID;
END $$

-- 12. THAY ĐỔI INSTOREID CỦA PHONE THÀNH FROMSTOREID CỦA ORDERS NẾU SẢN PHẨM ĐÃ ĐƯỢC GIAO ĐẾN CỬA HÀNG
DROP PROCEDURE IF EXISTS UpdateInStoreIDToFromStoreID $$
CREATE PROCEDURE UpdateInStoreIDToFromStoreID(IN orderID INT)
BEGIN
    UPDATE phone p
    JOIN order_detail od ON p.phoneID = od.phoneID
    JOIN orders o ON od.orderID = o.orderID
    SET p.INStoreID = o.FromStoreID
    WHERE o.orderID = orderID;  
END $$


-- 13. THÊM THÔNG TIN VÀO BẢNG order_detail, TÍNH GIÁ GỐC VÀ GIÁ CUỐI CÙNG
DROP PROCEDURE IF EXISTS AddOrderDetail $$

CREATE PROCEDURE AddOrderDetail(
    IN p_orderID INT, 
    IN p_phoneID INT, 
    IN p_serviceID INT, 
    IN p_promotionID INT
)
BEGIN
    -- Khai báo biến
    DECLARE v_original_price INT; 
    DECLARE v_final_price INT; 

    DECLARE v_original_service_price INT;
    DECLARE v_final_service_price INT;

    DECLARE v_discount_percentage DECIMAL(4,2);
    DECLARE v_discount_fixed INT;
    DECLARE v_fixed_new_price INT;

    DECLARE v_phone_model_id INT;
    DECLARE v_phone_model_option_id INT;

    DECLARE v_service_type_id INT;

    DECLARE v_start_promotion_date DATE;
    DECLARE v_end_promotion_date DATE;
    DECLARE v_order_time DATE;

    -- Lấy thông tin cần thiết
    SELECT o.orderTime, p.startDate, p.endDate 
    INTO v_order_time, v_start_promotion_date, v_end_promotion_date
    FROM orders o
    JOIN promotion p ON p.promotionID = p_promotionID
    WHERE o.orderID = p_orderID;

    -- Lấy giá gốc và thông tin điện thoại
    SELECT 
        COALESCE(
            customPrice, 
            (SELECT price 
             FROM phone_model_option 
             WHERE phone_model_option.phoneModelOptionID = phone.phoneModelOptionID)
        ), 
        pmo.phoneModelID, 
        phone.phoneModelOptionID
    INTO 
        v_original_price, 
        v_phone_model_id, 
        v_phone_model_option_id
    FROM 
        phone 
    JOIN 
        phone_model_option pmo 
    ON 
        phone.phoneModelOptionID = pmo.phoneModelOptionID
    WHERE 
        phone.phoneID = p_phoneID;

    -- Xử lý khuyến mãi điện thoại
    SELECT discountPercent, discountFixed, fixedNewPrice
    INTO v_discount_percentage, v_discount_fixed, v_fixed_new_price
    FROM promotion_detail_phone
    WHERE promotionID = p_promotionID
      AND (phoneModelID = 0 OR phoneModelID = v_phone_model_id)
      AND (phoneModelOptionID = 0 OR phoneModelOptionID = v_phone_model_option_id);

    IF v_fixed_new_price IS NOT NULL THEN
        SET v_final_price = v_fixed_new_price;
    ELSEIF v_discount_percentage IS NOT NULL THEN
        SET v_final_price = v_original_price * (1 - (v_discount_percentage / 100));
    ELSEIF v_discount_fixed IS NOT NULL THEN
        SET v_final_price = GREATEST(0, v_original_price - v_discount_fixed);
    ELSE
        SET v_final_price = v_original_price;
    END IF;

    -- Lấy giá gốc và thông tin dịch vụ
    SELECT price, serviceTypeID
    INTO v_original_service_price, v_service_type_id
    FROM services
    WHERE serviceID = p_serviceID;

    -- Xử lý khuyến mãi dịch vụ
    IF EXISTS (
        SELECT 1 
        FROM promotion_detail_service 
        WHERE promotionID = p_promotionID
    ) THEN
        SELECT discountPercent, discountFixed, fixedNewPrice
        INTO v_discount_percentage, v_discount_fixed, v_fixed_new_price
        FROM promotion_detail_service
        WHERE promotionID = p_promotionID 
          AND serviceTypeID = v_service_type_id
        LIMIT 1;

        IF v_discount_percentage IS NOT NULL THEN
            SET v_final_service_price = v_original_service_price * (1 - v_discount_percentage / 100);
        ELSEIF v_discount_fixed IS NOT NULL THEN
            SET v_final_service_price = GREATEST(0, v_original_service_price - v_discount_fixed);
        ELSEIF v_fixed_new_price IS NOT NULL THEN
            SET v_final_service_price = v_fixed_new_price;
        ELSE 
            SET v_final_service_price = v_original_service_price;
        END IF;
    ELSE
        SET v_final_service_price = v_original_service_price;
    END IF;

    -- Kiểm tra thời gian đặt hàng có nằm trong thời gian khuyến mãi không
    IF v_order_time NOT BETWEEN v_start_promotion_date AND v_end_promotion_date THEN
        SET v_final_price = v_original_price;
        SET v_final_service_price = v_original_service_price;
    END IF;

    -- Tổng giá cuối cùng
    SET v_final_price = v_final_price + v_final_service_price;

    -- Thêm thông tin vào bảng order_detail
    INSERT INTO order_detail(orderID, phoneID, serviceID, promotionID, originalPrice, finalPrice)
    VALUES (p_orderID, p_phoneID, p_serviceID, p_promotionID, v_original_price, v_final_price);

END $$ 


-- 14. SO SÁNH TECH_SPEC CỦA 2 MẪU ĐIỆN THOẠI
DROP PROCEDURE IF EXISTS CompareTechSpec $$
CREATE PROCEDURE CompareTechSpec(IN phoneModelOptionID1 INT, IN phoneModelOptionID2 INT)
BEGIN
    SELECT 
        ts.name AS TechSpecName,
        COALESCE(
            (SELECT pts.infoText FROM phone_tech_spec pts 
             WHERE pts.phoneModelOptionID = phoneModelOptionID1 AND pts.techSpecID = ts.techSpecID),
            (SELECT pts.infoNum FROM phone_tech_spec pts 
             WHERE pts.phoneModelOptionID = phoneModelOptionID1 AND pts.techSpecID = ts.techSpecID)
        ) AS SpecValue1,
        COALESCE(
            (SELECT pts.infoText FROM phone_tech_spec pts 
             WHERE pts.phoneModelOptionID = phoneModelOptionID2 AND pts.techSpecID = ts.techSpecID),
            (SELECT pts.infoNum FROM phone_tech_spec pts 
             WHERE pts.phoneModelOptionID = phoneModelOptionID2 AND pts.techSpecID = ts.techSpecID)
        ) AS SpecValue2,
         CASE 
            WHEN COALESCE(
                    (SELECT pts.infoText FROM phone_tech_spec pts 
                     WHERE pts.phoneModelOptionID = phoneModelOptionID1 AND pts.techSpecID = ts.techSpecID),
                    (SELECT pts.infoNum FROM phone_tech_spec pts 
                     WHERE pts.phoneModelOptionID = phoneModelOptionID1 AND pts.techSpecID = ts.techSpecID)
                ) = COALESCE(
                    (SELECT pts.infoText FROM phone_tech_spec pts 
                     WHERE pts.phoneModelOptionID = phoneModelOptionID2 AND pts.techSpecID = ts.techSpecID),
                    (SELECT pts.infoNum FROM phone_tech_spec pts 
                     WHERE pts.phoneModelOptionID = phoneModelOptionID2 AND pts.techSpecID = ts.techSpecID)
                ) THEN 'Equal'
            WHEN 
                (SELECT COALESCE(pts.infoNum, 0) 
                 FROM phone_tech_spec pts 
                 WHERE pts.phoneModelOptionID = phoneModelOptionID1 AND pts.techSpecID = ts.techSpecID) > 
                (SELECT COALESCE(pts.infoNum, 0) 
                 FROM phone_tech_spec pts 
                 WHERE pts.phoneModelOptionID = phoneModelOptionID2 AND pts.techSpecID = ts.techSpecID) 
                THEN 'First phone is better'
            ELSE 'Second phone is better'
        END AS CompareResult
    FROM 
        technical_spec ts
    WHERE 
        ts.techSpecID IN 
        (SELECT techSpecID FROM phone_tech_spec WHERE phoneModelOptionID = phoneModelOptionID1
         UNION
         SELECT techSpecID FROM phone_tech_spec WHERE phoneModelOptionID = phoneModelOptionID2)
    ORDER BY
        ts.name;
END $$

-- 15. QUẢN LÝ SỐ LƯỢNG TỔN KHO CỦA TỪNG MẪU ĐIỆN THOẠI Ở MỖI CỦA HÀNG
DROP PROCEDURE IF EXISTS checkStockLevel $$
CREATE PROCEDURE checkStockLevel(IN phoneModelID INT)
BEGIN
    SELECT pm.name AS PhoneModel, 
           s.name AS StoreName, 
           COUNT(p.phoneID) AS StockLevel
    FROM phone p
    JOIN phone_model_option pmo ON p.phoneModelOptionID = pmo.phoneModelOptionID
    JOIN phone_model pm ON pmo.phoneModelID = pm.phoneModelID
    JOIN store s ON p.inStoreID = s.storeID
    WHERE pm.phoneModelID = phoneModelID 
      AND p.status = 'InStore'
    GROUP BY pm.name, s.name;
END $$



-- 16. QUẢN LÝ SỐ LƯỢNG ĐƯỢC BÁN RA CỦA TỪNG MẪU ĐIỆN THOẠI
DROP PROCEDURE IF EXISTS checkSoldLevel $$
CREATE PROCEDURE checkSoldLevel(IN phoneModelID INT)
BEGIN
    SELECT pm.name AS PhoneModel, 
           COUNT(DISTINCT od.orderID) AS TotalOrders, 
           SUM(od.quantity) AS TotalSold
    FROM phone_model pm
    JOIN phone_model_option pmo ON pm.phoneModelID = pmo.phoneModelID
    JOIN phone p ON p.phoneModelOptionID = pmo.phoneModelOptionID
    JOIN order_detail od ON p.phoneID = od.phoneID
    WHERE pm.phoneModelID = phoneModelID
    GROUP BY pm.name;
END $$


-- 17. lỊCH SỬ MUA HÀNG CỦA KHÁCH HÀNG
drop procedure if exists checkOrderHistory $$
create procedure checkOrderHistory(in userID int)
begin
    SELECT o.userID, u.fullName, o.orderID, o.orderTime, o.status, o.shippedTime, SUM(od.finalPrice) AS TotalPrice
    FROM 
        orders o
    JOIN order_detail od ON o.orderID = od.orderID
    JOIN users u ON u.userID = o.userID
    WHERE o.userID = 21
    GROUP BY o.orderID;
    end $$


DELIMITER ;

CALL GetMonthlyRevenue(2,2023);
CALL ListMonthlyRevenue(2,2023);
CALL TotalMoneyCustomerHaveToPay(3);
CALL ExportInvoice(3);
select * from order_detail
where orderID = 27 and phoneID = 1090;
CALL GetBestSellingPhonesByMonth(2, 2023);
CALL CheckWarranty(1, '2023-09-27');
CALL UpdateInStoreIDToFromStoreID(49);
CALL GetPhonesByTechSpec(2, 0, 2.6);
CALL GetPhonesByPrice(2000000, 13000000);
CALL CompareTechSpec(12,23);

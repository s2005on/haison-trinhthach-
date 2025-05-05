-- TRANSACTIONS CHO SỬA DỮ LIỆU TRONG USERS
DELIMITER $$

DROP PROCEDURE IF EXISTS UpdateUser $$
CREATE PROCEDURE UpdateUser(
    IN userID INT,
    IN fullName VARCHAR(50),
    IN email VARCHAR(50),
    IN phone VARCHAR(15),
    IN address VARCHAR(100),
    IN provinceID INT,
    IN districtID INT,
    IN role ENUM('Customer', 'Employee'),
    IN storeID INT
)
BEGIN
    -- Bắt đầu giao dịch
    START TRANSACTION;
    BEGIN
        -- Cập nhật thông tin người dùng
        UPDATE users
        SET fullName = fullName, email = email, phone = phone,
            address = address, provinceID = provinceID,
            districtID = districtID, role = role, storeID = storeID
        WHERE userID = userID;
        -- Kiểm tra nếu cập nhật không thành công
        IF ROW_COUNT() = 0 THEN
            ROLLBACK;
            SIGNAL SQLSTATE '45000' 
                SET MESSAGE_TEXT = 'Update failed. Rolling back';
        END IF;
    END;

    -- Xác nhận giao dịch
    COMMIT;
END $$

-- TRANSACTIONS CHO SỬA DỮ LIỆU TRONG PHONE
DROP PROCEDURE IF EXISTS UpdatePhone $$
CREATE PROCEDURE UpdatePhone(
    IN phoneID INT,
    IN ownedByUserID INT,
    IN warrantyID INT,
    IN inStoreID INT,
    IN phoneModelOptionID INT,
    IN phoneCondition ENUM('New', 'Used', 'Refurbished'),
    IN customPrice INT,
    IN imei VARCHAR(15),
    IN status ENUM('Active', 'InStore', 'Inactive', 'Repairing'),
    IN warrantyUntil DATE
)

BEGIN
    -- Bắt đầu giao dịch
    START TRANSACTION;
    BEGIN
        -- Cập nhật thông tin điện thoại
        UPDATE phone
        SET ownedByUserID = ownedByUserID, warrantyID = warrantyID, 
            inStoreID = inStoreID, phoneModelOptionID = phoneModelOptionID, 
            phoneCondition = phoneCondition, customPrice = customPrice,
            imei = imei, status = status, warrantyUntil = warrantyUntil
        WHERE phoneID = phoneID;
        -- Kiểm tra nếu cập nhật không thành công
        IF ROW_COUNT() = 0 THEN
            ROLLBACK;
            SIGNAL SQLSTATE '45000' 
                SET MESSAGE_TEXT = 'Update failed. Rolling back transaction.';
        END IF;
    END;

    -- Xác nhận giao dịch
    COMMIT;
END $$

-- THÊM VÀO ĐƠN HÀNG ĐIỆN THOẠI MỚI MUA
DROP PROCEDURE IF EXISTS PurchasePhone $$
CREATE PROCEDURE PurchasePhone(
    IN p_phoneModelID INT,
    IN p_phoneID INT,
    IN p_serviceID INT,
    IN p_userID INT,
    IN p_fromStoreID INT,
    IN p_employeeID INT,
    IN p_originalPrice INT,
    IN p_finalPrice INT
)
BEGIN
    START TRANSACTION;

    -- 1. Tăng số lượng bán của model điện thoại
    UPDATE phone_model
    SET countSold = countSold + 1
    WHERE phoneModelID = p_phoneModelID;

    -- Kiểm tra nếu không tăng số lượng bán thành công
    IF ROW_COUNT() = 0 THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Failed to update phone model sales count. Rolling back.';
    END IF;

    -- 2. Tạo đơn hàng mới trong bảng orders
    INSERT INTO orders (orderTime, status, userID, fromStoreID, employeeID)
    VALUES (NOW(), 'Pending', p_userID, p_fromStoreID, p_employeeID);

    -- Kiểm tra nếu không tạo được đơn hàng
    IF ROW_COUNT() = 0 THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Failed to create order. Rolling back.';
    END IF;

    -- Lấy ID của đơn hàng vừa tạo
    SET @newOrderID = LAST_INSERT_ID();

    -- 3. Thêm chi tiết đơn hàng vào bảng order_detail
    INSERT INTO order_detail (orderID, phoneID, serviceID, originalPrice, finalPrice)
    VALUES (@newOrderID, p_phoneID, p_serviceID, p_originalPrice, p_finalPrice);

    -- Kiểm tra nếu không thêm được chi tiết đơn hàng
    IF ROW_COUNT() = 0 THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Failed to add order details. Rolling back.';
    END IF;

    -- Hoàn thành giao dịch
    COMMIT;
END $$

-- CẬP NHẬT TRẠNG THÁI ĐƠN HÀNG
DROP PROCEDURE IF EXISTS UpdateOrderStatusToDelivering $$
CREATE PROCEDURE UpdateOrderStatusToDelivering(
    IN p_orderID INT
)
BEGIN
    START TRANSACTION;
    UPDATE orders
    SET status = 'Delivering', shippedTime = NOW()
    WHERE orderID = p_orderID AND status = 'Preparing';

    COMMIT;
END $$


-- HỦY ĐƠN HÀNG NẾU KHÁCH MUỐN HOÀN TIỀN.
DROP PROCEDURE IF EXISTS CancelOrder $$
CREATE PROCEDURE CancelOrder(
    IN p_orderID INT
)
BEGIN
    -- Bắt đầu giao dịch
    START TRANSACTION;

    BEGIN
        -- 1. Khôi phục trạng thái sản phẩm về 'InStore'
        UPDATE phone
        SET status = 'InStore'
        WHERE phoneID IN (
            SELECT phoneID 
            FROM order_detail
            WHERE orderID = p_orderID
        );

        -- Kiểm tra nếu không cập nhật được trạng thái sản phẩm
        IF ROW_COUNT() = 0 THEN
            ROLLBACK;
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Failed to restore phone status. Rolling back transaction.';
        END IF;

        -- 2. Xóa chi tiết đơn hàng trong bảng order_detail
        DELETE FROM order_detail
        WHERE orderID = p_orderID;

        -- Kiểm tra nếu không xóa được chi tiết đơn hàng
        IF ROW_COUNT() = 0 THEN
            ROLLBACK;
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Failed to delete order details. Rolling back transaction.';
        END IF;

        -- 3. Cập nhật trạng thái đơn hàng trong bảng orders thành 'Cancelled'
        UPDATE orders
        SET status = 'Cancelled'
        WHERE orderID = p_orderID;

        -- Kiểm tra nếu không cập nhật được trạng thái đơn hàng
        IF ROW_COUNT() = 0 THEN
            ROLLBACK;
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Failed to update order status. Rolling back transaction.';
        END IF;
    END;

    -- Hoàn thành giao dịch
    COMMIT;
END $$
DELIMITER ;

SET SQL_SAFE_UPDATES = 0;

-- 3. Gọi stored procedure PurchasePhone
CALL PurchasePhone(
    2, -- phoneModelID
    8, -- phoneID
    6, -- serviceID
    1, -- userID
    1, -- fromStoreID
    295, -- employeeID
    15000000, -- originalPrice
    14000000 -- finalPrice
);

-- 4. Gọi stored procedure UpdateOrderStatusToDelivering
CALL UpdateOrderStatusToDelivering(
    1 -- orderID
);




DELIMITER $$

-- CẬP NHẬT SỐ LƯỢNG ĐÃ BÁN CỦA PHONE_MODEL
DROP TRIGGER IF EXISTS after_order_insert $$
CREATE TRIGGER after_order_insert
AFTER INSERT ON order_detail
FOR EACH ROW
BEGIN
    -- Cập nhật số lượng đã bán của phone model
    UPDATE phone_model
    SET countSold = countSold + 1
    WHERE phoneModelID = (
        SELECT phoneModelID
        FROM phone_model_option
        WHERE phoneModelOptionID = (
            SELECT phoneModelOptionID
            FROM phone
            WHERE phoneID = NEW.phoneID
        )
    );
END $$


-- TỰ ĐỘNG CẬP NHẬT TRẠNG THÁI ĐƠN HÀNG KHI ĐÃ GIAO
drop trigger if exists after_update_shipped_time $$
create trigger after_update_shipped_time
after update on orders
for each row
begin
	if new.shippedTime is not null then
		update orders
		set status = 'Completed'
		where orderID = new.orderID;
    end if;
end $$

-- TỰ ĐỘNG KÍCH HOẠT BẢO HÀNH CHO SẢN PHẨM MỚI MUA
DROP TRIGGER IF EXISTS after_update_order_status $$

CREATE TRIGGER after_update_order_status 
AFTER UPDATE ON orders 
FOR EACH ROW 
BEGIN 
    -- Khai báo các biến 
    DECLARE v_phoneID INT;
    DECLARE v_serviceID INT;
    DECLARE v_warrantyDuration INT;
    DECLARE done INT DEFAULT 0;

    -- Con trỏ để duyệt qua từng dòng của bảng order_detail
    DECLARE cur_order_details CURSOR FOR 
        SELECT od.phoneID, od.serviceID 
        FROM order_detail od
        INNER JOIN services s ON od.serviceID = s.serviceID
        WHERE od.orderID = NEW.orderID AND s.serviceTypeID = 1 limit 1;  

    -- Handler để xử lý khi con trỏ duyệt hết dữ liệu 
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;  

    -- Kiểm tra đơn hàng đã được hoàn tất chưa 
    IF NEW.status = 'Completed' AND OLD.status != 'Completed' THEN
        -- Mở con trỏ
        OPEN cur_order_details;

        read_order_details: LOOP 
            -- Lấy dữ liệu từ con trỏ
            FETCH cur_order_details INTO v_phoneID, v_serviceID;     

            -- Kiểm tra nếu hết dữ liệu thì thoát khỏi vòng lặp 
            IF done = 1 THEN  
                LEAVE read_order_details; 
            END IF;

            -- Lấy thời gian bảo hành từ bảng warranty
            SELECT warrantyDuration INTO v_warrantyDuration 
            FROM warranty 
            WHERE warrantyID = v_serviceID;

            -- Cập nhật thời gian bảo hành cho phone 
            UPDATE phone 
            SET warrantyUntil = DATE_ADD(NEW.shippedTime, INTERVAL v_warrantyDuration DAY)
            WHERE phoneID = v_phoneID;
        END LOOP;

        -- Đóng con trỏ
        CLOSE cur_order_details;
    END IF;
END $$


-- kIỂM TRA SÓ LƯỢNG HÀNG TRƯỚC KHI THÊM VÀO BẢNG ORDER_DETAIL
DROP TRIGGER IF EXISTS before_insert_order_detail $$
CREATE TRIGGER before_insert_order_detail
BEFORE INSERT ON order_detail
FOR EACH ROW
BEGIN
    DECLARE available_in_stock INT;

    -- Kiểm tra số lượng tồn kho trong một truy vấn duy nhất
    SELECT COUNT(*)
    INTO available_in_stock
    FROM phone p
    JOIN phone_model_option pmo ON p.phoneModelOptionID = pmo.phoneModelOptionID
    JOIN phone_model pm ON pmo.phoneModelID = pm.phoneModelID
    WHERE p.phoneID = NEW.phoneID
      AND p.phoneModelOptionID = (
          SELECT phoneModelOptionID 
          FROM phone 
          WHERE phoneID = NEW.phoneID
      )
      AND pm.phoneModelID = (
          SELECT phoneModelID 
          FROM phone_model_option 
          WHERE phoneModelOptionID = (
              SELECT phoneModelOptionID 
              FROM phone 
              WHERE phoneID = NEW.phoneID
          )
      )
      AND p.status = 'InStore';

    -- Nếu không còn tồn kho, phát tín hiệu lỗi
    IF available_in_stock = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'The selected phone model and option are out of stock.';
    END IF;
END $$

-- KIỂM TRA DỮ LIỆU TRƯỚC KHI THÊM VÀO BẢNG ORDERS
DROP TRIGGER IF EXISTS before_insert_orders $$

CREATE TRIGGER before_insert_orders
BEFORE INSERT ON orders
FOR EACH ROW
BEGIN
    -- Kiểm tra userID
    IF NOT EXISTS (
        SELECT 1 FROM users WHERE userID = NEW.userID AND role = 'Customer'
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Invalid userID: Must be a Customer';
    END IF;

    -- Kiểm tra employeeID
    IF NOT EXISTS (
        SELECT 1 FROM users WHERE userID = NEW.employeeID AND role = 'Employee'
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Invalid employeeID: Must be an Employee';
    END IF;
END$$

-- KIỂM TRA NGÀY GIAO HÀNG KHÔNG ĐƯỢC TRƯỚC NGÀY ĐẶT HÀNG

DROP TRIGGER IF EXISTS before_update_shipped_time $$

CREATE TRIGGER before_update_shipped_time
BEFORE UPDATE ON orders
FOR EACH ROW
BEGIN
    IF NEW.shippedTime < OLD.orderTime THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Shipped time cannot be earlier than order time.';
    END IF;
END $$

-- TỰ ĐỘNG CẬP NHẬT TRẠNG THÁI SẢN PHẨM KHI CÓ ĐƠN ĐẶT HÀNG
DROP TRIGGER IF EXISTS after_insert_order_detail $$

CREATE TRIGGER after_insert_order_detail 
AFTER INSERT ON order_detail
FOR EACH ROW
BEGIN
    -- Cập nhật trạng thái sản phẩm thành 'Active'
    UPDATE phone
    SET status = 'Active'
    WHERE phoneID = NEW.phoneID;
END $$


-- TỰ ĐỘNG CẬP NHẬT TRẠNG THÁI ĐIỆN THOẠI KHI ĐƠN HÀNG BỊ HUỶ
DROP TRIGGER IF EXISTS after_delete_order_detail $$
CREATE TRIGGER after_delete_order_detail
AFTER DELETE ON order_detail
FOR EACH ROW
BEGIN
    -- Kiểm tra xem điện thoại đã bị hủy đơn hàng chưa
    IF NOT EXISTS (
        SELECT 1
        FROM order_detail
        WHERE phoneID = OLD.phoneID
    ) THEN
        -- Cập nhật trạng thái điện thoại thành 'InStore'
        UPDATE phone
        SET status = 'InStore'
        WHERE phoneID IN (SELECT phoneID FROM order_detail WHERE orderID = OLD.orderID);
    END IF;
END $$


DELIMITER ;

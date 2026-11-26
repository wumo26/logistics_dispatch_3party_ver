package com.example.backend.service;

import com.example.backend.constants.OrderStatus;
import com.example.backend.constants.RouteStatus;
import com.example.backend.constants.ScheduleStatus;
import com.example.backend.constants.ShiftType;
import com.example.backend.dao.*;
import com.example.backend.entity.*;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.YearMonth;
import java.util.*;

/**
 * 排車狀態的集中防護，避免重排或撤回破壞已執行的配送歷史。
 */
@Service
@Transactional(readOnly = true)
public class DispatchGuardService {
    private final DriverShiftsDAO driverShiftsDAO;
    private final DriversDAO driversDAO;
    private final RoutesDAO routesDAO;
    private final OrdersDAO ordersDAO;
    private final VehiclesDAO vehiclesDAO;
    private final ScheduleMonthsDAO scheduleMonthsDAO;

    public DispatchGuardService(
            DriverShiftsDAO driverShiftsDAO, DriversDAO driversDAO, RoutesDAO routesDAO,
            OrdersDAO ordersDAO,
            VehiclesDAO vehiclesDAO, ScheduleMonthsDAO scheduleMonthsDAO
    ) {
        this.driverShiftsDAO = driverShiftsDAO;
        this.driversDAO = driversDAO;
        this.routesDAO = routesDAO;
        this.ordersDAO = ordersDAO;
        this.vehiclesDAO = vehiclesDAO;
        this.scheduleMonthsDAO = scheduleMonthsDAO;
    }

    @Transactional
    public void assertCanReplan(LocalDate date, Long warehouseId) {
        List<RoutesEntity> routes = routesDAO.findByDateAndWarehouseIdForUpdate(date, warehouseId);
        if (routes.stream().anyMatch(route -> route.getStatus() == RouteStatus.PUBLISHED)) {
            throw new IllegalArgumentException("當天已有發布的路線，請先撤回再重排");
        }
        List<Long> routeIds = routes.stream().map(RoutesEntity::getId).toList();
        if (!routeIds.isEmpty()) {
            List<String> delivering = ordersDAO.findByRouteIdIn(routeIds).stream()
                    .filter(order -> order.getStatus().isInDriverCustody())
                    .map(OrdersEntity::getOrderNumber)
                    .toList();
            if (!delivering.isEmpty()) {
                throw new IllegalArgumentException(
                        "仍有已點交或配送中的貨物，請完成配送或交接後再重排："
                                + String.join("、", delivering));
            }
            if (routesDAO.hasOpenMileage(routeIds)) {
                throw new IllegalArgumentException("仍有車輛尚未回倉收車，請完成里程後再重排");
            }
        }
    }

    @Transactional
    public void assertCanPublish(LocalDate date) {
        List<RoutesEntity> routes = routesDAO.findByDateForUpdate(date);
        if (routes.isEmpty()) {
            throw new IllegalArgumentException("當天沒有可發布的路線：" + date);
        }
        // 班表相關資料在迴圈前一次撈完，迴圈裡只從 Map 取，不必每條路線各查一次
        ScheduleMonthsEntity month = scheduleMonthsDAO.findByScheduleMonth(YearMonth.from(date).atDay(1)).orElse(null);
        boolean monthPublished = false;
        if (month != null && month.getStatus() == ScheduleStatus.PUBLISHED) {
            monthPublished = true;
        }
        // 同一位司機同一天只有一筆班次（uk_driver_shifts_driver_date），put 不會互相蓋掉
        Map<Long, DriverShiftsEntity> shiftsEntityMap = new HashMap<>();
        for (DriverShiftsEntity shift : driverShiftsDAO.findAllByWorkDate(date)) {
            shiftsEntityMap.put(shift.getDriverId(), shift);
        }
        List<Long> driverIds = new ArrayList<>();
        for (RoutesEntity route : routes) {
            if (route.getDriverId() != null) {
                driverIds.add(route.getDriverId());
            }
        }
        Map<Long, DriversEntity> driversEntityMap = new HashMap<>();
        for (DriversEntity driver : driversDAO.findAllById(driverIds)) {
            driversEntityMap.put(driver.getId(), driver);
        }

        List<String> problems = new ArrayList<>();
        // 月班表沒發布時每位司機都卡在同一條規則，整體列一次就好，不必每條路線重複一句
        if (!monthPublished) {
            problems.add(YearMonth.from(date) + " 的班表尚未發布");
        }
        for (RoutesEntity route : routes) {
            if (route.getStatus() != RouteStatus.DRAFT) {
                continue;
            }
            List<OrdersEntity> orders = ordersDAO.findByRouteIdOrderBySequence(route.getId());
            List<OrdersEntity> activeOrders = orders.stream()
                    .filter(order -> order.getStatus().isActive())
                    .toList();
            if (activeOrders.isEmpty()) {
                continue;
            }
            // 先查車輛：下面的訊息都用車牌辨識路線，路線編號調度員看不懂
            VehiclesEntity vehicle = vehiclesDAO.findById(route.getVehicleId()).orElse(null);
            String label = routeLabel(route, vehicle);

            List<String> wrongWarehouseOrders = activeOrders.stream()
                    .filter(order -> !Objects.equals(route.getWarehouseId(), order.getWarehouseId()))
                    .map(OrdersEntity::getOrderNumber)
                    .toList();
            if (!wrongWarehouseOrders.isEmpty()) {
                problems.add(label + " 含有不同出貨倉庫的訂單："
                        + String.join("、", wrongWarehouseOrders));
            }

            if (route.getDriverId() == null) {
                problems.add(label + " 尚未指派司機");
            } else {
                DriversEntity driver = driversEntityMap.get(route.getDriverId());
                if (monthPublished) {
                    // 月班表沒發布的情況上面已經整體列過，有發布才逐位檢查司機當天的班次
                    DriverShiftsEntity shift = shiftsEntityMap.get(route.getDriverId());
                    String reason = scheduleProblem(driver, shift, monthPublished);
                    if (reason != null) {
                        String who = label;
                        if (driver != null) {
                            who = label + "（" + driver.getName() + "）";
                        }
                        problems.add(who + "：" + reason);
                    }
                }
            }

            if (vehicle == null) {
                problems.add(label + " 找不到車輛");
            } else {
                int boxes = activeOrders.stream().mapToInt(OrdersEntity::getBoxCount).sum();
                if (boxes > vehicle.getCapacity()) {
                    problems.add("車輛 " + vehicle.getPlateNumber() + " 裝載 " + boxes
                            + " 箱，超過容量 " + vehicle.getCapacity() + " 箱");
                }
            }
        }

        if (!problems.isEmpty()) {
            throw new IllegalArgumentException(date + " 發布前檢查失敗：" + String.join("；", problems));
        }
    }

    /**
     * 司機當天不能出車的原因；可以出車時回傳 null。
     *
     * <p>只看傳進來的資料、不查資料庫：看板紅框與排車檢查共用同一套規則。
     * 規則與順序跟前端 driverScheduleNote 一致：先看人，再看月班表，最後看當天班次。
     * driver、shift 查不到時是 null，所以要先判斷才能讀它們的欄位。</p>
     */
    private String scheduleProblem(DriversEntity driver, DriverShiftsEntity shift, boolean monthPublished) {
        if (driver == null) {
            return "司機資料不存在";
        }
        if (!Boolean.TRUE.equals(driver.getIsActive())) {
            return "帳號已停用";
        }
        if (!monthPublished) {
            return "當月班表尚未發布";
        }
        if (shift == null) {
            return "當天未排班";
        }
        if (shift.getShiftType() == ShiftType.WORK) {
            return null;
        }
        if (shift.getShiftType() == ShiftType.DAY_OFF) {
            return "當天休假";
        }
        if (shift.getShiftType() == ShiftType.LEAVE) {
            if (shift.getChangeReason() == null || shift.getChangeReason().isBlank()) {
                return "當天請假";
            }
            return "當天請假（" + shift.getChangeReason() + "）";
        }
        // UNASSIGNED，以及日後新增、這裡還不認得的班次類型：一律當成不能出車
        return "當天尚未安排";
    }

    /** 訊息裡辨識路線：有車就用車牌，查不到車才退回路線編號 */
    private String routeLabel(RoutesEntity route, VehiclesEntity vehicle) {
        if (vehicle == null) {
            return "路線 " + route.getId();
        }
        return vehicle.getPlateNumber();
    }
}

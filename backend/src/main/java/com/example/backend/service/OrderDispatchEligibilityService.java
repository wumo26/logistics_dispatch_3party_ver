package com.example.backend.service;

import com.example.backend.constants.StoreStatus;
import com.example.backend.dao.StoresDAO;
import com.example.backend.dao.WarehousesDAO;
import com.example.backend.entity.StoresEntity;
import com.example.backend.entity.WarehousesEntity;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Locale;

/**
 * 訂單能否由指定倉庫排送的單一規則來源。
 *
 * <p>使用倉庫與門市座標的 Haversine 直線距離做穩定的半徑檢查，不依賴 OSRM 是否在線。
 * 真正的道路距離仍由排車階段的 OSRM 距離矩陣負責。</p>
 */
@Service
@Transactional(readOnly = true)
public class OrderDispatchEligibilityService {

    private static final double EARTH_RADIUS_METERS = 6_371_000.0;

    private final StoresDAO storesDAO;
    private final WarehousesDAO warehousesDAO;
    private final double maxDistanceMeters;

    public OrderDispatchEligibilityService(
            StoresDAO storesDAO,
            WarehousesDAO warehousesDAO,
            @Value("${app.dispatch.max-store-warehouse-distance-meters:30000}") double maxDistanceMeters
    ) {
        if (!Double.isFinite(maxDistanceMeters) || maxDistanceMeters <= 0) {
            throw new IllegalArgumentException("門市與倉庫的可排程距離上限必須大於 0 公尺");
        }
        this.storesDAO = storesDAO;
        this.warehousesDAO = warehousesDAO;
        this.maxDistanceMeters = maxDistanceMeters;
    }

    /** 供訂單確認／修改流程使用，避免未通過規則的訂單進入待排池。 */
    public void assertEligible(Long storeId, Long warehouseId) {
        StoresEntity store = storesDAO.findById(storeId)
                .orElseThrow(() -> new IllegalArgumentException("門市不存在，ID：" + storeId));
        WarehousesEntity warehouse = warehousesDAO.findById(warehouseId)
                .orElseThrow(() -> new IllegalArgumentException("倉庫不存在，ID：" + warehouseId));
        assertEligible(store, warehouse);
    }

    /** 供排車流程使用已經載入的實體，避免每張訂單再查一次資料庫。 */
    public void assertEligible(StoresEntity store, WarehousesEntity warehouse) {
        if (store.getStatus() != StoreStatus.ACTIVE) {
            throw new IllegalArgumentException("門市「" + store.getName() + "」目前未啟用，不能排程");
        }
        if (!Boolean.TRUE.equals(warehouse.getIsActive())) {
            throw new IllegalArgumentException("倉庫「" + warehouse.getName() + "」目前未啟用，不能排程");
        }
        assertValidCoordinates("門市「" + store.getName() + "」", store.getLat(), store.getLng());
        assertValidCoordinates("倉庫「" + warehouse.getName() + "」", warehouse.getLat(), warehouse.getLng());

        double distanceMeters = haversineMeters(
                warehouse.getLat(), warehouse.getLng(), store.getLat(), store.getLng());
        if (distanceMeters > maxDistanceMeters) {
            throw new IllegalArgumentException(String.format(
                    Locale.ROOT,
                    "門市「%s」距離倉庫「%s」約 %.1f 公里，超過可排程上限 %.1f 公里",
                    store.getName(), warehouse.getName(), distanceMeters / 1_000.0,
                    maxDistanceMeters / 1_000.0));
        }
    }

    double distanceMeters(StoresEntity store, WarehousesEntity warehouse) {
        return haversineMeters(warehouse.getLat(), warehouse.getLng(), store.getLat(), store.getLng());
    }

    private void assertValidCoordinates(String label, Double lat, Double lng) {
        if (lat == null || lng == null || !Double.isFinite(lat) || !Double.isFinite(lng)
                || lat < -90 || lat > 90 || lng < -180 || lng > 180) {
            throw new IllegalArgumentException(label + "缺少有效經緯度，不能排程");
        }
    }

    private double haversineMeters(double lat1, double lng1, double lat2, double lng2) {
        double latDelta = Math.toRadians(lat2 - lat1);
        double lngDelta = Math.toRadians(lng2 - lng1);
        double startLat = Math.toRadians(lat1);
        double endLat = Math.toRadians(lat2);
        double a = Math.sin(latDelta / 2) * Math.sin(latDelta / 2)
                + Math.cos(startLat) * Math.cos(endLat)
                * Math.sin(lngDelta / 2) * Math.sin(lngDelta / 2);
        double centralAngle = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(Math.max(0, 1 - a)));
        return EARTH_RADIUS_METERS * centralAngle;
    }
}

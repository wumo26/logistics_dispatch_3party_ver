package com.example.backend.service;

import com.example.backend.constants.StoreStatus;
import com.example.backend.dao.StoresDAO;
import com.example.backend.dao.WarehousesDAO;
import com.example.backend.entity.StoresEntity;
import com.example.backend.entity.WarehousesEntity;
import org.junit.jupiter.api.Test;

import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class OrderDispatchEligibilityServiceTest {

    private final StoresDAO storesDAO = mock(StoresDAO.class);
    private final WarehousesDAO warehousesDAO = mock(WarehousesDAO.class);
    private final OrderDispatchEligibilityService service =
            new OrderDispatchEligibilityService(storesDAO, warehousesDAO, 30_000);

    @Test
    void acceptsStoreInsideConfiguredRadius() {
        StoresEntity store = store(22.6300, 120.3100);
        WarehousesEntity warehouse = warehouse(22.6200, 120.3000);

        assertDoesNotThrow(() -> service.assertEligible(store, warehouse));
    }

    @Test
    void rejectsStoreOutsideConfiguredRadiusWithReadableDistance() {
        StoresEntity store = store(23.2000, 120.3000);
        WarehousesEntity warehouse = warehouse(22.6200, 120.3000);

        IllegalArgumentException error = assertThrows(
                IllegalArgumentException.class,
                () -> service.assertEligible(store, warehouse));

        assertTrue(error.getMessage().contains("超過可排程上限 30.0 公里"));
        assertTrue(error.getMessage().contains("測試門市"));
    }

    @Test
    void confirmationLookupUsesTheSameRule() {
        StoresEntity store = store(22.6300, 120.3100);
        WarehousesEntity warehouse = warehouse(22.6200, 120.3000);
        when(storesDAO.findById(11L)).thenReturn(Optional.of(store));
        when(warehousesDAO.findById(21L)).thenReturn(Optional.of(warehouse));

        assertDoesNotThrow(() -> service.assertEligible(11L, 21L));
    }

    @Test
    void rejectsInactiveStoreAndInvalidCoordinates() {
        StoresEntity inactive = store(22.6300, 120.3100);
        inactive.setStatus(StoreStatus.SUSPENDED);
        assertTrue(assertThrows(IllegalArgumentException.class,
                () -> service.assertEligible(inactive, warehouse(22.6200, 120.3000)))
                .getMessage().contains("未啟用"));

        StoresEntity invalid = store(95.0, 120.3100);
        assertTrue(assertThrows(IllegalArgumentException.class,
                () -> service.assertEligible(invalid, warehouse(22.6200, 120.3000)))
                .getMessage().contains("有效經緯度"));
    }

    private StoresEntity store(double lat, double lng) {
        StoresEntity store = new StoresEntity();
        store.setId(11L);
        store.setName("測試門市");
        store.setStatus(StoreStatus.ACTIVE);
        store.setLat(lat);
        store.setLng(lng);
        return store;
    }

    private WarehousesEntity warehouse(double lat, double lng) {
        WarehousesEntity warehouse = new WarehousesEntity();
        warehouse.setId(21L);
        warehouse.setName("測試倉庫");
        warehouse.setIsActive(true);
        warehouse.setLat(lat);
        warehouse.setLng(lng);
        return warehouse;
    }
}

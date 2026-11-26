package com.example.backend.service;

import com.example.backend.constants.OrderStatus;
import com.example.backend.constants.StoreStatus;
import com.example.backend.constants.VehicleStatus;
import com.example.backend.dao.DriversDAO;
import com.example.backend.dao.OrdersDAO;
import com.example.backend.dao.RoutesDAO;
import com.example.backend.dao.StoresDAO;
import com.example.backend.dao.VehiclesDAO;
import com.example.backend.dao.WarehousesDAO;
import com.example.backend.dispatch.OsrmClient;
import com.example.backend.dispatch.RouteOptimizer;
import com.example.backend.entity.OrdersEntity;
import com.example.backend.entity.StoresEntity;
import com.example.backend.entity.VehiclesEntity;
import com.example.backend.entity.WarehousesEntity;
import org.junit.jupiter.api.Test;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class DispatchDistanceGuardTest {

    @Test
    void autoDispatchRejectsDistanceBeforeCallingOsrm() {
        LocalDate date = LocalDate.of(2026, 10, 15);
        OrdersDAO ordersDAO = mock(OrdersDAO.class);
        VehiclesDAO vehiclesDAO = mock(VehiclesDAO.class);
        WarehousesDAO warehousesDAO = mock(WarehousesDAO.class);
        StoresDAO storesDAO = mock(StoresDAO.class);
        RoutesDAO routesDAO = mock(RoutesDAO.class);
        OsrmClient osrmClient = mock(OsrmClient.class);
        OrderDispatchEligibilityService eligibility = mock(OrderDispatchEligibilityService.class);

        WarehousesEntity warehouse = new WarehousesEntity();
        warehouse.setId(21L);
        warehouse.setName("測試倉");
        warehouse.setLat(22.6);
        warehouse.setLng(120.3);
        warehouse.setIsActive(true);
        StoresEntity store = new StoresEntity();
        store.setId(11L);
        store.setName("遠端門市");
        store.setLat(23.2);
        store.setLng(120.3);
        store.setStatus(StoreStatus.ACTIVE);
        OrdersEntity order = new OrdersEntity();
        order.setId(7L);
        order.setOrderNumber("FUTURE-007");
        order.setStoreId(11L);
        order.setWarehouseId(21L);
        order.setBoxCount(3);
        order.setDeliveryDate(date);
        order.setStatus(OrderStatus.CONFIRMED);
        VehiclesEntity vehicle = new VehiclesEntity();
        vehicle.setId(31L);
        vehicle.setWarehouseId(21L);
        vehicle.setPlateNumber("TEST-31");
        vehicle.setCapacity(20);
        vehicle.setStatus(VehicleStatus.AVAILABLE);

        when(warehousesDAO.findById(21L)).thenReturn(Optional.of(warehouse));
        when(routesDAO.findByDateAndWarehouseId(date, 21L)).thenReturn(List.of());
        when(ordersDAO.findByDeliveryDateAndStatusAndWarehouseIdAndRouteIdIsNull(
                date, OrderStatus.CONFIRMED, 21L)).thenReturn(List.of(order));
        when(vehiclesDAO.findByWarehouseIdAndStatus(21L, VehicleStatus.AVAILABLE))
                .thenReturn(List.of(vehicle));
        when(storesDAO.findAllById(any())).thenReturn(List.of(store));
        doThrow(new IllegalArgumentException("門市距離超過可排程上限"))
                .when(eligibility).assertEligible(store, warehouse);

        DispatchService service = new DispatchService(
                ordersDAO, vehiclesDAO, warehousesDAO, storesDAO, routesDAO,
                mock(DriversDAO.class), osrmClient, mock(RouteOptimizer.class), eligibility);

        assertThrows(IllegalArgumentException.class,
                () -> service.optimize(date, 21L, null));
        verify(osrmClient, never()).table(any());
    }
}

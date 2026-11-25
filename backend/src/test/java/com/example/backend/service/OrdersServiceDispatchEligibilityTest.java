package com.example.backend.service;

import com.example.backend.constants.OrderReviewAction;
import com.example.backend.constants.OrderStatus;
import com.example.backend.dao.OrdersDAO;
import com.example.backend.dao.StoresDAO;
import com.example.backend.dao.WarehousesDAO;
import com.example.backend.dto.request.OrderReviewRequestDTO;
import com.example.backend.entity.OrdersEntity;
import com.example.backend.entity.OrderItemsEntity;
import org.junit.jupiter.api.Test;

import java.time.LocalDate;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class OrdersServiceDispatchEligibilityTest {

    @Test
    void historyOrderItemsPreserveReportedMismatchAndUnknownActualQuantity() {
        OrdersDAO orders = mock(OrdersDAO.class);
        OrdersEntity order = new OrdersEntity();
        OrderItemsEntity item = new OrderItemsEntity();
        item.setItemName("鮮乳");
        item.setLoadingMismatchReported(true);
        order.addItem(item);
        when(orders.findById(7L)).thenReturn(Optional.of(order));
        OrdersService service = new OrdersService(orders, mock(StoresDAO.class), mock(WarehousesDAO.class),
                mock(OrderDispatchEligibilityService.class));

        var evidence = service.findById(7L).getItems().getFirst();
        assertTrue(evidence.isLoadingMismatchReported());
        assertNull(evidence.getLoadedQuantity());
    }

    @Test
    void confirmationCannotPutAnOutOfRangeOrderIntoTheDispatchPool() {
        OrdersDAO ordersDAO = mock(OrdersDAO.class);
        OrderDispatchEligibilityService eligibility = mock(OrderDispatchEligibilityService.class);
        OrdersService service = new OrdersService(
                ordersDAO, mock(StoresDAO.class), mock(WarehousesDAO.class), eligibility);

        OrdersEntity order = new OrdersEntity();
        order.setId(7L);
        order.setOrderNumber("FUTURE-007");
        order.setStoreId(11L);
        order.setWarehouseId(21L);
        order.setBoxCount(3);
        order.setDeliveryDate(LocalDate.of(2026, 10, 15));
        order.setStatus(OrderStatus.PENDING_CONFIRM);
        when(ordersDAO.findForUpdate(7L)).thenReturn(Optional.of(order));
        doThrow(new IllegalArgumentException("門市距離超過可排程上限"))
                .when(eligibility).assertEligible(11L, 21L);

        OrderReviewRequestDTO request = new OrderReviewRequestDTO();
        request.setAction(OrderReviewAction.CONFIRM);

        assertThrows(IllegalArgumentException.class, () -> service.review(7L, request));
        verify(ordersDAO, never()).save(order);
    }
}

package com.example.backend.dao;

import com.example.backend.constants.RouteStatus;
import com.example.backend.entity.RoutesEntity;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.Collection;
import java.util.List;
import java.util.Optional;

@Repository
public interface RoutesDAO extends JpaRepository<RoutesEntity, Long> {
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select route from RoutesEntity route where route.id = :id")
    Optional<RoutesEntity> findForUpdate(@Param("id") Long id);

    List<RoutesEntity> findByDateAndWarehouseId(LocalDate date, Long warehouseId);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("""
            select route from RoutesEntity route
            where route.date = :date and route.warehouseId = :warehouseId
            order by route.id
            """)
    List<RoutesEntity> findByDateAndWarehouseIdForUpdate(
            @Param("date") LocalDate date, @Param("warehouseId") Long warehouseId);

    @Query("""
            select distinct mileage.routeId from MileageLogsEntity mileage
            where mileage.routeId in :routeIds
            """)
    List<Long> findIdsWithMileage(@Param("routeIds") Collection<Long> routeIds);

    @Query("""
            select (count(mileage) > 0) from MileageLogsEntity mileage
            where mileage.routeId in :routeIds and mileage.endTime is null
            """)
    boolean hasOpenMileage(@Param("routeIds") Collection<Long> routeIds);

    /**
     * 當天全部倉庫的路線。
     *
     * 發布與撤回是一次涵蓋所有倉庫的動作，不像排車是一次一倉
     * 所以這裡不帶 warehouseId。
     */
    List<RoutesEntity> findByDate(LocalDate date);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select route from RoutesEntity route where route.date = :date order by route.id")
    List<RoutesEntity> findByDateForUpdate(@Param("date") LocalDate date);

    /**
     * 當天已指派司機的全部路線，不分倉庫。
     *
     * 司機不綁倉庫（見 docs/data-model.md），但一位司機一天只開一條路線，
     * 所以「誰還能指派」必須看整天而不是只看當前倉。
     */
    List<RoutesEntity> findByDateAndDriverIdIsNotNull(LocalDate date);

    /** 尚未到配送日的預覽只對已發布路線開放。 */
    List<RoutesEntity> findByDateAndDriverIdAndStatusOrderByIdAsc(
            LocalDate date, Long driverId, RouteStatus status);

    List<RoutesEntity> findByDateAndDriverIdOrderByIdAsc(LocalDate date, Long driverId);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select route from RoutesEntity route where route.date = :date and route.driverId = :driverId")
    Optional<RoutesEntity> findForDriverOnDateForUpdate(
            @Param("date") LocalDate date, @Param("driverId") Long driverId);

    /** 司機端預覽今天之後所有已發布任務，依配送日與路線排序。 */
    List<RoutesEntity> findByDateGreaterThanAndDriverIdAndStatusOrderByDateAscIdAsc(
            LocalDate date, Long driverId, RouteStatus status);

    boolean existsByDateAndDriverIdAndStatus(
            LocalDate date, Long driverId, RouteStatus status);

    /** 看板日期列：一段日期內全部倉庫的路線。 */
    List<RoutesEntity> findByDateBetween(LocalDate from, LocalDate to);

    /** 看板日期列：區間前面還沒結案的那幾天的路線。 */
    List<RoutesEntity> findByDateIn(Collection<LocalDate> dates);

}


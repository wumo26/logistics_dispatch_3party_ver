package com.example.backend.entity;

import jakarta.persistence.*;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

/** 每次提交保留一筆，綁定當次任務、人、車。撤回作廢但不刪除照片或稽核紀錄。 */
@Entity
@Table(name = "pre_trip_inspections", indexes = @Index(name = "idx_pre_trip_route", columnList = "routeId,id"))
public class PreTripInspection {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY) public Long id;
    @Column(nullable = false) public Long routeId;
    @Column(nullable = false) public Long driverId;
    @Column(nullable = false) public Long vehicleId;
    @Column(nullable = false) public Integer routeVersion;
    @Column(nullable = false) public LocalDate workDate;
    @Column(name = "alcohol_mg_l", nullable = false, precision = 3, scale = 2) public BigDecimal alcoholMgL;
    @Column(nullable = false) public boolean alcoholTested;
    @Column(nullable = false) public boolean headlights;
    @Column(nullable = false) public boolean taillights;
    @Column(nullable = false) public boolean turnSignals;
    @Column(nullable = false) public boolean brakeLights;
    @Column(nullable = false) public boolean frontLeftTire;
    @Column(nullable = false) public boolean frontRightTire;
    @Column(nullable = false) public boolean rearLeftTire;
    @Column(nullable = false) public boolean rearRightTire;
    @Column(nullable = false) public boolean dashcam;
    @Column(nullable = false) public String alcoholPhoto;
    @Column(nullable = false) public String vehiclePhoto;
    @Column(nullable = false) public String dashcamPhoto;
    @Column(nullable = false) public boolean passed;
    @Column(nullable = false) public LocalDateTime submittedAt;
    public LocalDateTime invalidatedAt;

    // Read accessors shared with the imported operational report queries.
    public Long getId() { return id; }
    public void setId(Long value) { id = value; }
    public Long getRouteId() { return routeId; }
    public void setRouteId(Long value) { routeId = value; }
    public Long getDriverId() { return driverId; }
    public void setDriverId(Long value) { driverId = value; }
    public Long getVehicleId() { return vehicleId; }
    public void setVehicleId(Long value) { vehicleId = value; }
    public Integer getRouteVersion() { return routeVersion; }
    public void setRouteVersion(Integer value) { routeVersion = value; }
    public LocalDate getWorkDate() { return workDate; }
    public void setWorkDate(LocalDate value) { workDate = value; }
    public Boolean getPassed() { return passed; }
    public void setPassed(boolean value) { passed = value; }
    public LocalDateTime getSubmittedAt() { return submittedAt; }
    public void setSubmittedAt(LocalDateTime value) { submittedAt = value; }
    public LocalDateTime getInvalidatedAt() { return invalidatedAt; }
    public void setInvalidatedAt(LocalDateTime value) { invalidatedAt = value; }
}

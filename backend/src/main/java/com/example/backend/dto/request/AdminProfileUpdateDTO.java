package com.example.backend.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

public record AdminProfileUpdateDTO(
        @NotBlank(message = "主管姓名不可空白")
        @Size(max = 50, message = "主管姓名不可超過 50 字元")
        String name,
        @Size(max = 20, message = "聯絡電話不可超過 20 字元")
        @Pattern(regexp = "[0-9+()\\-\\s]*", message = "聯絡電話格式不正確")
        String phone
) {}

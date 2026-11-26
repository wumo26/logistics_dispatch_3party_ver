package com.example.backend.controller;

import com.example.backend.dto.request.AdminUsersDTO;
import com.example.backend.service.AdminUsersService;
import com.example.backend.service.AuthService;
import jakarta.servlet.Filter;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.JwsHeader;
import org.springframework.security.oauth2.jwt.JwtClaimsSet;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.security.oauth2.jwt.JwtEncoderParameters;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.context.WebApplicationContext;

import java.time.Instant;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@Transactional
class AdminProfileApiTest {
    @Autowired WebApplicationContext context;
    @Autowired @Qualifier("springSecurityFilterChain") Filter security;
    @Autowired JwtEncoder jwtEncoder;
    @Autowired AdminUsersService admins;

    private MockMvc mvc;
    private String adminToken;

    @BeforeEach
    void setUp() {
        mvc = MockMvcBuilders.webAppContextSetup(context).addFilters(security).build();
        AdminUsersDTO dto = new AdminUsersDTO();
        dto.setAccount("CODEX-PROFILE-TEST");
        dto.setPassword("Test2026!");
        dto.setName("原主管名稱");
        dto.setPhone("0900000000");
        adminToken = bearer(admins.create(dto).getId(), AuthService.ROLE_ADMIN);
    }

    @Test
    void updatePersistsAndCurrentUserReadsFreshName() throws Exception {
        mvc.perform(get("/api/admin-users/me").header("Authorization", adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.name").value("原主管名稱"))
                .andExpect(jsonPath("$.phone").value("0900000000"));

        mvc.perform(put("/api/admin-users/me").header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"name\":\" 新主管名稱 \",\"phone\":\" 0912345678 \"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.name").value("新主管名稱"))
                .andExpect(jsonPath("$.phone").value("0912345678"));

        mvc.perform(get("/api/auth/me").header("Authorization", adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.name").value("新主管名稱"));
        mvc.perform(get("/api/admin-users/me").header("Authorization", adminToken))
                .andExpect(jsonPath("$.name").value("新主管名稱"));
    }

    @Test
    void invalidProfileIsRejectedWithoutChangingStoredData() throws Exception {
        mvc.perform(put("/api/admin-users/me").header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"name\":\" \",\"phone\":\"invalid\"}"))
                .andExpect(status().isBadRequest());
        mvc.perform(get("/api/admin-users/me").header("Authorization", adminToken))
                .andExpect(jsonPath("$.name").value("原主管名稱"));
    }

    @Test
    void driverCannotReadAdminProfile() throws Exception {
        mvc.perform(get("/api/admin-users/me")
                        .header("Authorization", bearer(1L, AuthService.ROLE_DRIVER)))
                .andExpect(status().isForbidden());
    }

    private String bearer(Long id, String role) {
        Instant now = Instant.now();
        JwtClaimsSet claims = JwtClaimsSet.builder()
                .issuer(AuthService.TOKEN_ISSUER).subject("CODEX-PROFILE-TEST")
                .issuedAt(now).expiresAt(now.plusSeconds(300))
                .claim("userId", id).claim("name", "原主管名稱").claim("role", role).build();
        return "Bearer " + jwtEncoder.encode(JwtEncoderParameters.from(
                JwsHeader.with(MacAlgorithm.HS256).build(), claims)).getTokenValue();
    }
}

package cl.duoc.jv0101.caso17.envios;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.web.servlet.MockMvc;

/**
 * IE3/IE4/IE5: el healthcheck de Docker Compose, la verificación post-deploy
 * del pipeline y el balanceador dependen de estos endpoints. Si alguien los
 * rompe, el pipeline falla en la etapa de pruebas, antes de construir la imagen.
 */
@SpringBootTest(properties = "APP_COMMIT=0123456789abcdef")
@AutoConfigureMockMvc
class ActuatorEndpointsTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void healthResponde200ConEstadoUp() throws Exception {
        mockMvc.perform(get("/actuator/health"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("UP"));
    }

    @Test
    void readinessIncluyeBaseDeDatosYEstaUp() throws Exception {
        mockMvc.perform(get("/actuator/health/readiness"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("UP"));
    }

    @Test
    void livenessEstaUp() throws Exception {
        mockMvc.perform(get("/actuator/health/liveness"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("UP"));
    }

    @Test
    void infoExponeVersionYCommitParaTrazabilidad() throws Exception {
        mockMvc.perform(get("/actuator/info"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.app.name").value("envios-svc"))
                .andExpect(jsonPath("$.app.version").isNotEmpty())
                .andExpect(jsonPath("$.app.commit").value("0123456789abcdef"));
    }

    @Test
    void endpointsSensiblesNoEstanExpuestos() throws Exception {
        mockMvc.perform(get("/actuator/env")).andExpect(status().isNotFound());
        mockMvc.perform(get("/actuator/beans")).andExpect(status().isNotFound());
    }
}

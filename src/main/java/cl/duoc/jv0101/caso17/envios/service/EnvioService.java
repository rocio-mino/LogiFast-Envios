package cl.duoc.jv0101.caso17.envios.service;

import java.util.List;
import java.util.Optional;
import org.springframework.stereotype.Service;
import cl.duoc.jv0101.caso17.envios.model.Envio;
import cl.duoc.jv0101.caso17.envios.repository.EnvioRepository;

@Service
public class EnvioService {

    private final EnvioRepository repository;

    public EnvioService(EnvioRepository repository) {
        this.repository = repository;
    }

    public List<Envio> findAll() {
        return repository.findAll();
    }

    public Optional<Envio> findById(Long id) {
        return repository.findById(id);
    }

    public Envio create(Envio recurso) {
        return repository.save(recurso);
    }

    public Optional<Envio> update(Long id, Envio datos) {
        return repository.findById(id).map(existente -> {
            existente.setNombre(datos.getNombre());
            existente.setOrigen(datos.getOrigen());
            existente.setPesoKg(datos.getPesoKg());
            return repository.save(existente);
        });
    }

    public boolean delete(Long id) {
        return repository.findById(id).map(existente -> {
            repository.delete(existente);
            return true;
        }).orElse(false);
    }
}

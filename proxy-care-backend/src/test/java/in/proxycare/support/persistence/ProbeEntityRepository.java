package in.proxycare.support.persistence;

import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

/** TEST-ONLY repository for {@link ProbeEntity}. */
public interface ProbeEntityRepository extends JpaRepository<ProbeEntity, UUID> {}

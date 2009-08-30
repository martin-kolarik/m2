package cz.smartcontrol.licensing.domain.model;

public interface VersionedDomainObject extends DomainObject {

    public Long getVersion();

    public void setVersion(Long version);

}
